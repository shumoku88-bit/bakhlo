(* A Record is a single-Measure form, not another book admission engine.
   Keep row order and keys; Book.put_entry still decides what may be saved. *)
module B = Book

type row = { key : string option; locus : string; negative : bool; amount : string }
type t = { measure : string; rows : row list }

type movement_fault =
  | Empty
  | Zero of int
  | Measure_differs of { position : int; expected : string; actual : string }
  | Unbalanced

let movement_fault (effects : B.posting list) =
  match effects with
  | [] -> Some Empty
  | first :: _ -> (
      let rec scan position = function
        | [] -> None
        | (p : B.posting) :: rest ->
            if Z.equal p.amount Z.zero then Some (Zero position)
            else if p.measure <> first.measure then
              Some (Measure_differs { position; expected = first.measure; actual = p.measure })
            else scan (position + 1) rest
      in
      match scan 1 effects with
      | Some _ as fault -> fault
      | None ->
          let sum = List.fold_left (fun s (p : B.posting) -> Z.add s p.amount) Z.zero effects in
          if Z.equal sum Z.zero then None else Some Unbalanced)

let of_effects book (effects : B.posting list) =
  match (movement_fault effects, effects) with
  | Some _, _ | None, [] -> Error "single-measure-movement-required"
  | None, first :: _ ->
      let measure = first.measure in
      if not (List.mem_assoc measure (B.measures book)) then Error "measure-scale-not-supplied"
      else
        Ok
          {
            measure;
            rows =
              List.map
                (fun (p : B.posting) ->
                  {
                    key = p.key;
                    locus = p.locus;
                    negative = Z.sign p.amount < 0;
                    amount = B.format book measure (Z.abs p.amount);
                  })
                effects;
          }

let amounts book draft =
  let rec loop position = function
    | [] -> Ok []
    | row :: rest -> (
        match B.parse_amount book ~measure:draft.measure row.amount with
        | Error why -> Error (Printf.sprintf "row-%d: %s" position why)
        | Ok n -> (
            match loop (position + 1) rest with
            | Error _ as error -> error
            | Ok ns -> Ok ((if row.negative then Z.neg n else n) :: ns)))
  in
  match draft.rows with [] -> Error "posting-required" | _ :: _ -> loop 1 draft.rows

let effects book draft =
  match amounts book draft with
  | Error _ as error -> error
  | Ok ns ->
      if draft.measure = "" then Error "empty-measure"
      else
        let rec loop position rows quantities =
          match (rows, quantities) with
          | [], [] -> Ok []
          | row :: rows, n :: ns -> (
              if row.locus = "" then Error (Printf.sprintf "row-%d: empty-locus" position)
              else
                match loop (position + 1) rows ns with
                | Error _ as error -> error
                | Ok rest ->
                    Ok
                      ({ B.key = row.key; locus = row.locus; measure = draft.measure; amount = n }
                      :: rest))
          | [], _ :: _ | _ :: _, [] -> Error "draft-row-count-mismatch"
        in
        loop 1 draft.rows ns

let pair (effects : B.posting list) =
  match effects with
  | [ a; b ]
    when a.measure = b.measure
         && Z.sign a.amount * Z.sign b.amount = -1
         && Z.equal (Z.add a.amount b.amount) Z.zero ->
      Some (if Z.sign a.amount < 0 then (a, b) else (b, a))
  | [] | _ :: _ -> None

let edit_refusal ~book (e : B.entry) =
  if
    e.exchange <> None || e.reversal_of <> None
    || List.exists (fun (row : B.entry) -> row.reversal_of = Some e.id) (B.entries book)
  then Some "linked-entry"
  else
    match pair e.effects with
    | Some _ -> None
    | None -> ( match of_effects book e.effects with Ok _ -> None | Error why -> Some why)

type mode = New | Edit of B.entry | Pay of string | Plan_new | Plan_edit of B.plan
type form_row = { key : string option; locus : string; amount : string }

let split_sign text =
  let negative = String.starts_with ~prefix:"-" text in
  if negative || String.starts_with ~prefix:"+" text then
    (negative, String.sub text 1 (String.length text - 1))
  else (false, text)

let form ~mode ~measure (rows : form_row list) =
  {
    measure;
    rows =
      List.map
        (fun (row : form_row) ->
          let negative, amount = split_sign row.amount in
          let key =
            match (mode, row.key) with
            | Edit entry, Some key ->
                if
                  List.exists
                    (fun (p : B.posting) -> p.key = Some key && p.locus = row.locus)
                    entry.effects
                then Some key
                else None
            | _, key -> key
          in
          { key; locus = row.locus; negative; amount })
        rows;
  }

let open_plan_draft ~book (plan : B.plan) =
  if plan.paid_by <> None then Error "plan-already-paid"
  else if plan.cancelled_on <> None then Error "plan-cancelled"
  else
    let effects =
      List.map
        (fun (locus, amount) ->
          if locus = "" || plan.measure = "" then None
          else Some { B.key = None; locus; measure = plan.measure; amount })
        plan.changes
    in
    if List.exists Option.is_none effects then Error "invalid-plan-posting"
    else of_effects book (List.filter_map Fun.id effects)

type transaction = { entry : B.entry; replace : bool; plan : string option }

