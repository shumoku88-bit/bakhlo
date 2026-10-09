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

type split_row = {
  locus : string;
  amount : string;
}

type split_state = {
  sources : split_row list;
  destinations : split_row list;
}

type split_target =
  | Source_locus of int
  | Source_amount of int
  | Destination_locus of int
  | Destination_amount of int

type focus =
  | Date
  | Currency
  | Source
  | Destination
  | Amount
  | Memo
  | History
  | Split of split_target

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

type locus_target = O.locus_target =
  | From_locus
  | To_locus
  | Posting_locus_at of int
  | Split_source of int
  | Split_destination of int

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

type command = O.command =
  | Theme
  | Date_today
  | Date_prev_day
  | Date_next_day

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
  pending : A.uncertain_evidence option;
  adding : string option;
  paste : (string * bool) option;
  theme : P.theme;
  overlay : overlay;
  postings : posting_editor option;
  split : split_state option;
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
  let recovery_notice = A.recovery_notice ~session in
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
    message = Option.value ~default:"試用台帳（普段の正データはLOAM）。" recovery_notice;
    blocked = recovery_notice <> None;
    pending = None;
    adding = None;
    paste = None;
    theme = P.load_theme ?config_home ();
    overlay = No_overlay;
    postings = None;
    split = None;
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

let split_to_draft measure (sp : split_state) : R.t =
  let src_rows =
    List.map
      (fun (r : split_row) ->
        { R.key = None; locus = r.locus; negative = true; amount = r.amount })
      sp.sources
  in
  let dst_rows =
    List.map
      (fun (r : split_row) ->
        { R.key = None; locus = r.locus; negative = false; amount = r.amount })
      sp.destinations
  in
  { R.measure; rows = src_rows @ dst_rows }

(* Split rows, not the mirrored two-row form, own inline amounts. *)
let has_amount s =
  match s.split with
  | None -> s.form.amount <> ""
  | Some sp -> List.exists (fun (r : split_row) -> r.amount <> "") (sp.sources @ sp.destinations)

let can_change_split_locus s rows idx =
  not s.blocked && editable s && s.adding = None && s.postings = None
  && match List.nth_opt rows idx with Some (r : split_row) -> r.amount = "" | None -> false

let sum_quanta book measure rows =
  List.fold_left
    (fun acc (r : split_row) ->
      match B.parse_amount book measure r.amount with
      | Ok q -> Z.add acc q
      | Error _ -> acc)
    Z.zero rows

let split_residual_quanta book measure (sp : split_state) =
  let src_total = sum_quanta book measure sp.sources in
  let dst_total = sum_quanta book measure sp.destinations in
  Z.sub src_total dst_total

let update_split_source_locus s idx id =
  match s.split with
  | None -> s
  | Some sp when not (can_change_split_locus s sp.sources idx) -> s
  | Some sp ->
      let sources =
        List.mapi (fun i r -> if i = idx then { r with locus = id } else r) sp.sources
      in
      let s = { s with split = Some { sp with sources } } in
      if idx = 0 then { s with form = { s.form with from_locus = id } } else s

let update_split_destination_locus s idx id =
  match s.split with
  | None -> s
  | Some sp when not (can_change_split_locus s sp.destinations idx) -> s
  | Some sp ->
      let destinations =
        List.mapi (fun i r -> if i = idx then { r with locus = id } else r) sp.destinations
      in
      let s = { s with split = Some { sp with destinations } } in
      if idx = 0 then { s with form = { s.form with to_locus = id } } else s

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
          | Split (Source_locus idx) -> (
              match s.split with
              | Some sp -> (match List.nth_opt sp.sources idx with Some r -> r.locus | None -> "")
              | None -> "")
          | Split (Source_amount idx) -> (
              match s.split with
              | Some sp -> (match List.nth_opt sp.sources idx with Some r -> r.amount | None -> "")
              | None -> "")
          | Split (Destination_locus idx) -> (
              match s.split with
              | Some sp -> (match List.nth_opt sp.destinations idx with Some r -> r.locus | None -> "")
              | None -> "")
          | Split (Destination_amount idx) -> (
              match s.split with
              | Some sp -> (match List.nth_opt sp.destinations idx with Some r -> r.amount | None -> "")
              | None -> "")
          | Currency | Source | Destination | History -> ""))

