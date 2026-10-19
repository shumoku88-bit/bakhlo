(* Local comparison only. Reuses the previously qualified, private Daily converter.
   This is not a full-household importer, backup or operational publisher. *)
module C = Daily
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module E = Bakhlo_loam_read.Envelope
exception Refused of string
let require p why = if not p then raise (Refused why)
let get why = function Ok x -> x | Error _ -> raise (Refused why)
let stat path = try Some (Unix.lstat path) with Unix.Unix_error (Unix.ENOENT, _, _) -> None
let stamp (s : Unix.stats) =
  s.st_dev, s.st_ino, s.st_kind, s.st_size, s.st_mtime, s.st_ctime, s.st_perm
let read path =
  match stat path with
  | None -> None
  | Some before ->
      require (before.st_kind = Unix.S_REG && before.st_size <= 32 * 1024 * 1024)
        "nonregular-or-oversized-input";
      let fd = Unix.openfile path [Unix.O_RDONLY; Unix.O_NONBLOCK; Unix.O_CLOEXEC] 0 in
      Fun.protect ~finally:(fun () -> Unix.close fd) (fun () ->
        require (stamp before = stamp (Unix.fstat fd)) "input-changed-at-open";
        let buffer = Buffer.create 4096 and chunk = Bytes.create 4096 in
        let rec loop () =
          let n = Unix.read fd chunk 0 4096 in
          if n > 0 then (
            Buffer.add_subbytes buffer chunk 0 n;
            require (Buffer.length buffer <= 32 * 1024 * 1024) "input-budget";
            loop ())
        in
        loop ();
        require (stamp before = stamp (Unix.fstat fd)
                 && Option.map stamp (stat path) = Some (stamp before)) "input-changed";
        Some (stamp before, Buffer.contents buffer))
let bytes path = match read path with Some (_, b) -> b | None -> raise (Refused "missing-input")
let write_new path contents =
  let fd = Unix.openfile path [Unix.O_WRONLY; Unix.O_CREAT; Unix.O_EXCL; Unix.O_CLOEXEC] 0o600 in
  Fun.protect ~finally:(fun () -> Unix.close fd) (fun () ->
    let rec loop offset =
      if offset < String.length contents then (
        let n = Unix.write_substring fd contents offset (String.length contents - offset) in
        require (n > 0) "zero-write";
        loop (offset + n))
    in
    loop 0;
    Unix.fsync fd);
  require (bytes path = contents) "copy-readback-changed"
let directory path =
  match stat path with
  | Some s -> require (s.st_kind = Unix.S_DIR) "nonregular-directory"
  | None -> Unix.mkdir path 0o700
let snapshot root =
  require (Unix.realpath root = root) "noncanonical-source-root";
  let root_stat = match stat root with Some s when s.st_kind = Unix.S_DIR -> stamp s
    | _ -> raise (Refused "missing-source-root") in
  let config = root ^ "/config" in
  let config_stat, names = match stat config with
    | None -> None, []
    | Some s ->
        require (s.st_kind = Unix.S_DIR) "nonregular-config-directory";
        Some (stamp s), Array.to_list (Sys.readdir config) |> List.sort String.compare in
  let files = List.map (fun name -> "config/" ^ name) names in
  root_stat, config_stat,
  List.map (fun name -> name, read (root ^ "/" ^ name)) ("household.loam" :: files)
let file_from (_, _, files) name =
  match List.assoc_opt name files with Some (Some (_, b)) -> Some b | _ -> None
let needed snapshot name = match file_from snapshot name with
  | Some b -> b | None -> raise (Refused "required-capture-input-missing")
let convert snapshot =
  let candidate, _, _, _ = C.from_loam
    ~raw:(needed snapshot "household.loam")
    ~measure_config:(needed snapshot "config/measure-presentation.tsv")
    ~label_config:(file_from snapshot "config/locus-catalog.tsv") in
  let book = get "current-daily-codec-refused" (B.of_string (C.to_string candidate)) in
  let printed = B.to_string book in
  let cold = get "candidate-cold-read-refused" (B.of_string printed) in
  require (B.to_string cold = printed) "candidate-roundtrip-changed";
  book, printed
let selected state =
  match read (state ^ "/CURRENT") with
  | None -> None
  | Some (_, text) ->
      let name = String.trim text in
      require (text = name ^ "\n" && String.starts_with ~prefix:"capture-" name
               && String.for_all (function 'a'..'z' | '0'..'9' | '-' -> true | _ -> false) name)
        "invalid-comparison-selector";
      let path = state ^ "/" ^ name in
      require (stat (path ^ "/COMPLETE") <> None) "incomplete-selected-comparison";
      Some path
