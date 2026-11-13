(* Screen messages for the core Record rules. *)
module B = Bakhlo_household.Book
module R = Bakhlo_household.Record

let tr message = message
let format_message = Printf.sprintf

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

(* A row refusal names its row, as in "row-2: amount-precision"; an amount
   refusal is worded once, in Amount_refusal. *)
let posting_message ~book ~measure why =
  match why with
  | "posting-required" -> tr "At least one posting is required."
  | "empty-measure" -> tr "A Measure is required."
  | _ -> (
      match (String.starts_with ~prefix:"row-" why, String.index_opt why ':') with
      | true, Some colon -> (
          let row = String.sub why 4 (colon - 4) in
          match String.trim (String.sub why (colon + 1) (String.length why - colon - 1)) with
          | "empty-locus" -> format_message "Row %s: choose an account." row
          | code -> Amount_refusal.say ~book ~measure ~field:("Row " ^ row ^ " amount") code)
      | _ -> format_message "Invalid postings (%s)." why)

let message ~plan ~book ~measure = function
  | R.Day_format -> tr "Enter a valid Gregorian date (YYYY-MM-DD, YYYY/MM/DD or YYYY.MM.DD)."
  | R.Postings why -> posting_message ~book ~measure why
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
    (fun why -> { message = message ~plan:false ~book ~measure:content.R.draft.measure why })
    (R.build_transaction ~new_id ~book ~mode content)

let build_plan ~new_id ~book ~editing ~day ~draft =
  Result.map_error
    (fun why -> { message = message ~plan:true ~book ~measure:draft.R.measure why })
    (R.build_plan ~new_id ~book ~editing ~day ~draft)
