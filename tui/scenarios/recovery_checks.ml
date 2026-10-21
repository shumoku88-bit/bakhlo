(* Synthetic persistence/restart checks of the append-only book; never inspect
   household inputs. Checkpoint faults and SIGKILL are not hardware power-loss
   qualification. *)
module F = Daily_file
module C = Shell_state
module H = Shell_input
module A = Daily_actions
module B = Bakhlo_sexp.Daily_book
module L = Bakhlo_sexp.Book_log
module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query

let get = function Ok x -> x | Error why -> raise (F.Refused why)
let require = F.require
let files directory = Sys.readdir directory |> Array.to_list |> List.sort String.compare

let refuses why f =
  match f () with
  | () -> raise (F.Refused ("expected refusal " ^ why))
  | exception F.Refused actual when actual = why -> ()

let io_refuses f =
  match f () with
  | () -> raise (F.Refused "expected file failure")
  | exception (Unix.Unix_error _ | Sys_error _) -> ()

let quantity book locus measure =
  let coordinate : D.Effect_coordinate.t =
    {
      locus = C.get_id (D.Identifier.Locus.of_string locus);
      measure = C.get_id (D.Identifier.Measure.of_string measure);
    }
  in
  match Q.query (B.image book) coordinate with
  | Ok (Q.Exact x) -> Z.to_string (D.Quantity.quanta (Q.quantity x))
  | Ok (Q.Known_present _) -> "present"
  | Error _ -> "unknown"

