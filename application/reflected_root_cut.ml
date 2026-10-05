module D = Bakhlo_domain
module Id = D.Identifier.Event
module F = Correction_frontier

type t = {
  source_frontier : F.t;
  reflected_roots : Id.t list;
  remaining_lineages : F.lineage list;
  remaining_events : D.Event.t list;
}

type error =
  | Duplicate_root of { id : Id.t; first_position : int; position : int }
  | Unknown_event of { id : Id.t; position : int }
  | Not_root of { id : Id.t; position : int }

let create ~frontier ~reflected_roots =
  let lineages = F.lineages frontier in
  let roots = Base.Set.of_list (module Id) (Base.List.map lineages ~f:F.root_id) in
  let admitted =
    Base.List.fold_result reflected_roots
      ~init:(1, Base.Map.empty (module Id))
      ~f:(fun (position, seen) id ->
        match Base.Map.find seen id with
        | Some first_position -> Error (Duplicate_root { id; first_position; position })
        | None -> (
            if Base.Set.mem roots id then Ok (position + 1, Base.Map.set seen ~key:id ~data:position)
            else
              match D.Event_memory.find_by_id (F.retained_events frontier) id with
              | None -> Error (Unknown_event { id; position })
              | Some _ -> Error (Not_root { id; position })))
  in
  match admitted with
  | Error error -> Error error
  | Ok (_, reflected) ->
      let remaining_lineages =
        Base.List.filter lineages ~f:(fun row -> not (Base.Map.mem reflected (F.root_id row)))
      in
      let remaining_events = Base.List.map remaining_lineages ~f:F.terminal_event in
      Ok { source_frontier = frontier; reflected_roots; remaining_lineages; remaining_events }

let source_frontier cut = cut.source_frontier
let reflected_roots cut = cut.reflected_roots
let remaining_lineages cut = cut.remaining_lineages
let remaining_events cut = cut.remaining_events
