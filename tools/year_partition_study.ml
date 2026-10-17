(* Year-Partitioned S-expression + Approach C: Storage Performance Prototype *)
module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query
module B = Bakhlo_sexp.Daily_book
module RB = Bakhlo_sexp.Records_book
module DA = Bakhlo_sexp.Durable_append

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

let amount i =
  if i mod 997 = 0 then Z.shift_left Z.one 180 else Z.of_int (100 + i mod 500)

let day year i =
  (* 10 entries/day, 365 constructed valid dates/year; deliberately omit leap day. *)
  let d = (i - 1) / 10 in
  let months = [|31;28;31;30;31;30;31;31;30;31;30;31|] in
  let rec date month rest =
    if rest < months.(month) then Printf.sprintf "%04d-%02d-%02d" year (month + 1) (rest + 1)
    else date (month + 1) (rest - months.(month))
  in date 0 (d mod 365)

let entry year i : B.entry =
  let reversal = i mod 97 = 0 in
  let source = if reversal then i - 1 else i in
  let m = currencies.(source mod 3) and n = amount source in
  let original_effects =
    if source mod 5 = 0 then
      [posting m "wallet" (Z.neg n); posting m "food" (Z.pred n); posting m "fees" Z.one]
    else [posting m "wallet" (Z.neg n); posting m "food" n]
  in
  let effects =
    if not reversal then original_effects
    else
      List.map (fun p ->
        posting m (D.Identifier.Locus.to_string (D.Effect.locus p))
          (Z.neg (D.Quantity.quanta (D.Effect.quantity p)))) original_effects
  in
  { id = Printf.sprintf "tx-%04d-%06d" year i;
    day = day year i;
    memo = Some (Printf.sprintf "Synthetic 記帳 %d-%d — quoted \"memo\"\nsecond line" year i);
    effects;
    reversal_of = (if reversal then Some (Printf.sprintf "tx-%04d-%06d" year (i - 1)) else None);
    exchange = None;
    original_amount = None }

let new_entry name day : B.entry =
  { id = name;
    day;
    memo = Some "synthetic publication";
    effects = [posting "jpy" "wallet" (Z.of_int (-1000)); posting "jpy" "food" (Z.of_int 1000)];
    reversal_of = None;
    exchange = None;
    original_amount = None }

let calc_fingerprint str =
  Stdlib.Digest.to_hex (Stdlib.Digest.string str)

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

(*******************************************************************************
  CarryForward Persistence Module (from Issue A contract)
*******************************************************************************)

