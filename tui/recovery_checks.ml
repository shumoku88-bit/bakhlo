(* Synthetic persistence/restart checks; never inspect household inputs.
   Checkpoint faults and SIGKILL are not hardware power-loss qualification. *)
module F = Daily_file
module C = Daily_interaction
module A = Daily_actions
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query

let get = function Ok x -> x | Error why -> raise (F.Refused why)
let require = F.require
let files directory = Sys.readdir directory |> Array.to_list |> List.sort String.compare

let refuses why f =
  try
    f ();
    raise (F.Refused ("missing-refusal-" ^ why))
  with F.Refused actual -> require (actual = why) ("wrong-refusal-" ^ actual)

let io_refuses f =
  try
    f ();
    raise (F.Refused "missing-IO-refusal")
  with Unix.Unix_error _ | Sys_error _ -> ()

let quantity book locus measure =
  let coordinate : D.Effect_coordinate.t =
    {
      locus = C.get_id (D.Identifier.Locus.of_string locus);
      measure = C.get_id (D.Identifier.Measure.of_string measure);
    }
  in
  match Q.query (B.image book) coordinate with
  | Ok (Q.Exact n) -> Z.to_string (D.Quantity.quanta (Q.quantity n))
  | Ok (Q.Known_present _) -> "presence"
  | Error (Q.Support_unknown _) -> "unknown"

