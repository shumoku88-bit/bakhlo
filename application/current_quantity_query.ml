open Base
module D = Loam_domain
module H = Current_quantity_groups
module P = Current_quantity_projection
module C = Reflected_root_cut

type opening =
  { coordinate : D.Effect_coordinate.t
  ; opening_event : D.Identifier.Event.t
  }
type presence =
  { reflected_roots : D.Identifier.Event.t list
  ; coordinates : D.Effect_coordinate.t list
  }
type present =
  { coordinate : D.Effect_coordinate.t
  ; evidence : presence
  ; cut : C.t
  }
type t =
  { source : Actual_source.t
  ; zero_origins : D.Effect_coordinate.t list
  ; coverage : D.Zero_origin_coverage.t
  ; openings : opening list
  ; opening_index : (D.Effect_coordinate.t, opening * int, D.Effect_coordinate.comparator_witness) Map.t
  ; presence : presence option
  ; present_index : (D.Effect_coordinate.t, present, D.Effect_coordinate.comparator_witness) Map.t
  ; totals : Effect_sum.t
  ; source_groups : H.t
  }
type error =
  | Zero_origins of D.Zero_origin_coverage.error
  | Duplicate_opening_coordinate of { coordinate : D.Effect_coordinate.t; first_position : int; position : int }
  | Opening_event_not_current of { opening : opening; position : int }
  | Opening_event_missing_coordinate of { opening : opening; position : int }
  | Groups of H.error
  | Presence_cut of C.error
  | Duplicate_presence_coordinate of { coordinate : D.Effect_coordinate.t; first_position : int; position : int }
  | Opening_overlaps_origin of { coordinate : D.Effect_coordinate.t; opening_position : int }
  | Assertion_overlaps_origin of { coordinate : D.Effect_coordinate.t; group_position : int; assertion_position : int }
  | Assertion_overlaps_opening of { opening : opening; group_position : int; assertion_position : int }
  | Presence_overlaps_exact of { coordinate : D.Effect_coordinate.t; position : int }
type unavailable = Support_unknown of { coordinate : D.Effect_coordinate.t }
type premise = Zero_origin | Opening of opening | Current_assertion of P.answer
type exact =
  { coordinate : D.Effect_coordinate.t
  ; quantity : D.Quantity.t
  ; premise : premise
  }
type outcome = Exact of exact | Known_present of present

let qualify_openings frontier openings =
  let empty = Map.empty (module D.Effect_coordinate) in
  if List.is_empty openings then Ok empty else
  let current =
    List.fold (Correction_frontier.frontier_events frontier)
      ~init:(Map.empty (module D.Identifier.Event))
      ~f:(fun index event -> Map.set index ~key:(D.Event.id event) ~data:event)
  in
  List.fold_result openings ~init:(empty, 1)
    ~f:(fun (index, position) ({ coordinate; opening_event } as opening : opening) ->
      match Map.find index coordinate with
      | Some (_, first_position) -> Error (Duplicate_opening_coordinate { coordinate; first_position; position })
      | None ->
        match Map.find current opening_event with
        | None -> Error (Opening_event_not_current { opening; position })
        | Some event ->
          if List.exists (D.Event.effects event) ~f:(fun change ->
            D.Identifier.Locus.equal coordinate.locus (D.Effect.locus change)
            && D.Identifier.Measure.equal coordinate.measure (D.Effect.measure change))
          then Ok (Map.set index ~key:coordinate ~data:(opening, position), position + 1)
          else Error (Opening_event_missing_coordinate { opening; position }))
  |> Result.map ~f:fst
;;
let qualify_presence frontier = function
  | None -> Ok None
  | Some ({ reflected_roots; coordinates } as evidence : presence) ->
    let ( let* ) result f = Result.bind result ~f in
    let* cut = Result.map_error (C.create ~frontier ~reflected_roots) ~f:(fun error -> Presence_cut error) in
    let* (index, _) = List.fold_result coordinates ~init:(Map.empty (module D.Effect_coordinate), 1)
        ~f:(fun (index, position) coordinate ->
          match Map.find index coordinate with
          | Some first_position -> Error (Duplicate_presence_coordinate { coordinate; first_position; position })
          | None -> Ok (Map.set index ~key:coordinate ~data:position, position + 1)) in
    Ok (Some (evidence, cut, Set.of_list (module D.Effect_coordinate) (Map.keys index)))