let clean_copies ~state =
  require (match stat state with Some s -> s.st_kind = Unix.S_DIR | None -> false)
    "missing-comparison-state";
  let target = match selected state with Some path -> path
    | None -> raise (Refused "missing-comparison-selector") in
  require (match stat target with Some s -> s.st_kind = Unix.S_DIR | None -> false)
    "nonregular-comparison-directory";
  ignore (bytes (target ^ "/COMPLETE"));
  let selector = bytes (state ^ "/CURRENT") in
  (* Preflight both bounded trees before deleting anything; never follow links. *)
  let rec tree path depth = match stat path with
    | None -> []
    | Some s when s.st_kind = Unix.S_REG && depth > 0 -> [path, s]
    | Some s when s.st_kind = Unix.S_DIR && depth <= 1 ->
        let names = Array.to_list (Sys.readdir path) in
        require (List.length names <= 4096) "copy-cleanup-budget";
        List.concat_map (fun name ->
          let child = path ^ "/" ^ name in
          match stat child with
          | Some child_stat when child_stat.st_kind = Unix.S_DIR ->
              require (depth = 0 && name = "config") "unexpected-copy-directory";
              tree child (depth + 1)
          | _ -> tree child (depth + 1)) names @ [path, s]
    | Some _ -> raise (Refused "unsafe-copy-cleanup-input") in
  let roots = [target ^ "/source"; target ^ "/loam-view"] in
  let nodes = List.concat_map (fun path -> tree path 0) roots in
  List.iter (fun (path, before) ->
      require (Option.map stamp (stat path) = Some (stamp before)) "copy-changed-before-cleanup") nodes;
  require (bytes (state ^ "/CURRENT") = selector) "selector-changed-before-cleanup";
  let directories = List.filter (fun (_, s) -> s.Unix.st_kind = Unix.S_DIR) nodes in
  List.iter (fun (path, before) ->
      List.iter (fun (directory, original) ->
        if String.starts_with ~prefix:(directory ^ "/") path then
          require (match stat directory with
            | Some current -> current.st_kind = Unix.S_DIR
                && current.st_dev = original.Unix.st_dev && current.st_ino = original.st_ino
            | None -> false) "copy-directory-changed-during-cleanup") directories;
      require (match stat path with
        | Some current -> current.st_kind = before.Unix.st_kind
            && current.st_dev = before.st_dev && current.st_ino = before.st_ino
        | None -> false) "copy-changed-during-cleanup";
      if before.st_kind = Unix.S_DIR then Unix.rmdir path else Unix.unlink path) nodes;
  print_endline "PASS: selected raw comparison copies removed; Bakhlo book and older generations retained."
let posting p =
  D.Identifier.Locus.to_string (D.Effect.locus p),
  D.Identifier.Measure.to_string (D.Effect.measure p),
  Z.to_string (D.Quantity.quanta (D.Effect.quantity p)),
  Option.map D.Identifier.Effect_key.to_string (D.Effect.key p)
let entry_value (e : B.entry) = e.day, e.memo, List.map posting e.effects, e.reversal_of, e.exchange, e.original_amount
let plan_value (p : B.plan) =
  p.day, p.measure, List.map (fun (l, q) -> l, Z.to_string q) p.changes, p.paid_by, p.cancelled_on
let delta before after =
  let buffer = Buffer.create 256 in
  Buffer.add_string buffer
    "PRIVATE comparison delta; not an import log or operational cutover.\n";
  let compare kind old_rows new_rows =
    List.iter (fun (id, value) -> match List.assoc_opt id old_rows with
      | None -> Printf.bprintf buffer "ADDED_%s\t%S\n" kind id
      | Some previous when previous <> value -> Printf.bprintf buffer "CHANGED_%s\t%S\n" kind id
      | Some _ -> ()) new_rows;
    List.iter (fun (id, _) -> if not (List.mem_assoc id new_rows) then
        Printf.bprintf buffer "REMOVED_%s\t%S\n" kind id) old_rows in
  compare "ENTRY" (List.map (fun (e : B.entry) -> e.id, entry_value e) (B.entries before))
    (List.map (fun (e : B.entry) -> e.id, entry_value e) (B.entries after));
  compare "PLAN" (List.map (fun (p : B.plan) -> p.id, plan_value p) (B.plans before))
    (List.map (fun (p : B.plan) -> p.id, plan_value p) (B.plans after));
  Buffer.add_string buffer
    "The complete new supported book is regenerated, including support and metadata; not date-filtered or blindly appended.\nCorrection/date versions, retired/replaced Scheduled and unsupported household families remain in source/household.loam.\nBoth UIs use separate trial copies; neither is operational authority.\n";
  Buffer.contents buffer
