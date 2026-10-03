(** Independent base Actual occurrence evidence, not an Event field, chronology,
    validity history or proof that an observation really occurred. ISO calendar
    validation belongs to this practical entrance; original strings/order retained. *)
type fact = { event : Loam_domain.Identifier.Event.t; valid_on : string }
type t
type error =
  | Invalid_date of { position : int; text : string }
  | Repeated_validity of
      { event : Loam_domain.Identifier.Event.t; first_position : int; position : int }
  | Unknown_validity_event of { event : Loam_domain.Identifier.Event.t; position : int }
  | Missing_validity of { event : Loam_domain.Identifier.Event.t }

(** Declaration-order date/duplicate/reference checks, then Event-order completeness.
    Exactly one base fact for EVERY supplied retained Event, including superseded ones.
    Does not admit Effect shape or correction frontier. Positions are one-based. *)
val create : events:Loam_domain.Event_memory.t -> facts:fact list -> (t, error) result
val facts : t -> fact list
