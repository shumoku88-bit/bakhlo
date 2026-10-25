(* Ledger (the book on book.txt) against Daily_book on the same random operations:
   both admit or both refuse, and an admitted step leaves the same book.txt bytes,
   entries, plans, balances with their support, and Daily Pace. Differing refusal
   reasons are listed for review. *)
open Base
module B = Bakhlo_sexp.Daily_book
module L = Bakhlo_sexp.Ledger
module X = Bakhlo_sexp.Daily_txt
module T = Bakhlo_book_txt.Book_txt
module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query
module O = Daily_book_oracle_tests
module R = Stdlib.Random.State

let get = function Ok x -> x | Error why -> failwith why

let ledger_of_txt text =
  match T.read text with Ok b -> get (L.of_txt b) | Error e -> failwith (T.code_name e.code)

let old_answer book (l, m) =
  match Q.query (B.image book) (O.coordinate l m) with
  | Ok x ->
      let support =
        match Q.premise x with
        | Q.Zero_origin -> "zero-origin"
        | Q.Opening o -> "opening " ^ D.Identifier.Event.to_string o.opening_event
        | Q.Current_assertion _ -> "counted"
      in
      Printf.sprintf "%s (%s)" (Z.to_string (D.Quantity.quanta (Q.quantity x))) support
  | Error _ -> "unknown"

let new_answer ledger (l, m) =
  match L.quantity ledger ~locus:l ~measure:m with
  | Some q ->
      let support =
        match q.support with T.Zero_origin -> "zero-origin" | T.Opening tx -> "opening " ^ tx | T.Counted _ -> "counted"
      in
      Printf.sprintf "%s (%s)" (Z.to_string q.amount) support
  | None -> "unknown"

let pace_of daily_pace book =
  match daily_pace book with
  | Ok (p : B.daily_pace) -> Z.to_string p.daily_pace_quanta
  | Error why -> "refused " ^ why

let compare_books ~seed ~step ~trace old ledger =
  let check = O.check ~seed ~step ~trace in
  check "book.txt bytes" (O.text_of old) (T.print (L.txt ledger));
  check "entries" (Sexplib0.Sexp.to_string (Sexplib0.Sexp.Atom (Int.to_string (B.entry_count old))))
    (Sexplib0.Sexp.to_string (Sexplib0.Sexp.Atom (Int.to_string (L.entry_count ledger))));
  if not (Poly.equal (B.entries old) (L.entries ledger)) then check "entry records" "old" "new";
  if not (Poly.equal (B.plans old) (L.plans ledger)) then check "plan records" "old" "new";
  let coordinates =
    List.concat_map (Array.to_list O.loci) ~f:(fun l -> List.map [ "jpy"; "usd" ] ~f:(fun m -> (l, m)))
  in
  List.iter coordinates ~f:(fun c -> check ("balance " ^ fst c ^ "/" ^ snd c) (old_answer old c) (new_answer ledger c));
  let days = [ "2026-09-30"; "2026-10-01"; "2026-10-03"; "2026-10-09"; "2026-10-31" ] in
  let show = function Ok n -> Z.to_string n | Error why -> "refused " ^ why in
  let pools label old_book ledger_book pool =
    check label
      (String.concat ~sep:"," (List.map (B.pools_at_end_of_days old_book ~measure:"jpy" ~pool ~days) ~f:show))
      (String.concat ~sep:"," (List.map (L.pools_at_end_of_days ledger_book ~measure:"jpy" ~pool ~days) ~f:show))
  in
  pools "zero-origin pool" old ledger [ O.coordinate "food" "jpy" ];
  (match
     ( B.with_bounded_history old [ ("wallet", "jpy", "2026-10-02") ],
       L.with_bounded_history ledger [ ("wallet", "jpy", "2026-10-02") ] )
   with
  | Ok o, Ok l -> pools "bounded pool" o l [ O.coordinate "wallet" "jpy"; O.coordinate "food" "jpy" ]
  | Error a, Error b -> check "bounded history refusal" a b
  | Ok _, Error why -> check "bounded history" "admitted" ("refused " ^ why)
  | Error why, Ok _ -> check "bounded history" ("refused " ^ why) "admitted");
  let pool = [ O.coordinate "wallet" "jpy" ] in
  List.iter [ ("2026-10-15", "2026-11-01"); ("2026-10-28", "2026-11-30") ] ~f:(fun (observed_at, end_exclusive) ->
      check ("daily pace " ^ observed_at)
        (pace_of (fun b -> B.daily_pace b ~measure:"jpy" ~pool ~observed_at ~end_exclusive) old)
        (match L.daily_pace ledger ~measure:"jpy" ~pool ~observed_at ~end_exclusive with
        | Ok p -> Z.to_string p.daily_pace_quanta
        | Error why -> "refused " ^ why))

