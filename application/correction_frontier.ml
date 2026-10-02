module D = Loam_domain
module Id = D.Identifier.Event

type t =
  { retained_events : D.Event_memory.t
  ; corrections : D.Event_correction.t list
  ; frontier_events : D.Event.t list
  }

type error =
  | Unresolved_correction of
      { position : int
      ; errors : Correction_check.error list
      }
  | Repeated_target of
      { id : Id.t
      ; first_position : int
      ; position : int
      }
  | Repeated_replacement of
      { id : Id.t
      ; first_position : int
      ; position : int
      }
  | Cycle of { path : Id.t list }

let index ~events corrections =
  Base.List.fold_result
    corrections
    ~init:(1, Base.Map.empty (module Id), Base.Map.empty (module Id))
    ~f:(fun (position, targets, replacements) (correction : D.Event_correction.t) ->
      match Correction_check.run ~events ~correction with
      | Error errors -> Error (Unresolved_correction { position; errors })
      | Ok _ ->
        (match Base.Map.find targets correction.target with
         | Some (first_position, _) ->
           Error (Repeated_target { id = correction.target; first_position; position })
         | None ->
           (match Base.Map.find replacements correction.replacement with
            | Some first_position ->
              Error (Repeated_replacement { id = correction.replacement; first_position; position })
            | None ->
              Ok
                ( position + 1
                , Base.Map.set targets ~key:correction.target ~data:(position, correction.replacement)
                , Base.Map.set replacements ~key:correction.replacement ~data:position ))))
;;

let check_acyclic targets corrections =
  let rec walk completed visiting reversed id =
    if Base.Set.mem visiting id
    then (
      let interior = Base.List.take_while reversed ~f:(fun seen -> not (Id.equal seen id)) in
      Error (Cycle { path = id :: Base.List.append (Base.List.rev interior) [ id ] }))
    else if Base.Set.mem completed id
    then Ok (Base.Set.union completed visiting)
    else (
      let visiting = Base.Set.add visiting id in
      match Base.Map.find targets id with
      | None -> Ok (Base.Set.union completed visiting)
      | Some (_, replacement) -> walk completed visiting (id :: reversed) replacement)
  in
  Base.List.fold_result
    corrections
    ~init:(Base.Set.empty (module Id))
    ~f:(fun completed (correction : D.Event_correction.t) ->
      walk completed (Base.Set.empty (module Id)) [] correction.target)
;;

let create ~events ~corrections =
  match index ~events corrections with
  | Error error -> Error error
  | Ok (_, targets, _) ->
    (match check_acyclic targets corrections with
     | Error error -> Error error
     | Ok _ ->
       let frontier_events =
         Base.List.filter (D.Event_memory.events events) ~f:(fun event ->
           not (Base.Map.mem targets (D.Event.id event)))
       in
       Ok { retained_events = events; corrections; frontier_events })
;;

let retained_events frontier = frontier.retained_events
let corrections frontier = frontier.corrections
let frontier_events frontier = frontier.frontier_events
