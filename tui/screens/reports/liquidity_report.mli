(** Liquidity's text: the core's conditional path ({!Bakhlo_household.Liquidity}) in
    the book's money format. *)

val render_lines :
  book:Bakhlo_household.Book.t ->
  Bakhlo_household.Liquidity.snapshot ->
  (Ui_render.style * string) list
(** Full exact Measure-scaled result text; at most 12 point rows plus an
    omitted-count note, while both totals still use every point. *)
