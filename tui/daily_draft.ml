(* Pure draft construction and validation. IDs and dates are supplied by the caller. *)
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module R = Posting_draft

let tr = Ui_text.tr

(* Translate stable format templates before inserting household values. *)
let format_message format =
  Printf.sprintf (Scanf.format_from_string (tr (string_of_format format)) format)

exception Refused of string

let get = function Ok x -> x | Error why -> raise (Refused why)
let get_id = function Ok x -> x | Error D.Identifier.Empty -> raise (Refused "empty-identity")
let lstr = D.Identifier.Locus.to_string
let mstr = D.Identifier.Measure.to_string
let quanta p = D.Quantity.quanta (D.Effect.quantity p)

type mode = New | Edit of B.entry | Pay of string | Plan_new | Plan_edit of B.plan
type transaction = { entry : B.entry; replace : bool; plan : string option }
type payload =
  | Entry_tx of transaction
  | Plan_tx of { plan : B.plan; replace : bool }

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
  | Multiple of {
      day : string;
      memo : string;
      draft : R.t;
      original_amount : (string * Z.t) option;
    }

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
  then Edit_refused (tr "Entries with Exchange or Reversal links cannot be edited here.")
  else
    match pair e.effects with
    | None -> (
        match R.of_effects book e.effects with
        | Error "single-measure-movement-required" ->
            Edit_refused (tr "Only ordinary single-Measure Movements can be edited here.")
        | Error "measure-scale-not-supplied" ->
            Edit_refused (tr "The Measure scale is not supplied; editing is unavailable.")
        | Error why -> Edit_refused (format_message "Multi-posting edit refused (%s)" why)
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

let prepare_pay ~today ~book (p : B.plan) : pay_preparation =
  if p.paid_by <> None then Pay_refused (tr "This Scheduled occurrence is already completed.")
  else if p.cancelled_on <> None then Pay_refused (tr "This Scheduled occurrence is cancelled.")
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
              Pay_refused (tr "Completion supports ordinary single-Measure Movements only.")
          | Error "measure-scale-not-supplied" ->
              Pay_refused (tr "The Measure scale is not supplied; completion is unavailable.")
          | Error why -> Pay_refused (format_message "Scheduled completion refused (%s)" why)
          | Ok draft ->
              Pay_multiple { day = today; measure = p.measure; draft; plan_id = p.id })
      | Some (from_, to_) ->
          Pay_single
            {
              form =
                {
                  day = today;
                  measure = p.measure;
                  from_locus = lstr (D.Effect.locus from_);
                  to_locus = lstr (D.Effect.locus to_);
                  amount = B.format book p.measure (quanta to_);
                  memo = "";
                };
              plan_id = p.id;
            }
    with Refused why -> Pay_refused (tr "Scheduled completion unavailable: " ^ why)

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
                    List.map (fun (row : R.row) -> { row with amount = form.amount }) draft.rows);
            })
  | New | Pay _ | Plan_new | Plan_edit _ ->
      Ok
        {
          R.measure = form.measure;
          rows =
            [
              { R.key = None; locus = form.from_locus; negative = true; amount = form.amount };
              { R.key = None; locus = form.to_locus; negative = false; amount = form.amount };
            ];
        }

type field_target =
  | Field_date
  | Field_currency
  | Field_source
  | Field_destination
  | Field_amount
  | Field_memo

type transaction_error = { message : string; field : field_target option; raw_cause : string }

let normalize_date_text text =
  let len = String.length text in
  let b = Buffer.create len in
  let rec loop i =
    if i >= len then Buffer.contents b
    else if i + 2 < len && Char.code text.[i] = 0xEF && Char.code text.[i + 1] = 0xBC then
      let c3 = Char.code text.[i + 2] in
      if c3 >= 0x90 && c3 <= 0x99 then begin
        Buffer.add_char b (Char.chr (Char.code '0' + (c3 - 0x90)));
        loop (i + 3)
      end
      else if c3 = 0x8F then begin
        Buffer.add_char b '/';
        loop (i + 3)
      end
      else if c3 = 0x8E then begin
        Buffer.add_char b '.';
        loop (i + 3)
      end
      else if c3 = 0x8D then begin
        Buffer.add_char b '-';
        loop (i + 3)
      end
      else begin
        Buffer.add_substring b text i 3;
        loop (i + 3)
      end
    else begin
      Buffer.add_char b text.[i];
      loop (i + 1)
    end
  in
  loop 0

