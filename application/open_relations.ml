open Base
module D = Loam_domain
module Id = D.Identifier.Relation
module Q = D.Quantity

type endpoint = Household | External of D.Identifier.External_party.t
type fact =
  { id : Id.t; source_event : D.Identifier.Event.t; source_effect : D.Identifier.Effect_key.t
  ; debtor : endpoint; creditor : endpoint; quantity : Q.t }
type error =
  | Repeated_id of { id : Id.t; first_position : int; position : int }
  | Unknown_event of { id : Id.t; event : D.Identifier.Event.t; position : int }
  | Missing_effect of { id : Id.t; event : D.Identifier.Event.t; key : D.Identifier.Effect_key.t; position : int }
  | Invalid_endpoints of { id : Id.t; debtor : endpoint; creditor : endpoint; position : int }
  | Nonpositive_quantity of { id : Id.t; quantity : Q.t; position : int }
  | Exceeds_source of { id : Id.t; quantity : Q.t; magnitude : Q.t; position : int }
  | Overcovered_source of
      { event : D.Identifier.Event.t; key : D.Identifier.Effect_key.t; total : Q.t; magnitude : Q.t; position : int }
type admitted = { fact : fact; event : D.Event.t; change : D.Effect.t }

(* Mechanical typed source key, not concatenated identity or a public EffectRef. *)
module Source = struct
  module Key = struct
    type t = { event : D.Identifier.Event.t; key : D.Identifier.Effect_key.t }
    let compare left right =
      let event = D.Identifier.Event.compare left.event right.event in
      if event = 0 then D.Identifier.Effect_key.compare left.key right.key else event
    ;;
    let sexp_of_t source = Sexp.List
      [ Atom (D.Identifier.Event.to_string source.event); Atom (D.Identifier.Effect_key.to_string source.key) ]
  end
  include Key
  include Comparator.Make (Key)
end

type t =
  { events : D.Event_memory.t; facts : fact list; admitted : admitted list
  ; by_id : (Id.t, admitted, Id.comparator_witness) Map.t }
let magnitude quantity = if Q.compare quantity Q.zero < 0 then Q.neg quantity else quantity
let endpoints = function
  | Household, External _ | External _, Household -> true
  | Household, Household | External _, External _ -> false
;;
let unique facts =
  Result.map
    (List.fold_result facts ~init:(1, Map.empty (module Id)) ~f:(fun (position, seen) fact ->
      match Map.find seen fact.id with
      | Some first_position -> Error (Repeated_id { id = fact.id; first_position; position })
      | None -> Ok (position + 1, Map.set seen ~key:fact.id ~data:position)))
    ~f:(fun _ -> ())
;;
let admit events position fact =
  let ( let* ) result f = Result.bind result ~f in
  let* event = match D.Event_memory.find_by_id events fact.source_event with
    | None -> Error (Unknown_event { id = fact.id; event = fact.source_event; position })
    | Some event -> Ok event in
  let* change = match List.find (D.Event.effects event) ~f:(fun change ->
    Option.equal D.Identifier.Effect_key.equal (D.Effect.key change) (Some fact.source_effect)) with
    | None -> Error (Missing_effect { id = fact.id; event = fact.source_event; key = fact.source_effect; position })
    | Some change -> Ok change in
  if not (endpoints (fact.debtor, fact.creditor)) then
    Error (Invalid_endpoints { id = fact.id; debtor = fact.debtor; creditor = fact.creditor; position })
  else if Q.compare fact.quantity Q.zero <= 0 then
    Error (Nonpositive_quantity { id = fact.id; quantity = fact.quantity; position })
  else
    let magnitude = magnitude (D.Effect.quantity change) in
    if Q.compare fact.quantity magnitude > 0 then Error (Exceeds_source { id = fact.id; quantity = fact.quantity; magnitude; position })
    else Ok { fact; event; change }
;;
let source fact : Source.t = { event = fact.source_event; key = fact.source_effect }
let create ~events ~facts =
  let ( let* ) result f = Result.bind result ~f in
  let* () = unique facts in
  let* (_, by_id, coverage, reversed) =
    List.fold_result facts ~init:(1, Map.empty (module Id), Map.empty (module Source), [])
      ~f:(fun (position, by_id, coverage, reversed) fact ->
        let* row = admit events position fact in
        let key = source fact in
        let prior = Option.value (Map.find coverage key) ~default:Q.zero in
        Ok (position + 1, Map.set by_id ~key:fact.id ~data:row,
          Map.set coverage ~key ~data:(Q.add prior fact.quantity), row :: reversed))
  in
  let admitted = List.rev reversed in
  let* _ = List.fold_result admitted ~init:1 ~f:(fun position row ->
    let key = source row.fact in
    let total = Map.find_exn coverage key in
    let magnitude = magnitude (D.Effect.quantity row.change) in
    if Q.compare total magnitude > 0 then
      Error (Overcovered_source { event = key.event; key = key.key; total; magnitude; position })
    else Ok (position + 1)) in
  Ok { events; facts; admitted; by_id }
;;
let source_events t = t.events
let facts t = t.facts
let admitted t = t.admitted
let fact row = row.fact
let source_event row = row.event
let source_effect row = row.change
let find_by_id t id = Map.find t.by_id id
