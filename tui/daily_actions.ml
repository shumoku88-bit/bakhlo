(* Pure daily-ledger actions: transaction building, validation, draft conversion,
   publication and reload logic. Independent of terminal frontends and view layouts. *)
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module F = Daily_file
module R = Posting_draft

let get = function Ok x -> x | Error why -> raise (F.Refused why)
let get_id = function Ok x -> x | Error D.Identifier.Empty -> raise (F.Refused "empty-identity")
let lstr = D.Identifier.Locus.to_string
let mstr = D.Identifier.Measure.to_string
let quanta p = D.Quantity.quanta (D.Effect.quantity p)

type mode = New | Edit of B.entry | Pay of string

type transaction = {
  entry : B.entry;
  replace : bool;
  plan : string option;
}

type single_form = {
  day : string;
  measure : string;
  from_locus : string;
  to_locus : string;
  amount : string;
  memo : string;
}

type draft_content =
  | Single of single_form
  | Multiple of { day : string; memo : string; draft : R.t }

let pair effects =
  match effects with
  | [ a; b ]
    when D.Identifier.Measure.equal (D.Effect.measure a) (D.Effect.measure b)
         && Z.sign (quanta a) * Z.sign (quanta b) = -1
         && Z.equal (Z.add (quanta a) (quanta b)) Z.zero ->
      Some (if Z.sign (quanta a) < 0 then (a, b) else (b, a))
  | [] | _ :: _ -> None

type edit_preparation =
  | Edit_refused of string
  | Edit_single of { form : single_form; entry : B.entry }
  | Edit_multiple of { day : string; measure : string; memo : string; draft : R.t; entry : B.entry }

let prepare_edit ~book (e : B.entry) : edit_preparation =
  if
    e.exchange <> None || e.reversal_of <> None
    || List.exists (fun (row : B.entry) -> row.reversal_of = Some e.id) (B.entries book)
  then Edit_refused "両替・返金の対応を持つ明細は、この入力では編集しません。"
  else
    match pair e.effects with
    | None -> (
        match R.of_effects book e.effects with
        | Error why -> Edit_refused ("複数行編集拒否: " ^ why)
        | Ok draft ->
            Edit_multiple
              {
                day = e.day;
                measure = draft.measure;
                memo = Option.value ~default:"" e.memo;
                draft;
                entry = e;
              })
    | Some (from_, to_) ->
        let measure = mstr (D.Effect.measure from_) in
        Edit_single
          {
            form =
              {
                day = e.day;
                measure;
                from_locus = lstr (D.Effect.locus from_);
                to_locus = lstr (D.Effect.locus to_);
                amount = B.format book measure (quanta to_);
                memo = Option.value ~default:"" e.memo;
              };
            entry = e;
          }

type pay_preparation =
  | Pay_refused of string
  | Pay_single of { form : single_form; plan_id : string }
  | Pay_multiple of { day : string; measure : string; draft : R.t; plan_id : string }

let prepare_pay ~book (p : B.plan) : pay_preparation =
  if p.paid_by <> None then Pay_refused "この予定は支払い済みです。"
  else if p.cancelled_on <> None then Pay_refused "この予定は取消済みです。"
  else
    try
      let effects =
        List.map
          (fun (loc, n) ->
            D.Effect.create ~key:None
              ~locus:(get_id (D.Identifier.Locus.of_string loc))
              ~measure:(get_id (D.Identifier.Measure.of_string p.measure))
              ~quantity:(D.Quantity.of_quanta n))
          p.changes
      in
      match pair effects with
      | None -> (
          match R.of_effects book effects with
          | Error why -> Pay_refused ("支払い入力拒否: " ^ why)
          | Ok draft ->
              Pay_multiple
                {
                  day = F.today ();
                  measure = p.measure;
                  draft;
                  plan_id = p.id;
                })
      | Some (from_, to_) ->
          Pay_single
            {
              form =
                {
                  day = F.today ();
                  measure = p.measure;
                  from_locus = lstr (D.Effect.locus from_);
                  to_locus = lstr (D.Effect.locus to_);
                  amount = B.format book p.measure (quanta to_);
                  memo = "";
                };
              plan_id = p.id;
            }
    with F.Refused why -> Pay_refused ("支払い入力不可: " ^ why)

let prepare_postings ~book ~mode ~(form : single_form) : (R.t, string) result =
  match mode with
  | Edit e -> (
      match R.of_effects book e.effects with
      | Error _ as err -> err
      | Ok draft ->
          Ok
            {
              draft with
              rows =
                (match pair e.effects with
                | None -> draft.rows
                | Some _ ->
                    List.map
                      (fun (row : R.row) -> { row with amount = form.amount })
                      draft.rows);
            })
  | New | Pay _ ->
      Ok
        {
          R.measure = form.measure;
          rows =
            [
              {
                R.key = None;
                locus = form.from_locus;
                negative = true;
                amount = form.amount;
              };
              {
                R.key = None;
                locus = form.to_locus;
                negative = false;
                amount = form.amount;
              };
            ];
        }

