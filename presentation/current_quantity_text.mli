val event_refusal : Loam_domain.Identifier.Event.t -> Loam_domain.Event.error -> string
val source_refusal : Loam_application.Actual_source.error -> string
val answer : Loam_application.Current_quantity_query.exact -> string
val present : Loam_application.Current_quantity_query.present -> string
val unavailable : Loam_application.Current_quantity_query.unavailable -> string
val refusal : Loam_application.Current_quantity_query.error -> string