let refresh ?(between = fun () -> ()) ~source ~state ~baseline () =
  directory state;
  let old = match selected state with
    | Some path -> get "previous-import-refused" (B.of_string (bytes (path ^ "/imported.sexp")))
    | None -> get "baseline-candidate-refused" (B.of_string (bytes baseline)) in
  let captured = snapshot source in
  ignore (get "household-framing-refused" (E.of_string (needed captured "household.loam")));
  let book, printed = convert captured in
  let name = Printf.sprintf "capture-%d-%d-%06x"
      (int_of_float (Unix.gettimeofday ())) (Unix.getpid ()) (Random.bits ()) in
  let target = state ^ "/" ^ name in
  Unix.mkdir target 0o700;
  write_new (target ^ "/INCOMPLETE") "Only COMPLETE marks a validated comparison capture.\n";
  List.iter (fun suffix -> Unix.mkdir (target ^ suffix) 0o700)
    [ "/source"; "/source/config"; "/loam-view"; "/loam-view/config"; "/config" ];
  let _, _, files = captured in
  List.iter (fun (name, value) -> match value with
    | None -> ()
    | Some (_, b) ->
        write_new (target ^ "/source/" ^ name) b;
        write_new (target ^ "/loam-view/" ^ name) b;
        if String.starts_with ~prefix:"config/" name then write_new (target ^ "/" ^ name) b)
    files;
  write_new (target ^ "/imported.sexp") printed;
  write_new (target ^ "/book.sexp") printed;
  write_new (target ^ "/delta.private.txt") (delta old book);
  between ();
  require (captured = snapshot source) "source-changed-during-capture";
  write_new (target ^ "/COMPLETE")
    "Scoped comparison capture; not a complete backup, full migration or production authority.\n";
  let selector = state ^ "/CURRENT-" ^ string_of_int (Unix.getpid ()) in
  write_new selector (name ^ "\n");
  Unix.rename selector (state ^ "/CURRENT");
  print_endline "PASS: private comparison refreshed; originals and previous trials unchanged."
let fixture ~changed =
  let amount = if changed then 15 else 10 in
  let actual = Printf.sprintf
    "LOAM-NORMALIZED-ACTUAL\t4\nTX\told\t2026-10-03\tDESC\tbefore\nEFFECT\twallet\tjpy\t-10\nEFFECT\tfood\tjpy\t10\nENDTX\n%s"
    (if changed then Printf.sprintf
      "TX\tcorrected\t2026-10-04\tDESC\tafter\nEFFECT\twallet\tjpy\t-%d\nEFFECT\tfood\tjpy\t%d\nREPLACES\told\nDATE-REV\tr\t2026-09-30\tREPLACES\tROOT\nENDTX\nTX\tfresh\t2026-10-12\tNODESC\nEFFECT\twallet\tjpy\t-3\nEFFECT\tfood\tjpy\t3\nENDTX\n" amount amount else "") in
  let inner name body = "BEGIN\t" ^ name ^ "\n" ^ body ^ "END\t" ^ name ^ "\n" in
  let scheduled = "LOAM-SCHEDULED-LIFECYCLE\t1\n" ^
    inner "Scheduled" "LOAM-SCHEDULED-MEMORY\t1\nSCHEDULED\tplanned\t2026-10-10\tjpy\nCHANGE\twallet\t-20\nCHANGE\tfood\t20\n" ^
    inner "Completion" ("LOAM-SCHEDULED-COMPLETION-MEMORY\t1\n" ^
      if changed then "COMPLETION\tplanned\tcorrected\n" else "") ^
    inner "Retirement" "LOAM-SCHEDULED-RETIREMENT-MEMORY\t1\n" ^
    inner "Replacement" "LOAM-SCHEDULED-REPLACEMENT-MEMORY\t1\n" in
  let sections = [ "Actual", actual; "Scheduled", scheduled;
    "ZeroOrigin", "LOAM-ZERO-ORIGIN-COVERAGE\t1\nCOORDINATE\tfood\tjpy\n";
    "OpeningSupport", "LOAM-OPENING-SUPPORT\t1\n";
    "CurrentQuantityAnchor", "LOAM-CURRENT-QUANTITY-ANCHOR\t2\nGROUP\nASSERT\twallet\tjpy\t1000\nEND\n";
    "CurrentQuantityPresence", "LOAM-CURRENT-QUANTITY-PRESENCE\t1\n";
    "LocusAdmission", "LOAM-LOCUS-ADMISSION-VOCABULARY\t1\nLOCUS\twallet\nLOCUS\tfood\n" ] in
  "LOAM-HOUSEHOLD-IMAGE\t2\n" ^ String.concat "" (List.map (fun (name, body) ->
    Printf.sprintf "SECTION\t%s\t%d\n%s" name (String.length body) body) sections)
