(* What every read-only bk command shows on one synthetic household year, printed
   in full so that a change to any view shows up as a diff against views.expected:

     $ bk reg wallet 2026-10
                               change  balance
       2026-10-01  ATM    Bank  +20,000   ...

   The year is generated, never copied from a household (as FFmpeg's first
   regression test generated its own pictures and sounds instead of shipping
   real streams), and it is the same on every run: no clock, no randomness.
   views.expected is what Bakhlo showed, not an independent answer; the hand-built
   lines in line_commands_checks.ml and the samples in test/ say what is right.
   After an intended change, read the diff and accept it with `dune promote`. *)
module F = Book_file
module L = Line_commands

let today = "2026-11-08"

(* Days from 2025-11-01 to 2027-02-28; neither year is a leap year. *)
let month_days = [| 31; 28; 31; 30; 31; 30; 31; 31; 30; 31; 30; 31 |]

let days =
  let rec go y m d acc =
    if (y, m) > (2027, 2) then List.rev acc
    else
      let next =
        if d = month_days.(m - 1) then if m = 12 then (y + 1, 1, 1) else (y, m + 1, 1)
        else (y, m, d + 1)
      in
      let y', m', d' = next in
      go y' m' d' ((y, m, d) :: acc)
  in
  go 2025 11 1 []

let date (y, m, d) = Printf.sprintf "%04d-%02d-%02d" y m d