let set_field s value =
  if s.blocked then s
  else
    match s.postings with
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
        | None -> (
            match s.focus with
            | Date -> { s with form = { s.form with day = value } }
            | Amount -> { s with form = { s.form with amount = value } }
            | Memo -> { s with form = { s.form with memo = value } }
            | Split (Source_amount idx) -> (
                match s.split with
                | None -> s
                | Some sp ->
                    let sources =
                      List.mapi
                        (fun i (r : split_row) -> if i = idx then { r with amount = value } else r)
                        sp.sources
                    in
                    let s = { s with split = Some { sp with sources } } in
                    if idx = 0 then { s with form = { s.form with amount = value } } else s)
            | Split (Destination_amount idx) -> (
                match s.split with
                | None -> s
                | Some sp ->
                    let destinations =
                      List.mapi
                        (fun i (r : split_row) -> if i = idx then { r with amount = value } else r)
                        sp.destinations
                    in
                    let s = { s with split = Some { sp with destinations } } in
                    if idx = 0 then { s with form = { s.form with amount = value } } else s)
            | Split (Source_locus _)
            | Split (Destination_locus _)
            | Currency | Source | Destination | History ->
                s))

let field_of_focus = function
  | Date -> Some Fm.Date
  | Currency -> Some Fm.Currency
  | Source -> Some Fm.Source
  | Destination -> Some Fm.Destination
  | Amount -> Some Fm.Amount
  | Memo -> Some Fm.Memo
  | History | Split _ -> None

let focus_of_field = function
  | Fm.Date -> Date
  | Fm.Currency -> Currency
  | Fm.Source -> Source
  | Fm.Destination -> Destination
  | Fm.Amount -> Amount
  | Fm.Memo -> Memo

(* Home has two regions. Field arrows never cross the region boundary. *)
let next s =
  match s.split with
  | None -> (
      match s.focus with
      | Date -> Currency
      | Currency -> Source
      | Source -> Destination
      | Destination -> Amount
      | Amount | Memo -> Memo
      | History -> Source
      | Split _ -> Source)
  | Some sp -> (
      match s.focus with
      | Date -> Currency
      | Currency -> Split (Source_locus 0)
      | Source | Destination | History -> Split (Source_locus 0)
      | Split (Source_locus i) -> Split (Source_amount i)
      | Split (Source_amount i) ->
          if i + 1 < List.length sp.sources then Split (Source_locus (i + 1))
          else Split (Destination_locus 0)
      | Split (Destination_locus j) -> Split (Destination_amount j)
      | Split (Destination_amount j) ->
          if j + 1 < List.length sp.destinations then Split (Destination_locus (j + 1))
          else Memo
      | Amount | Memo -> Memo)

let previous s =
  match s.split with
  | None -> (
      match s.focus with
      | Date | Currency -> Date
      | Source -> Currency
      | Destination -> Source
      | Amount -> Destination
      | Memo -> Amount
      | History -> Source
      | Split _ -> Source)
  | Some sp -> (
      let last_dst = max 0 (List.length sp.destinations - 1) in
      let last_src = max 0 (List.length sp.sources - 1) in
      match s.focus with
      | Date | Currency -> Date
      | Split (Source_locus 0) -> Currency
      | Split (Source_locus i) -> Split (Source_amount (i - 1))
      | Split (Source_amount i) -> Split (Source_locus i)
      | Split (Destination_locus 0) -> Split (Source_amount last_src)
      | Split (Destination_locus j) -> Split (Destination_amount (j - 1))
      | Split (Destination_amount j) -> Split (Destination_locus j)
      | Memo -> Split (Destination_amount last_dst)
      | Amount | Source | Destination | History -> Date)

let move_field s direction =
  if s.postings <> None then s
  else
    let focus = direction s in
    if focus = s.focus then s else { s with focus; record_focus = focus; cursor = None }

let switch_region s =
  if s.focus = History then { s with focus = s.record_focus }
  else { s with record_focus = s.focus; focus = History }

let text_field s =
  s.adding <> None
  || (match s.focus with
     | Split (Source_amount _) | Split (Destination_amount _) -> true
     | Split (Source_locus _) | Split (Destination_locus _) -> false
     | _ ->
         s.postings = None
         && match field_of_focus s.focus with Some fld -> Fm.is_text_field fld | None -> false)

let cursor s = Fm.cursor_pos ~value:(field s) s.cursor

let move_cursor s step =
  let value = field s in
  let next = Fm.move_cursor ~value ~cursor:s.cursor step in
  { s with cursor = Some next }

