type fact = {
  target : Bakhlo_domain.Identifier.Event.t;
  reversal : Bakhlo_domain.Identifier.Event.t;
}
(** Explicit correspondence between retained Events, NOT correction/deletion or
    inference from net zero. Absence is unresolved, not proof of no reversal. *)

type role = Target | Reversal
type endpoint = { role : role; event : Bakhlo_domain.Identifier.Event.t }

type error =
  | Repeated_endpoint of {
      event : Bakhlo_domain.Identifier.Event.t;
      first_role : role;
      first_position : int;
      role : role;
      position : int;
    }
  | Unresolved_endpoints of { position : int; endpoints : endpoint list }
  | Not_inverse of { position : int; fact : fact }

type t
type pair

val create : events:Bakhlo_domain.Event_memory.t -> facts:fact list -> (t, error) result
(** Per fact: target reuse -> reversal reuse (including self) -> ordered closure
    -> exact physical multiset inversion. Endpoints are globally disjoint across
    BOTH roles, so chains/cycles/identical duplicate facts refuse. Physical matching
    preserves Locus, Measure, exact signed quantities and occurrence multiplicity;
    ignores keys/order. Empty pairs allowed. One-based fact positions, declaration
    order retained. No nonzero/balance/date/currentness/correction gate here:
    Actual_source must qualify targets independently before admitting reversal sides
    (ordinary balance is derived; Exchange inverses remain explicit exceptions). These facts do not select frontier Events, cuts or support. *)

val source_events : t -> Bakhlo_domain.Event_memory.t
val facts : t -> fact list
val pairs : t -> pair list
val fact : pair -> fact
val target_event : pair -> Bakhlo_domain.Event.t
val reversal_event : pair -> Bakhlo_domain.Event.t
val find_by_target : t -> Bakhlo_domain.Identifier.Event.t -> pair option
val find_by_reversal : t -> Bakhlo_domain.Identifier.Event.t -> pair option