let self_check () =
  let directory = "scratch/recovery-check-" ^ F.new_id () in
  Unix.mkdir directory 0o700;
  let wire = F.read Interaction_check_fixture.example_book in
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
      original_amount = None;
      merchant = None;
    }
  in
  let payment = entry "recovery-payment" "jpy" in
  (* One publication of two operations: an atomic plan payment and another entry. *)
  let ops =
    [
      L.Put_entry { replace = false; entry = payment; plan = Some "planned-food" };
      L.Put_entry { replace = false; entry = entry "recovery-eur" "eur"; plan = None };
    ]
  in
  let expected_book = B.to_string (get (L.apply_all base ops)) in
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
    require (B.to_string book = expected_book) "recovery-metadata-lost"
  in
  let check_original book =
    require
      ((List.hd (B.plans book)).paid_by = None && B.to_string book = B.to_string base)
      "recovery-original-not-kept"
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
  (* An interrupted final append freezes every write path until it is discarded. *)
  let check_frozen session =
    let state = cold (F.load session.F.path) in
    require state.blocked "recovery-cold-open-not-frozen";
    let reset =
      match H.handle state (`Key (`ASCII 'N', [ `Ctrl ])) with
      | Some s -> s
      | None -> raise (F.Refused "recovery-reset-exited")
    in
    require
      (reset.blocked && (Shell_dispatch.reload reset).blocked && C.submit reset == reset)
      "recovery-reset-reload-or-submit-bypassed-stop";
    (match F.append (F.load session.path) ops with
    | F.Refused_input "torn-tail" -> ()
    | _ -> raise (F.Refused "recovery-direct-publisher-bypassed-stop"));
    let result = A.commit_add_locus ~session:(F.load session.path) "new-recovery-only" in
    require (result = A.Recovery_blocked) "recovery-application-did-not-freeze";
    let applied =
      C.apply_commit_result ~record_publication:false (cold session) ~draft:(cold session) result
    in
    require applied.blocked "recovery-commit-stop-not-reflected";
    refuses "torn-tail" (fun () ->
        F.create_copy ~source:session.path ~target:(session.path ^ ".ordinary-copy"))
  in

  (* A torn final line: reported read-only, stops writes, removed only explicitly. *)
  let torn = make "torn" in
  let saved =
    match F.append torn ops with F.Written s -> s | _ -> raise (F.Refused "torn-setup")
  in
  let next = L.record_line ~seq:2 [ L.Add_locus "after-torn" ] in
  let oc = open_out_gen [ Open_append; Open_binary ] 0o600 torn.path in
  output_string oc (String.sub next 0 (String.length next - 5));
  close_out oc;
  let report = readonly_report torn in
  require
    (report.torn_bytes = String.length next - 5
    && match report.selected with Ok s -> s.torn && s.records = 1 | Error _ -> false)
    "recovery-torn-tail-not-reported";
  check_frozen torn;
  let fresh = directory ^ "/torn-copy.sexp" in
  F.restore_copy ~source:torn.path ~target:fresh;
  require
    (F.read fresh = F.read torn.path && (cold (F.load fresh)).blocked)
    "recovery-copy-repaired-or-changed-torn-file";
  io_refuses (fun () -> F.restore_copy ~source:torn.path ~target:fresh);
  let removed, after = F.discard_torn_tail torn.path in
  require
    (removed = String.length next - 5
    && F.read_revision torn.path = saved.revision
    && not (cold after).blocked)
    "recovery-discard-changed-complete-records";
  check_candidate after.book;
  refuses "no-torn-tail" (fun () -> ignore (F.discard_torn_tail torn.path));

  (* Faults after the line is sent: uncertain, confirmed on reload, no retry. *)
  let check_uncertain step =
    let session =
      make ("fault-" ^ match step with F.Appended -> "appended" | F.Synced -> "synced")
    in
    match
      F.append
        ~checkpoint:(fun r -> if r = step then raise (Sys_error "synthetic checkpoint failure"))
        session ops
    with
    | F.Uncertain { expected } ->
        let loaded = F.load session.path in
        require (F.confirms ~expected loaded && not loaded.torn) "recovery-sent-line-missing";
        check_candidate loaded.book;
        let evidence = A.Expected_revision expected in
        let memory =
          C.apply_commit_result ~record_publication:false (cold session) ~draft:(cold session)
            (A.Uncertain { message = "一括書換の成否が不確定です"; evidence })
        in
        require memory.blocked "recovery-uncertain-not-stopped";
        let resumed = Shell_dispatch.reload memory in
        require
          ((not resumed.blocked) && resumed.pending = None && not (C.has_record_draft resumed))
          "recovery-confirmed-save-retained-retry";
        require
          (match
             B.put_entry (F.load session.path).book ~replace:false
               { payment with id = "duplicate-payment" }
               ~plan:(Some "planned-food")
           with
          | Error _ -> true
          | Ok _ -> false)
          "recovery-paid-plan-retried"
    | _ -> raise (F.Refused "recovery-fault-reported-success")
  in
  List.iter check_uncertain [ F.Appended; F.Synced ];

  (* Evidence the file does not show is never treated as confirmed. *)
  let external_ = make "external-rewrite" in
  let other =
    match F.append external_ [ L.Add_locus "external" ] with
    | F.Written s -> s
    | _ -> raise (F.Refused "external-setup")
  in
  let memory =
    C.apply_commit_result ~record_publication:false (cold external_) ~draft:(cold external_)
      (A.Uncertain
         {
           message = "synthetic";
           evidence = A.Expected_revision (Interaction_check_fixture.expected_after external_ ops);
         })
  in
  let stopped = Shell_dispatch.reload memory in
  require
    (stopped.blocked && stopped.pending <> None && F.read_revision external_.path = other.revision)
    "recovery-other-writer-counted-as-confirmation";

  (* Child processes die while holding the actual writer lock, not a mock state. *)
  List.iter
    (fun step ->
      let session =
        make ("kill-" ^ match step with F.Appended -> "appended" | F.Synced -> "synced")
      in
      let input, output = Unix.pipe () in
      match Unix.fork () with
      | 0 ->
          Unix.close input;
          ignore
            (F.append
               ~checkpoint:(fun reached ->
                 if reached = step then (
                   ignore (Unix.write_substring output "!" 0 1);
                   while true do
                     Unix.sleep 3600
                   done))
               session ops);
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
              require
                (Unix.read input (Bytes.create 1) 0 1 = 1)
                "recovery-child-exited-before-checkpoint";
              Unix.kill pid Sys.sigkill;
              let _, status = Unix.waitpid [] pid in
              reaped := true;
              require (status = Unix.WSIGNALED Sys.sigkill) "recovery-child-not-killed";
              let loaded = F.load session.path in
              require
                (loaded.records = 1 && not loaded.torn)
                "recovery-killed-writer-left-partial-book";
              check_candidate loaded.book;
              match F.append loaded [ L.Add_locus "after-kill" ] with
              | F.Written _ -> ()
              | _ -> raise (F.Refused "recovery-killed-writer-kept-lock")))
    [ F.Appended; F.Synced ];

  (* A real write failure before any byte lands leaves the original book. *)
  let io_failure = make "real-write-failure" in
  Unix.chmod io_failure.path 0o400;
  let failure = F.append io_failure ops in
  Unix.chmod io_failure.path 0o600;
  require
    ((match failure with F.Uncertain _ -> true | _ -> false) && F.read io_failure.path = wire)
    "recovery-real-write-failure-wrote-or-acknowledged";
  check_original (F.load io_failure.path).book;

  (* Another process holding the writer lock: refused, nothing written. *)
  let locked = make "writer-lock" in
  let input, output = Unix.pipe () in
  (match Unix.fork () with
  | 0 ->
      Unix.close input;
      F.with_writer locked.path (fun () ->
          ignore (Unix.write_substring output "!" 0 1);
          while true do
            Unix.sleep 3600
          done)
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
          (match F.append locked ops with
          | F.Refused_input "file-or-writer-unavailable" -> ()
          | _ -> raise (F.Refused "recovery-publication-bypassed-writer-lock"));
          require (F.read locked.path = wire) "recovery-lock-failure-mutated-files";
          Unix.kill pid Sys.sigkill;
          ignore (Unix.waitpid [] pid);
          reaped := true));
  (match F.append locked ops with
  | F.Written saved -> check_candidate saved.book
  | _ -> raise (F.Refused "recovery-save-after-lock-release-failed"));

  (* A missing book is unavailable, never an empty book. *)
  let missing = make "missing-selected" in
  Unix.unlink missing.path;
  require
    (match (F.inspect_recovery missing.path).selected with Error _ -> true | Ok _ -> false)
    "recovery-missing-selected-became-empty";
  require (not (Sys.file_exists missing.path)) "recovery-automatically-restored-selected";

  let healthy = make "healthy" in
  require ((readonly_report healthy).torn_bytes = 0) "recovery-healthy-not-clear";
  (match F.append healthy ops with
  | F.Written saved ->
      check_candidate saved.book;
      require
        (files (Filename.dirname healthy.path) = [ "book.sexp"; "book.sexp.lock" ])
        "recovery-normal-save-left-artifacts";
      check_candidate (F.load healthy.path).book
  | _ -> raise (F.Refused "recovery-normal-save-refused"));
  require (not (cold (F.load healthy.path)).blocked) "recovery-normal-save-froze-writes";

  Printf.printf "Recovery fixtures (synthetic): %s\n%!" directory;
  print_endline
    "PASS: append-only saves: torn final record reported read-only and removed only explicitly; \
     cold/Ctrl-N/reload/direct-write stops; 2 injected faults + 2 SIGKILL checkpoints; writer \
     lock, write failure and foreign-change refusals; exact quantities/payment links; no automatic \
     retry or repair."