let%expect_test "Ledger admits, refuses and answers like Daily_book" =
  let reasons = Hashtbl.create (module String) and admitted = ref 0 and refused = ref 0 in
  (* From the fixture, and from it with wallet and bank no longer offered. *)
  for seed = 1 to 300 do
    let st = R.make [| seed |] in
    let fixture = if seed > 200 then O.hidden_fixture else O.fixture in
    let old = ref (O.book_of_txt fixture) and ledger = ref (ledger_of_txt fixture) in
    let trace = ref [] in
    for step = 1 to 30 do
      let ops = List.init (if O.chance st 6 then 3 else if O.chance st 4 then 2 else 1) ~f:(fun _ -> O.generate st !old) in
      trace := String.concat ~sep:" + " (List.map ops ~f:O.describe) :: !trace;
      match (Bakhlo_sexp.Book_log.apply_all !old ops, L.apply_all !ledger ops) with
      | Ok o, Ok l -> (
          match X.to_text o X.no_sidecars with
          | Error _ -> Int.incr refused (* the old book could not have been saved *)
          | Ok _ ->
              Int.incr admitted;
              compare_books ~seed ~step ~trace:!trace o l;
              old := o;
              ledger := l)
      | Error a, Error b ->
          Int.incr refused;
          if not (String.equal a b) then Hashtbl.incr reasons (a ^ " -> " ^ b)
      | Ok o, Error why -> (
          match X.to_text o X.no_sidecars with
          | Error _ -> Hashtbl.incr reasons ("unsaveable -> " ^ why)
          | Ok _ -> O.check ~seed ~step ~trace:!trace "only Daily_book admits" "admitted" ("refused " ^ why))
      | Error why, Ok _ -> O.check ~seed ~step ~trace:!trace "only Ledger admits" ("refused " ^ why) "admitted"
    done
  done;
  Stdio.printf "admitted: %b; refused: %b\n" (!admitted > 1000) (!refused > 100);
  Hashtbl.iteri reasons ~f:(fun ~key ~data -> Stdio.printf "different reason: %s (%d)\n" key data);
  [%expect {| admitted: true; refused: true |}]

(* Cases the random operations do not reach: offering a hidden Locus again, and an
   overdue plan that drains the pool. *)
let%expect_test "Ledger re-offers a hidden Locus and counts overdue plans like Daily_book" =
  let old = O.book_of_txt O.hidden_fixture and ledger = ledger_of_txt O.hidden_fixture in
  let o = get (B.add_locus old "wallet") and l = get (L.add_locus ledger "wallet") in
  Stdio.printf "same book.txt: %b\n" (String.equal (O.text_of o) (T.print (L.txt l)));
  let plan : B.plan =
    {
      id = "overdue";
      day = "2026-10-05";
      measure = "jpy";
      changes = [ ("wallet", Z.of_int (-700)); ("expense", Z.of_int 700) ];
      paid_by = None;
      cancelled_on = None;
    }
  in
  let old = get (B.put_plan (O.book_of_txt O.fixture) ~replace:false plan)
  and ledger = get (L.put_plan (ledger_of_txt O.fixture) ~replace:false plan) in
  let pool = [ O.coordinate "wallet" "jpy" ] in
  let old_pace = get (B.daily_pace old ~measure:"jpy" ~pool ~observed_at:"2026-10-15" ~end_exclusive:"2026-11-01")
  and new_pace = get (L.daily_pace ledger ~measure:"jpy" ~pool ~observed_at:"2026-10-15" ~end_exclusive:"2026-11-01") in
  Stdio.printf "same pace: %b (%s)\n"
    (Z.equal old_pace.daily_pace_quanta new_pace.daily_pace_quanta)
    (Z.to_string new_pace.daily_pace_quanta);
  [%expect {|
    same book.txt: true
    same pace: true (2900)
    |}]
