(* Synthetic, opt-in measurement of existing owners; no new storage protocol. *)
module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query
module B = Bakhlo_sexp.Daily_book
module RB = Bakhlo_sexp.Records_book
module F = Daily_file
module A = Daily_actions

let require p why = if not p then failwith why
let get = function Ok x -> x | Error why -> failwith why
let id = function Ok x -> x | Error _ -> failwith "invalid-synthetic-id"
let coordinate locus measure : D.Effect_coordinate.t =
  { locus = id (D.Identifier.Locus.of_string locus);
    measure = id (D.Identifier.Measure.of_string measure) }
let posting measure locus amount =
  D.Effect.create ~key:None ~locus:(id (D.Identifier.Locus.of_string locus))
    ~measure:(id (D.Identifier.Measure.of_string measure))
    ~quantity:(D.Quantity.of_quanta amount)
let currencies = [| "jpy"; "eur"; "usd" |]
let amount i = if i mod 997 = 0 then Z.shift_left Z.one 180 else Z.of_int (100 + i mod 500)
let day i =
  (* 10 entries/day, 365 constructed valid dates/year; deliberately omit leap day. *)
  let d = (i - 1) / 10 in
  let year = 2000 + d / 365 in
  let months = [|31;28;31;30;31;30;31;31;30;31;30;31|] in
  let rec date month rest =
    if rest < months.(month) then Printf.sprintf "%04d-%02d-%02d" year (month + 1) (rest + 1)
    else date (month + 1) (rest - months.(month))
  in date 0 (d mod 365)
let entry i : B.entry =
  let reversal = i mod 97 = 0 in
  let source = if reversal then i - 1 else i in
  let m = currencies.(source mod 3) and n = amount source in
  let original_effects =
    if source mod 5 = 0 then
      [posting m "wallet" (Z.neg n); posting m "food" (Z.pred n); posting m "fees" Z.one]
    else [posting m "wallet" (Z.neg n); posting m "food" n]
  in
  let effects = if not reversal then original_effects else
    List.map (fun p -> posting m (D.Identifier.Locus.to_string (D.Effect.locus p))
      (Z.neg (D.Quantity.quanta (D.Effect.quantity p)))) original_effects in
  { id = Printf.sprintf "tx-%06d" i; day = day i;
    memo = Some (Printf.sprintf "Synthetic 記帳 %d — quoted \"memo\"\nsecond line" i);
    effects; reversal_of = (if reversal then Some (Printf.sprintf "tx-%06d" (i - 1)) else None);
    exchange = None }
let changes (e : B.entry) =
  List.map (fun p -> (D.Identifier.Locus.to_string (D.Effect.locus p),
                     D.Quantity.quanta (D.Effect.quantity p))) e.effects
let new_entry name : B.entry =
  { id = name; day = "2030-01-01"; memo = Some "synthetic publication";
    effects = [posting "jpy" "wallet" (Z.of_int (-1000)); posting "jpy" "food" (Z.of_int 1000)];
    reversal_of = None; exchange = None }
let rss_kib () =
  let ic = Unix.open_process_in (Printf.sprintf "ps -o rss= -p %d" (Unix.getpid ())) in
  let text = input_line ic in
  require (Unix.close_process_in ic = Unix.WEXITED 0) "rss-probe-failed";
  int_of_string (String.trim text)
let phase name f =
  let minor0, promoted0, major0 = Gc.counters () in
  let start = Unix.gettimeofday () in
  let result = f () in
  let elapsed = (Unix.gettimeofday () -. start) *. 1000. in
  let minor1, promoted1, major1 = Gc.counters () in
  Printf.printf "phase=%s ms=%.3f minor_words=%.0f promoted_words=%.0f major_words=%.0f rss_kib=%d\n%!"
    name elapsed (minor1 -. minor0) (promoted1 -. promoted0) (major1 -. major0) (rss_kib ());
  result
