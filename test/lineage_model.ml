open Base

(* Test-only finite structural model. No Domain/Application dependency, production
   comparator/index, or successor traversal. Reachability is immutable Warshall
   closure of the supplied relation, not a production-derived oracle. *)
type edge = int * int

let equal_edge (a, b) (c, d) = Int.equal a c && Int.equal b d
let contains edges a b = List.mem edges (a, b) ~equal:equal_edge
let possible_edges nodes = List.cartesian_product nodes nodes

let closure ~nodes ~edges =
  let possible = possible_edges nodes in
  List.fold nodes ~init:edges ~f:(fun reach via ->
      List.filter possible ~f:(fun (a, b) ->
          contains reach a b || (contains reach a via && contains reach via b)))

let has_incoming edges node = List.exists edges ~f:(fun (_, b) -> Int.equal b node)
let has_outgoing edges node = List.exists edges ~f:(fun (a, _) -> Int.equal a node)

let unique field edges =
  List.for_alli edges ~f:(fun i left ->
      List.for_alli edges ~f:(fun j right ->
          Int.equal i j || not (Int.equal (field left) (field right))))

let analyze ~nodes ~edges =
  let closed =
    List.for_all edges ~f:(fun (a, b) ->
        List.mem nodes a ~equal:Int.equal && List.mem nodes b ~equal:Int.equal)
  in
  let reach = closure ~nodes ~edges in
  if
    closed && unique fst edges && unique snd edges
    && not (List.exists nodes ~f:(fun node -> contains reach node node))
  then
    let roots = List.filter nodes ~f:(fun node -> not (has_incoming edges node)) in
    let terminals = List.filter nodes ~f:(fun node -> not (has_outgoing edges node)) in
    Some
      (List.filter (List.cartesian_product roots terminals) ~f:(fun (root, terminal) ->
           Int.equal root terminal || contains reach root terminal))
  else None

let edges_of_mask nodes mask =
  List.filteri (possible_edges nodes) ~f:(fun i _ -> not (Int.equal (mask land (1 lsl i)) 0))