let build_transaction ~book ~mode content : (transaction, string) result =
  try
    let day, memo_str, effects =
      match content with
      | Multiple { day; memo; draft } ->
          let effects = get (R.effects book draft) in
          (day, memo, effects)
      | Single form ->
          F.require (form.from_locus <> form.to_locus) "same-locus";
          let amount = get (B.parse_amount book form.measure form.amount) in
          let effects =
            match mode with
            | Edit e ->
                List.map
                  (fun p ->
                    D.Effect.create ~key:(D.Effect.key p) ~locus:(D.Effect.locus p)
                      ~measure:(D.Effect.measure p)
                      ~quantity:
                        (D.Quantity.of_quanta
                           (if Z.sign (quanta p) < 0 then Z.neg amount else amount)))
                  e.effects
            | New | Pay _ ->
                let effect_ loc n =
                  D.Effect.create ~key:None
                    ~locus:(get_id (D.Identifier.Locus.of_string loc))
                    ~measure:(get_id (D.Identifier.Measure.of_string form.measure))
                    ~quantity:(D.Quantity.of_quanta n)
                in
                [ effect_ form.from_locus (Z.neg amount); effect_ form.to_locus amount ]
          in
          (form.day, form.memo, effects)
    in
    (match D.Movement.validate effects with
    | Ok _ -> ()
    | Error _ -> raise (F.Refused "invalid-movement"));
    let memo =
      match mode with
      | Edit e when Option.value ~default:"" e.memo = memo_str -> e.memo
      | New | Pay _ | Edit _ -> if memo_str = "" then None else Some memo_str
    in
    let entry, replace, plan =
      match mode with
      | Edit e -> ({ e with day; memo; effects }, true, None)
      | New | Pay _ ->
          ( {
              B.id = F.new_id ();
              day;
              memo;
              effects;
              reversal_of = None;
              exchange = None;
            },
            false,
            match mode with Pay id -> Some id | New | Edit _ -> None )
    in
    match B.put_entry book ~replace entry ~plan with
    | Error why -> Error ("記帳拒否: " ^ why)
    | Ok _ -> Ok { entry; replace; plan }
  with
  | F.Refused why -> Error ("入力拒否: " ^ why)
  | Unix.Unix_error _ | Sys_error _ -> Error "入出力を開始できませんでした。下書きは保持しています。"

let recovery_message = "保存試行の未確認情報があります。書込み停止。終了して --inspect-recovery で確認してください。"

let recovery_notice ~session =
  match session.F.format with
  | F.Monolithic -> (
      try if F.unfinished_names session.F.path = [] then None else Some recovery_message
      with F.Refused _ | Unix.Unix_error _ | Sys_error _ -> Some "復旧情報を確認できません。書込み停止。空の状態とは扱いません。")
  | F.Records -> (
      match (session.F.engine, session.F.session) with
      | Some eng, Some sess -> (
          match Bakhlo_sexp.Durable_append.check_in_doubt eng ~session:sess with
          | Bakhlo_sexp.Durable_append.In_doubt_detected { unacknowledged_token; lsn; event_id } ->
              Some
                (Printf.sprintf
                   "未確認の保存があります (token: %s, lsn: %d, id: %s)。再送前に確認してください。"
                   unacknowledged_token lsn event_id)
          | Bakhlo_sexp.Durable_append.In_doubt_none -> None)
      | _ -> None)

type commit_result =
  | Published of F.t
  | Idempotent_duplicate of { lsn : int; event_id : string; session : F.t }
  | Conflict_base_changed
  | Conflict
  | Conflict_lsn of { expected : int; actual : int }
  | Payload_drift_refused of string
  | Recovery_blocked
  | Uncertain of string
  | Refused of string

let publish_candidate ~session candidate : commit_result =
  match F.publish session candidate with
  | F.Written session -> Published session
  | F.Conflict -> Conflict
  | F.Refused_input "recovery-required" -> Recovery_blocked
  | F.Refused_input why -> Refused ("記帳拒否: " ^ why)
  (* The publisher owns serialization. Only an uncertain result needs a retained
     copy here for existing reload reconciliation; ordinary saves do not reprint. *)
  | F.Uncertain -> Uncertain (B.to_string candidate)

let to_records_entry (e : B.entry) : Bakhlo_sexp.Records_book.entry =
  {
    id = e.id;
    day = e.day;
    token = Some (Printf.sprintf "tok-%s" e.id);
    memo = e.memo;
    effects = e.effects;
    reversal_of = e.reversal_of;
    exchange = e.exchange;
    opaque = [];
  }

