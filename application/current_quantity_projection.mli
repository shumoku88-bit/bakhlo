type assertion = {
  coordinate : Bakhlo_domain.Effect_coordinate.t;
  quantity : Bakhlo_domain.Quantity.t;
}
(** Conditional exact quantity from ONE anonymous reconciliation group: one
    qualified immutable cut and independent exact coordinate assertions. Not
    admitted Actual, reflection truth, zero origin, history, or operational balances.
    Multi-group ownership/support-family routing is NOT provided by this module. *)

type t

type error =
  | Duplicate_coordinate of {
      coordinate : Bakhlo_domain.Effect_coordinate.t;
      first_position : int;
      position : int;
    }

val create : cut:Reflected_root_cut.t -> assertions:assertion list -> (t, error) result
(** First repeated coordinate refuses, even for equal values, with one-based input
    positions. Original assertions/cut are retained. Empty assertions support no
    coordinate; signed/zero/huge assertions are exact premises, not inferred facts.
    Construction materializes asserted + matching unreflected terminal Effects.
    Every Effect occurrence counts, including zero/mixed/nonconserving Events.
    All components use this SAME supplied cut; no raw/new frontier can enter query. *)

val source_cut : t -> Reflected_root_cut.t
val assertions : t -> assertion list
val with_added_effects : t -> Bakhlo_domain.Effect.t list -> t

type answer
type unavailable = Assertion_unknown of { coordinate : Bakhlo_domain.Effect_coordinate.t }

val query : t -> Bakhlo_domain.Effect_coordinate.t -> (answer, unavailable) result
(** Independent assertion gate and indexed answer lookup. Unsupported remains
    unknown regardless of activity/net-zero/empty/all-reflected source. Queries
    do not traverse evidence, revalidate, aggregate, format, mutate, or read time.
    To reuse premises with changed source, explicitly construct a new checked cut
    and model; caller still owns truth/compatibility and full Actual selection. *)

val coordinate : answer -> Bakhlo_domain.Effect_coordinate.t
val asserted_quantity : answer -> Bakhlo_domain.Quantity.t
val delta : answer -> Bakhlo_domain.Quantity.t
val quantity : answer -> Bakhlo_domain.Quantity.t

val answer_cut : answer -> Reflected_root_cut.t
(** SAME admitted cut used to build this answer's delta, retained with the answer.
    Explanation consumers cannot accidentally pair an answer with another group's
    cut or silently merge cuts. This is provenance, not newly observed evidence. *)
