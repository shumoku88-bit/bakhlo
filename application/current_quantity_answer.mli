(* Only the supplied support FAMILY, not its Event witness, amount decomposition or cut. *)
type premise = Zero_origin | Opening | Current_assertion
type exact
type present
type outcome = Exact of exact | Known_present of present

type unavailable = Current_quantity_query.unavailable =
  | Support_unknown of { coordinate : Bakhlo_domain.Effect_coordinate.t }

type answer = (outcome, unavailable) result

val project : (Current_quantity_query.outcome, Current_quantity_query.unavailable) result -> answer
(** Trusted assembly projects ONE existing quantity-query outcome. No lookup, arithmetic,
    admission, inferred support or changed meaning. Exact signed Quantity/coordinate and
    support family survive; presence stays scalar-free and unsupported stays unsupported.
    Payloads are independent values, not aliases/backreferences to raw answers or images.
    A recipient of ONLY this answer has no source/cut/Effect/history accessor through it.
    Full evidence is retained by the original engine/owner, not deleted by projection.
    This is not authorization, safe serialization, a sandbox or a household-truth claim;
    a future host must separately authorize the question and acquire a coherent generation.
    Even the permitted quantity and coordinate can contain sensitive information. *)

val coordinate : exact -> Bakhlo_domain.Effect_coordinate.t
val quantity : exact -> Bakhlo_domain.Quantity.t
val premise : exact -> premise
val present_coordinate : present -> Bakhlo_domain.Effect_coordinate.t