let self_check () =
  let directory = "scratch/recovery-check-" ^ F.new_id () in
  Unix.mkdir directory 0o700;
  let wire = F.read "examples/daily-book.sexp" in
  let base = get (B.of_string wire) in
  let huge = Z.of_string "12345678901234567890123456789012" in
  let posting measure locus amount =
    D.Effect.create ~key:None
      ~locus:(C.get_id (D.Identifier.Locus.of_string locus))
      ~measure:(C.get_id (D.Identifier.Measure.of_string measure))
      ~quantity:(D.Quantity.of_quanta amount)
  in
  let entry id measure : B.entry =
    {
      id;
      day = "2026-11-03";
      memo = Some "合成\"\\\t\000";
      effects = [ posting measure "wallet" (Z.neg huge); posting measure "food" huge ];
      reversal_of = None;
      exchange = None;
    }
  in
  let payment = entry "recovery-payment" "jpy" in
  let candidate = get (B.put_entry base ~replace:false payment ~plan:(Some "planned-food")) in
  let candidate =
    get (B.put_entry candidate ~replace:false (entry "recovery-eur" "eur") ~plan:None)
  in
  let budget : B.budget =
    {
      id = "retained-budget";
      start_day = "2026-11-01";
      end_exclusive = "2026-12-01";
      measure = "jpy";
      allocations = [ ("food-purpose", huge) ];
      expense_loci = [ "food" ];
      actual_routes = [ ("food", Some "food-purpose") ];
      plan_routes = [ ("planned-food", "food", Some "food-purpose") ];
    }
  in
  let candidate = get (B.put_budget candidate ~replace:false budget) in
  let candidate_bytes = B.to_string candidate in
  let make name =
    let parent = directory ^ "/" ^ name in
    Unix.mkdir parent 0o700;
    let path = parent ^ "/book.sexp" in
    F.write_new path wire;
    F.load path
  in
  let cold session = C.initial ~config_home:(Filename.dirname session.F.path) session in
  let check_candidate book =
    require
      (quantity book "wallet" "jpy" = Z.to_string (Z.sub (Z.of_int 1000) huge)
      && quantity book "food" "jpy" = Z.to_string huge
      && quantity book "wallet" "eur" = Z.to_string (Z.sub (Z.of_int 10000) huge)
      && quantity book "food" "eur" = "unknown"
      && quantity book "bank" "jpy" = "unknown")
      "recovery-quantity-or-unknown-lost";
    require ((List.hd (B.plans book)).paid_by = Some payment.id) "recovery-payment-link-lost";
    require
      (B.to_string book = candidate_bytes && B.budgets book = Some [ budget ])
      "recovery-metadata-or-v4-lost"
  in
  let readonly_report session =
    let parent = Filename.dirname session.F.path in
    let before_files = files parent and before_bytes = F.read session.path in
    let report = F.inspect_recovery session.path in
    require
      (files parent = before_files && F.read session.path = before_bytes)
      "recovery-inspection-mutated-files";
    report
  in
  let check_frozen session =
    let state = cold (F.load session.F.path) in
    require state.blocked "recovery-cold-open-not-frozen";
    let reset =
      match C.handle state (`Key (`ASCII 'N', [ `Ctrl ])) with
      | Some s -> s
      | None -> raise (F.Refused "recovery-reset-exited")
    in
    require
      (reset.blocked && (C.reload reset).blocked && C.submit reset == reset)
      "recovery-reset-reload-or-submit-bypassed-stop";
    (match F.publish session candidate with
    | F.Refused_input "recovery-required" -> ()
    | _ -> raise (F.Refused "recovery-direct-publisher-bypassed-stop"));
    let result = A.commit_add_locus ~session "new-recovery-only" in
    require (result = A.Recovery_blocked) "recovery-application-did-not-freeze";
    let applied = C.apply_commit_result (cold session) ~draft:(cold session) result in
    require applied.blocked "recovery-commit-stop-not-reflected";
    refuses "recovery-required" (fun () ->
        F.create_copy ~source:session.path ~target:(session.path ^ ".ordinary-copy"))
  in
  (* The pre-fix runtime counterexample: a partial legacy pending file was ignored. *)
  let legacy = make "legacy" in
  let legacy_id = String.make 24 'a' in
  F.write_new (F.pending_path legacy.path legacy_id) "partial synthetic output";
  check_frozen legacy;
  (match (readonly_report legacy).items with
  | [ { F.comparison = F.Unreadable _; _ } ] -> ()
  | _ -> raise (F.Refused "recovery-partial-pending-hidden"));
  refuses "book-refused" (fun () ->
      ignore (F.confirm_current ~session:legacy ~attempt_id:legacy_id));
  let fresh = directory ^ "/legacy-restored.sexp" in
  F.restore_copy ~source:legacy.path ~target:fresh;
  require
    (F.read fresh = wire
    && (not (cold (F.load fresh)).blocked)
    && (cold (F.load legacy.path)).blocked)
    "recovery-copy-adopted-or-upgraded-original";
  io_refuses (fun () -> F.restore_copy ~source:legacy.path ~target:fresh);
  require (F.read fresh = wire) "recovery-overwrote-existing-target";
  let bad_target = directory ^ "/bad-restored.sexp" in
  refuses "book-refused" (fun () ->
      F.restore_copy ~source:(F.pending_path legacy.path legacy_id) ~target:bad_target);
  require (not (Sys.file_exists bad_target)) "recovery-invalid-source-created-target";

  let steps =
    [
      F.Attempt_synced;
      F.Pending_written;
      F.Backup_written;
      F.Outputs_synced;
      F.Selected_replaced;
      F.Selected_synced;
      F.Attempt_removed;
    ]
  in
  let selected_changed = function
    | F.Selected_replaced | F.Selected_synced | F.Attempt_removed -> true
    | _ -> false
  in
  let check_interruption step session =
    let expected = if selected_changed step then candidate_bytes else wire in
    require (F.read session.F.path = expected) "recovery-interruption-wrong-selected";
    let loaded = F.load session.path in
    let report = readonly_report loaded in
    if step = F.Attempt_removed then (
      require
        (report.items = [] && not (cold loaded).blocked)
        "recovery-completed-attempt-not-clear";
      check_candidate loaded.book)
    else (
      check_frozen loaded;
      let item =
        match report.items with
        | [ item ] -> item
        | _ -> raise (F.Refused "recovery-attempt-not-identified")
      in
      let id =
        match item.attempt_id with
        | Some id -> id
        | None -> raise (F.Refused "recovery-generated-id-invalid")
      in
      let expected_comparison =
        match step with
        | F.Attempt_synced | F.Pending_written -> F.Unresolved
        | F.Backup_written | F.Outputs_synced -> F.Before_current
        | F.Selected_replaced | F.Selected_synced -> F.Candidate_current
        | F.Attempt_removed -> raise (F.Refused "recovery-step-unreachable")
      in
      require (item.comparison = expected_comparison) "recovery-comparison-guessed-outcome";
      let copy = session.path ^ ".candidate-copy" in
      F.restore_copy ~source:(F.attempt_path session.path id) ~target:copy;
      require
        (F.read copy = candidate_bytes && F.read session.path = expected)
        "recovery-candidate-copy-changed-original";
      check_candidate (F.load copy).book;
      if selected_changed step then (
        let memory =
          C.apply_commit_result (cold session) ~draft:(cold session) (A.Uncertain candidate_bytes)
        in
        let stopped = C.reload memory in
        require
          (stopped.blocked && stopped.pending = Some candidate_bytes)
          "recovery-reload-silently-acknowledged-marker";
        ignore (F.confirm_current ~session:loaded ~attempt_id:id);
        let resumed = C.reload stopped in
        require
          ((not resumed.blocked) && resumed.pending = None && resumed.form.amount = "")
          "recovery-confirmation-retained-retry-draft";
        require
          (F.unfinished_names session.path = []
          && F.read (F.before_path session.path id) = wire
          && F.read session.path = candidate_bytes)
          "recovery-confirmation-deleted-backup-or-book";
        check_candidate (F.load session.path).book;
        require
          (match
             B.put_entry (F.load session.path).book ~replace:false
               { payment with id = "duplicate-payment" }
               ~plan:(Some "planned-food")
           with
          | Error _ -> true
          | Ok _ -> false)
          "recovery-paid-plan-retried")
      else (
        refuses "candidate-not-current" (fun () ->
            ignore (F.confirm_current ~session:loaded ~attempt_id:id));
        require
          (F.unfinished_names session.path <> [] && F.read session.path = wire)
          "recovery-unpublished-candidate-adopted";
        if step = F.Backup_written || step = F.Outputs_synced then (
          let copy = session.path ^ ".before-copy" in
          F.restore_copy ~source:(F.before_path session.path id) ~target:copy;
          require
            (F.read copy = wire && (List.hd (B.plans (F.load copy).book)).paid_by = None)
            "recovery-before-copy-lost-original-plan")))
  in
  List.iteri
    (fun n step ->
      let session = make ("fault-" ^ string_of_int n) in
      let result =
        F.publish
          ~checkpoint:(fun reached ->
            if reached = step then raise (Sys_error "synthetic checkpoint failure"))
          session candidate
      in
      require (result = F.Uncertain) "recovery-fault-reported-success";
      check_interruption step session)
    steps;

  (* Child processes die while holding the actual publisher lock, not a mock state. *)
  List.iteri
    (fun n step ->
      let session = make ("kill-" ^ string_of_int n) in
      let input, output = Unix.pipe () in
      match Unix.fork () with
      | 0 ->
          Unix.close input;
          ignore
            (F.publish
               ~checkpoint:(fun reached ->
                 if reached = step then (
                   ignore (Unix.write_substring output "!" 0 1);
                   while true do
                     Unix.sleep 3600
                   done))
               session candidate);
          Unix._exit 2
      | pid ->
          Unix.close output;
          let reaped = ref false in
          Fun.protect
            ~finally:(fun () ->
              Unix.close input;
              if not !reaped then (
                (try Unix.kill pid Sys.sigkill with Unix.Unix_error (Unix.ESRCH, _, _) -> ());
                ignore (Unix.waitpid [] pid)))
            (fun () ->
              let ready, _, _ = Unix.select [ input ] [] [] 10. in
              require (ready <> []) "recovery-child-checkpoint-timeout";
              let signal = Bytes.create 1 in
              require (Unix.read input signal 0 1 = 1) "recovery-child-exited-before-checkpoint";
              Unix.kill pid Sys.sigkill;
              let _, status = Unix.waitpid [] pid in
              reaped := true;
              require (status = Unix.WSIGNALED Sys.sigkill) "recovery-child-not-killed";
              check_interruption step session))
    steps;

  let malformed = make "malformed" in
  F.write_new (malformed.path ^ ".attempt-unrecognised.sexp") "broken";
  (match (readonly_report malformed).items with
  | [ { F.attempt_id = None; comparison = F.Unreadable _; _ } ] -> ()
  | _ -> raise (F.Refused "recovery-malformed-name-hidden"));
  check_frozen malformed;
  let before = files (Filename.dirname malformed.path) in
  refuses "invalid-attempt-id" (fun () ->
      ignore (F.confirm_current ~session:malformed ~attempt_id:"../not-an-id"));
  require (files (Filename.dirname malformed.path) = before) "recovery-invalid-id-mutated-namespace";

  let later = make "later-generation" in
  ignore
    (F.publish
       ~checkpoint:(fun step -> if step = F.Selected_synced then raise (Sys_error "synthetic"))
       later candidate);
  let item = List.hd (F.inspect_recovery later.path).items in
  let id =
    match item.attempt_id with Some id -> id | None -> raise (F.Refused "recovery-no-id")
  in
  let current = F.load later.path in
  let changed = get (B.add_locus current.book "synthetic-extra") in
  F.write_new (later.path ^ ".external") (B.to_string changed);
  Unix.rename (later.path ^ ".external") later.path;
  (match (F.inspect_recovery later.path).items with
  | [ { F.comparison = F.Unresolved; _ } ] -> ()
  | _ -> raise (F.Refused "recovery-later-generation-counted-as-confirmed"));
  refuses "confirmation-base-changed" (fun () ->
      ignore (F.confirm_current ~session:current ~attempt_id:id));
  refuses "candidate-not-current" (fun () ->
      ignore (F.confirm_current ~session:(F.load later.path) ~attempt_id:id));
  require
    (F.unfinished_names later.path <> [] && (F.load later.path).bytes = B.to_string changed)
    "recovery-later-generation-overwritten";

  let missing = make "missing-selected" in
  F.write_new (F.attempt_path missing.path legacy_id) candidate_bytes;
  Unix.unlink missing.path;
  let report = F.inspect_recovery missing.path in
  require
    (match report.selected with Error _ -> true | Ok _ -> false)
    "recovery-missing-selected-became-empty";
  require (report.items <> []) "recovery-missing-selected-hid-artifacts";
  let copy = missing.path ^ ".restored" in
  F.restore_copy ~source:(F.attempt_path missing.path legacy_id) ~target:copy;
  check_candidate (F.load copy).book;
  require (not (Sys.file_exists missing.path)) "recovery-automatically-restored-selected";

  let io_failure = make "real-write-failure" in
  let failure =
    F.publish
      ~checkpoint:(fun step ->
        if step = F.Attempt_synced then
          let item = List.hd (F.inspect_recovery io_failure.path).items in
          let id =
            match item.attempt_id with
            | Some id -> id
            | None -> raise (F.Refused "recovery-write-failure-no-id")
          in
          Unix.mkdir (F.pending_path io_failure.path id) 0o700)
      io_failure candidate
  in
  require
    (failure = F.Uncertain && F.read io_failure.path = wire)
    "recovery-real-write-failure-wrote-or-acknowledged";
  check_frozen io_failure;

  let partial = make "partial-attempt" in
  F.write_new (F.attempt_path partial.path legacy_id) "incomplete candidate";
  (match (readonly_report partial).items with
  | [ { F.comparison = F.Unreadable _; _ } ] -> ()
  | _ -> raise (F.Refused "recovery-partial-attempt-hidden"));
  check_frozen partial;

  let partial_pending = make "current-with-partial-pending" in
  F.write_new (F.attempt_path partial_pending.path legacy_id) wire;
  F.write_new (F.pending_path partial_pending.path legacy_id) "partial output";
  refuses "pending-differs" (fun () ->
      ignore (F.confirm_current ~session:partial_pending ~attempt_id:legacy_id));
  require
    (List.length (F.unfinished_names partial_pending.path) = 2 && F.read partial_pending.path = wire)
    "recovery-confirmation-deleted-partial-evidence";
  check_frozen partial_pending;

  let multiple = make "multiple-attempts" in
  let other_id = String.make 24 'b' in
  F.write_new (F.attempt_path multiple.path legacy_id) candidate_bytes;
  F.write_new (F.attempt_path multiple.path other_id) wire;
  require (List.length (readonly_report multiple).items = 2) "recovery-multiple-attempt-hidden";
  ignore (F.confirm_current ~session:multiple ~attempt_id:other_id);
  require
    (List.length (readonly_report multiple).items = 1 && (cold (F.load multiple.path)).blocked)
    "recovery-one-confirmation-cleared-other-attempt";
  check_frozen multiple;

  let nonregular = make "nonregular" in
  Unix.symlink "book.sexp" (F.attempt_path nonregular.path legacy_id);
  (match (readonly_report nonregular).items with
  | [ { F.comparison = F.Unreadable _; _ } ] -> ()
  | _ -> raise (F.Refused "recovery-symlink-read-as-candidate"));
  refuses "regular-file-required" (fun () ->
      ignore (F.confirm_current ~session:nonregular ~attempt_id:legacy_id));
  check_frozen nonregular;
  let bad_namespace = { nonregular with F.path = nonregular.path ^ "/not-a-directory" } in
  require
    (A.recovery_notice ~session:bad_namespace <> None && (cold bad_namespace).blocked)
    "recovery-scan-failure-became-clear";
  io_refuses (fun () -> ignore (F.inspect_recovery bad_namespace.path));

  let locked = make "writer-lock" in
  F.write_new (F.attempt_path locked.path legacy_id) wire;
  let input, output = Unix.pipe () in
  (match Unix.fork () with
  | 0 ->
      Unix.close input;
      F.with_writer locked.path (fun () ->
          ignore (Unix.write_substring output "!" 0 1);
          while true do
            Unix.sleep 3600
          done);
      Unix._exit 2
  | pid ->
      Unix.close output;
      let reaped = ref false in
      Fun.protect
        ~finally:(fun () ->
          Unix.close input;
          if not !reaped then (
            (try Unix.kill pid Sys.sigkill with Unix.Unix_error (Unix.ESRCH, _, _) -> ());
            ignore (Unix.waitpid [] pid)))
        (fun () ->
          let ready, _, _ = Unix.select [ input ] [] [] 10. in
          require
            (ready <> [] && Unix.read input (Bytes.create 1) 0 1 = 1)
            "recovery-writer-lock-not-acquired";
          (match F.publish locked candidate with
          | F.Refused_input "file-or-writer-unavailable" -> ()
          | _ -> raise (F.Refused "recovery-publication-bypassed-writer-lock"));
          io_refuses (fun () -> ignore (F.confirm_current ~session:locked ~attempt_id:legacy_id));
          require
            (F.read locked.path = wire && F.unfinished_names locked.path <> [])
            "recovery-lock-failure-mutated-files";
          Unix.kill pid Sys.sigkill;
          ignore (Unix.waitpid [] pid);
          reaped := true));
  ignore (F.confirm_current ~session:locked ~attempt_id:legacy_id);
  require
    (F.unfinished_names locked.path = [] && F.read locked.path = wire)
    "recovery-confirm-after-lock-release-failed";

  let healthy = make "healthy" in
  require ((readonly_report healthy).items = []) "recovery-healthy-not-clear";
  (match F.publish healthy candidate with
  | F.Written saved -> check_candidate saved.book
  | _ -> raise (F.Refused "recovery-normal-save-refused"));
  require
    (F.unfinished_names healthy.path = [] && not (cold (F.load healthy.path)).blocked)
    "recovery-normal-save-left-active-attempt";

  (* Records S-expression format coexistence and durable append checks *)
  let rec_path = Filename.concat directory "records-store.log" in
  let rec_h : Bakhlo_sexp.Records_book.header = {
    version = 1;
    measures = [ ("jpy", 0) ];
    labels = None;
    approved_loci = Some [ "wallet"; "food" ];
    origins = [];
    openings = [];
    observations = [];
    presence = None;
    opaque = [];
  } in
  let rec_log = Bakhlo_sexp.Records_book.to_string { header = rec_h; frames = [] } in
  F.write_new rec_path rec_log;
  let rec_session = F.load rec_path in
  require (rec_session.format = F.Records) "records-format-not-detected";

  (* Safe guard 1: Attempting monolithic publish on Records format MUST be refused *)
  refuses "cannot-rewrite-records-format-as-monolithic" (fun () ->
    ignore (F.publish rec_session rec_session.book));

  (* Safe guard 2: Attempting Records append on Monolithic format MUST be refused *)
  let mono_e = entry "mono-test" "jpy" in
  let rec_entry = A.to_records_entry mono_e in
  refuses "cannot-append-to-monolithic-format" (fun () ->
    ignore (F.append_entry healthy rec_entry));

  (* Commit transaction via Daily_actions on Records format: should append without full rewrite *)
  let tx : A.transaction = { entry = mono_e; replace = false; plan = None } in
  let rec_commit_res = A.commit_transaction ~session:rec_session ~base_bytes:rec_session.bytes tx in
  (match rec_commit_res with
  | A.Published updated ->
      require (updated.format = F.Records) "updated-format-not-records";
      require (List.length (B.entries updated.book) = 1) "records-entry-not-admitted";
      (* Re-read from disk to ensure durable append occurred on disk *)
      let reloaded = F.load rec_path in
      require (reloaded.format = F.Records) "reloaded-not-records";
      require (List.length (B.entries reloaded.book) = 1) "reloaded-entries-not-preserved";
      (* Fast-Ack idempotency check on same transaction *)
      (match A.commit_transaction ~session:updated ~base_bytes:updated.bytes tx with
      | A.Idempotent_duplicate _ -> ()
      | _ -> raise (F.Refused "records-idempotency-failed"))
  | _ -> raise (F.Refused "records-commit-transaction-failed"));

  Printf.printf "Recovery fixtures (synthetic): %s\n%!" directory;
  print_endline
    "PASS: durable candidate attempts, read-only recovery, explicit current-byte \
     confirmation/fresh restore, cold/Ctrl-N/reload/direct-write stops, 7 injected faults + 7 \
     SIGKILL checkpoints, exact quantities/v4/payment links and no automatic retry/pruning."
