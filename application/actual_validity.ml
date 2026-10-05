open Base
module D = Bakhlo_domain
module Id = D.Identifier.Event
module Revision_id = D.Identifier.Validity_revision

type reference = Base_ref of Id.t | Revision_ref of Revision_id.t

type fact =
  | Base of { event : Id.t; valid_on : string }
  | Revision of { id : Revision_id.t; event : Id.t; valid_on : string }

type correction = { target : reference; replacement : Revision_id.t }
type endpoint = Target of reference | Replacement of Revision_id.t

module Reference = struct
  module Key = struct
    type t = reference

    let compare left right =
      match (left, right) with
      | Base_ref a, Base_ref b -> Id.compare a b
      | Revision_ref a, Revision_ref b -> Revision_id.compare a b
      | Base_ref _, Revision_ref _ -> -1
      | Revision_ref _, Base_ref _ -> 1

    let sexp_of_t = function
      | Base_ref id -> Sexp.List [ Sexp.Atom "base"; Sexp.Atom (Id.to_string id) ]
      | Revision_ref id -> Sexp.List [ Sexp.Atom "revision"; Sexp.Atom (Revision_id.to_string id) ]
  end

  include Key
  include Comparator.Make (Key)

  let equal a b = Int.equal (compare a b) 0
end

module Cycle_check = Replacement_cycle.Make (Reference)

type t = {
  events : D.Event_memory.t;
  facts : fact list;
  corrections : correction list;
  current_facts : fact list;
  by_event : (Id.t, int * fact, Id.comparator_witness) Map.t;
}

type error =
  | Invalid_date of { position : int; text : string }
  | Repeated_fact of { reference : reference; first_position : int; position : int }
  | Unknown_validity_event of { event : Id.t; position : int }
  | Unresolved_correction of { position : int; endpoints : endpoint list }
  | Cross_event_correction of { position : int; target_event : Id.t; replacement_event : Id.t }
  | Repeated_target of { reference : reference; first_position : int; position : int }
  | Repeated_replacement of { id : Revision_id.t; first_position : int; position : int }
  | Cycle of { path : reference list }
  | Repeated_current_validity of { event : Id.t; first_position : int; position : int }
  | Missing_validity of { event : Id.t }

let reference = function
  | Base { event; valid_on = _ } -> Base_ref event
  | Revision { id; event = _; valid_on = _ } -> Revision_ref id

let event = function
  | Base { event; valid_on = _ } | Revision { id = _; event; valid_on = _ } -> event

let valid_on = function
  | Base { event = _; valid_on } | Revision { id = _; event = _; valid_on } -> valid_on

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
      let limit =
        match m with
        | 1 | 3 | 5 | 7 | 8 | 10 | 12 -> 31
        | 4 | 6 | 9 | 11 -> 30
        | 2 -> if leap then 29 else 28
        | _ -> 0
      in
      y > 0 && d > 0 && d <= limit

let index_facts ~events facts =
  List.fold_result facts
    ~init:(1, Map.empty (module Reference))
    ~f:(fun (position, seen) fact ->
      let text = valid_on fact and key = reference fact and event = event fact in
      if not (valid_date text) then Error (Invalid_date { position; text })
      else
        match Map.find seen key with
        | Some (first_position, _) ->
            Error (Repeated_fact { reference = key; first_position; position })
        | None -> (
            match D.Event_memory.find_by_id events event with
            | None -> Error (Unknown_validity_event { event; position })
            | Some _ -> Ok (position + 1, Map.set seen ~key ~data:(position, fact))))

let index_corrections facts corrections =
  List.fold_result corrections
    ~init:(1, Map.empty (module Reference), Map.empty (module Revision_id))
    ~f:(fun (position, targets, replacements) { target; replacement } ->
      match (Map.find facts target, Map.find facts (Revision_ref replacement)) with
      | None, None ->
          Error
            (Unresolved_correction
               { position; endpoints = [ Target target; Replacement replacement ] })
      | None, Some _ -> Error (Unresolved_correction { position; endpoints = [ Target target ] })
      | Some _, None ->
          Error (Unresolved_correction { position; endpoints = [ Replacement replacement ] })
      | Some (_, before), Some (_, after) -> (
          let target_event = event before and replacement_event = event after in
          if not (Id.equal target_event replacement_event) then
            Error (Cross_event_correction { position; target_event; replacement_event })
          else
            match Map.find targets target with
            | Some (first_position, _) ->
                Error (Repeated_target { reference = target; first_position; position })
            | None -> (
                match Map.find replacements replacement with
                | Some first_position ->
                    Error (Repeated_replacement { id = replacement; first_position; position })
                | None ->
                    Ok
                      ( position + 1,
                        Map.set targets ~key:target ~data:(position, replacement),
                        Map.set replacements ~key:replacement ~data:position ))))

let create ~events ~facts ~corrections =
  let ( let* ) result f = Result.bind result ~f in
  let* _, indexed = index_facts ~events facts in
  let* _, targets, _ = index_corrections indexed corrections in
  let* () =
    Result.map_error
      (Cycle_check.check
         ~successor:(fun key ->
           Option.map (Map.find targets key) ~f:(fun (_, id) -> Revision_ref id))
         ~starts:(List.map corrections ~f:(fun { target; replacement = _ } -> target)))
      ~f:(fun path -> Cycle { path })
  in
  let* _, reversed, by_event =
    List.fold_result facts
      ~init:(1, [], Map.empty (module Id))
      ~f:(fun (position, current, seen) fact ->
        if Map.mem targets (reference fact) then Ok (position + 1, current, seen)
        else
          let event = event fact in
          match Map.find seen event with
          | Some (first_position, _) ->
              Error (Repeated_current_validity { event; first_position; position })
          | None ->
              Ok (position + 1, fact :: current, Map.set seen ~key:event ~data:(position, fact)))
  in
  match
    List.find (D.Event_memory.events events) ~f:(fun event ->
        not (Map.mem by_event (D.Event.id event)))
  with
  | Some event -> Error (Missing_validity { event = D.Event.id event })
  | None -> Ok { events; facts; corrections; current_facts = List.rev reversed; by_event }

let source_events t = t.events
let facts t = t.facts
let corrections t = t.corrections
let current_facts t = t.current_facts
let find_current t id = Option.map (Map.find t.by_event id) ~f:snd
