(* Screen messages for the core Record rules. *)
module B = Bakhlo_household.Book
module R = Bakhlo_household.Record

let tr = Ui_text.tr
let format_message = Ui_text.format_message

let coordinate ~locus ~measure : (B.coordinate, string) result =
  if locus = "" || measure = "" then Error "A balance coordinate needs a Locus and a Measure."
  else Ok { locus; measure }

type payload = Entry_tx of R.transaction | Plan_tx of { plan : B.plan; replace : bool }
type transaction_error = { message : string }

let edit_refusal ~book entry =
  Option.map
    (function
      | "linked-entry" -> tr "Entries with Exchange or Reversal links cannot be edited here."
      | "single-measure-movement-required" ->
          tr "Only ordinary single-Measure Movements can be edited here."
      | "measure-scale-not-supplied" ->
          tr "The Measure scale is not supplied; editing is unavailable."
      | why -> format_message "Multi-posting edit refused (%s)" why)
    (R.edit_refusal ~book entry)

let posting_message why =
  let has fragment = Base.String.is_substring why ~substring:fragment in
  match why with
  | "posting-required" -> tr "At least one posting is required."
  | "empty-measure" -> tr "A Measure is required."
  | _ when has "invalid-amount" -> format_message "%s. Enter a valid exact decimal amount." why
  | _ when has "non-positive-amount" -> format_message "%s. Enter a positive amount magnitude." why
  | _ when has "amount-precision" -> format_message "%s. Check the Measure decimal scale." why
  | _ when has "division-by-zero" || has "indivisible-amount" ->
      Posting_draft.format_residual_error why
  | _ when has "empty-locus" -> format_message "%s. Select an admitted Locus." why
  | _ -> format_message "Invalid postings (%s)." why

let message ~plan = function
  | R.Day_format -> tr "Enter a valid Gregorian date (YYYY-MM-DD, YYYY/MM/DD or YYYY.MM.DD)."
  | R.Day_invalid -> tr "Enter a real Gregorian date."
  | R.Postings why -> posting_message why
  | R.Movement R.Empty -> tr "At least one posting is required."
  | R.Movement (R.Zero position) ->
      format_message "Posting %d is zero. Enter a nonzero amount." position
  | R.Movement (R.Measure_differs { position; expected; actual }) ->
      format_message "Posting %d Measure (%s) differs from the other postings (%s)." position actual
        expected
  | R.Movement R.Unbalanced ->
      tr "The signed postings are unbalanced; their exact sum must be zero."
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
      | why when (not plan) && String.starts_with ~prefix:"entry-admission" why ->
          tr "Movement admission refused (entry-admission); check conservation and relationships."
      | why ->
          if plan then format_message "Scheduled refused (%s). Review the draft." why
          else format_message "Record refused (%s). Review the draft." why)

let build_transaction ~new_id ~book ~mode content =
  Result.map_error
    (fun why -> { message = message ~plan:false why })
    (R.build_transaction ~new_id ~book ~mode content)

let build_plan ~new_id ~book ~mode ~day ~draft =
  Result.map_error
    (fun why -> { message = message ~plan:true why })
    (R.build_plan ~new_id ~book ~mode ~day ~draft)
