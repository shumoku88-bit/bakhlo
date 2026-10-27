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
type payload = Entry_tx of transaction | Plan_tx of { plan : B.plan; replace : bool }

type draft_content =
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

(* Why the Record editor cannot correct this entry, if it cannot. *)
let edit_refusal ~book (e : B.entry) =
  if
    e.exchange <> None || e.reversal_of <> None
    || List.exists (fun (row : B.entry) -> row.reversal_of = Some e.id) (B.entries book)
  then Some (tr "Entries with Exchange or Reversal links cannot be edited here.")
  else
    match pair e.effects with
    | Some _ -> None
    | None -> (
        match R.of_effects book e.effects with
        | Ok _ -> None
        | Error "single-measure-movement-required" ->
            Some (tr "Only ordinary single-Measure Movements can be edited here.")
        | Error "measure-scale-not-supplied" ->
            Some (tr "The Measure scale is not supplied; editing is unavailable.")
        | Error why -> Some (format_message "Multi-posting edit refused (%s)" why))

type transaction_error = { message : string }

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

let is_valid_canonical_date day = Bakhlo_book_txt.Book_txt.valid_date day
let refuse message = Error { message }
let ( let* ) = Result.bind

let canonical_day day =
  match normalize_date day with
  | Error _ -> refuse (tr "Enter a valid Gregorian date (YYYY-MM-DD, YYYY/MM/DD or YYYY.MM.DD).")
  | Ok day when not (is_valid_canonical_date day) -> refuse (tr "Enter a real Gregorian date.")
  | Ok day -> Ok day

let draft_effects ~book draft =
  let has why fragment = Base.String.is_substring why ~substring:fragment in
  match R.effects book draft with
  | Ok effects -> Ok effects
  | Error "posting-required" -> refuse (tr "At least one posting is required.")
  | Error "empty-measure" -> refuse (tr "A Measure is required.")
  | Error why when has why "invalid-amount" ->
      refuse (format_message "%s. Enter a valid exact decimal amount." why)
  | Error why when has why "non-positive-amount" ->
      refuse (format_message "%s. Enter a positive amount magnitude." why)
  | Error why when has why "amount-precision" ->
      refuse (format_message "%s. Check the Measure decimal scale." why)
  | Error why when has why "division-by-zero" || has why "indivisible-amount" ->
      refuse (R.format_residual_error why)
  | Error why when has why "empty-locus" ->
      refuse (format_message "%s. Select an admitted Locus." why)
  | Error why -> refuse (format_message "Invalid postings (%s)." why)

let balanced effects =
  match D.Movement.validate effects with
  | Ok _ -> Ok ()
  | Error (D.Movement.Empty :: _) -> refuse (tr "At least one posting is required.")
  | Error (D.Movement.Zero_quantity { position } :: _) ->
      refuse (format_message "Posting %d is zero. Enter a nonzero amount." position)
  | Error (D.Movement.Measure_mismatch { position; expected; actual } :: _) ->
      refuse
        (format_message "Posting %d Measure (%s) differs from the other postings (%s)." position
           (D.Identifier.Measure.to_string actual)
           (D.Identifier.Measure.to_string expected))
  | Error (D.Movement.Unbalanced { measure = _; residual = _ } :: _) ->
      refuse (tr "The signed postings are unbalanced; their exact sum must be zero.")
  | Error [] -> refuse (tr "Invalid Movement structure.")

let build_transaction ~new_id ~book ~mode
    (Multiple { day; memo = memo_str; draft; original_amount }) :
    (transaction, transaction_error) result =
  let* day = canonical_day day in
  let* effects = draft_effects ~book draft in
  let* () =
    match original_amount with
    | Some (m, _) when not (List.mem_assoc m (B.measures book)) ->
        refuse (tr "The Measure scale is not supplied in this book.")
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
  | Error "duplicate-entry" ->
      refuse (format_message "The Actual ID already exists (ID: %s)." entry.id)
  | Error "measure-scale-not-supplied" ->
      refuse (tr "The Measure scale is not supplied in this book.")
  | Error "locus-unapproved" -> refuse (tr "A Locus is not admitted by the current book.")
  | Error "plan-already-paid" -> refuse (tr "This Scheduled occurrence is already completed.")
  | Error "plan-cancelled" -> refuse (tr "This Scheduled occurrence is cancelled.")
  | Error "unknown-plan" -> refuse (tr "The Scheduled occurrence is unavailable.")
  | Error "entry-admission" ->
      (* The date is already valid, so this is a ledger admission refusal (conservation,
         relation or reversal), not a date error. *)
      refuse
        (tr "Movement admission refused (entry-admission); check conservation and relationships.")
  | Error why -> refuse (format_message "Record refused (%s). Review the draft." why)

let build_plan ~new_id ~book ~mode ~day ~draft : (B.plan * bool, transaction_error) result =
  let* day = canonical_day day in
  let* effects = draft_effects ~book draft in
  let* () = balanced effects in
  let changes = List.map (fun e -> (lstr (D.Effect.locus e), quanta e)) effects in
  let plan, replace =
    match mode with
    | Plan_edit p -> ({ p with day; measure = draft.R.measure; changes }, true)
    | Plan_new ->
        ( {
            B.id = new_id ();
            day;
            measure = draft.R.measure;
            changes;
            paid_by = None;
            cancelled_on = None;
          },
          false )
    | New | Edit _ | Pay _ -> failwith "unexpected mode for build_plan"
  in
  match B.put_plan book ~replace plan with
  | Ok _ -> Ok (plan, replace)
  | Error "duplicate-plan" ->
      refuse (format_message "The Scheduled ID already exists (ID: %s)." plan.id)
  | Error "unknown-plan" -> refuse (tr "The Scheduled occurrence is unavailable.")
  | Error "plan-already-paid" -> refuse (tr "This Scheduled occurrence is already completed.")
  | Error "plan-cancelled" -> refuse (tr "This Scheduled occurrence is cancelled.")
  | Error "locus-unapproved" -> refuse (tr "A Locus is not admitted by the current book.")
  | Error why -> refuse (format_message "Scheduled refused (%s). Review the draft." why)
