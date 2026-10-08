(* Shared daily-book drafts and actions; no terminal-provider dependency.
   Transaction input opens a preview; only its explicit confirmation publishes. *)
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query
module F = Daily_file
module P = Ui_preferences
module R = Posting_draft
module A = Daily_actions
module Br = Daily_browser
module Fm = Daily_form
module Pe = Posting_editor
module O = Daily_overlays

let get = A.get
let get_id = A.get_id
let lstr = A.lstr
let mstr = A.mstr
let quanta = A.quanta

type key =
  [ `ASCII of char
  | `Uchar of Uchar.t
  | `Escape
  | `Enter
  | `Tab
  | `Backspace
  | `Insert
  | `Delete
  | `Home
  | `End
  | `Arrow of [ `Up | `Down | `Left | `Right ]
  | `Page of [ `Up | `Down ]
  | `Function of int ]

type modifier = [ `Meta | `Ctrl | `Shift ]

type input =
  [ `Key of key * modifier list
  | `Paste of [ `Start | `End ]
  | `End
  | `Resize of unit
  | `Mouse of unit ]

type focus = Date | Currency | Source | Destination | Amount | Memo | History
type view = Br.view = Entries | Plans
type mode = A.mode = New | Edit of B.entry | Pay of string
type posting_focus = Pe.field = Posting_day | Posting_memo | Posting_locus | Posting_sign | Posting_amount

type posting_editor = Pe.t = {
  draft : R.t;
  row : int;
  field : posting_focus;
  visible : bool;
  notice : string option;
}

type locus_target = O.locus_target = From_locus | To_locus | Posting_locus_at of int

type locus_picker = O.locus_picker = {
  target : locus_target;
  query : string;
  selected : int;
  notice : string option;
}

type transaction = A.transaction = { entry : B.entry; replace : bool; plan : string option }

type overlay = O.overlay =
  | No_overlay
  | Commands of int
  | Themes of { selected : int; original : P.theme }
  | Loci of locus_picker
  | Preview of { transaction : transaction; base_bytes : string; scroll : int }
  | Detail of { entry : B.entry; scroll : int }
  | Plan_detail of { plan : B.plan; scroll : int }

type command = O.command = Theme

let commands = O.commands
let command_label = O.command_label

type form = A.single_form = {
  day : string;
  measure : string;
  from_locus : string;
  to_locus : string;
  amount : string;
  memo : string;
}

type state = {
  session : F.t;
  form : form;
  focus : focus;
  record_focus : focus;
  cursor : int option;
  view : view;
  selected : int;
  other_selected : int;
  mode : mode;
  message : string;
  blocked : bool;
  pending : string option;
  adding : string option;
  paste : (string * bool) option;
  theme : P.theme;
  overlay : overlay;
  postings : posting_editor option;
  config_home : string option;
  ui_notice : string option;
}

let loci book = match B.approved_loci book with Some xs -> xs | None -> []
let head = function x :: _ -> x | [] -> ""
let entries s = Br.entries s.session.book
let plans s = Br.plans s.session.book

let browser_of_state s = {
  Br.view = s.view;
  entries_selected = (if s.view = Entries then s.selected else s.other_selected);
  plans_selected = (if s.view = Plans then s.selected else s.other_selected);
}

let apply_browser s action =
  let b = Br.apply_action ~book:s.session.book (browser_of_state s) action in
  {
    s with
    view = b.view;
    selected = Br.selected_index b;
    other_selected = (match b.view with Entries -> b.plans_selected | Plans -> b.entries_selected);
  }

let initial ?config_home session =
  let choices = loci session.F.book in
  let from_locus = head choices
  and to_locus = head (match choices with [] -> [] | _ :: xs -> xs) in
  {
    session;
    form =
      {
        day = F.today ();
        measure = head (List.map fst (B.measures session.book));
        from_locus;
        to_locus;
        amount = "";
        memo = "";
      };
    focus = Source;
    record_focus = Source;
    cursor = None;
    view = Entries;
    selected = 0;
    other_selected = 0;
    mode = New;
    message = "試用台帳（普段の正データはLOAM）。";
    blocked = false;
    pending = None;
    adding = None;
    paste = None;
    theme = P.load_theme ?config_home ();
    overlay = No_overlay;
    postings = None;
    config_home;
    ui_notice = None;
  }

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

let backspace = Fm.backspace
let editable s = match s.mode with New | Pay _ -> true | Edit _ -> false
let pick = Fm.pick

let editor_visible s = match s.postings with Some e -> e.visible | None -> false
let update_editor s f = { s with postings = Option.map f s.postings }
let posting_row s = match s.postings with None -> None | Some e -> List.nth_opt e.draft.rows e.row

let update_posting_row s f =
  update_editor s (fun e ->
      {
        e with
        draft =
          {
            e.draft with
            rows = List.mapi (fun n row -> if n = e.row then f row else row) e.draft.rows;
          };
        notice = None;
      })

let field s =
  match s.postings with
  | Some e when e.visible -> (
      match e.field with
      | Posting_day -> s.form.day
      | Posting_memo -> s.form.memo
      | Posting_amount -> ( match posting_row s with None -> "" | Some row -> row.amount)
      | Posting_locus | Posting_sign -> "")
  | Some _ | None -> (
      match s.adding with
      | Some name -> name
      | None -> (
          match s.focus with
          | Date -> s.form.day
          | Amount -> s.form.amount
          | Memo -> s.form.memo
          | Currency | Source | Destination | History -> ""))

let set_field s value =
  match s.postings with
  | Some _ when s.blocked -> s
  | Some e when e.visible -> (
      match e.field with
      | Posting_day -> { s with form = { s.form with day = value } }
      | Posting_memo -> { s with form = { s.form with memo = value } }
      | Posting_amount -> update_posting_row s (fun row -> { row with amount = value })
      | Posting_locus | Posting_sign -> s)
  | Some _ -> s
  | None -> (
      match s.adding with
      | Some _ -> { s with adding = Some value }
      | None ->
          let form =
            match s.focus with
            | Date -> { s.form with day = value }
            | Amount -> { s.form with amount = value }
            | Memo -> { s.form with memo = value }
            | Currency | Source | Destination | History -> s.form
          in
          { s with form })

let field_of_focus = function
  | Date -> Some Fm.Date
  | Currency -> Some Fm.Currency
  | Source -> Some Fm.Source
  | Destination -> Some Fm.Destination
  | Amount -> Some Fm.Amount
  | Memo -> Some Fm.Memo
  | History -> None

let focus_of_field = function
  | Fm.Date -> Date
  | Fm.Currency -> Currency
  | Fm.Source -> Source
  | Fm.Destination -> Destination
  | Fm.Amount -> Amount
  | Fm.Memo -> Memo

(* Home has two regions. Field arrows never cross the region boundary. *)
let next = function
  | Date -> Currency
  | Currency -> Source
  | Source -> Destination
  | Destination -> Amount
  | Amount | Memo -> Memo
  | History -> Source

let previous = function
  | Date | Currency -> Date
  | Source -> Currency
  | Destination -> Source
  | Amount -> Destination
  | Memo -> Amount
  | History -> Source

let move_field s direction =
  if s.postings <> None then s
  else
    let focus = direction s.focus in
    if focus = s.focus then s else { s with focus; record_focus = focus; cursor = None }

let switch_region s =
  if s.focus = History then { s with focus = s.record_focus }
  else { s with record_focus = s.focus; focus = History }

let text_field s =
  s.adding <> None
  || (s.postings = None && match field_of_focus s.focus with Some fld -> Fm.is_text_field fld | None -> false)

let cursor s = Fm.cursor_pos ~value:(field s) s.cursor

let move_cursor s step =
  let value = field s in
  let next = Fm.move_cursor ~value ~cursor:s.cursor step in
  { s with cursor = Some next }

let insert_text s text =
  let value = field s in
  let updated, next_cursor = Fm.insert_at ~value ~cursor:s.cursor text in
  let s = set_field s updated in
  { s with cursor = Some next_cursor }

let erase_before_cursor s =
  let value = field s in
  let updated, next_cursor = Fm.erase_at ~value ~cursor:s.cursor in
  let s = set_field s updated in
  { s with cursor = Some next_cursor }

let count s = Br.count ~book:s.session.book (browser_of_state s)
let select s step = apply_browser { s with focus = History } (Br.Select step)
let switch_view s = apply_browser s Br.Switch_view

let change s step =
  if s.adding <> None then move_cursor s step
  else if s.focus <> History && s.postings <> None then s
  else if s.focus = History then switch_view s
  else if text_field s then move_cursor s step
  else if (not (editable s)) || s.form.amount <> "" then
    { s with message = "金額入力中／編集中は通貨・科目を変えません。Ctrl-Nで新規。" }
  else
    match field_of_focus s.focus with
    | None -> s
    | Some fld ->
        let choices =
          match fld with
          | Fm.Currency -> List.map fst (B.measures s.session.book)
          | Fm.Source | Fm.Destination -> loci s.session.book
          | Fm.Date | Fm.Amount | Fm.Memo -> []
        in
        let model = { Fm.form = s.form; focus = fld; cursor = s.cursor } in
        let updated = Fm.apply_action model (Fm.Cycle_choice { choices; step }) in
        { s with form = updated.form }

let pair = A.pair

let with_postings s draft =
  {
    s with
    postings = Some (Pe.create draft);
  }

let open_postings s =
  if s.adding <> None then s
  else
    match s.postings with
    | Some _ -> update_editor s (fun e -> { e with visible = true })
    | None -> (
        match A.prepare_postings ~book:s.session.book ~mode:s.mode ~form:s.form with
        | Error why -> { s with message = "複数行入力拒否: " ^ why }
        | Ok draft ->
            with_postings
              {
                s with
                message =
                  (if s.blocked then s.message else "複数posting下書き。Enterは保存せず、Ctrl-Sで検査・プレビュー。");
              }
              draft)

let entry_form s (e : B.entry) =
  match A.prepare_edit ~book:s.session.book e with
  | A.Edit_refused msg -> { s with message = msg }
  | A.Edit_multiple { day; measure; memo; draft; entry } ->
      with_postings
        {
          s with
          mode = Edit entry;
          focus = Amount;
          record_focus = Amount;
          cursor = None;
          adding = None;
          form = { s.form with day; measure; amount = ""; memo };
          message = "複数行編集：日付・各金額・メモ。行構成・符号・科目・通貨・キーを保持します。";
        }
        draft
  | A.Edit_single { form; entry } ->
      {
        s with
        mode = Edit entry;
        focus = Amount;
        record_focus = Amount;
        cursor = None;
        adding = None;
        form;
        message = "編集：日付・金額・メモ。IDと科目・通貨は保持します。";
      }

let has_draft s =
  s.adding <> None || s.postings <> None || s.mode <> New || s.form.amount <> ""
  || s.form.memo <> ""

let keep_draft s = { s with message = "入力中の下書きがあります。Ctrl-Nで明示的に破棄してから選んでください。" }

let edit_selected s =
  if has_draft s then keep_draft s
  else
    match s.view with
    | Entries -> (
        match List.nth_opt (entries s) s.selected with None -> s | Some e -> entry_form s e)
    | Plans -> { s with message = "予定を選んでEnterで詳細、詳細から支払い入力へ。" }

let pay_selected s =
  if s.blocked then s
  else
    match List.nth_opt (plans s) s.selected with
    | None -> s
    | Some _ when has_draft s -> keep_draft s
    | Some p -> (
        match A.prepare_pay ~book:s.session.book p with
        | A.Pay_refused msg -> { s with message = msg }
        | A.Pay_multiple { day; measure; draft; plan_id } ->
            with_postings
              {
                s with
                mode = Pay plan_id;
                focus = Amount;
                record_focus = Amount;
                cursor = None;
                adding = None;
                form = { s.form with day; measure; amount = ""; memo = "" };
                message = "複数行の支払い入力。Ctrl-Sで全体プレビュー。予定の日付・内訳は保持します。";
              }
              draft
        | A.Pay_single { form; plan_id } ->
            {
              s with
              mode = Pay plan_id;
              focus = Amount;
              record_focus = Amount;
              cursor = None;
              adding = None;
              form;
              message = "予定の支払い入力。Enterで全体プレビュー。予定の元日付は保持します。";
            })

let apply_commit_result s ~draft result =
  match result with
  | A.Published session when s.adding <> None ->
      { s with session; adding = None; cursor = None; message = "科目を追加しました。入力中の下書きは保持しています。" }
  | A.Published session ->
      {
        (initial ?config_home:s.config_home session) with
        theme = s.theme;
        ui_notice = s.ui_notice;
        form = { s.form with amount = ""; memo = "" };
        message = "書込みを確認しました（試用）。修正前のコピーも保管しました。";
      }
  | A.Conflict_base_changed ->
      { draft with blocked = true; pending = None; message = "確認元が変わりました。下書きは保持。再読込して確認し直してください。" }
  | A.Conflict ->
      { draft with blocked = true; pending = None; message = "別の更新があります。下書きは保持。Ctrl-Rで再読込してください。" }
  | A.Refused why -> { draft with message = why }
  | A.Uncertain bytes ->
      {
        draft with
        blocked = true;
        pending = Some bytes;
        message = "書込結果が不明です。再送せずCtrl-Rで確認。下書き・残ったファイルは保持しています。";
      }

let finish s candidate =
  let bytes = B.to_string candidate in
  match F.publish s.session candidate with
  | F.Written session when s.adding <> None ->
      { s with session; adding = None; cursor = None; message = "科目を追加しました。入力中の下書きは保持しています。" }
  | F.Written session ->
      {
        (initial ?config_home:s.config_home session) with
        theme = s.theme;
        ui_notice = s.ui_notice;
        form = { s.form with amount = ""; memo = "" };
        message = "書込みを確認しました（試用）。修正前のコピーも保管しました。";
      }
  | F.Conflict ->
      { s with blocked = true; pending = None; message = "別の更新があります。下書きは保持。Ctrl-Rで再読込してください。" }
  | F.Refused_input why -> { s with message = "記帳拒否: " ^ why }
  | F.Uncertain ->
      {
        s with
        blocked = true;
        pending = Some bytes;
        message = "書込結果が不明です。再送せずCtrl-Rで確認。下書き・残ったファイルは保持しています。";
      }

let submit s =
  if s.blocked then { s with message = "書込を止めています。Ctrl-Rで確認してください。" }
  else
    match s.adding with
    | Some name ->
        let result = A.commit_add_locus ~session:s.session name in
        apply_commit_result s ~draft:s result
    | None -> (
        let content =
          match s.postings with
          | Some e -> A.Multiple { day = s.form.day; memo = s.form.memo; draft = e.draft }
          | None -> A.Single s.form
        in
        match A.build_transaction ~book:s.session.book ~mode:s.mode content with
        | Error why -> { s with message = why }
        | Ok transaction ->
            {
              s with
              overlay =
                Preview
                  {
                    transaction;
                    base_bytes = s.session.bytes;
                    scroll = 0;
                  };
            })

let confirm s =
  match s.overlay with
  | Preview { transaction; base_bytes; _ } ->
      let draft = { s with overlay = No_overlay } in
      if s.blocked then draft
      else
        let result = A.commit_transaction ~session:s.session ~base_bytes transaction in
        apply_commit_result s ~draft result
  | No_overlay | Commands _ | Themes _ | Loci _ | Detail _ | Plan_detail _ -> s

let detail_selected s =
  match Br.selected_entry ~book:s.session.book (browser_of_state s) with
  | None -> s
  | Some entry -> { s with overlay = Detail { entry; scroll = 0 } }

let plan_detail_selected s =
  match Br.selected_plan ~book:s.session.book (browser_of_state s) with
  | None -> s
  | Some plan -> { s with overlay = Plan_detail { plan; scroll = 0 } }

let reload s =
  match A.reload ~session:s.session ~pending:s.pending ~mode:s.mode with
  | A.Pending_confirmed session ->
      {
        (initial ?config_home:s.config_home session) with
        theme = s.theme;
        ui_notice = s.ui_notice;
        message = "先ほどの記帳が現在のファイルにあります。再送しません。";
      }
  | A.Pending_unconfirmed session ->
      { s with session; message = "現在のファイルを読みました。先ほどの書込は未確認。Ctrl-Nで下書きを破棄するまで再送を止めます。" }
  | A.Edit_base_changed session ->
      {
        s with
        session;
        blocked = true;
        message = "編集中の元ファイルが変わりました。下書きは保持。Ctrl-Nで破棄して明細を選び直してください。";
      }
  | A.Reloaded session ->
      { s with session; blocked = false; message = "再読込しました。保存前の下書きは保持しています。" }
  | A.Reload_failed _ ->
      { s with blocked = true; message = "再読込できません。空台帳にせず、表示と下書きを保持しています。" }

let utf8 = O.utf8
let printable_uchar = O.printable_uchar

let locus_candidates s query = O.locus_candidates s.session.book query

let can_choose_locus s =
  (not s.blocked) && s.adding = None && editable s
  &&
  match s.overlay with
  | Loci { target = Posting_locus_at row; _ } -> (
      editor_visible s
      && match s.postings with Some e -> List.nth_opt e.draft.rows row <> None | None -> false)
  | No_overlay | Commands _ | Themes _ | Loci _ | Preview _ | Detail _ | Plan_detail _ ->
      s.form.amount = ""

let open_locus_picker s target =
  let current =
    match target with
    | From_locus -> s.form.from_locus
    | To_locus -> s.form.to_locus
    | Posting_locus_at row -> (
        match s.postings with
        | Some e -> ( match List.nth_opt e.draft.rows row with Some row -> row.locus | None -> "")
        | None -> "")
  in
  let rec index n = function
    | [] -> 0
    | id :: _ when id = current -> n
    | _ :: rest -> index (n + 1) rest
  in
  {
    s with
    overlay = Loci { target; query = ""; selected = index 0 (loci s.session.book); notice = None };
  }

let search_loci s picker query =
  { s with overlay = Loci { picker with query; selected = 0; notice = None } }

let picker_is_open s = match s.overlay with Loci _ -> true | _ -> false
let theme_at = O.theme_at
let theme_index = O.theme_index
let cycle_index = O.cycle_index
let entry_lines = O.entry_lines
let plan_lines = O.plan_lines
let preview_lines = O.preview_lines
let wrap_text = O.wrap_text
let review_page = O.review_page

let overlay_key ~dimensions ~width_of s (button, mods) =
  match s.overlay with
  | No_overlay -> None
  | (Preview _ | Detail _ | Plan_detail _) as overlay -> (
      let lines, scroll =
        match overlay with
        | Preview p -> (preview_lines s.session.book p.transaction, p.scroll)
        | Detail d -> (entry_lines s.session.book d.entry, d.scroll)
        | Plan_detail d -> (plan_lines s.session.book d.plan, d.scroll)
        | No_overlay | Commands _ | Themes _ | Loci _ -> assert false
      in
      let _, _, _, scroll, last = review_page ~dimensions ~width_of lines scroll in
      let move next =
        Some
          {
            s with
            overlay =
              (match overlay with
              | Preview p -> Preview { p with scroll = max 0 (min last next) }
              | Detail d -> Detail { d with scroll = max 0 (min last next) }
              | Plan_detail d -> Plan_detail { d with scroll = max 0 (min last next) }
              | No_overlay | Commands _ | Themes _ | Loci _ -> overlay);
          }
      in
      match (button, mods) with
      | `Escape, [] -> Some { s with overlay = No_overlay }
      | `Enter, [] when match overlay with Plan_detail _ -> true | _ -> false ->
          let width, height = dimensions in
          Some
            (if width < 32 || height < 10 then s
             else
               let payment = pay_selected s in
               if payment.mode <> s.mode then { payment with overlay = No_overlay } else payment)
      | `Arrow `Up, [] -> move (scroll - 1)
      | `Arrow `Down, [] -> move (scroll + 1)
      | `Page `Up, [] -> move (scroll - 5)
      | `Page `Down, [] -> move (scroll + 5)
      | `Home, [] -> move 0
      | `End, [] -> move last
      | `ASCII 's', [ `Ctrl ] when match overlay with Preview _ -> true | _ -> false ->
          let width, height = dimensions in
          Some (if width < 32 || height < 10 then s else confirm s)
      | _ -> Some s)
  | Commands selected -> (
      match (button, mods) with
      | `Escape, [] -> Some { s with overlay = No_overlay }
      | `Arrow `Up, [] | `Arrow `Left, [] ->
          Some { s with overlay = Commands (cycle_index (List.length commands) selected (-1)) }
      | `Arrow `Down, [] | `Arrow `Right, [] ->
          Some { s with overlay = Commands (cycle_index (List.length commands) selected 1) }
      | `Enter, [] -> (
          match List.nth_opt commands selected with
          | Some Theme ->
              Some
                { s with overlay = Themes { selected = theme_index s.theme; original = s.theme } }
          | None -> Some s)
      | _ -> Some s)
  | Themes { selected; original } -> (
      match (button, mods) with
      | `Escape, [] -> Some { s with theme = original; overlay = Commands 0 }
      | `Arrow `Up, [] | `Arrow `Left, [] ->
          let selected = cycle_index (List.length P.all_themes) selected (-1) in
          Some { s with theme = theme_at selected; overlay = Themes { selected; original } }
      | `Arrow `Down, [] | `Arrow `Right, [] ->
          let selected = cycle_index (List.length P.all_themes) selected 1 in
          Some { s with theme = theme_at selected; overlay = Themes { selected; original } }
      | `Enter, [] ->
          let theme = theme_at selected in
          Some
            (match P.save_theme ?config_home:s.config_home theme with
            | Ok () ->
                {
                  s with
                  theme;
                  overlay = No_overlay;
                  ui_notice = Some ("テーマを保存しました: " ^ P.theme_label theme);
                }
            | Error _ ->
                {
                  s with
                  theme;
                  overlay = No_overlay;
                  ui_notice = Some "テーマはこの起動中だけ変更しました。次回用のUI設定は保存できませんでした。";
                })
      | _ -> Some s)
  | Loci picker -> (
      let candidates = locus_candidates s picker.query in
      let move step =
        let selected = max 0 (min (max 0 (List.length candidates - 1)) (picker.selected + step)) in
        Some { s with overlay = Loci { picker with selected; notice = None } }
      in
      match (button, mods) with
      | `Escape, [] -> Some { s with overlay = No_overlay }
      | `Arrow `Up, [] -> move (-1)
      | `Arrow `Down, [] -> move 1
      | `Page `Up, [] -> move (-8)
      | `Page `Down, [] -> move 8
      | `Home, [] -> move (-List.length candidates)
      | `End, [] -> move (List.length candidates)
      | `Backspace, [] -> Some (search_loci s picker (backspace picker.query))
      | `ASCII 'u', [ `Ctrl ] -> Some (search_loci s picker "")
      | `Enter, [] -> (
          match List.nth_opt candidates picker.selected with
          | Some id when can_choose_locus s ->
              let chosen =
                match picker.target with
                | From_locus -> { s with form = { s.form with from_locus = id } }
                | To_locus -> { s with form = { s.form with to_locus = id } }
                | Posting_locus_at position ->
                    update_editor s (fun e ->
                        {
                          e with
                          draft =
                            {
                              e.draft with
                              rows =
                                List.mapi
                                  (fun n (row : R.row) ->
                                    if n = position then { row with locus = id } else row)
                                  e.draft.rows;
                            };
                          notice = None;
                        })
              in
              Some { chosen with overlay = No_overlay }
          | Some _ | None -> Some s)
      | `ASCII c, [] when Char.code c >= 32 && Char.code c <> 127 ->
          Some (search_loci s picker (picker.query ^ String.make 1 c))
      | `Uchar c, [] when printable_uchar c -> Some (search_loci s picker (picker.query ^ utf8 c))
      | _ -> Some s)

let is_space = function `ASCII ' ' -> true | `Uchar c -> Uchar.to_int c = 0x20 | _ -> false

let accepts_free_text s =
  match s.postings with
  | Some e when e.visible -> e.field = Posting_memo
  | Some _ -> false
  | None -> s.adding <> None || s.focus = Memo

let new_draft s =
  {
    (initial ?config_home:s.config_home s.session) with
    theme = s.theme;
    ui_notice = s.ui_notice;
    view = s.view;
    selected = s.selected;
    other_selected = s.other_selected;
    message = "新しい下書き。過去の不確かな試行は再送・回復しません。";
  }

let next_posting_field = Pe.next_field
let previous_posting_field = Pe.previous_field

let editor_key s e (button, mods) =
  let notice text = update_editor s (fun e -> Pe.set_notice e (Some text)) in
  let move step = update_editor s (fun e -> Pe.move_row e step) in
  let focus f = update_editor s (fun e -> Pe.move_field e f) in
  let add () =
    if s.blocked then s
    else if not (editable s) then notice "編集中は行構成・科目・符号・キーを保持します"
    else update_editor s Pe.add_row
  in
  let remove () =
    if s.blocked then s
    else if not (editable s) then notice "編集中は既存の行を削除しません"
    else update_editor s Pe.remove_row
  in
  let sign negative =
    if s.blocked then s
    else if not (editable s) then notice "編集中は符号を保持します"
    else update_editor s (fun e -> Pe.set_sign e negative)
  in
  match (button, mods) with
  | `ASCII 'n', [ `Ctrl ] -> new_draft s
  | `ASCII 'r', [ `Ctrl ] -> reload s
  | `ASCII 't', [ `Ctrl ] -> update_editor s (fun e -> { e with visible = not e.visible })
  | `Escape, [] -> update_editor s (fun e -> { e with visible = false })
  | button, [] when is_space button && not (accepts_free_text s) -> { s with overlay = Commands 0 }
  | _ when not e.visible -> s
  | `ASCII 's', [ `Ctrl ] ->
      if s.blocked then s else submit (update_editor s (fun e -> { e with notice = None }))
  | `ASCII 'a', [ `Ctrl ] | `Insert, [] -> add ()
  | `ASCII 'd', [ `Ctrl ] | `Delete, [] -> remove ()
  | `Arrow `Up, [] -> move (-1)
  | `Arrow `Down, [] -> move 1
  | `Page `Up, [] -> move (-6)
  | `Page `Down, [] -> move 6
  | `Home, [] -> move (-List.length e.draft.rows)
  | `End, [] -> move (List.length e.draft.rows)
  | `Tab, [] -> focus next_posting_field
  | `Tab, [ `Shift ] -> focus previous_posting_field
  | `Enter, [] when e.field = Posting_locus -> open_locus_picker s (Posting_locus_at e.row)
  | `Enter, [] -> focus next_posting_field
  | `Arrow `Left, [] when e.field = Posting_sign -> sign true
  | `Arrow `Right, [] when e.field = Posting_sign -> sign false
  | `ASCII 'u', [ `Ctrl ] -> set_field s ""
  | `Backspace, [] -> set_field s (backspace (field s))
  | `ASCII c, [] when Char.code c >= 32 && Char.code c <> 127 ->
      set_field s (field s ^ String.make 1 c)
  | `Uchar c, [] when printable_uchar c -> set_field s (field s ^ utf8 c)
  | _ -> s

(* Default geometry is for provider-free checks; both frontends supply live
   dimensions and their own cell-width measurement. *)
let key ?(dimensions = (100, 25)) ?(width_of = String.length) s (button, mods) =
  (* Notty decodes control bytes as upper-case ASCII; plain memo text is untouched. *)
  let button =
    match (button, mods) with `ASCII c, [ `Ctrl ] -> `ASCII (Char.lowercase_ascii c) | _ -> button
  in
  match s.paste with
  | Some _ when s.overlay <> No_overlay && not (picker_is_open s) -> Some s
  | Some (text, invalid) -> (
      match (button, mods) with
      | `ASCII c, [] when Char.code c >= 32 && Char.code c <> 127 ->
          Some { s with paste = Some (text ^ String.make 1 c, invalid) }
      | `Uchar c, [] when printable_uchar c -> Some { s with paste = Some (text ^ utf8 c, invalid) }
      | _ -> Some { s with paste = Some (text, true) })
  | None when button = `ASCII 'q' && mods = [ `Ctrl ] -> None
  | None -> (
      match overlay_key ~dimensions ~width_of s (button, mods) with
      | Some s -> Some s
      | None when editor_visible s -> (
          match s.postings with Some e -> Some (editor_key s e (button, mods)) | None -> Some s)
      | None -> (
          match (button, mods) with
          | `ASCII 't', [ `Ctrl ] -> Some (open_postings s)
          | button, [] when is_space button && not (accepts_free_text s) ->
              Some { s with overlay = Commands 0 }
          | `ASCII 'n', [ `Ctrl ] -> Some (new_draft s)
          | `ASCII 'e', [ `Ctrl ] -> Some (if s.blocked then s else edit_selected s)
          | `ASCII 'r', [ `Ctrl ] -> Some (reload s)
          | `ASCII 'p', [ `Ctrl ] ->
              Some
                (if s.adding <> None then s
                 else
                   let s = if s.focus = History then s else switch_region s in
                   switch_view s)
          | `ASCII 'a', [ `Ctrl ] ->
              Some
                (if s.blocked then s
                 else if s.postings <> None then s
                 else
                   let s = if s.focus = History then switch_region s else s in
                   {
                     s with
                     adding = Some "";
                     cursor = None;
                     message = "新しい科目名を入力しEnter（残高ゼロは作りません）。";
                   })
          | `ASCII 's', [ `Ctrl ] ->
              Some (if s.focus = History || s.postings <> None then s else submit s)
          | `ASCII 'u', [ `Ctrl ] ->
              Some (if text_field s then { (set_field s "") with cursor = None } else s)
          | `Escape, [] ->
              Some (if s.adding = None then s else { s with adding = None; cursor = None })
          | `Tab, [] | `Tab, [ `Shift ] -> Some (if s.adding <> None then s else switch_region s)
          | `Arrow `Up, [] ->
              Some
                (if s.adding <> None then s
                 else if s.focus = History then select s (-1)
                 else move_field s previous)
          | `Arrow `Down, [] ->
              Some
                (if s.adding <> None then s
                 else if s.focus = History then select s 1
                 else move_field s next)
          | `Page `Up, [] when s.focus = History -> Some (select s (-6))
          | `Page `Down, [] when s.focus = History -> Some (select s 6)
          | `Home, [] ->
              Some
                (if s.focus = History then select s (-count s)
                 else if text_field s then { s with cursor = Some 0 }
                 else s)
          | `End, [] ->
              Some
                (if s.focus = History then select s (count s)
                 else if text_field s then { s with cursor = None }
                 else s)
          | `Arrow `Left, [] -> Some (change s (-1))
          | `Arrow `Right, [] -> Some (change s 1)
          | `Backspace, [] -> Some (if text_field s then erase_before_cursor s else s)
          | `Enter, [] ->
              Some
                (if s.adding <> None then submit s
                 else if s.focus <> History && s.postings <> None then s
                 else
                   match s.focus with
                   | Source -> open_locus_picker s From_locus
                   | Destination -> open_locus_picker s To_locus
                   | History -> (
                       match s.view with
                       | Plans -> plan_detail_selected s
                       | Entries -> detail_selected s)
                   | Date | Currency | Amount | Memo -> submit s)
          | `ASCII c, [] when Char.code c >= 32 && Char.code c <> 127 ->
              Some (if text_field s then insert_text s (String.make 1 c) else s)
          | `Uchar c, [] -> Some (if text_field s then insert_text s (utf8 c) else s)
          | _ -> Some s))

