(* Synthetic persistence/restart checks of the whole-file book.txt store; never
   inspect household inputs. Checkpoint faults and SIGKILL are not hardware power-loss
   qualification. *)
module F = Daily_file
module C = Shell_state
module H = Shell_input
module A = Daily_actions
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain

let get = function Ok x -> x | Error why -> raise (F.Refused why)
let require = F.require
let files directory = Sys.readdir directory |> Array.to_list |> List.sort String.compare

let io_refuses f =
  match f () with
  | () -> raise (F.Refused "expected file failure")
  | exception (Unix.Unix_error _ | Sys_error _) -> ()

let quantity book locus measure =
  match B.quantity book ~locus ~measure with Some q -> Z.to_string q.amount | None -> "unknown"

let self_check () =
  let directory = "scratch/recovery-check-" ^ F.new_id () in
  Unix.mkdir directory 0o700;
  let wire = F.read Interaction_check_fixture.example_book in
  let base = (F.load Interaction_check_fixture.example_book).book in
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
      B.Put_entry { replace = false; entry = payment; plan = Some "planned-food" };
      B.Put_entry { replace = false; entry = entry "recovery-eur" "eur"; plan = None };
    ]
  in
  let expected_book = Bakhlo_sexp.Daily_txt.text (get (B.apply base ops)) in
  let make name =
    let parent = directory ^ "/" ^ name in
    Unix.mkdir parent 0o700;
    let path = parent ^ "/book.txt" in
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
    require (Bakhlo_sexp.Daily_txt.text book = expected_book) "recovery-metadata-lost"
  in
  let check_original book =
    require
      ((List.hd (B.plans book)).paid_by = None
      && Bakhlo_sexp.Daily_txt.text book = Bakhlo_sexp.Daily_txt.text base)
      "recovery-original-not-kept"
  in
  let step_name = function
    | F.Temp_written -> "temp-written"
    | F.Previous_kept -> "previous-kept"
    | F.Replaced -> "replaced"
  in
  (* Faults during the replacement: uncertain; a landed save is confirmed on reload
     and never retried, an unlanded one leaves the original book. *)
  let check_uncertain step =
    let session = make ("fault-" ^ step_name step) in
    match
      F.publish
        ~checkpoint:(fun r -> if r = step then raise (Sys_error "synthetic checkpoint failure"))
        session ops
    with
    | F.Uncertain { expected } when step <> F.Replaced ->
        let loaded = F.load session.path in
        require (not (F.confirms ~expected loaded)) "recovery-unlanded-save-confirmed";
        check_original loaded.book
    | F.Uncertain { expected } ->
        let loaded = F.load session.path in
        require (F.confirms ~expected loaded) "recovery-landed-save-missing";
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
  List.iter check_uncertain [ F.Temp_written; F.Previous_kept; F.Replaced ];

  (* Evidence the file does not show is never treated as confirmed. *)
  let external_ = make "external-rewrite" in
  let other =
    match F.publish external_ [ B.Add_locus "external" ] with
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
      let session = make ("kill-" ^ step_name step) in
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
              if step = F.Replaced then check_candidate loaded.book else check_original loaded.book;
              match F.publish loaded [ B.Add_locus "after-kill" ] with
              | F.Written _ -> ()
              | _ -> raise (F.Refused "recovery-killed-writer-kept-lock")))
    [ F.Temp_written; F.Previous_kept; F.Replaced ];

  (* A real write failure before any byte lands leaves the original book: the
     directory refuses the temporary file. *)
  let io_failure = make "real-write-failure" in
  let parent = Filename.dirname io_failure.path in
  Unix.chmod parent 0o500;
  let failure = F.publish io_failure ops in
  Unix.chmod parent 0o700;
  require
    ((match failure with
       | F.Written _ -> false
       | F.Uncertain _ | F.Refused_input _ | F.Conflict -> true)
    && F.read io_failure.path = wire)
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
          (match F.publish locked ops with
          | F.Refused_input "file-or-writer-unavailable" -> ()
          | _ -> raise (F.Refused "recovery-publication-bypassed-writer-lock"));
          require (F.read locked.path = wire) "recovery-lock-failure-mutated-files";
          Unix.kill pid Sys.sigkill;
          ignore (Unix.waitpid [] pid);
          reaped := true));
  (match F.publish locked ops with
  | F.Written saved -> check_candidate saved.book
  | _ -> raise (F.Refused "recovery-save-after-lock-release-failed"));

  (* A missing book is unavailable, never an empty book. *)
  let missing = make "missing-selected" in
  Unix.unlink missing.path;
  require
    (match F.load_result missing.path with Error _ -> true | Ok _ -> false)
    "recovery-missing-selected-became-empty";
  require (not (Sys.file_exists missing.path)) "recovery-automatically-restored-selected";

  let healthy = make "healthy" in
  (match F.publish healthy ops with
  | F.Written saved ->
      check_candidate saved.book;
      require
        (files (Filename.dirname healthy.path) = [ "book.txt"; "book.txt.lock"; "book.txt.prev" ])
        "recovery-normal-save-left-artifacts";
      check_candidate (F.load healthy.path).book
  | _ -> raise (F.Refused "recovery-normal-save-refused"));
  require (not (cold (F.load healthy.path)).blocked) "recovery-normal-save-froze-writes";

  Printf.printf "Recovery fixtures (synthetic): %s\n%!" directory;
  print_endline
    "PASS: whole-file saves: 3 injected faults + 3 SIGKILL checkpoints leave the old or the new \
     book (landed saves confirmed, never retried); writer lock, write failure and foreign-change \
     refusals; one .prev and no temporaries after a normal save; exact quantities/payment links; \
     no automatic retry or repair."