let entry_equals (a : B.entry) (b : B.entry) =
  String.equal a.id b.id
  && String.equal a.day b.day
  && Option.equal String.equal a.memo b.memo
  && Option.equal String.equal a.reversal_of b.reversal_of
  && Option.equal
       (fun (x1, y1) (x2, y2) -> String.equal x1 x2 && String.equal y1 y2)
       a.exchange b.exchange
  && List.equal
       (fun e1 e2 ->
         D.Identifier.Locus.equal (D.Effect.locus e1) (D.Effect.locus e2)
         && D.Identifier.Measure.equal (D.Effect.measure e1) (D.Effect.measure e2)
         && D.Quantity.equal (D.Effect.quantity e1) (D.Effect.quantity e2))
       a.effects b.effects

let commit_transaction ~session ~base_bytes (tx : transaction) : commit_result =
  if base_bytes <> session.F.bytes then Conflict_base_changed
  else
    match session.format with
    | F.Monolithic -> (
        match B.put_entry session.book ~replace:tx.replace tx.entry ~plan:tx.plan with
        | Error why -> Refused ("記帳拒否: " ^ why)
        | Ok candidate -> publish_candidate ~session candidate)
    | F.Records -> (
        let rec_entry = to_records_entry tx.entry in
        match B.put_entry session.book ~replace:tx.replace tx.entry ~plan:tx.plan with
        | Ok candidate -> (
            try
              match F.append_entry ~candidate session rec_entry with
              | F.Append_committed { session = updated; _ } -> Published updated
              | F.Append_idempotent { session = updated; lsn; event_id } ->
                  Idempotent_duplicate { lsn; event_id; session = updated }
              | F.Append_lsn_conflict { expected; actual } ->
                  Conflict_lsn { expected; actual }
              | F.Append_drift_refused msg ->
                  Payload_drift_refused msg
              | F.Append_storage_error err ->
                  Refused ("保存失敗: " ^ err)
            with F.Refused why -> Refused ("追記拒否: " ^ why))
        | Error why -> (
            let existing_opt =
              List.find_opt
                (fun (e : B.entry) -> String.equal e.id tx.entry.id)
                (B.entries session.book)
            in
            match existing_opt with
            | Some existing when entry_equals existing tx.entry -> (
                try
                  match F.append_entry session rec_entry with
                  | F.Append_idempotent { session = updated; lsn; event_id } ->
                      Idempotent_duplicate { lsn; event_id; session = updated }
                  | F.Append_drift_refused msg ->
                      Payload_drift_refused msg
                  | _ -> Refused ("記帳拒否: " ^ why)
                with F.Refused _ -> Refused ("記帳拒否: " ^ why))
            | Some _ ->
                Payload_drift_refused (Printf.sprintf "duplicate-id-%s-payload-drift" tx.entry.id)
            | None -> Refused ("記帳拒否: " ^ why)))

let commit_add_locus ~session name : commit_result =
  match B.add_locus session.F.book name with
  | Error why -> Refused ("科目追加拒否: " ^ why)
  | Ok candidate -> (
      match session.format with
      | F.Monolithic -> publish_candidate ~session candidate
      | F.Records -> (
          try
            match F.append_add_locus ~candidate session name with
            | F.Append_committed { session = updated; _ } -> Published updated
            | F.Append_idempotent { session = updated; lsn; event_id } ->
                Idempotent_duplicate { lsn; event_id; session = updated }
            | F.Append_lsn_conflict { expected; actual } ->
                Conflict_lsn { expected; actual }
            | F.Append_drift_refused msg ->
                Payload_drift_refused msg
            | F.Append_storage_error err ->
                Refused ("科目追加失敗: " ^ err)
          with F.Refused why -> Refused ("科目追加拒否: " ^ why)))

type reload_result =
  | Pending_confirmed of F.t
  | Pending_unconfirmed of F.t
  | Edit_base_changed of F.t
  | Reloaded of F.t
  | Recovery_required of F.t * string
  | Reload_failed of string

let reload ~session ~pending ~mode : reload_result =
  try
    let loaded = F.load session.F.path in
    match recovery_notice ~session:loaded with
    | Some notice -> Recovery_required (loaded, notice)
    | None -> (
        match pending with
        | Some bytes when loaded.bytes = bytes -> Pending_confirmed loaded
        | Some _ -> Pending_unconfirmed loaded
        | None -> (
            match mode with
            | Edit _ when loaded.bytes <> session.bytes -> Edit_base_changed loaded
            | New | Pay _ | Edit _ -> Reloaded loaded))
  with
  | F.Refused why -> Reload_failed why
  | Unix.Unix_error _ | Sys_error _ -> Reload_failed "IO-error"
