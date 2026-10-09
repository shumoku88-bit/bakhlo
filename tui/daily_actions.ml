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
        | Error "single-measure-movement-required" ->
            Edit_refused "単一通貨の通常移動のみ編集に対応しています。"
        | Error "measure-scale-not-supplied" ->
            Edit_refused "台帳に通貨の定義が存在しないため、編集できません。"
        | Error why -> Edit_refused (Printf.sprintf "複数行編集拒否 (%s)" why)
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
          | Error "single-measure-movement-required" ->
              Pay_refused "単一通貨の通常移動のみ支払い入力に対応しています。"
          | Error "measure-scale-not-supplied" ->
              Pay_refused "台帳に通貨の定義が存在しないため、支払い入力できません。"
          | Error why -> Pay_refused (Printf.sprintf "支払い入力拒否 (%s)" why)
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

type field_target =
  | Field_date
  | Field_currency
  | Field_source
  | Field_destination
  | Field_amount
  | Field_memo

type transaction_error = {
  message : string;
  field : field_target option;
  raw_cause : string;
}

let is_valid_date day =
  match D.Identifier.Event.of_string "date-check" with
  | Error _ -> false
  | Ok eid -> (
      match D.Event.create ~id:eid ~effects:[] with
      | Error _ -> false
      | Ok event -> (
          match D.Event_memory.of_events [ event ] with
          | Error _ -> false
          | Ok events -> (
              match
                Bakhlo_application.Actual_validity.create ~events
                  ~facts:[ Bakhlo_application.Actual_validity.Base { event = D.Event.id event; valid_on = day } ]
                  ~corrections:[]
              with
              | Ok _ -> true
              | Error _ -> false)))

