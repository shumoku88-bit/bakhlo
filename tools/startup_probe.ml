(* Synthetic startup/snapshot/in-memory response probe. Measurement only:
   Marshal here is a disposable-cache candidate, not a storage format. *)
module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query
module B = Bakhlo_sexp.Daily_book
module RB = Bakhlo_sexp.Records_book

let get = function Ok x -> x | Error why -> failwith why
let id = function Ok x -> x | Error _ -> failwith "invalid-id"
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
  let d = (i - 1) / 10 in
  let year = 2000 + d / 365 in
  let months = [|31;28;31;30;31;30;31;31;30;31;30;31|] in
  let rec date month rest =
    if rest < months.(month) then Printf.sprintf "%04d-%02d-%02d" year (month + 1) (rest + 1)
    else date (month + 1) (rest - months.(month)) in
  date 0 (d mod 365)
let entry i : B.entry =
  let reversal = i mod 97 = 0 in
  let source = if reversal then i - 1 else i in
  let m = currencies.(source mod 3) and n = amount source in
  let eff = if source mod 5 = 0 then
      [posting m "wallet" (Z.neg n); posting m "food" (Z.pred n); posting m "fees" Z.one]
    else [posting m "wallet" (Z.neg n); posting m "food" n] in
  let effects = if not reversal then eff else
    List.map (fun p -> posting m (D.Identifier.Locus.to_string (D.Effect.locus p))
      (Z.neg (D.Quantity.quanta (D.Effect.quantity p)))) eff in
  { id = Printf.sprintf "tx-%06d" i; day = day i;
    memo = Some (Printf.sprintf "Synthetic 記帳 %d" i); effects;
    reversal_of = (if reversal then Some (Printf.sprintf "tx-%06d" (i - 1)) else None);
    exchange = None; original_amount = None; merchant = None }

let generate n =
  let header : RB.header =
    { version = 1; measures = ["jpy",0; "eur",2; "usd",2]; labels = None;
      approved_loci = Some ["wallet"; "food"; "fees"; "bank"];
      origins = List.concat_map (fun m -> [coordinate "food" m; coordinate "fees" m]) (Array.to_list currencies);
      openings = []; presence = None; opaque = [];
      observations = [ { Bakhlo_application.Current_quantity_groups.reflected_roots = [];
        assertions = List.map (fun m ->
          { Bakhlo_application.Current_quantity_projection.coordinate = coordinate "wallet" m;
            quantity = D.Quantity.of_quanta (Z.of_int 1000000) }) (Array.to_list currencies) } ] } in
  let payloads = List.init n (fun i -> let e = entry (i + 1) in RB.Entry
    { id=e.id; day=e.day; memo=e.memo; token=None; effects=e.effects;
      reversal_of=e.reversal_of; exchange=e.exchange; original_amount=None; merchant=None; opaque=[] }) in
  let rb : RB.t = {header; frames = List.mapi (fun i p -> RB.encode_frame (i + 1) p) payloads} in
  B.to_string (get (B.of_records rb))

let read path = In_channel.with_open_bin path In_channel.input_all
let write path s = Out_channel.with_open_bin path (fun oc -> output_string oc s)
let now () = Unix.gettimeofday ()
let time name f =
  Gc.compact ();
  let t0 = now () in let r = f () in
  Printf.printf "%-28s %10.3f ms\n%!" name ((now () -. t0) *. 1000.); r
let median name k f =
  let xs = Array.init k (fun _ -> let t0 = now () in ignore (Sys.opaque_identity (f ())); now () -. t0) in
  Array.sort compare xs;
  Printf.printf "%-28s %10.4f ms (median of %d)\n%!" name (xs.(k/2) *. 1000.) k
let mib words = float_of_int (words * 8) /. 1048576.

let balance b = match Q.query (B.image b) (coordinate "wallet" "jpy") with
  | Ok (Q.Exact x) -> Z.to_string (D.Quantity.quanta (Q.quantity x)) | _ -> "non-exact"

let () = match Sys.argv with
  | [|_; "gen"; dir; n|] ->
      let s = generate (int_of_string n) in write (Filename.concat dir "book.sexp") s;
      let b = get (B.of_string s) in ignore (B.entries b);
      write (Filename.concat dir "book.snap") (Marshal.to_string b [Marshal.Closures]);
      Printf.printf "entries=%s sexp_bytes=%d\n" n (String.length s)
  | [|_; "load-sexp"; dir|] ->
      let t0 = now () in let b = get (B.of_string (read (Filename.concat dir "book.sexp"))) in
      Printf.printf "cold sexp load %.3f ms balance=%s\n" ((now () -. t0) *. 1000.) (balance b)
  | [|_; "load-snap"; dir|] ->
      let t0 = now () in let (b : B.t) = Marshal.from_string (read (Filename.concat dir "book.snap")) 0 in
      Printf.printf "cold snap load %.3f ms balance=%s\n" ((now () -. t0) *. 1000.) (balance b)
  | [|_; "detail"; dir|] ->
      let bytes = time "read sexp bytes" (fun () -> read (Filename.concat dir "book.sexp")) in
      ignore (time "Parsexp parse only" (fun () -> Parsexp.Many.parse_string_exn bytes));
      let b = time "Daily_book.of_string total" (fun () -> get (B.of_string bytes)) in
      ignore (B.entries b); Gc.compact ();
      Printf.printf "%-28s %10.1f MiB\n" "live book (reachable)" (mib (Obj.reachable_words (Obj.repr b)));
      Printf.printf "%-28s %10.1f MiB\n" "  of which image (Q.t)" (mib (Obj.reachable_words (Obj.repr (B.image b))));
      Printf.printf "%-28s %10.1f MiB\n" "  of which entries list" (mib (Obj.reachable_words (Obj.repr (B.entries b))));
      Printf.printf "%-28s %10.1f MiB\n" "sexp file" (float_of_int (String.length bytes) /. 1048576.);
      let snap = time "Marshal.to_string" (fun () -> Marshal.to_string b [Marshal.Closures]) in
      Printf.printf "%-28s %10.1f MiB\n" "snapshot bytes" (float_of_int (String.length snap) /. 1048576.);
      let (b2 : B.t) = time "Marshal.from_string" (fun () -> Marshal.from_string snap 0) in
      assert (balance b = balance b2);
      ignore (time "to_string (full print)" (fun () -> B.to_string b));
      let e = { (entry 999_999_9) with id = "probe-new"; day = "2030-01-01" } in
      median "put_entry (new)" 21 (fun () -> get (B.put_entry b ~replace:false e ~plan:None));
      let old = get (Option.to_result ~none:"no" (B.find_entry b "tx-000001")) in
      median "put_entry replace old" 21 (fun () -> get (B.put_entry b ~replace:true { old with memo = Some "x" } ~plan:None));
      median "balance query" 101 (fun () -> balance b);
      let pool = [coordinate "wallet" "jpy"] in
      median "daily_pace" 21 (fun () -> B.daily_pace b ~measure:"jpy" ~pool ~observed_at:"2030-01-01" ~end_exclusive:"2030-02-01")
  | _ -> prerr_endline "usage"; exit 2