let self_check () =
  let base = Filename.temp_file ~temp_dir:"scratch" "compare-check-" "" in
  Unix.unlink base;
  Unix.mkdir base 0o700;
  let source = Unix.realpath base ^ "/source" and state = Unix.realpath base ^ "/state" in
  directory source;
  directory (source ^ "/config");
  write_new (source ^ "/config/measure-presentation.tsv") "jpy\t0\n";
  write_new (source ^ "/config/daily-pace.tsv") "wallet\tjpy\n";
  write_new (source ^ "/household.loam") (fixture ~changed:false);
  let baseline = base ^ "/baseline.sexp" in
  let _, old_bytes = convert (snapshot source) in
  write_new baseline old_bytes;
  refresh ~source ~state ~baseline ();
  let first = Option.get (selected state) in
  let first_bytes = bytes (first ^ "/imported.sexp") in
  (* Both UIs are writable trials. Refresh must use source/imported evidence,
     preserving these edits without merging them into the next generation. *)
  let trial_book = get "trial-book-admission" (B.of_string first_bytes) in
  let trial_entry = Option.get (B.find_entry trial_book "old") in
  let trial_book = get "trial-edit-refused"
      (B.put_entry trial_book ~replace:true
         { trial_entry with memo = Some "Bakhlo trial-only edit" } ~plan:None) in
  let trial_book = get "trial-addition-refused"
      (B.put_entry trial_book ~replace:false
         { trial_entry with id = "fresh"; memo = Some "Bakhlo trial-only addition" } ~plan:None) in
  Unix.unlink (first ^ "/book.sexp");
  write_new (first ^ "/book.sexp") (B.to_string trial_book);
  Unix.unlink (first ^ "/config/daily-pace.tsv");
  write_new (first ^ "/config/daily-pace.tsv") "food\tjpy\n";
  Unix.unlink (first ^ "/loam-view/household.loam");
  write_new (first ^ "/loam-view/household.loam")
    (Base.String.substr_replace_all (fixture ~changed:false)
       ~pattern:"DESC\tbefore" ~with_:"DESC\tLOAM trial-only edit");
  Unix.unlink (first ^ "/loam-view/config/daily-pace.tsv");
  write_new (first ^ "/loam-view/config/daily-pace.tsv") "food\tjpy\n";
  let preserved = List.map (fun suffix -> suffix, bytes (first ^ suffix))
      [ "/book.sexp"; "/imported.sexp"; "/source/household.loam";
        "/source/config/daily-pace.tsv"; "/config/daily-pace.tsv";
        "/loam-view/household.loam"; "/loam-view/config/daily-pace.tsv" ] in
  Unix.unlink (source ^ "/household.loam");
  write_new (source ^ "/household.loam") (fixture ~changed:true);
  refresh ~source ~state ~baseline ();
  let second = Option.get (selected state) in
  require (first <> second) "refresh-reused-trial";
  List.iter (fun (suffix, before) ->
      require (bytes (first ^ suffix) = before) "previous-trial-edit-changed") preserved;
  let _, expected_fresh = convert (snapshot source) in
  require (bytes (second ^ "/book.sexp") = expected_fresh
           && bytes (second ^ "/imported.sexp") = expected_fresh)
    "fresh-book-merged-trial-edits";
  let updated = get "test-cold-admission" (B.of_string (bytes (second ^ "/book.sexp"))) in
  let entry = Option.get (B.find_entry updated "old") in
  require (B.entry_count updated = 2 && B.mem_entry updated "fresh"
           && entry.day = "2026-09-30" && entry.memo = Some "after")
    "correction-or-date-not-selected";
  require ((List.hd (B.plans updated)).paid_by = Some "old") "payment-link-not-remapped";
  let module Q = Bakhlo_application.Current_quantity_query in
  (match Q.query (B.image updated) (C.coord "wallet" "jpy") with
   | Ok (Q.Exact quantity) -> require (Z.equal (D.Quantity.quanta (Q.quantity quantity))
                                         (Z.of_int 982)) "independent-quantity-expectation"
   | Ok (Q.Known_present _) | Error _ -> raise (Refused "expected-exact-quantity"));
  require (bytes (first ^ "/imported.sexp") = first_bytes) "previous-capture-changed";
  require (bytes (second ^ "/source/household.loam") = bytes (source ^ "/household.loam"))
    "source-not-copied-exactly";
  require (bytes (second ^ "/config/daily-pace.tsv") = "wallet\tjpy\n") "config-not-copied";
  require (bytes (second ^ "/loam-view/config/daily-pace.tsv") = "wallet\tjpy\n")
    "loam-config-merged-trial-edits";
  let report = bytes (second ^ "/delta.private.txt") in
  require (Base.String.is_substring report ~substring:"ADDED_ENTRY\t\"fresh\""
           && Base.String.is_substring report ~substring:"CHANGED_ENTRY"
           && Base.String.is_substring report ~substring:"CHANGED_PLAN") "delta-missed-old-changes";
  let retained = List.map (fun suffix -> suffix, bytes (second ^ suffix))
      [ "/book.sexp"; "/imported.sexp"; "/config/daily-pace.tsv"; "/COMPLETE" ] in
  let before_cleanup = bytes (state ^ "/CURRENT") in
  Unix.symlink (source ^ "/household.loam") (second ^ "/loam-view/unsafe-link");
  (match clean_copies ~state with
   | () -> raise (Refused "unsafe-cleanup-was-accepted")
   | exception Refused "unsafe-copy-cleanup-input" -> ()
   | exception Refused _ -> raise (Refused "wrong-cleanup-refusal"));
  require (stat (second ^ "/source/household.loam") <> None) "cleanup-refusal-deleted-source-copy";
  Unix.unlink (second ^ "/loam-view/unsafe-link");
  clean_copies ~state;
  require (stat (second ^ "/source") = None && stat (second ^ "/loam-view") = None)
    "cleanup-left-raw-copies";
  require (bytes (state ^ "/CURRENT") = before_cleanup) "cleanup-changed-selector";
  List.iter (fun (suffix, before) -> require (bytes (second ^ suffix) = before)
      "cleanup-changed-bakhlo-input") retained;
  List.iter (fun (suffix, before) -> require (bytes (first ^ suffix) = before)
      "cleanup-changed-old-generation") preserved;
  require (bytes (source ^ "/household.loam") = fixture ~changed:true) "cleanup-changed-original";
  refresh ~source ~state ~baseline ();
  require (Option.get (selected state) <> second) "refresh-after-cleanup-failed";
  let selector = bytes (state ^ "/CURRENT") in
  (match refresh ~between:(fun () ->
       Unix.unlink (source ^ "/config/daily-pace.tsv");
       write_new (source ^ "/config/daily-pace.tsv") "changed\n") ~source ~state ~baseline () with
   | () -> raise (Refused "changed-source-was-accepted")
   | exception Refused "source-changed-during-capture" -> ()
   | exception Refused _ -> raise (Refused "wrong-change-refusal"));
  require (bytes (state ^ "/CURRENT") = selector) "failed-capture-changed-selector";
  Unix.unlink (source ^ "/config/daily-pace.tsv");
  Unix.symlink (second ^ "/config/daily-pace.tsv") (source ^ "/config/daily-pace.tsv");
  (match refresh ~source ~state ~baseline () with
   | () -> raise (Refused "symlink-source-was-accepted")
   | exception Refused "nonregular-or-oversized-input" -> ()
   | exception Refused _ -> raise (Refused "wrong-symlink-refusal"));
  require (bytes (state ^ "/CURRENT") = selector) "symlink-refusal-changed-selector";
  print_endline "PASS: synthetic refresh, preserved edits, correction/payment/configs, changed-source refusal, bounded raw-copy cleanup and refresh after cleanup."
let () =
  try match Array.to_list Sys.argv with
  | [ _; "self-check" ] -> self_check ()
  | [ _; "clean-copies"; state ] -> clean_copies ~state
  | [ _; "refresh"; source; state; baseline ] ->
      refresh ~source ~state ~baseline ()
  | _ -> raise (Refused "explicit-mode-required")
  with
  | Refused why -> prerr_endline ("Comparison refused: " ^ why ^ "; originals untouched."); exit 2
  | C.Refused why ->
      prerr_endline ("Comparison refused: source conversion profile (" ^ why ^ "); originals untouched."); exit 2
  | Unix.Unix_error _ | Sys_error _ ->
      prerr_endline "Comparison refused: filesystem boundary; private artifacts retained, originals untouched."; exit 2
  | _ -> prerr_endline "Comparison refused: unqualified input; private artifacts retained, originals untouched."; exit 2
