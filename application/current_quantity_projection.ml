module D = Bakhlo_domain
module Coordinate = D.Effect_coordinate
module Q = D.Quantity

type assertion = { coordinate : Coordinate.t; quantity : Q.t }
type answer = { coordinate : Coordinate.t; asserted_quantity : Q.t; delta : Q.t; quantity : Q.t }

type t = {
  source_cut : Reflected_root_cut.t;
  assertions : assertion list;
  answers : (Coordinate.t, answer, Coordinate.comparator_witness) Base.Map.t;
}

type error =
  | Duplicate_coordinate of { coordinate : Coordinate.t; first_position : int; position : int }

type unavailable = Assertion_unknown of { coordinate : Coordinate.t }

let create ~cut ~assertions =
  let indexed =
    Base.List.fold_result assertions
      ~init:(1, Base.Map.empty (module Coordinate))
      ~f:(fun (position, seen) (assertion : assertion) ->
        match Base.Map.find seen assertion.coordinate with
        | Some (first_position, _) ->
            Error
              (Duplicate_coordinate { coordinate = assertion.coordinate; first_position; position })
        | None ->
            Ok
              (position + 1, Base.Map.set seen ~key:assertion.coordinate ~data:(position, assertion)))
  in
  match indexed with
  | Error error -> Error error
  | Ok (_, supported) ->
      let totals =
        Base.List.fold (Reflected_root_cut.remaining_events cut) ~init:Effect_sum.empty
          ~f:(fun totals event -> Effect_sum.add_effects totals (D.Event.effects event))
      in
      let answers =
        Base.Map.mapi supported ~f:(fun ~key:coordinate ~data:(_, assertion) ->
            let delta = Effect_sum.at totals coordinate in
            {
              coordinate;
              asserted_quantity = assertion.quantity;
              delta;
              quantity = Q.add assertion.quantity delta;
            })
      in
      Ok { source_cut = cut; assertions; answers }

let source_cut model = model.source_cut
let assertions model = model.assertions

let query model coordinate =
  match Base.Map.find model.answers coordinate with
  | None -> Error (Assertion_unknown { coordinate })
  | Some answer -> Ok answer

let coordinate answer = answer.coordinate
let asserted_quantity answer = answer.asserted_quantity
let delta answer = answer.delta
let quantity answer = answer.quantity