module Carry_forward = struct
  type locus_quantity =
    | Exact of Z.t
    | Zero_origin
    | Known_present
    | Unknown

  type coordinate = { locus : string; measure : string }

  type t = {
    prior_year : int;
    prior_revision : int;
    prior_fingerprint : string;
    as_of_day : string;
    balances : (coordinate * locus_quantity) list;
    retained_roots : string list;
    schema_version : int;
  }

  let to_sexp_string (t : t) : string =
    let exact_items =
      List.filter_map (fun (c, q) ->
          match q with
          | Exact amt -> Some (Printf.sprintf "(%s %s %s)" c.locus c.measure (Z.to_string amt))
          | _ -> None) t.balances
      |> String.concat " "
    in
    let zero_origin_items =
      List.filter_map (fun (c, q) ->
          match q with
          | Zero_origin -> Some (Printf.sprintf "(%s %s)" c.locus c.measure)
          | _ -> None) t.balances
      |> String.concat " "
    in
    let unknown_items =
      List.filter_map (fun (c, q) ->
          match q with
          | Unknown -> Some (Printf.sprintf "(%s %s)" c.locus c.measure)
          | _ -> None) t.balances
      |> String.concat " "
    in
    let roots_items = String.concat " " t.retained_roots in
    Printf.sprintf
      "((bakhlo-carry-forward %d)\n\
      \ (prior-year %d)\n\
      \ (prior-revision %d)\n\
      \ (prior-fingerprint %S)\n\
      \ (as-of %s)\n\
      \ (retained-roots %s)\n\
      \ (balances\n\
      \   (exact %s)\n\
      \   (zero-origin %s)\n\
      \   (unknown %s)\n\
      \ ))"
      t.schema_version t.prior_year t.prior_revision t.prior_fingerprint t.as_of_day roots_items
      exact_items zero_origin_items unknown_items

  let of_sexp_string (bytes : string) : (t, string) Result.t =
    try
      let sexp = Parsexp.Single.parse_string_exn bytes in
      let items = match sexp with Sexplib0.Sexp.List xs -> xs | _ -> failwith "expected list" in
      let find_tag tag =
        List.find_map (function
          | Sexplib0.Sexp.List (Sexplib0.Sexp.Atom t :: vals) when t = tag -> Some vals
          | _ -> None) items
      in
      let version =
        match find_tag "bakhlo-carry-forward" with
        | Some [ Sexplib0.Sexp.Atom v ] -> int_of_string v
        | _ -> failwith "missing bakhlo-carry-forward"
      in
      let prior_year =
        match find_tag "prior-year" with
        | Some [ Sexplib0.Sexp.Atom y ] -> int_of_string y
        | _ -> failwith "missing prior-year"
      in
      let prior_revision =
        match find_tag "prior-revision" with
        | Some [ Sexplib0.Sexp.Atom r ] -> int_of_string r
        | _ -> failwith "missing prior-revision"
      in
      let prior_fingerprint =
        match find_tag "prior-fingerprint" with
        | Some [ Sexplib0.Sexp.Atom fp ] -> fp
        | _ -> failwith "missing prior-fingerprint"
      in
      let as_of_day =
        match find_tag "as-of" with
        | Some [ Sexplib0.Sexp.Atom d ] -> d
        | _ -> failwith "missing as-of"
      in
      let retained_roots =
        match find_tag "retained-roots" with
        | Some roots -> List.map (function Sexplib0.Sexp.Atom r -> r | _ -> failwith "invalid root") roots
        | None -> []
      in
      let balances =
        match find_tag "balances" with
        | Some b_items ->
          let parse_group = function
            | Sexplib0.Sexp.List (Sexplib0.Sexp.Atom "exact" :: xs) ->
              List.map (function
                | Sexplib0.Sexp.List [ Sexplib0.Sexp.Atom l; Sexplib0.Sexp.Atom m; Sexplib0.Sexp.Atom q ] ->
                  ({ locus = l; measure = m }, Exact (Z.of_string q))
                | _ -> failwith "invalid exact item") xs
            | Sexplib0.Sexp.List (Sexplib0.Sexp.Atom "zero-origin" :: xs) ->
              List.map (function
                | Sexplib0.Sexp.List [ Sexplib0.Sexp.Atom l; Sexplib0.Sexp.Atom m ] ->
                  ({ locus = l; measure = m }, Zero_origin)
                | _ -> failwith "invalid zero item") xs
            | Sexplib0.Sexp.List (Sexplib0.Sexp.Atom "unknown" :: xs) ->
              List.map (function
                | Sexplib0.Sexp.List [ Sexplib0.Sexp.Atom l; Sexplib0.Sexp.Atom m ] ->
                  ({ locus = l; measure = m }, Unknown)
                | _ -> failwith "invalid unknown item") xs
            | _ -> []
          in
          List.concat_map parse_group b_items
        | None -> []
      in
      Ok { prior_year; prior_revision; prior_fingerprint; as_of_day; balances; retained_roots; schema_version = version }
    with Failure err -> Error err | exn -> Error (Printexc.to_string exn)
end

(*******************************************************************************
  Trusted Selection Manifest
*******************************************************************************)

