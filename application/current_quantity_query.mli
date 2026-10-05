(** Four separated support families over ONE admitted Actual subset source.
    Not full normalized admission, historical completeness or household authority. *)
type opening =
  { coordinate : Bakhlo_domain.Effect_coordinate.t
  ; opening_event : Bakhlo_domain.Identifier.Event.t
  }

(** One independent nonzero/amount-unknown observation with a shared cut; no scalar/date. *)
type presence =
  { reflected_roots : Bakhlo_domain.Identifier.Event.t list
  ; coordinates : Bakhlo_domain.Effect_coordinate.t list
  }
type t
type error =
  | Zero_origins of Bakhlo_domain.Zero_origin_coverage.error
  | Duplicate_opening_coordinate of
      { coordinate : Bakhlo_domain.Effect_coordinate.t; first_position : int; position : int }
  | Opening_event_not_current of { opening : opening; position : int }
  | Opening_event_missing_coordinate of { opening : opening; position : int }
  | Groups of Current_quantity_groups.error
  | Presence_cut of Reflected_root_cut.error
  | Duplicate_presence_coordinate of
      { coordinate : Bakhlo_domain.Effect_coordinate.t; first_position : int; position : int }
  | Opening_overlaps_origin of
      { coordinate : Bakhlo_domain.Effect_coordinate.t; opening_position : int }
  | Assertion_overlaps_origin of
      { coordinate : Bakhlo_domain.Effect_coordinate.t; group_position : int; assertion_position : int }
  | Assertion_overlaps_opening of
      { opening : opening; group_position : int; assertion_position : int }
  | Presence_overlaps_exact of { coordinate : Bakhlo_domain.Effect_coordinate.t; position : int }
type unavailable = Support_unknown of { coordinate : Bakhlo_domain.Effect_coordinate.t }
type exact
type present
type premise = Zero_origin | Opening of opening | Current_assertion of Current_quantity_projection.answer
type outcome = Exact of exact | Known_present of present

(** Qualify origins, whole openings, whole groups, then presence cut/unique coordinates.
    Openings require unique coordinates (duplicate first), a CURRENT terminal Event
    and a matching Effect; never silently retarget superseded witnesses.
    Presence roots qualify even with no coordinates; [None] means no presence evidence.
    Then scan opening/origin overlap, group/assertion overlap and presence/exact overlap
    in declaration order. All positions one-based. Stale presence also refuses overlap;
    global admission, no partial result or family priority, even for equal quantities.
    Origin/opening sum ALL qualified terminals, not just a witness; assertions keep their
    independent cuts. Presence is not arithmetic: ANY matching Effect in its remaining
    terminals invalidates it, even when contributions cancel. No inferred support,
    merged cuts, second opening scalar/date or separately bound source projections. *)
val create
  : source:Actual_source.t
  -> zero_origins:Bakhlo_domain.Effect_coordinate.t list
  -> openings:opening list
  -> groups:Current_quantity_groups.group list
  -> presence:presence option
  -> (t, error) result
val source : t -> Actual_source.t
val zero_origins : t -> Bakhlo_domain.Effect_coordinate.t list
val openings : t -> opening list
val source_groups : t -> Current_quantity_groups.t
val presence : t -> presence option

(** Indexed lookup; exact/present payloads are disjoint and abstract. Stale/absent
    support remains unknown, never zero; no traversal, chronology or I/O. *)
val query : t -> Bakhlo_domain.Effect_coordinate.t -> (outcome, unavailable) result
val coordinate : exact -> Bakhlo_domain.Effect_coordinate.t
val quantity : exact -> Bakhlo_domain.Quantity.t
val premise : exact -> premise
val present_coordinate : present -> Bakhlo_domain.Effect_coordinate.t
val present_evidence : present -> presence
val present_cut : present -> Reflected_root_cut.t
