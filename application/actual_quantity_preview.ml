open Base
module D = Loam_domain
module Id = D.Identifier.Event
module H = Current_quantity_groups

type validity = { event : Id.t; valid_on : string }
type command =
  { events : D.Event.t list
  ; validities : validity list
  ; corrections : D.Event_correction.t list
  ; groups : H.group list
  }
type t = { validities : validity list; source_groups : H.t }
type error =
  | Events of D.Event_memory.error
  | Invalid_date of { position : int; text : string }
  | Repeated_validity of { event : Id.t; first_position : int; position : int }
  | Unknown_validity_event of { event : Id.t; position : int }
  | Missing_validity of { event : Id.t }
  | Corrections of Correction_frontier.error
  | Groups of H.error

let valid_date text =
  if not (Int.equal (String.length text) 10) then false
  else if not (Char.equal text.[4] '-' && Char.equal text.[7] '-') then false
  else
    let year = String.sub text ~pos:0 ~len:4 in
    let month = String.sub text ~pos:5 ~len:2 in
    let day = String.sub text ~pos:8 ~len:2 in
    if not (List.for_all [ year; month; day ] ~f:(String.for_all ~f:Char.is_digit)) then false
    else
      let y = Int.of_string year and m = Int.of_string month and d = Int.of_string day in
      let leap = y % 400 = 0 || (y % 4 = 0 && y % 100 <> 0) in
      let limit = match m with
        | 1 | 3 | 5 | 7 | 8 | 10 | 12 -> 31
        | 4 | 6 | 9 | 11 -> 30
        | 2 -> if leap then 29 else 28
        | _ -> 0 in
      y > 0 && d > 0 && d <= limit
;;

let run (command : command) =
  let ( let* ) result f = Result.bind result ~f in
  let* events = Result.map_error (D.Event_memory.of_events command.events) ~f:(fun error -> Events error) in
  let* (_, seen) = List.fold_result command.validities ~init:(1, Map.empty (module Id))
      ~f:(fun (position, seen) { event; valid_on } ->
        if not (valid_date valid_on) then Error (Invalid_date { position; text = valid_on })
        else match Map.find seen event with
          | Some first_position -> Error (Repeated_validity { event; first_position; position })
          | None ->
            match D.Event_memory.find_by_id events event with
            | None -> Error (Unknown_validity_event { event; position })
            | Some _ -> Ok (position + 1, Map.set seen ~key:event ~data:position)) in
  let* () = match List.find command.events ~f:(fun event -> not (Map.mem seen (D.Event.id event))) with
    | Some event -> Error (Missing_validity { event = D.Event.id event })
    | None -> Ok () in
  let* frontier = Result.map_error (Correction_frontier.create ~events ~corrections:command.corrections)
      ~f:(fun error -> Corrections error) in
  let* source_groups = Result.map_error (H.create ~frontier ~groups:command.groups) ~f:(fun error -> Groups error) in
  Ok { validities = command.validities; source_groups }
;;
let validities t = t.validities
let source_groups t = t.source_groups
let query t coordinate = H.query t.source_groups coordinate
