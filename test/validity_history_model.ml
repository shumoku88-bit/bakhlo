open Base

(* Integer-only extension of the earned Warshall model: 0/1 are Event-rooted
   bases, 2/3 identified revisions. No production date/reference/index dependency. *)
let event ~revision_events node = if node < 2 then node else List.nth_exn revision_events (node - 2)
let possible_edges = List.cartesian_product [ 0; 1; 2; 3 ] [ 2; 3 ]
let edges mask = List.filteri possible_edges ~f:(fun i _ -> mask land (1 lsl i) <> 0)
let nodes mask = List.filter [ 0; 1; 2; 3 ] ~f:(fun i -> mask land (1 lsl i) <> 0)
let assignment mask = [ mask % 2; mask / 2 ]

let analyze ~nodes ~edges ~revision_events =
  match Lineage_model.analyze ~nodes ~edges with
  | None -> None
  | Some pairs ->
      let owner = event ~revision_events in
      let terminals = List.map pairs ~f:snd in
      let events = List.map terminals ~f:owner in
      if
        List.for_all edges ~f:(fun (a, b) -> Int.equal (owner a) (owner b))
        && List.equal Int.equal (List.sort events ~compare:Int.compare) [ 0; 1 ]
      then Some terminals
      else None
