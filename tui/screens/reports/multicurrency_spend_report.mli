(** Multicurrency Spend's text: the core's families
    ({!Bakhlo_household.Multicurrency_spend}) in each Measure's money format. *)

val render_lines :
  book:Bakhlo_household.Book.t ->
  Bakhlo_household.Multicurrency_spend.snapshot ->
  (Ui_render.style * string) list
(** Full result text in fixed section order, with every unresolved and non-counted
    witness present and every amount exact and grouped at its own Measure scale.
    Logical lines are unwrapped for the caller to wrap. *)
