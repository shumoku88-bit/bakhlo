(* Synthetic startup/snapshot/in-memory response probe. Measurement only:
   Marshal here is a disposable-cache candidate, not a storage format. *)
module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query
module M = Bakhlo_application.Event_merchants
module B = Bakhlo_sexp.Daily_book

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

(* Ordinary S-expression text, so the fixture never depends on a writer path. *)
let generate n =
  let b = Buffer.create (n * 300) in
  let add = Buffer.add_string b in
  add "(bakhlo-daily 1) (scope corrected-entries explicit-plans)\n";
  add "(measures (measure jpy 0) (measure eur 2) (measure usd 2))\n";
  add "(labels (not-supplied)) (approved-loci (provided wallet food fees bank))\n(entries\n";
  for i = 1 to n do
    let e = entry i in
    let postings =
      String.concat " "
        (List.map (fun p ->
             Printf.sprintf "(posting %s %s %s (none))"
               (D.Identifier.Locus.to_string (D.Effect.locus p))
               (D.Identifier.Measure.to_string (D.Effect.measure p))
               (Z.to_string (D.Quantity.quanta (D.Effect.quantity p))))
           e.effects)
    in
    Printf.bprintf b "(entry %s (date %s) (memo (some \"%s\")) (postings %s) (reversal-of %s))\n"
      e.id e.day (Option.get e.memo) postings
      (match e.reversal_of with None -> "(none)" | Some t -> "(some " ^ t ^ ")")
  done;
  add ")\n(plans)\n(support (zero-origin";
  Array.iter (fun m -> Printf.bprintf b " (food %s) (fees %s)" m m) currencies;
  add ") (openings)\n(observations (observation (reflected) (quantities";
  Array.iter (fun m -> Printf.bprintf b " (wallet %s 1000000)" m) currencies;
  add "))) (presence (not-supplied)))\n";
  B.to_string (get (B.of_string (Buffer.contents b)))

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
      median "correct_entry_date" 21 (fun () ->
          get (B.correct_entry_date b ~id:"tx-000001" ~day:"2030-01-02"));
      let merchant = id (D.Identifier.External_party.of_string "probe-merchant") in
      median "classify_merchant (first)" 21 (fun () ->
          get (B.classify_merchant b ~id:"tx-000001" ~disposition:(M.Merchant merchant)));
      let plan : B.plan = { id = "probe-plan"; day = "2030-01-31"; measure = "jpy";
        changes = [ ("wallet", Z.of_int (-500)); ("food", Z.of_int 500) ]; paid_by = None; cancelled_on = None } in
      median "put_plan (new)" 21 (fun () -> get (B.put_plan b ~replace:false plan));
      median "add_locus" 21 (fun () -> get (B.add_locus b "probe-locus"));
      let file = Filename.concat dir "save.sexp" in
      (try Sys.remove file with Sys_error _ -> ());
      Out_channel.with_open_bin file (fun oc -> output_string oc bytes);
      let session = ref (Daily_file.load file) and n = ref 0 in
      median "save (append + full sync)" 21 (fun () ->
          incr n;
          let e = { (entry 1) with id = Printf.sprintf "save-%d" !n; day = "2030-01-02"; reversal_of = None } in
          match Daily_file.append !session [ Bakhlo_sexp.Book_log.Put_entry { replace = false; entry = e; plan = None } ] with
          | Daily_file.Written s -> session := s
          | _ -> failwith "save-refused");
      let target = get (Option.to_result ~none:"no" (B.find_entry b "tx-000002")) in
      let refund = { target with id = "probe-refund"; reversal_of = Some target.id;
        effects = List.map (fun p -> D.Effect.create ~key:(D.Effect.key p) ~locus:(D.Effect.locus p)
          ~measure:(D.Effect.measure p) ~quantity:(D.Quantity.neg (D.Effect.quantity p))) target.effects } in
      median "refund (reversal)" 21 (fun () -> get (B.put_entry b ~replace:false refund ~plan:None));
      let key k = Option.get (Result.to_option (D.Identifier.Effect_key.of_string k)) in
      let exchange = { (entry 3) with id = "probe-exchange"; reversal_of = None; exchange = Some ("s", "d");
        effects = [ D.Effect.create ~key:(Some (key "s")) ~locus:(id (D.Identifier.Locus.of_string "wallet"))
                      ~measure:(id (D.Identifier.Measure.of_string "jpy")) ~quantity:(D.Quantity.of_quanta (Z.of_int (-1000)));
                    D.Effect.create ~key:(Some (key "d")) ~locus:(id (D.Identifier.Locus.of_string "wallet"))
                      ~measure:(id (D.Identifier.Measure.of_string "usd")) ~quantity:(D.Quantity.of_quanta (Z.of_int 700)) ] } in
      median "exchange" 21 (fun () -> get (B.put_entry b ~replace:false exchange ~plan:None));
      median "observe" 21 (fun () -> get (B.observe_quantities b [ ("wallet", "jpy", Z.of_int 5000) ]));
      median "balance query" 101 (fun () -> balance b);
      median "represented coordinates (uncached)" 21 (fun () ->
        let image = B.image b in
        let frontier = Bakhlo_application.Actual_source.frontier (Q.source image) in
        let seen = Hashtbl.create 64 in
        List.iter (fun e -> List.iter (fun p ->
            Hashtbl.replace seen (D.Effect.locus p, D.Effect.measure p) ()) (D.Event.effects e))
          (Bakhlo_application.Correction_frontier.frontier_events frontier);
        List.sort_uniq D.Effect_coordinate.compare
          (Hashtbl.fold (fun (locus, measure) () acc -> ({ locus; measure } : D.Effect_coordinate.t) :: acc) seen []));
      let pool = [coordinate "wallet" "jpy"] in
      median "daily_pace" 21 (fun () -> B.daily_pace b ~measure:"jpy" ~pool ~observed_at:"2030-01-01" ~end_exclusive:"2030-02-01")
  | _ -> prerr_endline "usage"; exit 2
