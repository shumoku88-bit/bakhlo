open Base

(* Original tokens and list occurrence removal, independent of Domain/product sorting. *)
type change = { locus : string; measure : string; quanta : Z.t }

let inverse changes = List.map changes ~f:(fun c -> { c with quanta = Z.neg c.quanta })

let same a b =
  String.equal a.locus b.locus && String.equal a.measure b.measure && Z.equal a.quanta b.quanta

let rec remove_one wanted = function
  | [] -> None
  | head :: tail ->
      if same wanted head then Some tail
      else Option.map (remove_one wanted tail) ~f:(fun rest -> head :: rest)

let exact target reversal =
  let rec consume remaining = function
    | [] -> List.is_empty remaining
    | head :: tail -> (
        match remove_one head remaining with None -> false | Some rest -> consume rest tail)
  in
  consume (inverse reversal) target

let ordinary changes =
  List.for_all changes ~f:(fun c ->
      (not (Z.equal c.quanta Z.zero))
      && Z.equal Z.zero
           (List.fold changes ~init:Z.zero ~f:(fun total d ->
                if String.equal c.measure d.measure then Z.add total d.quanta else total)))

let unique_endpoints facts =
  let rec scan seen = function
    | [] -> true
    | id :: tail -> (not (List.mem seen id ~equal:Int.equal)) && scan (id :: seen) tail
  in
  scan [] (List.concat_map facts ~f:(fun (target, reversal) -> [ target; reversal ]))

let words () =
  let atoms =
    List.concat_map [ "jpy"; "usd" ] ~f:(fun measure ->
        List.map [ -1; 1 ] ~f:(fun n -> { locus = "here"; measure; quanta = Z.of_int n }))
  in
  let rec length = function
    | 0 -> [ [] ]
    | n ->
        List.concat_map atoms ~f:(fun head ->
            List.map (length (n - 1)) ~f:(fun tail -> head :: tail))
  in
  List.concat_map [ 0; 1; 2; 3 ] ~f:length

let relations () =
  let edges =
    List.concat_map [ 0; 1; 2; 3 ] ~f:(fun target ->
        List.map [ 0; 1; 2; 3 ] ~f:(fun reversal -> (target, reversal)))
  in
  [ [] ]
  @ List.map edges ~f:(fun edge -> [ edge ])
  @ List.concat_map edges ~f:(fun first -> List.map edges ~f:(fun second -> [ first; second ]))
