(** Pure endpoint closure within one supplied, identity-unique memory.
    NOT correction-frontier admission, an apply operation, or current authority.
    No graph traversal, formatting, mutation, clocks, I/O, or publication. *)

type endpoint = Target | Replacement
type error = Missing_event of { endpoint : endpoint; id : Bakhlo_domain.Identifier.Event.t }

type closed
(** Both named observations and their explicit relation are retained. This type
    only establishes endpoint closure, including for self/cyclic/competing edges. *)

val run :
  events:Bakhlo_domain.Event_memory.t ->
  correction:Bakhlo_domain.Event_correction.t ->
  (closed, error list) result
(** Report missing target before missing replacement; return both if both are
    absent. Refusal lists are nonempty. Each query makes two indexed lookups. *)

val correction : closed -> Bakhlo_domain.Event_correction.t
val target_event : closed -> Bakhlo_domain.Event.t
val replacement_event : closed -> Bakhlo_domain.Event.t