(* The year as book.txt: records in the order they were made, then plans,
   then where balances are known from, then the household's matters. *)
let book () =
  let b = Buffer.create 65536 in
  let line fields = Buffer.add_string b (String.concat "\t" fields ^ "\n") in
  let txs = Buffer.create 65536 in
  let n = ref 0 in
  let tx ?(extra = []) day memo effects =
    incr n;
    let id = Printf.sprintf "tx-%04d" !n in
    let add fields = Buffer.add_string txs (String.concat "\t" fields ^ "\n") in
    add [ "TX"; id; day; "DESC"; memo ];
    List.iter (fun (locus, measure, q) -> add [ "EFFECT"; locus; measure; string_of_int q ]) effects;
    List.iter add extra;
    add [ "ENDTX" ];
    id
  in
  let jpy locus q = (locus, "jpy", q) in
  let paid = Hashtbl.create 32 in
  let card = ref 0 and refunded = ref None in
  List.iteri
    (fun i ((_, m, d) as ymd) ->
      let day = date ymd in
      if day <= today then begin
        if d = 1 then ignore (tx day "ATM" [ jpy "bank" (-20000); jpy "wallet" 20000 ]);
        if d = 10 && !card > 0 then begin
          ignore (tx day "card bill" [ jpy "bank" (- !card); jpy "card" !card ]);
          card := 0
        end;
        if d = 20 then
          Hashtbl.replace paid ("phone", day)
            (tx day "phone bill" [ jpy "bank" (-3000); jpy "phone" 3000 ]);
        if d = 25 then ignore (tx day "salary" [ jpy "salary" (-300000); jpy "bank" 300000 ]);
        if d = 27 then
          Hashtbl.replace paid ("rent", day)
            (tx day "rent" [ jpy "bank" (-80000); jpy "rent" 80000 ]);
        if i mod 2 = 0 then begin
          let q = 300 + (i * 137 mod 1200 / 10 * 10) in
          let memo = [| "lunch"; "groceries"; "coffee"; "bakery" |].(i / 2 mod 4) in
          let extra = if i mod 14 = 0 then [ [ "MERCHANT"; "corner-shop" ] ] else [] in
          ignore (tx ~extra day memo [ jpy "wallet" (-q); jpy "food" q ])
        end;
        if i mod 7 = 3 then begin
          let q = 1000 + (i * 53 mod 4000 / 10 * 10) in
          let id = tx day "online order" [ jpy "card" (-q); jpy "food" q ] in
          card := !card + q;
          if m = 9 && !refunded = None then refunded := Some (id, q)
        end;
        match day with
        | "2026-08-03" ->
            ignore
              (tx
                 ~extra:[ [ "EXCHANGE"; "jpy"; "usd" ] ]
                 day "exchange at the airport"
                 [ jpy "bank" (-16000); ("usd-cash", "usd", 10000) ])
        | "2026-08-05" ->
            ignore (tx day "museum" [ ("usd-cash", "usd", -2500); ("travel", "usd", 2500) ])
        | "2026-08-06" ->
            card := !card + 6100;
            ignore
              (tx
                 ~extra:[ [ "ORIGINAL"; "usd"; "4000" ] ]
                 day "hotel"
                 [ jpy "card" (-6100); jpy "travel" 6100 ])
        | "2026-09-25" -> (
            match !refunded with
            | Some (id, q) ->
                card := !card - q;
                ignore
                  (tx
                     ~extra:[ [ "REVERSAL-OF"; id ] ]
                     day "online order returned"
                     [ jpy "card" q; jpy "food" (-q) ])
            | None -> ())
        | _ -> ()
      end)
    days;
  line [ "BOOK"; "1" ];
  line [ "MEASURE"; "jpy"; "0" ];
  line [ "MEASURE"; "usd"; "2" ];
  let loci =
    [
      ("wallet", "Wallet", "ASSET");
      ("bank", "Bank", "ASSET");
      ("card", "カード", "LIABILITY");
      ("usd-cash", "USD cash", "ASSET");
      ("salary", "Salary", "INCOME");
      ("food", "Food", "EXPENSE");
      ("rent", "Rent", "EXPENSE");
      ("phone", "Phone", "EXPENSE");
      ("travel", "Travel", "EXPENSE");
      ("insurance", "Insurance", "EXPENSE");
    ]
  in
  List.iter (fun (id, label, _) -> line [ "LOCUS"; id; label; "" ]) loci;
  List.iter (fun (id, _, role) -> line [ "ROLE"; id; role ]) loci;
  Buffer.add_buffer b txs;
  (* Monthly plans for rent and the phone, three months ahead; the last phone plan
     is cancelled, and the yearly insurance is overdue. *)
  let p = ref 0 in
  let plan ?ending day changes =
    incr p;
    line [ "PLAN"; Printf.sprintf "plan-%04d" !p; day; "jpy" ];
    List.iter (fun (locus, q) -> line [ "CHANGE"; locus; string_of_int q ]) changes;
    Option.iter line ending;
    line [ "ENDPLAN" ]
  in
  List.iter
    (fun ((_, _, d) as ymd) ->
      let day = date ymd in
      let series name amount =
        let ending =
          match Hashtbl.find_opt paid (name, day) with
          | Some id -> Some [ "PAID-BY"; id ]
          | None ->
              if name = "phone" && day = "2027-02-20" then Some [ "CANCELLED"; "2026-11-01" ]
              else None
        in
        plan ?ending day [ ("bank", -amount); (name, amount) ]
      in
      if d = 20 then series "phone" 3000;
      if d = 27 then series "rent" 80000)
    days;
  plan "2026-11-05" [ ("bank", -12000); ("insurance", 12000) ];
  List.iter
    (fun (locus, measure) -> line [ "ZERO-ORIGIN"; locus; measure ])
    [ ("wallet", "jpy"); ("bank", "jpy"); ("card", "jpy"); ("usd-cash", "usd") ];
  line [ "ITEM"; "attention-1"; "DUE_ON"; "2026-11-30"; "renew the passport" ];
  line [ "ITEM"; "attention-2"; "NO_DUE_DATE"; "-"; "tax return" ];
  line [ "ITEM"; "attention-3"; "DUE_ON"; "2026-10-01"; "bike repair" ];
  line [ "ITEM"; "attention-4"; "DUE_ON"; "2026-11-01"; "call the bank" ];
  line [ "CLOSE"; "attention-3"; "2026-10-03"; "RESOLVED" ];
  line [ "END" ];
  Buffer.contents b

let settings =
  [
    ("daily-pace.tsv", "wallet\tjpy\nbank\tjpy\n");
    ( "boundary-presets.tsv",
      "pay\t2025-10-25\t2025-11-25\t2025-12-25\t2026-01-25\t2026-02-25\t2026-03-25\t2026-04-25\t2026-05-25\t2026-06-25\t2026-07-25\t2026-08-25\t2026-09-25\t2026-10-25\t2026-11-25\t2026-12-25\t2027-01-25\n"
    );
    ("balance-view.tsv", "wallet\tjpy\nbank\tjpy\ncard\tjpy\nusd-cash\tusd\n");
    ( "scheduled-coverage.tsv",
      "rent\t2025-11-27\t1\tbank\trent\nphone\t2025-11-20\t1\tbank\tphone\n" );
  ]

(* Each command as typed after `bk`, read by the same words bk reads. *)
let views =
  [
    [ "pace" ];
    [ "pace"; "if"; "-5000" ];
    [ "bal" ];
    [ "plans" ];
    [ "loci" ];
    [ "todo" ];
    [ "day" ];
    [ "day"; "2026-08-06" ];
    [ "find"; "lunch"; "2026-10" ];
    [ "find"; "amt:5000.." ];
    [ "find"; "acct:travel" ];
    [ "reg"; "wallet"; "2026-10" ];
    [ "reg"; "card" ];
    [ "reg"; "usd-cash" ];
    [ "month" ];
    [ "month"; "2026" ];
    [ "report"; "ie" ];
    [ "report"; "ie"; "2026-08" ];
  ]

let () =
  (* The writer refuses symlinked components; macOS temporary directories are links. *)
  let dir = Unix.realpath (Filename.temp_dir "bakhlo-views" "") in
  let write name text =
    Out_channel.with_open_bin (Filename.concat dir name) (fun c -> Out_channel.output_string c text)
  in
  let text = book () in
  write "book.txt" text;
  List.iter (fun (name, text) -> write name text) settings;
  let path = Filename.concat dir "book.txt" in
  List.iter
    (fun words ->
      print_string ("$ bk " ^ String.concat " " words ^ "\n");
      match Command_line.line_command words with
      | None -> print_string "(not a bk command)\n"
      | Some command ->
          let io = { L.read = (fun () -> None); print = print_string } in
          ignore (L.run io command (F.load path) ~today);
          print_string "\n")
    views;
  if F.read path <> text then failwith "a view changed the book";
  List.iter (fun name -> Sys.remove (Filename.concat dir name)) ("book.txt" :: List.map fst settings);
  Unix.rmdir dir