let handle ?(dimensions = (100, 25)) ?(width_of = String.length) s (input : input) =
  match input with
  | `Key event -> key ~dimensions ~width_of s event
  | `Paste `Start -> Some { s with paste = Some ("", false) }
  | `Paste `End when picker_is_open s -> (
      match (s.overlay, s.paste) with
      | Loci picker, Some (text, false) ->
          Some (search_loci { s with paste = None } picker (picker.query ^ text))
      | Loci picker, Some (_, true) ->
          Some
            {
              s with
              paste = None;
              overlay = Loci { picker with notice = Some "改行・制御入りの検索貼付を拒否しました" };
            }
      | _ -> Some { s with paste = None })
  | `Paste `End when s.overlay <> No_overlay -> Some { s with paste = None }
  | `Paste `End when s.postings <> None -> (
      match s.paste with
      | Some (text, false) -> Some (set_field { s with paste = None } (field s ^ text))
      | Some (_, true) ->
          Some
            (update_editor { s with paste = None } (fun e ->
                 { e with notice = Some "改行・制御入り貼付を拒否。自動記帳しません" }))
      | None -> Some s)
  | `Paste `End -> (
      match s.paste with
      | None -> Some s
      | Some (text, invalid) ->
          Some
            (if invalid then { s with paste = None; message = "改行・制御キー入りの貼付を拒否しました。自動記帳しません。" }
             else if text_field s then insert_text { s with paste = None } text
             else { s with paste = None }))
  | `End -> None
  | `Resize _ | `Mouse _ -> Some s

