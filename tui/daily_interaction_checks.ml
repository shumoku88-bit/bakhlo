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
            let model = { Br.view; entries_selected = selected; plans_selected = selected } in
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
  let rendered_texts = List.map snd lines_24 in
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

  (* インライン Locus catalog の展開検証 *)
  let s_src_focused = { s with focus = Split (Source_locus 0) } in
  let lines_cat = screen ~frontend:"check" (80, 24) s_src_focused in
  let rendered_cat = List.map snd lines_cat in
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
    [ None; Some "synthetic-unconfirmed" ];
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
    { stale with blocked = true; pending = Some "unconfirmed"; message = "household-warning" }
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
    { themed with blocked = true; pending = Some "uncertain"; message = "household-conflict" }
  in
  let blocked = press (press (press blocked (`ASCII ' ')) `Enter) `Enter in
  require
    (blocked.blocked
    && blocked.pending = Some "uncertain"
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
      { original with blocked = true; pending = Some "uncertain"; message = "household-warning" };
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
  (* Return a deterministic Unicode/long-list renderer fixture. *)
  print_endline
    "PASS: synthetic shared record/reopen/edit, backups, plan lifecycle/payment, budget \
     publication, unknown, conflict/stale draft, focus markers, ASCII/Unicode Space, theme \
     preview/cancel/save/fallback, palette contrast, UI-only failure, locus picker and modal \
     paste.";
  { base with theme = P.Terminal; overlay = No_overlay }
