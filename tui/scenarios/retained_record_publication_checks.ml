(* Publications belong to their requesting editor, including uncertain outcomes.
   All files are synthetic copies isolated from the calling suite's book. *)
open Interaction_check_fixture

let run ~width_of ~directory (home : C.state) =
  let fresh name =
    let path = directory ^ "/retained-record-" ^ name ^ ".txt" in
    F.write_new path (F.read home.session.path);
    C.initial ~config_home:directory (F.load path)
  in
  let rename state label =
    X.apply_request state
      (Screen.Publish
         (Screen.Set_locus_label { locus = "wallet"; label; help = "Synthetic account" }))
  in
  let unchanged_record (before : C.state) (after : C.state) label =
    require
      (C.has_record_draft after && after.record = before.record
      && after.record_visible = before.record_visible)
      label
  in
  let base = fresh "other-success" in
  let held = key ~width_of (prepare_record ~width_of base) `Escape in
  let renamed = rename held "Wallet renamed" in
  unchanged_record held renamed "other-publication-retains-record-exactly";
  require
    (renamed.session.revision <> base.session.revision
    && F.read_revision base.session.path = renamed.session.revision
    && (not renamed.blocked) && renamed.pending = None)
    "other-publication-writes-and-refreshes-session";
  let resumed = key ~width_of renamed (`ASCII 'r') in
  require
    (resumed.record_visible && resumed.record = held.record)
    "record-resumes-after-other-publication";
  let review = key ~width_of resumed `Enter in
  let published = key ~width_of review `Enter in
  require
    ((not (C.has_record_draft published))
    && (not published.record_visible)
    && B.entry_count (F.load base.session.path).book = B.entry_count base.session.book + 1)
    "record-publication-clears-only-its-own-draft";

  (* A competing writer after the resumed Preview must still refuse, with the
     exact reviewed Record intact. Preserving drafts cannot weaken the writer. *)
  let base = fresh "conflict" in
  let held = key ~width_of (prepare_record ~width_of base) `Escape in
  let renamed = rename held "First rename" in
  let review = key ~width_of (key ~width_of renamed (`ASCII 'r')) `Enter in
  let competitor =
    rename (C.initial ~config_home:directory (F.load base.session.path)) "Competing rename"
  in
  let refused = key ~width_of review `Enter in
  unchanged_record review refused "record-conflict-retains-reviewed-draft";
  require
    (refused.blocked
    && F.read_revision base.session.path = competitor.session.revision
    && B.entry_count (F.load base.session.path).book = B.entry_count base.session.book)
    "record-conflict-does-not-publish";

  let base = fresh "pay" in
  let paying = pay_selected (C.open_route base W.Scheduled) in
  require (paying.record_visible && C.has_record_draft paying) "payment-draft-open";
  let held_pay = key ~width_of paying `Escape in
  let renamed = rename held_pay "Pay account renamed" in
  unchanged_record held_pay renamed "other-publication-retains-pay-draft";
  require
    (Record_editors.active renamed.screens.editors = None
    && not (Base.String.is_substring renamed.message ~substring:"Next-plan inspection"))
    "other-publication-does-not-run-pay-continuation";
  let paid = key ~width_of (C.submit (key ~width_of renamed (`ASCII 'r'))) `Enter in
  require
    (paid.record = None && (not paid.record_visible)
    && List.exists (fun (p : B.plan) -> p.paid_by <> None) (B.plans paid.session.book))
    "payment-publication-clears-own-draft";
  require
    (match Record_editors.active paid.screens.editors with
    | Some (Record_editors.Scheduled_continuation _) -> true
    | _ -> false)
    "payment-publication-keeps-own-continuation";

  let base = fresh "other-uncertain" in
  let held = key ~width_of (prepare_record ~width_of base) `Escape in
  let saved = rename held "Uncertain rename" in
  let uncertain =
    C.apply_outcome held ~draft:held
      (Publication.Uncertain
         {
           message = "Synthetic lost acknowledgement";
           evidence = Publication.Expected_revision saved.session.revision;
         })
  in
  unchanged_record held uncertain "other-uncertain-retains-record";
  require (uncertain.blocked && uncertain.pending <> None) "other-uncertain-stops-writes";
  let confirmed = X.reload uncertain in
  unchanged_record held confirmed "other-confirmed-publication-retains-record";
  require
    ((not confirmed.blocked) && confirmed.pending = None
    && confirmed.session.revision = saved.session.revision)
    "other-confirmed-publication-resumes-writes";

  let base = fresh "own-uncertain" in
  let review = key ~width_of (prepare_record ~width_of base) `Enter in
  let saved = key ~width_of review `Enter in
  let uncertain =
    C.apply_outcome ~record_publication:true review ~draft:review
      (Publication.Uncertain
         {
           message = "Synthetic lost acknowledgement";
           evidence = Publication.Expected_revision saved.session.revision;
         })
  in
  unchanged_record review uncertain "own-uncertain-retains-record";
  let hidden = key ~width_of uncertain `Escape in
  require
    ((not hidden.record_visible) && C.has_record_draft hidden)
    "own-uncertain-can-hide-retained-record";
  let confirmed = X.reload hidden in
  require
    (confirmed.record = None && (not confirmed.record_visible) && (not confirmed.blocked)
   && confirmed.pending = None
    && confirmed.session.revision = saved.session.revision)
    "own-confirmed-publication-clears-draft-even-after-hide";
  List.iter
    (fun result ->
      let refused = C.apply_outcome held ~draft:held result in
      unchanged_record held refused "failed-publication-retains-other-record")
    [
      Publication.Storage_failed "Synthetic storage failure";
      Publication.Refused "Synthetic refusal";
    ];
  print_endline
    "PASS: retained Record/Pay drafts survive unrelated publication and recovery; own publication \
     clears, stale Preview refuses."
