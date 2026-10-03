open Base
module D = Loam_domain
module H = Current_quantity_groups
module P = Current_quantity_projection

type opening = { coordinate : D.Effect_coordinate.t; opening_event : D.Identifier.Event.t }
type t =
  { source : Actual_source.t
  ; zero_origins : D.Effect_coordinate.t list
  ; coverage : D.Zero_origin_coverage.t
  ; openings : opening list
  ; opening_index : (D.Effect_coordinate.t, opening * int, D.Effect_coordinate.comparator_witness) Map.t
  ; totals : Effect_sum.t
  ; source_groups : H.t
  }
type error =
  | Zero_origins of D.Zero_origin_coverage.error
  | Duplicate_opening_coordinate of { coordinate : D.Effect_coordinate.t; first_position : int; position : int }
  | Opening_event_not_current of { opening : opening; position : int }
  | Opening_event_missing_coordinate of { opening : opening; position : int }
  | Groups of H.error
  | Opening_overlaps_origin of { coordinate : D.Effect_coordinate.t; opening_position : int }
  | Assertion_overlaps_origin of { coordinate : D.Effect_coordinate.t; group_position : int; assertion_position : int }
  | Assertion_overlaps_opening of { opening : opening; group_position : int; assertion_position : int }
type unavailable = Support_unknown of { coordinate : D.Effect_coordinate.t }
type premise = Zero_origin | Opening of opening | Current_assertion of P.answer
type answer = { coordinate : D.Effect_coordinate.t; quantity : D.Quantity.t; premise : premise }

let qualify_openings frontier openings =
  let empty = Map.empty (module D.Effect_coordinate) in
  if List.is_empty openings then Ok empty else
  let current = List.fold (Correction_frontier.frontier_events frontier) ~init:(Map.empty (module D.Identifier.Event))
      ~f:(fun index event -> Map.set index ~key:(D.Event.id event) ~data:event) in
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
let create ~source ~zero_origins ~openings ~groups =
  let ( let* ) result f = Result.bind result ~f in
  let* coverage = Result.map_error (D.Zero_origin_coverage.of_coordinates zero_origins) ~f:(fun error -> Zero_origins error) in
  let frontier = Actual_source.frontier source in
  let* opening_index = qualify_openings frontier openings in
  let* source_groups = Result.map_error (H.create ~frontier ~groups) ~f:(fun error -> Groups error) in
  let* _ = List.fold_result openings ~init:1 ~f:(fun opening_position ({ coordinate; opening_event = _ } : opening) ->
    if D.Zero_origin_coverage.covers coverage coordinate
    then Error (Opening_overlaps_origin { coordinate; opening_position })
    else Ok (opening_position + 1)) in
  let* _ = List.fold_result groups ~init:1 ~f:(fun group_position ({ reflected_roots = _; assertions } : H.group) ->
    let* _ = List.fold_result assertions ~init:1 ~f:(fun assertion_position ({ coordinate; quantity = _ } : P.assertion) ->
      if D.Zero_origin_coverage.covers coverage coordinate
      then Error (Assertion_overlaps_origin { coordinate; group_position; assertion_position })
      else match Map.find opening_index coordinate with
        | Some (opening, _) -> Error (Assertion_overlaps_opening { opening; group_position; assertion_position })
        | None -> Ok (assertion_position + 1)) in
    Ok (group_position + 1)) in
  let totals = List.fold (Correction_frontier.frontier_events frontier) ~init:Effect_sum.empty
      ~f:(fun totals event -> Effect_sum.add_effects totals (D.Event.effects event)) in
  Ok { source; zero_origins; coverage; openings; opening_index; totals; source_groups }
;;
let source t = t.source
let zero_origins t = t.zero_origins
let openings t = t.openings
let source_groups t = t.source_groups
let query t coordinate =
  if D.Zero_origin_coverage.covers t.coverage coordinate
  then Ok { coordinate; quantity = Effect_sum.at t.totals coordinate; premise = Zero_origin }
  else match Map.find t.opening_index coordinate with
    | Some (opening, _) -> Ok { coordinate; quantity = Effect_sum.at t.totals coordinate; premise = Opening opening }
    | None ->
      match H.query t.source_groups coordinate with
      | Ok answer -> Ok { coordinate; quantity = P.quantity answer; premise = Current_assertion answer }
      | Error (P.Assertion_unknown { coordinate }) -> Error (Support_unknown { coordinate })
;;
let coordinate (answer : answer) = answer.coordinate
let quantity (answer : answer) = answer.quantity
let premise (answer : answer) = answer.premise
