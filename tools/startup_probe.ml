(* Synthetic startup/snapshot/save/in-memory response probe. Measurement only:
   Marshal here is a disposable-cache candidate, not a storage format. *)
module D = Bakhlo_domain
module M = Bakhlo_application.Event_merchants
module B = Bakhlo_sexp.Daily_book
module L = Bakhlo_sexp.Book_log
module T = Bakhlo_book_txt.Book_txt
module F = Daily_file

let get = function Ok x -> x | Error why -> failwith why
let id = function Ok x -> x | Error _ -> failwith "invalid-id"

let coordinate locus measure : D.Effect_coordinate.t =
  {
    locus = id (D.Identifier.Locus.of_string locus);
    measure = id (D.Identifier.Measure.of_string measure);
  }

let currencies = [| "jpy"; "eur"; "usd" |]
let amount i = if i mod 997 = 0 then Z.shift_left Z.one 180 else Z.of_int (100 + (i mod 500))

let day i =
  let d = (i - 1) / 10 in
  let year = 2000 + (d / 365) in
  let months = [| 31; 28; 31; 30; 31; 30; 31; 31; 30; 31; 30; 31 |] in
  let rec date month rest =
    if rest < months.(month) then Printf.sprintf "%04d-%02d-%02d" year (month + 1) (rest + 1)
    else date (month + 1) (rest - months.(month))
  in
  date 0 (d mod 365)

(* Ten entries a day; every 97th reverses the one before, every 5th pays a fee. *)
let tx i : T.tx =
  let reversal = i mod 97 = 0 in
  let source = if reversal then i - 1 else i in
  let m = currencies.(source mod 3) and n = amount source in
  let posting locus amount : T.posting = { locus; measure = m; amount; key = None } in
  let effects =
    if source mod 5 = 0 then [ posting "wallet" (Z.neg n); posting "food" (Z.pred n); posting "fees" Z.one ]
    else [ posting "wallet" (Z.neg n); posting "food" n ]
  in
  {
    id = Printf.sprintf "tx-%06d" i;
    day = day i;
    memo = Some (Printf.sprintf "Synthetic 記帳 %d" i);
    effects = (if reversal then List.map (fun (p : T.posting) -> { p with amount = Z.neg p.amount }) effects else effects);
    reversal_of = (if reversal then Some (Printf.sprintf "tx-%06d" (i - 1)) else None);
    original = None;
    merchant = None;
    exchange = None;
  }

let generate n =
  let locus id : T.locus = { id; label = id; help = ""; hidden = false } in
  let txs = List.init n (fun i -> tx (i + 1)) in
  T.to_string
    {
      measures = [ ("jpy", 0); ("eur", 2); ("usd", 2) ];
      loci = List.map locus [ "wallet"; "food"; "fees"; "bank" ];
      roles = [];
      txs;
      plans = [];
      zero_origins = List.concat_map (fun m -> [ ("food", m); ("fees", m) ]) (Array.to_list currencies);
      openings = [];
      history_from = [];
      anchors =
        [
          {
            last = (match List.rev txs with last :: _ -> Some last.id | [] -> None);
            also = [];
            asserts = List.map (fun m -> (("wallet", m), Z.of_int 1000000)) (Array.to_list currencies);
          };
        ];
      items = [];
      closes = [];
    }

let read path = In_channel.with_open_bin path In_channel.input_all
let write path s = Out_channel.with_open_bin path (fun oc -> output_string oc s)
let now () = Unix.gettimeofday ()

let time name f =
  Gc.compact ();
  let t0 = now () in
  let r = f () in
  Printf.printf "%-32s %10.3f ms\n%!" name ((now () -. t0) *. 1000.);
  r

let median name k f =
  let xs =
    Array.init k (fun _ ->
        let t0 = now () in
        ignore (Sys.opaque_identity (f ()));
        now () -. t0)
  in
  Array.sort compare xs;
  Printf.printf "%-32s %10.4f ms (median of %d)\n%!" name (xs.(k / 2) *. 1000.) k

let mib words = float_of_int (words * 8) /. 1048576.

let balance b =
  match B.quantity b ~locus:"wallet" ~measure:"jpy" with Some q -> Z.to_string q.amount | None -> "unknown"

let entry_of_tx (tx : T.tx) : B.entry =
  {
    id = tx.id;
    day = tx.day;
    memo = tx.memo;
    reversal_of = tx.reversal_of;
    exchange = None;
    original_amount = None;
    merchant = None;
    effects =
      List.map
        (fun (p : T.posting) ->
          D.Effect.create ~key:None
            ~locus:(id (D.Identifier.Locus.of_string p.locus))
            ~measure:(id (D.Identifier.Measure.of_string p.measure))
            ~quantity:(D.Quantity.of_quanta p.amount))
        tx.effects;
  }