let insert_text s text =
  if s.blocked then s
  else
    let value = field s in
    let updated, next_cursor = Fm.insert_at ~value ~cursor:s.cursor text in
    let s = set_field s updated in
    { s with cursor = Some next_cursor }

let erase_before_cursor s =
  if s.blocked then s
  else
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
  else if s.blocked then s
  else if text_field s then move_cursor s step
  else
    match s.focus with
    | Split (Source_locus idx) -> (
        match s.split with
        | None -> s
        | Some sp ->
            let choices = loci s.session.book in
            let current = match List.nth_opt sp.sources idx with Some r -> r.locus | None -> "" in
            let chosen = pick choices current step in
            update_split_source_locus s idx chosen)
    | Split (Destination_locus idx) -> (
        match s.split with
        | None -> s
        | Some sp ->
            let choices = loci s.session.book in
            let current = match List.nth_opt sp.destinations idx with Some r -> r.locus | None -> "" in
            let chosen = pick choices current step in
            update_split_destination_locus s idx chosen)
    | _ ->
        if (not (editable s)) || has_amount s then
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

let add_source_row s =
  if s.blocked || not (editable s) || s.postings <> None then s
  else
    let book = s.session.book in
    let measure = s.form.measure in
    let sp =
      match s.split with
      | Some sp -> sp
      | None ->
          {
            sources = [ { locus = s.form.from_locus; amount = s.form.amount } ];
            destinations = [ { locus = s.form.to_locus; amount = s.form.amount } ];
          }
    in
    let diff = split_residual_quanta book measure sp in
    let default_amt =
      if Z.sign diff < 0 then B.format book measure (Z.abs diff) else ""
    in
    let new_row = { locus = ""; amount = default_amt } in
    let sources = sp.sources @ [ new_row ] in
    let new_idx = List.length sources - 1 in
    let next_focus = Split (Source_locus new_idx) in
    {
      s with
      split = Some { sp with sources };
      focus = next_focus;
      record_focus = next_focus;
      cursor = None;
      message = "出金元を追加しました。";
    }

let add_destination_row s =
  if s.blocked || not (editable s) || s.postings <> None then s
  else
    let book = s.session.book in
    let measure = s.form.measure in
    let sp =
      match s.split with
      | Some sp -> sp
      | None ->
          {
            sources = [ { locus = s.form.from_locus; amount = s.form.amount } ];
            destinations = [ { locus = s.form.to_locus; amount = s.form.amount } ];
          }
    in
    let diff = split_residual_quanta book measure sp in
    let default_amt =
      if Z.sign diff > 0 then B.format book measure diff else ""
    in
    let new_row = { locus = ""; amount = default_amt } in
    let destinations = sp.destinations @ [ new_row ] in
    let new_idx = List.length destinations - 1 in
    let next_focus = Split (Destination_locus new_idx) in
    {
      s with
      split = Some { sp with destinations };
      focus = next_focus;
      record_focus = next_focus;
      cursor = None;
      message = "入金先を追加しました。";
    }

let remove_split_row s =
  if s.blocked || (not (editable s)) || s.postings <> None then s
  else
    match s.split with
    | None -> s
    | Some sp -> (
        match s.focus with
        | Split (Source_locus idx) | Split (Source_amount idx) ->
            if List.length sp.sources <= 1 then { s with message = "出金元の最後の1行は削除できません。" }
            else
              let sources = List.filteri (fun i _ -> i <> idx) sp.sources in
              let next_idx = min idx (List.length sources - 1) in
              let focus = Split (Source_locus next_idx) in
              {
                s with
                split = Some { sp with sources };
                focus;
                record_focus = focus;
                cursor = None;
              }
        | Split (Destination_locus idx) | Split (Destination_amount idx) ->
            if List.length sp.destinations <= 1 then { s with message = "入金先の最後の1行は削除できません。" }
            else
              let destinations = List.filteri (fun i _ -> i <> idx) sp.destinations in
              let next_idx = min idx (List.length destinations - 1) in
              let focus = Split (Destination_locus next_idx) in
              {
                s with
                split = Some { sp with destinations };
                focus;
                record_focus = focus;
                cursor = None;
              }
        | _ -> s)

let pair = A.pair

let with_postings s draft =
  {
    s with
    postings = Some (Pe.create draft);
    split = None;
    focus = (match s.focus with Split _ -> Amount | _ -> s.focus);
    record_focus = (match s.record_focus with Split _ -> Amount | _ -> s.record_focus);
  }

