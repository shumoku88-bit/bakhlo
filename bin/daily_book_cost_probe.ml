(* Research-only, synthetic, compiled Daily_book cost probe.
   No production data and no persistence writes. This probe is removed after
   results have been checked and recorded in a short research note. *)

module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query

let get = function Ok x -> x | Error why -> failwith why

let ident name of_string = match of_string name with
  | Ok id -> id
  | Error _ -> failwith ("invalid synthetic identifier: " ^ name)

let posting locus measure amount =
  D.Effect.create
    ~locus:(ident locus D.Identifier.Locus.of_string)
    ~measure:(ident measure D.Identifier.Measure.of_string)
    ~quantity:(D.Quantity.of_quanta (Z.of_int amount))
    ~key:None

let entry id amount : B.entry =
  { id; day = "2026-10-08"; memo = None;
    effects = [posting "wallet" "jpy" (-amount); posting "food" "jpy" amount];
    reversal_of = None; exchange = None }

let coordinate locus measure : D.Effect_coordinate.t =
  { locus = ident locus D.Identifier.Locus.of_string;
    measure = ident measure D.Identifier.Measure.of_string }

let qty book locus measure =
  match Q.query (B.image book) (coordinate locus measure) with
  | Ok (Q.Exact exact) -> D.Quantity.quanta (Q.quantity exact)
  | Ok (Q.Known_present _) -> failwith "unexpected known-present result"
  | Error (Q.Support_unknown _) -> failwith "unexpected unknown result"

let check_balance book count extra =
  if B.entry_count book <> count then
    failwith "entry count mismatch";
  if not (Z.equal (qty book "wallet" "jpy") (Z.of_int (1000 - count - extra))) then
    failwith "wallet quantity mismatch";
  if not (Z.equal (qty book "food" "jpy") (Z.of_int (count + extra))) then
    failwith "food quantity mismatch";
  if not (Z.equal (qty book "wallet" "eur") (Z.of_int 10000)) then
    failwith "unrelated EUR quantity changed"

let median xs =
  match List.sort Float.compare xs with
  | [a; b; c] -> let _ = a and _ = c in b
  | _ -> failwith "three trials required"

let timed label action check =
  let durations = ref [] in
  for _ = 1 to 3 do
    let start = Unix.gettimeofday () in
    let answer = action () in
    let duration = Unix.gettimeofday () -. start in
    check answer;
    durations := duration :: !durations
  done;
  Printf.printf "%s_ms=%.4f\n%!" label (median !durations *. 1000.)

let expect_refusal label inc full =
  match inc, full with
  | Error left, Error right when String.equal left right ->
      Printf.printf "refusal_%s=equal:%s\n%!" label left
  | _ -> failwith ("refusal divergence: " ^ label)

let main n =
  if n < 1 || n > 10000 then
    failwith "benchmark size must be 1..10000";
  let initial =
    In_channel.with_open_text "examples/daily-book.sexp"
      (fun ch -> get (B.of_string (In_channel.input_all ch)))
  in
  if B.entry_count initial <> 0 then failwith "synthetic fixture unexpectedly nonempty";
  Printf.printf "size=%d\n%!" n;
  let book = ref initial in
  let start = Unix.gettimeofday () in
  for i = 1 to n do
    book := get (B.put_entry !book ~replace:false
      (entry (Printf.sprintf "synthetic-%06d" i) 1) ~plan:None)
  done;
  let build_ms = (Unix.gettimeofday () -. start) *. 1000. in
  let base = !book in
  check_balance base n 0;
  Printf.printf "build_incremental_%d_ms=%.4f\n%!" n build_ms;

  let fresh = entry "synthetic-fresh" 1 in
  let inc = get (B.put_entry base ~replace:false fresh ~plan:None) in
  let full = get (B.put_entry_full base ~replace:false fresh ~plan:None) in
  check_balance inc (n + 1) 0;
  check_balance full (n + 1) 0;
  if B.to_string inc <> B.to_string full then
    failwith "fresh append full-oracle bytes differ";
  timed "append_incremental" (fun () ->
    get (B.put_entry base ~replace:false fresh ~plan:None))
    (fun answer -> check_balance answer (n + 1) 0);
  timed "append_full" (fun () ->
    get (B.put_entry_full base ~replace:false fresh ~plan:None))
    (fun answer -> check_balance answer (n + 1) 0);

  let middle = Printf.sprintf "synthetic-%06d" ((n + 1) / 2) in
  let existing = match B.find_entry base middle with
    | Some e -> e
    | None -> failwith "missing selected correction target" in
  let edited = { existing with memo = Some "revised synthetic amount";
    day = "2026-10-09";
    effects = [posting "wallet" "jpy" (-2); posting "food" "jpy" 2] } in
  let corrected = get (B.put_entry base ~replace:true edited ~plan:None) in
  let full_corrected = get (B.put_entry_full base ~replace:true edited ~plan:None) in
  check_balance corrected n 1;
  if B.to_string corrected <> B.to_string full_corrected then
    failwith "correction full-oracle bytes differ";
  timed "correct_full" (fun () ->
    get (B.put_entry base ~replace:true edited ~plan:None))
    (fun answer -> check_balance answer n 1);

  let serialized = B.to_string base in
  Printf.printf "snapshot_bytes=%d\n%!" (String.length serialized);
  timed "cold_decode_and_admit" (fun () -> get (B.of_string serialized))
    (fun answer -> check_balance answer n 0);

  expect_refusal "duplicate"
    (B.put_entry base ~replace:false existing ~plan:None)
    (B.put_entry_full base ~replace:false existing ~plan:None);
  let invalid = { fresh with effects =
    [posting "wallet" "jpy" (-2); posting "food" "jpy" 1] } in
  expect_refusal "unbalanced"
    (B.put_entry base ~replace:false invalid ~plan:None)
    (B.put_entry_full base ~replace:false invalid ~plan:None);
  check_balance base n 0;
  Printf.printf "CHECK=PASS\n%!"

let () =
  if Array.length Sys.argv <> 2 then
    failwith "usage: daily_book_cost_probe 1000|10000";
  main (int_of_string Sys.argv.(1))
