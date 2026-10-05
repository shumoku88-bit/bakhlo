(** Independent Event-scoped commercial-provider evidence: whom the household
    regards as supplying the acquired goods/services. Not payment destination,
    creditor, Effect-level seller, description, amount, support or a party registry. *)
type disposition = Merchant of Bakhlo_domain.Identifier.External_party.t | Nonmerchant

type fact = { event : Bakhlo_domain.Identifier.Event.t; disposition : disposition }
type t

type error =
  | Repeated_disposition of {
      event : Bakhlo_domain.Identifier.Event.t;
      first_position : int;
      position : int;
    }
  | Unknown_merchant_event of { event : Bakhlo_domain.Identifier.Event.t; position : int }

val create : events:Bakhlo_domain.Event_memory.t -> facts:fact list -> (t, error) result
(** Against ONE supplied retained memory, including superseded Events.
    Per-declaration duplicate then reference checks; first failure, one-based positions.
    Even identical dispositions conflict. Missing rows remain unresolved, not Nonmerchant.
    Exact facts/order/source survive; no completeness, truth or correction inheritance. *)

val source_events : t -> Bakhlo_domain.Event_memory.t
val facts : t -> fact list

val find_disposition : t -> Bakhlo_domain.Identifier.Event.t -> disposition option
(** Exact retained-ID lookup: [None] is unresolved, [Some Nonmerchant] explicit.
    No correction traversal, inference from other facts or retargeting. *)