let is_leap_year y = y mod 400 = 0 || (y mod 4 = 0 && y mod 100 <> 0)

let days_in_month ~year ~month =
  match month with
  | 1 | 3 | 5 | 7 | 8 | 10 | 12 -> 31
  | 4 | 6 | 9 | 11 -> 30
  | 2 -> if is_leap_year year then 29 else 28
  | _ -> 0

let normalize_date text =
  let norm = normalize_date_text text in
  let count_char c s =
    let count = ref 0 in
    String.iter (fun ch -> if ch = c then incr count) s;
    !count
  in
  let dashes = count_char '-' norm in
  let slashes = count_char '/' norm in
  let dots = count_char '.' norm in
  let sep_opt =
    if dashes = 2 && slashes = 0 && dots = 0 then Some '-'
    else if slashes = 2 && dashes = 0 && dots = 0 then Some '/'
    else if dots = 2 && dashes = 0 && slashes = 0 then Some '.'
    else None
  in
  match sep_opt with
  | None -> Error "invalid-date"
  | Some sep -> (
      match String.split_on_char sep norm with
      | [ y_str; m_str; d_str ] ->
          let is_digit c = c >= '0' && c <= '9' in
          if String.length y_str <> 4 || not (String.for_all is_digit y_str) then
            Error "invalid-date"
          else if
            (String.length m_str < 1 || String.length m_str > 2)
            || not (String.for_all is_digit m_str)
          then Error "invalid-date"
          else if
            (String.length d_str < 1 || String.length d_str > 2)
            || not (String.for_all is_digit d_str)
          then Error "invalid-date"
          else
            let year = int_of_string y_str in
            let month = int_of_string m_str in
            let day = int_of_string d_str in
            if year < 1 || year > 9999 then Error "invalid-date"
            else if month < 1 || month > 12 then Error "invalid-date"
            else if day < 1 || day > days_in_month ~year ~month then Error "invalid-date"
            else Ok (Printf.sprintf "%04d-%02d-%02d" year month day)
      | _ -> Error "invalid-date")

let next_calendar_day (year, month, day) =
  let max_d = days_in_month ~year ~month in
  if day < max_d then (year, month, day + 1)
  else if month < 12 then (year, month + 1, 1)
  else (year + 1, 1, 1)

let prev_calendar_day (year, month, day) =
  if day > 1 then (year, month, day - 1)
  else if month > 1 then
    let prev_m = month - 1 in
    (year, prev_m, days_in_month ~year ~month:prev_m)
  else (year - 1, 12, 31)

let shift_calendar_day date_str step =
  match normalize_date date_str with
  | Error _ -> Error "invalid-date"
  | Ok canon ->
      let year = int_of_string (String.sub canon 0 4)
      and month = int_of_string (String.sub canon 5 2)
      and day = int_of_string (String.sub canon 8 2) in
      let rec loop (y, m, d) n =
        if n = 0 then (y, m, d)
        else if n > 0 then loop (next_calendar_day (y, m, d)) (n - 1)
        else loop (prev_calendar_day (y, m, d)) (n + 1)
      in
      let y, m, d = loop (year, month, day) step in
      if y < 1 || y > 9999 then Error "date-out-of-range"
      else Ok (Printf.sprintf "%04d-%02d-%02d" y m d)

let is_valid_canonical_date day =
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
                  ~facts:
                    [
                      Bakhlo_application.Actual_validity.Base
                        { event = D.Event.id event; valid_on = day };
                    ]
                  ~corrections:[]
              with
              | Ok _ -> true
              | Error _ -> false)))

let is_valid_date day =
  match normalize_date day with Error _ -> false | Ok canon -> is_valid_canonical_date canon