let open_postings s =
  if s.adding <> None then s
  else
    match s.postings with
    | Some _ -> update_editor s (fun e -> { e with visible = true })
    | None when s.blocked -> s
    | None -> (
        let draft =
          match s.split with
          | Some sp -> Ok (split_to_draft s.form.measure sp)
          | None -> A.prepare_postings ~book:s.session.book ~mode:s.mode ~form:s.form
        in
        match draft with
        | Error "single-measure-movement-required" ->
            { s with message = "単一通貨の通常移動のみ複数行編集に対応しています。" }
        | Error "measure-scale-not-supplied" ->
            { s with message = "台帳に未登録の通貨のため、複数行編集できません。" }
        | Error why -> { s with message = Printf.sprintf "複数行入力の開始不可 (%s)。" why }
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
        split = None;
        postings = None;
        message = "編集：日付・金額・メモ。IDと科目・通貨は保持します。";
      }

let has_draft s =
  s.adding <> None || s.postings <> None || s.split <> None || s.mode <> New || has_amount s
  || s.form.memo <> ""

let keep_draft s = { s with message = "入力中の下書きがあります。Ctrl-Nで明示的に破棄してから選んでください。" }

let edit_selected s =
  if s.blocked then s
  else if has_draft s then keep_draft s
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
              split = None;
              postings = None;
              message = "予定の支払い入力。Enterで全体プレビュー。予定の元日付は保持します。";
            })

let focus_of_action_field = function
  | A.Field_date -> Date
  | A.Field_currency -> Currency
  | A.Field_source -> Source
  | A.Field_destination -> Destination
  | A.Field_amount -> Amount
  | A.Field_memo -> Memo

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
  | A.Idempotent_duplicate { session; _ } when s.adding <> None ->
      { s with session; adding = None; cursor = None; message = "科目はすでに登録されています（重複適用なし）。" }
  | A.Idempotent_duplicate { session; _ } ->
      {
        (initial ?config_home:s.config_home session) with
        theme = s.theme;
        ui_notice = s.ui_notice;
        form = { s.form with amount = ""; memo = "" };
        message = "すでに保存済みの取引です（重複適用なし・Fast-Ack）。";
      }
  | A.Conflict_lsn { expected; actual } ->
      { draft with blocked = true; pending = None; message = Printf.sprintf "別の追記がありました (LSN: 期待%d / 実際%d)。下書きは保持しています。Ctrl-Rで再読込してください。" expected actual }
  | A.Payload_drift_refused why ->
      { draft with blocked = true; message = Printf.sprintf "同一IDで異なる内容の記帳が試行されました (%s)。再送を停止。下書きは保持しています。" why }
  | A.Conflict_base_changed ->
      { draft with blocked = true; pending = None; message = "台帳の基準状態が変わりました。下書きは保持しています。Ctrl-Rで再読込して確認し直してください。" }
  | A.Conflict ->
      { draft with blocked = true; pending = None; message = "別の更新がありました。下書きは保持しています。Ctrl-Rで再読込してください。" }
  | A.Recovery_blocked ->
      { draft with blocked = true; message = A.recovery_message }
  | A.Storage_failed err ->
      { draft with blocked = true; message = Printf.sprintf "保存に失敗しました (%s)。下書きは保持しています。ディスクの空き容量や権限を確認してください。" err }
  | A.Refused why ->
      { draft with message = Printf.sprintf "記帳が拒否されました: %s。下書きは保持しています。" why }
  | A.Uncertain { message; evidence } ->
      {
        draft with
        blocked = true;
        pending = Some evidence;
        message = Printf.sprintf "書込結果が不明です (%s)。二重記帳を防ぐため再送せず、Ctrl-Rで確認してください。下書きは保持しています。" message;
      }

let finish s candidate =
  apply_commit_result s ~draft:s (A.publish_candidate ~session:s.session candidate)

