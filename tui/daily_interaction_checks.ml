(* Synthetic self-checks for the shared daily interaction state machine.
   Kept out of Daily_interaction so the production module holds only behaviour. *)
open Daily_interaction

(* Synthetic renderer cases; no publication or dependency on a provider. *)
let posting_render_cases s =
  let rows =
    loci s.session.book
    |> List.mapi (fun n locus -> { R.key = None; locus; negative = n = 0; amount = "1" })
  in
  let active =
    with_postings
      {
        s with
        form = { s.form with memo = String.concat "" (List.init 30 (fun _ -> "長いメモ")) ^ "\n\255" };
      }
      { R.measure = s.form.measure; rows }
  in
  [
    active;
    update_editor active (fun e -> { e with row = max 0 (List.length rows - 1) });
    update_editor active (fun e -> { e with field = Posting_day });
    update_editor active (fun e -> { e with field = Posting_memo });
    update_editor active (fun e -> { e with draft = { e.draft with rows = [] } });
    update_editor active (fun e -> { e with visible = false });
    { active with overlay = Commands 0 };
    { active with overlay = Themes { selected = 0; original = s.theme } };
    {
      active with
      overlay = Loci { target = Posting_locus_at 0; query = ""; selected = 0; notice = None };
    };
  ]

let browser_slice_self_check () =
  let require = F.require in
  let empty =
    get (B.of_string
      "(bakhlo-daily 3) (scope corrected-entries explicit-plans)\n\
       (measures (measure jpy 0) (measure eur 2))\n\
       (labels (provided (label wallet 同じ表示 財布) (label food 同じ表示 食費)))\n\
       (approved-loci (provided wallet food)) (entries) (plans)\n\
       (support (zero-origin (wallet jpy) (food jpy) (wallet eur) (food eur))\n\
       (openings) (observations) (presence (not-supplied)))")
  in
  let huge = Z.of_string "12345678901234567890123456789012" in
  let posting measure locus quantity =
    D.Effect.create ~key:None
      ~locus:(get_id (D.Identifier.Locus.of_string locus))
      ~measure:(get_id (D.Identifier.Measure.of_string measure))
      ~quantity:(D.Quantity.of_quanta quantity)
  in
  let entry n : B.entry =
    let measure = if n mod 2 = 0 then "jpy" else "eur" in
    let amount = Z.add huge (Z.of_int n) in
    {
      id = "slice-entry-" ^ string_of_int n;
      day = Printf.sprintf "2026-10-%02d" (20 - n);
      memo = Some ("合成あい \"\\\t " ^ string_of_int n);
      effects = [ posting measure "wallet" (Z.neg amount); posting measure "food" amount ];
      reversal_of = None;
      exchange = None;
    }
  in
  let book =
    List.fold_left
      (fun book n -> get (B.put_entry book ~replace:false (entry n) ~plan:None))
      empty (List.init 20 Fun.id)
  in
  let seed = entry 0 in
  let refund =
    { seed with id = "slice-refund"; reversal_of = Some seed.id;
      effects = [ posting "jpy" "wallet" huge; posting "jpy" "food" (Z.neg huge) ] }
  in
  let book = get (B.put_entry book ~replace:false refund ~plan:None) in
  let book =
    List.fold_left
      (fun book n ->
        let plan : B.plan =
          { id = "slice-plan-" ^ string_of_int n;
            day = Printf.sprintf "2026-10-%02d" (30 - n);
            measure = if n mod 2 = 0 then "jpy" else "eur";
            changes = [ ("wallet", Z.neg huge); ("food", huge) ];
            paid_by = None; cancelled_on = None }
        in
        get (B.put_plan book ~replace:false plan))
      book (List.init 30 Fun.id)
  in
  let book =
    get (B.put_entry book ~replace:false
      { (entry 1) with id = "slice-payment" } ~plan:(Some "slice-plan-3"))
    |> fun book -> get (B.cancel_plan book ~id:"slice-plan-5" ~day:"2026-11-03")
  in
  let check book =
    List.iter
      (fun view ->
        List.iter
          (fun selected ->
            let model = Br.create ~view ~entries_selected:selected ~plans_selected:selected () in
            List.iter
              (fun room ->
                let start = max 0 (selected - room + 1) in
                (* The former format-all/filter path is the independent oracle. *)
                let expected =
                  Br.history_lines ~book model
                  |> List.mapi (fun n text -> (n, text))
                  |> List.filter (fun (n, _) -> n >= start && n < start + room)
                in
                require (Br.visible_slice ~book model ~room = expected)
                  "browser-slice-changed-order-index-or-format")
              [ -1; 0; 1; 2; 7; 21; 22; 30; 35; 80 ])
          [ -3; 0; 1; 9; 20; 21; 29; 30; 45 ])
      [ Br.Entries; Br.Plans ]
  in
  check empty;
  check book;
  check (get (B.of_string (B.to_string book)));
  check (get (B.put_entry book ~replace:true { seed with memo = Some "更新された日本語" } ~plan:None));
  print_endline
    "PASS: slice-before-format matches full-history order/indices, empty/boundary windows, Unicode/duplicate labels, exact Measures, refunds and open/paid/cancelled plans."

let scheduled_browser_self_check () =
  let require = F.require in
  let today = "2026-10-10" in
  let empty_book =
    get (B.of_string
      "(bakhlo-daily 3) (scope corrected-entries explicit-plans)\n\
       (measures (measure jpy 0))\n\
       (labels (provided (label wallet 同じ表示 財布) (label food 同じ表示 食費) (label rent 同じ表示 家賃)))\n\
       (approved-loci (provided wallet food rent)) (entries) (plans)\n\
       (support (zero-origin (wallet jpy) (food jpy) (rent jpy))\n\
       (openings) (observations) (presence (not-supplied)))")
  in
  let make_plan ~id ~day ?paid_by ?cancelled_on changes =
    {
      B.id;
      day;
      measure = "jpy";
      changes = List.map (fun (l, a) -> (l, Z.of_int a)) changes;
      paid_by;
      cancelled_on;
    }
  in
  let p_past_paid = make_plan ~id:"p_past_paid" ~day:"2026-10-01" [ ("wallet", -100); ("food", 100) ] in
  let p_past_cancelled = make_plan ~id:"p_past_cancelled" ~day:"2026-10-03" [ ("wallet", -200); ("food", 200) ] in
  let p_overdue_1 = make_plan ~id:"p_overdue_1" ~day:"2026-10-05" [ ("wallet", -300); ("food", 300) ] in
  let p_overdue_2 = make_plan ~id:"p_overdue_2" ~day:"2026-10-08" [ ("wallet", -400); ("rent", 400) ] in
  let p_today = make_plan ~id:"p_today" ~day:"2026-10-10" [ ("wallet", -500); ("food", 500) ] in
  let p_future = make_plan ~id:"p_future" ~day:"2026-10-15" [ ("wallet", -600); ("food", 600) ] in
  let p_future_paid = make_plan ~id:"p_future_paid" ~day:"2026-10-20" [ ("wallet", -700); ("food", 700) ] in
  let recurring_nov = make_plan ~id:"sub_2026_11" ~day:"2026-11-01" [ ("wallet", -800); ("food", 800) ] in
  let recurring_dec = make_plan ~id:"sub_2026_12" ~day:"2026-12-01" [ ("wallet", -800); ("food", 800) ] in

  (* 1. 空一覧の検証 *)
  require (Br.plans ~today empty_book = []) "scheduled-empty-plans";
  require (Br.initial_plan_index ~today [] = 0) "scheduled-empty-initial-index";
  let empty_model = Br.create ~view:Br.Plans () in
  require (Br.visible_slice ~today ~book:empty_book empty_model ~room:5 = []) "scheduled-empty-visible-slice";

  let plans_raw = [
    recurring_dec; p_future; p_past_cancelled; p_overdue_2;
    p_future_paid; p_past_paid; recurring_nov; p_today; p_overdue_1
  ] in
  let book =
    List.fold_left (fun b p -> get (B.put_plan b ~replace:false p)) empty_book plans_raw
  in
  let posting locus quantity =
    D.Effect.create ~key:None
      ~locus:(get_id (D.Identifier.Locus.of_string locus))
      ~measure:(get_id (D.Identifier.Measure.of_string "jpy"))
      ~quantity:(D.Quantity.of_quanta (Z.of_int quantity))
  in
  let pay_entry id day effects =
    {
      B.id;
      day;
      memo = None;
      effects = List.map (fun (loc, q) -> posting loc q) effects;
      reversal_of = None;
      exchange = None;
    }
  in
  let book = get (B.put_entry book ~replace:false (pay_entry "e1" "2026-10-01" [ ("wallet", -100); ("food", 100) ]) ~plan:(Some "p_past_paid")) in
  let book = get (B.put_entry book ~replace:false (pay_entry "e2" "2026-10-20" [ ("wallet", -700); ("food", 700) ]) ~plan:(Some "p_future_paid")) in
  let book = get (B.cancel_plan book ~id:"p_past_cancelled" ~day:"2026-10-02") in
  let raw_ids = [
    "sub_2026_12"; "p_future"; "p_past_cancelled"; "p_overdue_2";
    "p_future_paid"; "p_past_paid"; "sub_2026_11"; "p_today"; "p_overdue_1"
  ] in
  require (List.map (fun (p : B.plan) -> p.id) (B.plans book) = raw_ids)
    "scheduled-raw-book-plans-unmutated";

  let sorted = Br.plans ~today book in
  let sorted_ids = List.map (fun (p : B.plan) -> p.id) sorted in
  let expected_ids = [
    "p_past_paid";
    "p_past_cancelled";
    "p_overdue_1";
    "p_overdue_2";
    "p_today";
    "p_future";
    "p_future_paid";
    "sub_2026_11";
    "sub_2026_12";
  ] in
  require (sorted_ids = expected_ids) "scheduled-sort-chronological-order";

  (* 3. 初期選択の優先順位 *)
  let init_idx = Br.initial_plan_index ~today sorted in
  require (init_idx = 2) "scheduled-initial-select-overdue-oldest";
  require ((List.nth sorted init_idx).id = "p_overdue_1") "scheduled-initial-select-target";

  let find_p id = List.find (fun (p : B.plan) -> p.id = id) (B.plans book) in
  let plans_no_overdue = [ find_p "p_past_paid"; find_p "p_past_cancelled"; find_p "p_today"; find_p "p_future" ] in
  let sorted_no_overdue = List.sort (Br.compare_plans ~today) plans_no_overdue in
  let init_no_overdue = Br.initial_plan_index ~today sorted_no_overdue in
  require ((List.nth sorted_no_overdue init_no_overdue).id = "p_today") "scheduled-initial-select-upcoming";

  let plans_future_closed_only = [ find_p "p_past_paid"; find_p "p_future_paid" ] in
  let sorted_fc = List.sort (Br.compare_plans ~today) plans_future_closed_only in
  let init_fc = Br.initial_plan_index ~today sorted_fc in
  require ((List.nth sorted_fc init_fc).id = "p_future_paid") "scheduled-initial-select-future-closed";

  let plans_all_closed = [ find_p "p_past_paid"; find_p "p_past_cancelled" ] in
  let sorted_ac = List.sort (Br.compare_plans ~today) plans_all_closed in
  let init_ac = Br.initial_plan_index ~today sorted_ac in
  require ((List.nth sorted_ac init_ac).id = "p_past_cancelled") "scheduled-initial-select-all-closed-latest";

  (* 4. スクロール動作と上下移動 *)
  let model = Br.apply_action ~today ~book Br.initial (Br.Set_view Br.Plans) in
  require (model.plans_selected = 2) "scheduled-opened-selected-overdue";
  require (model.plans_scroll_top = 2) "scheduled-opened-scroll-top";

  let slice = Br.visible_slice ~today ~book model ~room:4 in
  require (List.length slice = 4) "scheduled-visible-slice-length";
  let first_index, first_text = List.hd slice in
  require (first_index = 2) "scheduled-slice-first-is-selected-index";
  require (Base.String.is_substring first_text ~substring:"p_overdue_1") "scheduled-slice-first-is-overdue";
  require (Base.String.is_substring first_text ~substring:"[期限超過]") "scheduled-status-overdue";

  let model_up1 = Br.apply_action ~today ~book model (Br.Select (-1)) in
  require (model_up1.plans_selected = 1) "scheduled-up1-selected-past-cancelled";
  let slice_up1 = Br.visible_slice ~today ~book model_up1 ~room:4 in
  require (fst (List.hd slice_up1) = 1) "scheduled-up1-scroll-shows-past";
  require (Base.String.is_substring (snd (List.hd slice_up1)) ~substring:"[取消 2026-10-02]") "scheduled-status-cancelled";

  let model_up2 = Br.apply_action ~today ~book model_up1 (Br.Select (-1)) in
  require (model_up2.plans_selected = 0) "scheduled-up2-selected-past-paid";
  let slice_up2 = Br.visible_slice ~today ~book model_up2 ~room:4 in
  require (fst (List.hd slice_up2) = 0) "scheduled-up2-scroll-shows-oldest";
  require (Base.String.is_substring (snd (List.hd slice_up2)) ~substring:"[支払済]") "scheduled-status-paid";

  let model_up3 = Br.apply_action ~today ~book model_up2 (Br.Select (-1)) in
  require (model_up3.plans_selected = 0) "scheduled-clamp-top";

  let model_down = Br.apply_action ~today ~book model (Br.Select 1) in
  require (model_down.plans_selected = 3) "scheduled-down-selected-next-overdue";
  let model_down_today = Br.apply_action ~today ~book model_down (Br.Select 1) in
  require (model_down_today.plans_selected = 4) "scheduled-down-selected-today";
  let text_today = List.nth (Br.history_lines ~today ~book model_down_today) 4 in
  require (Base.String.is_substring text_today ~substring:"[本日]") "scheduled-status-today";

  (* 5. 選択復元（ビュー切り替えとデータ更新）*)
  let model_at_overdue2 = model_down in
  require (model_at_overdue2.selected_plan_id = Some "p_overdue_2") "scheduled-selected-plan-id-saved";
  let model_entries = Br.apply_action ~today ~book model_at_overdue2 Br.Switch_view in
  require (model_entries.view = Br.Entries) "scheduled-switch-to-entries";
  let model_back_plans = Br.apply_action ~today ~book model_entries Br.Switch_view in
  require (model_back_plans.view = Br.Plans) "scheduled-switch-back-to-plans";
  require (model_back_plans.plans_selected = 3) "scheduled-restore-selection-index";
  require (model_back_plans.selected_plan_id = Some "p_overdue_2") "scheduled-restore-selection-id";

  let fresh_plan = make_plan ~id:"p_fresh_early" ~day:"2026-10-04" [ ("wallet", -50); ("food", 50) ] in
  let book_updated = get (B.put_plan book ~replace:false fresh_plan) in
  let synced = Br.sync_selection ~today ~book:book_updated model_back_plans in
  require (synced.selected_plan_id = Some "p_overdue_2") "scheduled-sync-preserves-selected-id";
  require (synced.plans_selected = 4) "scheduled-sync-updated-index-by-id";
  require ((List.nth (Br.plans ~today book_updated) 4).id = "p_overdue_2") "scheduled-sync-matches-plan";

  (* 6. 繰り返し予定の独立性 *)
  let nov_plan = List.find (fun (p : B.plan) -> p.id = "sub_2026_11") sorted in
  let dec_plan = List.find (fun (p : B.plan) -> p.id = "sub_2026_12") sorted in
  require (nov_plan.day = "2026-11-01" && dec_plan.day = "2026-12-01") "scheduled-recurring-distinct-days";
  require (nov_plan.id <> dec_plan.id) "scheduled-recurring-distinct-ids";

  print_endline
    "PASS: scheduled chronological sort, smart initial selection, viewport scrolling, \
     all-closed/empty cases, overdue/cancelled/recurring distinction, and ID-based selection recovery."


