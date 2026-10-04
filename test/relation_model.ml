open Base

(* Original tokens/lists and Zarith only. No Domain/Application or product indexes. *)
type endpoint = Household | External of string
type fact =
  { id : string; event : string; key : string
  ; debtor : endpoint; creditor : endpoint; quantity : Z.t }
type source = { event : string; key : string; quanta : Z.t }
let same_source event key e k = String.equal event e && String.equal key k
let endpoints = function
  | Household, External _ | External _, Household -> true
  | Household, Household | External _, External _ -> false
;;
let unique facts =
  let rec scan seen = function
    | [] -> true
    | (fact : fact) :: tail -> not (List.mem seen fact.id ~equal:String.equal) && scan (fact.id :: seen) tail
  in scan [] facts
;;
let admitted sources facts =
  unique facts && List.for_all facts ~f:(fun (fact : fact) ->
    match List.find sources ~f:(fun source -> same_source fact.event fact.key source.event source.key) with
    | None -> false
    | Some source ->
      let total = List.fold facts ~init:Z.zero ~f:(fun sum other ->
        if same_source fact.event fact.key other.event other.key then Z.add sum other.quantity else sum) in
      endpoints (fact.debtor, fact.creditor) && Z.sign fact.quantity > 0
      && Z.leq fact.quantity (Z.abs source.quanta) && Z.leq total (Z.abs source.quanta))
;;
let sources =
  [ { event = "a"; key = "s"; quanta = Z.of_int (-2) }
  ; { event = "a"; key = "t"; quanta = Z.of_int 2 }
  ; { event = "b"; key = "s"; quanta = Z.of_int 2 } ]
let shapes () =
  let rows = List.concat_map [ "r"; "q" ] ~f:(fun id ->
    List.concat_map [ "a", "s"; "a", "t"; "b", "s"; "missing", "s"; "b", "t" ] ~f:(fun (event, key) ->
      List.concat_map [ Household, External "p"; External "p", Household;
        Household, Household; External "p", External "q" ] ~f:(fun (debtor, creditor) ->
        List.map [ -1; 0; 1; 2; 3 ] ~f:(fun quantity ->
          Some { id; event; key; debtor; creditor; quantity = Z.of_int quantity })))) in
  let slots = None :: rows in
  List.concat_map slots ~f:(fun first -> List.map slots ~f:(fun second -> List.filter_opt [ first; second ]))
;;
