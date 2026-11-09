(* Screen messages for the core Record rules. *)
module B = Bakhlo_household.Book
module R = Bakhlo_household.Record

let tr message = message
let format_message = Printf.sprintf

(* Whether a refusal code mentions a reason, as in "row-2:invalid-amount". *)
let mentions why reason =
  let n = String.length reason in
  let rec at i = i + n <= String.length why && (String.sub why i n = reason || at (i + 1)) in
  at 0

let coordinate ~locus ~measure : (B.coordinate, string) result =
  if locus = "" || measure = "" then Error "A balance coordinate needs a Locus and a Measure."
  else Ok { locus; measure }

type mode = Actual of R.mode | Plan_new | Plan_edit of B.plan
type payload = Entry_tx of R.transaction | Plan_tx of { plan : B.plan; replace : bool }
type transaction_error = { message : string }

let open_edit ~book entry =
  Result.map_error
    (function
      | "linked-entry" -> tr "Entries with Exchange or Reversal links cannot be edited here."
      | "single-measure-movement-required" ->
          tr "Only ordinary single-Measure Movements can be edited here."
      | why -> format_message "Multi-posting edit refused (%s)" why)
    (R.open_edit ~book entry)

let open_plan ~book plan =
  Result.map_error
    (function
      | "plan-already-paid" -> tr "This Scheduled occurrence is already completed."
      | "plan-cancelled" -> tr "This Scheduled occurrence is cancelled."
      | why -> why)
    (R.open_plan ~book plan)

(* Exact-amount and remainder refusals in words. *)
let format_residual_error why =
  if String.equal why "posting-required" then tr "At least one posting is required."
  else
    let line_prefix =
      if String.starts_with ~prefix:"row-" why then
        match String.index_opt why ':' with Some idx -> String.sub why 0 idx ^ ": " | None -> ""
      else ""
    in
    if mentions why "invalid-amount" then line_prefix ^ tr "Invalid amount (for example 1000)."
    else if mentions why "non-positive-amount" then
      line_prefix ^ tr "Enter a positive amount magnitude."
    else if mentions why "amount-precision" then
      line_prefix ^ tr "The amount exceeds the Measure decimal scale."
    else if mentions why "division-by-zero" then
      line_prefix ^ tr "The amount expression divides by zero."
    else if mentions why "indivisible-amount" then
      line_prefix ^ tr "The result cannot be represented at this Measure's decimal scale."
    else why

let posting_message why =
  let has = mentions why in
  match why with
  | "posting-required" -> tr "At least one posting is required."
  | "empty-measure" -> tr "A Measure is required."
  | _ when has "invalid-amount" -> format_message "%s. Enter a valid exact decimal amount." why
  | _ when has "non-positive-amount" -> format_message "%s. Enter a positive amount magnitude." why
  | _ when has "amount-precision" -> format_message "%s. Check the Measure decimal scale." why
  | _ when has "division-by-zero" || has "indivisible-amount" -> format_residual_error why
  | _ when has "empty-locus" -> format_message "%s. Select an admitted Locus." why
  | _ -> format_message "Invalid postings (%s)." why

let message ~plan = function
  | R.Day_format -> tr "Enter a valid Gregorian date (YYYY-MM-DD, YYYY/MM/DD or YYYY.MM.DD)."
  | R.Postings why -> posting_message why
  | R.Unbalanced -> tr "The signed postings are unbalanced; their exact sum must be zero."
  | R.Original_measure -> tr "The Measure scale is not supplied in this book."
  | R.Admission { reason; id } -> (
      match reason with
      | "duplicate-entry" when not plan ->
          format_message "The Actual ID already exists (ID: %s)." id
      | "duplicate-plan" when plan -> format_message "The Scheduled ID already exists (ID: %s)." id
      | "measure-scale-not-supplied" when not plan ->
          tr "The Measure scale is not supplied in this book."
      | "locus-unapproved" -> tr "A Locus is not admitted by the current book."
      | "plan-already-paid" -> tr "This Scheduled occurrence is already completed."
      | "plan-cancelled" -> tr "This Scheduled occurrence is cancelled."
      | "unknown-plan" -> tr "The Scheduled occurrence is unavailable."
      | "merchant-classified" when not plan ->
          tr "This Actual's Merchant is already classified; a correction keeps it."
      | why when (not plan) && String.starts_with ~prefix:"entry-admission" why ->
          tr "Movement admission refused (entry-admission); check conservation and relationships."
      | why ->
          if plan then format_message "Scheduled refused (%s). Review the draft." why
          else format_message "Record refused (%s). Review the draft." why)

let build_transaction ~new_id ~book ~mode content =
  Result.map_error
    (fun why -> { message = message ~plan:false why })
    (R.build_transaction ~new_id ~book ~mode content)

let build_plan ~new_id ~book ~editing ~day ~draft =
  Result.map_error
    (fun why -> { message = message ~plan:true why })
    (R.build_plan ~new_id ~book ~editing ~day ~draft)