let home_three_tier_self_check ~directory ~base =
  let require = F.require in
  let step s input =
    match handle s input with Some s -> s | None -> raise (F.Refused "three-tier-unexpected-exit")
  in
  let press s button = step s (`Key (button, [])) in
  let ctrl s c = step s (`Key (`ASCII c, [ `Ctrl ])) in
  let text s value =
    Uutf.String.fold_utf_8
      (fun s _ -> function `Uchar c -> press s (`Uchar c) | `Malformed _ -> s)
      s value
  in
  let path = directory ^ "/three-tier-" ^ F.new_id () ^ ".sexp" in
  F.create_copy ~source:"examples/daily-book.sexp" ~target:path;
  let s_home = initial ~config_home:directory (F.load path) in
  let s_home = { s_home with focus = History } in

  (* 1. Summary の常時表示（閲覧時） *)
  let lines_browse = screen ~frontend:"check" (80, 24) s_home in
  let rendered_browse = List.map snd lines_browse in
  require
    (List.exists (fun t -> Base.String.is_substring t ~substring:"【口座残高】" || Base.String.is_substring t ~substring:"【残高】") rendered_browse)
    "three-tier-summary-balance-present-in-browse";
  require
    (List.exists (fun t -> Base.String.is_substring t ~substring:"【デイリーペース】" || Base.String.is_substring t ~substring:"【ペース】") rendered_browse)
    "three-tier-summary-pace-present-in-browse";

  (* 2. 'r' キーで Floating Create Editor が起動すること *)
  let s_editing = press s_home (`ASCII 'r') in
  require (s_editing.focus <> History) "three-tier-r-key-opens-editor";
  let overlay_editing = overlay_screen ~dimensions:(80, 24) ~width_of:String.length s_editing in
  require (Option.is_some overlay_editing) "three-tier-floating-editor-active";
  let editor_lines = match overlay_editing with Some rows -> List.map snd rows | None -> [] in
  require
    (List.exists (fun t -> Base.String.is_substring t ~substring:"新規記帳") editor_lines)
    "three-tier-floating-editor-title";

  (* 3. 記帳入力中も背景 (screen) に Summary が残っていること *)
  let lines_bg = screen ~frontend:"check" (80, 24) s_editing in
  let rendered_bg = List.map snd lines_bg in
  require
    (List.exists (fun t -> Base.String.is_substring t ~substring:"【口座残高】" || Base.String.is_substring t ~substring:"【残高】") rendered_bg)
    "three-tier-summary-present-during-editing";

  (* 4. コマンドパレット (New_transaction) からも Floating Editor が起動すること *)
  let s_cmd = press s_home (`ASCII ' ') in
  require (match s_cmd.overlay with Commands _ -> true | _ -> false) "three-tier-command-palette-opened";
  let s_cmd_selected =
    let rec to_new_tx s =
      match s.overlay with
      | Commands i when i = 4 -> s
      | Commands _ -> to_new_tx (press s (`Arrow `Down))
      | _ -> s
    in
    to_new_tx s_cmd
  in
  let s_from_cmd = press s_cmd_selected `Enter in
  require (s_from_cmd.focus <> History && Option.is_some (overlay_screen ~dimensions:(80, 24) ~width_of:String.length s_from_cmd))
    "three-tier-new-transaction-from-command-palette";

  (* 5. Esc によるキャンセルで正データが変化せず、Workspace (History) へ戻ること *)
  let orig_bytes = F.read path in
  let s_dirty = text { s_editing with focus = Memo } "未保存のメモ" in
  let s_escaped = press s_dirty `Escape in
  require (s_escaped.focus = History) "three-tier-escape-returns-to-workspace";
  require (overlay_screen ~dimensions:(80, 24) ~width_of:String.length s_escaped = None)
    "three-tier-escape-closes-floating-editor";
  require (F.read path = orig_bytes) "three-tier-escape-leaves-disk-unmutated";

  (* 6. Floating Editor からの新規記帳の保存成功で自動的に閉じ、Workspace に戻ること *)
  let s_new = press s_home (`ASCII 'r') in
  let s_new = { s_new with form = { day = "2026-10-09"; measure = "jpy"; from_locus = "wallet"; to_locus = "food"; amount = "500"; memo = "昼食代" } } in
  let s_preview = ctrl s_new 's' in
  require (match s_preview.overlay with Preview _ -> true | _ -> false) "three-tier-save-preview-opened";
  let s_saved = confirm s_preview in
  require (s_saved.overlay = No_overlay) "three-tier-saved-no-overlay";
  require (s_saved.focus = History) "three-tier-save-auto-closes-to-workspace";
  let loaded_book = (F.load path).book in
  let has_new_entry =
    List.exists
      (fun (e : B.entry) -> e.memo = Some "昼食代")
      (B.entries loaded_book)
  in
  require has_new_entry "three-tier-new-entry-persisted-to-book";

  (* 7. 保存検証エラーおよびコミットエラーでドラフトが失われずエディタが開いたままであること *)
  let s_bad = press s_saved (`ASCII 'r') in
  let s_bad = { s_bad with form = { s_bad.form with amount = "不正な金額" } } in
  let s_bad_try = ctrl s_bad 's' in
  require (s_bad_try.overlay = No_overlay) "three-tier-bad-amount-no-preview";
  require (s_bad_try.message <> "") "three-tier-bad-amount-message-shown";
  require (s_bad_try.form.amount = "不正な金額") "three-tier-bad-draft-retained";
  require (s_bad_try.focus <> History) "three-tier-error-keeps-editor-open";
  let s_conflict = apply_commit_result s_bad ~draft:s_bad A.Conflict in
  require s_conflict.blocked "three-tier-conflict-blocked";
  require (s_conflict.form.amount = "不正な金額") "three-tier-conflict-retains-draft";
  require (s_conflict.focus <> History) "three-tier-conflict-keeps-editor-open";

  (* 8. 既存記帳の訂正 (Ctrl-E) が引き続き動作すること *)
  let s_edit = ctrl s_saved 'e' in
  require (match s_edit.mode with Edit _ -> true | _ -> false) "three-tier-ctrl-e-enters-edit-mode";
  require (s_edit.focus <> History) "three-tier-edit-mode-opens-editor";
  let s_edit_cancel = press s_edit `Escape in
  require (s_edit_cancel.focus = History) "three-tier-edit-cancel-returns-to-workspace";
  require (overlay_screen ~dimensions:(80, 24) ~width_of:String.length s_edit_cancel = None)
    "three-tier-edit-cancel-closes-editor";
  let s_cleared = ctrl s_edit_cancel 'n' in
  require (s_cleared.mode = New) "three-tier-ctrl-n-resets-to-new";

  (* 9. 狭小画面 (64x20) での安定描画とセル幅均一性 *)
  let lines_small = screen ~frontend:"check" (64, 20) s_home in
  require (List.length lines_small = 20) "three-tier-small-screen-height-20";
  require (List.for_all (fun (_, l) -> String.length l <= 64) lines_small) "three-tier-small-screen-width-bounded";
  let overlay_small = overlay_screen ~dimensions:(64, 20) ~width_of:String.length s_new in
  (match overlay_small with
  | Some rows ->
      let w = String.length (snd (List.hd rows)) in
      require (List.for_all (fun (_, l) -> String.length l = w) rows) "three-tier-overlay-small-uniform-width"
  | None -> ());

  print_endline "PASS: three-tier Summary + Workspace + Floating Create Editor lifecycle, cancellation safety, auto-close, and draft retention."

let floating_stability_self_check ~directory ~base =
  let require = F.require in
  let step s input =
    match handle s input with Some s -> s | None -> raise (F.Refused "stability-unexpected-exit")
  in
  let press s button = step s (`Key (button, [])) in
  let ctrl s c = step s (`Key (`ASCII c, [ `Ctrl ])) in
  let path = directory ^ "/stability-" ^ F.new_id () ^ ".sexp" in
  F.create_copy ~source:"examples/daily-book.sexp" ~target:path;
  let s_home = initial ~config_home:directory (F.load path) in
  let s_home = { s_home with focus = History } in
  let s_edit = press s_home (`ASCII 'r') in
  require (s_edit.focus <> History) "stability-r-opens-editor";

  (* 1. フォーム項目間の移動でモーダル外枠の高さ・幅が変化しない *)
  let fields = [ Date; Currency; Source; Destination; Amount; Memo ] in
  let get_overlay_dims s dim =
    match overlay_screen ~dimensions:dim ~width_of:String.length s with
    | None -> raise (F.Refused "stability-overlay-none")
    | Some rows ->
        let h = List.length rows in
        let w = if h > 0 then String.length (snd (List.hd rows)) else 0 in
        require (List.for_all (fun (_, r) -> String.length r = w) rows) "stability-uniform-width";
        (w, h)
  in
  let standard_dim = (80, 24) in
  let base_w, base_h = get_overlay_dims { s_edit with focus = Date } standard_dim in
  List.iter
    (fun f ->
      let s_f = { s_edit with focus = f } in
      let w, h = get_overlay_dims s_f standard_dim in
      require (w = base_w && h = base_h) "stability-field-move-geometry-fixed")
    fields;

  (* 2. 候補一覧（Loci picker）の開閉でモーダル外枠の高さ・幅が変化しない *)
  let s_src = { s_edit with focus = Source } in
  let s_picker = press s_src `Enter in
  require (match s_picker.overlay with Loci _ -> true | _ -> false) "stability-locus-picker-opened";
  let picker_w, picker_h = get_overlay_dims s_picker standard_dim in
  require (picker_w = base_w && picker_h = base_h) "stability-picker-geometry-identical-to-editor";
  let s_closed = press s_picker `Escape in
  require (s_closed.overlay = No_overlay) "stability-picker-closed-by-escape";
  let closed_w, closed_h = get_overlay_dims s_closed standard_dim in
  require (closed_w = base_w && closed_h = base_h) "stability-picker-close-geometry-retained";

  (* 3. キーボード操作: 上下、Tab、Shift+Tab、Enter、Esc *)
  (* ↑↓: 通常時はフォーム項目移動 *)
  let s_d = { s_edit with focus = Date } in
  let s_c = press s_d (`Arrow `Down) in
  require (s_c.focus = Currency) "stability-arrow-down-next-field";
  let s_back_d = press s_c (`Arrow `Up) in
  require (s_back_d.focus = Date) "stability-arrow-up-prev-field";

  (* ↑↓: 候補一覧（Loci picker）では候補移動 *)
  let picker_start = match s_picker.overlay with Loci p -> p.selected | _ -> -1 in
  let s_picker_down = press s_picker (`Arrow `Down) in
  let picker_next = match s_picker_down.overlay with Loci p -> p.selected | _ -> -1 in
  require (picker_next = picker_start + 1) "stability-picker-arrow-down-moves-candidate";
  let s_picker_up = press s_picker_down (`Arrow `Up) in
  let picker_back = match s_picker_up.overlay with Loci p -> p.selected | _ -> -1 in
  require (picker_back = picker_start) "stability-picker-arrow-up-moves-candidate";

  (* Tab / Shift+Tab: エディタとワークスペースの領域切替（下書き保持） *)
  let s_tab_ws = press s_edit `Tab in
  require (s_tab_ws.focus = History) "stability-tab-switches-to-workspace";
  require (s_tab_ws.form = s_edit.form) "stability-tab-retains-draft";
  let s_tab_back = step s_tab_ws (`Key (`Tab, [ `Shift ])) in
  require (s_tab_back.focus = s_edit.focus) "stability-shift-tab-returns-to-editor";

  (* ←→: テキスト項目ではカーソル移動 *)
  let s_memo = { s_edit with focus = Memo; form = { s_edit.form with memo = "テスト" }; cursor = None } in
  let s_memo_left = press s_memo (`Arrow `Left) in
  require (s_memo_left.cursor = Some 6) "stability-arrow-left-moves-cursor";
  let s_memo_right = press s_memo_left (`Arrow `Right) in
  require (s_memo_right.cursor = Some 9) "stability-arrow-right-moves-cursor";

  (* Enter: 候補選択 (Pick_locus) *)
  let s_picker_choice = press s_picker_down `Enter in
  require (s_picker_choice.overlay = No_overlay) "stability-picker-enter-selects-and-closes";
  require (s_picker_choice.form.from_locus <> "") "stability-picker-entered-locus";

  (* Esc: 候補一覧を閉じる（閉じていればエディタを閉じる） *)
  let s_esc_picker = press s_picker `Escape in
  require (s_esc_picker.overlay = No_overlay && s_esc_picker.focus <> History)
    "stability-escape-closes-candidate-keeps-editor";
  let s_esc_editor = press s_esc_picker `Escape in
  require (s_esc_editor.focus = History) "stability-escape-closes-editor-to-workspace";

  (* Ctrl-S: 確認・保存プレビューの起動 *)
  let s_valid = { s_edit with form = { day = "2026-10-09"; measure = "jpy"; from_locus = "wallet"; to_locus = "food"; amount = "300"; memo = "おやつ" } } in
  let s_preview = ctrl s_valid 's' in
  require (match s_preview.overlay with Preview _ -> true | _ -> false) "stability-ctrl-s-opens-preview";

  (* 4. フォーカス表示の明確な区別（Panel_active, Panel_heading, Panel） *)
  let ov_rows = match overlay_screen ~dimensions:standard_dim ~width_of:String.length s_src with
    | Some rows -> rows | None -> []
  in
  let active_styles = List.filter (fun (st, _) -> st = Panel_active) ov_rows in
  let heading_styles = List.filter (fun (st, _) -> st = Panel_heading) ov_rows in
  require (List.length active_styles >= 1) "stability-has-panel-active-field";
  require (List.length heading_styles >= 1) "stability-has-panel-heading-candidate";
  let active_text = snd (List.hd active_styles) in
  require (Base.String.is_substring active_text ~substring:"> 出金元") "stability-panel-active-is-input-field";
  require (List.exists (fun (_, t) -> Base.String.is_substring t ~substring:"*") heading_styles)
    "stability-panel-heading-is-selected-candidate";

  (* 5. 画面サイズ変更後も操作不能なフィールドが生じない *)
  List.iter
    (fun dim ->
      List.iter
        (fun f ->
          let s_f = { s_edit with focus = f } in
          let w, h = get_overlay_dims s_f dim in
          require (w > 0 && h > 0) "stability-resized-valid-overlay")
        fields)
    [ (64, 20); (80, 24); (100, 30); (40, 14) ];

  print_endline "PASS: floating editor geometry stability, unified key navigation, focus style distinction, and resize tolerance."

let split_form_self_check ~directory ~base =
  let require = F.require in
  let step s input =
    match handle s input with Some s -> s | None -> raise (F.Refused "split-unexpected-exit")
  in
  let press s button = step s (`Key (button, [])) in
  let ctrl s c = step s (`Key (`ASCII c, [ `Ctrl ])) in
  let text s value =
    Uutf.String.fold_utf_8
      (fun s _ -> function `Uchar c -> press s (`Uchar c) | `Malformed _ -> s)
      s value
  in
  let path = directory ^ "/split.sexp" in
  F.write_new path (B.to_string base.session.book);
  let s = initial ~config_home:directory (F.load path) in
  (* 1. 出金元で '+' を押して出金元行が増えること *)
  let s_added_src = press { s with focus = Source } (`ASCII '+') in
  require
    (match s_added_src.split with
    | Some sp -> List.length sp.sources = 2 && List.length sp.destinations = 1
    | None -> false)
    "split-add-source-increased-rows";
  require (s_added_src.focus = Split (Source_locus 1)) "split-add-source-focused-new-locus";

  (* 2. '-' で行が削除できること *)
  let s_removed_src = press s_added_src (`ASCII '-') in
  require
    (match s_removed_src.split with
    | Some sp -> List.length sp.sources = 1
    | None -> false)
    "split-remove-source-decreased-rows";

  (* 3. 入金先で '+' を押して入金先行が増えること *)
  let s_added_dst = press { s with focus = Destination } (`ASCII '+') in
  require
    (match s_added_dst.split with
    | Some sp -> List.length sp.sources = 1 && List.length sp.destinations = 2
    | None -> false)
    "split-add-destination-increased-rows";
  require (s_added_dst.focus = Split (Destination_locus 1)) "split-add-destination-focused-new-locus";

  (* 4. 差額自動補完とスマートEnterのフロー:
        出金元 1000円
        入金先1 食費 600円
        Enter押下 -> 自動で入金先2が追加され、金額400円が補完される！
        入金先2科目選択 -> Enter押下 -> 差額0なのでMemoへ進む！ *)
  let s = { s with focus = Source } in
  let s = press s (`ASCII '+') in
  let s = press s (`ASCII '-') in
  let s = { s with focus = Split (Source_amount 0) } in
  let s = text s "1000" in
  let s = { s with focus = Split (Destination_locus 0) } in
  let s = match s.split with
    | Some sp -> { s with split = Some { sp with destinations = [ { (List.hd sp.destinations) with locus = "food" } ] } }
    | None -> s
  in
  let s = { s with focus = Split (Destination_amount 0) } in
  let s = text s "600" in
  let s = press s `Enter in
  require
    (match s.split with
    | Some sp ->
        List.length sp.destinations = 2
        && (List.nth sp.destinations 1).amount = "400"
    | None -> false)
    "split-smart-enter-auto-added-destination-with-residual";
  require (s.focus = Split (Destination_locus 1)) "split-smart-enter-focused-new-destination-locus";

  let s = match s.split with
    | Some sp ->
        let dsts = List.mapi (fun i (r : split_row) -> if i = 1 then { r with locus = "bank" } else r) sp.destinations in
        { s with split = Some { sp with destinations = dsts } }
    | None -> s
  in
  let s = { s with focus = Split (Destination_amount 1) } in
  let s = press s `Enter in
  require (s.focus = Memo) "split-smart-enter-zero-residual-advanced-to-memo";
  let s = text s "架空の分割記帳" in

  (* 画面描画の行数と全行表示の検証: 分割フォームで行が増えても記帳欄が見切れず全行含まれ、画面高さにピッタリ収まること *)
  let lines_24 = screen ~frontend:"check" (80, 24) s in
  require (List.length lines_24 = 24) "split-screen-height-24-fit";
  let rendered_texts =
    match overlay_screen ~dimensions:(80, 24) ~width_of:String.length s with
    | Some rows -> List.map snd rows
    | None -> List.map snd lines_24
  in
  require
    (List.exists (fun t -> Base.String.is_substring t ~substring:"出金元 1") rendered_texts)
    "split-screen-contains-src-1";
  require
    (List.exists (fun t -> Base.String.is_substring t ~substring:"入金先 1") rendered_texts)
    "split-screen-contains-dst-1";
  require
    (List.exists (fun t -> Base.String.is_substring t ~substring:"入金先 2") rendered_texts)
    "split-screen-contains-dst-2";
  require
    (List.exists (fun t -> Base.String.is_substring t ~substring:"下書き差額") rendered_texts)
    "split-screen-contains-residual";

  (* Floating Editor 内の Locus catalog の展開検証 *)
  let s_src_focused = { s with focus = Split (Source_locus 0) } in
  let rendered_cat =
    match overlay_screen ~dimensions:(80, 24) ~width_of:String.length s_src_focused with
    | Some rows -> List.map snd rows
    | None -> []
  in
  require
    (List.exists (fun t -> Base.String.is_substring t ~substring:"Locus catalog") rendered_cat)
    "split-screen-contains-locus-catalog";

  (* ホーム画面の残高サマリー表示とクイックキー（r/Esc）の検証 *)
  let s_home = { s with focus = History } in
  let lines_home = screen ~frontend:"check" (80, 24) s_home in
  let rendered_home = List.map snd lines_home in
  require
    (List.exists (fun t -> Base.String.is_substring t ~substring:"【口座残高】") rendered_home)
    "home-screen-contains-balance-summary";
  let entered = press s_home (`ASCII 'r') in
  require (entered.focus <> History) "home-r-key-starts-recording";
  let escaped = press entered `Escape in
  require (escaped.focus = History) "recording-escape-returns-home";

  (* 5. Ctrl-S で確認プレビューを開き、確定保存する *)
  let preview = ctrl s 's' in
  require (match preview.overlay with Preview _ -> true | _ -> false) "split-preview-opened";
  let saved = confirm preview in
  require (saved.overlay = No_overlay) "split-saved-confirmed";
  let loaded = (F.load path).book in
  let last_entry = List.hd (B.entries loaded) in
  require (List.length last_entry.effects = 3) "split-saved-three-effects";
  require (last_entry.memo = Some "架空の分割記帳") "split-saved-memo"

let split_safety_self_check ~directory ~base =
  let require = F.require in
  let step s input =
    match handle s input with Some s -> s | None -> raise (F.Refused "split-safety-exit")
  in
  let press s button = step s (`Key (button, [])) in
  let ctrl s c = step s (`Key (`ASCII c, [ `Ctrl ])) in
  let plan : B.plan =
    {
      id = "split-safety-plan";
      day = "2026-11-10";
      measure = "jpy";
      changes = [ ("wallet", Z.of_int (-1000)); ("food", Z.of_int 1000) ];
      paid_by = None;
      cancelled_on = None;
    }
  in
  let seed : B.entry =
    {
      id = "split-safety-existing";
      day = "2026-11-01";
      memo = None;
      effects =
        List.map
          (fun (locus, n) ->
            D.Effect.create ~key:None ~locus:(get_id (D.Identifier.Locus.of_string locus))
              ~measure:(get_id (D.Identifier.Measure.of_string "jpy"))
              ~quantity:(D.Quantity.of_quanta (Z.of_int n)))
          [ ("wallet", -50); ("food", 50) ];
      reversal_of = None;
      exchange = None;
    }
  in
  let book = get (B.put_plan base.session.book ~replace:false plan) in
  let book = get (B.put_entry book ~replace:false seed ~plan:None) in
  let path = directory ^ "/split-safety.sexp" in
  F.write_new path (B.to_string book);
  let fresh () = initial ~config_home:directory (F.load path) in
  let base = fresh () in
  let split : split_state =
    {
      sources = [ { locus = "wallet"; amount = "1000" } ];
      destinations = [ { locus = "food"; amount = "600" }; { locus = "bank"; amount = "400" } ];
    }
  in
  let filled =
    {
      base with
      form = { base.form with amount = "600"; day = "2026-11-03"; memo = "分割を保持" };
      split = Some split;
      focus = Split (Destination_amount 1);
    }
  in
  let same_draft a b =
    a.form = b.form && a.split = b.split && a.postings = b.postings && a.mode = b.mode
    && a.adding = b.adding
  in
  let before = F.read path in
  let files () = Sys.readdir directory |> Array.to_list |> List.sort String.compare in
  let before_files = files () in
  let opened = ctrl filled 't' in
  let expected_rows =
    [
      { R.key = None; locus = "wallet"; negative = true; amount = "1000" };
      { R.key = None; locus = "food"; negative = false; amount = "600" };
      { R.key = None; locus = "bank"; negative = false; amount = "400" };
    ]
  in
  require
    (match opened.postings with
    | Some e -> e.visible && e.draft.measure = "jpy" && e.draft.rows = expected_rows
    | None -> false)
    "split-to-editor-lost-rows-or-amounts";
  require (opened.split = None && opened.form = filled.form) "split-conversion-kept-two-drafts";
  let held = press opened `Escape in
  let resumed = ctrl held 't' in
  require (resumed.postings = opened.postings && resumed.split = None) "split-editor-resume-lost-rows";
  require ((press { held with focus = Source } (`ASCII '+')).split = None)
    "split-held-editor-created-a-second-inline-draft";
  let preview = ctrl resumed 's' in
  require
    (match preview.overlay with
    | Preview { transaction; _ } ->
        List.map quanta transaction.entry.effects = List.map Z.of_int [ -1000; 600; 400 ]
        && transaction.entry.day = filled.form.day && transaction.entry.memo = Some filled.form.memo
    | _ -> false)
    "split-converted-preview-lost-transaction";
  require (same_draft (press preview `Escape) resumed) "split-preview-cancel-lost-draft";
  let partial =
    {
      base with
      split =
        Some
          {
            sources = [ { locus = "wallet"; amount = "" } ];
            destinations = [ { locus = "food"; amount = "" }; { locus = "bank"; amount = "400" } ];
          };
    }
  in
  require (has_draft partial && has_draft { base with split = Some split })
    "split-secondary-row-not-a-draft";
  require (same_draft (ctrl partial 'e') partial) "split-partial-replaced-by-edit";
  require
    (same_draft (pay_selected { partial with view = Plans; selected = List.length (plans partial) - 1 })
       partial)
    "split-partial-replaced-by-payment";
  require
    ((press { partial with focus = Currency } (`Arrow `Right)).form.measure = partial.form.measure)
    "split-secondary-amount-currency-changed";
  let incomplete = ctrl partial 't' in
  require
    (match incomplete.postings with
    | Some e -> List.map (fun (r : R.row) -> r.amount) e.draft.rows = [ ""; ""; "400" ]
    | None -> false)
    "split-conversion-filled-or-dropped-blank-amount";
  require (same_draft (ctrl incomplete 's') incomplete) "split-invalid-preview-lost-draft";
  let foreign =
    {
      filled with
      form = { filled.form with measure = "eur"; amount = "6.00" };
      split =
        Some
          {
            sources = [ { locus = "wallet"; amount = "10.00" } ];
            destinations = [ { locus = "food"; amount = "6.00" }; { locus = "bank"; amount = "4.00" } ];
          };
    }
  in
  let foreign_preview = ctrl (ctrl foreign 't') 's' in
  require
    (match foreign_preview.overlay with
    | Preview { transaction; _ } ->
        List.map quanta transaction.entry.effects = List.map Z.of_int [ -1000; 600; 400 ]
        && List.for_all (fun p -> mstr (D.Effect.measure p) = "eur") transaction.entry.effects
    | _ -> false)
    "split-conversion-lost-foreign-measure-or-scale";
  let editable_row = { partial with focus = Split (Destination_locus 0) } in
  let cycled = press editable_row (`Arrow `Right) in
  require (cycled.split <> editable_row.split) "split-empty-row-cannot-select-locus";
  List.iter
    (fun focus ->
      let selected = { filled with focus } in
      require
        ((press selected (`Arrow `Right)).split = selected.split)
        "split-arrow-bypassed-filled-row-locus-guard";
      let picker = press selected `Enter in
      require
        (picker_is_open picker && (press picker `Enter).split = selected.split)
        "split-picker-bypassed-filled-row-locus-guard")
    [ Split (Source_locus 0); Split (Destination_locus 1) ];
  List.iter
    (fun pending ->
      List.iter
        (fun focus ->
          let frozen = { filled with focus; blocked = true; pending; message = "household-warning" } in
          let unchanged changed =
            require
              (same_draft frozen changed && changed.pending = frozen.pending && changed.blocked
              && changed.message = frozen.message)
              "split-blocked-input-mutated-draft-or-warning"
          in
          List.iter
            (fun key -> unchanged (press frozen key))
            [ `ASCII '9'; `ASCII '+'; `ASCII '-'; `Backspace; `Delete; `Enter; `Arrow `Right ];
          List.iter (fun c -> unchanged (ctrl frozen c)) [ 'a'; 'd'; 'u'; 's'; 't' ];
          List.iter
            (fun payload ->
              let pasted = List.fold_left press (step frozen (`Paste `Start)) payload in
              unchanged (step pasted (`Paste `End)))
            [ [ `ASCII '9' ]; [ `ASCII '9'; `Enter ] ])
        [
          Split (Source_amount 0); Split (Destination_amount 1);
          Split (Source_locus 0); Split (Destination_locus 1); Date; Currency; Memo;
        ])
    [ None; Some (A.Unspecified_evidence "synthetic-unconfirmed") ];
  require (F.read path = before && files () = before_files) "split-readonly-checks-published";
  let saved = ctrl preview 's' in
  let cold = (F.load path).book in
  require (not saved.blocked && saved.split = None && saved.postings = None) "split-save-draft-not-reset";
  let actual = List.hd (entries saved) in
  require
    (List.map quanta actual.effects = List.map Z.of_int [ -1000; 600; 400 ]
    && List.map (fun p -> lstr (D.Effect.locus p)) actual.effects = [ "wallet"; "food"; "bank" ]
    && List.find (fun (e : B.entry) -> e.id = seed.id) (B.entries cold) = seed)
    "split-cold-save-lost-effects-or-existing-entry";
  let payer = { filled with session = (fresh ()).session; mode = Pay plan.id } in
  let paid = ctrl (ctrl (ctrl payer 't') 's') 's' in
  let cold = (F.load path).book in
  let paid_plan = List.find (fun (p : B.plan) -> p.id = plan.id) (B.plans cold) in
  let payment = List.hd (entries paid) in
  require
    (not paid.blocked && paid_plan.paid_by = Some payment.id
    && paid_plan.day = plan.day && paid_plan.changes = plan.changes
    && List.map quanta payment.effects = List.map Z.of_int [ -1000; 600; 400 ])
    "split-converted-payment-lost-link-or-scheduled-evidence";
  print_endline
    "PASS: split/editor row-preserving conversion, partial-draft guards, frozen conflict/uncertain \
     input/paste, preview/cancel and cold save/payment."