module Trusted_selection = struct
  type revision_entry = {
    revision : int;
    fingerprint : string;
  }

  type t = {
    generation : int;
    years : (int * revision_entry) list;
  }

  let to_sexp_string (t : t) : string =
    let entries_str =
      List.map (fun (y, e) ->
          Printf.sprintf "(year %d (revision %d) (fingerprint %S))" y e.revision e.fingerprint)
        t.years
      |> String.concat "\n  "
    in
    Printf.sprintf "((manifest 1)\n (generation %d)\n (selections\n  %s\n ))\n"
      t.generation entries_str

  let of_sexp_string (str : string) : (t, string) Result.t =
    try
      let sexp = Parsexp.Single.parse_string_exn str in
      let items = match sexp with Sexplib0.Sexp.List xs -> xs | _ -> failwith "expected list" in
      let find_tag tag =
        List.find_map (function
          | Sexplib0.Sexp.List (Sexplib0.Sexp.Atom t :: vals) when t = tag -> Some vals
          | _ -> None) items
      in
      let generation =
        match find_tag "generation" with
        | Some [ Sexplib0.Sexp.Atom g ] -> int_of_string g
        | _ -> failwith "missing generation"
      in
      let years =
        match find_tag "selections" with
        | Some s_items ->
          List.map (function
            | Sexplib0.Sexp.List (Sexplib0.Sexp.Atom "year" :: Sexplib0.Sexp.Atom y :: fields) ->
              let rev =
                List.find_map (function
                  | Sexplib0.Sexp.List [ Sexplib0.Sexp.Atom "revision"; Sexplib0.Sexp.Atom r ] -> Some (int_of_string r)
                  | _ -> None) fields
                |> Option.get
              in
              let fp =
                List.find_map (function
                  | Sexplib0.Sexp.List [ Sexplib0.Sexp.Atom "fingerprint"; Sexplib0.Sexp.Atom f ] -> Some f
                  | _ -> None) fields
                |> Option.get
              in
              (int_of_string y, { revision = rev; fingerprint = fp })
            | _ -> failwith "invalid year entry") s_items
        | None -> []
      in
      Ok { generation; years }
    with Failure err -> Error err | exn -> Error (Printexc.to_string exn)
end

(*******************************************************************************
  Safe Year-Partition Publisher (Mirrors Daily_file.publish protocol for current year)
*******************************************************************************)

