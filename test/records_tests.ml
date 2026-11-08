module B = Bakhlo_household.Book
module R = Bakhlo_household.Record
module S = Scheduled_tests

let read = S.read "records"
let fields = S.fields
let option = S.option
let money = Z.to_string
let fail why = failwith ("Record sample: " ^ why)
let get = function Ok x -> x | Error why -> fail why

let effects_lines effects =
  List.map
    (fun (p : B.posting) ->
      String.concat "\t"
        ([ "EFFECT"; p.locus; p.measure; money p.amount ]
        @ match p.key with None -> [] | Some key -> [ key ]))
    effects

let entry_lines (e : B.entry) =
  [
    String.concat "\t"
      ([ "TX"; e.id; e.day ] @ match e.memo with None -> [] | Some memo -> [ "DESC"; memo ]);
  ]
  @ effects_lines e.effects
  @ (match e.reversal_of with None -> [] | Some id -> [ "REVERSAL-OF\t" ^ id ])
  @ (match e.original_amount with
    | None -> []
    | Some (m, q) -> [ "ORIGINAL\t" ^ m ^ "\t" ^ money q ])
  @ (match e.merchant with
    | None -> []
    | Some B.Nonmerchant -> [ "NONMERCHANT" ]
    | Some (B.Merchant name) -> [ "MERCHANT\t" ^ name ])
  @ (match e.exchange with None -> [] | Some (s, d) -> [ "EXCHANGE\t" ^ s ^ "\t" ^ d ])
  @ [ "ENDTX" ]

let draft_lines (draft : R.t) =
  ("MEASURE\t" ^ draft.measure)
  :: List.map
       (fun (row : R.row) ->
         String.concat "\t"
           [
             "ROW";
             Option.value ~default:"-" row.key;
             row.locus;
             (if row.negative then "-" else "") ^ row.amount;
           ])
       draft.rows

let entry input = match S.entry_block input with e, [] -> e | _ -> fail "extra TX input"
let book path = get (B.read (read path))
let find_entry book id = match B.find_entry book id with Some e -> e | None -> fail ("entry " ^ id)

let find_plan book id =
  match List.find_opt (fun (p : B.plan) -> p.id = id) (B.plans book) with
  | Some p -> p
  | None -> fail ("plan " ^ id)

let value key input =
  match
    List.find_map
      (fun line -> match fields line with [ k; v ] when k = key -> Some v | _ -> None)
      input
  with
  | Some s -> s
  | None -> fail ("missing " ^ key)

let answer header input =
  let refusal why = [ "REFUSED\t" ^ why ] in
  match fields header with
  | [ "MOVEMENT"; _name ] -> (
      let e = entry (("TX\tprobe\t2027-01-12" :: input) @ [ "ENDTX" ]) in
      match R.movement_fault e.effects with
      | None -> [ "OK" ]
      | Some why -> [ "FAULT\t" ^ R.movement_code why ])
  | [ "EDITABLE"; _name; path ] -> (
      match R.edit_refusal ~book:(book path) (entry input) with
      | None -> [ "OK" ]
      | Some why -> refusal why)
  | [ "POSTINGS"; _name; path ] -> (
      match R.of_effects (book path) (entry input).effects with
      | Ok draft -> draft_lines draft
      | Error why -> refusal why)
  | [ "PAY-DRAFT"; _name; path; id ] -> (
      let book = book path in
      match R.open_plan_draft ~book (find_plan book id) with
      | Ok draft -> draft_lines draft
      | Error why -> refusal why)
  | [ "FORM"; _name; path; mode; target; fresh ] -> (
      let book = book path in
      let mode =
        match mode with
        | "NEW" -> R.New
        | "EDIT" -> R.Edit (find_entry book target)
        | "PAY" -> R.Pay target
        | _ -> fail "form mode"
      in
      let rows =
        List.filter_map
          (fun line ->
            match fields line with
            | [ "ROW"; key; locus; amount ] -> Some { R.key = option key; locus; amount }
            | _ -> None)
          input
      in
      let original_amount =
        List.find_map
          (fun line ->
            match fields line with [ "ORIGINAL"; m; q ] -> Some (m, Z.of_string q) | _ -> None)
          input
      in
      let content =
        let editing = match mode with R.Edit e -> Some e | R.New | R.Pay _ -> None in
        {
          R.day = value "DAY" input;
          memo = value "MEMO" input;
          draft = R.form ~editing ~measure:(value "MEASURE" input) rows;
          original_amount;
        }
      in
      match R.build_transaction ~new_id:(fun () -> fresh) ~book ~mode content with
      | Error why -> refusal (R.code why)
      | Ok tx ->
          String.concat "\t"
            [
              "RESULT"; (if tx.replace then "REPLACE" else "NEW"); Option.value ~default:"-" tx.plan;
            ]
          :: entry_lines tx.entry)
  | _ -> fail ("question " ^ header)

let%expect_test "Record form samples use only the household core" =
  let failures = ref 0 and questions = ref 0 in
  let rec blocks = function
    | [] -> ()
    | header :: rest ->
        let kind = List.hd (fields header) in
        let rec take stop acc = function
          | [] -> fail ("missing " ^ stop)
          | line :: rest when line = stop -> (List.rev acc, rest)
          | line :: rest -> take stop (line :: acc) rest
        in
        let input, rest = take "ENDINPUT" [] rest in
        let want, rest = take ("END" ^ kind) [] rest in
        let got = answer header input in
        incr questions;
        if want <> got then (
          incr failures;
          Printf.printf "FAIL %s:\nwant:\n%s\ngot:\n%s\n" header (String.concat "\n" want)
            (String.concat "\n" got));
        blocks rest
  in
  blocks (S.lines (read "forms.answers"));
  Printf.printf "%d Record answers, %d failures\n" !questions !failures;
  [%expect {| 37 Record answers, 0 failures |}]