let build_transaction ~new_id ~book ~mode content : (transaction, transaction_error) result =
  let err ?field ~raw message = Error { message; field; raw_cause = raw } in
  let validate_and_put ~day ~memo_str ~effects ~original_amount =
    match original_amount with
    | Some (m, _) when not (List.mem_assoc m (B.measures book)) ->
        err ~field:Field_currency ~raw:"measure-scale-not-supplied"
          (tr "The Measure scale is not supplied in this book.")
    | _ -> (
    match D.Movement.validate effects with
    | Error (D.Movement.Empty :: _) ->
        err ~raw:"empty-movement" (tr "At least one posting is required.")
    | Error (D.Movement.Zero_quantity { position } :: _) ->
        err ~field:Field_amount ~raw:"zero-quantity"
          (format_message "Posting %d is zero. Enter a nonzero amount." position)
    | Error (D.Movement.Measure_mismatch { position; expected; actual } :: _) ->
        err ~field:Field_currency ~raw:"measure-mismatch"
          (format_message "Posting %d Measure (%s) differs from the other postings (%s)." position
             (D.Identifier.Measure.to_string actual)
             (D.Identifier.Measure.to_string expected))
    | Error (D.Movement.Unbalanced { measure = _; residual = _ } :: _) ->
        err ~field:Field_amount ~raw:"unbalanced-movement"
          (tr "The signed postings are unbalanced; their exact sum must be zero.")
    | Error [] -> err ~raw:"invalid-movement" (tr "Invalid Movement structure.")
    | Ok _ -> (
        let memo =
          match mode with
          | Edit e when Option.value ~default:"" e.memo = memo_str -> e.memo
          | New | Pay _ | Edit _ | Plan_new | Plan_edit _ ->
              if memo_str = "" then None else Some memo_str
        in
        let entry, replace, plan =
          match mode with
          | Edit e -> ({ e with day; memo; effects }, true, None)
          | New | Pay _ | Plan_new | Plan_edit _ ->
              ( { B.id = new_id (); day; memo; effects; reversal_of = None; exchange = None; original_amount; merchant = None },
                false,
                match mode with Pay id -> Some id | New | Edit _ | Plan_new | Plan_edit _ -> None )
        in
        match B.put_entry book ~replace entry ~plan with
        | Ok _ -> Ok { entry; replace; plan }
        | Error "duplicate-entry" ->
            err ~raw:"duplicate-entry"
              (format_message "The Actual ID already exists (ID: %s)." entry.id)
        | Error "measure-scale-not-supplied" ->
            err ~field:Field_currency ~raw:"measure-scale-not-supplied"
              (tr "The Measure scale is not supplied in this book.")
        | Error "locus-unapproved" ->
            err ~raw:"locus-unapproved" (tr "A Locus is not admitted by the current book.")
        | Error "plan-already-paid" ->
            err ~raw:"plan-already-paid" (tr "This Scheduled occurrence is already completed.")
        | Error "plan-cancelled" ->
            err ~raw:"plan-cancelled" (tr "This Scheduled occurrence is cancelled.")
        | Error "unknown-plan" ->
            err ~raw:"unknown-plan" (tr "The Scheduled occurrence is unavailable.")
        | Error "entry-admission" ->
            (* Date has already been proven valid via Actual_validity.valid_date.
               Therefore this refusal represents a ledger event admission requirement
               (e.g. zero quantity, imbalance, or invalid relation/reversal), NOT a date error. *)
            err ~raw:"entry-admission"
              (tr
                 "Movement admission refused (entry-admission); check conservation and \
                  relationships.")
        | Error why -> err ~raw:why (format_message "Record refused (%s). Review the draft." why)))
  in
  match content with
  | Single form -> (
      match normalize_date form.day with
      | Error _ ->
          err ~field:Field_date ~raw:"invalid-date"
            (tr "Enter a valid Gregorian date (YYYY-MM-DD, YYYY/MM/DD or YYYY.MM.DD).")
      | Ok canon_day -> (
          if not (is_valid_canonical_date canon_day) then
            err ~field:Field_date ~raw:"invalid-date" (tr "Enter a real Gregorian date.")
          else if String.equal form.from_locus "" then
            err ~field:Field_source ~raw:"empty-source-locus"
              (tr "Select the negative posting Locus.")
          else if String.equal form.to_locus "" then
            err ~field:Field_destination ~raw:"empty-destination-locus"
              (tr "Select the positive posting Locus.")
          else if String.equal form.from_locus form.to_locus then
            err ~field:Field_destination ~raw:"same-locus"
              (format_message "The two posting Loci must differ (%s)."
                 (B.label book form.from_locus))
          else if String.equal form.amount "" then
            err ~field:Field_amount ~raw:"empty-amount"
              (tr "Enter an amount (for example 1000 or 1,000).")
          else
            match B.parse_amount book form.measure form.amount with
            | Error "invalid-amount" ->
                err ~field:Field_amount ~raw:"invalid-amount"
                  (tr "Invalid amount; enter an exact decimal such as 1000 or 1,000.")
            | Error "non-positive-amount" ->
                err ~field:Field_amount ~raw:"non-positive-amount"
                  (tr "The amount magnitude must be greater than zero.")
            | Error "amount-precision" ->
                let scale = try List.assoc form.measure (B.measures book) with Not_found -> 0 in
                let exp =
                  if scale = 0 then tr "integer amounts only"
                  else format_message "at most %d decimal places" scale
                in
                err ~field:Field_amount ~raw:"amount-precision"
                  (format_message "The amount exceeds Measure %s precision (%s)." form.measure exp)
            | Error "division-by-zero" ->
                err ~field:Field_amount ~raw:"division-by-zero"
                  (tr "The amount expression divides by zero.")
            | Error "indivisible-amount" ->
                err ~field:Field_amount ~raw:"indivisible-amount"
                  (tr "The result cannot be represented at this Measure's decimal scale.")
            | Error why ->
                err ~field:Field_amount ~raw:why (format_message "Invalid amount (%s)." why)
            | Ok amount -> (
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
                      | New | Pay _ | Plan_new | Plan_edit _ ->
                          [ effect_ form.from_locus (Z.neg amount); effect_ form.to_locus amount ]
                    in
                    Ok effects
                  with Refused why -> Error why
                in
                match effects_res with
                | Error why -> err ~raw:why (format_message "Invalid Locus (%s)." why)
                | Ok effects -> validate_and_put ~day:canon_day ~memo_str:form.memo ~effects ~original_amount:None)))
  | Multiple { day; memo = memo_str; draft; original_amount } -> (
      match normalize_date day with
      | Error _ ->
          err ~field:Field_date ~raw:"invalid-date"
            (tr "Enter a valid Gregorian date (YYYY-MM-DD, YYYY/MM/DD or YYYY.MM.DD).")
      | Ok canon_day -> (
          if not (is_valid_canonical_date canon_day) then
            err ~field:Field_date ~raw:"invalid-date" (tr "Enter a real Gregorian date.")
          else
            match R.effects book draft with
            | Error "posting-required" ->
                err ~raw:"posting-required" (tr "At least one posting is required.")
            | Error "empty-measure" ->
                err ~field:Field_currency ~raw:"empty-measure" (tr "A Measure is required.")
            | Error why when Base.String.is_substring why ~substring:"invalid-amount" ->
                err ~raw:why (format_message "%s. Enter a valid exact decimal amount." why)
            | Error why when Base.String.is_substring why ~substring:"non-positive-amount" ->
                err ~raw:why (format_message "%s. Enter a positive amount magnitude." why)
            | Error why when Base.String.is_substring why ~substring:"amount-precision" ->
                err ~raw:why (format_message "%s. Check the Measure decimal scale." why)
            | Error why when Base.String.is_substring why ~substring:"division-by-zero"
                          || Base.String.is_substring why ~substring:"indivisible-amount" ->
                err ~raw:why (R.format_residual_error why)
            | Error why when Base.String.is_substring why ~substring:"empty-locus" ->
                err ~raw:why (format_message "%s. Select an admitted Locus." why)
            | Error why -> err ~raw:why (format_message "Invalid postings (%s)." why)
            | Ok effects -> validate_and_put ~day:canon_day ~memo_str ~effects ~original_amount))

