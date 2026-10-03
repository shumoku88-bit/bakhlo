open Base
module Cut = Root_cut_model

type group = { roots : int list; assertions : (int * Z.t) list }

type error =
  | Invalid_cut of { group_position : int; error : Cut.error }
  | Invalid_assertions of { group_position : int; coordinate : int; first_position : int; position : int }
  | Repeated_coordinate of
      { coordinate : int; first_group_position : int; first_assertion_position : int
      ; group_position : int; assertion_position : int }

let qualify ~nodes ~pairs ~group_position group =
  match Cut.cut ~nodes ~pairs ~reflected:group.roots with
  | Error error -> Error (Invalid_cut { group_position; error })
  | Ok _ ->
    (match List.find_mapi group.assertions ~f:(fun i (coordinate, _) ->
       match List.findi (List.take group.assertions i) ~f:(fun _ (prior, _) -> Int.equal coordinate prior) with
       | None -> None
       | Some (first, _) -> Some (Invalid_assertions { group_position; coordinate; first_position = first + 1; position = i + 1 })) with
     | None -> Ok group
     | Some error -> Error error)
;;

let admit ~nodes ~pairs groups =
  let rec scan group_position prior = function
    | [] -> Ok groups
    | group :: rest ->
      (match qualify ~nodes ~pairs ~group_position group with
       | Error error -> Error error
       | Ok _ ->
         let conflict = List.find_mapi group.assertions ~f:(fun i (coordinate, _) ->
           List.find_map (List.rev prior) ~f:(fun (first_group_position, previous) ->
             Option.map (List.findi previous.assertions ~f:(fun _ (c, _) -> Int.equal coordinate c))
               ~f:(fun (j, _) -> Repeated_coordinate { coordinate; first_group_position;
                 first_assertion_position = j + 1; group_position; assertion_position = i + 1 }))) in
         (match conflict with
          | Some error -> Error error
          | None -> scan (group_position + 1) ((group_position, group) :: prior) rest))
  in
  scan 1 [] groups
;;

let reobserve ~nodes ~pairs groups incoming =
  match qualify ~nodes ~pairs ~group_position:1 incoming with
  | Error error -> Error error
  | Ok _ ->
    let replaced = List.map incoming.assertions ~f:fst in
    let retained = List.filter_map groups ~f:(fun group ->
      let assertions = List.filter group.assertions ~f:(fun (c, _) -> not (List.mem replaced c ~equal:Int.equal)) in
      if List.is_empty assertions then None else Some { group with assertions }) in
    admit ~nodes ~pairs (retained @ [ incoming ])
;;

let premise groups coordinate =
  List.find_map groups ~f:(fun group ->
    Option.map (List.find group.assertions ~f:(fun (c, _) -> Int.equal c coordinate))
      ~f:(fun (_, quantity) -> group.roots, quantity))
;;

let equal_group a b =
  List.equal Int.equal a.roots b.roots
  && List.equal (fun (c, q) (d, r) -> Int.equal c d && Z.equal q r) a.assertions b.assertions
;;

let equal_premise a b =
  Option.equal (fun (roots, q) (other_roots, r) -> List.equal Int.equal roots other_roots && Z.equal q r) a b
;;

let old_groups first_cut second_cut ownership : group list =
  let assertions group = List.filter_map [ 0; 1 ] ~f:(fun coordinate ->
    let state = (ownership lsr (coordinate * 2)) land 3 in
    if not (Int.equal (state land (1 lsl group)) 0)
    then Some (coordinate, Z.of_int ((group + 1) * 100 + coordinate)) else None) in
  [ { roots = Cut.declaration_of_mask [ 0; 2 ] first_cut; assertions = assertions 0 }
  ; { roots = Cut.declaration_of_mask [ 0; 2 ] second_cut; assertions = assertions 1 } ]
;;

let incoming root_mask coordinate_mask : group =
  { roots = Cut.declaration_of_mask [ 0; 2 ] root_mask
  ; assertions = List.map (Cut.declaration_of_mask [ 0; 1 ] coordinate_mask)
      ~f:(fun c -> c, Z.neg (Z.shift_left Z.one (128 + c))) }
;;
