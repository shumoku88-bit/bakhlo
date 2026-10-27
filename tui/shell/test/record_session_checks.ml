(* Pure synthetic Record contract checks. No ledger files, publication or locale
   settings are written. Preview may allocate the existing random Actual identity. *)
module B = Bakhlo_household.Daily_book
module A = Daily_actions
module S = Record_session
module D = Bakhlo_domain
module O = Daily_overlays

let require condition cause = if not condition then failwith cause
let get = function Ok x -> x | Error why -> failwith why

let fixture =
  "BOOK\t1\n\
   MEASURE\tjpy\t0\n\
   MEASURE\teur\t2\n\
   LOCUS\twallet\t財布\tSynthetic cash\n\
   LOCUS\tfood\t食費\tSynthetic food\n\
   LOCUS\tbank\tbank\t\n\
   PLAN\tscheduled-1\t2026-10-10\tjpy\n\
   CHANGE\twallet\t-200\n\
   CHANGE\tfood\t200\n\
   ENDPLAN\n\
   ZERO-ORIGIN\tfood\tjpy\n\
   ANCHOR\t-\n\
   ASSERT\twallet\tjpy\t1000\n\
   ENDANCHOR\n\
   END\n"

let self_check ~width_of () =
  let book = Bakhlo_household.Daily_txt.book fixture in
  let before = Bakhlo_household.Daily_txt.text book in
  let dimensions = (100, 30) and base_revision = "synthetic-generation" in
  let handle ?(book = book) ?(blocked = false) ?(dimensions = dimensions) state input =
    S.handle ~new_id:Daily_file.new_id ~book ~base_revision ~blocked ~dimensions ~width_of state
      input
  in
  let update ?book ?blocked ?dimensions state input =
    match handle ?book ?blocked ?dimensions state input with
    | S.Updated next -> next
    | S.Closed _ -> failwith "record-check-unexpected-close"
    | S.Publish _ -> failwith "record-check-unexpected-publication"
    | S.Enable_unresolved _ -> failwith "record-check-unexpected-enable"
  in
  let key state button = update state (`Key (button, [])) in
  let ctrl state c = update state (`Key (`ASCII c, [ `Ctrl ])) in
  let text state value =
    Uutf.String.fold_utf_8
      (fun state _ -> function
        | `Uchar c when Uchar.to_int c < 128 -> key state (`ASCII (Char.chr (Uchar.to_int c)))
        | `Uchar c -> key state (`Uchar c)
        | `Malformed _ -> failwith "malformed-check-text")
      state value
  in
  let screen ?(dimensions = dimensions) state = S.screen ~book ~dimensions ~width_of state in
  let contains state needle =
    List.exists (fun (_, line) -> Base.String.is_substring line ~substring:needle) (screen state)
  in
  (* New Records start in quick capture; Tab continues in the full form. *)
  let full t =
    match handle t (`Key (`Tab, [])) with S.Updated next -> next | _ -> failwith "quick-tab"
  in
  let create () = full (S.create ~book ~day:"2026-10-11" ~measure:"jpy" ()) in
  require (not (S.has_draft (create ()))) "fresh-record-is-empty";
  let date_only = key (update (create ()) (`Key (`Tab, [ `Shift ]))) `Backspace in
  require (S.has_draft date_only) "date-only-record-edit-is-retained";
  let measure_only = key (key (create ()) `Tab) `Backspace in
  require (S.has_draft measure_only) "measure-only-record-edit-is-retained";
  let prepare ?(amount = "100") ?(description = "q 食事") ?(locus_query = "wallet") () =
    let state = text (create ()) description in
    let state = key (key state `Tab) `Tab in
    let state = key (text state locus_query) `Enter in
    let state = key (text state ("-" ^ amount)) `Tab in
    let state = key (text state "food") `Enter in
    text state ("+" ^ amount)
  in
  let draft = prepare () in
  require (S.has_draft draft && contains draft "q 食事") "japanese-user-data-under-english-record";
  let review = key draft `Enter in
  require (contains review "Record / Preview" && contains review "Publish") "enter-opens-preview";
  require (not (contains (ctrl review 's') "Writes are stopped")) "ctrl-s-is-not-publication";
  let edited = key (key review `Tab) `Enter in
  require (contains edited "q 食事" && contains edited "Record / Edit") "preview-edit-retains-draft";
  (match handle review (`Key (`Escape, [])) with
  | S.Closed retained -> require (S.has_draft retained) "cancel-retains-draft"
  | _ -> failwith "escape-cancels-without-publishing");
  let tx =
    match handle review (`Key (`Enter, [])) with
    | S.Publish (A.Entry_tx tx, base, retained) ->
        require
          (base = base_revision && S.has_draft retained)
          "publication-carries-generation-and-draft";
        tx
    | _ -> failwith "selected-publish-enter"
  in
  require (tx.entry.memo = Some "q 食事") "publication-preserves-description";
  require
    (List.map A.quanta tx.entry.effects = [ Z.of_int (-100); Z.of_int 100 ])
    "signed-conservation";
  (* Selecting an action wraps in either direction without changing the reviewed
     payload. Edit and Cancel remain available while publication is blocked. *)
  let previous state = update state (`Key (`Tab, [ `Shift ])) in
  List.iter
    (fun navigate ->
      let wrapped = navigate review in
      match handle wrapped (`Key (`Enter, [])) with
      | S.Publish (A.Entry_tx selected, base, _) ->
          require
            (selected = tx && base = base_revision)
            "review-action-wrap-preserves-reviewed-payload"
      | _ -> failwith "review-action-wrap-returns-to-publish")
    [
      (fun t -> key (key (key t `Tab) `Tab) `Tab);
      (fun t -> previous (previous (previous t)));
      (fun t -> key (key (key t (`Arrow `Right)) (`Arrow `Right)) (`Arrow `Right));
      (fun t -> key (key (key t (`Arrow `Left)) (`Arrow `Left)) (`Arrow `Left));
    ];
  let cancel = previous review in
  require (S.border_intent cancel = `Cancel) "review-backward-selects-cancel";
  (match handle ~blocked:true cancel (`Key (`Enter, [])) with
  | S.Closed retained ->
      require
        (S.has_draft retained && contains retained "q 食事")
        "blocked-review-cancel-retains-draft"
  | _ -> failwith "blocked-review-cancel-is-available");
  let edit = previous cancel in
  (match handle ~blocked:true edit (`Key (`Enter, [])) with
  | S.Updated retained ->
      require
        (contains retained "Record / Edit" && contains retained "q 食事")
        "blocked-review-edit-retains-draft"
  | _ -> failwith "blocked-review-edit-is-available");
  require
    (A.format_message "Locus %s is already admitted." "財布" = "Locus 財布 is already admitted.")
    "catalog-translates-template-not-user-data";
  let matched = prepare ~locus_query:"wall" () |> fun t -> key t `Enter in
  (match handle matched (`Key (`Enter, [])) with
  | S.Publish (A.Entry_tx selected, _, _) ->
      require
        (A.lstr (D.Effect.locus (List.hd selected.entry.effects)) = "wallet")
        "search-accepts-exact-stored-id"
  | _ -> failwith "filtered-locus-acceptance");
  ignore (get (B.put_entry book ~replace:tx.replace tx.entry ~plan:tx.plan));
  (match handle ~blocked:true review (`Key (`Enter, [])) with
  | S.Updated retained -> require (S.has_draft retained) "blocked-publish-retains"
  | _ -> failwith "blocked-publish-refused");
  (match handle ~dimensions:(24, 8) review (`Key (`Enter, [])) with
  | S.Updated _ -> ()
  | _ -> failwith "tiny-publish-refused");
  require
    (screen draft = screen (update ~blocked:true draft (`Key (`ASCII '9', []))))
    "blocked-fields-frozen";
  let cursor =
    create () |> fun t ->
    text t "ab" |> fun t ->
    key t (`Arrow `Left) |> fun t -> text t "食"
  in
  require (contains cursor "a食|b") "unicode-caret-insertion";
  let cursor = key cursor `Backspace in
  require (contains cursor "a|b") "unicode-caret-backspace";
  let pasted =
    create () |> fun t ->
    update t (`Paste `Start) |> fun t ->
    text t "q 財布" |> fun t -> update t (`Paste `End)
  in
  require (contains pasted "q 財布") "single-line-paste-is-text";
  let refused =
    create () |> fun t ->
    update t (`Paste `Start) |> fun t ->
    text t "not-published" |> fun t ->
    ctrl t 's' |> fun t -> update t (`Paste `End)
  in
  require ((not (S.has_draft refused)) && contains refused "Paste refused") "control-paste-refusal";
  let unbalanced =
    prepare ~amount:"100" () |> fun t ->
    key t `Backspace |> fun t ->
    text t "1" |> fun t -> key t `Enter
  in
  require
    (contains unbalanced "unbalanced" && not (contains unbalanced "Record / Preview"))
    "exact-unbalanced-refusal";
  let calculated = prepare ~amount:"(500+300)/2" () |> fun t -> key t `Enter in
  (match handle calculated (`Key (`Enter, [])) with
  | S.Publish (A.Entry_tx tx, _, _) ->
      require
        (List.map A.quanta tx.entry.effects = [ Z.of_int (-400); Z.of_int 400 ])
        "calculator-record-publishes-exact-quanta"
  | _ -> failwith "calculator-record-review-refused");
  let invalid = prepare ~amount:"500/0" () |> fun t -> key t `Enter in
  require
    (contains invalid "divides by zero"
    && contains invalid "500/0"
    && not (contains invalid "Record / Preview"))
    "calculator-refusal-retains-raw-draft";
  let huge = String.make 70 '9' in
  let huge_review =
    prepare ~amount:huge () |> fun t ->
    key t `Enter |> fun t -> key t `End
  in
  (match handle huge_review (`Key (`Enter, [])) with
  | S.Publish (A.Entry_tx tx, _, _) ->
      require
        (Z.equal (List.nth (List.map A.quanta tx.entry.effects) 1) (Z.of_string huge))
        "huge-exact-quantity"
  | _ -> failwith "huge-review-is-not-partial-number");
  let edit_book = get (B.put_entry book ~replace:false tx.entry ~plan:None) in
  let edit = get (S.of_edit ~book:edit_book tx.entry) in
  let sign_locked =
    edit |> fun t ->
    key (key (key t `Tab) `Tab) `Tab |> fun t ->
    key t `Home |> fun t -> text t "+"
  in
  (* LOAM Correction: signs, Loci and rows are editable; the date is kept. *)
  require (not (contains sign_locked "keeps the posting sign")) "edit-sign-editable";
  require (contains (ctrl edit 'n') "Posting 3") "edit-row-can-be-added";
  require (contains edit "Date (kept)") "edit-date-labelled-kept";
  let shifted =
    update edit (`Key (`Tab, [ `Shift ])) |> fun t -> update t (`Key (`Tab, [ `Shift ]))
  in
  require (not (contains (text shifted "2") "keeps the date")) "edit-focus-skips-kept-date";
  let edit_review =
    S.preview ~new_id:Daily_file.new_id ~book:edit_book ~base_revision ~blocked:false edit
  in
  (match handle ~book:edit_book edit_review (`Key (`Enter, [])) with
  | S.Publish (A.Entry_tx next, _, _) ->
      require
        (next.entry.id = tx.entry.id && next.entry.effects = tx.entry.effects && next.replace)
        "edit-preserves-identity-structure"
  | _ -> failwith "edit-preview-publish");
  let plan = List.hd (B.plans book) in
  let completion = get (S.of_plan ~day:"2026-10-11" ~book plan) in
  let completion =
    S.preview ~new_id:Daily_file.new_id ~book ~base_revision ~blocked:false completion
  in
  (match handle completion (`Key (`Enter, [])) with
  | S.Publish (A.Entry_tx next, _, _) ->
      require
        (next.plan = Some plan.id && next.entry.day = "2026-10-11")
        "scheduled-link-and-actual-day"
  | _ -> failwith "scheduled-completion-preview");
  require
    (Result.is_error (S.of_plan ~book { plan with paid_by = Some "already" }))
    "completed-plan-refused";
  require
    (Result.is_error (S.of_plan ~book { plan with cancelled_on = Some "2026-10-10" }))
    "cancelled-plan-refused";
  require (S.surface_dimensions (80, 23) = (72, 20)) "record-bounded-floating-surface";
  require (S.surface_dimensions (140, 39) = (76, 24)) "record-large-surface-bounded";
  require
    (S.surface_dimensions (48, 13) = (48, 13) && S.surface_dimensions (32, 8) = (32, 8))
    "record-compact-full-surface";
  require
    (S.border_intent (create ()) = `Create
    && S.border_intent edit = `Change
    && S.border_intent (get (S.of_plan ~book plan)) = `Change)
    "record-border-semantic-intent";
  let cancel_review = key (key review `Tab) `Tab in
  require (S.border_intent cancel_review = `Cancel) "record-cancel-border-is-local-action";
  let long_description = String.concat "" (List.init 24 (fun _ -> "長い説明")) ^ "終端" in
  let long_input = text (create ()) long_description in
  List.iter
    (fun dimensions ->
      let rows = screen ~dimensions long_input in
      require
        (List.exists (fun (_, line) -> Base.String.is_substring line ~substring:"終端|") rows)
        "record-active-caret-tail-visible-in-compact-pane")
    [ (32, 8); (48, 13); (72, 20) ];
  let literal_bar = text (create ()) "a|b" in
  require
    (List.filter_map
       (fun (style, _) -> O.input_cell ~width:72 style)
       (screen ~dimensions:(72, 20) literal_bar)
    = [ 17 ])
    "record-literal-bar-is-not-a-second-caret";
  let mid_edit = prepare ~description:long_description () in
  let mid_edit =
    List.fold_left
      (fun state _ -> update state (`Key (`Tab, [ `Shift ])))
      mid_edit (List.init 5 Fun.id)
  in
  let mid_edit = update ~dimensions:(48, 14) mid_edit (`Resize ()) in
  let mid_edit = text (key mid_edit (`Arrow `Left)) "食" in
  let mid_edit = update ~dimensions:(120, 36) mid_edit (`Resize ()) in
  List.iter
    (fun dimensions ->
      let rows = screen ~dimensions mid_edit in
      require
        (List.exists (fun (_, line) -> Base.String.is_substring line ~substring:"終食|") rows)
        "record-resized-mid-string-cjk-edit-visible";
      require
        (O.cursor_in_rows ~width_of ~width:(fst dimensions) rows <> None)
        "record-resized-mid-string-caret-metadata")
    [ (32, 9); (48, 14); (80, 24); (120, 36) ];
  let mid_review = key (ctrl mid_edit 's') `End in
  (match handle mid_review (`Key (`Enter, [])) with
  | S.Publish (A.Entry_tx next, _, _) ->
      require
        (next.entry.memo = Some (String.concat "" (List.init 24 (fun _ -> "長い説明")) ^ "終食端"))
        "record-resize-retains-whole-mid-string-edited-draft"
  | _ -> failwith "record-resized-mid-string-preview-publication");
  let wide_posting = prepare ~amount:huge () in
  List.iter
    (fun dimensions ->
      let width = fst dimensions in
      let rows = screen ~dimensions wide_posting in
      let caret_rows =
        List.filter_map
          (fun (style, line) ->
            match O.input_cell ~width style with
            | None -> None
            | Some cell -> Some (style, line, cell))
          rows
      in
      (match (caret_rows, O.cursor_in_rows ~width_of ~width rows) with
      | [ (O.Columns (pane_width, O.Input cell, right), line, column) ], Some (painted, _) ->
          require
            (cell > 0
            && cell < pane_width - 1
            && column = cell && painted = cell
            && width_of line = width
            && O.input_cell ~width:(width - pane_width - 1) right = None)
            "record-wide-posting-caret-stays-inside-left-pane"
      | _ -> failwith "record-wide-posting-retains-recursive-input");
      require
        (List.exists
           (fun (style, _) ->
             match style with O.Columns (_, O.Focused_frame, O.Frame) -> true | _ -> false)
           rows)
        "record-wide-posting-focus-does-not-recolor-candidates";
      require
        (List.exists
           (fun (style, _) ->
             match style with O.Columns (_, O.Chrome, O.Chrome) -> true | _ -> false)
           rows)
        "record-wide-panes-retain-child-chrome")
    [ (72, 20); (80, 24); (120, 36) ];
  let compact_focus = update draft (`Key (`Tab, [ `Shift ])) in
  require
    (List.exists
       (fun (_, line) -> Base.String.is_substring line ~substring:"|")
       (screen ~dimensions:(32, 8) compact_focus))
    "record-low-viewport-follows-field-focus";
  let short_notice = S.with_notice draft "Input retained." in
  require
    (List.length (screen draft) = List.length (screen short_notice))
    "record-short-feedback-keeps-geometry";
  let many_rows = ctrl (ctrl (ctrl draft 'n') 'n') 'n' in
  require
    (List.exists
       (fun (_, line) -> Base.String.is_substring line ~substring:"Posting 5")
       (screen ~dimensions:(32, 8) many_rows))
    "record-added-row-remains-visible";
  let six_rows = ctrl many_rows 'n' in
  require
    (List.exists
       (fun (_, line) -> Base.String.is_substring line ~substring:"Posting 6")
       (screen ~dimensions:(72, 20) six_rows))
    "record-six-rows-reached";
  let seven_rows = ctrl six_rows 'n' in
  require (contains seven_rows "supports up to six posting rows") "record-max-six-rows-cap";
  let overflow = prepare ~amount:huge ~description:long_description () |> fun t -> key t `Enter in
  (match handle ~dimensions:(72, 20) overflow (`Key (`Enter, [])) with
  | S.Updated retained ->
      require (contains retained "Review to the end") "overflow-explicit-end-gate"
  | S.Publish _ | S.Closed _ | S.Enable_unresolved _ -> failwith "unreviewed-overflow-published");
  let ended =
    match handle ~dimensions:(72, 20) overflow (`Key (`End, [])) with
    | S.Updated t -> t
    | _ -> failwith "review-end-navigation"
  in
  (match handle ~dimensions:(72, 20) ended (`Key (`Enter, [])) with
  | S.Publish (A.Entry_tx next, _, _) ->
      require (next.entry.memo = Some long_description) "ended-review-retains-whole-payload";
      let count =
        List.length (List.concat_map (O.wrap_text ~width_of 68) (O.preview_lines book next))
      in
      require
        (List.exists
           (fun (style, line) ->
             style = O.Focused_frame
             && Base.String.is_substring line ~substring:(Printf.sprintf "%d/%d lines" count count))
           (screen ~dimensions:(72, 20) ended))
        "record-publish-end-actually-displays-final-review-line"
  | _ -> failwith "full-sized-ended-review-not-publishable");
  let compact_end =
    match handle ~dimensions:(48, 13) ended (`Key (`End, [])) with
    | S.Updated t -> t
    | _ -> failwith "compact-review-end"
  in
  (match handle ~dimensions:(48, 13) compact_end (`Key (`Enter, [])) with
  | S.Updated retained -> require (contains retained "enlarge") "compact-full-preview-refused"
  | S.Publish _ | S.Closed _ | S.Enable_unresolved _ ->
      failwith "compact-end-bypassed-full-preview-gate");
  let keyed =
    {
      tx.entry with
      id = "keyed-edit";
      effects =
        List.mapi
          (fun n posting ->
            D.Effect.create
              ~key:
                (Some
                   (get
                      (match D.Identifier.Effect_key.of_string ("key-" ^ string_of_int n) with
                      | Ok key -> Ok key
                      | Error _ -> Error "synthetic-key")))
              ~locus:(D.Effect.locus posting) ~measure:(D.Effect.measure posting)
              ~quantity:(D.Effect.quantity posting))
          tx.entry.effects;
    }
  in
  let keyed_book = get (B.put_entry book ~replace:false keyed ~plan:(Some plan.id)) in
  let keyed_editor = get (S.of_edit ~book:keyed_book keyed) in
  let keyed_review =
    S.preview ~new_id:Daily_file.new_id ~book:keyed_book ~base_revision ~blocked:false keyed_editor
  in
  (match handle ~book:keyed_book keyed_review (`Key (`Enter, [])) with
  | S.Publish (A.Entry_tx next, _, _) ->
      require
        (next.entry.id = keyed.id && next.entry.effects = keyed.effects)
        "edit-preserves-posting-keys";
      let edited_book = get (B.put_entry keyed_book ~replace:true next.entry ~plan:next.plan) in
      require
        ((List.hd (B.plans edited_book)).paid_by = Some keyed.id)
        "edit-preserves-payment-link"
  | _ -> failwith "keyed-edit-preview");
  (* Changing a keyed posting's Locus drops only that key; others and the link stay. *)
  let relocated =
    keyed_editor |> fun t ->
    key (key t `Tab) `Tab |> fun t ->
    List.fold_left (fun t _ -> key t `Backspace) t (List.init 20 Fun.id) |> fun t -> text t "bank"
  in
  let relocated_review =
    S.preview ~new_id:Daily_file.new_id ~book:keyed_book ~base_revision ~blocked:false relocated
  in
  (match handle ~book:keyed_book relocated_review (`Key (`Enter, [])) with
  | S.Publish (A.Entry_tx next, _, _) ->
      let keys = List.map D.Effect.key next.entry.effects in
      require
        (next.entry.id = keyed.id
        && List.nth keys 0 = None
        && List.nth keys 1 = D.Effect.key (List.nth keyed.effects 1)
        && A.lstr (D.Effect.locus (List.hd next.entry.effects)) = "bank")
        "edit-locus-change-drops-only-its-key";
      let edited_book = get (B.put_entry keyed_book ~replace:true next.entry ~plan:next.plan) in
      require
        ((List.hd (B.plans edited_book)).paid_by = Some keyed.id)
        "edit-locus-change-keeps-payment-link"
  | _ -> failwith "relocated-edit-preview");
  List.iter
    (fun dimensions ->
      List.iter
        (fun state ->
          let rows = screen ~dimensions state in
          require (List.length rows <= snd dimensions) "record-bounded-height";
          require
            (List.for_all (fun (_, line) -> width_of line <= fst dimensions) rows)
            "record-bounded-cell-width")
        [
          draft;
          review;
          S.with_notice review (String.concat "" (List.init 20 (fun _ -> "Long refusal 日本語 ")));
        ])
    [ (32, 8); (48, 13); (48, 14); (72, 20); (80, 24); (140, 40); (24, 8) ];
  let wide_screen = screen ~dimensions:(72, 20) draft in
  require
    (List.exists (fun (_, line) -> Base.String.is_substring line ~substring:"Movement") wide_screen
    && List.exists
         (fun (_, line) -> Base.String.is_substring line ~substring:"Postings")
         wide_screen
    && List.exists
         (fun (_, line) -> Base.String.is_substring line ~substring:"Locus candidates")
         wide_screen)
    "record-wide-layout-has-movement-postings-and-candidates-panels";
  let medium_screen = screen ~dimensions:(60, 24) draft in
  require
    (List.exists
       (fun (_, line) -> Base.String.is_substring line ~substring:"Movement")
       medium_screen
    && List.exists
         (fun (_, line) -> Base.String.is_substring line ~substring:"Postings")
         medium_screen
    && List.exists
         (fun (_, line) -> Base.String.is_substring line ~substring:"Locus candidates")
         medium_screen)
    "record-medium-layout-has-stacked-movement-postings-and-candidates-panels";
  let degraded_screen = screen ~dimensions:(32, 8) draft in
  require
    (List.exists
       (fun (_, line) -> Base.String.is_substring line ~substring:"Fields")
       degraded_screen)
    "record-degraded-layout-falls-back-to-fields-panel";
  let preview_gate_screen = screen ~dimensions:(72, 20) review in
  require
    (List.exists
       (fun (_, line) -> Base.String.is_substring line ~substring:"Movement / signed postings")
       preview_gate_screen
    && List.exists
         (fun (_, line) -> Base.String.is_substring line ~substring:"Publication gate")
         preview_gate_screen
    && List.exists
         (fun (_, line) -> Base.String.is_substring line ~substring:"recheck evidence")
         preview_gate_screen)
    "record-preview-contains-publication-gate";
  let no_suspense_editor = text (create ()) "wallet" in
  let no_suspense_editor = ctrl no_suspense_editor 'u' in
  (* LOAM: Ctrl-U without suspense asks to admit it, then returns to the draft. *)
  require
    (contains no_suspense_editor "Unresolved recording / Enable"
    && contains no_suspense_editor "Admit ordinary Locus: suspense."
    && contains no_suspense_editor "[Enable unresolved recording]")
    "ctrl-u-without-suspense-asks-to-enable";
  List.iter
    (fun dimensions ->
      let rows = screen ~dimensions no_suspense_editor in
      require
        (List.length rows <= snd dimensions
        && List.for_all (fun (_, line) -> width_of line <= fst dimensions) rows)
        "ctrl-u-enable-view-bounded")
    [ (32, 8); (48, 14); (80, 24); (140, 40) ];
  let returned = key no_suspense_editor (`ASCII 'e') in
  require
    ((not (contains returned "Unresolved recording / Enable")) && S.has_draft returned)
    "ctrl-u-enable-e-returns-to-draft";
  require
    (match handle no_suspense_editor (`Key (`Enter, [])) with
    | S.Enable_unresolved _ -> true
    | _ -> false)
    "ctrl-u-enable-enter-requests-admission";
  require
    (match handle ~blocked:true no_suspense_editor (`Key (`Enter, [])) with
    | S.Updated _ -> true
    | _ -> false)
    "ctrl-u-enable-blocked-writes-no-admission";
  require
    (contains
       (S.unresolved_not_enabled no_suspense_editor "locus-policy-not-supplied")
       "Unresolved recording was not enabled: locus-policy-not-supplied")
    "ctrl-u-enable-failure-returns-with-cause";
  let suspense_fixture =
    "BOOK\t1\n\
     MEASURE\tjpy\t0\n\
     LOCUS\twallet\t財布\tSynthetic cash\n\
     LOCUS\tfood\t食費\tSynthetic food\n\
     LOCUS\tsuspense\t仮払\tSynthetic suspense\n\
     ZERO-ORIGIN\tfood\tjpy\n\
     END\n"
  in
  let s_book = Bakhlo_household.Daily_txt.book suspense_fixture in
  require
    (contains
       (S.after_unresolved_enabled ~book:s_book no_suspense_editor)
       "Unresolved recording enabled.")
    "ctrl-u-enabled-returns-to-draft-with-notice";
  let s_create () = full (S.create ~book:s_book ~day:"2026-10-11" ~measure:"jpy" ()) in
  let s_handle ?(blocked = false) ?(dimensions = dimensions) state input =
    S.handle ~new_id:Daily_file.new_id ~book:s_book ~base_revision ~blocked ~dimensions ~width_of
      state input
  in
  let s_update ?blocked ?dimensions state input =
    match s_handle ?blocked ?dimensions state input with
    | S.Updated next -> next
    | _ -> failwith "suspense-test-unexpected"
  in
  let s_key state button = s_update state (`Key (button, [])) in
  let s_ctrl state c = s_update state (`Key (`ASCII c, [ `Ctrl ])) in
  let s_text state value =
    Uutf.String.fold_utf_8
      (fun state _ -> function
        | `Uchar c when Uchar.to_int c < 128 -> s_key state (`ASCII (Char.chr (Uchar.to_int c)))
        | `Uchar c -> s_key state (`Uchar c)
        | `Malformed _ -> failwith "malformed-text")
      state value
  in
  let s_editor = s_text (s_create ()) "昼食" in
  let s_editor = s_key (s_key s_editor `Tab) `Tab in
  let s_editor = s_key (s_text s_editor "wallet") `Enter in
  let s_editor = s_key (s_text s_editor "-2500") `Enter in
  let incomplete = s_ctrl s_editor 'u' in
  require
    (List.exists
       (fun (_, line) -> Base.String.is_substring line ~substring:"Complete every current Locus")
       (S.screen ~book:s_book ~dimensions ~width_of incomplete))
    "ctrl-u-incomplete-locus-refused";
  let s_editor = s_key (s_text s_editor "food") `Enter in
  let s_editor = s_text s_editor "+2500" in
  let already_balanced = s_ctrl s_editor 'u' in
  require
    (List.exists
       (fun (_, line) -> Base.String.is_substring line ~substring:"already balanced")
       (S.screen ~book:s_book ~dimensions ~width_of already_balanced))
    "ctrl-u-already-balanced-refused";
  let s_editor = s_text (s_create ()) "昼食" in
  let s_editor = s_key (s_key s_editor `Tab) `Tab in
  let s_editor = s_key (s_text s_editor "wallet") `Enter in
  let s_editor = s_key (s_text s_editor "-2500") `Enter in
  let s_editor = s_key (s_text s_editor "food") `Enter in
  let s_editor = s_text s_editor "+2000" in
  let s_filled = s_ctrl s_editor 'u' in
  let s_filled_screen = S.screen ~book:s_book ~dimensions ~width_of s_filled in
  require
    (List.exists
       (fun (_, line) -> Base.String.is_substring line ~substring:"suspense")
       s_filled_screen)
    "ctrl-u-adds-suspense-row";
  require
    (List.exists (fun (_, line) -> Base.String.is_substring line ~substring:"+500") s_filled_screen)
    "ctrl-u-correct-adjustment-amount";
  let plan_draft = S.create_plan ~book ~day:"2026-10-15" ~measure:"jpy" () in
  require (not (S.has_draft plan_draft)) "fresh-plan-draft-is-empty";
  require (S.has_draft (key plan_draft `Backspace)) "date-only-plan-edit-is-retained";
  require (S.has_draft (key (key plan_draft `Tab) `Backspace)) "measure-only-plan-edit-is-retained";
  require (S.mode plan_draft = A.Plan_new) "is-plan-identified";
  require (contains plan_draft "Scheduled / Create") "plan-create-title";
  require (S.border_intent plan_draft = `Create) "plan-create-border-intent";
  let plan_draft = key (key plan_draft `Tab) `Tab in
  let plan_draft = key (text plan_draft "wallet") `Enter in
  let plan_draft = key (text plan_draft "-1000/2") `Tab in
  let plan_draft = key (text plan_draft "food") `Enter in
  let plan_draft = text plan_draft "+250*2" in
  require (S.has_draft plan_draft) "plan-has-draft-after-input";
  let plan_review = key plan_draft `Enter in
  require (contains plan_review "Scheduled / Preview") "plan-preview-title";
  (match handle plan_review (`Key (`Enter, [])) with
  | S.Publish (A.Plan_tx { plan = new_p; replace }, base, retained) ->
      require (base = base_revision && S.has_draft retained) "plan-publish-carries-generation";
      require (not replace) "new-plan-replace-is-false";
      require (new_p.day = "2026-10-15") "new-plan-due-day";
      require (new_p.measure = "jpy") "new-plan-measure";
      require
        (new_p.changes = [ ("wallet", Z.of_int (-500)); ("food", Z.of_int 500) ])
        "new-plan-changes";
      require (new_p.paid_by = None && new_p.cancelled_on = None) "new-plan-unpaid-uncancelled";
      let plan_book = get (B.put_plan book ~replace:false new_p) in
      let plan_editor = get (S.of_edit_plan ~book:plan_book new_p) in
      require (contains plan_editor "Scheduled / Edit") "plan-edit-title";
      require (S.border_intent plan_editor = `Change) "plan-edit-border-intent";
      let plan_edit_review =
        S.preview ~new_id:Daily_file.new_id ~book:plan_book ~base_revision ~blocked:false
          plan_editor
      in
      (match handle ~book:plan_book plan_edit_review (`Key (`Enter, [])) with
      | S.Publish (A.Plan_tx { plan = edited_p; replace = edit_replace }, _, _) ->
          require edit_replace "edited-plan-replace-is-true";
          require (edited_p.id = new_p.id) "edited-plan-preserves-id";
          require (edited_p.day = new_p.day) "edited-plan-preserves-day"
      | _ -> failwith "plan-edit-publish-failed");
      require
        (Result.is_error (S.of_edit_plan ~book:plan_book { new_p with paid_by = Some "already" }))
        "paid-plan-edit-refused";
      require
        (Result.is_error
           (S.of_edit_plan ~book:plan_book { new_p with cancelled_on = Some "2026-10-16" }))
        "cancelled-plan-edit-refused"
  | _ -> failwith "plan-publish-failed");
  (* Prefix matching check for locus_candidates (LOAM specification parity: no substring matches) *)
  let candidates_prefix_su = O.locus_candidates s_book "su" in
  require (candidates_prefix_su = [ "suspense" ]) "prefix-search-matches-prefix";
  let candidates_prefix_o = O.locus_candidates s_book "o" in
  require (candidates_prefix_o = []) "prefix-search-excludes-middle-substring-match";
  (* Date field input protection check *)
  let date_editor = full (S.create ~book ~day:"2026-10-14" ~measure:"jpy" ()) in
  let date_editor = update date_editor (`Key (`Tab, [ `Shift ])) in
  let date_editor = text date_editor "コンビニ" in
  let date_editor = key date_editor (`ASCII 'x') in
  let date_screen = S.screen ~book ~dimensions ~width_of date_editor in
  require
    (List.exists
       (fun (_, line) -> Base.String.is_substring line ~substring:"2026-10-14")
       date_screen)
    "date-field-rejects-non-date-and-japanese-input";

  (* Original amount LOAM-compatible end-to-end tests *)
  let draft_with_orig = prepare ~amount:"3000" () in
  require
    (contains draft_with_orig "Original amount: (none)   Ctrl-O add")
    "empty-original-amount-summary";
  require (contains draft_with_orig "C-o original") "ctrl-o-original-in-nav";
  let orig_editor = ctrl draft_with_orig 'o' in
  require (contains orig_editor "Record / Original amount") "orig-amount-screen-title";
  require (contains orig_editor "╭") "orig-amount-rounded-frame";
  require (contains orig_editor "not another posting") "orig-amount-meaning-posting";
  require (contains orig_editor "No FX inference") "orig-amount-meaning-fx";
  require (contains orig_editor "Publish later in Preview") "orig-amount-meaning-preview";
  require
    (contains orig_editor "[Enter] next/attach" && contains orig_editor "[Esc] cancel")
    "orig-amount-footer-shortcuts";

  (* Validation: empty Measure *)
  let bad_m = key orig_editor `Enter in
  let bad_m_attached = key bad_m `Enter in
  require
    (contains bad_m_attached "Enter a nonempty single-line original Measure token.")
    "orig-amount-empty-measure-refused";
  (* Validation: unregistered Measure *)
  let unreg_m = text orig_editor "usd" in
  let unreg_m_refused = key unreg_m `Enter in
  require
    (contains unreg_m_refused "Measure 'usd' scale is not configured in this book.")
    "orig-amount-unregistered-measure-refused";

  (* Scale 0 (JPY): allows integer, rejects decimals *)
  let jpy_editor = key orig_editor `Backspace in
  let jpy_editor = text jpy_editor "jpy" in
  let jpy_amount = key jpy_editor `Enter in
  let jpy_decimal = key (text jpy_amount "500.5") `Enter in
  require
    (contains jpy_decimal "Enter a positive original amount with at most 0 decimal places.")
    "orig-amount-scale-0-decimal-refused";
  let jpy_valid = key (text (key (key jpy_amount `Home) `End) "5000") `Enter in
  require
    (contains jpy_valid "Original amount: 5000 jpy   Ctrl-O edit")
    "orig-amount-scale-0-attached-summary";
  let jpy_preview = key jpy_valid `Enter in
  require (contains jpy_preview "Original amount: 5000 jpy") "orig-amount-scale-0-preview";

  (* Clear via Ctrl-O -> Ctrl-D *)
  let cleared = ctrl (ctrl jpy_valid 'o') 'd' in
  require (contains cleared "Original amount: (none)   Ctrl-O add") "cleared-jpy-summary";

  (* Open fresh original editor for EUR (scale 2) *)
  let eur_editor = ctrl cleared 'o' in
  let with_m = text eur_editor "eur" in
  let to_amount = key with_m `Enter in
  (* Validation: excess decimals (eur scale 2, input 30.001) *)
  let too_precise = key (text to_amount "30.001") `Enter in
  require
    (contains too_precise "Enter a positive original amount with at most 2 decimal places.")
    "orig-amount-precision-refused";

  (* Validation: zero or negative amount *)
  let zero_amt = key (text to_amount "0.00") `Enter in
  require (contains zero_amt "Original amount must be positive.") "orig-amount-zero-refused";

  (* Valid input: 30.00 eur *)
  let valid_orig = key (text to_amount "30.00") `Enter in
  require
    (contains valid_orig "Original amount: 30.00 eur   Ctrl-O edit")
    "orig-amount-attached-summary";
  require (S.has_draft valid_orig) "orig-amount-attached-has-draft";

  (* Preview shows Original amount *)
  let orig_preview = key valid_orig `Enter in
  require (contains orig_preview "Record / Preview") "orig-amount-preview-opened";
  require (contains orig_preview "Original amount: 30.00 eur") "orig-amount-visible-in-preview";

  (* Publish carries exact original amount *)
  (match handle orig_preview (`Key (`Enter, [])) with
  | S.Publish (A.Entry_tx tx, _, _) ->
      require
        (tx.entry.original_amount = Some ("eur", Z.of_int 3000))
        "orig-amount-published-quanta";
      (* Correction editor retains original amount and forbids modifying it via Ctrl-O *)
      let book_with_orig = get (B.put_entry book ~replace:false tx.entry ~plan:None) in
      let edit_with_orig = get (S.of_edit ~book:book_with_orig tx.entry) in
      require
        (contains edit_with_orig "Original amount: 30.00 eur")
        "edit-retains-original-amount-summary";
      let edit_ctrl_o = ctrl edit_with_orig 'o' in
      require
        (contains edit_ctrl_o "Original amount is not changed by the current Correction editor.")
        "correction-editor-ctrl-o-refused"
  | _ -> failwith "orig-amount-publish-failed");

  (* Scheduled completion (Pay) forbids Ctrl-O *)
  let pay_session = get (S.of_plan ~day:"2026-10-11" ~book plan) in
  let pay_ctrl_o = ctrl pay_session 'o' in
  require
    (contains pay_ctrl_o
       "Original amount is available from new Actual Record, not Scheduled completion.")
    "scheduled-completion-ctrl-o-refused";

  (* Clearing via Ctrl-D *)
  let open_to_clear = ctrl valid_orig 'o' in
  let cleared = ctrl open_to_clear 'd' in
  require (contains cleared "Original amount cleared.") "ctrl-d-notice";
  require (contains cleared "Original amount: (none)   Ctrl-O add") "cleared-summary";

  (* Esc cancels Record *)
  let open_to_esc = ctrl valid_orig 'o' in
  (match handle open_to_esc (`Key (`Escape, [])) with
  | S.Closed _ -> ()
  | _ -> failwith "orig-amount-esc-must-close");

  (* Returning via Ctrl-O without changes *)
  let open_to_return = ctrl valid_orig 'o' in
  let returned = ctrl open_to_return 'o' in
  require
    (contains returned "Original amount: 30.00 eur   Ctrl-O edit")
    "orig-amount-return-keeps-attached";

  (* LOAM quick capture: a bounded framed modal with its footer inside. *)
  let quick = S.create ~book ~day:"2026-10-11" ~measure:"jpy" () in
  require
    (S.in_quick_capture quick && not (S.in_quick_capture (create ())))
    "quick-capture-is-in-front-of-a-new-record";
  let modal ~dimensions state =
    S.screen ~book ~dimensions ~surface:(Quick_capture.surface dimensions) ~width_of state
  in
  let modal_rows = modal ~dimensions:(80, 24) quick in
  require
    (List.length modal_rows = 14
    && Base.String.is_substring (snd (List.nth modal_rows 0)) ~substring:"╭ Record"
    && Base.String.is_substring (snd (List.nth modal_rows 13)) ~substring:"╰")
    "quick-modal-is-a-closed-fourteen-row-frame";
  let footer_rows =
    List.mapi (fun i (_, line) -> (i, line)) modal_rows
    |> List.filter_map (fun (i, line) ->
        if Base.String.is_substring line ~substring:"full form" then Some i else None)
  in
  require
    (footer_rows <> [] && List.for_all (fun i -> i > 0 && i < 13) footer_rows)
    "quick-modal-footer-stays-inside-the-frame";
  let caret_rows =
    List.filter (fun (style, _) -> match style with O.Input _ -> true | _ -> false) modal_rows
  in
  require (List.length caret_rows = 1) "quick-modal-has-one-caret";
  let caret_style, caret_line = List.hd caret_rows in
  let caret_cell = match caret_style with O.Input cell -> cell | _ -> 0 in
  let caret_bar = String.rindex caret_line '|' in
  require
    (width_of (String.sub caret_line 0 caret_bar) = caret_cell
    && caret_cell > 0 && caret_cell < 74
    && List.for_all (fun (_, line) -> width_of line = 75) modal_rows)
    "quick-modal-caret-points-at-the-bar-inside-the-frame";
  (* A long non-ASCII line keeps the caret inside the frame. *)
  let pasted =
    quick |> fun t ->
    update t (`Paste `Start) |> fun t ->
    text t (String.concat "" (List.init 12 (fun _ -> "長い説明"))) |> fun t -> update t (`Paste `End)
  in
  let pasted_rows = modal ~dimensions:(80, 24) pasted in
  let pasted_carets =
    List.filter (fun (style, _) -> match style with O.Input _ -> true | _ -> false) pasted_rows
  in
  require (List.length pasted_carets = 1) "quick-modal-long-line-has-one-caret";
  let pasted_style, pasted_line = List.hd pasted_carets in
  let pasted_cell = match pasted_style with O.Input cell -> cell | _ -> 0 in
  let pasted_bar = String.rindex pasted_line '|' in
  require
    (width_of (String.sub pasted_line 0 pasted_bar) = pasted_cell
    && pasted_cell > 0 && pasted_cell < 74
    && List.for_all (fun (_, line) -> width_of line = 75) pasted_rows)
    "quick-modal-long-unicode-caret-stays-inside-the-frame";
  (* Tab continues in the full form with the same draft; Esc keeps it. *)
  let tabbed = update pasted (`Key (`Tab, [])) in
  require
    ((not (S.in_quick_capture tabbed)) && S.has_draft tabbed)
    "quick-tab-continues-in-the-full-form-with-its-draft";
  (match handle pasted (`Key (`Escape, [])) with
  | S.Closed retained -> require (S.has_draft retained) "quick-escape-retains-the-draft"
  | _ -> failwith "quick-escape-closes-without-publishing");
  (* A small terminal uses the whole area, unframed, with the footer inside. *)
  let compact = modal ~dimensions:(32, 9) quick in
  require
    (List.length compact = 9
    && (not (List.exists (fun (_, line) -> Base.String.is_substring line ~substring:"╭") compact))
    && (match List.nth compact 7 with O.Chrome, text -> text <> "" | _ -> false)
    && List.for_all (fun (_, line) -> width_of line <= 32) compact)
    "quick-compact-terminal-uses-the-whole-area-unframed";
  require (Bakhlo_household.Daily_txt.text book = before) "record-checks-leave-book-unchanged"
