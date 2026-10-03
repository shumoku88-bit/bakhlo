open Base

(* Original tokens/lists and Zarith arithmetic only, no Domain/Application dependency. *)
type change = { key : string option; measure : string; quanta : Z.t }
type claim = { source : string; destination : string }
let sum changes measure =
  List.fold changes ~init:Z.zero ~f:(fun total change ->
    if String.equal change.measure measure then Z.add total change.quanta else total)
;;
let admitted changes { source; destination } =
  let find key = List.find changes ~f:(fun change -> Option.equal String.equal change.key (Some key)) in
  match find source, find destination with
  | Some source, Some destination ->
    not (String.equal source.measure destination.measure)
    && Z.sign source.quanta < 0 && Z.sign destination.quanta > 0
    && List.for_all changes ~f:(fun change ->
      String.equal change.measure source.measure || String.equal change.measure destination.measure)
    && Z.sign (sum changes source.measure) < 0 && Z.sign (sum changes destination.measure) > 0
  | None, _ | _, None -> false
;;
let nonzero changes = List.for_all changes ~f:(fun change -> not (Z.equal change.quanta Z.zero))
let ordinary changes =
  nonzero changes && List.for_all changes ~f:(fun change -> Z.equal (sum changes change.measure) Z.zero)
;;
let selected = { source = "source"; destination = "destination" }
let measures = [ "jpy"; "usd" ]
let extras = None :: List.concat_map (measures @ [ "eur" ]) ~f:(fun measure ->
  List.map [ -2; -1; 0; 1; 2 ] ~f:(fun quantity -> Some { key = None; measure; quanta = Z.of_int quantity }))
let shapes () =
  List.concat_map measures ~f:(fun source_measure ->
    List.concat_map [ -1; 0; 1 ] ~f:(fun source_quantity ->
      List.concat_map measures ~f:(fun destination_measure ->
        List.concat_map [ -1; 0; 1 ] ~f:(fun destination_quantity ->
          List.concat_map extras ~f:(fun first -> List.map extras ~f:(fun second ->
            [ { key = Some "source"; measure = source_measure; quanta = Z.of_int source_quantity }
            ; { key = Some "destination"; measure = destination_measure; quanta = Z.of_int destination_quantity }
            ] @ List.filter_opt [ first; second ]))))))
;;
