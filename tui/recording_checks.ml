(* Synthetic keyboard regressions for preview/detail and draft preservation.
   Both providers run these with their own cell-width measurement. *)
module C = Daily_interaction
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module F = Daily_file

let render_cases (state : C.state) =
  let entry : B.entry =
    match B.entries state.session.book with
    | entry :: _ -> entry
    | [] ->
        {
          id = "render-only";
          day = "2026-10-07";
          memo = None;
          effects =
            C.get
              (Posting_draft.effects state.session.book
                 {
                   measure = state.form.measure;
                   rows =
                     [
                       { key = None; locus = "wallet"; negative = true; amount = "1" };
                       { key = None; locus = "food"; negative = false; amount = "1" };
                     ];
                 });
          reversal_of = None;
          exchange = None;
        }
  in
  let long =
    {
      entry with
      memo = Some (String.concat "" (List.init 40 (fun _ -> "長いメモ [] ")) ^ "\n\255");
      effects = List.concat (List.init 20 (fun _ -> entry.effects));
    }
  in
  List.concat_map
    (fun entry ->
      [
        { state with overlay = C.Detail { entry; scroll = 0 } };
        { state with overlay = C.Detail { entry; scroll = max_int } };
        {
          state with
          overlay =
            C.Preview
              {
                transaction = { entry; replace = true; plan = None };
                base_bytes = state.session.bytes;
                scroll = 0;
              };
        };
        {
          state with
          overlay =
            C.Preview
              {
                transaction = { entry; replace = true; plan = None };
                base_bytes = state.session.bytes;
                scroll = max_int;
              };
        };
      ])
    [ entry; long ]
  @ List.map
      (fun focus -> { state with focus; overlay = C.No_overlay })
      [ C.Date; C.Currency; C.Source; C.Destination; C.Amount; C.Memo; C.History ]
  @ [ { state with focus = C.History; view = C.Plans; overlay = C.No_overlay } ]
  @ List.map
      (fun scroll ->
        {
          state with
          overlay =
            C.Plan_detail
              {
                plan =
                  {
                    B.id = "render-plan";
                    day = entry.day;
                    measure = state.form.measure;
                    changes =
                      List.map (fun p -> (C.lstr (D.Effect.locus p), C.quanta p)) long.effects;
                    paid_by = None;
                    cancelled_on = None;
                  };
                scroll;
              };
        })
      [ 0; max_int ]