;;
let present_index = function
  | None -> Map.empty (module D.Effect_coordinate)
  | Some (evidence, cut, declared) ->
    let touched = List.fold (C.remaining_events cut) ~init:(Set.empty (module D.Effect_coordinate))
        ~f:(fun touched event -> List.fold (D.Event.effects event) ~init:touched ~f:(fun touched change ->
          Set.add touched { locus = D.Effect.locus change; measure = D.Effect.measure change })) in
    Set.fold (Set.diff declared touched) ~init:(Map.empty (module D.Effect_coordinate))
      ~f:(fun index coordinate -> Map.set index ~key:coordinate ~data:{ coordinate; evidence; cut })
;;
let create ~source ~zero_origins ~openings ~groups ~presence =
  let ( let* ) result f = Result.bind result ~f in
  let* coverage = Result.map_error (D.Zero_origin_coverage.of_coordinates zero_origins) ~f:(fun error -> Zero_origins error) in
  let frontier = Actual_source.frontier source in
  let* opening_index = qualify_openings frontier openings in
  let* source_groups = Result.map_error (H.create ~frontier ~groups) ~f:(fun error -> Groups error) in
  let* qualified_presence = qualify_presence frontier presence in
  let* _ = List.fold_result openings ~init:1 ~f:(fun opening_position ({ coordinate; opening_event = _ } : opening) ->
    if D.Zero_origin_coverage.covers coverage coordinate
    then Error (Opening_overlaps_origin { coordinate; opening_position })
    else Ok (opening_position + 1)) in
  let* _ =
    List.fold_result groups ~init:1
      ~f:(fun group_position ({ reflected_roots = _; assertions } : H.group) ->
        let* _ =
          List.fold_result assertions ~init:1
            ~f:(fun assertion_position ({ coordinate; quantity = _ } : P.assertion) ->
              if D.Zero_origin_coverage.covers coverage coordinate
              then Error (Assertion_overlaps_origin { coordinate; group_position; assertion_position })
              else match Map.find opening_index coordinate with
                | Some (opening, _) ->
                  Error (Assertion_overlaps_opening { opening; group_position; assertion_position })
                | None -> Ok (assertion_position + 1))
        in
        Ok (group_position + 1))
  in
  let* _ = match presence with
    | None -> Ok 1
    | Some { reflected_roots = _; coordinates } ->
      List.fold_result coordinates ~init:1 ~f:(fun position coordinate ->
        if D.Zero_origin_coverage.covers coverage coordinate || Map.mem opening_index coordinate
           || Option.is_some (H.group_for source_groups coordinate)
        then Error (Presence_overlaps_exact { coordinate; position })
        else Ok (position + 1)) in
  let totals = List.fold (Correction_frontier.frontier_events frontier) ~init:Effect_sum.empty
      ~f:(fun totals event -> Effect_sum.add_effects totals (D.Event.effects event)) in
  Ok
    { source
    ; zero_origins
    ; coverage
    ; openings
    ; opening_index
    ; presence
    ; present_index = present_index qualified_presence
    ; totals
    ; source_groups
    }
;;
let source t = t.source
let zero_origins t = t.zero_origins
let openings t = t.openings
let presence t = t.presence
let source_groups t = t.source_groups
let query t coordinate =
  if D.Zero_origin_coverage.covers t.coverage coordinate
  then Ok (Exact { coordinate; quantity = Effect_sum.at t.totals coordinate; premise = Zero_origin })
  else match Map.find t.opening_index coordinate with
    | Some (opening, _) -> Ok (Exact { coordinate; quantity = Effect_sum.at t.totals coordinate; premise = Opening opening })
    | None ->
      match H.query t.source_groups coordinate with
      | Ok answer -> Ok (Exact { coordinate; quantity = P.quantity answer; premise = Current_assertion answer })
      | Error (P.Assertion_unknown { coordinate }) ->
        match Map.find t.present_index coordinate with
        | Some present -> Ok (Known_present present)
        | None -> Error (Support_unknown { coordinate })
;;
let coordinate (answer : exact) = answer.coordinate
let quantity (answer : exact) = answer.quantity
let premise (answer : exact) = answer.premise
let present_coordinate (answer : present) = answer.coordinate
let present_evidence (answer : present) = answer.evidence
let present_cut (answer : present) = answer.cut