module Year_partition_file = struct
  type t = {
    year : int;
    path : string;
    bytes : string;
    book : B.t;
    carry_forward : Carry_forward.t option;
  }

  type breakdown_timing = {
    t_print1_ms : float;
    t_check_ms : float;
    t_print2_ms : float;
    t_lock_ms : float;
    t_write_attempt_ms : float;
    t_write_pending_backup_ms : float;
    t_rename_sync_ms : float;
    t_readback_ms : float;
    t_unlink_ms : float;
    t_total_ms : float;
  }

  let read path =
    let ic = open_in_bin path in
    let len = in_channel_length ic in
    let b = really_input_string ic len in
    close_in ic;
    b

  let write_new path bytes =
    let fd = Unix.openfile path [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_EXCL; Unix.O_CLOEXEC ] 0o600 in
    Fun.protect ~finally:(fun () -> Unix.close fd) (fun () ->
        let len = String.length bytes in
        let rec loop n =
          if n < len then
            let w = Unix.write_substring fd bytes n (len - n) in
            require (w > 0) "zero-write";
            loop (n + w)
        in
        loop 0;
        Unix.fsync fd);
    require (read path = bytes) "readback-changed"

  let sync_parent path =
    let fd = Unix.openfile (Filename.dirname path) [ Unix.O_RDONLY; Unix.O_CLOEXEC ] 0 in
    Fun.protect ~finally:(fun () -> Unix.close fd) (fun () -> Unix.fsync fd)

  let with_writer path f =
    let lockpath = path ^ ".lock" in
    let fd = Unix.openfile lockpath [ Unix.O_RDWR; Unix.O_CREAT; Unix.O_CLOEXEC ] 0o600 in
    Fun.protect ~finally:(fun () -> Unix.close fd) (fun () ->
        Unix.lockf fd Unix.F_TLOCK 0;
        f ())

  let nonce () =
    let fd = Unix.openfile "/dev/urandom" [ Unix.O_RDONLY; Unix.O_CLOEXEC ] 0 in
    Fun.protect ~finally:(fun () -> Unix.close fd) (fun () ->
        let b = Bytes.create 12 in
        let rec loop n =
          if n < 12 then
            let c = Unix.read fd b n (12 - n) in
            require (c > 0) "entropy-read";
            loop (n + c)
        in
        loop 0;
        String.concat "" (List.init 12 (fun i -> Printf.sprintf "%02x" (Char.code (Bytes.get b i)))))

  let attempt_path path id = path ^ ".attempt-" ^ id ^ ".sexp"
  let pending_path path id = path ^ ".pending-" ^ id
  let before_path path id = path ^ ".before-" ^ id ^ ".sexp"

  (* Fully safe publish protocol matching Daily_file.publish *)
  let publish_measured session book : (t * breakdown_timing) =
    let t0 = Unix.gettimeofday () in

    (* Phase 1: Serialization 1 *)
    let bytes = B.to_string book in
    let t1 = Unix.gettimeofday () in

    (* Phase 2: Parse and Admission Check *)
    let checked = get (B.of_string bytes) in
    let t2 = Unix.gettimeofday () in

    (* Phase 3: Printer Stability Check (Serialization 2) *)
    let bytes2 = B.to_string checked in
    require (bytes2 = bytes) "unstable-printer";
    let t3 = Unix.gettimeofday () in

    with_writer session.path (fun () ->
        let t4 = Unix.gettimeofday () in
        require (read session.path = session.bytes) "conflict";

        let suffix = nonce () in
        let attempt = attempt_path session.path suffix in
        let pending = pending_path session.path suffix in
        let backup = before_path session.path suffix in

        (* Phase 5: Write Attempt & Sync parent *)
        write_new attempt bytes;
        sync_parent session.path;
        let t5 = Unix.gettimeofday () in

        (* Phase 6: Write Pending & Backup & Sync parent *)
        write_new pending bytes;
        write_new backup session.bytes;
        sync_parent session.path;
        let t6 = Unix.gettimeofday () in

        require (read session.path = session.bytes) "conflict-before-rename";

        (* Phase 7: Atomic Rename & Sync parent *)
        Unix.rename pending session.path;
        sync_parent session.path;
        let t7 = Unix.gettimeofday () in

        (* Phase 8: Readback Verification *)
        require (read session.path = bytes) "selected-readback-changed";
        let t8 = Unix.gettimeofday () in

        (* Phase 9: Remove Attempt & Sync parent *)
        Unix.unlink attempt;
        sync_parent session.path;
        let t9 = Unix.gettimeofday () in

        let timing = {
          t_print1_ms = (t1 -. t0) *. 1000.;
          t_check_ms = (t2 -. t1) *. 1000.;
          t_print2_ms = (t3 -. t2) *. 1000.;
          t_lock_ms = (t4 -. t3) *. 1000.;
          t_write_attempt_ms = (t5 -. t4) *. 1000.;
          t_write_pending_backup_ms = (t6 -. t5) *. 1000.;
          t_rename_sync_ms = (t7 -. t6) *. 1000.;
          t_readback_ms = (t8 -. t7) *. 1000.;
          t_unlink_ms = (t9 -. t8) *. 1000.;
          t_total_ms = (t9 -. t0) *. 1000.;
        } in
        ({ session with bytes; book = checked }, timing))
end

(*******************************************************************************
  Generation & Benchmark Driver
*******************************************************************************)