let () =
  match Sys.argv with
  | [| _; "gen"; dir; n |] ->
      let s = generate (int_of_string n) in
      F.write_new (Filename.concat dir "book.txt") s;
      let session = F.load (Filename.concat dir "book.txt") in
      write (Filename.concat dir "book.snap") (Marshal.to_string session.book [ Marshal.Closures ]);
      Printf.printf "entries=%s book_txt_bytes=%d\n" n (String.length s)
  | [| _; "load-txt"; dir |] ->
      let t0 = now () in
      let session = F.load (Filename.concat dir "book.txt") in
      Printf.printf "cold book.txt load %.3f ms balance=%s\n" ((now () -. t0) *. 1000.) (balance session.book)
  | [| _; "load-snap"; dir |] ->
      let t0 = now () in
      let (b : B.t) = Marshal.from_string (read (Filename.concat dir "book.snap")) 0 in
      Printf.printf "cold snap load %.3f ms balance=%s\n" ((now () -. t0) *. 1000.) (balance b)
  | [| _; "detail"; dir |] ->
      let path = Filename.concat dir "book.txt" in
      let bytes = time "read book.txt bytes" (fun () -> read path) in
      let txt = time "Book_txt.read" (fun () -> get (Result.map_error (fun e -> T.code_name e.T.code) (T.read bytes))) in
      let b = time "Daily_book.of_txt" (fun () -> get (B.of_txt txt)) in
      Gc.compact ();
      Printf.printf "%-32s %10.1f MiB\n" "live book (reachable)" (mib (Obj.reachable_words (Obj.repr b)));
      Printf.printf "%-32s %10.1f MiB\n" "live book.txt (reachable)" (mib (Obj.reachable_words (Obj.repr txt)));
      Printf.printf "%-32s %10.1f MiB\n" "book.txt file" (float_of_int (String.length bytes) /. 1048576.);
      let snap = time "Marshal.to_string" (fun () -> Marshal.to_string b [ Marshal.Closures ]) in
      let (b2 : B.t) = time "Marshal.from_string" (fun () -> Marshal.from_string snap 0) in
      assert (balance b = balance b2);
      ignore (time "Book_txt.print" (fun () -> T.print txt));
      let e = { (entry_of_tx (tx 1)) with id = "probe-new"; day = "2030-01-01" } in
      median "put_entry (new)" 21 (fun () -> get (B.put_entry b ~replace:false e ~plan:None));
      let old = get (Option.to_result ~none:"no" (B.find_entry b "tx-000001")) in
      median "put_entry replace old" 21 (fun () -> get (B.put_entry b ~replace:true { old with memo = Some "x" } ~plan:None));
      median "correct_entry_date" 21 (fun () -> get (B.correct_entry_date b ~id:"tx-000001" ~day:"2030-01-02"));
      let merchant = id (D.Identifier.External_party.of_string "probe-merchant") in
      median "classify_merchant (first)" 21 (fun () ->
          get (B.classify_merchant b ~id:"tx-000001" ~disposition:(M.Merchant merchant)));
      median "observe" 21 (fun () -> get (B.observe_quantities b [ ("wallet", "jpy", Z.of_int 5000) ]));
      median "balance query" 101 (fun () -> balance b);
      let pool = [ coordinate "wallet" "jpy" ] in
      median "daily_pace" 21 (fun () ->
          B.daily_pace b ~measure:"jpy" ~pool ~observed_at:"2030-01-01" ~end_exclusive:"2030-02-01");
      (* The whole save, durable flush included, on a copy. *)
      let file = Filename.concat dir "save.txt" in
      List.iter (fun p -> try Sys.remove p with Sys_error _ -> ()) [ file; file ^ ".prev" ];
      F.write_new file bytes;
      let session = ref (F.load file) and n = ref 0 in
      median "save (whole file + full sync)" 21 (fun () ->
          incr n;
          let e = { e with id = Printf.sprintf "save-%d" !n; day = "2030-01-02" } in
          match F.publish !session [ L.Put_entry { replace = false; entry = e; plan = None } ] with
          | F.Written s -> session := s
          | _ -> failwith "save-refused")
  | _ ->
      prerr_endline "usage: probe gen DIR N | load-txt DIR | load-snap DIR | detail DIR";
      exit 2
