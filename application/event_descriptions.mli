(** Optional Event-scoped human recognizer text, not Merchant/Purpose/kind,
    quantity, support or correction priority. No independent description ID.
    Qualified against ONE supplied retained memory, not just its current terminals. *)
type fact = { event : Bakhlo_domain.Identifier.Event.t; text : string }
type t
type error =
  | Repeated_description of
      { event : Bakhlo_domain.Identifier.Event.t; first_position : int; position : int }
  | Unknown_description_event of { event : Bakhlo_domain.Identifier.Event.t; position : int }

(** Per-declaration duplicate then reference checks; first failure, one-based positions.
    Zero or one fact per retained Event; even identical duplicates refuse. No completeness
    or text validation/coercion. Exact text/order retained, including empty/control text.
    This establishes structural association, not truth, chronology or inheritance. *)
val create : events:Bakhlo_domain.Event_memory.t -> facts:fact list -> (t, error) result
val source_events : t -> Bakhlo_domain.Event_memory.t
val facts : t -> fact list

(** Exact retained-ID lookup: absent is [None], supplied empty text is [Some ""].
    No correction traversal, retargeting or fallback from another Event. *)
val find_text : t -> Bakhlo_domain.Identifier.Event.t -> string option
