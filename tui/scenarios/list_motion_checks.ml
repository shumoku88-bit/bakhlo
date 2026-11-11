(* Lists longer than their pane keep their painted rows while the cursor moves inside
   them: from the end, k moves the marker up and the list stays put. *)
open Interaction_check_fixture

let count = 14
let day = "2026-10-01"

let book_text =
  let lines f = String.concat "" (List.init count f) in
  "BOOK\t1\nMEASURE\tjpy\t0\n"
  ^ lines (fun i -> Printf.sprintf "LOCUS\tlocus-%02d\tLocus %02d\t\n" i i)
  ^ lines (fun i ->
      Printf.sprintf
        "TX\ttx-%02d\t%s\tDESC\tsynthetic %02d\n\
         EFFECT\tlocus-00\tjpy\t%d\n\
         EFFECT\tlocus-01\tjpy\t-%d\n\
         ENDTX\n"
        i day i (i + 1) (i + 1))
  ^ lines (fun i -> Printf.sprintf "ITEM\tattention-%02d\tNO_DUE_DATE\t-\tmatter-%02d\n" i i)
  ^ "END\n"

(* The painted list frame with the selection marker blanked. *)
let list_frame ~width_of dimensions state =
  let rows = List.map snd (R.screen ~width_of dimensions state) in
  let rec from = function
    | [] -> []
    | row :: rest -> if String.starts_with ~prefix:"╭" row then row :: upto rest else from rest
  and upto = function
    | [] -> []
    | row :: rest -> if String.starts_with ~prefix:"╰" row then [ row ] else row :: upto rest
  in
  List.map
    (fun row ->
      if String.starts_with ~prefix:"│ > " row then "│   " ^ String.sub row 6 (String.length row - 6)
      else row)
    (from rows)

let run ~width_of ~directory () =
  let dir = directory ^ "/list-motion" in
  Unix.mkdir dir 0o700;
  let path = dir ^ "/book.txt" in
  F.write_new path book_text;
  let home = C.initial ~config_home:dir (F.load path) in
  (* Commitments are kept beside the book; add them as the user would. *)
  let add state i =
    let adding = key ~width_of state (`ASCII 'n') in
    match visible_form adding with
    | Some f ->
        let f = Ui_form.set_text f "label" (Printf.sprintf "commitment %02d" i) in
        let f = Ui_form.set_text f "amount" (string_of_int (100 + i)) in
        key ~width_of (with_visible_form adding (Ui_form.set_focused f 5)) `Enter
    | None -> failwith "expected the add-commitment form"
  in
  let settlements = List.fold_left add (C.open_route home W.Settlements) (List.init count Fun.id) in
  require (List.length (settlement_rows settlements) = count) "list-motion-commitments-added";
  let dimensions = (60, 12) in
  let to_end state = key ~dimensions ~width_of state `End in
  (* Settlements' End goes to the first row (LOAM); j walks to the last one. *)
  let walk_to_end state =
    List.fold_left
      (fun s _ -> key ~dimensions ~width_of s (`ASCII 'j'))
      state (List.init count Fun.id)
  in
  List.iter
    (fun (label, state, reach_end) ->
      let ended = reach_end state in
      let up = key ~dimensions ~width_of ended (`ASCII 'k') in
      let before = list_frame ~width_of dimensions ended
      and after = list_frame ~width_of dimensions up in
      require
        (List.length before > 2
        && before = after
        && List.map snd (R.screen ~width_of dimensions ended)
           <> List.map snd (R.screen ~width_of dimensions up))
        (label ^ "-list-stays-put-when-cursor-moves-back-from-end"))
    [
      ("loci", C.open_route home W.Loci, to_end);
      ("attention", C.open_route home W.Attention, to_end);
      ("selected-day", C.open_route home (W.Selected_day day), to_end);
      ("settlements", settlements, walk_to_end);
    ];
  (* Attention's column heading scrolls away with the list and is back at the first item. *)
  let attention_ended = to_end (C.open_route home W.Attention) in
  let heading state = contains (R.screen ~width_of dimensions state) "Matter / Context" in
  require
    ((not (heading attention_ended)) && heading (key ~dimensions ~width_of attention_ended `Home))
    "attention-heading-returns-with-the-first-item";
  print_endline
    "PASS: Loci, Attention, Selected Day and Settlements lists keep their rows while the cursor \
     moves back from the end (synthetic)."
