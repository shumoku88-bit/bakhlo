open Base
module Graph = Lineage_model

(* Test-only integer/list specification. Admissible pairs come from the independent
   closure model; cut validation uses original list prefixes, not production sets. *)
type error =
  | Duplicate_root of { id : int; first_position : int; position : int }
  | Unknown_event of { id : int; position : int }
  | Not_root of { id : int; position : int }

let select ~reflected pairs =
  List.filter pairs ~f:(fun (root, _) -> not (List.mem reflected root ~equal:Int.equal))
;;

let cut ~nodes ~pairs ~reflected =
  let error = List.find_mapi reflected ~f:(fun i id ->
    let position = i + 1 in
    match List.findi (List.take reflected i) ~f:(fun _ previous -> Int.equal previous id) with
    | Some (first, _) -> Some (Duplicate_root { id; first_position = first + 1; position })
    | None ->
      if List.exists pairs ~f:(fun (root, _) -> Int.equal root id) then None
      else if List.mem nodes id ~equal:Int.equal then Some (Not_root { id; position })
      else Some (Unknown_event { id; position }))
  in
  match error with
  | Some error -> Error error
  | None -> Ok (select ~reflected pairs)
;;

let declaration_of_mask nodes mask =
  List.filteri nodes ~f:(fun i _ -> not (Int.equal (mask land (1 lsl i)) 0))
;;
