(** The detail lines of Actual entries, Scheduled plans and Previews on screen.
    [Book_display] (cli/) owns exact quantities, grouped amounts and Locus candidates.
    Read-only; nothing here publishes. *)

module B = Bakhlo_household.Book

val quantity : book:B.t -> measure:string -> string -> string
(** [Book_display.quantity_value] as text: the Measure's exact decimals, or "Unknown". *)

val entry_lines : B.t -> B.entry -> string list
(** Every Effect with its exact quantity and key, then the entry's facts and the
    Scheduled occurrences it completed. *)

val plan_lines : B.t -> B.plan -> string list
(** Every expected Effect, the due day, IDs and whether it is open, cancelled or
    completed. *)

val preview_rows : B.t -> Bakhlo_household.Record.transaction -> (Ui_render.style * string) list
(** What saving the transaction publishes: new, correction or Scheduled completion,
    then [entry_lines] and the balanced total. Styles come from the book fields;
    exact quantities/dates lead, identities and headings recede. *)

val plan_preview_rows : B.t -> replace:bool -> B.plan -> (Ui_render.style * string) list
(** What saving the plan publishes: new or same-ID edit, then [plan_lines] and the
    balanced total, with the same field-owned hierarchy. *)
