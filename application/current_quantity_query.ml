open Base
module D = Loam_domain
module H = Current_quantity_groups
module P = Current_quantity_projection

type t =
  { source : Actual_source.t
  ; zero_origins : D.Effect_coordinate.t list
  ; coverage : D.Zero_origin_coverage.t
  ; totals : Effect_sum.t
  ; source_groups : H.t
  }
type error =
  | Zero_origins of D.Zero_origin_coverage.error
  | Groups of H.error
  | Overlapping_support of { coordinate : D.Effect_coordinate.t; group_position : int; assertion_position : int }
type unavailable = Support_unknown of { coordinate : D.Effect_coordinate.t }
type premise = Zero_origin | Current_assertion of P.answer
type answer = { coordinate : D.Effect_coordinate.t; quantity : D.Quantity.t; premise : premise }

let create ~source ~zero_origins ~groups =
  let ( let* ) result f = Result.bind result ~f in
  let* coverage = Result.map_error (D.Zero_origin_coverage.of_coordinates zero_origins) ~f:(fun error -> Zero_origins error) in
  let frontier = Actual_source.frontier source in
  let* source_groups = Result.map_error (H.create ~frontier ~groups) ~f:(fun error -> Groups error) in
  let* _ = List.fold_result groups ~init:1 ~f:(fun group_position ({ reflected_roots = _; assertions } : H.group) ->
    let* _ = List.fold_result assertions ~init:1 ~f:(fun assertion_position ({ coordinate; quantity = _ } : P.assertion) ->
      if D.Zero_origin_coverage.covers coverage coordinate
      then Error (Overlapping_support { coordinate; group_position; assertion_position })
      else Ok (assertion_position + 1)) in
    Ok (group_position + 1)) in
  let totals = List.fold (Correction_frontier.frontier_events frontier) ~init:Effect_sum.empty
      ~f:(fun totals event -> Effect_sum.add_effects totals (D.Event.effects event)) in
  Ok { source; zero_origins; coverage; totals; source_groups }
;;
let source t = t.source
let zero_origins t = t.zero_origins
let source_groups t = t.source_groups
let query t coordinate =
  if D.Zero_origin_coverage.covers t.coverage coordinate
  then Ok { coordinate; quantity = Effect_sum.at t.totals coordinate; premise = Zero_origin }
  else match H.query t.source_groups coordinate with
    | Ok answer -> Ok { coordinate; quantity = P.quantity answer; premise = Current_assertion answer }
    | Error (P.Assertion_unknown { coordinate }) -> Error (Support_unknown { coordinate })
;;
let coordinate (answer : answer) = answer.coordinate
let quantity (answer : answer) = answer.quantity
let premise (answer : answer) = answer.premise