let generate dir n =
  let entries = List.init n (fun i -> entry (i + 1)) in
  let plans = List.init 360 (fun i ->
    let paid = i < 20 and cancelled = i >= 20 && i < 40 in
    let e = if paid then entry (i + 1) else new_entry "plan-template" in
    RB.Plan { id = Printf.sprintf "plan-%03d" i; day = "2030-01-01"; measure = "jpy";
      changes = (if paid then changes e else changes (new_entry "plan-template"));
      paid_by = (if paid then Some e.id else None);
      cancelled_on = (if cancelled then Some "2029-12-31" else None); opaque = [] }) in
  (* Paid plans use exactly the entry's actual Measure. *)
  let plans = List.mapi (fun i p -> match p with RB.Plan p when i < 20 ->
    RB.Plan { p with measure = currencies.((i + 1) mod 3) } | p -> p) plans in
  let header : RB.header =
    { version = 1; measures = ["jpy",0; "eur",2; "usd",2]; labels = None;
      approved_loci = Some ["wallet"; "food"; "fees"; "bank"];
      origins = List.concat_map (fun m -> [coordinate "food" m; coordinate "fees" m]) (Array.to_list currencies);
      openings = []; presence = None; opaque = [];
      observations = [ { Bakhlo_application.Current_quantity_groups.reflected_roots = [];
        assertions = List.map (fun m ->
          { Bakhlo_application.Current_quantity_projection.coordinate = coordinate "wallet" m;
            quantity = D.Quantity.of_quanta (Z.of_int 1000000) }) (Array.to_list currencies) } ] } in
  let payloads = plans @ List.map (fun (e : B.entry) -> RB.Entry
    { id=e.id; day=e.day; memo=e.memo; token=Some ("request-" ^ e.id); effects=e.effects;
      reversal_of=e.reversal_of; exchange=e.exchange; opaque=[] }) entries in
  let rb : RB.t = {header; frames = List.mapi (fun i p -> RB.encode_frame (i + 1) p) payloads} in
  let book = phase "fixture-admission" (fun () -> get (B.of_records rb)) in
  let mono = B.to_string book and records = RB.to_string rb in
  require (B.to_string (get (B.of_string mono)) = B.to_string (get (B.of_string records))) "paired-facts-differ";
  F.write_new (Filename.concat dir "initial.sexp") mono;
  F.write_new (Filename.concat dir "initial.records") records;
  Printf.printf "fixture entries=%d plans=360 paid=20 cancelled=20 reversals=%d huge_quanta=%d mono_bytes=%d records_bytes=%d\n%!"
    n (n / 97) (n / 997) (String.length mono) (String.length records)
let exact book locus measure =
  match Q.query (B.image book) (coordinate locus measure) with
  | Ok (Q.Exact x) -> D.Quantity.quanta (Q.quantity x)
  | Ok (Q.Known_present _) | Error _ -> failwith "expected-exact-synthetic-balance"
let check book n =
  require (B.entry_count book = n) "entry-count";
  require (List.length (B.plans book) = 360) "plan-count";
  require (Q.query (B.image book) (coordinate "bank" "jpy") |> Result.is_error) "unknown-became-zero";
  let expected = Array.make 3 (Z.of_int 1000000) in
  for i = 1 to n do
    (* Independent arithmetic oracle, not a fold over generated/read postings. *)
    let reversal = i mod 97 = 0 in
    let source = if reversal then i - 1 else i in
    let delta = if reversal then amount source else Z.neg (amount source) in
    let k = source mod 3 in
    expected.(k) <- Z.add expected.(k) delta
  done;
  Array.iteri (fun i m -> require (Z.equal expected.(i) (exact book "wallet" m)) "balance-oracle") currencies
let published = function A.Published s -> s | A.Refused why | A.Storage_failed why -> failwith why
  | _ -> failwith "publication-not-confirmed"
let measure_worker dir format n =
  let suffix = if format = "mono" then "sexp" else "records" in
  let path = Filename.concat dir ("initial." ^ suffix) in
  let current = ref (phase "load" (fun () -> F.load path)) in
  check (!current).book n;
  let original_wallet = exact (!current).book "wallet" "jpy" in
  let original_eur_wallet = exact (!current).book "wallet" "eur" in
  ignore (phase "queries-1000" (fun () -> for _ = 1 to 1000 do
    ignore (exact (!current).book "wallet" "jpy");
    ignore (get (B.daily_pace (!current).book ~measure:"jpy" ~pool:[coordinate "wallet" "jpy"]
                  ~observed_at:"2030-01-01" ~end_exclusive:"2030-02-01")) done));
  for i = 1 to 3 do
    let e = new_entry (Printf.sprintf "new-%d" i) in
    current := phase (Printf.sprintf "record-%d" i) (fun () -> published
      (A.commit_transaction ~session:!current ~base_bytes:(!current).bytes
        {entry=e; replace=false; plan=None}))
  done;
  let old = Option.get (B.find_entry (!current).book "tx-000010") in
  let edited_effects = List.map (fun p ->
    let locus = D.Identifier.Locus.to_string (D.Effect.locus p) in
    let q = D.Quantity.quanta (D.Effect.quantity p) in
    posting "eur" locus (if locus="wallet" then Z.pred q else if locus="food" then Z.succ q else q)) old.effects in
  let edit = { old with day="1999-12-31"; memo=Some "corrected old date, amount and memo";
    effects=edited_effects } in
  let apply name tx =
    let before = F.read path in
    let result = phase name (fun () -> A.commit_transaction ~session:!current ~base_bytes:(!current).bytes tx) in
    match format, result with
    | "mono", A.Published s -> current := s
    | "records", A.Refused _ -> require (F.read path = before) "unsupported-operation-mutated";
        Printf.printf "refused=%s bytes_unchanged=true\n%!" name
    | _ -> failwith "unexpected-operation-result"
  in
  apply "correct-old" {entry=edit; replace=true; plan=None};
  apply "pay-plan" {entry=new_entry "payment"; replace=false; plan=Some "plan-040"};
  let cold = phase "reload" (fun () -> F.load path) in
  require (B.to_string cold.book = B.to_string (!current).book) "cold-facts-differ";
  require (B.entry_count cold.book = n + (if format="mono" then 4 else 3)) "cold-count";
  require (Z.equal (exact cold.book "wallet" "jpy")
    (Z.sub original_wallet (Z.of_int (if format="mono" then 4000 else 3000)))) "cold-balance";
  require (Z.equal (exact cold.book "wallet" "eur")
    (if format="mono" then Z.pred original_eur_wallet else original_eur_wallet)) "cold-corrected-amount";
  let p = List.find (fun (p:B.plan) -> p.id="plan-040") (B.plans cold.book) in
  require (p.paid_by = (if format="mono" then Some "payment" else None)) "cold-payment-link";
  if format="mono" then require ((Option.get (B.find_entry cold.book old.id)).day="1999-12-31") "cold-correction";
  let restored = Filename.concat dir ("restored." ^ suffix) in
  ignore (phase "restore-fresh-copy" (fun () ->
    if format="mono" then F.restore_copy ~source:path ~target:restored
    else F.copy_records ~source:path ~target:restored));
  require (F.read restored = F.read path) "restore-bytes";
  require (B.to_string (F.load restored).book = B.to_string cold.book) "restore-facts";
  let backups = Sys.readdir dir |> Array.to_list |> List.filter
    (fun f -> String.starts_with ~prefix:(Filename.basename path ^ ".before-") f) in
  let backup_bytes = List.fold_left (fun n f -> n + (Unix.stat (Filename.concat dir f)).st_size) 0 backups in
  Printf.printf "retention format=%s current_bytes=%d backups=%d backup_bytes=%d rss_end_kib=%d\n%!"
    format (Unix.stat path).st_size (List.length backups) backup_bytes (rss_kib ());
  Printf.printf "PASS format=%s cold_facts_and_exact_fresh_restore=true\n%!" format
let probe () =
  let header : RB.header = {version=1; measures=["jpy",0]; labels=None; approved_loci=None;
    origins=[]; openings=[]; observations=[]; presence=None;
    opaque=[Sexplib0.Sexp.List [Sexplib0.Sexp.Atom "future-metadata"; Sexplib0.Sexp.Atom "keep-me"]]} in
  let rb : RB.t = {header; frames=[]} in
  let wire = RB.to_string rb in
  require ((get (RB.of_string wire)).header.opaque = header.opaque) "records-opaque-codec";
  let daily = get (B.of_string wire) in
  require (not (Base.String.is_substring (B.to_string daily) ~substring:"keep-me")) "unexpected-opaque-preservation";
  print_endline "CONFIRMED: Records codec preserves opaque header; Daily conversion/export drops it. Not full roundtrip.";
  print_endline "LIMIT: process timing and fsync-return evidence only; no power-loss/device/off-host qualification."
let () =
  match Array.to_list Sys.argv with
  | [_; "generate"; dir; n] -> generate dir (int_of_string n)
  | [_; "worker"; dir; format; n] when format="mono" || format="records" -> measure_worker dir format (int_of_string n)
  | [_; "probe"] -> probe ()
  | _ -> failwith "Usage: storage-study generate DIR N | worker DIR mono/records N | probe"