let quantity s locus = O.quantity ~book:s.session.book ~measure:s.form.measure locus

let posting_text book p = Br.posting_text book p
let history s = Br.history_lines ~book:s.session.book (browser_of_state s)

type style = O.style = Plain | Active | Heading | Status | Panel | Panel_heading | Panel_active

let panel_width = O.panel_width
let clip_text = O.clip_text
let panel_line = O.panel_line
let panel_border = O.panel_border
let panel_bottom = O.panel_bottom

let posting_status s e = Pe.status s.session.book e
let posting_line = Pe.line

let posting_panel ~dimensions ~width_of s (e : Pe.t) =
  O.posting_panel ~dimensions ~width_of ~book:s.session.book
    ~day:s.form.day ~memo:s.form.memo ~blocked:s.blocked ~message:s.message e

let overlay_screen ~dimensions ~width_of s =
  O.overlay_screen ~dimensions ~width_of ~book:s.session.book
    ~day:s.form.day ~measure:s.form.measure ~memo:s.form.memo
    ~blocked:s.blocked ~editable:(editable s)
    ~can_choose_locus:(can_choose_locus s) ~message:s.message
    ~has_draft:(has_draft s) ?postings:s.postings s.overlay

let screen ?(width_of = String.length) ~frontend (width, height) s =
  let line style value = (style, clip_text ~width_of width value) in
  let plain = line Plain in
  let browsing = s.focus = History in
  let with_cursor value =
    let at = cursor s in
    String.sub value 0 at ^ "|" ^ String.sub value at (String.length value - at)
  in
  let field focus title value =
    let active = s.adding = None && s.focus = focus in
    let value = if active && s.adding = None && text_field s then with_cursor value else value in
    line (if active then Active else Plain) ((if active then "> " else "  ") ^ title ^ "  " ^ value)
  in
  if width < 64 || height < 20 then
    let rows = [ plain ("Bakhlo / " ^ frontend); plain "端末を64桁×20行以上に広げてください" ] in
    if s.blocked then
      rows @ List.init (max 0 (height - 3)) (fun _ -> plain "") @ [ line Status s.message ]
    else rows
  else
    let room = max 1 (height - 15) in
    let start = max 0 (s.selected - room + 1) in
    let rows =
      history s
      |> List.mapi (fun n text -> (n, text))
      |> List.filter (fun (n, _) -> n >= start && n < start + room)
      |> List.map (fun (n, text) ->
          let active = browsing && s.selected = n in
          line (if active then Active else Plain) ((if active then "> " else "  ") ^ text))
    in
    let form_rows =
      match s.postings with
      | Some e ->
          [
            plain ("日付: " ^ s.form.day);
            plain ("通貨: " ^ e.draft.measure);
            plain (Printf.sprintf "複数posting: %d行（下書き保持中）" (List.length e.draft.rows));
            plain ("メモ: " ^ s.form.memo);
            plain (posting_status s e);
            plain (Option.value ~default:"" e.notice);
          ]
      | None ->
          [
            field Date "日付" s.form.day;
            field Currency "通貨" s.form.measure;
            field Source "出金元" (B.label s.session.book s.form.from_locus);
            field Destination "入金先・科目" (B.label s.session.book s.form.to_locus);
            field Amount "金額" s.form.amount;
            field Memo "メモ" s.form.memo;
          ]
    in
    let content =
      [
        line Heading ("Bakhlo / " ^ frontend ^ " — S式の家計簿（試用）");
        line
          (if browsing then Heading else Active)
          ((if browsing then "  " else "> ")
          ^ "記帳 — "
          ^
          match s.mode with
          | New -> "新規"
          | Edit e -> "明細訂正 [" ^ e.id ^ "]"
          | Pay id -> "予定の支払い [" ^ id ^ "]");
      ]
      @ form_rows
      @ [
          line
            (if s.adding <> None then Active else Plain)
            (match s.adding with
            | Some name -> "追加する科目: " ^ with_cursor name ^ "  Enter:追加 Esc:取消"
            | None ->
                if browsing then ""
                else if s.postings <> None then "Ctrl-T:複数行入力へ戻る（下書き保持）"
                else "↑↓:項目 ←→:候補/文字位置 Enter:選択/確認 Ctrl-S:確認");
          plain
            (if browsing then ""
             else if s.postings = None && List.mem s.focus [ Source; Destination; Amount ] then
               "出金元: " ^ quantity s s.form.from_locus ^ " / 入金先: " ^ quantity s s.form.to_locus
               ^ " " ^ s.form.measure
             else "Ctrl-T:複数行 Ctrl-A:科目追加 Ctrl-R:再読込");
          line Status s.message;
          line Status (Option.value ~default:"" s.ui_notice);
          line
            (if browsing then Active else Heading)
            ((if browsing then "> " else "  ")
            ^ "閲覧 — "
            ^ (match s.view with Entries -> "[明細]  予定" | Plans -> "明細  [予定]")
            ^ " "
            ^ String.make (max 0 (width - 28)) '-');
          plain
            (if not browsing then ""
             else
               match s.view with
               | Entries -> "←→:表示切替 ↑↓:選択 Enter:詳細 Ctrl-E:編集"
               | Plans -> "←→:表示切替 ↑↓:選択 Enter:詳細（未記録は義務なしではありません）");
        ]
      @ if rows = [] then [ plain "記録なし" ] else rows
    in
    content
    @ List.init (max 0 (height - List.length content - 1)) (fun _ -> plain "")
    @ [
        (if s.blocked then line Status s.message else plain "Tab:上下 Ctrl-N:新規 Space:コマンド Ctrl-Q:終了");
      ]
