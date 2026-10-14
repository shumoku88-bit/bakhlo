(* Pure synthetic Record contract checks. No ledger files, publication or locale
   settings are written. Preview may allocate the existing random Actual identity. *)
module B = Bakhlo_sexp.Daily_book
module A = Daily_actions
module S = Record_session
module D = Bakhlo_domain
module O = Daily_overlays

let require condition cause = if not condition then failwith cause
let get = function Ok x -> x | Error why -> failwith why

let fixture =
  "(bakhlo-daily 3)\n(scope corrected-entries explicit-plans)\n\
   (measures (measure \"jpy\" 0) (measure \"eur\" 2))\n\
   (labels (provided (label \"wallet\" \"財布\" \"Synthetic cash\") (label \"food\" \"食費\" \"Synthetic food\")))\n\
   (approved-loci (provided \"wallet\" \"food\"))\n(entries)\n\
   (plans (plan \"scheduled-1\" (date \"2026-10-10\") (measure \"jpy\")\n\
     (changes (\"wallet\" -200) (\"food\" 200)) (paid-by (none)) (cancelled-on (none))))\n\
   (support (zero-origin (\"food\" \"jpy\")) (openings)\n\
     (observations (observation (reflected) (quantities (\"wallet\" \"jpy\" 1000))))\n\
     (presence (not-supplied)))\n"