let build_plan ~new_id ~book ~mode ~day ~draft : (B.plan * bool, transaction_error) result =
  let err ?field ~raw message = Error { message; field; raw_cause = raw } in
  match normalize_date day with
  | Error _ ->
      err ~field:Field_date ~raw:"invalid-date"
        (tr "Enter a valid Gregorian date (YYYY-MM-DD, YYYY/MM/DD or YYYY.MM.DD).")
  | Ok canon_day -> (
      if not (is_valid_canonical_date canon_day) then
        err ~field:Field_date ~raw:"invalid-date" (tr "Enter a real Gregorian date.")
      else
        match R.effects book draft with
        | Error "posting-required" ->
            err ~raw:"posting-required" (tr "At least one posting is required.")
        | Error "empty-measure" ->
            err ~field:Field_currency ~raw:"empty-measure" (tr "A Measure is required.")
        | Error why when Base.String.is_substring why ~substring:"invalid-amount" ->
            err ~raw:why (format_message "%s. Enter a valid exact decimal amount." why)
        | Error why when Base.String.is_substring why ~substring:"non-positive-amount" ->
            err ~raw:why (format_message "%s. Enter a positive amount magnitude." why)
        | Error why when Base.String.is_substring why ~substring:"amount-precision" ->
            err ~raw:why (format_message "%s. Check the Measure decimal scale." why)
        | Error why when Base.String.is_substring why ~substring:"division-by-zero"
                      || Base.String.is_substring why ~substring:"indivisible-amount" ->
            err ~raw:why (R.format_residual_error why)
        | Error why when Base.String.is_substring why ~substring:"empty-locus" ->
            err ~raw:why (format_message "%s. Select an admitted Locus." why)
        | Error why -> err ~raw:why (format_message "Invalid postings (%s)." why)
        | Ok effects -> (
            match D.Movement.validate effects with
            | Error (D.Movement.Empty :: _) ->
                err ~raw:"empty-movement" (tr "At least one posting is required.")
            | Error (D.Movement.Zero_quantity { position } :: _) ->
                err ~field:Field_amount ~raw:"zero-quantity"
                  (format_message "Posting %d is zero. Enter a nonzero amount." position)
            | Error (D.Movement.Measure_mismatch { position; expected; actual } :: _) ->
                err ~field:Field_currency ~raw:"measure-mismatch"
                  (format_message "Posting %d Measure (%s) differs from the other postings (%s)." position
                     (D.Identifier.Measure.to_string actual)
                     (D.Identifier.Measure.to_string expected))
            | Error (D.Movement.Unbalanced { measure = _; residual = _ } :: _) ->
                err ~field:Field_amount ~raw:"unbalanced-movement"
                  (tr "The signed postings are unbalanced; their exact sum must be zero.")
            | Error [] -> err ~raw:"invalid-movement" (tr "Invalid Movement structure.")
            | Ok _ ->
                let changes =
                  List.map (fun e -> (lstr (D.Effect.locus e), quanta e)) effects
                in
                let plan, replace =
                  match mode with
                  | Plan_edit p ->
                      ({ p with day = canon_day; measure = draft.R.measure; changes }, true)
                  | Plan_new ->
                      ( {
                          B.id = new_id ();
                          day = canon_day;
                          measure = draft.R.measure;
                          changes;
                          paid_by = None;
                          cancelled_on = None;
                        },
                        false )
                  | New | Edit _ | Pay _ ->
                      failwith "unexpected mode for build_plan"
                in
                match B.put_plan book ~replace plan with
                | Ok _ -> Ok (plan, replace)
                | Error "duplicate-plan" ->
                    err ~raw:"duplicate-plan"
                      (format_message "The Scheduled ID already exists (ID: %s)." plan.id)
                | Error "unknown-plan" ->
                    err ~raw:"unknown-plan" (tr "The Scheduled occurrence is unavailable.")
                | Error "plan-already-paid" ->
                    err ~raw:"plan-already-paid" (tr "This Scheduled occurrence is already completed.")
                | Error "plan-cancelled" ->
                    err ~raw:"plan-cancelled" (tr "This Scheduled occurrence is cancelled.")
                | Error "locus-unapproved" ->
                    err ~raw:"locus-unapproved" (tr "A Locus is not admitted by the current book.")
                | Error why ->
                    err ~raw:why (format_message "Scheduled refused (%s). Review the draft." why)))