let generate_partitioned dir total_years =
  let entries_per_year = 3650 in
  let start_year = 2000 in
  let current_year = start_year + total_years - 1 in

  Printf.printf "Generating %d-year partitioned corpus (%d entries total)...\n%!"
    total_years (total_years * entries_per_year);

  let selection_entries = ref [] in

  (* Generate past years (2000 to current_year - 1) *)
  for y = start_year to current_year - 1 do
    let y_entries = List.init entries_per_year (fun i -> entry y (i + 1)) in
    let header : RB.header =
      { version = 1; measures = ["jpy",0; "eur",2; "usd",2]; labels = None;
        approved_loci = Some ["wallet"; "food"; "fees"; "bank"];
        origins = List.concat_map (fun m -> [coordinate "food" m; coordinate "fees" m]) (Array.to_list currencies);
        openings = []; presence = None; opaque = [];
        observations = (if y = start_year then [
          { Bakhlo_application.Current_quantity_groups.reflected_roots = [];
            assertions = List.map (fun m ->
              { Bakhlo_application.Current_quantity_projection.coordinate = coordinate "wallet" m;
                quantity = D.Quantity.of_quanta (Z.of_int 1000000) }) (Array.to_list currencies) }
        ] else []) }
    in
    let payloads = List.map (fun (e : B.entry) -> RB.Entry
      { id=e.id; day=e.day; memo=e.memo; token=Some ("request-" ^ e.id); effects=e.effects;
        reversal_of=e.reversal_of; exchange=e.exchange; opaque=[] }) y_entries
    in
    let rb : RB.t = { header; frames = List.mapi (fun i p -> RB.encode_frame (i + 1) p) payloads } in
    let book = get (B.of_records rb) in
    let mono_text = B.to_string book in
    let path = Filename.concat dir (Printf.sprintf "year-%d.sexp" y) in
    Year_partition_file.write_new path mono_text;
    selection_entries := (y, { Trusted_selection.revision = 1; fingerprint = calc_fingerprint mono_text }) :: !selection_entries
  done;

  (* Generate CarryForward from (current_year - 1) if past years exist *)
  let cf_opt =
    if total_years > 1 then begin
      let prior_year = current_year - 1 in
      let prior_path = Filename.concat dir (Printf.sprintf "year-%d.sexp" prior_year) in
      let prior_text = Year_partition_file.read prior_path in
      let prior_fp = calc_fingerprint prior_text in

      (* Calculate wallet balances mathematically from generated entries *)
      let wallet_balances = Array.make 3 (Z.of_int 1000000) in
      for y = start_year to prior_year do
        for i = 1 to entries_per_year do
          let reversal = i mod 97 = 0 in
          let source = if reversal then i - 1 else i in
          let delta = if reversal then amount source else Z.neg (amount source) in
          let k = source mod 3 in
          wallet_balances.(k) <- Z.add wallet_balances.(k) delta
        done
      done;

      let balances =
        [
          ({ Carry_forward.locus = "wallet"; measure = "jpy" }, Carry_forward.Exact wallet_balances.(0));
          ({ Carry_forward.locus = "wallet"; measure = "eur" }, Carry_forward.Exact wallet_balances.(1));
          ({ Carry_forward.locus = "wallet"; measure = "usd" }, Carry_forward.Exact wallet_balances.(2));
          ({ Carry_forward.locus = "food"; measure = "jpy" }, Carry_forward.Zero_origin);
          ({ Carry_forward.locus = "fees"; measure = "jpy" }, Carry_forward.Zero_origin);
          ({ Carry_forward.locus = "bank"; measure = "jpy" }, Carry_forward.Unknown);
        ]
      in
      let cf = {
        Carry_forward.prior_year;
        prior_revision = 1;
        prior_fingerprint = prior_fp;
        as_of_day = Printf.sprintf "%04d-12-31" prior_year;
        balances;
        retained_roots = [];
        schema_version = 1;
      } in
      let cf_path = Filename.concat dir (Printf.sprintf "carry-forward-%d.sexp" current_year) in
      Year_partition_file.write_new cf_path (Carry_forward.to_sexp_string cf);
      Some cf
    end else None
  in

  (* Generate Current Year (year-current_year.sexp) with 3650 entries *)
  let curr_entries = List.init entries_per_year (fun i -> entry current_year (i + 1)) in
  let curr_obs =
    match cf_opt with
    | Some cf ->
      let exacts = List.filter_map (fun (c, q) ->
        match q with Carry_forward.Exact amt ->
          Some { Bakhlo_application.Current_quantity_projection.coordinate =
                   coordinate c.Carry_forward.locus c.Carry_forward.measure;
                 quantity = D.Quantity.of_quanta amt }
        | _ -> None) cf.balances in
      [ { Bakhlo_application.Current_quantity_groups.reflected_roots = []; assertions = exacts } ]
    | None ->
      [ { Bakhlo_application.Current_quantity_groups.reflected_roots = [];
          assertions = List.map (fun m ->
            { Bakhlo_application.Current_quantity_projection.coordinate = coordinate "wallet" m;
              quantity = D.Quantity.of_quanta (Z.of_int 1000000) }) (Array.to_list currencies) } ]
  in
  let curr_header : RB.header =
    { version = 1; measures = ["jpy",0; "eur",2; "usd",2]; labels = None;
      approved_loci = Some ["wallet"; "food"; "fees"; "bank"];
      origins = List.concat_map (fun m -> [coordinate "food" m; coordinate "fees" m]) (Array.to_list currencies);
      openings = []; presence = None; opaque = [];
      observations = curr_obs }
  in
  let curr_payloads = List.map (fun (e : B.entry) -> RB.Entry
    { id=e.id; day=e.day; memo=e.memo; token=Some ("request-" ^ e.id); effects=e.effects;
      reversal_of=e.reversal_of; exchange=e.exchange; opaque=[] }) curr_entries
  in
  let curr_rb : RB.t = { header = curr_header; frames = List.mapi (fun i p -> RB.encode_frame (i + 1) p) curr_payloads } in
  let curr_book = get (B.of_records curr_rb) in
  let curr_mono_text = B.to_string curr_book in
  let curr_path = Filename.concat dir (Printf.sprintf "year-%d.sexp" current_year) in
  Year_partition_file.write_new curr_path curr_mono_text;
  selection_entries := (current_year, { Trusted_selection.revision = 1; fingerprint = calc_fingerprint curr_mono_text }) :: !selection_entries;

  (* Generate manifest.sexp *)
  let manifest = {
    Trusted_selection.generation = total_years;
    years = List.sort (fun (y1, _) (y2, _) -> compare y1 y2) !selection_entries;
  } in
  let manifest_path = Filename.concat dir "manifest.sexp" in
  Year_partition_file.write_new manifest_path (Trusted_selection.to_sexp_string manifest);

  Printf.printf "Corpus generated successfully in %s.\n%!" dir

