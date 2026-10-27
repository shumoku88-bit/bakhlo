(* Every book.txt publisher retains the same evidence when acknowledgement is
   lost. Actual writer checkpoints exercise both an unlanded and a landed save. *)
open Interaction_check_fixture
module A = Daily_actions

let run ~width_of ~directory () =
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
  let check name ops sidecars receive =
    List.iter
      (fun checkpoint ->
        let state = fresh (name ^ if checkpoint = F.Replaced then "-landed" else "-unlanded") in
        let state = if name = "observe" then Shell_dispatch.open_observe state else state in
        let before = F.read state.session.path in
        let result =
          F.publish
            ~checkpoint:(fun reached ->
              if reached = checkpoint then raise (Sys_error "synthetic lost acknowledgement"))
            ?sidecars state.session ops
          |> A.publication_result
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
    None
    (fun state result -> fst (Shell_publication.observation_result state result));
  let roles : Bakhlo_sexp.Daily_txt.sidecars =
    { roles = "LOAM-ACCOUNTING-ROLE-MAP\t1\nROLE\twallet\tASSET\n"; attention = "" }
  in
  check "roles" [] (Some roles) (fun state result -> fst (Shell_files.sidecars_result state result));
  let attention =
    get (Att.add_item Att.empty ~id:"synthetic-recovery" ~context:"Review" ~due:Att.No_due_date)
  in
  let sidecars : Bakhlo_sexp.Daily_txt.sidecars =
    { roles = ""; attention = Att.to_string attention }
  in
  check "attention" [] (Some sidecars) (fun state result ->
      fst (Shell_files.sidecars_result state result));
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
