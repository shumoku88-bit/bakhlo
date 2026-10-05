module D = Bakhlo_domain
module Id = D.Identifier.Event

type lineage = {
  root_id : Id.t;
  terminal_event : D.Event.t;
  correction_path : D.Event_correction.t list;
}

type t = {
  retained_events : D.Event_memory.t;
  corrections : D.Event_correction.t list;
  frontier_events : D.Event.t list;
  lineages : lineage list;
}

type error =
  | Unresolved_correction of { position : int; errors : Correction_check.error list }
  | Repeated_target of { id : Id.t; first_position : int; position : int }
  | Repeated_replacement of { id : Id.t; first_position : int; position : int }
  | Cycle of { path : Id.t list }

let index ~events corrections =
  Base.List.fold_result corrections
    ~init:(1, Base.Map.empty (module Id), Base.Map.empty (module Id))
    ~f:(fun (position, targets, replacements) (correction : D.Event_correction.t) ->
      match Correction_check.run ~events ~correction with
      | Error errors -> Error (Unresolved_correction { position; errors })
      | Ok closed -> (
          match Base.Map.find targets correction.target with
          | Some (first_position, _, _) ->
              Error (Repeated_target { id = correction.target; first_position; position })
          | None -> (
              match Base.Map.find replacements correction.replacement with
              | Some first_position ->
                  Error
                    (Repeated_replacement { id = correction.replacement; first_position; position })
              | None ->
                  Ok
                    ( position + 1,
                      Base.Map.set targets ~key:correction.target
                        ~data:(position, correction, Correction_check.replacement_event closed),
                      Base.Map.set replacements ~key:correction.replacement ~data:position ))))

module Cycle_check = Replacement_cycle.Make (Id)

let check_acyclic targets corrections =
  Base.Result.map_error
    (Cycle_check.check
       ~successor:(fun id ->
         Base.Option.map (Base.Map.find targets id) ~f:(fun (_, _, replacement) ->
             D.Event.id replacement))
       ~starts:
         (Base.List.map corrections ~f:(fun (correction : D.Event_correction.t) ->
              correction.target)))
    ~f:(fun path -> Cycle { path })

(* Called only after the supplied relation's closure/uniqueness/cycle checks.
   The index retains resolved replacement observations, so no lookup default or
   impossible missing-Event exception is needed during terminal traversal. *)
let build_lineages ~events ~targets ~replacements =
  let rec terminal event reversed =
    match Base.Map.find targets (D.Event.id event) with
    | None -> (event, Base.List.rev reversed)
    | Some (_, correction, replacement) ->
        (terminal [@tailcall]) replacement (correction :: reversed)
  in
  Base.List.filter_map (D.Event_memory.events events) ~f:(fun event ->
      if Base.Map.mem replacements (D.Event.id event) then None
      else
        let terminal_event, correction_path = terminal event [] in
        Some { root_id = D.Event.id event; terminal_event; correction_path })

let create ~events ~corrections =
  match index ~events corrections with
  | Error error -> Error error
  | Ok (_, targets, replacements) -> (
      match check_acyclic targets corrections with
      | Error error -> Error error
      | Ok _ ->
          let frontier_events =
            Base.List.filter (D.Event_memory.events events) ~f:(fun event ->
                not (Base.Map.mem targets (D.Event.id event)))
          in
          let lineages = build_lineages ~events ~targets ~replacements in
          Ok { retained_events = events; corrections; frontier_events; lineages })

let retained_events frontier = frontier.retained_events
let corrections frontier = frontier.corrections
let frontier_events frontier = frontier.frontier_events
let lineages frontier = frontier.lineages
let root_id lineage = lineage.root_id
let terminal_event lineage = lineage.terminal_event
let correction_path lineage = lineage.correction_path