let exact book locus measure =
  match Q.query (B.image book) (coordinate locus measure) with
  | Ok (Q.Exact x) -> D.Quantity.quanta (Q.quantity x)
  | Ok (Q.Known_present _) | Error _ -> failwith "expected-exact-synthetic-balance"

let run_worker dir total_years =
  let entries_per_year = 3650 in
  let start_year = 2000 in
  let current_year = start_year + total_years - 1 in
  let current_path = Filename.concat dir (Printf.sprintf "year-%d.sexp" current_year) in
  let cf_path = Filename.concat dir (Printf.sprintf "carry-forward-%d.sexp" current_year) in
  let manifest_path = Filename.concat dir "manifest.sexp" in

  Printf.printf "\n=== Starting Year-Partition Worker: %d Years (%d Total Entries) ===\n%!"
    total_years (total_years * entries_per_year);

  (* 1. Cold Load Phase *)
  let session = phase "cold-load" (fun () ->
      (* Step 1: Read and verify manifest *)
      let manifest_str = Year_partition_file.read manifest_path in
      let _manifest = get (Trusted_selection.of_sexp_string manifest_str) in

      (* Step 2: Read CarryForward if applicable *)
      let cf_opt =
        if Sys.file_exists cf_path then
          Some (get (Carry_forward.of_sexp_string (Year_partition_file.read cf_path)))
        else None
      in

      (* Step 3: Read ONLY current year file (Past years are NOT read) *)
      let curr_text = Year_partition_file.read current_path in
      let book = get (B.of_string curr_text) in

      { Year_partition_file.year = current_year;
        path = current_path;
        bytes = curr_text;
        book;
        carry_forward = cf_opt })
  in

  (* 2. Verification of semantic integrity *)
  require (B.entry_count session.book = entries_per_year) "current-year-entry-count";
  require (Q.query (B.image session.book) (coordinate "bank" "jpy") |> Result.is_error) "unknown-bank-became-zero";

  (* 3. Query phase (1,000 queries) *)
  ignore (phase "queries-1000" (fun () ->
      for _ = 1 to 1000 do
        ignore (exact session.book "wallet" "jpy");
        ignore (get (B.daily_pace session.book ~measure:"jpy" ~pool:[coordinate "wallet" "jpy"]
                      ~observed_at:(Printf.sprintf "%d-01-01" current_year)
                      ~end_exclusive:(Printf.sprintf "%d-02-01" current_year)))
      done));

  (* 4. Ten Sequential Safe Commits with Detailed Phase Breakdown *)
  let current_session = ref session in
  let commit_timings = ref [] in

  for i = 1 to 10 do
    let e = new_entry (Printf.sprintf "new-%d-%02d" current_year i) (Printf.sprintf "%04d-12-31" current_year) in
    let (new_sess, timing) =
      phase (Printf.sprintf "record-%d" i) (fun () ->
          let next_book = get (B.put_entry (!current_session).book ~replace:false e ~plan:None) in
          Year_partition_file.publish_measured !current_session next_book)
    in
    current_session := new_sess;
    commit_timings := timing :: !commit_timings;
    Printf.printf "  [commit-%02d breakdown] print1=%.2fms check=%.2fms print2=%.2fms lock=%.2fms write_att=%.2fms write_pend_bk=%.2fms rename=%.2fms readback=%.2fms unlink=%.2fms | TOTAL=%.2fms\n%!"
      i timing.t_print1_ms timing.t_check_ms timing.t_print2_ms timing.t_lock_ms
      timing.t_write_attempt_ms timing.t_write_pending_backup_ms timing.t_rename_sync_ms
      timing.t_readback_ms timing.t_unlink_ms timing.t_total_ms
  done;

  (* 5. Statistical Aggregation of Commit Times *)
  let total_times = List.map (fun t -> t.Year_partition_file.t_total_ms) !commit_timings in
  let sorted_times = List.sort compare total_times in
  let count = List.length sorted_times in
  let median = List.nth sorted_times (count / 2) in
  let p95 = List.nth sorted_times (int_of_float (float_of_int count *. 0.95)) in
  let min_time = List.hd sorted_times in
  let max_time = List.nth sorted_times (count - 1) in

  Printf.printf "\n=== Commit Statistics (%d Years) ===\n" total_years;
  Printf.printf "  Median Commit Time: %.2f ms\n" median;
  Printf.printf "  P95 Commit Time:    %.2f ms\n" p95;
  Printf.printf "  Min Commit Time:    %.2f ms\n" min_time;
  Printf.printf "  Max Commit Time:    %.2f ms\n" max_time;

  (* 6. Reload & Cold Verification *)
  let reloaded_sess = phase "reload" (fun () ->
      let text = Year_partition_file.read current_path in
      let b = get (B.of_string text) in
      { !current_session with bytes = text; book = b })
  in
  require (B.entry_count reloaded_sess.book = entries_per_year + 10) "reloaded-count";
  require (B.to_string reloaded_sess.book = B.to_string (!current_session).book) "cold-facts-differ";

  (* 7. Disk & Backup Usage Inspection *)
  let curr_stat = Unix.stat current_path in
  let backups =
    Sys.readdir dir
    |> Array.to_list
    |> List.filter (fun f -> String.starts_with ~prefix:(Filename.basename current_path ^ ".before-") f)
  in
  let backup_bytes =
    List.fold_left (fun acc f -> acc + (Unix.stat (Filename.concat dir f)).st_size) 0 backups
  in
  Printf.printf "\n=== Storage Metrics ===\n";
  Printf.printf "  Current Year File Size:  %d bytes (%.2f MB)\n" curr_stat.st_size (float_of_int curr_stat.st_size /. 1_000_000.);
  Printf.printf "  Backups Created:         %d files\n" (List.length backups);
  Printf.printf "  Total Backup Disk Usage: %d bytes (%.2f MB)\n" backup_bytes (float_of_int backup_bytes /. 1_000_000.);
  Printf.printf "  Peak RSS:                %d KiB (%.2f MiB)\n%!" (rss_kib ()) (float_of_int (rss_kib ()) /. 1024.);
  Printf.printf "PASS: Year-partition benchmark successfully verified.\n%!"

let () =
  match Array.to_list Sys.argv with
  | [ _; "generate"; dir; years ] -> generate_partitioned dir (int_of_string years)
  | [ _; "worker"; dir; years ] -> run_worker dir (int_of_string years)
  | _ -> failwith "Usage: year-partition-study generate DIR YEARS | worker DIR YEARS"
