(* Publication's reviewed base, current session and file on disk are distinct.
   Actual writer checkpoints also exercise unlanded and landed uncertain saves. *)
open Interaction_check_fixture

(* Publication's opening example: a plan is reviewed against A, then a role
   update writes B but returns an uncertain result. An old session and an old
   review hit different gates; neither gate is permission to rebase the request. *)
let check_reviewed_base ~directory () =
  let path = Filename.concat directory "publication-reviewed-base.txt" in
  F.create_copy ~source:example_book ~target:path;
  let original = F.load path in
  let reviewed_plan = List.hd (B.plans original.book) in
  let result =
    F.publish
      ~checkpoint:(function F.Replaced -> raise (Sys_error "synthetic interruption") | _ -> ())
      original
      [ B.Set_roles [ ("wallet", Asset) ] ]
    |> Publication.of_file_outcome
  in
  let evidence =
    match result with
    | Publication.Uncertain { evidence; _ } -> evidence
    | _ -> failwith "expected uncertain role update"
  in
  let current = F.load path in
  let saved_bytes = F.read path in
  require (current.revision <> original.revision) "publication-review-fixture-changed";
  let cancel_reviewed_plan session =
    Publication.cancel_plan ~session ~base_revision:original.revision ~id:reviewed_plan.id
      ~day:"2026-10-11"
  in
  require
    (match cancel_reviewed_plan original with Publication.Conflict -> true | _ -> false)
    "publication-review-current-base-but-changed-file";
  require (F.read path = saved_bytes) "publication-review-file-conflict-does-not-write";
  require
    (match cancel_reviewed_plan current with
    | Publication.Conflict_base_changed -> true
    | _ -> false)
    "publication-review-stale-base-with-current-session";
  require (F.read path = saved_bytes) "publication-review-base-conflict-does-not-write";
  let mode = Draft.Plan_edit reviewed_plan in
  require
    (match Publication.reload ~session:original ~pending:(Some evidence) ~mode with
    | Publication.Pending_confirmed loaded -> loaded.revision = current.revision
    | _ -> false)
    "publication-review-pending-confirmation-precedes-edit-staleness";
  require (F.read path = saved_bytes) "publication-review-confirmation-does-not-write";
  require
    (match Publication.reload ~session:original ~pending:None ~mode with
    | Publication.Edit_base_changed loaded -> loaded.revision = current.revision
    | _ -> false)
    "publication-review-without-pending-keeps-edit-stale";
  require (F.read path = saved_bytes) "publication-review-stale-edit-reload-does-not-write";
  print_endline
    "PASS: Publication distinguishes an outdated review from a changed file, confirms pending \
     saves before edit staleness and never writes during reload."

let run ~width_of ~directory () =
  check_reviewed_base ~directory ();
  let fresh name =
    let path = Filename.concat directory ("publication-recovery-" ^ name ^ ".txt") in
    F.create_copy ~source:example_book ~target:path;
    C.initial ~config_home:directory (F.load path) |> prepare_record ~width_of |> fun state ->
    key ~width_of state `Escape
  in
  let retained before after =
    require
      (after.C.record = before.C.record && C.has_record_draft after
      && after.record_visible = before.record_visible)
      "book-publication-retains-unrelated-record"
  in
  let check name ops receive =
    List.iter
      (fun checkpoint ->
        let state = fresh (name ^ if checkpoint = F.Replaced then "-landed" else "-unlanded") in
        let state = if name = "observe" then Shell_dispatch.open_observe state else state in
        let before = F.read state.session.path in
        let result =
          F.publish
            ~checkpoint:(fun reached ->
              if reached = checkpoint then raise (Sys_error "synthetic lost acknowledgement"))
            state.session ops
          |> Publication.of_file_outcome
        in
        let stopped = receive state result in
        retained state stopped;
        require
          (stopped.blocked && stopped.pending <> None && not stopped.pending_record_publication)
          "book-publication-keeps-uncertain-evidence";
        let after = F.read state.session.path in
        let reloaded = Shell_dispatch.reload stopped in
        retained state reloaded;
        require (F.read state.session.path = after) "book-publication-reload-never-retries";
        if checkpoint = F.Replaced then (
          require (after <> before) "book-publication-landed-new-bytes";
          require
            ((not reloaded.blocked) && reloaded.pending = None
            && reloaded.session.revision = F.read_revision state.session.path
            && not (Observe_screen.modal reloaded.screens.observe))
            "book-publication-confirmed-clears-only-pending-editor")
        else (
          require (after = before) "book-publication-unlanded-keeps-original";
          require
            (reloaded.blocked && reloaded.pending = stopped.pending)
            "book-publication-unconfirmed-remains-stopped"))
      [ F.Temp_written; F.Replaced ]
  in
  check "observe"
    [ B.Observe [ ("wallet", "jpy", Z.of_int 2345) ] ]
    (fun state result -> fst (Shell_publication.observation_result state result));
  check "roles"
    [ B.Set_roles [ ("wallet", Asset) ] ]
    (fun state result -> fst (Shell_files.section_result state result));
  let attention =
    get (Att.add_item Att.empty ~id:"synthetic-recovery" ~context:"Review" ~due:Att.No_due_date)
  in
  check "attention"
    [ B.Set_attention { items = attention.items; closes = attention.closes } ]
    (fun state result -> fst (Shell_files.section_result state result));
  let state = fresh "stale-observe" in
  let before = F.read state.session.path in
  let stale, outcome =
    Shell_publication.publish_observation state ~rows:[ ("wallet", "jpy", Z.zero) ] ~base:"stale"
  in
  require
    (outcome = Screen.Publish_conflict && stale.blocked && stale.pending = None
    && F.read state.session.path = before)
    "book-publication-stale-observation-refuses-without-evidence";
  retained state stale;
  print_endline
    "PASS: Observe, roles and Attention retain uncertain revision evidence, confirm landed saves \
     without retry, keep unlanded saves stopped and preserve unrelated Record drafts."
