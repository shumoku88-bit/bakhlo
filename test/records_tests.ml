module B = Bakhlo_household.Book
module R = Bakhlo_household.Record
open Samples

let money = Z.to_string

let entry_lines (e : B.entry) =
  row ([ "TX"; e.id; e.day ] @ match e.memo with None -> [] | Some memo -> [ "DESC"; memo ])
  :: List.map
       (fun (p : B.posting) ->
         row
           ([ "EFFECT"; p.locus; p.measure; money p.amount ]
           @ match p.key with None -> [] | Some key -> [ key ]))
       e.effects
  @ (match e.reversal_of with None -> [] | Some id -> [ "REVERSAL-OF\t" ^ id ])
  @ (match e.original_amount with None -> [] | Some (m, q) -> [ row [ "ORIGINAL"; m; money q ] ])
  @ (match e.merchant with
    | None -> []
    | Some B.Nonmerchant -> [ "NONMERCHANT" ]
    | Some (B.Merchant name) -> [ "MERCHANT\t" ^ name ])
  @ (match e.exchange with None -> [] | Some (s, d) -> [ row [ "EXCHANGE"; s; d ] ])
  @ [ "ENDTX" ]

let form_lines = function
  | Error why -> [ "REFUSED\t" ^ why ]
  | Ok (draft : R.t) ->
      ("MEASURE\t" ^ draft.measure)
      :: List.map
           (fun (r : R.row) ->
             row
               [
                 "ROW";
                 Option.value ~default:"-" r.key;
                 r.locus;
                 (if r.negative then "-" else "") ^ r.amount;
               ])
           draft.rows

let value key input = match values key input with [ v ] -> v | _ -> bad ("one " ^ key ^ " line")

(* OPEN asks what a form opens with; FORM asks what a filled form becomes. *)
let answer use (q : question) =
  let book =
    match context use "BOOK" with
    | Some name -> ( match B.read (read "records" name) with Ok b -> b | Error why -> bad why)
    | None -> bad "USE BOOK required"
  in
  let entry id = match B.find_entry book id with Some e -> e | None -> bad ("entry " ^ id) in
  match q.header with
  | [ "OPEN"; "ENTRY"; id ] -> row q.header :: form_lines (R.open_edit ~book (entry id))
  | [ "OPEN"; "PLAN"; id ] -> (
      match List.find_opt (fun (p : B.plan) -> p.id = id) (B.plans book) with
      | Some plan -> row q.header :: form_lines (R.open_plan ~book plan)
      | None -> bad ("plan " ^ id))
  | [ "FORM"; mode; target; fresh ] ->
      let input, _ = split_at (fun fs -> fs = [ "ENDINPUT" ]) q.body in
      let mode =
        match mode with
        | "NEW" -> R.New
        | "EDIT" -> R.Edit (entry target)
        | "PAY" -> R.Pay target
        | other -> bad ("form mode " ^ other)
      in
      let rows =
        List.filter_map
          (fun line ->
            match fields line with
            | [ "ROW"; key; locus; amount ] ->
                Some { R.key = (if key = "-" then None else Some key); locus; amount }
            | _ -> None)
          input
      in
      let original_amount =
        List.find_map
          (fun line ->
            match fields line with [ "ORIGINAL"; m; q ] -> Some (m, Z.of_string q) | _ -> None)
          input
      in
      let editing = match mode with R.Edit e -> Some e | R.New | R.Pay _ -> None in
      let content =
        {
          R.day = value "DAY" input;
          memo = value "MEMO" input;
          draft = R.form ~editing ~measure:(value "MEASURE" input) rows;
          original_amount;
        }
      in
      let result =
        match R.build_transaction ~new_id:(fun () -> fresh) ~book ~mode content with
        | Error why -> [ "REFUSED\t" ^ R.code why ]
        | Ok tx ->
            row
              [
                "RESULT";
                (if tx.replace then "REPLACE" else "NEW");
                Option.value ~default:"-" tx.plan;
              ]
            :: entry_lines tx.entry
      in
      (row q.header :: input) @ ("ENDINPUT" :: result)
  | _ -> bad ("question " ^ row q.header)

let%expect_test "Record form samples use only the household core" =
  let counts = create () in
  check counts ~dir:"records" ~file:"forms.answers" ~blocks:[ "OPEN"; "FORM" ] ~answer;
  Printf.printf "%d OPEN, %d FORM, %d failures\n" (counted counts "OPEN") (counted counts "FORM")
    counts.failures;
  [%expect {| 10 OPEN, 18 FORM, 0 failures |}]