let build_transaction ~book ~mode content : (transaction, transaction_error) result =
  let err ?field ~raw message = Error { message; field; raw_cause = raw } in
  let validate_and_put ~day ~memo_str ~effects =
    match D.Movement.validate effects with
    | Error _ ->
        err ~raw:"invalid-movement"
          "出金と入金の合計額が一致していません。貸借差額が0になるよう確認してください。"
    | Ok _ ->
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
        | Ok _ -> Ok { entry; replace; plan }
        | Error "duplicate-entry" ->
            err ~raw:"duplicate-entry"
              (Printf.sprintf "同一の取引IDが既に台帳に存在します (ID: %s)。" entry.id)
        | Error "measure-scale-not-supplied" ->
            err ~field:Field_currency ~raw:"measure-scale-not-supplied"
              "指定された通貨は台帳に登録されていません。"
        | Error "locus-unapproved" ->
            err ~raw:"locus-unapproved"
              "台帳で許可されていない科目が含まれています。登録済み科目を確認してください。"
        | Error "plan-already-paid" ->
            err ~raw:"plan-already-paid" "この支払い予定は既に支払い済みです。"
        | Error "plan-cancelled" ->
            err ~raw:"plan-cancelled" "この支払い予定は既に取消済みです。"
        | Error "unknown-plan" ->
            err ~raw:"unknown-plan" "指定された支払い予定が見つかりません。"
        | Error "entry-admission" ->
            (* Date has already been proven valid via Actual_validity.valid_date.
               Therefore this refusal represents a ledger event admission requirement
               (e.g. zero quantity, imbalance, or invalid relation/reversal), NOT a date error. *)
            err ~raw:"entry-admission"
              "台帳の記録要件を満たしていません (entry-admission)。貸借バランスや取引の前提条件を確認してください。"
        | Error why ->
            err ~raw:why
              (Printf.sprintf "記帳が拒否されました (%s)。入力内容を確認してください。" why)
  in
  match content with
  | Single form ->
      if not (is_valid_date form.day) then
        err ~field:Field_date ~raw:"invalid-date"
          "日付の形式が正しくありません (YYYY-MM-DD)。例: 2026-10-09"
      else if String.equal form.from_locus "" then
        err ~field:Field_source ~raw:"empty-source-locus"
          "出金元の科目が未選択です。出金元を選んでください。"
      else if String.equal form.to_locus "" then
        err ~field:Field_destination ~raw:"empty-destination-locus"
          "入金先・科目が未選択です。入金先を選んでください。"
      else if String.equal form.from_locus form.to_locus then
        err ~field:Field_destination ~raw:"same-locus"
          (Printf.sprintf "出金元と入金先に同じ科目 (%s) は指定できません。異なる科目を選んでください。"
             (B.label book form.from_locus))
      else if String.equal form.amount "" then
        err ~field:Field_amount ~raw:"empty-amount"
          "金額が入力されていません。半角数字で入力してください。"
      else
        (match B.parse_amount book form.measure form.amount with
        | Error "invalid-amount" ->
            err ~field:Field_amount ~raw:"invalid-amount"
              "金額の形式が正しくありません。半角数字で入力してください (例: 1000)。"
        | Error "non-positive-amount" ->
            err ~field:Field_amount ~raw:"non-positive-amount"
              "金額には0より大きい正の値を入力してください。"
        | Error "amount-precision" ->
            let scale =
              try List.assoc form.measure (B.measures book) with Not_found -> 0
            in
            let exp = if scale = 0 then "整数のみ" else Printf.sprintf "小数%d桁まで" scale in
            err ~field:Field_amount ~raw:"amount-precision"
              (Printf.sprintf "通貨 %s の小数桁数を超えています (%s)。" form.measure exp)
        | Error why ->
            err ~field:Field_amount ~raw:why
              (Printf.sprintf "金額の入力が不正です (%s)。" why)
        | Ok amount ->
            let effects_res =
              try
                let effect_ loc n =
                  D.Effect.create ~key:None
                    ~locus:(get_id (D.Identifier.Locus.of_string loc))
                    ~measure:(get_id (D.Identifier.Measure.of_string form.measure))
                    ~quantity:(D.Quantity.of_quanta n)
                in
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
                      [ effect_ form.from_locus (Z.neg amount); effect_ form.to_locus amount ]
                in
                Ok effects
              with F.Refused why -> Error why
            in
            (match effects_res with
            | Error why ->
                err ~raw:why (Printf.sprintf "科目の指定が不正です (%s)。" why)
            | Ok effects ->
                validate_and_put ~day:form.day ~memo_str:form.memo ~effects))

  | Multiple { day; memo = memo_str; draft } ->
      if not (is_valid_date day) then
        err ~field:Field_date ~raw:"invalid-date"
          "日付の形式が正しくありません (YYYY-MM-DD)。例: 2026-10-09"
      else
        match R.effects book draft with
        | Error "posting-required" ->
            err ~raw:"posting-required" "明細行がありません。1行以上の取引明細を入力してください。"
        | Error "empty-measure" ->
            err ~field:Field_currency ~raw:"empty-measure" "通貨が指定されていません。"
        | Error why when Base.String.is_substring why ~substring:"invalid-amount" ->
            err ~raw:why (Printf.sprintf "%s。半角数字で金額を入力してください。" why)
        | Error why when Base.String.is_substring why ~substring:"non-positive-amount" ->
            err ~raw:why (Printf.sprintf "%s。0より大きい正の金額を入力してください。" why)
        | Error why when Base.String.is_substring why ~substring:"amount-precision" ->
            err ~raw:why (Printf.sprintf "%s。通貨の小数桁数を確認してください。" why)
        | Error why when Base.String.is_substring why ~substring:"科目未選択" ->
            err ~raw:why (Printf.sprintf "%s。科目を選んでください。" why)
        | Error why ->
            err ~raw:why (Printf.sprintf "複数行明細の入力が不正です (%s)。" why)
        | Ok effects ->
            validate_and_put ~day ~memo_str ~effects

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
  | Storage_failed of string
  | Refused of string