let submit s =
  if s.blocked then s
  else
    match s.adding with
    | Some name ->
        let result = A.commit_add_locus ~session:s.session name in
        apply_commit_result s ~draft:s result
    | None -> (
        let content =
          match s.postings with
          | Some e -> A.Multiple { day = s.form.day; memo = s.form.memo; draft = e.draft }
          | None -> (
              match s.split with
              | Some sp ->
                  let draft = split_to_draft s.form.measure sp in
                  A.Multiple { day = s.form.day; memo = s.form.memo; draft }
              | None -> A.Single s.form)
        in
        match A.build_transaction ~book:s.session.book ~mode:s.mode content with
        | Error err ->
            let focus =
              match err.A.field with
              | Some f ->
                  if s.postings <> None || s.split <> None then s.focus
                  else focus_of_action_field f
              | None -> s.focus
            in
            { s with message = err.A.message; focus; record_focus = focus; cursor = None }
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

let handle_amount_enter s =
  if s.blocked then s
  else
    let book = s.session.book in
    let measure = s.form.measure in
    match s.split with
    | None -> submit s
    | Some sp -> (
        match s.focus with
        | Split (Source_amount _) ->
            let diff = split_residual_quanta book measure sp in
            if
              Z.sign diff > 0
              && List.length sp.destinations = 1
              && (List.hd sp.destinations).amount = ""
            then
              let (hd_dst : split_row) = List.hd sp.destinations in
              let destinations = [ { hd_dst with amount = B.format book measure diff } ] in
              let s = { s with split = Some { sp with destinations } } in
              {
                s with
                focus = Split (Destination_locus 0);
                record_focus = Split (Destination_locus 0);
                cursor = None;
              }
            else if Z.sign diff < 0 then add_source_row s
            else move_field s next
        | Split (Destination_amount _) ->
            let diff = split_residual_quanta book measure sp in
            if Z.sign diff > 0 then add_destination_row s
            else { s with focus = Memo; record_focus = Memo; cursor = None }
        | _ -> move_field s next)

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
  | A.Recovery_required (session, message) ->
      { s with session; blocked = true; message }
  | A.Reloaded session ->
      { s with session; blocked = false; message = "再読込しました。保存前の下書きは保持しています。" }
  | A.Reload_failed why ->
      { s with blocked = true; message = Printf.sprintf "再読込できません (%s)。空台帳にせず、表示と下書きを保持しています。" why }

let utf8 = O.utf8
let printable_uchar = O.printable_uchar

let locus_candidates s query = O.locus_candidates s.session.book query

let can_choose_locus s =
  (not s.blocked) && s.adding = None && editable s
  &&
  match s.overlay with
  | Loci { target = Split_source idx; _ } -> (
      match s.split with
      | Some sp -> can_change_split_locus s sp.sources idx
      | None -> false)
  | Loci { target = Split_destination idx; _ } -> (
      match s.split with
      | Some sp -> can_change_split_locus s sp.destinations idx
      | None -> false)
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
    | Split_source idx -> (
        match s.split with
        | Some sp -> (match List.nth_opt sp.sources idx with Some r -> r.locus | None -> "")
        | None -> "")
    | Split_destination idx -> (
        match s.split with
        | Some sp -> (match List.nth_opt sp.destinations idx with Some r -> r.locus | None -> "")
        | None -> "")
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

let adjust_date s step =
  let current_day = s.form.day in
  let base_day =
    if current_day = "" then F.today ()
    else
      match A.normalize_date current_day with
      | Ok canon -> canon
      | Error _ -> F.today ()
  in
  match A.shift_calendar_day base_day step with
  | Ok new_day ->
      let msg = Printf.sprintf "日付を %s に変更しました。" new_day in
      (match s.postings with
      | Some _ ->
          let s = { s with form = { s.form with day = new_day } } in
          update_editor s (fun e -> Pe.set_notice e (Some msg))
      | None ->
          { s with form = { s.form with day = new_day }; message = msg })
  | Error _ ->
      { s with message = "日付の暦日計算に失敗しました。" }

let overlay_key ~dimensions ~width_of s (button, mods) =
  match
    O.handle_key ~dimensions ~width_of ~book:s.session.book ~theme:s.theme
      ?config_home:s.config_home ~can_choose_locus:(can_choose_locus s) s.overlay
      (button, mods)
  with
  | O.Unhandled -> None
  | O.Updated overlay -> Some { s with overlay }
  | O.Closed -> Some { s with overlay = No_overlay }
  | O.Confirm_transaction _ ->
      let width, height = dimensions in
      Some (if width < 32 || height < 10 then s else confirm s)
  | O.Pay_plan _ ->
      let width, height = dimensions in
      Some
        (if width < 32 || height < 10 then s
         else
           let payment = pay_selected s in
           if payment.mode <> s.mode then { payment with overlay = No_overlay } else payment)
  | O.Theme_preview (theme, overlay) -> Some { s with theme; overlay }
  | O.Theme_saved (theme, ui_notice) -> Some { s with theme; overlay = No_overlay; ui_notice }
  | O.Pick_locus (target, id) ->
      let chosen =
        match target with
        | From_locus -> { s with form = { s.form with from_locus = id } }
        | To_locus -> { s with form = { s.form with to_locus = id } }
        | Split_source idx -> update_split_source_locus s idx id
        | Split_destination idx -> update_split_destination_locus s idx id
        | Posting_locus_at position ->
            update_editor s (fun e ->
                Pe.update_row_at e position (fun (row : R.row) -> { row with locus = id }))
      in
      Some { chosen with overlay = No_overlay }
  | O.Execute_command cmd -> (
      match cmd with
      | O.Date_today ->
          let today = F.today () in
          let s = { s with overlay = No_overlay } in
          let s =
            match s.postings with
            | Some _ ->
                let s = { s with form = { s.form with day = today } } in
                update_editor s (fun e -> Pe.set_notice e (Some ("日付を今日 (" ^ today ^ ") に設定")))
            | None ->
                let s = { s with form = { s.form with day = today } } in
                { s with message = "日付を今日 (" ^ today ^ ") に戻しました。" }
          in
          Some s
      | O.Date_prev_day ->
          let s = { s with overlay = No_overlay } in
          Some (adjust_date s (-1))
      | O.Date_next_day ->
          let s = { s with overlay = No_overlay } in
          Some (adjust_date s 1)
      | O.Theme -> Some s)

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
  | (`ASCII 't' | `ASCII 'T'), [] when e.field = Posting_day ->
      let today = F.today () in
      let s = set_field s today in
      update_editor s (fun e -> Pe.set_notice e (Some (Printf.sprintf "日付を今日 (%s) に設定" today)))
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
              Some
                (if s.adding <> None then { s with adding = None; cursor = None }
                 else if s.focus <> History then
                   { s with focus = History; record_focus = s.focus; cursor = None }
                 else s)
          | `ASCII 'r', [] when s.focus = History -> Some (switch_region s)
          | `ASCII 'n', [] when s.focus = History -> Some (switch_region s)
          | `ASCII 'j', [] when s.focus = History -> Some (select s 1)
          | `ASCII 'k', [] when s.focus = History -> Some (select s (-1))
          | `ASCII 'q', [] when s.focus = History -> None
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
          | `ASCII '+', _ | `ASCII '=', [ `Shift ] ->
              Some
                (match s.focus with
                | Source | Split (Source_locus _) | Split (Source_amount _) ->
                    add_source_row s
                | Destination | Amount | Split (Destination_locus _) | Split (Destination_amount _) ->
                    add_destination_row s
                | _ -> if text_field s then insert_text s "+" else s)
          | `ASCII '-', [] when (match s.focus with Split (Source_locus _) | Split (Destination_locus _) -> true | _ -> false) ->
              Some (remove_split_row s)
          | `Delete, [] when (match s.focus with Split _ -> true | _ -> false) ->
              Some (remove_split_row s)
          | `ASCII 'd', [ `Ctrl ] when (match s.focus with Split _ -> true | _ -> false) ->
              Some (remove_split_row s)
          | `Enter, [] ->
              Some
                (if s.adding <> None then submit s
                 else if s.focus <> History && s.postings <> None then s
                 else
                   match s.focus with
                   | Source -> open_locus_picker s From_locus
                   | Destination -> open_locus_picker s To_locus
                   | Split (Source_locus idx) -> open_locus_picker s (Split_source idx)
                   | Split (Destination_locus idx) -> open_locus_picker s (Split_destination idx)
                   | Split (Source_amount _) | Split (Destination_amount _) ->
                       handle_amount_enter s
                   | History -> (
                       match s.view with
                       | Plans -> plan_detail_selected s
                       | Entries -> detail_selected s)
                   | Date | Currency | Amount | Memo -> submit s)
          | (`ASCII 't' | `ASCII 'T'), [] when s.focus = Date && s.adding = None ->
              let today = F.today () in
              Some { (set_field s today) with cursor = None; message = Printf.sprintf "日付を今日 (%s) に戻しました。" today }
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
  | `Paste `End when s.overlay <> No_overlay || s.blocked -> Some { s with paste = None }
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
    let find_index_opt p xs =
      let rec loop i = function
        | [] -> None
        | x :: rest -> if p x then Some i else loop (i + 1) rest
      in
      loop 0 xs
    in
    let locus_catalog_lines ?(base_rows = 6) current_locus =
      let book = s.session.book in
      let measure = s.form.measure in
      let all_loci = loci book in
      let total = List.length all_loci in
      let max_allowed = height - 10 - base_rows in
      if total = 0 || max_allowed < 2 then []
      else
        let current_idx =
          match find_index_opt (fun id -> id = current_locus) all_loci with
          | Some idx -> idx
          | None -> 0
        in
        let max_slots = max 1 (min 4 (max_allowed - 1)) in
        let slots = min max_slots total in
        let start = max 0 (min (total - slots) (max 0 (current_idx - 1))) in
        let visible_loci =
          all_loci
          |> List.mapi (fun i id -> (i, id))
          |> List.filter (fun (i, _) -> i >= start && i < start + slots)
        in
        let catalog_items =
          visible_loci
          |> List.map (fun (_, id) ->
              let is_curr = (id = current_locus) in
              let mark = if is_curr then "    > " else "      " in
              let q = quantity s id in
              let label = B.label book id in
              let q_str = if q = "不明" then "" else " (" ^ q ^ " " ^ measure ^ ")" in
              let row_text = Printf.sprintf "%s%-10s %-10s%s" mark id label q_str in
              line (if is_curr then Active else Plain) row_text)
        in
        [ plain "    候補カタログ (Locus catalog): ←→:選択" ] @ catalog_items
    in
    let form_rows =
      if browsing then
        let book = s.session.book in
        let measure = s.form.measure in
        let all_loci = loci book in
        let balances =
          List.filter_map
            (fun id ->
              let q = quantity s id in
              if q = "不明" || q = "0" then None
              else Some (Printf.sprintf "%s: %s" (B.label book id) q))
            all_loci
        in
        let balance_text =
          if balances = [] then
            "残高: " ^ String.concat " │ "
              (List.filter_map
                 (fun id ->
                   let q = quantity s id in
                   if q = "不明" then None
                   else Some (Printf.sprintf "%s: %s" (B.label book id) q))
                 (List.filteri (fun i _ -> i < 3) all_loci))
          else
            "残高: " ^ String.concat " │ " (List.filteri (fun i _ -> i < 3) balances)
        in
        let balance_line = if balance_text = "残高: " then "残高: 未記録" else balance_text ^ " " ^ measure in
        let draft_summary =
          if s.postings <> None then "複数下書き保持中（r/nで再開）"
          else if s.form.amount <> "" || s.form.memo <> "" then
            Printf.sprintf "下書き保持中: %s %s %s（r/nで再開）"
              (B.label book s.form.from_locus) s.form.amount s.form.measure
          else "記帳: [r/n]キーまたはTabで開始"
        in
        [
          line Heading ("【口座残高】 " ^ balance_line);
          plain ("【状態】 " ^ draft_summary);
        ]
      else
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
        | None -> (
            match s.split with
            | Some sp ->
                let book = s.session.book in
                let measure = s.form.measure in
                let split_base_rows = 4 + List.length sp.sources + List.length sp.destinations in
                let src_lines =
                  List.mapi
                    (fun i (r : split_row) ->
                      let locus_active = s.focus = Split (Source_locus i) in
                      let amount_active = s.focus = Split (Source_amount i) in
                      let locus_label = if r.locus = "" then "（未選択）" else B.label book r.locus in
                      let amount_val =
                        if amount_active && text_field s then with_cursor r.amount else r.amount
                      in
                      let tag = Printf.sprintf "出金元 %d" (i + 1) in
                      let active = locus_active || amount_active in
                      let mark = if active then "> " else "  " in
                      let locus_display = if locus_active then "[" ^ locus_label ^ "]" else locus_label in
                      let amount_display =
                        if amount_active then "[" ^ (if amount_val = "" then " " else amount_val) ^ "]"
                        else if r.amount = "" then "—"
                        else r.amount
                      in
                      let main_line =
                        line (if active then Active else Plain)
                          (Printf.sprintf "%s%s  %s  %s %s" mark tag locus_display amount_display measure)
                      in
                      let catalog =
                        if locus_active && s.adding = None then
                          locus_catalog_lines ~base_rows:split_base_rows r.locus
                        else []
                      in
                      main_line :: catalog)
                    sp.sources
                  |> List.concat
                in
                let dst_lines =
                  List.mapi
                    (fun j (r : split_row) ->
                      let locus_active = s.focus = Split (Destination_locus j) in
                      let amount_active = s.focus = Split (Destination_amount j) in
                      let locus_label = if r.locus = "" then "（未選択）" else B.label book r.locus in
                      let amount_val =
                        if amount_active && text_field s then with_cursor r.amount else r.amount
                      in
                      let tag = Printf.sprintf "入金先 %d" (j + 1) in
                      let active = locus_active || amount_active in
                      let mark = if active then "> " else "  " in
                      let locus_display = if locus_active then "[" ^ locus_label ^ "]" else locus_label in
                      let amount_display =
                        if amount_active then "[" ^ (if amount_val = "" then " " else amount_val) ^ "]"
                        else if r.amount = "" then "—"
                        else r.amount
                      in
                      let main_line =
                        line (if active then Active else Plain)
                          (Printf.sprintf "%s%s  %s  %s %s" mark tag locus_display amount_display measure)
                      in
                      let catalog =
                        if locus_active && s.adding = None then
                          locus_catalog_lines ~base_rows:split_base_rows r.locus
                        else []
                      in
                      main_line :: catalog)
                    sp.destinations
                  |> List.concat
                in
                let residual_status =
                  let draft = split_to_draft measure sp in
                  match R.residual book draft with
                  | Error why -> "下書き差額: 計算不可 (" ^ R.format_residual_error why ^ ")"
                  | Ok n ->
                      "下書き差額: "
                      ^ B.format book measure n
                      ^ " " ^ measure
                      ^ if Z.equal n Z.zero then "（0・数量のみ整合）" else "（0でない・記帳不可）"
                in
                [
                  field Date "日付" s.form.day;
                  field Currency "通貨" s.form.measure;
                ]
                @ src_lines
                @ dst_lines
                @ [
                  field Memo "メモ" s.form.memo;
                  plain residual_status;
                ]
            | None ->
                let src_catalog =
                  if s.focus = Source && s.adding = None then locus_catalog_lines s.form.from_locus else []
                in
                let dst_catalog =
                  if s.focus = Destination && s.adding = None then locus_catalog_lines s.form.to_locus else []
                in
                [
                  field Date "日付" s.form.day;
                  field Currency "通貨" s.form.measure;
                  field Source "出金元" (B.label s.session.book s.form.from_locus);
                ]
                @ src_catalog
                @ [
                  field Destination "入金先・科目" (B.label s.session.book s.form.to_locus);
                ]
                @ dst_catalog
                @ [
                  field Amount "金額" s.form.amount;
                  field Memo "メモ" s.form.memo;
                ])
    in
    let header_and_footer_lines = 9 + List.length form_rows in
    let room = max 1 (height - header_and_footer_lines) in
    let rows =
      Br.visible_slice ~book:s.session.book (browser_of_state s) ~room
      |> List.map (fun (n, text) ->
          let active = browsing && s.selected = n in
          line (if active then Active else Plain) ((if active then "> " else "  ") ^ text))
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
                else if s.split <> None then "↑↓:項目 ←→:候補/文字位置 Enter:選択/次へ +:行追加 -:行削除 Ctrl-S:確認"
                else "↑↓:項目 ←→:候補/文字位置 Enter:選択/確認 +:出金/入金元追加 Ctrl-S:確認");
          plain
            (if browsing then ""
             else if s.postings = None && List.mem s.focus [ Source; Destination; Amount ] then
               "出金元: " ^ quantity s s.form.from_locus ^ " / 入金先: " ^ quantity s s.form.to_locus
               ^ " " ^ s.form.measure
             else if s.postings = None && s.split <> None then
               match s.focus with
               | Split (Source_locus idx) | Split (Source_amount idx) -> (
                   match s.split with
                   | Some sp -> (
                       match List.nth_opt sp.sources idx with
                       | Some r when r.locus <> "" ->
                           Printf.sprintf "出金元%d現在量: %s %s" (idx + 1) (quantity s r.locus) s.form.measure
                       | _ -> "+:行追加 -:行削除")
                   | None -> "")
               | Split (Destination_locus idx) | Split (Destination_amount idx) -> (
                   match s.split with
                   | Some sp -> (
                       match List.nth_opt sp.destinations idx with
                       | Some r when r.locus <> "" ->
                           Printf.sprintf "入金先%d現在量: %s %s" (idx + 1) (quantity s r.locus) s.form.measure
                       | _ -> "+:行追加 -:行削除")
                   | None -> "")
               | _ -> "+:行追加 -:行削除"
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
        (if s.blocked then line Status s.message
         else if browsing then plain "r/n:記帳 Tab:上下切替 ↑↓/jk:選択 Enter:詳細 Space:コマンド q:終了"
         else plain "Tab:上下 Esc:ホーム Ctrl-N:新規 Space:コマンド Ctrl-Q:終了");
      ]
