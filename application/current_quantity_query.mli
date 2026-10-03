(** Two separated support families over ONE admitted ordinary base Actual source.
    Not full normalized admission, opening/presence routing, history or authority. *)
type t
type error =
  | Zero_origins of Loam_domain.Zero_origin_coverage.error
  | Groups of Current_quantity_groups.error
  | Overlapping_support of
      { coordinate : Loam_domain.Effect_coordinate.t
      ; group_position : int; assertion_position : int }
type unavailable = Support_unknown of { coordinate : Loam_domain.Effect_coordinate.t }
type answer
type premise = Zero_origin | Current_assertion of Current_quantity_projection.answer

(** Qualify zero declarations, then whole exact-group image against [source], then
    scan group/assertion order for cross-family overlap (even equal quantities).
    Global refusal; no partial result or family priority. Zero-origin uses ALL ordinary
    frontier Events, while each assertion keeps its own cut. Never Movement-coerce,
    merge cuts, infer origin from activity, or combine separately bound projections. *)
val create
  : source:Actual_source.t
  -> zero_origins:Loam_domain.Effect_coordinate.t list
  -> groups:Current_quantity_groups.group list
  -> (t, error) result
val source : t -> Actual_source.t
val zero_origins : t -> Loam_domain.Effect_coordinate.t list
val source_groups : t -> Current_quantity_groups.t

(** Support gate then indexed arithmetic/ownership lookup; no traversal or I/O.
    Missing support stays unknown even with activity/net zero/empty source. *)
val query : t -> Loam_domain.Effect_coordinate.t -> (answer, unavailable) result
val coordinate : answer -> Loam_domain.Effect_coordinate.t
val quantity : answer -> Loam_domain.Quantity.t
val premise : answer -> premise
