(* Daily book overlay panes, review views, and modal panels. *)
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query
module P = Ui_preferences
module R = Posting_draft
module A = Daily_actions
module Pe = Posting_editor

type style = Plain | Active | Heading | Status | Panel | Panel_heading | Panel_active

let panel_width = 34

let utf8 c =
  let b = Buffer.create 4 in
  Uutf.Buffer.add_utf_8 b c;
  Buffer.contents b

let printable_uchar c =
  let n = Uchar.to_int c in
  n >= 32 && (n < 127 || n > 159)

let visible text =
  let b = Buffer.create (String.length text) in
  Uutf.String.fold_utf_8
    (fun () _ -> function
      | `Uchar c ->
          let n = Uchar.to_int c in
          if n < 32 || (n >= 127 && n <= 159) then Buffer.add_string b (Printf.sprintf "\\u%04x" n)
          else Uutf.Buffer.add_utf_8 b c
      | `Malformed bytes ->
          String.iter (fun c -> Buffer.add_string b (Printf.sprintf "\\x%02x" (Char.code c))) bytes)
    () text;
  Buffer.contents b

let clip_text ~width_of room value =
  let text = visible value in
  if room <= 0 then ""
  else if width_of text <= room then text
  else
    let _, prefix =
      Uutf.String.fold_utf_8
        (fun (stopped, prefix) _ -> function
          | `Uchar c when not stopped ->
              let next = prefix ^ utf8 c in
              if width_of next <= room - 1 then (false, next) else (true, prefix)
          | `Uchar _ | `Malformed _ -> (stopped, prefix))
        (false, "") text
    in
    prefix ^ "~"

let panel_line ?(width = panel_width) ~width_of style text =
  let room = max 0 (width - 4) in
  let text = clip_text ~width_of room text in
  let text = text ^ String.make (room - width_of text) ' ' in
  (style, "| " ^ text ^ " |")

let panel_border ?(width = panel_width) ~width_of title =
  let room = max 0 (width - 4) in
  let title = clip_text ~width_of room (" " ^ title ^ " ") in
  (Panel_heading, "+-" ^ title ^ String.make (room - width_of title) '-' ^ "-+")

let panel_bottom ?(width = panel_width) () = (Panel, "+" ^ String.make (max 0 (width - 2)) '-' ^ "+")

let wrap_text ~width_of room text =
  let lines, last =
    Uutf.String.fold_utf_8
      (fun (lines, current) _ -> function
        | `Malformed _ -> (lines, current)
        | `Uchar c ->
            let glyph = utf8 c in
            let next = current ^ glyph in
            if current = "" || width_of next <= room then (lines, next)
            else (current :: lines, glyph))
      ([], "") (visible text)
  in
  List.rev (last :: lines)

let review_page ~dimensions:(width, height) ~width_of lines scroll =
  let width = max 4 (min 76 (width - 4)) in
  let capacity = max 1 (height - 7) in
  let lines = List.concat_map (wrap_text ~width_of (max 1 (width - 4))) lines in
  let last = max 0 (List.length lines - capacity) in
  (width, capacity, lines, min last (max 0 scroll), last)

let quantity ~book ~measure locus =
  if locus = "" || measure = "" then "不明"
  else
    match (D.Identifier.Locus.of_string locus, D.Identifier.Measure.of_string measure) with
    | Ok locus_id, Ok measure_id -> (
        let coordinate : D.Effect_coordinate.t = { locus = locus_id; measure = measure_id } in
        match Q.query (B.image book) coordinate with
        | Error (Q.Support_unknown _) -> "不明"
        | Ok (Q.Known_present _) -> "存在あり・金額不明"
        | Ok (Q.Exact e) ->
            B.format book measure (D.Quantity.quanta (Q.quantity e)))
    | Error _, _ | _, Error _ -> "不明"

type command = Theme

let commands = [ Theme ]
let command_label = function Theme -> "Theme"

let theme_at n = match List.nth_opt P.all_themes n with Some theme -> theme | None -> P.Terminal

let theme_index theme =
  let rec loop n = function
    | [] -> 0
    | candidate :: _ when candidate = theme -> n
    | _ :: rest -> loop (n + 1) rest
  in
  loop 0 P.all_themes

let cycle_index length current step = if length = 0 then 0 else (current + step + length) mod length

type locus_target = From_locus | To_locus | Posting_locus_at of int

type locus_picker = {
  target : locus_target;
  query : string;
  selected : int;
  notice : string option;
}

let loci book = match B.approved_loci book with Some xs -> xs | None -> []

let locus_candidates book query =
  let query = String.lowercase_ascii query in
  let matches value = Base.String.is_substring (String.lowercase_ascii value) ~substring:query in
  List.filter (fun id -> matches id || matches (B.label book id)) (loci book)

type transaction = A.transaction = { entry : B.entry; replace : bool; plan : string option }

type overlay =
  | No_overlay
  | Commands of int
  | Themes of { selected : int; original : P.theme }
  | Loci of locus_picker
  | Preview of { transaction : transaction; base_bytes : string; scroll : int }
  | Detail of { entry : B.entry; scroll : int }
  | Plan_detail of { plan : B.plan; scroll : int }

let entry_lines book (entry : B.entry) =
  [
    "ID: " ^ entry.id;
    "日付: " ^ entry.day;
    ("メモ: " ^ match entry.memo with None -> "（未指定）" | Some text -> "[" ^ text ^ "]");
  ]
  @ List.concat
      (List.mapi
         (fun n p ->
           let locus = A.lstr (D.Effect.locus p) and measure = A.mstr (D.Effect.measure p) in
           [
             Printf.sprintf "行%d: %s [%s]" (n + 1) (B.label book locus) locus;
             ("  "
             ^ (if Z.sign (A.quanta p) > 0 then "+" else "")
             ^ B.format book measure (A.quanta p)
             ^ " " ^ measure ^ " / キー: "
             ^
             match D.Effect.key p with
             | None -> "（無名）"
             | Some key -> "[" ^ D.Identifier.Effect_key.to_string key ^ "]");
           ])
         entry.effects)
  @ (match entry.reversal_of with None -> [] | Some id -> [ "返金・取消の対象: " ^ id ])
  @ (match entry.exchange with None -> [] | Some (a, b) -> [ "両替の対応: " ^ a ^ " → " ^ b ])
  @ (B.plans book
    |> List.filter_map (fun (p : B.plan) ->
        if p.paid_by = Some entry.id then Some ("支払い対応: " ^ p.id ^ " / 予定日 " ^ p.day) else None))

let plan_lines book (plan : B.plan) =
  [
    "予定ID: " ^ plan.id;
    "予定日: " ^ plan.day;
    "通貨: " ^ plan.measure;
    (match (plan.cancelled_on, plan.paid_by) with
    | Some day, _ -> "取消日: " ^ day
    | None, Some id -> "支払い明細: " ^ id
    | None, None -> "未払い（Enterで支払い入力、まだ保存しません）");
  ]
  @ List.mapi
      (fun n (locus, amount) ->
        Printf.sprintf "行%d: %s [%s] / %s%s %s" (n + 1) (B.label book locus) locus
          (if Z.sign amount > 0 then "+" else "")
          (B.format book plan.measure amount)
          plan.measure)
      plan.changes

let preview_lines book (transaction : transaction) =
  (match transaction.plan with
    | Some id -> (
        [ "予定の支払い: " ^ id ^ "（実績と対応を同時に保存）" ]
        @
        match List.find_opt (fun (p : B.plan) -> p.id = id) (B.plans book) with
        | None -> []
        | Some p -> [ "元の予定日: " ^ p.day ^ "（変更しません）" ])
    | None -> [ (if transaction.replace then "既存明細の訂正（同じID）" else "新規記帳") ])
  @ entry_lines book transaction.entry

let posting_panel ~dimensions:(width, height) ~width_of ~book ~day ~memo ~blocked ~message (e : Pe.t) =
  let width = max 4 (min 76 (width - 4)) in
  let line = panel_line ~width ~width_of in
  let active field = if e.field = field then Panel_active else Panel in
  let slots = min 6 (max 1 (height - 14)) in
  let start = max 0 (e.row - slots + 1) in
  let row_focus =
    match e.field with
    | Pe.Posting_locus | Pe.Posting_sign | Pe.Posting_amount -> true
    | Pe.Posting_day | Pe.Posting_memo -> false
  in
  let rows =
    List.init slots (fun offset ->
        let n = start + offset in
        match List.nth_opt e.draft.rows n with
        | None -> line Panel (if e.draft.rows = [] && offset = 0 then "行なし: Ctrl-Aで追加" else "")
        | Some row ->
            line
              (if n = e.row && row_focus then Panel_active else Panel)
              ((if n = e.row then "> " else "  ")
              ^ Pe.line book n row e.draft.measure))
  in
  let chosen = List.nth_opt e.draft.rows e.row in
  let field_name = Pe.field_label e.field in
  [
    panel_border ~width ~width_of "複数posting下書き";
    line (active Pe.Posting_day) ("日付: " ^ day);
    line Panel ("通貨: " ^ e.draft.measure ^ "（固定・換算しません）");
    line (active Pe.Posting_memo) ("メモ: " ^ memo);
    line Panel
      (Printf.sprintf "行 %d / %d  欄: %s"
         (if e.draft.rows = [] then 0 else e.row + 1)
         (List.length e.draft.rows) field_name);
  ]
  @ rows
  @ [
      line Panel
        (match chosen with
        | None -> "ID: —"
        | Some row ->
            "ID: " ^ row.locus ^ " / 現在量: "
            ^ quantity ~book ~measure:e.draft.measure row.locus);
      line Panel
        ("キー: "
        ^
        match chosen with
        | None -> "—"
        | Some { R.key = None; _ } -> "未指定（無名posting）"
        | Some { R.key = Some key; _ } -> D.Identifier.Effect_key.to_string key);
      line Panel (Pe.status book e);
      line Panel (if blocked then message else Option.value ~default:message e.notice);
      line Panel "Tab:欄 ↑↓:行 Enter:科目/次欄 Ctrl-S:確認";
      line Panel "Ctrl-A:行追加 Ctrl-D:削除 Esc:閉じて保持";
      panel_bottom ~width ();
    ]

let overlay_screen ~dimensions:((width, height) as dimensions) ~width_of ~book ~day ~measure ~memo ~blocked ~editable ~can_choose_locus ~message ~has_draft ?postings overlay =
  let panel_line = panel_line ~width_of and panel_border = panel_border ~width_of in
  match overlay with
  | No_overlay -> (
      match postings with
      | Some e when e.Pe.visible ->
          Some (posting_panel ~dimensions ~width_of ~book ~day ~memo ~blocked ~message e)
      | Some _ | None -> None)
  | (Preview _ | Detail _ | Plan_detail _) as ov ->
      let title, lines, scroll, hint =
        match ov with
        | Preview p ->
            ( "取引全体の確認",
              preview_lines book p.transaction,
              p.scroll,
              "Ctrl-S:確定して保存  Esc:編集へ戻る" )
        | Detail d ->
            ("明細詳細（閲覧のみ）", entry_lines book d.entry, d.scroll, "Esc:一覧へ戻る（下書き保持）")
        | Plan_detail d ->
            ( "予定詳細",
              plan_lines book d.plan,
              d.scroll,
              if d.plan.paid_by <> None || d.plan.cancelled_on <> None then "Esc:一覧へ戻る（支払い不可）"
              else if blocked then "書込み停止中 / Esc:一覧へ戻る"
              else if has_draft then "下書き保持中 / Escで戻りCtrl-Nで破棄してから支払い"
              else "Enter:支払い入力へ（保存しません） Esc:一覧へ戻る" )
        | No_overlay | Commands _ | Themes _ | Loci _ -> assert false
      in
      let pane_width, capacity, lines, scroll, _ = review_page ~dimensions ~width_of lines scroll in
      let line = panel_line ~width:pane_width in
      if width < 32 || height < 10 then
        Some [ line Panel "端末を32桁×10行以上に広げてください"; line Panel "Esc:戻る / 保存しません" ]
      else
        Some
          ([ panel_border ~width:pane_width title ]
          @ (lines
            |> List.filteri (fun n _ -> n >= scroll && n < scroll + capacity)
            |> List.map (line Panel))
          @ [
              line Panel
                (Printf.sprintf "表示 %d–%d / %d行  ↑↓/Page/Home/End" (scroll + 1)
                   (min (scroll + capacity) (List.length lines))
                   (List.length lines));
              line Panel hint;
              panel_bottom ~width:pane_width ();
            ])
  | Commands selected ->
      let rows =
        List.mapi
          (fun n command ->
            panel_line
              (if n = selected then Panel_active else Panel)
              ((if n = selected then "> " else "  ") ^ command_label command))
          commands
      in
      Some
        ((panel_border "Command Palette" :: rows)
        @ [
            panel_line Panel "";
            panel_line Panel "Up/Down  select";
            panel_line Panel "Enter    open";
            panel_line Panel "Esc      close";
            panel_bottom ();
          ])
  | Themes { selected; _ } ->
      let rows =
        P.all_themes
        |> List.mapi (fun n theme ->
            panel_line
              (if n = selected then Panel_active else Panel)
              ((if n = selected then "> " else "  ") ^ P.theme_label theme))
      in
      Some
        ((panel_border "Theme" :: rows)
        @ [
            panel_line Panel "";
            panel_line Panel "Up/Down  preview";
            panel_line Panel "Enter    save";
            panel_line Panel "Esc      cancel";
            panel_bottom ();
          ])
  | Loci picker ->
      let width = max 4 (min 76 (width - 4)) in
      let line = panel_line ~width in
      let candidates = locus_candidates book picker.query in
      let count = List.length candidates in
      let selected = max 0 (min (max 0 (count - 1)) picker.selected) in
      let slots = min 8 (max 1 (height - 11)) in
      let start = max 0 (selected - slots + 1) in
      let rows =
        List.init slots (fun offset ->
            let n = start + offset in
            match List.nth_opt candidates n with
            | None -> line Panel (if count = 0 && offset = 0 then "候補なし" else "")
            | Some id ->
                line
                  (if n = selected then Panel_active else Panel)
                  ((if n = selected then "> " else "  ")
                  ^ B.label book id ^ " [" ^ id ^ "]"))
      in
      let chosen = List.nth_opt candidates selected in
      let notice =
        match picker.notice with
        | Some text -> text
        | None ->
            if blocked then "閲覧のみ: 書込停止中。下書きは保持します"
            else if not editable then "閲覧のみ: 編集中の科目は保持します"
            else if not can_choose_locus then "閲覧のみ: 戻って金額を消すと変更できます"
            else "選択は下書きのみ。まだ記帳しません"
      in
      let count_text =
        match B.approved_loci book with
        | None -> "科目一覧は未設定"
        | Some all ->
            Printf.sprintf "候補 %d / %d (全%d)"
              (if count = 0 then 0 else selected + 1)
              count (List.length all)
      in
      Some
        ([
           panel_border ~width
             (match picker.target with
             | From_locus -> "出金元"
             | To_locus -> "入金先・科目"
             | Posting_locus_at row -> Printf.sprintf "行%dの科目" (row + 1));
           line Panel ("検索: " ^ picker.query);
           line Panel count_text;
         ]
        @ rows
        @ [
            line Panel ("ID: " ^ Option.value ~default:"—" chosen);
            line Panel
              (match chosen with
              | None -> "現在量: —"
              | Some id -> "現在量: " ^ quantity ~book ~measure id ^ " " ^ measure);
            line Panel notice;
            line Panel
              (if can_choose_locus then "↑↓ 選択  Enter 確定  Esc 戻る" else "↑↓ 閲覧  Esc 戻る（選択変更不可）");
            line Panel "文字検索 / Backspace / Ctrl-U 消去";
            panel_bottom ~width ();
          ])