let publish_candidate ~session candidate : commit_result =
  try
    match F.publish session candidate with
    | F.Written session -> Published session
    | F.Conflict -> Conflict
    | F.Refused_input "recovery-required" -> Recovery_blocked
    | F.Refused_input why -> Refused why
    | F.Uncertain -> Uncertain "一括書換の成否が不確定です"
  with
  | Unix.Unix_error (err, fn, arg) ->
      Storage_failed (Printf.sprintf "%s (%s %s)" (Unix.error_message err) fn arg)
  | Sys_error msg -> Storage_failed msg

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
        | Error why -> Refused why
        | Ok candidate -> publish_candidate ~session candidate)
    | F.Records -> (
        let rec_entry = to_records_entry tx.entry in
        match B.put_entry session.book ~replace:tx.replace tx.entry ~plan:tx.plan with
        | Ok candidate -> (
            try
              match F.append_entry ~candidate session rec_entry with
              | F.Append_committed { session = updated; _ } -> Published updated
              | F.Append_sync_uncertain { error; _ } ->
                  Uncertain (Printf.sprintf "ディレクトリ同期失敗: %s" error)
              | F.Append_idempotent { session = updated; lsn; event_id } ->
                  Idempotent_duplicate { lsn; event_id; session = updated }
              | F.Append_lsn_conflict { expected; actual } ->
                  Conflict_lsn { expected; actual }
              | F.Append_drift_refused msg ->
                  Payload_drift_refused msg
              | F.Append_storage_error err ->
                  Storage_failed err
            with
            | Unix.Unix_error (err, fn, arg) ->
                Storage_failed (Printf.sprintf "%s (%s %s)" (Unix.error_message err) fn arg)
            | Sys_error msg -> Storage_failed msg
            | F.Refused why -> Refused why)
        | Error why -> (
            let existing_opt = B.find_entry session.book tx.entry.id in
            match existing_opt with
            | Some existing when entry_equals existing tx.entry -> (
                try
                  match F.append_entry session rec_entry with
                  | F.Append_idempotent { session = updated; lsn; event_id } ->
                      Idempotent_duplicate { lsn; event_id; session = updated }
                  | F.Append_drift_refused msg ->
                      Payload_drift_refused msg
                  | _ -> Refused why
                with F.Refused _ -> Refused why)
            | Some _ ->
                Payload_drift_refused (Printf.sprintf "duplicate-id-%s-payload-drift" tx.entry.id)
            | None -> Refused why))

let commit_add_locus ~session name : commit_result =
  let name = String.trim name in
  if String.equal name "" then
    Refused "科目名が入力されていません。追加する科目名を入力してください。"
  else
    match B.add_locus session.F.book name with
    | Error "duplicate-locus" ->
        Refused (Printf.sprintf "科目「%s」は既に登録されています。" name)
    | Error "locus-policy-not-supplied" ->
        Refused "台帳に科目管理ポリシーが設定されていません。"
    | Error why ->
        Refused (Printf.sprintf "科目追加拒否 (%s)" why)
    | Ok candidate -> (
        match session.format with
        | F.Monolithic -> publish_candidate ~session candidate
        | F.Records -> (
            try
              match F.append_add_locus ~candidate session name with
              | F.Append_committed { session = updated; _ } -> Published updated
              | F.Append_sync_uncertain { error; _ } ->
                  Uncertain (Printf.sprintf "ディレクトリ同期失敗: %s" error)
              | F.Append_idempotent { session = updated; lsn; event_id } ->
                  Idempotent_duplicate { lsn; event_id; session = updated }
              | F.Append_lsn_conflict { expected; actual } ->
                  Conflict_lsn { expected; actual }
              | F.Append_drift_refused msg ->
                  Payload_drift_refused msg
              | F.Append_storage_error err ->
                  Storage_failed err
            with
            | Unix.Unix_error (err, fn, arg) ->
                Storage_failed (Printf.sprintf "%s (%s %s)" (Unix.error_message err) fn arg)
            | Sys_error msg -> Storage_failed msg
            | F.Refused why -> Refused why))

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