let self_check ~width_of () =
  let book=get (B.of_string fixture) in
  let before=B.to_string book in
  let dimensions=100,30 and base_bytes="synthetic-generation" in
  let handle ?(book=book) ?(blocked=false) ?(dimensions=dimensions) state input =
    S.handle ~book ~base_bytes ~blocked ~dimensions ~width_of state input in
  let update ?book ?blocked ?dimensions state input =
    match handle ?book ?blocked ?dimensions state input with
    | S.Updated next -> next
    | S.Closed _ -> failwith "record-check-unexpected-close"
    | S.Publish _ -> failwith "record-check-unexpected-publication" in
  let key state button=update state (`Key (button,[])) in
  let ctrl state c=update state (`Key (`ASCII c,[`Ctrl])) in
  let text state value =
    Uutf.String.fold_utf_8 (fun state _ -> function
      | `Uchar c when Uchar.to_int c<128 -> key state (`ASCII (Char.chr (Uchar.to_int c)))
      | `Uchar c -> key state (`Uchar c)
      | `Malformed _ -> failwith "malformed-check-text") state value in
  let screen ?(dimensions=dimensions) state = S.screen ~book ~dimensions ~width_of state in
  let contains state needle =
    List.exists (fun (_,line) -> Base.String.is_substring line ~substring:needle) (screen state) in
  let create ()=S.create ~book ~day:"2026-10-11" ~measure:"jpy" () in
  require (not (S.has_draft (create ()))) "fresh-record-is-empty";
  let prepare ?(amount="100") ?(description="q 食事") ?(locus_query="wallet") () =
    let state=text (create ()) description in
    let state=key (key state `Tab) `Tab in
    let state=key (text state locus_query) `Enter in
    let state=key (text state ("-"^amount)) `Tab in
    let state=key (text state "food") `Enter in
    text state ("+"^amount) in
  let draft=prepare () in
  require (S.has_draft draft && contains draft "q 食事") "japanese-user-data-under-english-record";
  let review=key draft `Enter in
  require (contains review "Record / Preview" && contains review "Publish") "enter-opens-preview";
  require (not (contains (ctrl review 's') "Writes are stopped")) "ctrl-s-is-not-publication";
  let edited=key (key review `Tab) `Enter in
  require (contains edited "q 食事" && contains edited "Record / Edit") "preview-edit-retains-draft";
  (match handle review (`Key (`Escape,[])) with
   | S.Closed retained -> require (S.has_draft retained) "cancel-retains-draft"
   | _ -> failwith "escape-cancels-without-publishing");
  let tx=match handle review (`Key (`Enter,[])) with
    | S.Publish (A.Entry_tx tx,base,retained) ->
        require (base=base_bytes && S.has_draft retained) "publication-carries-generation-and-draft"; tx
    | _ -> failwith "selected-publish-enter" in
  require (tx.entry.memo=Some "q 食事") "publication-preserves-description";
  require (List.map A.quanta tx.entry.effects=[Z.of_int (-100);Z.of_int 100]) "signed-conservation";
  require (A.format_message "Locus %s is already admitted." "財布" = "Locus 財布 is already admitted.")
    "catalog-translates-template-not-user-data";
  let matched=prepare ~locus_query:"wall" () |> fun t -> key t `Enter in
  (match handle matched (`Key (`Enter,[])) with
   | S.Publish (A.Entry_tx selected,_,_) ->
       require (A.lstr (D.Effect.locus (List.hd selected.entry.effects))="wallet") "search-accepts-exact-stored-id"
   | _ -> failwith "filtered-locus-acceptance");
  ignore (get (B.put_entry book ~replace:tx.replace tx.entry ~plan:tx.plan));
  (match handle ~blocked:true review (`Key (`Enter,[])) with
   | S.Updated retained -> require (S.has_draft retained) "blocked-publish-retains"
   | _ -> failwith "blocked-publish-refused");
  (match handle ~dimensions:(24,8) review (`Key (`Enter,[])) with
   | S.Updated _ -> () | _ -> failwith "tiny-publish-refused");
  require (screen draft=screen (update ~blocked:true draft (`Key (`ASCII '9',[])))) "blocked-fields-frozen";
  let cursor=create () |> fun t -> text t "ab" |> fun t -> key t (`Arrow `Left)
      |> fun t -> text t "食" in
  require (contains cursor "a食|b") "unicode-caret-insertion";
  let cursor=key cursor `Backspace in
  require (contains cursor "a|b") "unicode-caret-backspace";
  let pasted=create () |> fun t -> update t (`Paste `Start)
      |> fun t -> text t "q 財布" |> fun t -> update t (`Paste `End) in
  require (contains pasted "q 財布") "single-line-paste-is-text";
  let refused=create () |> fun t -> update t (`Paste `Start)
      |> fun t -> text t "not-published" |> fun t -> ctrl t 's'
      |> fun t -> update t (`Paste `End) in
  require (not (S.has_draft refused) && contains refused "Paste refused") "control-paste-refusal";
  let unbalanced=prepare ~amount:"100" () |> fun t -> key t `Backspace |> fun t -> text t "1"
      |> fun t -> key t `Enter in
  require (contains unbalanced "unbalanced" && not (contains unbalanced "Record / Preview")) "exact-unbalanced-refusal";
  let huge=String.make 70 '9' in
  let huge_review=prepare ~amount:huge () |> fun t -> key t `Enter |> fun t -> key t `End in
  (match handle huge_review (`Key (`Enter,[])) with
   | S.Publish (A.Entry_tx tx,_,_) -> require (Z.equal (List.nth (List.map A.quanta tx.entry.effects) 1) (Z.of_string huge)) "huge-exact-quantity"
   | _ -> failwith "huge-review-is-not-partial-number");
  let edit_book=get (B.put_entry book ~replace:false tx.entry ~plan:None) in
  let edit=get (S.of_edit ~book:edit_book tx.entry) in
  let sign_locked=edit |> fun t -> key (key (key t `Tab) `Tab) `Tab
      |> fun t -> key t `Home |> fun t -> text t "+" in
  require (contains sign_locked "keeps the posting sign") "edit-sign-locked-to-retained-effects";
  require (contains (ctrl edit 'n') "keeps the posting structure") "edit-row-structure-locked";
  let edit_review=S.preview ~book:edit_book ~base_bytes ~blocked:false edit in
  (match handle ~book:edit_book edit_review (`Key (`Enter,[])) with
   | S.Publish (A.Entry_tx next,_,_) ->
       require (next.entry.id=tx.entry.id && next.entry.effects=tx.entry.effects && next.replace) "edit-preserves-identity-structure"
   | _ -> failwith "edit-preview-publish");
  let plan=List.hd (B.plans book) in
  let completion=get (S.of_plan ~day:"2026-10-11" ~book plan) in
  let completion=S.preview ~book ~base_bytes ~blocked:false completion in
  (match handle completion (`Key (`Enter,[])) with
   | S.Publish (A.Entry_tx next,_,_) -> require (next.plan=Some plan.id && next.entry.day="2026-10-11") "scheduled-link-and-actual-day"
   | _ -> failwith "scheduled-completion-preview");
  require (Result.is_error (S.of_plan ~book {plan with paid_by=Some "already"})) "completed-plan-refused";
  require (Result.is_error (S.of_plan ~book {plan with cancelled_on=Some "2026-10-10"})) "cancelled-plan-refused";
  require (S.surface_dimensions (80,23)=(72,20)) "record-bounded-floating-surface";
  require (S.surface_dimensions (140,39)=(76,24)) "record-large-surface-bounded";
  require (S.surface_dimensions (48,13)=(48,13)
    && S.surface_dimensions (32,8)=(32,8)) "record-compact-full-surface";
  require (S.border_intent (create ())=`Create && S.border_intent edit=`Change
    && S.border_intent (get (S.of_plan ~book plan))=`Change) "record-border-semantic-intent";
  let cancel_review=key (key review `Tab) `Tab in
  require (S.border_intent cancel_review=`Cancel) "record-cancel-border-is-local-action";
  let long_description=String.concat "" (List.init 24 (fun _->"長い説明")) ^ "終端" in
  let long_input=text (create ()) long_description in
  List.iter (fun dimensions ->
    let rows=screen ~dimensions long_input in
    require (List.exists (fun (_,line)->Base.String.is_substring line ~substring:"終端|") rows)
      "record-active-caret-tail-visible-in-compact-pane") [32,8;48,13;72,20];
  let literal_bar=text (create ()) "a|b" in
  require (List.filter_map (fun (style,_) -> match style with O.Input cell->Some cell | _->None)
    (screen ~dimensions:(72,20) literal_bar)=[17]) "record-literal-bar-is-not-a-second-caret";
  let compact_focus=update draft (`Key (`Tab,[`Shift])) in
  require (List.exists (fun (_,line)->Base.String.is_substring line ~substring:"|")
    (screen ~dimensions:(32,8) compact_focus)) "record-low-viewport-follows-field-focus";
  let short_notice=S.with_notice draft "Input retained." in
  require (List.length (screen draft)=List.length (screen short_notice))
    "record-short-feedback-keeps-geometry";
  let many_rows=ctrl (ctrl (ctrl draft 'n') 'n') 'n' in
  require (List.exists (fun (_,line)->Base.String.is_substring line ~substring:"Posting 5")
    (screen ~dimensions:(32,8) many_rows)) "record-added-row-remains-visible";
  let overflow=prepare ~amount:huge ~description:long_description () |> fun t->key t `Enter in
  (match handle ~dimensions:(72,20) overflow (`Key (`Enter,[])) with
   | S.Updated retained -> require (contains retained "Review to the end") "overflow-explicit-end-gate"
   | S.Publish _|S.Closed _ -> failwith "unreviewed-overflow-published");
  let ended=match handle ~dimensions:(72,20) overflow (`Key (`End,[])) with
    | S.Updated t->t | _->failwith "review-end-navigation" in
  (match handle ~dimensions:(72,20) ended (`Key (`Enter,[])) with
   | S.Publish (A.Entry_tx next,_,_) ->
       require (next.entry.memo=Some long_description) "ended-review-retains-whole-payload";
       let count = List.length (List.concat_map (O.wrap_text ~width_of 68) (O.preview_lines book next)) in
       require (List.exists (fun (style,line) -> style = O.Focused_frame
         && Base.String.is_substring line ~substring:(Printf.sprintf "%d/%d lines" count count))
         (screen ~dimensions:(72,20) ended)) "record-publish-end-actually-displays-final-review-line"
   | _->failwith "full-sized-ended-review-not-publishable");
  let compact_end=match handle ~dimensions:(48,13) ended (`Key (`End,[])) with
    | S.Updated t->t | _->failwith "compact-review-end" in
  (match handle ~dimensions:(48,13) compact_end (`Key (`Enter,[])) with
   | S.Updated retained -> require (contains retained "enlarge") "compact-full-preview-refused"
   | S.Publish _|S.Closed _ -> failwith "compact-end-bypassed-full-preview-gate");
  let keyed={tx.entry with id="keyed-edit";
    effects=List.mapi (fun n posting ->
      D.Effect.create ~key:(Some (get (match D.Identifier.Effect_key.of_string ("key-"^string_of_int n) with
        | Ok key -> Ok key | Error _ -> Error "synthetic-key")))
        ~locus:(D.Effect.locus posting) ~measure:(D.Effect.measure posting)
        ~quantity:(D.Effect.quantity posting)) tx.entry.effects} in
  let keyed_book=get (B.put_entry book ~replace:false keyed ~plan:(Some plan.id)) in
  let keyed_editor=get (S.of_edit ~book:keyed_book keyed) in
  let keyed_review=S.preview ~book:keyed_book ~base_bytes ~blocked:false keyed_editor in
  (match handle ~book:keyed_book keyed_review (`Key (`Enter,[])) with
   | S.Publish (A.Entry_tx next,_,_) ->
       require (next.entry.id=keyed.id && next.entry.effects=keyed.effects) "edit-preserves-posting-keys";
       let edited_book=get (B.put_entry keyed_book ~replace:true next.entry ~plan:next.plan) in
       require ((List.hd (B.plans edited_book)).paid_by=Some keyed.id) "edit-preserves-payment-link"
   | _ -> failwith "keyed-edit-preview");
  List.iter (fun dimensions ->
    List.iter (fun state ->
      let rows=screen ~dimensions state in
      require (List.length rows<=snd dimensions) "record-bounded-height";
      require (List.for_all (fun (_,line) -> width_of line<=fst dimensions) rows) "record-bounded-cell-width")
      [draft;review;S.with_notice review (String.concat "" (List.init 20 (fun _ -> "Long refusal 日本語 ")))])
    [32,8;48,13;48,14;72,20;80,24;140,40;24,8];
  let wide_screen = screen ~dimensions:(72,20) draft in
  require (List.exists (fun (_,line) -> Base.String.is_substring line ~substring:"Movement") wide_screen
    && List.exists (fun (_,line) -> Base.String.is_substring line ~substring:"Postings") wide_screen
    && List.exists (fun (_,line) -> Base.String.is_substring line ~substring:"Locus candidates") wide_screen)
    "record-wide-layout-has-movement-postings-and-candidates-panels";
  let medium_screen = screen ~dimensions:(60,24) draft in
  require (List.exists (fun (_,line) -> Base.String.is_substring line ~substring:"Movement") medium_screen
    && List.exists (fun (_,line) -> Base.String.is_substring line ~substring:"Postings") medium_screen
    && List.exists (fun (_,line) -> Base.String.is_substring line ~substring:"Locus candidates") medium_screen)
    "record-medium-layout-has-stacked-movement-postings-and-candidates-panels";
  let degraded_screen = screen ~dimensions:(32,8) draft in
  require (List.exists (fun (_,line) -> Base.String.is_substring line ~substring:"Fields") degraded_screen)
    "record-degraded-layout-falls-back-to-fields-panel";
  let preview_gate_screen = screen ~dimensions:(72,20) review in
  require (List.exists (fun (_,line) -> Base.String.is_substring line ~substring:"Movement / signed postings") preview_gate_screen
    && List.exists (fun (_,line) -> Base.String.is_substring line ~substring:"Publication gate") preview_gate_screen
    && List.exists (fun (_,line) -> Base.String.is_substring line ~substring:"recheck evidence") preview_gate_screen)
    "record-preview-contains-publication-gate";
  let plan_draft = S.create_plan ~book ~day:"2026-10-15" ~measure:"jpy" () in
  require (not (S.has_draft plan_draft)) "fresh-plan-draft-is-empty";
  require (S.mode plan_draft = A.Plan_new) "is-plan-identified";
  require (contains plan_draft "Scheduled / Create") "plan-create-title";
  require (S.border_intent plan_draft = `Create) "plan-create-border-intent";
  let plan_draft = key (key plan_draft `Tab) `Tab in
  let plan_draft = key (text plan_draft "wallet") `Enter in
  let plan_draft = key (text plan_draft "-500") `Tab in
  let plan_draft = key (text plan_draft "food") `Enter in
  let plan_draft = text plan_draft "+500" in
  require (S.has_draft plan_draft) "plan-has-draft-after-input";
  let plan_review = key plan_draft `Enter in
  require (contains plan_review "Scheduled / Preview") "plan-preview-title";
  (match handle plan_review (`Key (`Enter, [])) with
   | S.Publish (A.Plan_tx { plan = new_p; replace }, base, retained) ->
       require (base = base_bytes && S.has_draft retained) "plan-publish-carries-generation";
       require (not replace) "new-plan-replace-is-false";
       require (new_p.day = "2026-10-15") "new-plan-due-day";
       require (new_p.measure = "jpy") "new-plan-measure";
       require (new_p.changes = [("wallet", Z.of_int (-500)); ("food", Z.of_int 500)]) "new-plan-changes";
       require (new_p.paid_by = None && new_p.cancelled_on = None) "new-plan-unpaid-uncancelled";
       let plan_book = get (B.put_plan book ~replace:false new_p) in
       let plan_editor = get (S.of_edit_plan ~book:plan_book new_p) in
       require (contains plan_editor "Scheduled / Edit") "plan-edit-title";
       require (S.border_intent plan_editor = `Change) "plan-edit-border-intent";
       let plan_edit_review = S.preview ~book:plan_book ~base_bytes ~blocked:false plan_editor in
       (match handle ~book:plan_book plan_edit_review (`Key (`Enter, [])) with
        | S.Publish (A.Plan_tx { plan = edited_p; replace = edit_replace }, _, _) ->
            require edit_replace "edited-plan-replace-is-true";
            require (edited_p.id = new_p.id) "edited-plan-preserves-id";
            require (edited_p.day = new_p.day) "edited-plan-preserves-day"
        | _ -> failwith "plan-edit-publish-failed");
       require (Result.is_error (S.of_edit_plan ~book:plan_book { new_p with paid_by = Some "already" }))
         "paid-plan-edit-refused";
       require (Result.is_error (S.of_edit_plan ~book:plan_book { new_p with cancelled_on = Some "2026-10-16" }))
         "cancelled-plan-edit-refused"
   | _ -> failwith "plan-publish-failed");
  require (B.to_string book=before) "record-checks-leave-book-unchanged"
