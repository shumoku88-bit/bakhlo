(** Pure endpoint closure within one supplied, identity-unique memory.
    NOT correction-frontier admission, an apply operation, or current authority.
    No graph traversal, formatting, mutation, clocks, I/O, or publication. *)

type endpoint = Target | Replacement

type error =
  | Missing_event of
      { endpoint : endpoint
      ; id : Loam_domain.Identifier.Event.t
      }

(** Both named observations and their explicit relation are retained. This type
    only establishes endpoint closure, including for self/cyclic/competing edges. *)
type closed

(** Report missing target before missing replacement; return both if both are
    absent. Refusal lists are nonempty. Each query makes two indexed lookups. *)
val run
  :  events:Loam_domain.Event_memory.t
  -> correction:Loam_domain.Event_correction.t
  -> (closed, error list) result

val correction : closed -> Loam_domain.Event_correction.t
val target_event : closed -> Loam_domain.Event.t
val replacement_event : closed -> Loam_domain.Event.t