let error_display_self_check ~directory ~base =
  let require = F.require in
  let step s input =
    match handle s input with Some s -> s | None -> raise (F.Refused "error-display-exit")
  in
  let press s button = step s (`Key (button, [])) in
  let make_effect locus measure quantity =
    D.Effect.create ~key:None
      ~locus:(get_id (D.Identifier.Locus.of_string locus))
      ~measure:(get_id (D.Identifier.Measure.of_string measure))
      ~quantity:(D.Quantity.of_quanta quantity)
  in

  (* 1. 日付エラー: 形式不正で日付欄へフォーカス移動、下書き保持、blockedにならない *)
  let orig_bad_date = { base.form with day = "2026-99-99"; from_locus = "wallet"; to_locus = "food"; amount = "500" } in
  let s_bad_date = { base with form = orig_bad_date; focus = Amount } in
  let s_date_err = press s_bad_date `Enter in
  require (s_date_err.focus = Date) "error-display-bad-date-focus-to-date";
  require (Base.String.is_substring s_date_err.message ~substring:"日付の形式が正しくありません") "error-display-bad-date-message";
  require (s_date_err.form = orig_bad_date) "error-display-bad-date-draft-retained";
  require (not s_date_err.blocked) "error-display-bad-date-not-blocked";

  (* 2. 出金元未選択: 出金元欄へフォーカス移動、下書き保持 *)
  let orig_empty_src = { base.form with day = "2026-10-09"; from_locus = ""; to_locus = "food"; amount = "500" } in
  let s_empty_src = { base with form = orig_empty_src; focus = Amount } in
  let s_src_err = press s_empty_src `Enter in
  require (s_src_err.focus = Source) "error-display-empty-source-focus-to-source";
  require (Base.String.is_substring s_src_err.message ~substring:"出金元の科目が未選択です") "error-display-empty-source-message";
  require (s_src_err.form = orig_empty_src) "error-display-empty-source-draft-retained";

  (* 3. 入金先未選択: 入金先欄へフォーカス移動、下書き保持 *)
  let orig_empty_dst = { base.form with day = "2026-10-09"; from_locus = "wallet"; to_locus = ""; amount = "500" } in
  let s_empty_dst = { base with form = orig_empty_dst; focus = Amount } in
  let s_dst_err = press s_empty_dst `Enter in
  require (s_dst_err.focus = Destination) "error-display-empty-destination-focus-to-destination";
  require (Base.String.is_substring s_dst_err.message ~substring:"入金先・科目が未選択です") "error-display-empty-destination-message";
  require (s_dst_err.form = orig_empty_dst) "error-display-empty-destination-draft-retained";

  (* 4. 同一科目: 入金先欄へフォーカス移動、科目名を含む自然な日本語メッセージ、下書き保持 *)
  let orig_same = { base.form with day = "2026-10-09"; from_locus = "wallet"; to_locus = "wallet"; amount = "500" } in
  let s_same = { base with form = orig_same; focus = Amount } in
  let s_same_err = press s_same `Enter in
  require (s_same_err.focus = Destination) "error-display-same-locus-focus-to-destination";
  require (Base.String.is_substring s_same_err.message ~substring:"同じ科目") "error-display-same-locus-message-same";
  require (s_same_err.form = orig_same) "error-display-same-locus-draft-retained";

  (* 5. 金額未入力: 金額欄へフォーカス移動、下書き保持 *)
  let orig_empty_amt = { base.form with day = "2026-10-09"; from_locus = "wallet"; to_locus = "food"; amount = "" } in
  let s_empty_amt = { base with form = orig_empty_amt; focus = Memo } in
  let s_amt_err = press s_empty_amt `Enter in
  require (s_amt_err.focus = Amount) "error-display-empty-amount-focus-to-amount";
  require (Base.String.is_substring s_amt_err.message ~substring:"金額が入力されていません") "error-display-empty-amount-message";
  require (s_amt_err.form = orig_empty_amt) "error-display-empty-amount-draft-retained";

  (* 6. 金額形式不正: 金額欄へフォーカス移動、下書き保持 *)
  let orig_bad_amt = { base.form with day = "2026-10-09"; from_locus = "wallet"; to_locus = "food"; amount = "abc" } in
  let s_bad_amt = { base with form = orig_bad_amt; focus = Memo } in
  let s_amt_fmt_err = press s_bad_amt `Enter in
  require (s_amt_fmt_err.focus = Amount) "error-display-bad-amount-focus-to-amount";
  require (Base.String.is_substring s_amt_fmt_err.message ~substring:"金額の形式が正しくありません") "error-display-bad-amount-message";
  require (s_amt_fmt_err.form = orig_bad_amt) "error-display-bad-amount-draft-retained";

  (* 7. 小数桁数超過: 金額欄へフォーカス移動、下書き保持 *)
  let orig_prec = { base.form with day = "2026-10-09"; measure = "jpy"; from_locus = "wallet"; to_locus = "food"; amount = "100.5" } in
  let s_prec = { base with form = orig_prec; focus = Memo } in
  let s_prec_err = press s_prec `Enter in
  require (s_prec_err.focus = Amount) "error-display-precision-focus-to-amount";
  require (Base.String.is_substring s_prec_err.message ~substring:"小数桁数を超えています") "error-display-precision-message";
  require (s_prec_err.form = orig_prec) "error-display-precision-draft-retained";

  (* 8. ゼロ・負の金額: 金額欄へフォーカス移動、下書き保持 *)
  let orig_zero = { base.form with day = "2026-10-09"; from_locus = "wallet"; to_locus = "food"; amount = "0" } in
  let s_zero = { base with form = orig_zero; focus = Memo } in
  let s_zero_err = press s_zero `Enter in
  require (s_zero_err.focus = Amount) "error-display-zero-amount-focus-to-amount";
  require (Base.String.is_substring s_zero_err.message ~substring:"0より大きい正の値") "error-display-zero-amount-message";
  require (s_zero_err.form = orig_zero) "error-display-zero-amount-draft-retained";

  (* 9. entry-admission: 実際の該当エラーを発生させ、返却されたメッセージとフィールドを検証 *)
  let orig_entry : B.entry =
    {
      id = "entry-e1";
      day = "2026-10-09";
      memo = Some "Orig";
      effects =
        [
          make_effect "wallet" "jpy" (Z.of_int (-1000));
          make_effect "food" "jpy" (Z.of_int 1000);
        ];
      reversal_of = None;
      exchange = None;
    }
  in
  let rev_entry : B.entry =
    {
      id = "entry-rev";
      day = "2026-10-09";
      memo = Some "Rev";
      effects =
        [
          make_effect "wallet" "jpy" (Z.of_int 1000);
          make_effect "food" "jpy" (Z.of_int (-1000));
        ];
      reversal_of = Some orig_entry.id;
      exchange = None;
    }
  in
  let book_with_e1 = F.get "book-e1" (B.put_entry base.session.book ~replace:false orig_entry ~plan:None) in
  let book_with_rev = F.get "book-rev" (B.put_entry book_with_e1 ~replace:false rev_entry ~plan:None) in
  (* orig_entryを金額変更して更新しようとすると、rev_entryとの反転関係が崩れるためCoreのentry-admissionにより拒否される *)
  let content = A.Single { day = "2026-10-09"; measure = "jpy"; from_locus = "wallet"; to_locus = "food"; amount = "500"; memo = "" } in
  (match A.build_transaction ~book:book_with_rev ~mode:(A.Edit orig_entry) content with
   | Ok _ -> failwith "expected entry-admission error, got Ok"
   | Error err ->
       require (err.field = None) "error-display-entry-admission-field-none";
       require (err.raw_cause = "entry-admission") "error-display-entry-admission-raw-cause";
       require (not (Base.String.is_substring err.message ~substring:"日付")) "error-display-entry-admission-not-blamed-on-date";
       require (Base.String.is_substring err.message ~substring:"entry-admission") "error-display-entry-admission-retains-code";
       require (Base.String.is_substring err.message ~substring:"台帳の記録要件を満たしていません") "error-display-entry-admission-message-text");

  let s_edit_admission =
    {
      base with
      session = { base.session with book = book_with_rev };
      mode = A.Edit orig_entry;
      form = { base.form with day = "2026-10-09"; measure = "jpy"; from_locus = "wallet"; to_locus = "food"; amount = "500" };
      focus = Amount;
    }
  in
  let s_admitted_err = submit s_edit_admission in
  require (s_admitted_err.focus = Amount) "error-display-entry-admission-focus-not-moved-to-date";
  require (s_admitted_err.form.amount = "500") "error-display-entry-admission-draft-retained";
  require (not (Base.String.is_substring s_admitted_err.message ~substring:"日付")) "error-display-entry-admission-submit-not-blamed-on-date";
  require (Base.String.is_substring s_admitted_err.message ~substring:"entry-admission") "error-display-entry-admission-submit-retains-code";

  (* Movement.validate: 貸借不一致だけでなく、各型付きエラーの原因に応じた案内を検証 *)
  let unbalanced_draft =
    {
      R.measure = "jpy";
      rows =
        [
          { key = None; locus = "wallet"; negative = true; amount = "100" };
          { key = None; locus = "food"; negative = false; amount = "80" };
        ];
    }
  in
  let content_unbalanced = A.Multiple { day = "2026-10-09"; memo = ""; draft = unbalanced_draft } in
  (match A.build_transaction ~book:base.session.book ~mode:New content_unbalanced with
   | Ok _ -> failwith "expected unbalanced error, got Ok"
   | Error err ->
       require (err.field = Some A.Field_amount) "error-display-movement-unbalanced-field";
       require (err.raw_cause = "unbalanced-movement") "error-display-movement-unbalanced-cause";
       require (Base.String.is_substring err.message ~substring:"出金と入金の合計額が一致していません") "error-display-movement-unbalanced-message");

  let zero_effects =
    [
      make_effect "wallet" "jpy" Z.zero;
      make_effect "food" "jpy" Z.zero;
    ]
  in
  (match D.Movement.validate zero_effects with
   | Error (D.Movement.Zero_quantity { position } :: _) ->
       require (position = 1) "error-display-movement-zero-quantity-position"
   | _ -> failwith "expected Zero_quantity error");

  let mismatch_effects =
    [
      make_effect "wallet" "jpy" (Z.of_int (-100));
      make_effect "food" "eur" (Z.of_int 100);
    ]
  in
  (match D.Movement.validate mismatch_effects with
   | Error (D.Movement.Measure_mismatch _ :: _) -> ()
   | _ -> failwith "expected Measure_mismatch error");

  (* 10. 保存失敗、LSN競合、成否不確定、破損時のfail-closedと下書き保持の区別 *)
  let dummy_draft = { base with form = orig_bad_date } in
  let s_stor = apply_commit_result base ~draft:dummy_draft (A.Storage_failed "Read-only file system") in
  require s_stor.blocked "error-display-storage-failed-blocked";
  require (s_stor.form = orig_bad_date) "error-display-storage-failed-draft-retained";
  require (Base.String.is_substring s_stor.message ~substring:"保存に失敗しました") "error-display-storage-failed-message-title";
  require (Base.String.is_substring s_stor.message ~substring:"Read-only file system") "error-display-storage-failed-message-raw";

  let s_lsn = apply_commit_result base ~draft:dummy_draft (A.Conflict_lsn { expected = 3; actual = 4 }) in
  require s_lsn.blocked "error-display-conflict-lsn-blocked";
  require (s_lsn.form = orig_bad_date) "error-display-conflict-lsn-draft-retained";
  require (Base.String.is_substring s_lsn.message ~substring:"LSN: 期待3 / 実際4") "error-display-conflict-lsn-message";

  let s_uncert =
    apply_commit_result base ~draft:dummy_draft
      (A.Uncertain
         {
           message = "sync-timeout";
           evidence = A.Unspecified_evidence "sync-timeout";
         })
  in
  require s_uncert.blocked "error-display-uncertain-blocked";
  require (s_uncert.form = orig_bad_date) "error-display-uncertain-draft-retained";
  require (Base.String.is_substring s_uncert.message ~substring:"書込結果が不明です") "error-display-uncertain-message";
  require (Base.String.is_substring s_uncert.message ~substring:"sync-timeout") "error-display-uncertain-raw";

  let s_drift = apply_commit_result base ~draft:dummy_draft (A.Payload_drift_refused "duplicate-id-drift") in
  require s_drift.blocked "error-display-drift-blocked";
  require (s_drift.form = orig_bad_date) "error-display-drift-draft-retained";
  require (Base.String.is_substring s_drift.message ~substring:"同一IDで異なる内容の記帳が試行されました") "error-display-drift-message";

  (* 11. 複数行・分割下書き差額の自然な日本語エラー表示 *)
  let bad_split : split_state =
    {
      sources = [ { locus = "wallet"; amount = "bad" } ];
      destinations = [ { locus = "food"; amount = "100" } ];
    }
  in
  let s_split_bad = { base with split = Some bad_split; form = { base.form with measure = "jpy" } } in
  let rendered_split =
    match overlay_screen ~dimensions:(80, 24) ~width_of:String.length s_split_bad with
    | Some rows -> List.map snd rows
    | None -> List.map snd (screen ~frontend:"check" (80, 24) s_split_bad)
  in
  require
    (List.exists (fun t -> Base.String.is_substring t ~substring:"下書き差額: 計算不可") rendered_split)
    "error-display-split-residual-natural-message";
  require
    (List.exists (fun t -> Base.String.is_substring t ~substring:"金額の形式が不正です") rendered_split)
    "error-display-split-residual-details";

  (* 12. 回帰テスト: 一括書換 (Monolithic) の保存後Ack喪失、下書き保持、再読込後の確認・未確認 *)
  let mono_path = directory ^ "/mono-regression-" ^ F.new_id () ^ ".sexp" in
  F.write_new mono_path base.session.bytes;
  let mono_sess = F.load mono_path in
  let mono_cand_entry : B.entry =
    {
      id = "mono-cand-" ^ F.new_id ();
      day = "2026-10-09";
      memo = Some "Mono ack-loss candidate";
      effects =
        [
          make_effect "wallet" "jpy" (Z.of_int (-500));
          make_effect "food" "jpy" (Z.of_int 500);
        ];
      reversal_of = None;
      exchange = None;
    }
  in
  let mono_cand_book = F.get "cand-book" (B.put_entry mono_sess.book ~replace:false mono_cand_entry ~plan:None) in
  let mono_cand_bytes = B.to_string mono_cand_book in
  let mono_state = initial ~config_home:directory mono_sess in
  let mono_draft = { mono_state with form = { mono_state.form with day = "2026-10-09"; amount = "500" } } in
  (* Ack喪失シミュレーション: 不確定結果を適用。下書きとblockedが保持され、再送が阻止される *)
  let s_mono_uncert =
    apply_commit_result mono_draft ~draft:mono_draft
      (A.Uncertain
         {
           message = "一括書換の成否が不確定です";
           evidence = A.Monolithic_candidate mono_cand_bytes;
         })
  in
  require s_mono_uncert.blocked "mono-ack-loss-blocked";
  require (s_mono_uncert.pending = Some (A.Monolithic_candidate mono_cand_bytes)) "mono-ack-loss-pending";
  require (s_mono_uncert.form.amount = "500") "mono-ack-loss-draft-retained";
  require (Base.String.is_substring s_mono_uncert.message ~substring:"一括書換の成否が不確定です") "mono-ack-loss-message-raw";
  let pressed_mono = press s_mono_uncert `Enter in
  require (pressed_mono.blocked && pressed_mono.pending = s_mono_uncert.pending && pressed_mono.form = s_mono_uncert.form) "mono-ack-loss-resend-stopped";

  (* ケースA: ディスクが旧内容のまま (保存未達) の再読込 -> Pending_unconfirmed で下書き・blocked・再送停止を維持 *)
  let s_mono_unconf = reload s_mono_uncert in
  require s_mono_unconf.blocked "mono-unconfirmed-blocked";
  require (s_mono_unconf.pending = Some (A.Monolithic_candidate mono_cand_bytes)) "mono-unconfirmed-pending-preserved";
  require (s_mono_unconf.form.amount = "500") "mono-unconfirmed-draft-retained";
  require (Base.String.is_substring s_mono_unconf.message ~substring:"先ほどの書込は未確認") "mono-unconfirmed-message";

  (* ケースB: ディスクに保存候補が到達済み (保存後Ack喪失) の再読込 -> 候補バイト列照合で Pending_confirmed となり成功復帰 *)
  let mono_tmp = mono_path ^ ".tmp" in
  F.write_new mono_tmp mono_cand_bytes;
  Unix.rename mono_tmp mono_path;
  let s_mono_conf = reload s_mono_uncert in
  require (not s_mono_conf.blocked) "mono-confirmed-unblocked";
  require (s_mono_conf.pending = None) "mono-confirmed-pending-cleared";
  require (s_mono_conf.form.amount = "") "mono-confirmed-draft-cleared";
  require (Base.String.is_substring s_mono_conf.message ~substring:"先ほどの記帳が現在のファイルにあります") "mono-confirmed-message";

  (* 13. 回帰テスト: Records形式のSync_uncertain、request_tokenと確定ログによる照合、再読込後の確認・未確認 *)
  let rec_path = directory ^ "/records-regression-" ^ F.new_id () ^ ".sexp" in
  let rec_init_str = B.to_records_string base.session.book in
  F.write_new rec_path rec_init_str;
  let rec_sess = F.load rec_path in
  require (rec_sess.format = F.Records) "rec-format-is-records";
  let rec_entry_id = "rec-entry-" ^ F.new_id () in
  let rec_tok = "tok-" ^ rec_entry_id in
  let rec_cand_entry : B.entry =
    {
      id = rec_entry_id;
      day = "2026-10-09";
      memo = Some "Records sync-uncertain";
      effects =
        [
          make_effect "wallet" "jpy" (Z.of_int (-800));
          make_effect "food" "jpy" (Z.of_int 800);
        ];
      reversal_of = None;
      exchange = None;
    }
  in
  let rec_entry_wire = A.to_records_entry rec_cand_entry in
  let rec_state = initial ~config_home:directory rec_sess in
  let rec_draft = { rec_state with form = { rec_state.form with day = "2026-10-09"; amount = "800" } } in
  (* ケースA: トークンが確定ログに存在しない (保存未達) 状態での再読込 -> 説明文字列に依存せず Pending_unconfirmed *)
  let s_rec_uncert =
    apply_commit_result rec_draft ~draft:rec_draft
      (A.Uncertain
         {
           message = "ディレクトリ同期失敗: synthetic-fsync-error";
           evidence = A.Records_token { request_token = rec_tok; lsn = 1; event_id = rec_entry_id };
         })
  in
  require s_rec_uncert.blocked "records-sync-uncert-blocked";
  require (s_rec_uncert.pending = Some (A.Records_token { request_token = rec_tok; lsn = 1; event_id = rec_entry_id })) "records-sync-uncert-pending";
  require (s_rec_uncert.form.amount = "800") "records-sync-uncert-draft-retained";
  require (Base.String.is_substring s_rec_uncert.message ~substring:"ディレクトリ同期失敗") "records-sync-uncert-message-raw";
  let pressed_rec = press s_rec_uncert `Enter in
  require (pressed_rec.blocked && pressed_rec.pending = s_rec_uncert.pending && pressed_rec.form = s_rec_uncert.form) "records-sync-uncert-resend-stopped";

  let s_rec_unconf = reload s_rec_uncert in
  require s_rec_unconf.blocked "records-unconfirmed-blocked";
  require (s_rec_unconf.pending = Some (A.Records_token { request_token = rec_tok; lsn = 1; event_id = rec_entry_id })) "records-unconfirmed-pending-preserved";
  require (s_rec_unconf.form.amount = "800") "records-unconfirmed-draft-retained";
  require (Base.String.is_substring s_rec_unconf.message ~substring:"先ほどの書込は未確認") "records-unconfirmed-message";

  (* ケースB: 追記は確定ログにコミットされたがSyncがUncertainだった場合 -> request_tokenとログ照合で Pending_confirmed *)
  let append_res = F.append_entry rec_sess rec_entry_wire in
  (match append_res with
   | F.Append_committed { lsn; event_id; _ } ->
       require (event_id = rec_entry_id) "records-append-committed-id";
       require (lsn >= 1) "records-append-committed-lsn"
   | _ -> failwith "expected Append_committed for setup");
  let s_rec_conf = reload s_rec_uncert in
  require (not s_rec_conf.blocked) "records-confirmed-unblocked";
  require (s_rec_conf.pending = None) "records-confirmed-pending-cleared";
  require (s_rec_conf.form.amount = "") "records-confirmed-draft-cleared";
  require (Base.String.is_substring s_rec_conf.message ~substring:"先ほどの記帳が現在のファイルにあります") "records-confirmed-message";

  print_endline
    "PASS: error display natural Japanese, field focus targeting, non-blaming admission, draft \
     retention, and storage/LSN/uncertain fail-closed distinction."

let flexible_input_self_check ~directory ~base =
  let require = F.require in
  let step s input =
    match handle s input with Some s -> s | None -> raise (F.Refused "flexible-input-exit")
  in
  let press s button = step s (`Key (button, [])) in

  (* 1. 日付正規化と検証: YYYY-MM-DD, YYYY/MM/DD, YYYY.MM.DD, YYYY/M/D, 全角区切り・全角数字 *)
  let check_date_ok raw expected =
    match A.normalize_date raw with
    | Ok canon -> require (canon = expected) ("date-norm-mismatch-" ^ raw)
    | Error err -> failwith ("expected valid date for " ^ raw ^ ", got " ^ err)
  in
  let check_date_err raw =
    match A.normalize_date raw with
    | Error _ -> ()
    | Ok canon -> failwith ("expected error for date " ^ raw ^ ", got " ^ canon)
  in
  check_date_ok "2026-10-09" "2026-10-09";
  check_date_ok "2026/10/09" "2026-10-09";
  check_date_ok "2026.10.09" "2026-10-09";
  check_date_ok "2026/1/9" "2026-01-09";
  check_date_ok "2026-1-9" "2026-01-09";
  check_date_ok "2026.1.9" "2026-01-09";
  check_date_ok "２０２６／１／９" "2026-01-09";
  check_date_ok "２０２６．１０．０９" "2026-10-09";
  check_date_ok "２０２６－１０－０９" "2026-10-09";
  check_date_ok "2024-02-29" "2024-02-29"; (* うるう年 *)
  check_date_ok "2024/2/29" "2024-02-29";
  check_date_ok "2000-02-29" "2000-02-29"; (* 400年閏年 *)
  check_date_ok "2026-02-28" "2026-02-28";
  check_date_ok "2026-12-31" "2026-12-31";
  check_date_ok "2026-01-01" "2026-01-01";

  (* 日付エラー検証: 平年2/29、100年非閏年、月超過、日超過、ゼロ、区切り不整合、年省略 *)
  check_date_err "2026-02-29"; (* 平年2月29日 *)
  check_date_err "2026/02/29";
  check_date_err "1900-02-29"; (* 100年非閏年 *)
  check_date_err "2026-04-31"; (* 4月31日 *)
  check_date_err "2026-13-01";
  check_date_err "2026-00-10";
  check_date_err "2026-10-00";
  check_date_err "2026-10-32";
  check_date_err "20261009";  (* 区切りなし *)
  check_date_err "10-09";     (* 年省略 *)
  check_date_err "1009";
  check_date_err "2026-10/09"; (* 混在区切り *)
  check_date_err "2026-10";    (* 日欠落 *)

  (* 2. 暦日単位の日付計算 (shift_calendar_day): 月末、年末、閏年 *)
  let check_shift raw step expected =
    match A.shift_calendar_day raw step with
    | Ok shifted -> require (shifted = expected) ("shift-mismatch-" ^ raw)
    | Error err -> failwith ("expected shift for " ^ raw ^ ", got " ^ err)
  in
  check_shift "2026-10-09" 1 "2026-10-10";
  check_shift "2026-10-09" (-1) "2026-10-08";
  check_shift "2026-10-31" 1 "2026-11-01"; (* 月末跨ぎ *)
  check_shift "2026-11-01" (-1) "2026-10-31";
  check_shift "2026-12-31" 1 "2027-01-01"; (* 年末跨ぎ *)
  check_shift "2026-01-01" (-1) "2025-12-31"; (* 年始跨ぎ *)
  check_shift "2024-02-28" 1 "2024-02-29"; (* 閏年2/28 -> 2/29 *)
  check_shift "2024-02-29" 1 "2024-03-01"; (* 閏年2/29 -> 3/1 *)
  check_shift "2024-03-01" (-1) "2024-02-29"; (* 閏年3/1 -> 2/29 *)
  check_shift "2026-02-28" 1 "2026-03-01"; (* 平年2/28 -> 3/1 *)
  check_shift "2026-03-01" (-1) "2026-02-28"; (* 平年3/1 -> 2/28 *)
  check_shift "2026/1/9" 1 "2026-01-10"; (* スラッシュ入力からの加算 *)
  check_shift "２０２６．１０．０９" (-1) "2026-10-08";

  (* 3. 日付エラー時の下書き保持とフォーカス *)
  let orig_bad_leap = { base.form with day = "2026/02/29"; from_locus = "wallet"; to_locus = "food"; amount = "1000" } in
  let s_bad_leap = { base with form = orig_bad_leap; focus = Amount } in
  let s_leap_err = press s_bad_leap `Enter in
  require (s_leap_err.focus = Date) "flexible-bad-date-focus-to-date";
  require (s_leap_err.form.day = "2026/02/29") "flexible-bad-date-draft-retained";
  require (Base.String.is_substring s_leap_err.message ~substring:"日付の形式が正しくありません") "flexible-bad-date-message";

  (* 4. 金額エラー時の下書き保持とフォーカス (不正カンマ、小数超過、ゼロ、負値) *)
  let orig_bad_comma = { base.form with day = "2026-10-09"; from_locus = "wallet"; to_locus = "food"; amount = "12,34" } in
  let s_comma_err = press { base with form = orig_bad_comma; focus = Memo } `Enter in
  require (s_comma_err.focus = Amount) "flexible-bad-comma-focus-to-amount";
  require (s_comma_err.form.amount = "12,34") "flexible-bad-comma-draft-retained";
  require (Base.String.is_substring s_comma_err.message ~substring:"金額の形式が正しくありません") "flexible-bad-comma-message";

  let orig_fw_prec = { base.form with day = "2026-10-09"; measure = "jpy"; from_locus = "wallet"; to_locus = "food"; amount = "１０００．５" } in
  let s_prec_err = press { base with form = orig_fw_prec; focus = Memo } `Enter in
  require (s_prec_err.focus = Amount) "flexible-precision-focus-to-amount";
  require (s_prec_err.form.amount = "１０００．５") "flexible-precision-draft-retained";
  require (Base.String.is_substring s_prec_err.message ~substring:"小数桁数を超えています") "flexible-precision-message";

  let orig_fw_zero = { base.form with day = "2026-10-09"; from_locus = "wallet"; to_locus = "food"; amount = "０，０００" } in
  let s_zero_err = press { base with form = orig_fw_zero; focus = Memo } `Enter in
  require (s_zero_err.focus = Amount) "flexible-zero-focus-to-amount";
  require (s_zero_err.form.amount = "０，０００") "flexible-zero-draft-retained";
  require (Base.String.is_substring s_zero_err.message ~substring:"0より大きい正の値") "flexible-zero-message";

  let orig_fw_neg = { base.form with day = "2026-10-09"; from_locus = "wallet"; to_locus = "food"; amount = "ー１０００" } in
  let s_neg_err = press { base with form = orig_fw_neg; focus = Memo } `Enter in
  require (s_neg_err.focus = Amount) "flexible-neg-focus-to-amount";
  require (s_neg_err.form.amount = "ー１０００") "flexible-neg-draft-retained";
  require (Base.String.is_substring s_neg_err.message ~substring:"金額の形式が正しくありません") "flexible-neg-message";

  (* 5. 科目未選択エラー時でも、入力した全角・カンマ金額・スラッシュ日付が保持されること *)
  let orig_flexible_draft = { base.form with day = "2026/1/9"; from_locus = ""; to_locus = "food"; amount = "１，０００" } in
  let s_flex_err = press { base with form = orig_flexible_draft; focus = Amount } `Enter in
  require (s_flex_err.focus = Source) "flexible-draft-locus-err-focus";
  require (s_flex_err.form.day = "2026/1/9") "flexible-draft-retained-day";
  require (s_flex_err.form.amount = "１，０００") "flexible-draft-retained-amount";

  (* 6. キーボード入力: 日付欄での直接文字入力（ハイフン衝突なし）と 't' キー *)
  let empty_date_state = { base with form = { base.form with day = "" }; focus = Date } in
  let typed_date =
    List.fold_left
      (fun s ch -> press s (`ASCII ch))
      empty_date_state
      [ '2'; '0'; '2'; '6'; '-'; '1'; '0'; '-'; '0'; '9' ]
  in
  require (typed_date.form.day = "2026-10-09") "direct-date-hyphen-input-successful";

  (* 日付欄で 't' キー: 今日のローカル日付に復帰 *)
  let old_date_state = { base with form = { base.form with day = "2020-01-01" }; focus = Date } in
  let t_pressed = press old_date_state (`ASCII 't') in
  require (t_pressed.form.day = F.today ()) "date-t-key-resets-to-today";
  require (Base.String.is_substring t_pressed.message ~substring:"今日") "date-t-key-message";

  (* メモ欄で 't' キー: メモに 't' が入力され、日付はリセットされないこと *)
  let memo_state = { base with form = { base.form with day = "2020-01-01"; memo = "" }; focus = Memo } in
  let t_memo = press memo_state (`ASCII 't') in
  require (t_memo.form.memo = "t") "memo-t-key-types-char";
  require (t_memo.form.day = "2020-01-01") "memo-t-key-does-not-reset-date";

  (* 7. コマンドパレットからの日付操作: 今日、前日 (-1日)、翌日 (+1日) *)
  let sp_state = { base with form = { base.form with day = "2026-10-09" }; focus = Date } in
  let cmd_opened = press sp_state (`ASCII ' ') in
  require (cmd_opened.overlay = Commands 0) "commands-opened-from-date";

  (* コマンドパレットで ↓ で "今日の日付に戻す (Today)" (index 1) へ移動して Enter *)
  let cmd_today = press (press cmd_opened (`Arrow `Down)) `Enter in
  require (cmd_today.overlay = No_overlay) "cmd-today-overlay-closed";
  require (cmd_today.form.day = F.today ()) "cmd-today-sets-today";

  (* コマンドパレットで ↓↓ で "日付を前日へ (-1日)" (index 2) へ移動して Enter *)
  let cmd_prev = press (press (press (press { base with form = { base.form with day = "2026-10-09" }; focus = Date } (`ASCII ' ')) (`Arrow `Down)) (`Arrow `Down)) `Enter in
  require (cmd_prev.overlay = No_overlay) "cmd-prev-overlay-closed";
  require (cmd_prev.form.day = "2026-10-08") "cmd-prev-decrements-day";

  (* コマンドパレットで ↓↓↓ で "日付を翌日へ (+1日)" (index 3) へ移動して Enter *)
  let cmd_next = press (press (press (press (press { base with form = { base.form with day = "2026-10-09" }; focus = Date } (`ASCII ' ')) (`Arrow `Down)) (`Arrow `Down)) (`Arrow `Down)) `Enter in
  require (cmd_next.overlay = No_overlay) "cmd-next-overlay-closed";
  require (cmd_next.form.day = "2026-10-10") "cmd-next-increments-day";

  (* 8. 正常記帳と保存: 全角・カンマ金額「１，０００」とスラッシュ日付「2026/1/9」 *)
  let valid_flex_form =
    {
      day = "2026/1/9";
      measure = "jpy";
      from_locus = "wallet";
      to_locus = "food";
      amount = "１，０００";
      memo = "昼食（柔軟入力）";
    }
  in
  let s_flex_submit = press { base with form = valid_flex_form; focus = Amount } `Enter in
  (match s_flex_submit.overlay with
   | Preview p ->
       require (p.transaction.entry.day = "2026-01-09") "preview-normalized-date-entry";
       let food_eff = List.find (fun p -> D.Identifier.Locus.to_string (D.Effect.locus p) = "food") p.transaction.entry.effects in
       require (Z.equal (A.quanta food_eff) (Z.of_int 1000)) "preview-exact-quanta-1000"
   | _ -> failwith "expected Preview overlay for valid flex form");

  let s_saved = step s_flex_submit (`Key (`ASCII 's', [ `Ctrl ])) in
  require (s_saved.overlay = No_overlay) "saved-overlay-closed";
  require (s_saved.form.amount = "") "saved-draft-amount-cleared";
  let latest_entries = B.entries s_saved.session.book in
  let saved_entry = List.hd latest_entries in
  require (saved_entry.day = "2026-01-09") "persisted-entry-canonical-date";
  require (saved_entry.memo = Some "昼食（柔軟入力）") "persisted-entry-memo";
  let saved_food = List.find (fun p -> D.Identifier.Locus.to_string (D.Effect.locus p) = "food") saved_entry.effects in
  require (Z.equal (A.quanta saved_food) (Z.of_int 1000)) "persisted-entry-exact-quanta";

  (* 9. 小数通貨 (EUR) での「1,234.56」の正常記帳 *)
  let valid_eur_form =
    {
      day = "2026.10.09";
      measure = "eur";
      from_locus = "wallet";
      to_locus = "food";
      amount = "１，２３４．５６";
      memo = "Euro flexible";
    }
  in
  let s_eur_submit = press { base with form = valid_eur_form; focus = Amount } `Enter in
  (match s_eur_submit.overlay with
   | Preview p ->
       require (p.transaction.entry.day = "2026-10-09") "preview-eur-normalized-date";
       let food_eff = List.find (fun p -> D.Identifier.Locus.to_string (D.Effect.locus p) = "food") p.transaction.entry.effects in
       require (Z.equal (A.quanta food_eff) (Z.of_int 123456)) "preview-eur-quanta-123456"
   | _ -> failwith "expected Preview overlay for eur form");

  (* 10. blocked 状態での日付変更禁止 (コマンドパレット & 't' キー) *)
  let blocked_base =
    {
      base with
      blocked = true;
      form = { base.form with day = "2026-10-09"; amount = "1,000"; memo = "blocked-memo" };
      message = "保存試行の未確認情報があります。書込み停止。";
      focus = Date;
    }
  in

  (* blocked中の日付欄での 't' キー: 日付もメッセージも変更されないこと *)
  let blocked_t = press blocked_base (`ASCII 't') in
  require (blocked_t.form.day = "2026-10-09") "blocked-date-t-key-no-change-day";
  require (blocked_t.form.amount = "1,000") "blocked-date-t-key-retains-amount";
  require (blocked_t.form.memo = "blocked-memo") "blocked-date-t-key-retains-memo";
  require (blocked_t.blocked = true) "blocked-date-t-key-stays-blocked";
  require (blocked_t.message = "保存試行の未確認情報があります。書込み停止。") "blocked-date-t-key-retains-message";

  (* blocked中のコマンドパレット Date_today: 日付も下書きも変更されないこと *)
  let blocked_cmd = press blocked_base (`ASCII ' ') in
  require (blocked_cmd.overlay = Commands 0) "blocked-commands-opened";
  let blocked_today = press (press blocked_cmd (`Arrow `Down)) `Enter in
  require (blocked_today.overlay = No_overlay) "blocked-cmd-today-overlay-closed";
  require (blocked_today.form.day = "2026-10-09") "blocked-cmd-today-no-change-day";
  require (blocked_today.form.amount = "1,000") "blocked-cmd-today-retains-amount";
  require (blocked_today.blocked = true) "blocked-cmd-today-stays-blocked";
  require (blocked_today.message = "保存試行の未確認情報があります。書込み停止。") "blocked-cmd-today-retains-message";

  (* blocked中のコマンドパレット Date_prev_day: 日付も下書きも変更されないこと *)
  let blocked_prev = press (press (press (press blocked_base (`ASCII ' ')) (`Arrow `Down)) (`Arrow `Down)) `Enter in
  require (blocked_prev.overlay = No_overlay) "blocked-cmd-prev-overlay-closed";
  require (blocked_prev.form.day = "2026-10-09") "blocked-cmd-prev-no-change-day";
  require (blocked_prev.form.amount = "1,000") "blocked-cmd-prev-retains-amount";
  require (blocked_prev.blocked = true) "blocked-cmd-prev-stays-blocked";
  require (blocked_prev.message = "保存試行の未確認情報があります。書込み停止。") "blocked-cmd-prev-retains-message";

  (* blocked中のコマンドパレット Date_next_day: 日付も下書きも変更されないこと *)
  let blocked_next = press (press (press (press (press blocked_base (`ASCII ' ')) (`Arrow `Down)) (`Arrow `Down)) (`Arrow `Down)) `Enter in
  require (blocked_next.overlay = No_overlay) "blocked-cmd-next-overlay-closed";
  require (blocked_next.form.day = "2026-10-09") "blocked-cmd-next-no-change-day";
  require (blocked_next.form.amount = "1,000") "blocked-cmd-next-retains-amount";
  require (blocked_next.blocked = true) "blocked-cmd-next-stays-blocked";
  require (blocked_next.message = "保存試行の未確認情報があります。書込み停止。") "blocked-cmd-next-retains-message";

  (* 11. 不正日付からの前日・翌日操作の拒否と下書き完全保持 *)
  let invalid_date_state =
    {
      base with
      form = { base.form with day = "2026-02-29"; amount = "1,000"; memo = "draft-memo"; from_locus = "wallet"; to_locus = "food" };
      focus = Date;
    }
  in
  (* 前日操作: 今日の日付で代用せず、操作拒否、元の "2026-02-29" と全下書きを保持し、日付欄修正を案内 *)
  let inv_prev = press (press (press (press invalid_date_state (`ASCII ' ')) (`Arrow `Down)) (`Arrow `Down)) `Enter in
  require (inv_prev.overlay = No_overlay) "inv-prev-overlay-closed";
  require (inv_prev.form.day = "2026-02-29") "inv-prev-retains-raw-invalid-day";
  require (inv_prev.form.amount = "1,000") "inv-prev-retains-amount";
  require (inv_prev.form.memo = "draft-memo") "inv-prev-retains-memo";
  require (inv_prev.form.from_locus = "wallet" && inv_prev.form.to_locus = "food") "inv-prev-retains-loci";
  require (Base.String.is_substring inv_prev.message ~substring:"日付の形式が不正なため移動できません") "inv-prev-message-guidance";
  require (Base.String.is_substring inv_prev.message ~substring:"2026-02-29") "inv-prev-message-raw-echo";
  require (Base.String.is_substring inv_prev.message ~substring:"日付欄 (YYYY-MM-DD) を修正") "inv-prev-message-fix-hint";

  (* 翌日操作: 同様に今日で代用せず拒否し、下書き保持 *)
  let inv_next = press (press (press (press (press invalid_date_state (`ASCII ' ')) (`Arrow `Down)) (`Arrow `Down)) (`Arrow `Down)) `Enter in
  require (inv_next.overlay = No_overlay) "inv-next-overlay-closed";
  require (inv_next.form.day = "2026-02-29") "inv-next-retains-raw-invalid-day";
  require (inv_next.form.amount = "1,000") "inv-next-retains-amount";
  require (inv_next.form.memo = "draft-memo") "inv-next-retains-memo";
  require (Base.String.is_substring inv_next.message ~substring:"日付の形式が不正なため移動できません") "inv-next-message-guidance";

  (* 12. 空の日付の扱い: 空欄は今日 (F.today ()) を基準として前日・翌日に移動 *)
  let empty_date_base =
    {
      base with
      form = { base.form with day = ""; amount = "500"; memo = "empty-day-memo" };
      focus = Date;
    }
  in
  let empty_prev = press (press (press (press empty_date_base (`ASCII ' ')) (`Arrow `Down)) (`Arrow `Down)) `Enter in
  let expected_yesterday =
    match A.shift_calendar_day (F.today ()) (-1) with Ok d -> d | Error _ -> failwith "today-shift-fail"
  in
  require (empty_prev.form.day = expected_yesterday) "empty-day-prev-shifts-from-today";
  require (empty_prev.form.amount = "500") "empty-day-prev-retains-amount";

  let empty_next = press (press (press (press (press empty_date_base (`ASCII ' ')) (`Arrow `Down)) (`Arrow `Down)) (`Arrow `Down)) `Enter in
  let expected_tomorrow =
    match A.shift_calendar_day (F.today ()) 1 with Ok d -> d | Error _ -> failwith "today-shift-fail"
  in
  require (empty_next.form.day = expected_tomorrow) "empty-day-next-shifts-from-today";
  require (empty_next.form.amount = "500") "empty-day-next-retains-amount";

  (* 13. 限界値 0001-01-01 と 9999-12-31 の範囲外移動拒否と下書き保持 *)
  require (A.shift_calendar_day "0001-01-01" (-1) = Error "date-out-of-range") "min-date-shift-unit-refused";
  require (A.shift_calendar_day "9999-12-31" 1 = Error "date-out-of-range") "max-date-shift-unit-refused";

  let min_date_state =
    {
      base with
      form = { base.form with day = "0001-01-01"; amount = "2,000"; memo = "min-date-memo" };
      focus = Date;
    }
  in
  let min_prev = press (press (press (press min_date_state (`ASCII ' ')) (`Arrow `Down)) (`Arrow `Down)) `Enter in
  require (min_prev.overlay = No_overlay) "min-prev-overlay-closed";
  require (min_prev.form.day = "0001-01-01") "min-prev-retains-day";
  require (min_prev.form.amount = "2,000") "min-prev-retains-amount";
  require (min_prev.form.memo = "min-date-memo") "min-prev-retains-memo";
  require (Base.String.is_substring min_prev.message ~substring:"許容範囲 (0001-01-01 〜 9999-12-31)") "min-prev-range-message";

  let max_date_state =
    {
      base with
      form = { base.form with day = "9999-12-31"; amount = "3,000"; memo = "max-date-memo" };
      focus = Date;
    }
  in
  let max_next = press (press (press (press (press max_date_state (`ASCII ' ')) (`Arrow `Down)) (`Arrow `Down)) (`Arrow `Down)) `Enter in
  require (max_next.overlay = No_overlay) "max-next-overlay-closed";
  require (max_next.form.day = "9999-12-31") "max-next-retains-day";
  require (max_next.form.amount = "3,000") "max-next-retains-amount";
  require (max_next.form.memo = "max-date-memo") "max-next-retains-memo";
  require (Base.String.is_substring max_next.message ~substring:"許容範囲 (0001-01-01 〜 9999-12-31)") "max-next-range-message";

  (* 14. 性能退行チェック: 1,000回の正規化・パースループが数ミリ秒以内で完了すること *)
  let t0 = Unix.gettimeofday () in
  for _ = 1 to 1000 do
    ignore (A.normalize_date "２０２６／１／９");
    ignore (B.parse_amount base.session.book "jpy" "１，２３４，５６７");
    ignore (B.parse_amount base.session.book "eur" "１，２３４．５６");
    ignore (A.shift_calendar_day "2026-10-09" 1);
  done;
  let elapsed = Unix.gettimeofday () -. t0 in
  require (elapsed < 0.2) "flexible-input-performance-no-regression";

  print_endline
    "PASS: flexible amount (commas, full-width, fractional, precision), flexible date \
     (separators, leap/end-of-month/year, draft retention), date shortcuts (today 't', prev/next \
     commands) and exact quanta persistence."

let posting_self_check ~directory ~base =
  let require = F.require in
  let submit s = confirm (submit s) in
  let step s input =
    match handle s input with Some s -> s | None -> raise (F.Refused "posting-unexpected-exit")
  in
  let press s button = step s (`Key (button, [])) in
  let ctrl s c = step s (`Key (`ASCII c, [ `Ctrl ])) in
  let text s value =
    Uutf.String.fold_utf_8
      (fun s _ -> function `Uchar c -> press s (`Uchar c) | `Malformed _ -> s)
      s value
  in
  let editor s =
    match s.postings with Some e -> e | None -> raise (F.Refused "posting-editor-missing")
  in
  let effect_ ?key locus n =
    D.Effect.create
      ~key:(Option.map (fun key -> get_id (D.Identifier.Effect_key.of_string key)) key)
      ~locus:(get_id (D.Identifier.Locus.of_string locus))
      ~measure:(get_id (D.Identifier.Measure.of_string "jpy"))
      ~quantity:(D.Quantity.of_quanta (Z.of_int n))
  in
  let paid_plan : B.plan =
    {
      id = "paid-plan";
      day = "2026-11-01";
      measure = "jpy";
      changes = [ ("wallet", Z.of_int (-120)); ("food", Z.of_int 120) ];
      paid_by = None;
      cancelled_on = None;
    }
  in
  let split_plan =
    {
      paid_plan with
      id = "split-plan";
      day = "2026-12-11";
      changes = [ ("wallet", Z.of_int (-300)); ("food", Z.of_int 200); ("bank", Z.of_int 100) ];
    }
  in
  let keyed : B.entry =
    {
      id = "keyed-split";
      day = "2026-11-02";
      memo = Some "";
      effects =
        [
          effect_ ~key:" debit key " "wallet" (-120);
          effect_ ~key:"food-one" "food" 30;
          effect_ "food" 90;
        ];
      reversal_of = None;
      exchange = None;
    }
  in
  let book = get (B.put_plan base.session.book ~replace:false paid_plan) in
  let book = get (B.put_entry book ~replace:false keyed ~plan:(Some paid_plan.id)) in
  let book = get (B.put_plan book ~replace:false split_plan) in
  let path = directory ^ "/postings.sexp" in
  F.write_new path (B.to_string book);
  let base = initial ~config_home:directory (F.load path) in
  let base =
    { base with form = { base.form with amount = "300"; day = "2026-11-03"; memo = "架空の分割" } }
  in
  let bytes = F.read path in
  let files () = Sys.readdir directory |> Array.to_list |> List.sort String.compare in
  let before_files = files () in
  let opened = ctrl base 'T' in
  require
    (editor_visible opened && opened.form = base.form && List.length (editor opened).draft.rows = 2)
    "posting-open-preserved-basic-draft";
  let held = press opened `Escape in
  let accidental = ctrl (press held `Enter) 'S' in
  require
    ((not (editor_visible held)) && accidental.postings = held.postings && F.read path = bytes)
    "posting-hidden-enter-saved-or-lost";
  let resumed = ctrl held 't' in
  require (resumed.postings = opened.postings) "posting-resume-lost-focus-or-rows";
  let themed = press (press (press (press opened (`ASCII ' ')) `Enter) `Escape) `Escape in
  require
    (themed.postings = opened.postings && themed.theme = opened.theme)
    "posting-theme-lost-draft";
  let added = ctrl opened 'a' in
  require
    (List.length (editor added).draft.rows = 3
    && R.residual added.session.book (editor added).draft <> Ok Z.zero)
    "posting-blank-row-became-zero";
  let removed = ctrl added 'd' in
  require ((editor removed).draft = (editor opened).draft) "posting-add-remove-mutated-other-rows";
  let picker = press added `Enter in
  let swallowed = ctrl (ctrl picker 's') 'n' in
  require
    (swallowed.postings = picker.postings && swallowed.session == picker.session)
    "posting-picker-published-or-cleared";
  let picked = press (text picker "BaNk") `Enter in
  require
    ((List.nth (editor picked).draft.rows 2).locus = "bank"
    && (editor picked).field = Posting_locus
    && picked.overlay = No_overlay)
    "posting-picker-target-or-focus";
  let candidate = text (press (press picked `Tab) `Tab) "100" in
  let candidate = text (ctrl (press candidate (`Arrow `Up)) 'u') "200" in
  require
    (get (R.residual candidate.session.book (editor candidate).draft) = Z.zero)
    "posting-exact-residual";
  let candidate = press candidate (`Arrow `Up) in
  let entered = press candidate `Enter in
  require (entered.session == candidate.session && F.read path = bytes) "posting-enter-published";
  let bad_paste =
    List.fold_left step candidate
      [
        `Paste `Start;
        `Key (`ASCII '9', []);
        `Key (`ASCII 'S', [ `Ctrl ]);
        `Key (`Enter, []);
        `Paste `End;
      ]
  in
  require
    ((editor bad_paste).draft = (editor candidate).draft && F.read path = bytes)
    "posting-paste-invoked-save";
  let pasted =
    List.fold_left step (ctrl candidate 'u')
      [
        `Paste `Start;
        `Key (`ASCII '3', []);
        `Key (`ASCII '0', []);
        `Key (`ASCII '0', []);
        `Paste `End;
      ]
  in
  require ((editor pasted).draft = (editor candidate).draft) "posting-single-line-amount-paste";
  List.iter
    (fun state ->
      let failed = ctrl state 's' in
      require
        ((editor failed).draft = (editor state).draft
        && F.read path = bytes
        && files () = before_files)
        "posting-invalid-input-wrote-or-lost")
    [
      set_field candidate "301";
      set_field candidate "0";
      set_field candidate "";
      set_field candidate "1.001";
      { candidate with form = { candidate.form with day = "2026-02-30" } };
      update_posting_row candidate (fun row -> { row with locus = "not-approved" });
      update_posting_row candidate (fun row -> { row with locus = "" });
    ];
  let preview = ctrl candidate 's' in
  require
    (F.read path = bytes && files () = before_files && preview.postings = candidate.postings)
    "posting-preview-published-or-lost";
  let saved = confirm preview in
  require
    (saved.postings = None
    && List.length (B.entries (F.load path).book) = 2
    && quantity saved "wallet" = "580"
    && quantity saved "bank" = "不明")
    "posting-save-cold-quantity";
  let recorded = List.hd (entries saved) in
  require
    (recorded.day = base.form.day
    && recorded.memo = Some base.form.memo
    && List.map quanta recorded.effects = List.map Z.of_int [ -300; 200; 100 ])
    "posting-split-cold-fields";
  let editing = ctrl { (initial ~config_home:directory (F.load path)) with selected = 1 } 'e' in
  let e = editor editing in
  require
    (e.draft.rows |> List.map (fun (row : R.row) -> row.key) = List.map D.Effect.key keyed.effects)
    "posting-existing-keys-lost-at-open";
  List.iter
    (fun changed ->
      require ((editor changed).draft = e.draft) "posting-edit-structure-or-sign-changed")
    [
      ctrl editing 'a';
      ctrl editing 'd';
      press (update_editor editing (fun e -> { e with field = Posting_sign })) (`Arrow `Right);
      press
        (text
           (press (update_editor editing (fun e -> { e with field = Posting_locus })) `Enter)
           "bank")
        `Enter;
    ];
  let changed = text (ctrl editing 'u') "150" in
  let changed = text (ctrl (press changed (`Arrow `Down)) 'u') "50" in
  let changed = text (ctrl (press changed (`Arrow `Down)) 'u') "100" in
  let changed = { changed with form = { changed.form with day = "2026-11-04" } } in
  let edited = confirm (ctrl changed 's') in
  let cold = (F.load path).book in
  let corrected = List.find (fun (row : B.entry) -> row.id = keyed.id) (B.entries cold) in
  let identity p =
    (D.Effect.key p, lstr (D.Effect.locus p), mstr (D.Effect.measure p), Z.sign (quanta p))
  in
  require
    (List.map identity corrected.effects = List.map identity keyed.effects
    && List.map quanta corrected.effects = List.map Z.of_int [ -150; 50; 100 ]
    && corrected.memo = Some "" && corrected.day = changed.form.day
    && corrected.exchange = keyed.exchange
    && corrected.reversal_of = keyed.reversal_of
    && (List.hd (B.plans cold)).paid_by = Some keyed.id
    && List.length (B.entries cold) = 2)
    "posting-edit-lost-identity-multiplicity-memo-or-payment-link";
  let backups =
    Sys.readdir directory |> Array.to_list
    |> List.filter (String.starts_with ~prefix:"postings.sexp.before-")
  in
  require
    (List.exists
       (fun name ->
         let book = get (B.of_string (F.read (directory ^ "/" ^ name))) in
         List.exists
           (fun (row : B.entry) ->
             row.id = keyed.id && List.map quanta row.effects = List.map quanta keyed.effects)
           (B.entries book))
       backups)
    "posting-pre-edit-backup-missing";
  let payment =
    press (press { edited with view = Plans; focus = History; selected = 1 } `Enter) `Enter
  in
  require
    (editor_visible payment && payment.mode = Pay split_plan.id
    && List.length (editor payment).draft.rows = 3)
    "posting-multiple-plan-payment-open";
  let paid =
    confirm
      (ctrl { payment with form = { payment.form with day = "2026-11-07"; memo = "架空の支払い" } } 's')
  in
  let cold = (F.load path).book in
  let plan = List.nth (B.plans cold) 1 in
  let actual = List.hd (entries paid) in
  require
    (plan.paid_by = Some actual.id && plan.day = split_plan.day && plan.changes = split_plan.changes
   && actual.day = "2026-11-07"
    && actual.memo = Some "架空の支払い"
    && List.length actual.effects = 3)
    "posting-payment-link-or-scheduled-evidence-lost";
  require
    ((pay_selected { paid with view = Plans; selected = 1 }).postings = None)
    "posting-paid-plan-reused";
  let stale = ctrl { (initial ~config_home:directory (F.load path)) with form = base.form } 't' in
  let other =
    submit
      { (initial ~config_home:directory (F.load path)) with form = { base.form with amount = "1" } }
  in
  let conflict = confirm (ctrl stale 's') in
  require
    (conflict.blocked
    && conflict.postings = stale.postings
    && (F.load path).bytes = other.session.bytes)
    "posting-conflict-lost-draft-or-overwrote";
  let frozen = List.fold_left (fun state c -> ctrl state c) conflict [ 'a'; 'd'; 'u'; 's' ] in
  let frozen = text frozen "999" in
  require
    (frozen.postings = conflict.postings && frozen.message = conflict.message)
    "posting-blocked-draft-not-frozen";
  let stale_edit = entry_form other (List.hd (entries other)) |> open_postings in
  ignore (submit { other with form = { base.form with amount = "2" } });
  let refreshed = ctrl stale_edit 'r' in
  require
    (refreshed.blocked && refreshed.postings = stale_edit.postings)
    "posting-stale-edit-reload-authorized";
  let uncertain =
    { stale with blocked = true; pending = Some (A.Unspecified_evidence "unconfirmed"); message = "household-warning" }
  in
  let frozen = ctrl (set_field uncertain "999") 's' in
  require
    (frozen.postings = uncertain.postings
    && frozen.pending = uncertain.pending
    && frozen.message = uncertain.message)
    "posting-uncertain-write-retried-or-lost";
  List.iter
    (fun state ->
      let pasted =
        List.fold_left step state
          [ `Paste `Start; `Key (`ASCII 'S', [ `Ctrl ]); `Key (`Enter, []); `Paste `End ]
      in
      require
        ((editor pasted).draft = (editor state).draft
        && pasted.pending = state.pending && pasted.message = state.message)
        "posting-hidden-or-active-paste-concealed-household-warning")
    [ uncertain; press uncertain `Escape ];
  require ((ctrl uncertain 'n').postings = None) "posting-explicit-discard-failed";
  let huge = "123456789012345678901234567890.12" in
  let euro : R.t =
    {
      measure = "eur";
      rows =
        [
          { R.key = None; locus = "wallet"; negative = true; amount = huge };
          { R.key = None; locus = "food"; negative = false; amount = huge };
        ];
    }
  in
  require
    (R.residual base.session.book euro = Ok Z.zero
    && List.map quanta (get (R.effects base.session.book euro))
       = [
           Z.neg (Z.of_string "12345678901234567890123456789012");
           Z.of_string "12345678901234567890123456789012";
         ])
    "posting-huge-exact-foreign-quantity";
  require
    (R.residual base.session.book
       { euro with rows = List.map (fun (row : R.row) -> { row with amount = "1.001" }) euro.rows }
    <> Ok Z.zero)
    "posting-rounded-foreign-input";
  require
    (R.of_effects base.session.book
       [
         List.hd keyed.effects;
         D.Effect.create ~key:None
           ~locus:(get_id (D.Identifier.Locus.of_string "food"))
           ~measure:(get_id (D.Identifier.Measure.of_string "eur"))
           ~quantity:(D.Quantity.of_quanta (Z.of_int 120));
       ]
    = Error "single-measure-movement-required")
    "posting-mixed-measures-cancelled";
  List.iter
    (fun entry ->
      let refused = entry_form base entry in
      require
        (refused.postings = None && refused.mode = New && refused.form = base.form)
        "posting-unsupported-relation-was-stripped")
    [ { keyed with exchange = Some ("a", "b") }; { keyed with reversal_of = Some "original" } ];
  let long = List.fold_left (fun s _ -> ctrl s 'a') opened (List.init 20 Fun.id) in
  require
    (List.length (editor long).draft.rows = 22
    && (editor (press long `End)).row = 21
    && (editor (press long `Home)).row = 0)
    "posting-six-row-cap-or-scroll-loss";
  print_endline
    "PASS: shared multiple postings, exact residual/foreign input, row picker, hold/resume/paste, \
     checked save/cold edit/keys/payment/backups and conflict/uncertain guards."

let self_check () =
  let require p why = F.require p why in
  let submit s = confirm (submit s) in
  let directory = "scratch/daily-tui-check-" ^ F.new_id () in
  Unix.mkdir directory 0o700;
  let path = directory ^ "/book.sexp" in
  F.create_copy ~source:"examples/daily-book.sexp" ~target:path;
  let s = initial ~config_home:directory (F.load path) in
  require (quantity s "wallet" = "1000" && quantity s "bank" = "不明") "initial-quantity";
  let before = F.read path in
  let invalid = submit { s with form = { s.form with amount = "0" } } in
  require (F.read path = before && invalid.form.amount = "0") "invalid-wrote-or-lost-draft";
  let s =
    submit { s with form = { s.form with day = "2026-10-03"; amount = "100"; memo = "架空の記帳" } }
  in
  require (quantity s "wallet" = "900" && List.length (B.entries s.session.book) = 1) "append";
  let reopened = initial ~config_home:directory (F.load path) in
  let s = edit_selected reopened in
  let s =
    submit { s with form = { s.form with day = "2026-09-01"; amount = "150"; memo = "架空の編集" } }
  in
  require
    (quantity s "wallet" = "850" && List.length (B.entries s.session.book) = 1)
    "replacement-not-history";
  let backups =
    Sys.readdir directory |> Array.to_list
    |> List.filter (fun name -> String.starts_with ~prefix:"book.sexp.before-" name)
  in
  require
    (List.exists
       (fun name ->
         match B.of_string (F.read (directory ^ "/" ^ name)) with
         | Error _ -> false
         | Ok book -> List.exists (fun (e : B.entry) -> e.memo = Some "架空の記帳") (B.entries book))
       backups)
    "before-edit-backup";
  let s = pay_selected { s with view = Plans; focus = History; selected = 0 } in
  let s = submit { s with form = { s.form with day = "2026-10-07"; memo = "架空の支払い" } } in
  require
    (quantity s "wallet" = "650" && (List.hd (B.plans s.session.book)).paid_by <> None)
    "plan-payment";
  let s = submit { s with adding = Some "日用品" } in
  require
    (quantity s "日用品" = "不明" && List.length (B.entries s.session.book) = 2)
    "category-invented-zero";
  let stale = initial ~config_home:directory (F.load path) in
  let latest = submit { stale with form = { stale.form with amount = "1"; memo = "架空の別更新" } } in
  let conflict = submit { stale with form = { stale.form with amount = "2"; memo = "架空の競合" } } in
  require
    (conflict.blocked && conflict.form.amount = "2" && (F.load path).bytes = latest.session.bytes)
    "conflict";
  let editing = edit_selected latest in
  let next_write =
    submit
      {
        (initial ~config_home:directory (F.load path)) with
        form = { stale.form with amount = "1" };
      }
  in
  let refreshed = reload editing in
  require
    (refreshed.blocked && refreshed.form = editing.form
    && refreshed.session.bytes = next_write.session.bytes)
    "stale-edit-after-refresh";
  let pasted =
    get (match handle s (`Paste `Start) with Some s -> Ok s | None -> Error "paste-start")
  in
  let pasted =
    get
      (match handle pasted (`Key (`Enter, [])) with Some s -> Ok s | None -> Error "paste-enter")
  in
  let pasted =
    get (match handle pasted (`Paste `End) with Some s -> Ok s | None -> Error "paste-end")
  in
  require
    (pasted.session.bytes = s.session.bytes && pasted.form = s.form && pasted.paste = None)
    "paste-submitted";
  List.iter
    (fun view ->
      let lines =
        screen ~frontend:"check" (100, 25) { s with view; focus = History; selected = 0 }
      in
      require
        (match List.filter (fun (style, _) -> style = Active) lines with
        | [ (_, heading); (_, row) ] ->
            String.starts_with ~prefix:"> 閲覧" heading && String.starts_with ~prefix:"> " row
        | [] | _ :: _ -> false)
        "history-focus-marker")
    [ Entries; Plans ];
  let plan_path = directory ^ "/plans.sexp" in
  F.create_copy ~source:"examples/daily-book.sexp" ~target:plan_path;
  let plan_state = initial ~config_home:directory (F.load plan_path) in
  let extra : B.plan =
    {
      id = "extra";
      day = "2026-11-01";
      measure = "jpy";
      changes = [ ("wallet", Z.of_int (-300)); ("food", Z.of_int 100); ("bank", Z.of_int 200) ];
      paid_by = None;
      cancelled_on = None;
    }
  in
  let created = finish plan_state (get (B.put_plan plan_state.session.book ~replace:false extra)) in
  require (List.length (B.plans (F.load plan_path).book) = 2) "plan-create-cold-read";
  let changed = { extra with day = "2026-11-02" } in
  let updated = finish created (get (B.put_plan created.session.book ~replace:true changed)) in
  require ((List.nth (B.plans (F.load plan_path).book) 1).day = changed.day) "plan-update-cold-read";
  let cancelled =
    finish updated (get (B.cancel_plan updated.session.book ~id:"planned-food" ~day:"2026-10-07"))
  in
  let cancelled = { cancelled with view = Plans; selected = 0 } in
  require
    ((List.hd (B.plans (F.load plan_path).book)).cancelled_on = Some "2026-10-07"
    && quantity cancelled "wallet" = "1000")
    "plan-cancel-cold-read";
  let refused_payment = pay_selected cancelled in
  require
    (refused_payment.form = cancelled.form
    && refused_payment.mode = cancelled.mode
    && refused_payment.message = "この予定は取消済みです。")
    "cancelled-plan-payment-draft";
  require
    (List.exists
       (fun text -> String.starts_with ~prefix:"2026-10-10 [取消 2026-10-07] " text)
       (history cancelled))
    "cancelled-plan-display";
  let budget : B.budget =
    {
      id = "trial-budget";
      start_day = "2026-10-01";
      end_exclusive = "2026-12-01";
      measure = "jpy";
      allocations = [ ("daily", Z.of_int 2000); ("reserve", Z.zero) ];
      expense_loci = [ "food" ];
      actual_routes = [ ("food", Some "daily") ];
      plan_routes = [ ("extra", "food", Some "daily") ];
    }
  in
  let budgeted =
    finish cancelled (get (B.put_budget cancelled.session.book ~replace:false budget))
  in
  let budget_answer =
    get (B.budget_review (F.load plan_path).book ~id:budget.id ~observed_at:"2026-10-07")
  in
  require
    (Z.equal (List.hd budget_answer.rows).after_known (Z.of_int 1900))
    "budget-create-cold-read";
  let rebalanced =
    finish budgeted
      (get
         (B.rebalance_budget budgeted.session.book ~id:budget.id ~from_purpose:"daily"
            ~to_purpose:"reserve" ~amount:(Z.of_int 200)))
  in
  let answer =
    get (B.budget_review (F.load plan_path).book ~id:budget.id ~observed_at:"2026-10-07")
  in
  require
    (Z.equal (List.hd answer.rows).after_known (Z.of_int 1700)
    && Z.equal (List.nth answer.rows 1).allocated (Z.of_int 200)
    && quantity rebalanced "wallet" = "1000")
    "budget-rebalance-cold-read";
  require (backspace "あい" = "あ") "unicode-backspace";
  require
    (match key s (`ASCII 'Q', [ `Ctrl ]) with None -> true | Some _ -> false)
    "provider-control-quit";
  require
    (match key s (`ASCII 'N', [ `Ctrl ]) with
    | None -> false
    | Some s -> s.form.amount = "" && s.focus = Source)
    "provider-control-new";
  (* UI contrast only; never a household quantity or accounting calculation. *)
  let luminance (color : P.color) =
    let linear channel =
      let value = float_of_int channel /. 255. in
      if value <= 0.04045 then value /. 12.92 else ((value +. 0.055) /. 1.055) ** 2.4
    in
    (0.2126 *. linear color.r) +. (0.7152 *. linear color.g) +. (0.0722 *. linear color.b)
  in
  List.iter
    (fun theme ->
      match P.palette theme with
      | None -> ()
      | Some palette ->
          List.iter
            (fun (foreground, background) ->
              let first = luminance foreground and second = luminance background in
              require
                ((max first second +. 0.05) /. (min first second +. 0.05) >= 4.5)
                "theme-text-contrast")
            [
              (palette.foreground, palette.background);
              (palette.heading, palette.background);
              (palette.status, palette.background);
              (palette.panel_foreground, palette.panel_background);
              (palette.accent, palette.panel_background);
              (palette.selected_foreground, palette.selected_background);
            ])
    P.all_themes;
  let homes bakhlo xdg home = P.home_from_environment ~bakhlo ~xdg ~home in
  require
    (homes (Some "bakhlo-config") (Some "xdg-config") (Some "home") = Some "bakhlo-config")
    "ui-config-bakhlo-priority";
  require
    (P.path ~config_home:directory () = Some (directory ^ "/ui-theme"))
    "ui-config-explicit-priority";
  List.iter
    (fun missing ->
      require
        (homes missing (Some "xdg-config") (Some "home") = Some "xdg-config/bakhlo")
        "ui-config-xdg-fallback";
      require
        (homes missing missing (Some "home") = Some "home/.config/bakhlo")
        "ui-config-home-fallback";
      require (homes missing missing missing = None) "ui-config-no-home")
    [ None; Some "" ];
  require
    (P.load_theme ~config_home:"" () = P.Terminal
    && P.save_theme ~config_home:"" P.Bakhlo_dark = Error "ui-config-home-unavailable")
    "ui-config-unavailable-fallback";
  let ui_home = directory ^ "/ui" in
  let themed = initial ~config_home:ui_home (F.load path) in
  let theme_book_bytes = F.read path and book_files = Sys.readdir directory in
  let step state input =
    match handle state input with Some next -> next | None -> raise (F.Refused "ui-event-exited")
  in
  let press state button = step state (`Key (button, [])) in
  let require_draft next why =
    require
      (next.session == themed.session && next.form = themed.form && next.focus = themed.focus
     && next.view = themed.view && next.selected = themed.selected && next.mode = themed.mode
     && next.blocked = themed.blocked && next.pending = themed.pending
     && next.adding = themed.adding && next.message = themed.message)
      why
  in
  List.iter
    (fun space ->
      List.iter
        (fun focus ->
          let opened = press { themed with focus } space in
          require (opened.overlay = Commands 0) "command-palette-space";
          let closed = press opened `Escape in
          require (closed.overlay = No_overlay && closed.focus = focus) "command-close-focus")
        [ Date; Currency; Source; Destination; Amount; History ];
      let memo = { themed with focus = Memo; form = { themed.form with memo = "a" } } in
      let memo = press memo space in
      require (memo.form.memo = "a " && memo.overlay = No_overlay) "memo-space-is-text";
      let adding = press { themed with adding = Some "new" } space in
      require (adding.adding = Some "new " && adding.overlay = No_overlay) "locus-space-is-text")
    [ `ASCII ' '; `Uchar (Uchar.of_int 0x20) ];
  let commands = press themed (`ASCII ' ') in
  let swallowed =
    List.fold_left step commands
      [
        `Key (`ASCII 'x', []);
        `Key (`Tab, []);
        `Key (`ASCII 'N', [ `Ctrl ]);
        `Key (`ASCII 'A', [ `Ctrl ]);
        `Paste `Start;
        `Key (`ASCII ' ', []);
        `Key (`Enter, []);
        `Key (`Arrow `Down, []);
        `Paste `End;
      ]
  in
  require_draft swallowed "overlay-keys-and-paste-leaked";
  require
    (swallowed.overlay = commands.overlay
    && swallowed.paste = None && swallowed.theme = commands.theme
    && swallowed.message = commands.message)
    "overlay-paste-invoked-command";
  let themes = press commands `Enter in
  require (themes.overlay = Themes { selected = 0; original = P.Terminal }) "theme-selector-open";
  let light = press themes (`Arrow `Down) in
  require
    (light.theme = P.Bakhlo_light && P.load_theme ~config_home:ui_home () = P.Terminal)
    "theme-live-preview-not-saved";
  let cancelled = press light `Escape in
  require (cancelled.theme = P.Terminal && cancelled.overlay = Commands 0) "theme-preview-cancel";
  let themes = press cancelled `Enter in
  let dark = press (press themes (`Arrow `Down)) (`Arrow `Down) in
  let saved = press dark `Enter in
  require
    (saved.theme = P.Bakhlo_dark && saved.overlay = No_overlay
    && (initial ~config_home:ui_home (F.load path)).theme = P.Bakhlo_dark
    && F.read (ui_home ^ "/ui-theme") = "bakhlo-dark\n")
    "theme-save-cold-read";
  require ((Unix.stat (ui_home ^ "/ui-theme")).st_perm = 0o600) "ui-theme-permissions";
  let light = press (press (press saved (`ASCII ' ')) `Enter) (`Arrow `Up) in
  require (light.theme = P.Bakhlo_light) "theme-reopen-selected-saved";
  let restored = press light `Escape in
  require
    (restored.theme = P.Bakhlo_dark && restored.overlay = Commands 0)
    "theme-cancel-nonterminal";
  List.iter
    (fun next -> require_draft next "theme-changed-household-state")
    [ commands; themes; light; cancelled; dark; saved; restored ];
  require
    (F.read path = theme_book_bytes
    && Sys.readdir directory |> Array.to_list
       |> List.filter (( <> ) "ui")
       |> List.sort String.compare
       = (Array.to_list book_files |> List.sort String.compare))
    "theme-published-household-bytes-or-artifacts";
  let invalid_home = directory ^ "/invalid-ui" in
  Unix.mkdir invalid_home 0o700;
  let invalid_path = invalid_home ^ "/ui-theme" in
  List.iter
    (fun bytes ->
      F.write_new invalid_path bytes;
      require (P.load_theme ~config_home:invalid_home () = P.Terminal) "invalid-theme-fallback";
      Unix.unlink invalid_path)
    [ ""; "unknown\n"; "bakhlo-dark\njunk\n"; String.make 1000 'x' ];
  Unix.mkdir invalid_path 0o700;
  require (P.load_theme ~config_home:invalid_home () = P.Terminal) "unreadable-theme-fallback";
  require
    (P.save_theme ~config_home:invalid_home P.Bakhlo_dark = Error "ui-theme-save-failed"
    && Sys.is_directory invalid_path
    && Array.to_list (Sys.readdir invalid_home) = [ "ui-theme" ])
    "failed-atomic-save-changed-target-or-left-temp";
  Unix.rmdir invalid_path;
  Unix.mkfifo invalid_path 0o600;
  require (P.load_theme ~config_home:invalid_home () = P.Terminal) "nonregular-theme-fallback";
  Unix.unlink invalid_path;
  List.iter
    (fun theme ->
      require (P.save_theme ~config_home:invalid_home theme = Ok ()) "atomic-theme-save";
      require
        (P.load_theme ~config_home:invalid_home () = theme
        && F.read invalid_path = P.theme_id theme ^ "\n"
        && Array.to_list (Sys.readdir invalid_home) = [ "ui-theme" ])
        "atomic-theme-replace-cold-read")
    P.all_themes;
  (* A regular file cannot be a config directory: deterministic even when run as root. *)
  let failed = { themed with config_home = Some path } in
  let failed = press (press (press (press failed (`ASCII ' ')) `Enter) (`Arrow `Up)) `Enter in
  require
    (failed.theme = P.Bakhlo_dark && failed.overlay = No_overlay && failed.ui_notice <> None
   && (not failed.blocked) && failed.pending = None
    && P.load_theme ~config_home:path () = P.Terminal
    && F.read path = theme_book_bytes)
    "ui-save-failure-is-not-household-failure";
  require_draft failed "ui-save-failure-lost-draft";
  let blocked =
    { themed with blocked = true; pending = Some (A.Unspecified_evidence "uncertain"); message = "household-conflict" }
  in
  let blocked = press (press (press blocked (`ASCII ' ')) `Enter) `Enter in
  require
    (blocked.blocked
    && blocked.pending = Some (A.Unspecified_evidence "uncertain")
    && blocked.message = "household-conflict"
    && blocked.ui_notice <> None)
    "theme-save-hid-household-warning";
  let blocked = press blocked (`ASCII ' ') in
  let rows = screen ~frontend:"check" (64, 20) blocked in
  require
    (List.length rows = 20 && List.nth rows 19 = (Status, "household-conflict"))
    "overlay-concealed-household-warning";
  let reset = step failed (`Key (`ASCII 'N', [ `Ctrl ])) in
  require (reset.theme = P.Bakhlo_dark) "unsaved-session-theme-lost-on-new";
  require (handle commands (`Key (`ASCII 'Q', [ `Ctrl ])) = None) "overlay-quit";
  let long_id = "long-" ^ String.concat "" (List.init 25 (fun _ -> "識別子")) in
  let ids =
    [ "wallet"; "food"; "bank"; "bank-two"; " Savings "; long_id; "case-id"; "CASE-ID" ]
    @ List.init 16 (fun n -> Printf.sprintf "item-%02d" n)
  in
  let label id =
    match id with
    | "wallet" -> "財布"
    | "food" -> "食費"
    | "bank" | "bank-two" -> "同名の口座"
    | " Savings " -> "積立 fund"
    | id when id = long_id -> String.concat "" (List.init 25 (fun _ -> "長い科目名")) ^ "🙂"
    | _ -> id
  in
  let fixture =
    "(bakhlo-daily 1)(scope corrected-entries explicit-plans)"
    ^ "(measures (measure jpy 0)(measure eur 2))" ^ "(labels (provided "
    ^ String.concat " "
        (List.map (fun id -> Printf.sprintf "(label %S %S synthetic)" id (label id)) ids)
    ^ "))(approved-loci (provided "
    ^ String.concat " " (List.map (Printf.sprintf "%S") ids)
    ^ "))(entries)(plans)(support (zero-origin (food jpy))(openings)"
    ^ "(observations (observation (reflected) (quantities (wallet jpy 1000)(wallet eur 10000))))"
    ^ "(presence (provided (reflected) (coordinates (bank-two jpy)))))"
  in
  let picker_path = directory ^ "/picker.sexp" in
  F.write_new picker_path (B.to_string (get (B.of_string fixture)));
  let base = initial ~config_home:directory (F.load picker_path) in
  let load_policy name policy =
    let path = directory ^ "/picker-" ^ name ^ ".sexp" in
    let bytes =
      Base.String.substr_replace_all fixture
        ~pattern:
          ("(approved-loci (provided "
          ^ String.concat " " (List.map (Printf.sprintf "%S") ids)
          ^ "))")
        ~with_:policy
    in
    F.write_new path (B.to_string (get (B.of_string bytes)));
    initial ~config_home:directory (F.load path)
  in
  let missing = load_policy "missing" "(approved-loci (not-supplied))"
  and empty = load_policy "empty" "(approved-loci (provided))" in
  let picker_bytes = F.read picker_path in
  let files_before = Sys.readdir directory |> Array.to_list |> List.sort String.compare in
  let same_context original next =
    next.session == original.session && next.focus = original.focus && next.view = original.view
    && next.selected = original.selected && next.mode == original.mode
    && next.blocked = original.blocked && next.pending = original.pending
    && next.adding = original.adding && next.message = original.message
    && next.theme = original.theme
    && next.ui_notice = original.ui_notice
    && next.postings = original.postings
  in
  let original = { base with focus = Source; form = { base.form with memo = "draft remains" } } in
  let opened = press original `Enter in
  require
    (opened.overlay = Loci { target = From_locus; query = ""; selected = 0; notice = None }
    && opened.form = original.form && same_context original opened)
    "picker-open-not-publish";
  let moved = press opened (`Arrow `Down) in
  require (moved.form = original.form && same_context original moved) "picker-arrow-mutated-draft";
  let cancelled = press moved `Escape in
  require
    (cancelled.overlay = No_overlay && cancelled.form = original.form
   && same_context original cancelled)
    "picker-cancel-lost-context";
  let search state text =
    Uutf.String.fold_utf_8
      (fun state _ -> function `Uchar c -> press state (`Uchar c) | `Malformed _ -> state)
      state text
  in
  require (locus_candidates base "BaNk" = [ "bank"; "bank-two" ]) "picker-id-case-search";
  require
    (locus_candidates base "同名" = [ "bank"; "bank-two" ])
    "picker-duplicate-label-distinct-ids";
  require (locus_candidates base "食費" = [ "food" ]) "picker-japanese-label-search";
  let case_choice = press (press (search opened "case-id") (`Arrow `Down)) `Enter in
  require
    (locus_candidates base "case-id" = [ "case-id"; "CASE-ID" ]
    && case_choice.form.from_locus = "CASE-ID")
    "picker-case-distinct-identities";
  require (locus_candidates base "積立 fund" = [ " Savings " ]) "picker-label-space-search";
  let searched = search opened "BANK" in
  let chosen = press (press searched (`Arrow `Down)) `Enter in
  require
    (chosen.overlay = No_overlay
    && chosen.form = { original.form with from_locus = "bank-two" }
    && same_context original chosen)
    "picker-selected-stable-id";
  let to_original = { original with focus = Destination } in
  let chosen = press (search (press to_original `Enter) "avings") `Enter in
  require
    (chosen.form = { to_original.form with to_locus = " Savings " }
    && same_context to_original chosen)
    "picker-to-locus-no-identity-trim";
  let chosen = press (search opened long_id) `Enter in
  require
    (chosen.form.from_locus = long_id && same_context original chosen)
    "picker-long-id-not-truncated";
  List.iter
    (fun space ->
      let state = press (search opened "積立") space in
      require
        (match state.overlay with Loci p -> p.query = "積立 " | _ -> false)
        "picker-space-is-query")
    [ `ASCII ' '; `Uchar (Uchar.of_int 0x20) ];
  let state = press (search opened "財布") `Backspace in
  require
    (match state.overlay with Loci p -> p.query = "財" | _ -> false)
    "picker-unicode-backspace";
  let state = step state (`Key (`ASCII 'U', [ `Ctrl ])) in
  require
    (match state.overlay with Loci p -> p.query = "" && p.selected = 0 | _ -> false)
    "picker-clear-search";
  let state = press (search opened "no-match") `Enter in
  require
    (state.form = original.form && picker_is_open state && same_context original state)
    "picker-no-match-enter-published";
  let state = press (press opened `End) (`Arrow `Down) in
  require
    (match state.overlay with Loci p -> p.selected = List.length ids - 1 | _ -> false)
    "picker-last-candidate";
  let state = press (press state `Home) (`Arrow `Up) in
  require
    (match state.overlay with Loci p -> p.selected = 0 | _ -> false)
    "picker-first-candidate";
  let pasted =
    List.fold_left step opened
      [
        `Paste `Start;
        `Key (`Uchar (Uchar.of_int 0x98df), []);
        `Key (`Uchar (Uchar.of_int 0x8cbb), []);
        `Paste `End;
      ]
  in
  require
    (match pasted.overlay with
    | Loci p -> p.query = "食費" && pasted.form = original.form
    | _ -> false)
    "picker-single-line-paste-search";
  let rejected =
    List.fold_left step opened
      [
        `Paste `Start;
        `Key (`ASCII 'x', []);
        `Key (`Enter, []);
        `Key (`Uchar (Uchar.of_int 10), []);
        `Paste `End;
      ]
  in
  require
    (match rejected.overlay with
    | Loci p ->
        p.query = "" && p.notice <> None && rejected.form = original.form
        && same_context original rejected
    | _ -> false)
    "picker-paste-control-published-or-leaked";
  let swallowed =
    List.fold_left step opened
      [
        `Key (`Tab, []);
        `Key (`ASCII 'A', [ `Ctrl ]);
        `Key (`ASCII 'N', [ `Ctrl ]);
        `Key (`ASCII 'R', [ `Ctrl ]);
      ]
  in
  require
    (swallowed.form = original.form && same_context original swallowed)
    "picker-modal-shortcuts-leaked";
  List.iter
    (fun original ->
      let browsed = search (press original `Enter) "BANK" in
      let attempted = press browsed `Enter in
      require
        (picker_is_open attempted && attempted.form = original.form
       && same_context original attempted)
        "picker-bypassed-amount-edit-blocked-guard")
    [
      { original with form = { original.form with amount = "1" } };
      { original with mode = Edit (List.hd (B.entries s.session.book)) };
      { original with blocked = true; pending = Some (A.Unspecified_evidence "uncertain"); message = "household-warning" };
    ];
  List.iter
    (fun base ->
      let opened = press { base with focus = Source } `Enter in
      require
        (locus_candidates opened "" = [] && (press opened `Enter).form = base.form)
        "picker-missing-or-empty-policy-invented-choice")
    [ missing; empty ];
  require
    (quantity base "wallet" = "1000"
    && quantity base "food" = "0"
    && quantity base "bank" = "不明"
    && quantity base "bank-two" = "存在あり・金額不明"
    && quantity { base with form = { base.form with measure = "eur" } } "wallet" = "100.00")
    "picker-quantity-unknown-zero-presence-currency";
  require
    (F.read picker_path = picker_bytes
    && Sys.readdir directory |> Array.to_list |> List.sort String.compare = files_before)
    "picker-published-household-bytes-or-artifacts";
  posting_self_check ~directory ~base;
  browser_slice_self_check ();
  split_form_self_check ~directory ~base;
  split_safety_self_check ~directory ~base;
  error_display_self_check ~directory ~base;
  flexible_input_self_check ~directory ~base;
  scheduled_browser_self_check ();
  home_three_tier_self_check ~directory ~base;
  floating_stability_self_check ~directory ~base;
  (* Return a deterministic Unicode/long-list renderer fixture. *)
  print_endline
    "PASS: synthetic shared record/reopen/edit, backups, plan lifecycle/payment, budget \
     publication, unknown, conflict/stale draft, focus markers, ASCII/Unicode Space, theme \
     preview/cancel/save/fallback, palette contrast, UI-only failure, locus picker and modal \
     paste.";
  { base with focus = History; theme = P.Terminal; overlay = No_overlay }