let home_check ~width_of ~directory (base : C.state) =
  let require = F.require in
  let plan : B.plan =
    {
      id = "home-payment";
      day = "2026-11-03";
      measure = "jpy";
      changes = [ ("wallet", Z.of_int (-20)); ("food", Z.of_int 20) ];
      paid_by = None;
      cancelled_on = None;
    }
  in
  let seed = List.hd (B.entries base.session.book) in
  let book =
    List.fold_left
      (fun book n ->
        C.get
          (B.put_entry book ~replace:false { seed with id = "home-" ^ string_of_int n } ~plan:None))
      base.session.book (List.init 10 Fun.id)
  in
  let book = C.get (B.put_plan book ~replace:false plan) in
  let path = directory ^ "/home.sexp" in
  F.write_new path (B.to_string book);
  let base = C.initial ~config_home:directory (F.load path) in
  let bytes = F.read path and files = Sys.readdir directory in
  let step s event =
    match C.handle ~width_of s event with
    | Some s -> s
    | None -> raise (F.Refused "home-unexpected-exit")
  in
  let press s button = step s (`Key (button, [])) in
  let ctrl s c = step s (`Key (`ASCII c, [ `Ctrl ])) in
  let text s value =
    Uutf.String.fold_utf_8
      (fun s _ -> function `Uchar c -> press s (`Uchar c) | `Malformed _ -> s)
      s value
  in
  let upper = press base (`Arrow `Down) in
  require (upper.focus = C.Destination && upper.form = base.form) "upper-arrow-left-region";
  require ((press upper (`Arrow `Up)).focus = C.Source) "upper-arrow-not-field";
  let memo = { base with focus = C.Memo; form = { base.form with amount = "100"; memo = "あい" } } in
  let memo = press memo (`Arrow `Left) in
  require (memo.cursor = Some 3) "unicode-cursor-not-scalar-boundary";
  let inserted = text memo "X" in
  require
    (inserted.form.memo = "あXい" && (press inserted `Backspace).form = memo.form)
    "cursor-insert-or-backspace";
  let pasted = List.fold_left step memo [ `Paste `Start; `Key (`ASCII 'Y', []); `Paste `End ] in
  require (pasted.form.memo = "あYい") "paste-ignored-cursor";
  let digits = { base with focus = C.Amount; form = { base.form with amount = "1234" } } in
  let digits = text (press (press digits (`Arrow `Left)) (`Arrow `Left)) "9" in
  require
    (digits.form.amount = "12934" && (press digits `Backspace).form.amount = "1234")
    "amount-cursor-edited-other-field";
  require
    ((press { memo with focus = C.Date; cursor = None } (`Arrow `Up)).focus = C.Date
    && (press memo (`Arrow `Down)).cursor = memo.cursor)
    "field-boundary-crossed-or-reset";
  let lower = press memo `Tab in
  let lower = press lower `End in
  let lower = ctrl lower 'u' in
  require
    (lower.focus = C.History && lower.selected = 10 && lower.form = memo.form
   && lower.cursor = memo.cursor)
    "tab-or-list-edited-form";
  let empty_adding = ctrl base 'a' in
  require ((ctrl empty_adding 'e').adding = empty_adding.adding) "edit-discarded-locus-name";
  let adding = ctrl lower 'a' in
  require
    (adding.focus = C.Memo && adding.form = lower.form && (ctrl adding 'p').focus = C.Memo
    && (press adding `Escape).form = lower.form)
    "vocabulary-add-input-target-not-upper";
  let upper = step lower (`Key (`Tab, [ `Shift ])) in
  require (upper.focus = C.Memo && upper.cursor = memo.cursor) "region-return-lost-field-or-cursor";
  let shortcut = ctrl memo 'p' in
  require
    (shortcut.focus = C.History && shortcut.view = C.Plans
    && (press shortcut `Tab).focus = C.Memo
    && shortcut.cursor = memo.cursor)
    "view-shortcut-lost-recording-position";
  let plans = press lower (`Arrow `Right) in
  let plans = press plans (`Arrow `Down) in
  require
    (plans.view = C.Plans && plans.selected = 1 && plans.form = memo.form)
    "lower-switch-mutated-draft";
  let entries = press plans (`Arrow `Left) in
  require (entries.view = C.Entries && entries.selected = 10) "entry-selection-not-remembered";
  let plans = press entries (`Arrow `Right) in
  require (plans.selected = 1) "plan-selection-not-remembered";
  let detail = press plans `Enter in
  require
    (match detail.overlay with C.Plan_detail d -> d.plan.id = plan.id | _ -> false)
    "plan-enter-overwrote-form";
  let refused = press detail `Enter in
  require
    (refused.form = memo.form && refused.mode = memo.mode && refused.overlay = detail.overlay)
    "payment-discarded-active-draft";
  let plans = press refused `Escape in
  require ((ctrl entries 'e').form = memo.form) "edit-discarded-active-draft";
  let history_detail = press entries `Enter in
  let returned = press (ctrl history_detail 's') `Escape in
  require
    (returned.form = memo.form && returned.selected = entries.selected)
    "history-detail-not-readonly";
  let held = press (ctrl memo 't') `Escape in
  let browsed = press (press (press held `Tab) (`Arrow `Right)) (`Arrow `Left) in
  let resumed = ctrl (press browsed `Tab) 't' in
  require
    (C.editor_visible resumed && resumed.postings = (ctrl memo 't').postings)
    "browse-lost-held-postings";
  let cleared = ctrl plans 'n' in
  require
    (cleared.view = C.Plans && cleared.selected = 1 && cleared.focus = C.Source)
    "new-draft-reset-browser";
  let payment = press (press (press cleared `Tab) `Enter) `Enter in
  require
    (payment.mode = C.Pay plan.id && payment.focus = C.Amount && payment.record_focus = C.Amount)
    "payment-did-not-return-to-form";
  let back = press (press payment `Tab) `Tab in
  require
    (back.form = payment.form && back.mode = payment.mode && back.focus = C.Amount)
    "payment-browse-lost-context";
  let preview = press back `Enter in
  require (match preview.overlay with C.Preview _ -> true | _ -> false) "payment-skipped-preview";
  List.iter
    (fun state ->
      let lines = C.screen ~width_of ~frontend:"check" (64, 20) state in
      let has hint =
        List.exists (fun (_, line) -> Base.String.is_substring line ~substring:hint) lines
      in
      require
        (List.length lines = 20 && List.for_all (fun (_, line) -> width_of line <= 64) lines)
        "home-layout-outside-terminal";
      require
        (has "←→:表示切替" = (state.C.focus = C.History)
        && has "↑↓:項目" = (state.focus <> C.History && state.postings = None))
        "home-help-not-focused")
    [ memo; lower; plans; held; browsed; payment ];
  let blocked =
    { plans with blocked = true; pending = Some (Daily_actions.Unspecified_evidence "unconfirmed"); message = "household-warning" }
  in
  List.iter
    (fun selected ->
      let stopped = press (press { blocked with selected } `Enter) `Enter in
      require
        (stopped.form = blocked.form && stopped.mode = blocked.mode
       && stopped.pending = blocked.pending && stopped.message = blocked.message)
        "plan-detail-bypassed-write-stop")
    [ 0; 1 ];
  let clean_detail = press (press cleared `Tab) `Enter in
  let pasted =
    List.fold_left step clean_detail
      [ `Paste `Start; `Key (`Enter, []); `Key (`ASCII 'S', [ `Ctrl ]); `Paste `End ]
  in
  require
    (pasted.mode = C.New && pasted.overlay = clean_detail.overlay && pasted.form = clean_detail.form)
    "plan-detail-paste-started-payment";
  require (F.read path = bytes && Sys.readdir directory = files) "home-navigation-published";
  print_endline
    "PASS: two-region Tab/field arrows, view/selection/draft retention, Unicode caret/paste, held \
     postings, readonly plans and guarded payment return."

let self_check ~width_of () =
  let require = F.require in
  let directory = "scratch/recording-check-" ^ F.new_id () in
  Unix.mkdir directory 0o700;
  let path = directory ^ "/book.sexp" in
  let base = C.initial ~config_home:directory (F.load "examples/daily-book.sexp") in
  let posting locus n key =
    D.Effect.create
      ~key:(Option.map (fun key -> C.get_id (D.Identifier.Effect_key.of_string key)) key)
      ~locus:(C.get_id (D.Identifier.Locus.of_string locus))
      ~measure:(C.get_id (D.Identifier.Measure.of_string "jpy"))
      ~quantity:(D.Quantity.of_quanta (Z.of_int n))
  in
  let seed : B.entry =
    {
      id = "seed-detail";
      day = "2026-10-03";
      memo = Some "架空の明細";
      effects =
        [
          posting "wallet" (-120) (Some " debit key ");
          posting "food" 30 (Some "food-one");
          posting "food" 90 None;
        ];
      reversal_of = None;
      exchange = None;
    }
  in
  let book =
    C.get (B.put_entry base.session.book ~replace:false seed ~plan:(Some "planned-food"))
  in
  F.write_new path (B.to_string book);
  let initial () = C.initial ~config_home:directory (F.load path) in
  let step ?(dimensions = (64, 20)) s input =
    match C.handle ~dimensions ~width_of s input with
    | Some s -> s
    | None -> raise (F.Refused "recording-unexpected-exit")
  in
  let press ?dimensions s button = step ?dimensions s (`Key (button, [])) in
  let ctrl ?dimensions s c = step ?dimensions s (`Key (`ASCII c, [ `Ctrl ])) in
  let type_text s text =
    Uutf.String.fold_utf_8
      (fun s _ -> function `Uchar c -> press s (`Uchar c) | `Malformed _ -> s)
      s text
  in
  let base = initial () in
  home_check ~width_of ~directory base;
  let files () = Sys.readdir directory |> Array.to_list |> List.sort String.compare in
  let bytes = F.read path and inventory = files () in
  let unchanged () =
    require (F.read path = bytes && files () = inventory) "review-wrote-household"
  in
  require (base.focus = C.Source) "new-draft-did-not-start-at-source";
  let draft =
    {
      base with
      focus = C.Amount;
      form = { base.form with day = "2026-10-07"; amount = "100"; memo = "入力中のメモ" };
    }
  in
  let selected = press draft `Tab in
  let detail = press selected `Enter in
  require
    (match detail.overlay with C.Detail { entry; _ } -> entry = seed | _ -> false)
    "history-enter-not-detail";
  let detail = List.fold_left (fun s c -> ctrl s c) detail [ 's'; 'e'; 'p'; 'n'; 'a'; 'r' ] in
  let detail = press detail `Enter in
  unchanged ();
  let returned = press detail `Escape in
  require
    (returned.form = draft.form && returned.focus = C.History
    && returned.selected = selected.selected
    && returned.mode = draft.mode)
    "detail-lost-draft-or-selection";
  let preview = press draft `Enter in
  let transaction =
    match preview.overlay with
    | C.Preview p -> p.transaction
    | _ -> raise (F.Refused "preview-not-open")
  in
  require
    (transaction.entry.day = draft.form.day
    && transaction.entry.memo = Some draft.form.memo
    && List.map C.quanta transaction.entry.effects = List.map Z.of_int [ -100; 100 ])
    "preview-does-not-match-draft";
  unchanged ();
  let swallowed = List.fold_left (fun s c -> ctrl s c) preview [ 'n'; 'e'; 'p'; 'a'; 'r'; 't' ] in
  let swallowed = press (press swallowed `Enter) `Tab in
  require
    (swallowed.form = draft.form && swallowed.overlay = preview.overlay)
    "preview-modal-keys-leaked";
  let pasted =
    List.fold_left step preview
      [ `Paste `Start; `Key (`ASCII 'S', [ `Ctrl ]); `Key (`Enter, []); `Paste `End ]
  in
  require
    (pasted.overlay = preview.overlay && pasted.form = preview.form && pasted.paste = None)
    "preview-paste-confirmed";
  unchanged ();
  let tiny = ctrl ~dimensions:(20, 5) preview 's' in
  require (tiny.overlay = preview.overlay) "tiny-preview-authorized-save";
  let cancelled = press preview `Escape in
  require
    (cancelled.form = draft.form && cancelled.focus = draft.focus && cancelled.mode = draft.mode
    && cancelled.postings = draft.postings)
    "preview-cancel-lost-context";
  unchanged ();
  List.iter
    (fun state ->
      let refused = press state `Enter in
      require (refused.overlay = C.No_overlay && refused.form = state.form) "invalid-opened-preview";
      unchanged ())
    [
      { draft with form = { draft.form with amount = "0" } };
      { draft with form = { draft.form with amount = "1.2" } };
      { draft with form = { draft.form with day = "2026-02-30" } };
    ];
  let huge = "123456789012345678901234567890.12" in
  let foreign =
    press { draft with form = { draft.form with measure = "eur"; amount = huge } } `Enter
  in
  require
    (match foreign.overlay with
    | C.Preview p ->
        List.map C.quanta p.transaction.entry.effects
        = [
            Z.neg (Z.of_string "12345678901234567890123456789012");
            Z.of_string "12345678901234567890123456789012";
          ]
    | _ -> false)
    "foreign-preview-rounded-or-converted";
  require ((press foreign `Escape).form.amount = huge) "foreign-preview-lost-text";
  unchanged ();
  let saved = ctrl preview 's' in
  let cold = (F.load path).book in
  require
    (List.length (B.entries cold) = 2
    && List.hd (List.rev (B.entries cold)) = transaction.entry
    && saved.overlay = C.No_overlay && saved.form.amount = "")
    "confirmed-preview-not-exact-entry";
  let saved_bytes = F.read path in
  ignore (ctrl saved 's');
  require (F.read path = saved_bytes) "confirmation-repeated-entry";
  let addition =
    {
      (initial ()) with
      focus = C.Memo;
      form = { draft.form with amount = "456"; memo = "科目追加前のメモ" };
    }
  in
  let adding = type_text (ctrl addition 'a') "新しい科目" in
  let added = press adding `Enter in
  require
    (added.form = addition.form && added.focus = addition.focus && added.mode = addition.mode
   && added.view = addition.view
    && added.selected = addition.selected
    && added.postings = addition.postings
    && added.adding = None
    && C.quantity added "新しい科目" = "不明"
    && List.length (B.entries (F.load path).book) = 2)
    "vocabulary-add-lost-draft-or-invented-balance";
  let cancelled_add = press (type_text (ctrl added 'a') "取消する科目") `Escape in
  require
    (cancelled_add.form = addition.form && cancelled_add.session.bytes = added.session.bytes)
    "vocabulary-cancel-lost-draft";
  let editing = ctrl { (initial ()) with selected = 1 } 'e' in
  require (C.editor_visible editing) "multiple-edit-not-open";
  let edited_draft =
    C.update_editor editing (fun e ->
        {
          e with
          draft =
            {
              e.draft with
              rows =
                List.mapi
                  (fun n (row : Posting_draft.row) ->
                    { row with amount = List.nth [ "150"; "50"; "100" ] n })
                  e.draft.rows;
            };
        })
  in
  let before_edit = F.read path in
  let edit_preview = ctrl edited_draft 's' in
  require
    (F.read path = before_edit && edit_preview.postings = edited_draft.postings)
    "edit-preview-lost-rows";
  let back = press edit_preview `Escape in
  require
    (back.postings = edited_draft.postings && back.mode = edited_draft.mode)
    "edit-preview-return-lost-keys";
  let edited = ctrl (ctrl back 's') 's' in
  let corrected = List.find (fun (e : B.entry) -> e.id = seed.id) (B.entries (F.load path).book) in
  require
    (corrected.id = seed.id && corrected.memo = seed.memo
    && List.map D.Effect.key corrected.effects = List.map D.Effect.key seed.effects
    && List.map C.quanta corrected.effects = List.map Z.of_int [ -150; 50; 100 ]
    && (List.hd (B.plans edited.session.book)).paid_by = Some seed.id)
    "confirmed-edit-lost-identity-keys-or-payment";
  let split : B.plan =
    {
      id = "open-split";
      day = "2026-11-03";
      measure = "jpy";
      changes = [ ("wallet", Z.of_int (-300)); ("food", Z.of_int 200); ("bank", Z.of_int 100) ];
      paid_by = None;
      cancelled_on = None;
    }
  in
  let planned = C.finish edited (C.get (B.put_plan edited.session.book ~replace:false split)) in
  let payment =
    press (press { planned with view = C.Plans; focus = C.History; selected = 1 } `Enter) `Enter
  in
  let plan_bytes = F.read path in
  let pay_preview = ctrl payment 's' in
  require
    (F.read path = plan_bytes && (List.nth (B.plans (F.load path).book) 1).paid_by = None)
    "payment-preview-closed-plan";
  let pay_transaction =
    match pay_preview.overlay with
    | C.Preview p -> p.transaction
    | _ -> raise (F.Refused "payment-preview-missing")
  in
  require (pay_transaction.plan = Some split.id) "preview-lost-plan-intent";
  ignore (ctrl pay_preview 's');
  let paid_plan = List.nth (B.plans (F.load path).book) 1 in
  require
    (paid_plan.paid_by = Some pay_transaction.entry.id
    && paid_plan.day = split.day && paid_plan.changes = split.changes)
    "confirmed-payment-not-atomic";
  let stale_base = initial () in
  let stale =
    press { stale_base with focus = C.Amount; form = { stale_base.form with amount = "2" } } `Enter
  in
  let other =
    ctrl
      (press
         { stale_base with focus = C.Amount; form = { stale_base.form with amount = "1" } }
         `Enter)
      's'
  in
  let other_bytes = F.read path and other_inventory = files () in
  let conflict = ctrl stale 's' in
  require
    (conflict.blocked && conflict.overlay = C.No_overlay && conflict.form = stale.form
    && F.read path = other_bytes
    && files () = other_inventory
    && conflict.session.bytes <> other.session.bytes)
    "preview-conflict-overwrote-or-lost-draft";
  let refreshed = { stale with session = F.load path } in
  let refused = ctrl refreshed 's' in
  require
    (refused.blocked && refused.form = stale.form && F.read path = other_bytes)
    "old-preview-authorized-new-base";
  let uncertain =
    { stale with blocked = true; pending = Some (Daily_actions.Unspecified_evidence "unconfirmed"); message = "household-warning" }
  in
  let blocked = ctrl uncertain 's' in
  require
    (blocked.blocked
    && blocked.pending = uncertain.pending
    && blocked.form = uncertain.form
    && blocked.message = uncertain.message
    && F.read path = other_bytes)
    "preview-retried-uncertain-write";
  List.iter
    (fun state ->
      let lines =
        match state.C.overlay with
        | C.Preview p -> C.preview_lines state.session.book p.transaction
        | C.Detail d -> C.entry_lines state.session.book d.entry
        | C.Plan_detail d -> C.plan_lines state.session.book d.plan
        | _ -> raise (F.Refused "review-case-missing")
      in
      List.iter
        (fun text ->
          let wrapped = C.wrap_text ~width_of 28 text in
          require
            (String.concat "" wrapped = C.visible text
            && List.for_all (fun line -> width_of line <= 28) wrapped)
            "review-wrap-lost-text")
        lines;
      let bottom = press state `End in
      let _, _, _, scroll, last =
        C.review_page ~dimensions:(64, 20) ~width_of lines
          (match bottom.overlay with
          | C.Preview p -> p.scroll
          | C.Detail d -> d.scroll
          | C.Plan_detail d -> d.scroll
          | _ -> 0)
      in
      require (scroll = last) "review-end-not-visible";
      let resized = press ~dimensions:(40, 10) bottom (`Arrow `Up) in
      let top = press resized `Home in
      require
        (match top.overlay with
        | C.Preview p -> p.scroll = 0
        | C.Detail d -> d.scroll = 0
        | C.Plan_detail d -> d.scroll = 0
        | _ -> false)
        "review-resize-or-home-lost-navigation")
    (render_cases (initial ()) |> List.filter (fun state -> state.C.overlay <> C.No_overlay));
  print_endline
    "PASS: recording preview/cancel/explicit confirm, readonly detail, vocabulary draft \
     preservation, keyed edits/payment, stale/conflict/uncertain gates and complete Unicode \
     scrolling."
