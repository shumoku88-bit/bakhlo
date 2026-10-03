(** Conditional exact quantity from ONE anonymous reconciliation group: one
    qualified immutable cut and independent exact coordinate assertions. Not
    admitted Actual, reflection truth, zero origin, history, or operational balances.
    Multi-group ownership/support-family routing is NOT provided by this module. *)
type assertion =
  { coordinate : Loam_domain.Effect_coordinate.t
  ; quantity : Loam_domain.Quantity.t
  }

type t

type error =
  | Duplicate_coordinate of
      { coordinate : Loam_domain.Effect_coordinate.t
      ; first_position : int
      ; position : int
      }

(** First repeated coordinate refuses, even for equal values, with one-based input
    positions. Original assertions/cut are retained. Empty assertions support no
    coordinate; signed/zero/huge assertions are exact premises, not inferred facts.
    Construction materializes asserted + matching unreflected terminal Effects.
    Every Effect occurrence counts, including zero/mixed/nonconserving Events.
    All components use this SAME supplied cut; no raw/new frontier can enter query. *)
val create
  :  cut:Reflected_root_cut.t
  -> assertions:assertion list
  -> (t, error) result

val source_cut : t -> Reflected_root_cut.t
val assertions : t -> assertion list

type answer

type unavailable = Assertion_unknown of { coordinate : Loam_domain.Effect_coordinate.t }

(** Independent assertion gate and indexed answer lookup. Unsupported remains
    unknown regardless of activity/net-zero/empty/all-reflected source. Queries
    do not traverse evidence, revalidate, aggregate, format, mutate, or read time.
    To reuse premises with changed source, explicitly construct a new checked cut
    and model; caller still owns truth/compatibility and full Actual selection. *)
val query : t -> Loam_domain.Effect_coordinate.t -> (answer, unavailable) result

val coordinate : answer -> Loam_domain.Effect_coordinate.t
val asserted_quantity : answer -> Loam_domain.Quantity.t
val delta : answer -> Loam_domain.Quantity.t
val quantity : answer -> Loam_domain.Quantity.t
