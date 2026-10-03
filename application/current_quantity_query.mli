(** Three separated support families over ONE admitted ordinary base Actual source.
    Not full normalized admission, presence routing, history or household authority. *)
type opening =
  { coordinate : Loam_domain.Effect_coordinate.t
  ; opening_event : Loam_domain.Identifier.Event.t
  }
type t
type error =
  | Zero_origins of Loam_domain.Zero_origin_coverage.error
  | Duplicate_opening_coordinate of
      { coordinate : Loam_domain.Effect_coordinate.t; first_position : int; position : int }
  | Opening_event_not_current of { opening : opening; position : int }
  | Opening_event_missing_coordinate of { opening : opening; position : int }
  | Groups of Current_quantity_groups.error
  | Opening_overlaps_origin of
      { coordinate : Loam_domain.Effect_coordinate.t; opening_position : int }
  | Assertion_overlaps_origin of
      { coordinate : Loam_domain.Effect_coordinate.t; group_position : int; assertion_position : int }
  | Assertion_overlaps_opening of
      { opening : opening; group_position : int; assertion_position : int }
type unavailable = Support_unknown of { coordinate : Loam_domain.Effect_coordinate.t }
type answer
type premise = Zero_origin | Opening of opening | Current_assertion of Current_quantity_projection.answer

(** Qualify origins, the whole opening relation, then whole groups against [source].
    Opening declarations require unique coordinates (duplicate checked first), a CURRENT
    terminal Event and at least one matching Effect. Retained superseded Events refuse;
    neither identity/date order nor corrections silently retarget a declaration.
    Then scan opening/origin overlap in declaration order, followed by group/assertion
    overlap with origin/opening. All positions one-based. Global refusal even for equal
    quantities/unrelated queries; no partial result or family priority.
    Origin/opening sum ALL ordinary frontier Events, not just an opening witness;
    each assertion keeps its own cut. No second opening scalar/date/cut, Movement
    coercion, merged cuts, inferred support or separately bound projections. *)
val create
  : source:Actual_source.t
  -> zero_origins:Loam_domain.Effect_coordinate.t list
  -> openings:opening list
  -> groups:Current_quantity_groups.group list
  -> (t, error) result
val source : t -> Actual_source.t
val zero_origins : t -> Loam_domain.Effect_coordinate.t list
val openings : t -> opening list
val source_groups : t -> Current_quantity_groups.t

(** Support gate then indexed arithmetic/ownership lookup; no traversal or I/O.
    Missing support stays unknown even with activity/net zero/empty source. *)
val query : t -> Loam_domain.Effect_coordinate.t -> (answer, unavailable) result
val coordinate : answer -> Loam_domain.Effect_coordinate.t
val quantity : answer -> Loam_domain.Quantity.t
val premise : answer -> premise