type draft_content =
  | Multiple of { day : string; memo : string; draft : t; original_amount : (string * Z.t) option }

type error =
  | Day_format
  | Day_invalid
  | Postings of string
  | Movement of movement_fault
  | Original_measure
  | Admission of { reason : string; id : string }

let movement_code = function
  | Empty -> "empty"
  | Zero p -> Printf.sprintf "zero:%d" p
  | Measure_differs { position; expected; actual } ->
      Printf.sprintf "measure-differs:%d:%s:%s" position expected actual
  | Unbalanced -> "unbalanced"

let code = function
  | Day_format -> "day-format"
  | Day_invalid -> "day-invalid"
  | Postings why -> "postings:" ^ why
  | Movement why -> "movement:" ^ movement_code why
  | Original_measure -> "original-measure"
  | Admission { reason; _ } -> "admission:" ^ reason

let ( let* ) = Result.bind

let canonical_day day =
  match Day.normalize day with
  | Error _ -> Error Day_format
  | Ok day when not (Day.is_valid day) -> Error Day_invalid
  | Ok day -> Ok day

let draft_effects ~book draft = Result.map_error (fun why -> Postings why) (effects book draft)

let balanced effects =
  match movement_fault effects with None -> Ok () | Some why -> Error (Movement why)

let build_transaction ~new_id ~book ~mode
    (Multiple { day; memo = memo_str; draft; original_amount }) =
  let* day = canonical_day day in
  let* effects = draft_effects ~book draft in
  let* () =
    match original_amount with
    | Some (m, _) when not (List.mem_assoc m (B.measures book)) -> Error Original_measure
    | _ -> Ok ()
  in
  let* () = balanced effects in
  let memo =
    match mode with
    | Edit e when Option.value ~default:"" e.memo = memo_str -> e.memo
    | New | Pay _ | Edit _ | Plan_new | Plan_edit _ -> if memo_str = "" then None else Some memo_str
  in
  let entry, replace, plan =
    match mode with
    | Edit e -> ({ e with day; memo; effects }, true, None)
    | New | Pay _ | Plan_new | Plan_edit _ ->
        ( {
            B.id = new_id ();
            day;
            memo;
            effects;
            reversal_of = None;
            exchange = None;
            original_amount;
            merchant = None;
          },
          false,
          match mode with Pay id -> Some id | New | Edit _ | Plan_new | Plan_edit _ -> None )
  in
  match B.put_entry book ~replace entry ~plan with
  | Ok _ -> Ok { entry; replace; plan }
  | Error reason -> Error (Admission { reason; id = entry.id })

let build_plan ~new_id ~book ~mode ~day ~draft =
  let* day = canonical_day day in
  let* effects = draft_effects ~book draft in
  let* () = balanced effects in
  let changes = List.map (fun (e : B.posting) -> (e.locus, e.amount)) effects in
  let plan, replace =
    match mode with
    | Plan_edit p -> ({ p with day; measure = draft.measure; changes }, true)
    | Plan_new ->
        ( {
            B.id = new_id ();
            day;
            measure = draft.measure;
            changes;
            paid_by = None;
            cancelled_on = None;
          },
          false )
    | New | Edit _ | Pay _ -> failwith "unexpected mode for build_plan"
  in
  match B.put_plan book ~replace plan with
  | Ok _ -> Ok (plan, replace)
  | Error reason -> Error (Admission { reason; id = plan.id })

(* The Original field's decimal contract predates receipt expressions. Keep it
   distinct: changing its accepted notation would change the existing editor. *)
let parse_original_quanta ~scale amount_str =
  let trimmed = String.trim amount_str in
  if trimmed = "" then Error `Invalid
  else
    match split_sign trimmed with
    | true, _ -> Error `Non_positive
    | false, core -> (
        let core = String.concat "" (String.split_on_char ',' core) in
        let is_digit c = c >= '0' && c <= '9' in
        match String.split_on_char '.' core with
        | [ whole ] ->
            let whole = String.trim whole in
            if whole = "" || not (String.for_all is_digit whole) then Error `Invalid
            else
              let q = Z.mul (Z.of_string whole) (Z.pow (Z.of_int 10) scale) in
              if Z.sign q <= 0 then Error `Non_positive else Ok q
        | [ whole; fraction ] ->
            let whole = String.trim whole in
            let fraction = String.trim fraction in
            let whole_ok = whole = "" || String.for_all is_digit whole in
            let frac_ok = fraction <> "" && String.for_all is_digit fraction in
            if not (whole_ok && frac_ok) then Error `Invalid
            else if String.length fraction > scale then Error `Precision
            else
              let whole_val = if whole = "" then Z.zero else Z.of_string whole in
              let frac_padded = fraction ^ String.make (scale - String.length fraction) '0' in
              let frac_val = if frac_padded = "" then Z.zero else Z.of_string frac_padded in
              let q = Z.add (Z.mul whole_val (Z.pow (Z.of_int 10) scale)) frac_val in
              if Z.sign q <= 0 then Error `Non_positive else Ok q
        | _ -> Error `Invalid)

let original_code = function
  | `Invalid -> "invalid-amount"
  | `Precision -> "amount-precision"
  | `Non_positive -> "non-positive-amount"
