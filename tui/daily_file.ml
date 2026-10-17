(* One selected S-expression file and separate pre-edit backups.
   Cooperative writers/stable parent namespaces; not a security sandbox or a
   qualified power-loss protocol. No background retry, adoption or pruning. *)
module B = Bakhlo_sexp.Daily_book
module RB = Bakhlo_sexp.Records_book
module DA = Bakhlo_sexp.Durable_append
module Annual = Bakhlo_sexp.Annual_scope
module Year_read = Bakhlo_sexp.Year_read
module Effect_coordinate = Bakhlo_domain.Effect_coordinate

exception Refused of string

let require p why = if not p then raise (Refused why)
let get why = function Ok x -> x | Error _ -> raise (Refused why)

type format = Monolithic | Records

type t = {
  path : string;
  bytes : string;
  book : B.t;
  format : format;
  engine : DA.engine option;
  session : DA.client_session option;
  annual_year : int option;
}

type outcome = Written of t | Conflict | Refused_input of string | Uncertain

let detect_format bytes =
  let trimmed = String.trim bytes in
  if String.starts_with ~prefix:";; Bakhlo Records S-expression" trimmed
     || String.starts_with ~prefix:"(frame" trimmed then
    Records
  else
    Monolithic

let read path =
  let initial = Unix.lstat path in
  require (initial.st_kind = Unix.S_REG) "regular-file-required";
  let fd = Unix.openfile path [ Unix.O_RDONLY; Unix.O_CLOEXEC ] 0 in
  Fun.protect
    ~finally:(fun () -> Unix.close fd)
    (fun () ->
      let check s =
        s.Unix.st_kind = Unix.S_REG && s.st_dev = initial.st_dev && s.st_ino = initial.st_ino
        && s.st_size = initial.st_size && s.st_mtime = initial.st_mtime
        && s.st_ctime = initial.st_ctime
      in
      require (check (Unix.fstat fd)) "changed-at-open";
      let b = Buffer.create 4096 and chunk = Bytes.create 4096 in
      let rec loop () =
        let n = Unix.read fd chunk 0 4096 in
        if n > 0 then (
          Buffer.add_subbytes b chunk 0 n;
          loop ())
      in
      loop ();
      require (check (Unix.fstat fd) && check (Unix.lstat path)) "changed-during-read";
      Buffer.contents b)

let records_revision ~lsn ~crc = Printf.sprintf "records:lsn:%d:crc:%s" lsn crc

let check_annual_path annual_year path =
  Option.iter
    (fun year -> get "annual-file-name-mismatch" (Annual.check_path ~year path))
    annual_year

let check_annual_book annual_year book =
  Option.iter
    (fun year ->
      match Annual.check_book ~year book with
      | Ok () -> ()
      | Error why -> raise (Refused why))
    annual_year

