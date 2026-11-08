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
      "LOCUS\tcard\tカード\t";
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
      "ZERO-ORIGIN\twallet\tjpy";
      "ZERO-ORIGIN\twater\tjpy";
      "ZERO-ORIGIN\tfood\tjpy";
      "ZERO-ORIGIN\tbank\tjpy";
      "ZERO-ORIGIN\tcard\tjpy";
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
  require (contains out "  1  Wallet\n  2  Water\n") "bk-r-numbers-several-loci";
  require (contains out "Amount 2 [+1,200]") "bk-r-offers-the-balancing-amount";
  require
    (contains after
       "2026-11-08\tDESC\tramen\nEFFECT\twallet\tjpy\t-1200\nEFFECT\tfood\tjpy\t1200\nENDTX")
    "bk-r-writes-the-entry";
  (* A memo recorded before offers its rows. *)
  let result, out, after = run "bk-r-again" `Record [ ""; "lunch"; "1"; ""; ""; ""; ""; ""; "" ] in
  require
    (result = `Saved && contains out "  1  Wallet  -900  Food  +900")
    "bk-r-offers-earlier-rows";
  require
    (contains after "DESC\tlunch\nEFFECT\twallet\tjpy\t-900\nEFFECT\tfood\tjpy\t900\nENDTX\nPLAN")
    "bk-r-reuses-earlier-rows";
  (* Changing the first earlier row makes the last one offer the balance. *)
  let result, out, after =
    run "bk-r-changed" `Record [ ""; "lunch"; "1"; ""; "-1000"; ""; ""; ""; "" ]
  in
  require
    (result = `Saved && contains out "Amount 2 [+1,000]"
    && contains after "DESC\tlunch\nEFFECT\twallet\tjpy\t-1000\nEFFECT\tfood\tjpy\t1000\nENDTX")
    "bk-r-last-earlier-row-balances";
  (* An answer that matches nothing says how to quit and does not reprint the list. *)
  let result, out, after = run "bk-pay-quit" `Pay [ "q" ] in
  require
    (result = `Stopped && after = book_text
    && out
       = "  1  2026-11-05  Bank  -80,000  Food   +80,000  jpy  overdue\n\
         \  2  2026-11-20  Bank   -3,000  Water   +3,000  jpy\n\
          Plan [1]: Nothing matches \"q\". Type a number or the start of a name; Ctrl-D quits.\n\
          Plan [1]: \n\
          Nothing was saved.\n")
    "bk-pay-no-match-asks-again";
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
    (result = `Saved
    && contains out
         "  1  2026-11-05  Bank  -80,000  Food   +80,000  jpy  overdue\n\
         \  2  2026-11-20  Bank   -3,000  Water   +3,000  jpy\n")
    "bk-pay-lists-overdue-first";
  require (contains after "CHANGE\tfood\t80000\nPAID-BY\t") "bk-pay-links-the-plan";
  (* The Preview names the plan by its due day and each row by display name; no IDs. *)
  require
    (contains out
       "\n\
       \  Pays the plan due 2026-11-05\n\
       \  2026-11-08  (no memo)\n\
       \  Bank  -80,000  jpy\n\
       \  Food  +80,000  jpy\n\n\
        Save? (y / n / e to edit) [y]: Saved.\n"
    && (not (contains out "rent-11"))
    && not (contains out "entry-"))
    "bk-pay-preview-without-ids";
  (* `e` edits the plan's rows before saving: another amount still completes it. *)
  let result, _, after =
    run "bk-pay-edit" `Pay [ "wat"; ""; "phone"; "e"; ""; "-2800"; ""; "+2800"; ""; "" ]
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
  (* `bk bal` and `bk pace` print the screens' rows from the book's config files.
     Hand-worked: wallet -900, food +900; the pool (bank 0, wallet -900) less both
     plans before 2026-11-25 (80,000 overdue, 3,000) leaves -83,900 over 17 days:
     -4,935.29â¦ floors to -4,936 a day. *)
  Unix.mkdir "scratch/bk-print" 0o700;
  Unix.mkdir "scratch/bk-print/config" 0o700;
  let write name text =
    Out_channel.with_open_bin name (fun c -> Out_channel.output_string c text)
  in
  write "scratch/bk-print/book.txt" book_text;
  write "scratch/bk-print/config/daily-pace.tsv" "bank\tjpy\nwallet\tjpy\n";
  write "scratch/bk-print/config/boundary-presets.tsv" "pay\t2026-10-25\t2026-11-25\t2026-12-25\n";
  let printed command =
    let io, out = script [] in
    let result = L.run io command (F.load "scratch/bk-print/book.txt") ~today:"2026-11-08" in
    (result, Buffer.contents out)
  in
  let result, out = printed `Balances in
  require
    (result = `Stopped
    && contains out "  Wallet  -900  jpy\n"
    && contains out "  Food    +900  jpy\n"
    && contains out "  カード     0  jpy\n")
    "bk-bal-prints-current-balances";
  (* The ID is shown only when two Loci share a label (a label equal to its ID is the ID). *)
  Unix.mkdir "scratch/bk-names" 0o700;
  write "scratch/bk-names/book.txt"
    "BOOK\t1\n\
     MEASURE\tjpy\t0\n\
     LOCUS\ta\tSame\t\n\
     LOCUS\tb\tSame\t\n\
     LOCUS\tc\tc\t\n\
     ZERO-ORIGIN\ta\tjpy\n\
     ZERO-ORIGIN\tb\tjpy\n\
     ZERO-ORIGIN\tc\tjpy\n\
     END\n";
  let io, out = script [] in
  ignore (L.run io `Balances (F.load "scratch/bk-names/book.txt") ~today:"2026-11-08");
  require
    (Buffer.contents out = "  Same [a]  0  jpy\n  Same [b]  0  jpy\n  c         0  jpy\n")
    "bk-bal-names-loci-by-label";
  let result, out = printed `Pace in
  require
    (result = `Stopped
    && contains out "Daily Pace 2026-11-08  (cycle 2026-10-25 .. 2026-11-25, end excluded)"
    && contains out "-4,936 jpy/day" && contains out "-83,900 free" && contains out "17 days left")
    "bk-pace-prints-the-breakdown";
  require (F.read "scratch/bk-print/book.txt" = book_text) "bk-bal-and-pace-write-nothing";
  (* `bk plans`: a rent series watched monthly, a phone bill due on the 31st and
     salary, on 2026-11-08. Lines are built by hand from the column widths. *)
  let plans_text =
    String.concat "\n"
      [
        "BOOK\t1";
        "MEASURE\tjpy\t0";
        "LOCUS\tbank\tBank\t";
        "LOCUS\trent\tRent\t";
        "LOCUS\tphone\tPhone\t";
        "LOCUS\tsalary\tSalary\t";
        "PLAN\trent-11\t2026-11-27\tjpy";
        "CHANGE\tbank\t-80000";
        "CHANGE\trent\t80000";
        "ENDPLAN";
        "PLAN\trent-12\t2026-12-27\tjpy";
        "CHANGE\tbank\t-80000";
        "CHANGE\trent\t80000";
        "ENDPLAN";
        "PLAN\tphone-10\t2026-10-31\tjpy";
        "CHANGE\tbank\t-3000";
        "CHANGE\tphone\t3000";
        "ENDPLAN";
        "PLAN\tsal-11\t2026-11-25\tjpy";
        "CHANGE\tsalary\t-300000";
        "CHANGE\tbank\t300000";
        "ENDPLAN";
        "END";
        "";
      ]
  in
  let plans name action answers =
    let dir = "scratch/" ^ name in
    Unix.mkdir dir 0o700;
    Unix.mkdir (dir ^ "/config") 0o700;
    write (dir ^ "/book.txt") plans_text;
    write (dir ^ "/config/scheduled-coverage.tsv") "Rent\t2026-11-27\t1\tbank\trent\n";
    let io, out = script answers in
    let result = L.run io (`Plans action) (F.load (dir ^ "/book.txt")) ~today:"2026-11-08" in
    (result, Buffer.contents out, F.read (dir ^ "/book.txt"))
  in
  let result, out, after = plans "bk-plans" `List [] in
  require
    (result = `Stopped && after = plans_text
    && out
       = "     to     from     amount       next        last        open\n\
         \  1  Phone  Bank      3,000  jpy  2026-10-31  2026-10-31     1  overdue\n\
         \  2  Bank   Salary  300,000  jpy  2026-11-25  2026-11-25     1\n\
         \  3  Rent   Bank     80,000  jpy  2026-11-27  2026-12-27     2  monthly, missing 2027-01\n"
    )
    "bk-plans-lists-series";
  (* More: the 31st has no November, so the person dates it. *)
  let result, out, after = plans "bk-plans-more" `More [ "Ph"; ""; ""; "2026-11-30"; "" ] in
  require
    (result = `Saved
    && contains out "2026-11 has no day 31."
    && contains out
         "  New plans\n\
         \  2026-11-30  Bank  -3,000  Phone  +3,000\n\
         \  2026-12-31  Bank  -3,000  Phone  +3,000\n\
         \  2027-01-31  Bank  -3,000  Phone  +3,000\n"
    && List.for_all
         (fun day ->
           contains after ("\t" ^ day ^ "\tjpy\nCHANGE\tbank\t-3000\nCHANGE\tphone\t3000"))
         [ "2026-11-30"; "2026-12-31"; "2027-01-31" ])
    "bk-plans-more-fills-and-asks-missing-days";
  (* Amount: from a day on, two-row plans get the new amount. *)
  let result, out, after = plans "bk-plans-amount" `Amount [ "Re"; "2026-12-01"; "85,000"; "" ] in
  require
    (result = `Saved
    && contains out "  New amount 85,000 from 2026-12-01\n  2026-12-27  80,000  ->  85,000  jpy\n"
    && contains after "PLAN\trent-12\t2026-12-27\tjpy\nCHANGE\tbank\t-85000\nCHANGE\trent\t85000"
    && contains after "PLAN\trent-11\t2026-11-27\tjpy\nCHANGE\tbank\t-80000")
    "bk-plans-amount-changes-from-a-day";
  let result, out, after = plans "bk-plans-same" `Amount [ "Re"; ""; "80000" ] in
  require
    (result = `Stopped && contains out "Every plan already has that amount." && after = plans_text)
    "bk-plans-amount-unchanged-writes-nothing";
  (* Cancel: chosen plans only, on the given day. *)
  let result, _, after = plans "bk-plans-cancel" `Cancel [ "Re"; "2"; ""; "" ] in
  require
    (result = `Saved
    && contains after
         "PLAN\trent-12\t2026-12-27\tjpy\n\
          CHANGE\tbank\t-80000\n\
          CHANGE\trent\t80000\n\
          CANCELLED\t2026-11-08\n\
          ENDPLAN"
    && contains after
         "PLAN\trent-11\t2026-11-27\tjpy\nCHANGE\tbank\t-80000\nCHANGE\trent\t80000\nENDPLAN")
    "bk-plans-cancel-cancels-chosen-plans";
  print_endline
    "PASS: bk r, pay, bal, pace and plans: pick Loci, plans and series, balance rows, reuse \
     earlier rows, fill, re-price and cancel series, word refusals as the screens, and save only \
     after the Preview (EOF, n and conflicts write nothing)."
