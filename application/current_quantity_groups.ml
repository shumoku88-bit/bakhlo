open Base
open Bakhlo_domain
module Projection = Current_quantity_projection

type group =
  { reflected_roots : Identifier.Event.t list
  ; assertions : Projection.assertion list
  }

type qualified_group = { facts : group; projection : Projection.t }

type t =
  { frontier : Correction_frontier.t
  ; qualified_groups : qualified_group list
  ; owners : (Effect_coordinate.t, Projection.t, Effect_coordinate.comparator_witness) Map.t
  }

type error =
  | Invalid_cut of { group_position : int; error : Reflected_root_cut.error }
  | Invalid_assertions of { group_position : int; error : Projection.error }
  | Repeated_coordinate of
      { coordinate : Effect_coordinate.t
      ; first_group_position : int
      ; first_assertion_position : int
      ; group_position : int
      ; assertion_position : int
      }

type owner = { group_position : int; assertion_position : int; projection : Projection.t }

let qualify ~frontier ~group_position facts =
  match Reflected_root_cut.create ~frontier ~reflected_roots:facts.reflected_roots with
  | Error error -> Error (Invalid_cut { group_position; error })
  | Ok cut ->
    (match Projection.create ~cut ~assertions:facts.assertions with
     | Error error -> Error (Invalid_assertions { group_position; error })
     | Ok projection -> Ok { facts; projection })
;;

let index_group ~group_position owners (group : qualified_group) =
  List.fold_result group.facts.assertions ~init:(1, owners)
    ~f:(fun (assertion_position, owners) (assertion : Projection.assertion) ->
      let coordinate = assertion.coordinate in
      match Map.find owners coordinate with
      | Some (first : owner) ->
        Error (Repeated_coordinate
          { coordinate; first_group_position = first.group_position
          ; first_assertion_position = first.assertion_position; group_position; assertion_position })
      | None ->
        let owner = { group_position; assertion_position; projection = group.projection } in
        Ok (assertion_position + 1, Map.set owners ~key:coordinate ~data:owner))
  |> Result.map ~f:snd
;;

let materialize ~frontier ~qualified_groups owners =
  { frontier; qualified_groups; owners = Map.map owners ~f:(fun (owner : owner) -> owner.projection) }
;;

let create ~frontier ~groups =
  List.fold_result groups ~init:(1, [], Map.empty (module Effect_coordinate))
    ~f:(fun (group_position, reversed, owners) facts ->
      match qualify ~frontier ~group_position facts with
      | Error error -> Error error
      | Ok group ->
        Result.map (index_group ~group_position owners group)
          ~f:(fun owners -> group_position + 1, group :: reversed, owners))
  |> Result.map ~f:(fun (_, reversed, owners) ->
      materialize ~frontier ~qualified_groups:(List.rev reversed) owners)
;;

let source_frontier t = t.frontier
let groups t = List.map t.qualified_groups ~f:(fun group -> group.facts)
let group_for t coordinate = Map.find t.owners coordinate

let query t coordinate =
  match group_for t coordinate with
  | None -> Error (Projection.Assertion_unknown { coordinate })
  | Some projection -> Projection.query projection coordinate
;;

let reobserve t incoming =
  match qualify ~frontier:t.frontier ~group_position:1 incoming with
  | Error error -> Error error
  | Ok incoming_group ->
    let coordinates = Set.of_list (module Effect_coordinate)
        (List.map incoming.assertions ~f:(fun (assertion : Projection.assertion) -> assertion.coordinate)) in
    let reduced = List.fold_result t.qualified_groups ~init:(1, [])
        ~f:(fun (group_position, reversed) group ->
          let assertions = List.filter group.facts.assertions
              ~f:(fun (assertion : Projection.assertion) -> not (Set.mem coordinates assertion.coordinate)) in
          if List.is_empty assertions then Ok (group_position + 1, reversed)
          else if Int.equal (List.length assertions) (List.length group.facts.assertions)
          then Ok (group_position + 1, group :: reversed)
          else
            match Projection.create ~cut:(Projection.source_cut group.projection) ~assertions with
            | Error error -> Error (Invalid_assertions { group_position; error })
            | Ok projection ->
              let facts = { group.facts with assertions } in
              Ok (group_position + 1, { facts; projection } :: reversed)) in
    Result.bind reduced ~f:(fun (_, reversed) ->
      let qualified_groups = List.rev_append reversed [ incoming_group ] in
      List.fold_result qualified_groups ~init:(1, Map.empty (module Effect_coordinate))
        ~f:(fun (group_position, owners) group ->
          Result.map (index_group ~group_position owners group)
            ~f:(fun owners -> group_position + 1, owners))
      |> Result.map ~f:(fun (_, owners) -> materialize ~frontier:t.frontier ~qualified_groups owners))
;;
