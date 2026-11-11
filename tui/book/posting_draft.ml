(* Screen wording for exact-amount and remainder refusals. *)
let tr = Ui_text.tr

let format_residual_error why =
  if String.equal why "posting-required" then tr "At least one posting is required."
  else
    let line_prefix =
      if Base.String.is_prefix why ~prefix:"row-" then
        match String.index_opt why ':' with Some idx -> String.sub why 0 idx ^ ": " | None -> ""
      else ""
    in
    if Base.String.is_substring why ~substring:"invalid-amount" then
      line_prefix ^ tr "Invalid amount (for example 1000)."
    else if Base.String.is_substring why ~substring:"non-positive-amount" then
      line_prefix ^ tr "Enter a positive amount magnitude."
    else if Base.String.is_substring why ~substring:"amount-precision" then
      line_prefix ^ tr "The amount exceeds the Measure decimal scale."
    else if Base.String.is_substring why ~substring:"division-by-zero" then
      line_prefix ^ tr "The amount expression divides by zero."
    else if Base.String.is_substring why ~substring:"indivisible-amount" then
      line_prefix ^ tr "The result cannot be represented at this Measure's decimal scale."
    else why
