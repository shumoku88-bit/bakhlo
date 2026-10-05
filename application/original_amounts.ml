open Base
module D = Bakhlo_domain
module Id = D.Identifier.Event
module F = Correction_frontier

type fact = { root : Id.t; measure : D.Identifier.Measure.t; quantity : D.Quantity.t }
type current = { retained_fact : fact; terminal_event : D.Event.t }

type t = {
  frontier : F.t;
  facts : fact list;
  currents : current list;
  by_terminal : (Id.t, current, Id.comparator_witness) Map.t;
}

type error =
  | Repeated_root of { root : Id.t; first_position : int; position : int }
  | Nonpositive_quantity of { root : Id.t; quantity : D.Quantity.t; position : int }
  | Unknown_event of { root : Id.t; position : int }
  | Not_root of { root : Id.t; position : int }

let create ~frontier ~facts =
  let roots =
    List.fold (F.lineages frontier)
      ~init:(Map.empty (module Id))
      ~f:(fun index lineage ->
        Map.set index ~key:(F.root_id lineage) ~data:(F.terminal_event lineage))
  in
  let init = (1, Map.empty (module Id), [], Map.empty (module Id)) in
  match
    List.fold_result facts ~init
      ~f:(fun
          (position, seen, rows, by_terminal) ({ root; measure = _; quantity } as retained_fact) ->
        match Map.find seen root with
        | Some first_position -> Error (Repeated_root { root; first_position; position })
        | None -> (
            if D.Quantity.compare quantity D.Quantity.zero <= 0 then
              Error (Nonpositive_quantity { root; quantity; position })
            else
              match D.Event_memory.find_by_id (F.retained_events frontier) root with
              | None -> Error (Unknown_event { root; position })
              | Some _ -> (
                  match Map.find roots root with
                  | None -> Error (Not_root { root; position })
                  | Some terminal_event ->
                      let current = { retained_fact; terminal_event } in
                      (* Distinct admitted roots have distinct terminals in the qualified frontier. *)
                      Ok
                        ( position + 1,
                          Map.set seen ~key:root ~data:position,
                          current :: rows,
                          Map.set by_terminal ~key:(D.Event.id terminal_event) ~data:current ))))
  with
  | Error error -> Error error
  | Ok (_, _, rows, by_terminal) -> Ok { frontier; facts; currents = List.rev rows; by_terminal }

let source_frontier t = t.frontier
let facts t = t.facts
let currents t = t.currents
let retained_fact current = current.retained_fact
let terminal_event current = current.terminal_event
let find_current t event = Map.find t.by_terminal event