let load ?annual_year path =
  check_annual_path annual_year path;
  let initial_bytes = read path in
  (match annual_year, B.source_format_of_string initial_bytes with
   | Some _, `Records _ -> raise (Refused "annual-records-unsupported")
   | _ -> ());
  let format = detect_format initial_bytes in
  match format with
  | Monolithic ->
      let book = get "book-refused" (B.of_string initial_bytes) in
      check_annual_book annual_year book;
      { path; bytes = initial_bytes; book; format = Monolithic; engine = None; session = None;
        annual_year }
  | Records ->
      require (annual_year = None) "annual-records-unsupported";
      (* 1. First recover and open engine under lock to ensure clean truncated state *)
      let eng, act = get "records-engine-failed" (DA.recover_and_open path) in
      (match act with
      | DA.Corrupt_fail_closed { offset; reason } ->
          raise (Refused (Printf.sprintf "records-log-corrupt-at-%d: %s" offset reason))
      | DA.Truncate_failed err ->
          raise (Refused ("records-truncate-failed: " ^ err))
      | DA.Clean _ | DA.Torn_write_truncated _ -> ());

      (* 2. Read back clean content after recovery truncate, and parse book *)
      let clean_bytes = read path in
      let book = get "book-refused" (B.of_string clean_bytes) in

      (* 3. Verify consistency between Book and Engine LSN to guard against race condition *)
      let parsed_records = get "records-parse-failed" (RB.of_string clean_bytes) in
      let last_parsed_lsn, last_crc =
        match List.rev parsed_records.frames with
        | [] ->
            let h_frame = RB.encode_frame 0 (RB.Header parsed_records.header) in
            (0, h_frame.crc)
        | f :: _ -> (f.lsn, f.crc)
      in
      require (DA.current_lsn eng = last_parsed_lsn) "records-engine-book-lsn-mismatch";

      let sess = DA.create_session ~session_id:"tui-daily" () in
      Option.iter
        (fun tok -> DA.acknowledge_session sess ~token:tok ~lsn:(DA.current_lsn eng))
        (DA.latest_token eng);
      let session_bytes = records_revision ~lsn:last_parsed_lsn ~crc:last_crc in
      { path; bytes = session_bytes; book; format = Records; engine = Some eng;
        session = Some sess; annual_year = None }

let nonce () =
  let fd = Unix.openfile "/dev/urandom" [ Unix.O_RDONLY; Unix.O_CLOEXEC ] 0 in
  Fun.protect
    ~finally:(fun () -> Unix.close fd)
    (fun () ->
      let b = Bytes.create 12 in
      let rec loop n =
        if n < 12 then (
          let count = Unix.read fd b n (12 - n) in
          require (count > 0) "entropy-read";
          loop (n + count))
      in
      loop 0;
      String.concat "" (List.init 12 (fun n -> Printf.sprintf "%02x" (Char.code (Bytes.get b n)))))

let new_id () = "entry-" ^ nonce ()

let write_new path bytes =
  let fd = Unix.openfile path [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_EXCL; Unix.O_CLOEXEC ] 0o600 in
  Fun.protect
    ~finally:(fun () -> Unix.close fd)
    (fun () ->
      let rec loop n =
        if n < String.length bytes then (
          let count = Unix.write_substring fd bytes n (String.length bytes - n) in
          require (count > 0) "zero-write";
          loop (n + count))
      in
      loop 0;
      Unix.fsync fd);
  require (read path = bytes) "readback-changed"

let sync_parent path =
  let fd = Unix.openfile (Filename.dirname path) [ Unix.O_RDONLY; Unix.O_CLOEXEC ] 0 in
  Fun.protect ~finally:(fun () -> Unix.close fd) (fun () -> Unix.fsync fd)

let create_empty_with_scope ~annual_year ~path ~measure ~scale =
  check_annual_path annual_year path;
  let book = get "empty-book-refused" (B.empty ~measure ~scale) in
  check_annual_book annual_year book;
  let bytes = B.to_string book in
  write_new path bytes;
  sync_parent path;
  let session = load ?annual_year path in
  require (session.bytes = bytes) "first-run-cold-readback-changed";
  session

let create_empty ~path ~measure ~scale =
  create_empty_with_scope ~annual_year:None ~path ~measure ~scale

let create_annual_empty ~year ~path ~measure ~scale =
  create_empty_with_scope ~annual_year:(Some year) ~path ~measure ~scale

let unfinished_names path =
  let base = Filename.basename path in
  let attempt_prefix = base ^ ".attempt-" and pending_prefix = base ^ ".pending-" in
  Sys.readdir (Filename.dirname path)
  |> Array.to_list
  |> List.filter (fun name ->
      String.starts_with ~prefix:attempt_prefix name
      || String.starts_with ~prefix:pending_prefix name)
  |> List.sort String.compare

let require_finished path = require (unfinished_names path = []) "recovery-required"

type annual_book_summary = { year : int; entries : int; open_plans : int }

(* Read-only discovery of explicitly named YYYY.sexp files. Scan and admit
   every candidate before returning anything, so a corrupt year never yields
   a misleading partial list. Ordinary S-expression files are not annual. *)
let list_annual_books ~directory =
  require ((Unix.lstat directory).st_kind = Unix.S_DIR) "annual-directory-required";
  Sys.readdir directory
  |> Array.to_list
  |> List.sort String.compare
  |> List.filter_map (fun name ->
       if Filename.check_suffix name ".sexp" then
         match Annual.of_string (Filename.chop_suffix name ".sexp") with
         | Ok year -> Some year
         | Error _ -> None
       else None)
  |> List.map (fun year ->
       let path = Filename.concat directory (Annual.file_name year) in
       require_finished path;
       let session = load ~annual_year:year path in
       { year; entries = B.entry_count session.book;
         open_plans = List.length (B.open_plans session.book) })

let with_writer path f =
  let lockpath = path ^ ".lock" in
  (try require ((Unix.lstat lockpath).st_kind = Unix.S_REG) "nonregular-lock"
   with Unix.Unix_error (Unix.ENOENT, _, _) -> ());
  let fd = Unix.openfile lockpath [ Unix.O_RDWR; Unix.O_CREAT; Unix.O_CLOEXEC ] 0o600 in
  Fun.protect
    ~finally:(fun () -> Unix.close fd)
    (fun () ->
      let stat = Unix.fstat fd and named = Unix.lstat lockpath in
      require
        (stat.st_kind = Unix.S_REG && named.st_kind = Unix.S_REG && stat.st_dev = named.st_dev
       && stat.st_ino = named.st_ino)
        "changed-lock";
      Unix.lockf fd Unix.F_TLOCK 0;
      f ())

let valid_attempt_id id =
  String.length id = 24
  && String.for_all (fun c -> (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')) id

let attempt_path path id = path ^ ".attempt-" ^ id ^ ".sexp"
let pending_path path id = path ^ ".pending-" ^ id
let before_path path id = path ^ ".before-" ^ id ^ ".sexp"

let artifact_id path name =
  let base = Filename.basename path in
  let attempt_prefix = base ^ ".attempt-" and pending_prefix = base ^ ".pending-" in
  let extract prefix suffix =
    let len = String.length name - String.length prefix - String.length suffix in
    if len < 0 || not (Filename.check_suffix name suffix) then None
    else
      let id = String.sub name (String.length prefix) len in
      if valid_attempt_id id then Some id else None
  in
  if String.starts_with ~prefix:attempt_prefix name then (true, extract attempt_prefix ".sexp")
  else (false, extract pending_prefix "")

type comparison = Candidate_current | Before_current | Unresolved | Unreadable of string
type recovery_item = { name : string; attempt_id : string option; comparison : comparison }
type recovery_report = { selected : (t, string) result; items : recovery_item list }

(* A reload must retain the opt-in annual admission gate. Dropping it would
   make Ctrl-R/recovery review silently turn an annual session into an ordinary
   unscoped book, permitting subsequent cross-year publication. *)
let reload session = load ?annual_year:session.annual_year session.path

let load_result path =
  try Ok (load path) with
  | Refused why -> Error why
  | Unix.Unix_error _ | Sys_error _ -> Error "file-unavailable"

(* Read-only observations, not publication permission or proof of past outcome.
   Unrecognised/partial artifacts remain visible and block ordinary publication. *)
let inspect_recovery path =
  let selected = load_result path in
  match selected with
  | Ok { format = Records; _ } ->
      (* Records format uses append-only log recovery and never uses monolithic attempt/pending artifacts *)
      { selected; items = [] }
  | _ ->
      let names = unfinished_names path in
      let items =
        names
        |> List.filter (fun name ->
            match artifact_id path name with
            | false, Some id -> not (List.mem (Filename.basename (attempt_path path id)) names)
            | _ -> true)
    |> List.map (fun name ->
        let _, attempt_id = artifact_id path name in
        let comparison =
          match (attempt_id, selected) with
          | None, _ -> Unreadable "unrecognised-artifact-name"
          | Some _, Error _ -> Unreadable "selected-unavailable"
          | Some id, Ok current -> (
              let candidate_path = Filename.concat (Filename.dirname path) name in
              match load_result candidate_path with
              | Error why -> Unreadable ("candidate-" ^ why)
              | Ok candidate -> (
                  require
                    (read candidate_path = candidate.bytes)
                    "recovery-changed-during-inspection";
                  if current.bytes = candidate.bytes then Candidate_current
                  else
                    let before = load_result (before_path path id) in
                    match before with
                    | Ok before when before.bytes = current.bytes -> Before_current
                    | Ok _ | Error _ -> Unresolved))
        in
        { name; attempt_id; comparison })
  in
  require (unfinished_names path = names) "recovery-changed-during-inspection";
  let same_selection =
    match (selected, load_result path) with
    | Ok a, Ok b -> a.bytes = b.bytes
    | Error a, Error b -> a = b
    | _ -> false
  in
  require same_selection "recovery-changed-during-inspection";
  { selected; items }

let sync_file path =
  let fd = Unix.openfile path [ Unix.O_RDONLY; Unix.O_CLOEXEC ] 0 in
  Fun.protect
    ~finally:(fun () -> Unix.close fd)
    (fun () ->
      let stat = Unix.fstat fd and named = Unix.lstat path in
      require
        (stat.st_kind = Unix.S_REG && named.st_kind = Unix.S_REG && stat.st_dev = named.st_dev
       && stat.st_ino = named.st_ino)
        "changed-at-sync";
      Unix.fsync fd)

(* Explicitly acknowledge only an admitted candidate EXACTLY present now.
   Never acknowledge a merely newer/different file or infer non-publication. *)
let confirm_current ~session ~attempt_id =
  require (session.format = Monolithic) "cannot-confirm-records-format";
  require (valid_attempt_id attempt_id) "invalid-attempt-id";
  with_writer session.path (fun () ->
      let current = load session.path in
      require (current.bytes = session.bytes) "confirmation-base-changed";
      let attempt = attempt_path session.path attempt_id in
      let pending = pending_path session.path attempt_id in
      let exists path =
        try
          ignore (Unix.lstat path);
          true
        with Unix.Unix_error (Unix.ENOENT, _, _) -> false
      in
      let has_attempt = exists attempt and has_pending = exists pending in
      require (has_attempt || has_pending) "attempt-not-found";
      let candidate = load (if has_attempt then attempt else pending) in
      require (candidate.bytes = current.bytes) "candidate-not-current";
      if has_pending then require (read pending = candidate.bytes) "pending-differs";
      sync_file session.path;
      sync_parent session.path;
      require (read session.path = current.bytes) "confirmation-base-changed";
      if has_pending then Unix.unlink pending;
      if has_attempt then Unix.unlink attempt;
      sync_parent session.path;
      require (read session.path = current.bytes) "confirmation-readback-changed";
      current)

(* Restore only to an explicitly fresh target, preserving original bytes. A
   checked copy is not automatic adoption, reconciliation or a format upgrade. *)
let restore_copy ~source ~target =
  let original = load source in
  require (original.format = Monolithic) "cannot-restore-records-as-monolithic-copy";
  write_new target original.bytes;
  sync_parent target;
  require (read source = original.bytes) "source-changed-during-restore";
  require ((load target).bytes = original.bytes) "restored-readback-changed"

let create_copy ~source ~target =
  let original = load source in
  require (original.format = Monolithic) "cannot-copy-records-as-monolithic";
  require_finished source;
  let bytes = B.to_string original.book in
  ignore (get "printed-book-refused" (B.of_string bytes));
  write_new target bytes;
  sync_parent target;
  require (read source = original.bytes) "source-changed-during-copy"

let copy_records ~source ~target =
  let original = load source in
  require (original.format = Records) "cannot-copy-monolithic-as-records";
  let content = read source in
  write_new target content;
  sync_parent target;
  let copied = load target in
  require (copied.bytes = original.bytes) "copied-records-readback-changed"

let export_monolithic ~session ~target =
  let bytes = B.to_string session.book in
  ignore (get "printed-book-refused" (B.of_string bytes));
  write_new target bytes;
  sync_parent target;
  let loaded = load target in
  require (loaded.format = Monolithic) "exported-not-monolithic"

type publication_step =
  | Attempt_synced
  | Pending_written
  | Backup_written
  | Outputs_synced
  | Selected_replaced
  | Selected_synced
  | Attempt_removed

(* Checkpoints are for deterministic fault/child-process interruption checks;
   ordinary callers use the no-op default and cannot bypass any gate. *)
let publish ?(checkpoint = fun _ -> ()) session book =
  require (session.format = Monolithic) "cannot-rewrite-records-format-as-monolithic";
  let attempted = ref false in
  try
    let bytes = B.to_string book in
    let checked = get "printed-book-refused" (B.of_string bytes) in
    require (B.to_string checked = bytes) "unstable-printer";
    check_annual_path session.annual_year session.path;
    check_annual_book session.annual_year checked;
    with_writer session.path (fun () ->
        require_finished session.path;
        if read session.path <> session.bytes then Conflict
        else
          let suffix = nonce () in
          let attempt = attempt_path session.path suffix in
          let pending = pending_path session.path suffix in
          let backup = before_path session.path suffix in
          attempted := true;
          (* This independent candidate survives pending -> selected rename.
             A partial attempt file also conservatively freezes cold writes. *)
          write_new attempt bytes;
          sync_parent session.path;
          checkpoint Attempt_synced;
          write_new pending bytes;
          checkpoint Pending_written;
          write_new backup session.bytes;
          checkpoint Backup_written;
          sync_parent session.path;
          checkpoint Outputs_synced;
          if read session.path <> session.bytes then Conflict
          else (
            Unix.rename pending session.path;
            checkpoint Selected_replaced;
            sync_parent session.path;
            require (read session.path = bytes) "selected-readback-changed";
            checkpoint Selected_synced;
            (* Only our completed temporary attempt is removed; backups stay. *)
            Unix.unlink attempt;
            checkpoint Attempt_removed;
            sync_parent session.path;
            Written { session with bytes; book = checked }))
  with
  | Refused why -> if !attempted then Uncertain else Refused_input why
  | Unix.Unix_error _ | Sys_error _ ->
      if !attempted then Uncertain else Refused_input "file-or-writer-unavailable"

type append_outcome =
  | Append_committed of { session : t; lsn : int; event_id : string }
  | Append_idempotent of { session : t; lsn : int; event_id : string }
  | Append_lsn_conflict of { expected : int; actual : int }
  | Append_drift_refused of string
  | Append_storage_error of string
  | Append_sync_uncertain of { session : t; lsn : int; event_id : string; error : string }

let append_entry ?candidate session (e : RB.entry) =
  require (session.format = Records) "cannot-append-to-monolithic-format";
  match session.engine, session.session with
  | Some eng, Some sess ->
      let expected_lsn = DA.current_lsn eng + 1 in
      let res = DA.append_entry eng ~session:sess ~expected_lsn e in
      (match res with
      | DA.Commit_success { lsn; event_id } ->
          Option.iter (fun tok -> DA.acknowledge_session sess ~token:tok ~lsn) e.token;
          let new_book =
            match candidate with
            | Some b -> b
            | None ->
                let b_str = read session.path in
                get "book-refused" (B.of_string b_str)
          in
          let frame = RB.encode_frame lsn (RB.Entry e) in
          let new_bytes = records_revision ~lsn ~crc:frame.crc in
          Append_committed { session = { session with bytes = new_bytes; book = new_book }; lsn; event_id }
      | DA.Sync_uncertain { lsn; event_id; error } ->
          (* Note: Do NOT acknowledge_session here. Sync_uncertain means client Ack is unconfirmed,
             preserving in-doubt state for safety against silent duplicate entry. *)
          let new_book =
            match candidate with
            | Some b -> b
            | None ->
                let b_str = read session.path in
                get "book-refused" (B.of_string b_str)
          in
          let frame = RB.encode_frame lsn (RB.Entry e) in
          let new_bytes = records_revision ~lsn ~crc:frame.crc in
          Append_sync_uncertain { session = { session with bytes = new_bytes; book = new_book }; lsn; event_id; error }
      | DA.Idempotent_duplicate { lsn; event_id } ->
          Append_idempotent { session; lsn; event_id }
      | DA.Lsn_conflict { expected; actual } ->
          Append_lsn_conflict { expected; actual }
      | DA.Payload_drift_refused msg ->
          Append_drift_refused msg
      | DA.Storage_error err ->
          Append_storage_error err)
  | _ -> raise (Refused "engine-not-initialized")

let append_add_locus ?candidate session locus =
  require (session.format = Records) "cannot-append-to-monolithic-format";
  match session.engine, session.session with
  | Some eng, Some sess ->
      let expected_lsn = DA.current_lsn eng + 1 in
      let payload = RB.Add_locus { locus; opaque = [] } in
      let token = Some (Printf.sprintf "req-locus-%s" locus) in
      let res = DA.append_payload eng ~session:sess ~expected_lsn ~token ~event_id:locus ~payload in
      (match res with
      | DA.Commit_success { lsn; event_id } ->
          Option.iter (fun tok -> DA.acknowledge_session sess ~token:tok ~lsn) token;
          let new_book =
            match candidate with
            | Some b -> b
            | None ->
                let b_str = read session.path in
                get "book-refused" (B.of_string b_str)
          in
          let frame = RB.encode_frame lsn payload in
          let new_bytes = records_revision ~lsn ~crc:frame.crc in
          Append_committed { session = { session with bytes = new_bytes; book = new_book }; lsn; event_id }
      | DA.Sync_uncertain { lsn; event_id; error } ->
          let new_book =
            match candidate with
            | Some b -> b
            | None ->
                let b_str = read session.path in
                get "book-refused" (B.of_string b_str)
          in
          let frame = RB.encode_frame lsn payload in
          let new_bytes = records_revision ~lsn ~crc:frame.crc in
          Append_sync_uncertain { session = { session with bytes = new_bytes; book = new_book }; lsn; event_id; error }
      | DA.Idempotent_duplicate { lsn; event_id } ->
          Append_idempotent { session; lsn; event_id }
      | DA.Lsn_conflict { expected; actual } ->
          Append_lsn_conflict { expected; actual }
      | DA.Payload_drift_refused msg ->
          Append_drift_refused msg
      | DA.Storage_error err ->
          Append_storage_error err)
  | _ -> raise (Refused "engine-not-initialized")

let today () =
  let tm = Unix.localtime (Unix.time ()) in
  Printf.sprintf "%04d-%02d-%02d" (tm.Unix.tm_year + 1900) (tm.Unix.tm_mon + 1) tm.Unix.tm_mday

type annual_rollover_preview = {
  prior_year : int;
  year : int;
  prior_fingerprint : string;
  current_fingerprint : string;
  balances : (Effect_coordinate.t * Year_read.balance) list;
  open_plans : B.plan list;
}

let preview_annual_rollover ~directory ~year ~coordinates =
  require (year >= 2 && year <= 9999) "annual-year-invalid";
  let prior_year = year - 1 in
  require ((Unix.lstat directory).st_kind = Unix.S_DIR) "annual-directory-required";
  let prior_path = Filename.concat directory (Annual.file_name prior_year) in
  let current_path = Filename.concat directory (Annual.file_name year) in
  require (prior_path <> current_path) "annual-same-paths";
  let safe_stat path why =
    try
      let st = Unix.lstat path in
      require (st.st_kind = Unix.S_REG) why;
      st
    with Unix.Unix_error _ | Sys_error _ -> raise (Refused why)
  in
  let pst = safe_stat prior_path "annual-file-missing" in
  let cst = safe_stat current_path "annual-file-missing" in
  require (pst.st_dev <> cst.st_dev || pst.st_ino <> cst.st_ino) "annual-same-paths";
  try
    with_writer prior_path (fun () ->
      with_writer current_path (fun () ->
        require_finished prior_path;
        require_finished current_path;
        let prior_session = load ~annual_year:prior_year prior_path in
        let current_session = load ~annual_year:year current_path in
        let module StringSet = Set.Make (String) in
        let prior_plan_ids =
          List.fold_left
            (fun s (p : B.plan) -> StringSet.add p.id s)
            StringSet.empty (B.plans prior_session.book)
        in
        List.iter
          (fun (p : B.plan) ->
            require (not (StringSet.mem p.id prior_plan_ids)) "overlapping-plan-id")
          (B.plans current_session.book);
        List.iter
          (fun (e : B.entry) ->
            require (not (B.mem_entry current_session.book e.id)) "overlapping-entry-id")
          (B.entries prior_session.book);
        let prior_bytes = prior_session.bytes in
        let current_bytes = current_session.bytes in
        let prior_fp_str = Stdlib.Digest.to_hex (Stdlib.Digest.string prior_bytes) in
        let current_fp_str = Stdlib.Digest.to_hex (Stdlib.Digest.string current_bytes) in
        let prior_fp = Year_read.fingerprint prior_bytes in
        let current_fp = Year_read.fingerprint current_bytes in
        let module Source = struct
          type snapshot = {
            selection : Year_read.selection;
            prior_orig : Year_read.original;
            curr_orig : Year_read.original;
          }
          (* Ephemeral invocation generation/revision only identify this snapshot, not persisted/global authority. *)
          let acquire () =
            let gen = 1 in
            let years = [
              { Year_read.year = prior_year; revision = 1; fingerprint = prior_fp };
              { Year_read.year = year; revision = 1; fingerprint = current_fp };
            ] in
            let selection = { Year_read.generation = gen; years } in
            let prior_orig = { Year_read.generation = gen; year = prior_year; revision = 1; contents = prior_bytes } in
            let curr_orig = { Year_read.generation = gen; year; revision = 1; contents = current_bytes } in
            Ok { selection; prior_orig; curr_orig }
          let selection s = s.selection
          let read s ~year:y =
            if y = prior_year then Ok s.prior_orig
            else if y = year then Ok s.curr_orig
            else Error (Year_read.Year_missing y)
        end in
        let module R = Year_read.Make (Source) in
        let session =
          match R.begin_session () with
          | Ok s -> s
          | Error _ -> raise (Refused "rollover-session-failed")
        in
        let prior_v =
          match R.load_year session ~year:prior_year with
          | Ok v -> v
          | Error _ -> raise (Refused "rollover-prior-load-failed")
        in
        let carry =
          match R.derive_carry_forward session prior_v with
          | Ok c -> c
          | Error _ -> raise (Refused "rollover-carry-failed")
        in
        let annual_read =
          match R.read_with_carry session ~year carry with
          | Ok r -> r
          | Error _ -> raise (Refused "rollover-read-failed")
        in
        let balances =
          List.map (fun coord -> (coord, R.carry_balance annual_read coord)) coordinates
        in
        let open_plans = B.open_plans prior_session.book in
        require (read prior_path = prior_bytes) "prior-source-changed";
        require (read current_path = current_bytes) "current-source-changed";
        require_finished prior_path;
        require_finished current_path;
        {
          prior_year;
          year;
          prior_fingerprint = prior_fp_str;
          current_fingerprint = current_fp_str;
          balances;
          open_plans;
        }))
  with
  | Refused _ as exn -> raise exn
  | Unix.Unix_error _ | Sys_error _ -> raise (Refused "file-or-writer-unavailable")
