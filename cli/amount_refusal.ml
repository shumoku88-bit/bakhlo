(* Why an amount was not taken.

   Every place that reads an amount (bk r, bk fx, the Record, Exchange,
   Settlements, Observe, bulk plan amounts) hands the text to the core
   (household/amount.ml), which answers with an exact quantity or a short code
   such as "amount-precision". This module turns that code into the sentence the
   household reads, the same everywhere. Before 2026-11-13 each screen had its
   own words: "Amount must be positive.", "Enter a positive amount magnitude."
   and "Source amount must be positive." meant one thing, and two screens showed
   the bare code.

   A sentence names the box the amount was typed in, then says what to do, with
   the Measure's real limits rather than a general rule:

     Amount: must be more than zero.
     Original amount: ils takes at most 2 decimal places.
     Source amount: jpy takes no decimal places.
     Row 2 amount: the result is not a whole 1 jpy; nothing is rounded.
     Destination amount: the book has no Measure gbp.

   A balance that was seen (Observe, bk check) is a signed amount without
   arithmetic, so its typing mistake is shown with a sign instead
   ([~signed:true]):

     Balance: write digits like 12,345 or -500.

   The examples run in cli/test (amount-refusals-name-the-field-and-the-limit). *)
module B = Bakhlo_household.Book

(* The smallest unit a Measure can hold, as the household would write it:
   1 jpy at scale 0, 0.01 ils at scale 2. *)
let smallest book measure = B.format book measure Z.one ^ " " ^ measure

let say ~book ~measure ?(field = "Amount") ?(signed = false) why =
  let scale = List.assoc_opt measure (B.measures book) in
  let reason =
    match (why, scale) with
    | ("unknown-measure" | "measure-scale-not-supplied"), _ | _, None ->
        "the book has no Measure " ^ measure
    | "empty-amount", _ -> "enter an amount"
    | ("invalid-amount" | "invalid-integer"), _ when signed -> "write digits like 12,345 or -500"
    | ("invalid-amount" | "invalid-integer"), _ ->
        "write digits like 1,200 or 12.50, or arithmetic like (500+300)/2"
    | "non-positive-amount", _ -> "must be more than zero"
    | "amount-precision", Some 0 -> measure ^ " takes no decimal places"
    | "amount-precision", Some scale ->
        Printf.sprintf "%s takes at most %d decimal places" measure scale
    | "division-by-zero", _ -> "the arithmetic divides by zero"
    | "indivisible-amount", Some _ ->
        "the result is not a whole " ^ smallest book measure ^ "; nothing is rounded"
    | why, _ -> "not taken (" ^ why ^ ")"
  in
  field ^ ": " ^ reason ^ "."
