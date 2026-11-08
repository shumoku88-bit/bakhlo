(* `bk r` and `bk pay` against a synthetic book, with scripted answers. *)
module F = Book_file
module L = Line_commands

let require condition name = if not condition then failwith name

let book_text =
  String.concat "\n"
    [
      "BOOK\t1";
      "MEASURE\tjpy\t0";
      "LOCUS\twallet\tWallet\t";
      "LOCUS\twater\tWater\t";
      "LOCUS\tfood\tFood\t";
      "LOCUS\tbank\tBank\t";
      "TX\tt1\t2026-11-01\tDESC\tlunch";
      "EFFECT\twallet\tjpy\t-900";
      "EFFECT\tfood\tjpy\t900";
      "ENDTX";
      "PLAN\trent-11\t2026-11-05\tjpy";
      "CHANGE\tbank\t-80000";
      "CHANGE\tfood\t80000";
      "ENDPLAN";
      "PLAN\tphone-11\t2026-11-20\tjpy";
      "CHANGE\tbank\t-3000";
      "CHANGE\twater\t3000";
      "ENDPLAN";
      "END";
      "";
    ]

let fresh name =
  let path = Filename.concat "scratch" (name ^ ".txt") in
  Out_channel.with_open_bin path (fun c -> Out_channel.output_string c book_text);
  path

(* Answers in order; the printed text is kept for the checks. *)
let script answers =
  let pending = ref answers and out = Buffer.create 256 in
  let read () =
    match !pending with
    | a :: rest ->
        pending := rest;
        Some a
    | [] -> None
  in
  ({ L.read; print = Buffer.add_string out }, out)

let run name command answers =
  let path = fresh name in
  let io, out = script answers in
  let result = L.run io command (F.load path) ~today:"2026-11-08" in
  (result, Buffer.contents out, F.read path)

let contains text fragment = Base.String.is_substring text ~substring:fragment

let run_all () =
  (* A prefix with one Locus is taken; several are numbered; Enter balances. *)
  let result, out, after =
    run "bk-r" `Record [ ""; "ramen"; "wa"; "1"; "-1200"; "fo"; ""; ""; "" ]
  in
  require (result = `Saved) "bk-r-saves";
  require (contains out "  1  wallet  Wallet\n  2  water  Water") "bk-r-numbers-several-loci";
  require (contains out "Amount 2 [+1,200]") "bk-r-offers-the-balancing-amount";
  require
    (contains after
       "2026-11-08\tDESC\tramen\nEFFECT\twallet\tjpy\t-1200\nEFFECT\tfood\tjpy\t1200\nENDTX")
    "bk-r-writes-the-entry";
  (* A memo recorded before offers its rows. *)
  let result, out, after = run "bk-r-again" `Record [ ""; "lunch"; "1"; ""; ""; ""; ""; ""; "" ] in
  require (result = `Saved && contains out "  1  wallet -900  food +900") "bk-r-offers-earlier-rows";
  require
    (contains after "DESC\tlunch\nEFFECT\twallet\tjpy\t-900\nEFFECT\tfood\tjpy\t900\nENDTX\nPLAN")
    "bk-r-reuses-earlier-rows";
  (* A refused amount is worded as on the screen and the rows can be fixed. *)
  let result, out, _ =
    run "bk-r-refused" `Record
      [ ""; "x"; "wallet"; "-abc"; "food"; "+5"; ""; ""; "-5"; ""; ""; ""; "" ]
  in
  require
    (result = `Saved && contains out "Enter a valid exact decimal amount.")
    "bk-r-refusal-then-fix";
  (* End of input or "n" saves nothing. *)
  let result, _, after = run "bk-r-eof" `Record [ ""; "ramen"; "wallet"; "-1"; "food" ] in
  require (result = `Stopped && after = book_text) "bk-r-eof-writes-nothing";
  let result, _, after =
    run "bk-r-no" `Record [ ""; "ramen"; "wallet"; "-1"; "food"; ""; ""; "n" ]
  in
  require (result = `Stopped && after = book_text) "bk-r-no-writes-nothing";
  (* Enter through `bk pay` pays the oldest open plan as planned. *)
  let result, out, after = run "bk-pay" `Pay [ ""; ""; ""; "" ] in
  require
    (result = `Saved && contains out "rent-11  bank -80,000  food +80,000 jpy  overdue")
    "bk-pay-lists-overdue-first";
  require (contains after "CHANGE\tfood\t80000\nPAID-BY\t") "bk-pay-links-the-plan";
  (* `e` edits the plan's rows before saving: another amount still completes it. *)
  let result, _, after =
    run "bk-pay-edit" `Pay [ "ph"; ""; "phone"; "e"; ""; "-2800"; ""; "+2800"; ""; "" ]
  in
  require
    (result = `Saved
    && contains after "EFFECT\tbank\tjpy\t-2800\nEFFECT\twater\tjpy\t2800\nENDTX"
    && contains after "CHANGE\twater\t3000\nPAID-BY\t")
    "bk-pay-edits-then-completes";
  (* A book saved by someone else meanwhile is a conflict, never overwritten. *)
  let path = fresh "bk-conflict" in
  let session = F.load path in
  (match
     F.publish (F.load path)
       [ Bakhlo_household.Book.Cancel_plan { id = "phone-11"; day = "2026-11-08" } ]
   with
  | F.Written _ -> ()
  | _ -> failwith "bk-conflict-setup");
  let changed = F.read path in
  let io, out = script [ ""; "ramen"; "wallet"; "-1"; "food"; ""; ""; "" ] in
  let result = L.run io `Record session ~today:"2026-11-08" in
  require
    (result = `Stopped
    && contains (Buffer.contents out) "The book changed while you were typing"
    && F.read path = changed)
    "bk-r-conflict-writes-nothing";
  print_endline
    "PASS: bk r and bk pay pick Loci and plans, balance rows, reuse earlier rows, word refusals as \
     the screens, and save only after the Preview (EOF, n and conflicts write nothing)."
