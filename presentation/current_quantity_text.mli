val event_refusal : Bakhlo_domain.Identifier.Event.t -> Bakhlo_domain.Event.error -> string
val source_refusal : Bakhlo_application.Actual_source.error -> string

(** Terminal formatting shared by the fixture and experimental text read shells;
    not a structural operation/wire answer. Each shell names its evidence scope. *)
val exact_row : Bakhlo_application.Current_quantity_query.exact -> string
val answer : Bakhlo_application.Current_quantity_query.exact -> string
val present : Bakhlo_application.Current_quantity_query.present -> string
val unavailable : Bakhlo_application.Current_quantity_query.unavailable -> string
val refusal : Bakhlo_application.Current_quantity_query.error -> string
