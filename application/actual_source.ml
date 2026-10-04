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
  ; reversals : Actual_reversals.fact list
  ; relations : Open_relations.fact list
  }
type t =
  { frontier : Correction_frontier.t
  ; validity : Actual_validity.t
  ; descriptions : Event_descriptions.t
  ; merchants : Event_merchants.t
  ; original_amounts : Original_amounts.t
  ; exchanges : Exchange_evidence.t
  ; reversals : Actual_reversals.t
  ; relations : Open_relations.t
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
  | Reversals of Actual_reversals.error
  | Relations of Open_relations.error

let check_event ~balance_exempt event_position original =
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
  if balance_exempt then Ok ()
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
     ; reversals
     ; relations
     } : command)
  =
  let ( let* ) result f = Result.bind result ~f in
  let* events = Result.map_error (D.Event_memory.of_events originals) ~f:(fun error -> Events error) in
  let* exchanges =
    Result.map_error (Exchange_evidence.create ~events ~corrections ~facts:exchanges)
      ~f:(fun error -> Exchanges error)
  in
  let* reversals =
    Result.map_error (Actual_reversals.create ~events ~facts:reversals)
      ~f:(fun error -> Reversals error)
  in
  let* _ = List.fold_result originals ~init:1 ~f:(fun position event ->
    let id = D.Event.id event in
    (* Disjoint roles guarantee every ordinary target is checked here. Inversion
       derives ordinary reversal balance; Exchange inverses retain their explicit
       Reversal exception, not a claim of per-Measure conservation. *)
    let balance_exempt =
      Option.is_some (Exchange_evidence.find_by_event exchanges id)
      || Option.is_some (Actual_reversals.find_by_reversal reversals id) in
    Result.map (check_event ~balance_exempt position event) ~f:(fun () -> position + 1)) in
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
  let* relations =
    Result.map_error (Open_relations.create ~events ~facts:relations)
      ~f:(fun error -> Relations error)
  in
  Ok { frontier; validity; descriptions; merchants; original_amounts; exchanges; reversals; relations }
;;
let frontier t = t.frontier
let validity t = t.validity
let descriptions t = t.descriptions
let merchants t = t.merchants
let original_amounts t = t.original_amounts
let exchanges t = t.exchanges
let reversals t = t.reversals
let relations t = t.relations
