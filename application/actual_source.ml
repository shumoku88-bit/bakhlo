open Base
module D = Loam_domain
module Q = D.Quantity

type command =
  { events : D.Event.t list
  ; validities : Actual_validity.fact list
  ; validity_corrections : Actual_validity.correction list
  ; corrections : D.Event_correction.t list
  ; descriptions : Event_descriptions.fact list
  ; merchants : Event_merchants.fact list
  ; original_amounts : Original_amounts.fact list
  ; exchanges : Exchange_evidence.fact list
  }
type t =
  { frontier : Correction_frontier.t
  ; validity : Actual_validity.t
  ; descriptions : Event_descriptions.t
  ; merchants : Event_merchants.t
  ; original_amounts : Original_amounts.t
  ; exchanges : Exchange_evidence.t
  }
type error =
  | Events of D.Event_memory.error
  | Zero_effect of { event : D.Identifier.Event.t; event_position : int; effect_position : int }
  | Unbalanced_measure of
      { event : D.Identifier.Event.t; event_position : int; measure : D.Identifier.Measure.t; residual : Q.t }
  | Validity of Actual_validity.error
  | Corrections of Correction_frontier.error
  | Descriptions of Event_descriptions.error
  | Merchants of Event_merchants.error
  | Original_amounts of Original_amounts.error
  | Exchanges of Exchange_evidence.error

let check_event ~exchange event_position original =
  let changes = D.Event.effects original in
  let event = D.Event.id original in
  let ( let* ) result f = Result.bind result ~f in
  let* (_, totals) =
    List.fold_result changes ~init:(1, Measure_totals.empty)
      ~f:(fun (effect_position, totals) change ->
        if Q.equal (D.Effect.quantity change) Q.zero
        then Error (Zero_effect { event; event_position; effect_position })
        else Ok (effect_position + 1, Measure_totals.add totals change))
  in
  if exchange then Ok ()
  else match Measure_totals.first_nonzero totals with
    | Some (measure, residual) -> Error (Unbalanced_measure { event; event_position; measure; residual })
    | None -> Ok ()
;;

let create
    ({ events = originals
     ; validities
     ; validity_corrections
     ; corrections
     ; descriptions
     ; merchants
     ; original_amounts
     ; exchanges
     } : command)
  =
  let ( let* ) result f = Result.bind result ~f in
  let* events = Result.map_error (D.Event_memory.of_events originals) ~f:(fun error -> Events error) in
  let* exchanges =
    Result.map_error (Exchange_evidence.create ~events ~corrections ~facts:exchanges)
      ~f:(fun error -> Exchanges error)
  in
  let* _ = List.fold_result originals ~init:1 ~f:(fun position event ->
    let exchange = Option.is_some (Exchange_evidence.find_by_event exchanges (D.Event.id event)) in
    Result.map (check_event ~exchange position event) ~f:(fun () -> position + 1)) in
  let* validity =
    Result.map_error
      (Actual_validity.create ~events ~facts:validities ~corrections:validity_corrections)
      ~f:(fun error -> Validity error)
  in
  let* frontier =
    Result.map_error (Correction_frontier.create ~events ~corrections)
      ~f:(fun error -> Corrections error)
  in
  let* descriptions =
    Result.map_error (Event_descriptions.create ~events ~facts:descriptions)
      ~f:(fun error -> Descriptions error)
  in
  let* merchants =
    Result.map_error (Event_merchants.create ~events ~facts:merchants)
      ~f:(fun error -> Merchants error)
  in
  let* original_amounts =
    Result.map_error (Original_amounts.create ~frontier ~facts:original_amounts)
      ~f:(fun error -> Original_amounts error)
  in
  Ok { frontier; validity; descriptions; merchants; original_amounts; exchanges }
;;
let frontier t = t.frontier
let validity t = t.validity
let descriptions t = t.descriptions
let merchants t = t.merchants
let original_amounts t = t.original_amounts
let exchanges t = t.exchanges
