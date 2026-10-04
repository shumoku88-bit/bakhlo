open Base

(* Original tokens/list membership and Zarith only; no Domain/Application/index dependency. *)
type target = { id : string; source : string; quantity : Z.t }
type fact = { event : string; target : string; quantity : Z.t }
let targets =
  [ { id = "r"; source = "a"; quantity = Z.of_int 2 }
  ; { id = "q"; source = "b"; quantity = Z.of_int 2 } ]
let events = [ "a"; "b"; "c"; "d" ]
let total facts target = List.fold facts ~init:Z.zero ~f:(fun sum fact ->
  if String.equal fact.target target then Z.add sum fact.quantity else sum)
let rows facts target = List.filter facts ~f:(fun fact -> String.equal fact.target target)
let admitted events targets facts =
  let rec unique seen = function
    | [] -> true
    | fact :: tail ->
      not (List.exists seen ~f:(fun prior -> String.equal prior.event fact.event && String.equal prior.target fact.target))
      && unique (fact :: seen) tail in
  unique [] facts && List.for_all facts ~f:(fun fact ->
    List.mem events fact.event ~equal:String.equal &&
    match List.find targets ~f:(fun target -> String.equal target.id fact.target) with
    | None -> false
    | Some target ->
      not (String.equal target.source fact.event) && Z.sign fact.quantity > 0
      && Z.leq fact.quantity target.quantity && Z.leq (total facts fact.target) target.quantity)
;;
let remaining targets facts id =
  Option.map (List.find targets ~f:(fun target -> String.equal target.id id))
    ~f:(fun target -> Z.sub target.quantity (total facts id))
;;
let shapes () =
  let choices = None :: List.concat_map (events @ [ "missing" ]) ~f:(fun event ->
    List.concat_map [ "r"; "q"; "unknown" ] ~f:(fun target ->
      List.map [ -1; 0; 1; 2; 3 ] ~f:(fun quantity -> Some { event; target; quantity = Z.of_int quantity }))) in
  List.concat_map choices ~f:(fun first -> List.map choices ~f:(fun second -> List.filter_opt [ first; second ]))
;;
