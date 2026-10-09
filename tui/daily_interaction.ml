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
  | New_transaction

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
  browser : Br.model;
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
  candidate_selected : int option;
}

let loci book = match B.approved_loci book with Some xs -> xs | None -> []
let head = function x :: _ -> x | [] -> ""
let entries s = Br.entries s.session.book
let plans s = Br.plans s.session.book

let browser_of_state s =
  let b = s.browser in
  let b = if b.view <> s.view then { b with view = s.view } else b in
  match s.view with
  | Entries ->
      if b.entries_selected <> s.selected then
        { b with entries_selected = s.selected; selected_entry_id = None }
      else b
  | Plans ->
      if b.plans_selected <> s.selected then
        { b with plans_selected = s.selected; selected_plan_id = None; plans_initialized = true }
      else b

let apply_browser s action =
  let cur_b = browser_of_state s in
  let b = Br.apply_action ~book:s.session.book cur_b action in
  {
    s with
    browser = b;
    view = b.view;
    selected = Br.selected_index b;
    other_selected = (match b.view with Entries -> b.plans_selected | Plans -> b.entries_selected);
  }

let initial ?(focus = Source) ?config_home session =
  let recovery_notice = A.recovery_notice ~session in
  let choices = loci session.F.book in
  let from_locus = head choices
  and to_locus = head (match choices with [] -> [] | _ :: xs -> xs) in
  let browser = Br.initial in
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
    focus;
    record_focus = (if focus = History then Source else focus);
    cursor = None;
    view = browser.view;
    selected = Br.selected_index browser;
    other_selected = 0;
    browser;
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
    candidate_selected = None;
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
    if focus = s.focus then { s with candidate_selected = None }
    else { s with focus; record_focus = focus; cursor = None; candidate_selected = None }

let candidates_for_state s =
  match s.focus with
  | Currency -> List.map fst (B.measures s.session.book)
  | Source | Destination -> loci s.session.book
  | Split (Source_locus _) | Split (Destination_locus _) -> loci s.session.book
  | _ -> []

let current_candidate_value s =
  match s.focus with
  | Currency -> s.form.measure
  | Source -> s.form.from_locus
  | Destination -> s.form.to_locus
  | Split (Source_locus i) ->
      (match s.split with Some sp -> (match List.nth_opt sp.sources i with Some r -> r.locus | None -> "") | None -> "")
  | Split (Destination_locus j) ->
      (match s.split with Some sp -> (match List.nth_opt sp.destinations j with Some r -> r.locus | None -> "") | None -> "")
  | _ -> ""

let apply_candidate s value =
  match s.focus with
  | Currency -> { s with form = { s.form with measure = value } }
  | Source -> { s with form = { s.form with from_locus = value } }
  | Destination -> { s with form = { s.form with to_locus = value } }
  | Split (Source_locus i) -> update_split_source_locus s i value
  | Split (Destination_locus j) -> update_split_destination_locus s j value
  | _ -> s

let switch_region s =
  if s.focus = History then { s with focus = s.record_focus; candidate_selected = None }
  else { s with record_focus = s.focus; focus = History; candidate_selected = None }

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
        match Br.selected_entry ~book:s.session.book (browser_of_state s) with
        | None -> s
        | Some e -> entry_form s e)
    | Plans -> { s with message = "予定を選んでEnterで詳細、詳細から支払い入力へ。" }

let pay_selected s =
  if s.blocked then s
  else
    match Br.selected_plan ~book:s.session.book (browser_of_state s) with
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
      let browser = Br.sync_selection ~book:session.F.book (browser_of_state s) in
      {
        (initial ?config_home:s.config_home session) with
        focus = History;
        record_focus = Source;
        theme = s.theme;
        ui_notice = s.ui_notice;
        browser;
        view = browser.view;
        selected = Br.selected_index browser;
        other_selected = (match browser.view with Entries -> browser.plans_selected | Plans -> browser.entries_selected);
        form = { s.form with amount = ""; memo = "" };
        message = "書込みを確認しました（試用）。修正前のコピーも保管しました。";
      }
  | A.Idempotent_duplicate { session; _ } when s.adding <> None ->
      { s with session; adding = None; cursor = None; message = "科目はすでに登録されています（重複適用なし）。" }
  | A.Idempotent_duplicate { session; _ } ->
      let browser = Br.sync_selection ~book:session.F.book (browser_of_state s) in
      {
        (initial ?config_home:s.config_home session) with
        focus = History;
        record_focus = Source;
        theme = s.theme;
        ui_notice = s.ui_notice;
        browser;
        view = browser.view;
        selected = Br.selected_index browser;
        other_selected = (match browser.view with Entries -> browser.plans_selected | Plans -> browser.entries_selected);
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
      let browser = Br.sync_selection ~book:session.F.book (browser_of_state s) in
      {
        s with
        session;
        browser;
        view = browser.view;
        selected = Br.selected_index browser;
        other_selected = (match browser.view with Entries -> browser.plans_selected | Plans -> browser.entries_selected);
        blocked = false;
        message = "再読込しました。保存前の下書きは保持しています。";
      }
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
  if s.blocked then s
  else
    let current_day = s.form.day in
    let base_day_res =
      if current_day = "" then Ok (F.today ())
      else
        match A.normalize_date current_day with
        | Ok canon when A.is_valid_canonical_date canon -> Ok canon
        | _ -> Error (`Invalid_date current_day)
    in
    match base_day_res with
    | Error (`Invalid_date raw) ->
        let msg =
          Printf.sprintf
            "日付の形式が不正なため移動できません (%s)。日付欄 (YYYY-MM-DD) を修正してください。"
            raw
        in
        (match s.postings with
        | Some _ -> update_editor s (fun e -> Pe.set_notice e (Some msg))
        | None -> { s with message = msg })
    | Ok base_day -> (
        match A.shift_calendar_day base_day step with
        | Ok new_day ->
            let msg = Printf.sprintf "日付を %s に変更しました。" new_day in
            (match s.postings with
            | Some _ ->
                let s = { s with form = { s.form with day = new_day } } in
                update_editor s (fun e -> Pe.set_notice e (Some msg))
            | None ->
                { s with form = { s.form with day = new_day }; message = msg })
        | Error "date-out-of-range" ->
            let msg = "日付の許容範囲 (0001-01-01 〜 9999-12-31) を超えるため移動できません。" in
            (match s.postings with
            | Some _ -> update_editor s (fun e -> Pe.set_notice e (Some msg))
            | None -> { s with message = msg })
        | Error _ ->
            let msg = "日付の暦日計算に失敗しました。" in
            (match s.postings with
            | Some _ -> update_editor s (fun e -> Pe.set_notice e (Some msg))
            | None -> { s with message = msg }))

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
      | O.New_transaction ->
          let s = { s with overlay = No_overlay; focus = s.record_focus } in
          Some s
      | O.Date_today ->
          let s = { s with overlay = No_overlay } in
          if s.blocked then Some s
          else
            let today = F.today () in
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
  let b = browser_of_state s in
  {
    (initial ?config_home:s.config_home s.session) with
    theme = s.theme;
    ui_notice = s.ui_notice;
    browser = b;
    view = b.view;
    selected = Br.selected_index b;
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
      if s.blocked then s
      else
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
              Some (if s.focus = History || s.postings <> None then s else submit { s with candidate_selected = None })
          | `ASCII 'u', [ `Ctrl ] ->
              Some (if text_field s then { (set_field s "") with cursor = None } else s)
          | `Escape, [] ->
              Some
                (if s.candidate_selected <> None then { s with candidate_selected = None }
                 else if s.adding <> None then { s with adding = None; cursor = None }
                 else if s.focus <> History then
                   { s with focus = History; record_focus = s.focus; cursor = None; candidate_selected = None }
                 else s)
          | `ASCII 'r', [] when s.focus = History -> Some (switch_region s)
          | `ASCII 'n', [] when s.focus = History -> Some (switch_region s)
          | `ASCII 'j', [] when s.focus = History -> Some (select s 1)
          | `ASCII 'k', [] when s.focus = History -> Some (select s (-1))
          | `ASCII 'q', [] when s.focus = History -> None
          | `Tab, [] | `Tab, [ `Shift ] ->
              Some (if s.adding <> None then s else switch_region s)
          | `Arrow `Up, [] when s.focus = History ->
              Some (if s.adding <> None then s else select s (-1))
          | `Arrow `Up, [] ->
              Some (if s.adding <> None then s else move_field s previous)
          | `Arrow `Down, [] when s.focus = History ->
              Some (if s.adding <> None then s else select s 1)
          | `Arrow `Down, [] ->
              Some (if s.adding <> None then s else move_field s next)
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
          | `Arrow `Left, [] when s.focus = History -> Some (switch_view s)
          | `Arrow `Right, [] when s.focus = History -> Some (switch_view s)
          | `Arrow `Left, [] -> Some (change s (-1))
          | `Arrow `Right, [] -> Some (change s 1)
          | `Backspace, [] ->
              Some (if text_field s then erase_before_cursor s else s)
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
          | `Enter, [] -> (
              if s.adding <> None then Some (submit s)
              else if s.focus = History then
                Some (match s.view with Plans -> plan_detail_selected s | Entries -> detail_selected s)
              else
                match s.focus with
                | Source -> Some (open_locus_picker s From_locus)
                | Destination -> Some (open_locus_picker s To_locus)
                | Split (Source_locus idx) -> Some (open_locus_picker s (Split_source idx))
                | Split (Destination_locus idx) -> Some (open_locus_picker s (Split_destination idx))
                | Split (Source_amount _) | Split (Destination_amount _) ->
                    Some (handle_amount_enter s)
                | Currency | Date | Amount | Memo ->
                    Some (submit s)
                | History -> Some s)
          | (`ASCII 't' | `ASCII 'T'), [] when s.focus = Date && s.adding = None ->
              if s.blocked then Some s
              else
                let today = F.today () in
                Some { (set_field s today) with cursor = None; message = Printf.sprintf "日付を今日 (%s) に戻しました。" today }
          | `ASCII c, [] when Char.code c >= 32 && Char.code c <> 127 ->
              Some (if text_field s then insert_text s (String.make 1 c) else s)
          | `Uchar c, [] ->
              Some (if text_field s then insert_text s (utf8 c) else s)
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

let try_read_file path =
  try
    if Sys.file_exists path && not (Sys.is_directory path) then
      let ic = open_in_bin path in
      let len = in_channel_length ic in
      let bytes = really_input_string ic len in
      close_in ic;
      Some bytes
    else None
  with _ -> None

let load_file_content candidates =
  let rec loop = function
    | [] -> None
    | None :: rest -> loop rest
    | Some path :: rest -> (
        match try_read_file path with
        | Some content -> Some content
        | None -> loop rest)
  in
  loop candidates

let parse_daily_pace_tsv ~measure content =
  let lines = String.split_on_char '\n' content in
  let parse_line line =
    let line = String.trim line in
    if line = "" || String.starts_with ~prefix:"#" line then None
    else
      let parts =
        String.split_on_char '\t' line
        |> List.map String.trim
        |> List.filter (fun s -> s <> "")
      in
      let parts =
        match parts with
        | [ locus; m ] -> Some (locus, m)
        | _ -> (
            let parts2 =
              String.split_on_char ' ' line
              |> List.map String.trim
              |> List.filter (fun s -> s <> "")
            in
            match parts2 with
            | [ locus; m ] -> Some (locus, m)
            | _ -> None)
      in
      match parts with
      | Some (locus, m) when String.lowercase_ascii m = String.lowercase_ascii measure -> (
          match (D.Identifier.Locus.of_string locus, D.Identifier.Measure.of_string measure) with
          | Ok locus_id, Ok measure_id ->
              Some ({ locus = locus_id; measure = measure_id } : D.Effect_coordinate.t)
          | _ -> None)
      | _ -> None
  in
  let coords = List.filter_map parse_line lines in
  let rec dedup acc = function
    | [] -> List.rev acc
    | c :: rest ->
        if List.exists (fun (x : D.Effect_coordinate.t) -> D.Effect_coordinate.equal x c) acc then
          dedup acc rest
        else
          dedup (c :: acc) rest
  in
  let unique_coords = dedup [] coords in
  if unique_coords = [] then None else Some unique_coords

let parse_boundary_window ~today content =
  let lines = String.split_on_char '\n' content in
  let rec find_window = function
    | start_d :: end_d :: rest ->
        if start_d <= today && today < end_d then Some (start_d, end_d)
        else find_window (end_d :: rest)
    | _ -> None
  in
  let rec check_lines = function
    | [] -> None
    | line :: rest ->
        let line = String.trim line in
        if line = "" || String.starts_with ~prefix:"#" line then check_lines rest
        else
          let tokens =
            String.split_on_char '\t' line
            |> List.map String.trim
            |> List.filter (fun s -> s <> "")
          in
          let dates =
            match tokens with
            | _preset :: ds -> ds
            | [] -> []
          in
          match find_window dates with
          | Some (s, e) -> Some (s, e)
          | None -> check_lines rest
  in
  check_lines lines

let budget_window ~book ~measure ~today =
  match B.budgets book with
  | None -> None
  | Some budgets -> (
      let matching =
        List.filter
          (fun (b : B.budget) ->
            b.measure = measure && b.start_day <= today && today < b.end_exclusive)
          budgets
      in
      match matching with
      | b :: _ -> Some (b.start_day, b.end_exclusive)
      | [] -> None)

let load_balance_view_loci s =
  let session_dir = Filename.dirname s.session.F.path in
  let candidates =
    [
      Option.map (fun h -> Filename.concat h "balance-view.tsv") s.config_home;
      Some (Filename.concat session_dir "balance-view.tsv");
      Some (Filename.concat session_dir "config/balance-view.tsv");
    ]
  in
  match load_file_content candidates with
  | Some content ->
      let lines = String.split_on_char '\n' content in
      let parse_line line =
        let line = String.trim line in
        if line = "" || String.starts_with ~prefix:"#" line then None
        else
          match String.split_on_char '\t' line with
          | locus :: _ when locus <> "" -> Some locus
          | _ -> None
      in
      let loci = List.filter_map parse_line lines in
      if loci = [] then None else Some loci
  | None -> None

let primary_account_loci s =
  let book = s.session.book in
  let all_loci = loci book in
  match load_balance_view_loci s with
  | Some bv_loci ->
      let matched = List.filter (fun id -> List.mem id all_loci) bv_loci in
      if matched <> [] then matched else all_loci
  | None -> (
      let session_dir = Filename.dirname s.session.F.path in
      let pace_candidates =
        [
          Option.map (fun h -> Filename.concat h "daily-pace.tsv") s.config_home;
          Some (Filename.concat session_dir "daily-pace.tsv");
          Some (Filename.concat session_dir "config/daily-pace.tsv");
        ]
      in
      let pace_loci =
        match load_file_content pace_candidates with
        | Some content -> (
            match parse_daily_pace_tsv ~measure:s.form.measure content with
            | Some coords ->
                Some (List.map (fun (c : D.Effect_coordinate.t) -> D.Identifier.Locus.to_string c.locus) coords)
            | None -> None)
        | None -> None
      in
      match pace_loci with
      | Some p_loci when p_loci <> [] ->
          let matched = List.filter (fun id -> List.mem id all_loci) p_loci in
          if matched <> [] then matched else all_loci
      | _ -> (
          let expense_set =
            match B.budgets book with
            | Some budgets -> List.concat_map (fun (b : B.budget) -> b.expense_loci) budgets
            | None -> []
          in
          let non_expense = List.filter (fun id -> not (List.mem id expense_set)) all_loci in
          if non_expense <> [] then non_expense else all_loci))

let summary_balances ~width_of ~max_width s =
  let book = s.session.book in
  let account_loci = primary_account_loci s in
  let measures = List.map fst (B.measures book) in
  let balances =
    List.filter_map
      (fun id ->
        let label = B.label book id in
        let locus_balances =
          List.filter_map
            (fun m ->
              let q = O.quantity ~book ~measure:m id in
              if q = "不明" || q = "0" then None
              else Some (q ^ " " ^ m))
            measures
        in
        match locus_balances with
        | [] -> (
            let primary_m = s.form.measure in
            let q = O.quantity ~book ~measure:primary_m id in
            if q = "存在あり・金額不明" then Some (label ^ ": 金額不明")
            else if q = "不明" then Some (label ^ ": 不明")
            else None)
        | xs -> Some (label ^ ": " ^ String.concat ", " xs))
      account_loci
  in
  let text =
    if balances = [] then
      let sample =
        List.filter_map
          (fun id ->
            let label = B.label book id in
            let q = O.quantity ~book ~measure:s.form.measure id in
            if q = "不明" then Some (label ^ ": 不明")
            else Some (label ^ ": " ^ q ^ " " ^ s.form.measure))
          (List.filteri (fun i _ -> i < 3) account_loci)
      in
      if sample = [] then "未記録" else String.concat " │ " sample
    else
      String.concat " │ " balances
  in
  clip_text ~width_of max_width text

let summary_daily_pace s =
  let measure = s.form.measure in
  let today = s.form.day in
  let session_dir = Filename.dirname s.session.F.path in
  let pool_candidates =
    [
      Option.map (fun h -> Filename.concat h "daily-pace.tsv") s.config_home;
      Some (Filename.concat session_dir "daily-pace.tsv");
      Some (Filename.concat session_dir "config/daily-pace.tsv");
    ]
  in
  let window_candidates =
    [
      Option.map (fun h -> Filename.concat h "boundary-presets.tsv") s.config_home;
      Some (Filename.concat session_dir "boundary-presets.tsv");
      Some (Filename.concat session_dir "config/boundary-presets.tsv");
    ]
  in
  let pool_opt =
    match load_file_content pool_candidates with
    | Some content -> parse_daily_pace_tsv ~measure content
    | None -> None
  in
  let window_opt =
    match load_file_content window_candidates with
    | Some content -> (
        match parse_boundary_window ~today content with
        | Some w -> Some w
        | None -> budget_window ~book:s.session.book ~measure ~today)
    | None -> budget_window ~book:s.session.book ~measure ~today
  in
  match (pool_opt, window_opt) with
  | None, _ | _, None ->
      ("未設定", "未設定")
  | Some pool, Some (start_d, end_exclusive) -> (
      match B.daily_pace s.session.book ~measure ~pool ~observed_at:today ~end_exclusive with
      | Ok pace ->
          let pace_str = Printf.sprintf "%s %s/日" (B.format s.session.book measure pace.daily_pace_quanta) measure in
          let period_str = Printf.sprintf "%s 〜 %s (残%d日)" pace.observed_at pace.end_exclusive pace.remaining_days in
          (pace_str, period_str)
      | Error why ->
          let err_str = Printf.sprintf "計算不可 (%s)" why in
          let period_str = Printf.sprintf "%s 〜 %s" start_d end_exclusive in
          (err_str, period_str))

let summary_next_scheduled s =
  let book = s.session.book in
  let today = s.form.day in
  let open_plans =
    B.plans book
    |> List.filter (fun (p : B.plan) -> B.plan_is_open p)
    |> List.sort (fun (a : B.plan) (b : B.plan) ->
        let c = String.compare a.day b.day in
        if c <> 0 then c else String.compare a.id b.id)
  in
  let upcoming = List.filter (fun (p : B.plan) -> p.day >= today) open_plans in
  match upcoming with
  | p :: _ ->
      let amt_summary =
        match p.changes with
        | (locus, amt) :: _ ->
            Printf.sprintf " %s %s%s %s" (B.label book locus)
              (if Z.sign amt > 0 then "+" else "")
              (B.format book p.measure amt) p.measure
        | [] -> ""
      in
      Printf.sprintf "%s [%s]%s" p.day p.id amt_summary
  | [] -> (
      let overdue = List.filter (fun (p : B.plan) -> p.day < today) open_plans in
      match overdue with
      | p :: _ -> Printf.sprintf "期限超過あり (%s [%s])" p.day p.id
      | [] -> "なし")

let summary_lines ~width_of ~width ~height s =
  let line style value = (style, clip_text ~width_of width value) in
  let plain = line Plain in
  let max_w = max 20 (width - 16) in
  let balance_str = summary_balances ~width_of ~max_width:max_w s in
  let pace_str, period_str = summary_daily_pace s in
  let next_plan_str = summary_next_scheduled s in
  let is_compact = width < 80 || height < 24 in
  if is_compact then
    [
      line Heading ("【残高】 " ^ balance_str);
      plain (Printf.sprintf "【ペース】 %s (%s)  【予定】 %s" pace_str period_str next_plan_str);
    ]
  else
    [
      line Heading ("【口座残高】 " ^ balance_str);
      plain (Printf.sprintf "【デイリーペース】 %s    【計算対象期間】 %s" pace_str period_str);
      plain ("【次回予定】 " ^ next_plan_str);
    ]

let floating_create_editor ~dimensions:(width, height) ~width_of s =
  let pane_width = max 32 (min 76 (width - 4)) in
  let pane_height =
    let slots = min 8 (max 1 (height - 11)) in
    slots + 9
  in
  let line style text = panel_line ~width:pane_width ~width_of style text in
  if width < 32 || height < 10 then
    [
      line Panel "端末を32桁×10行以上に広げてください";
      line Panel "Esc:戻る / 保存しません";
    ]
  else
    let title =
      match s.mode with
      | New -> "新規記帳 (Floating Create Editor)"
      | Edit e -> Printf.sprintf "明細訂正 [%s]" e.id
      | Pay id -> Printf.sprintf "予定の支払い [%s]" id
    in
    let border_top = panel_border ~width:pane_width ~width_of title in
    let with_cursor value =
      let at = cursor s in
      let len = String.length value in
      let at = max 0 (min len at) in
      String.sub value 0 at ^ "|" ^ String.sub value at (len - at)
    in
    let field focus title value =
      let is_active = s.adding = None && s.focus = focus in
      if is_active then
        let val_disp = if text_field s then with_cursor value else value in
        (true, line Panel_active (Printf.sprintf "> %s  %s" title val_disp))
      else
        (false, line Panel (Printf.sprintf "  %s  %s" title value))
    in
    let catalog_rows target_locus =
      if height < 16 then []
      else
        let all_loci = loci s.session.book in
        let total = List.length all_loci in
        if total = 0 then []
        else
          let current_idx =
            let rec loop i = function
              | [] -> 0
              | x :: rest -> if x = target_locus then i else loop (i + 1) rest
            in
            loop 0 all_loci
          in
          let slots = min 3 total in
          let start = max 0 (min (total - slots) (max 0 (current_idx - 1))) in
          [ (false, line Panel "    候補カタログ (Locus catalog): Enter:詳細選択") ]
          @ (all_loci
            |> List.mapi (fun i id -> (i, id))
            |> List.filter (fun (i, _) -> i >= start && i < start + slots)
            |> List.map (fun (i, id) ->
                let is_curr = (id = target_locus) || (target_locus = "" && i = current_idx) in
                let mark = if is_curr then "    * " else "      " in
                let q = quantity s id in
                let label = B.label s.session.book id in
                let q_str = if q = "不明" || q = "" then "" else " (" ^ q ^ " " ^ s.form.measure ^ ")" in
                let text = Printf.sprintf "%s%-8s %-8s%s" mark id label q_str in
                (false, line (if is_curr then Panel_heading else Panel) text)))
    in
    let form_fields =
      match s.split with
      | Some sp ->
          let book = s.session.book in
          let measure = s.form.measure in
          let d_active, d_line = field Date "日付" s.form.day in
          let c_active, c_line = field Currency "通貨" s.form.measure in
          let src_lines =
            List.mapi
              (fun i (r : split_row) ->
                let locus_active = s.focus = Split (Source_locus i) in
                let amount_active = s.focus = Split (Source_amount i) in
                let active = locus_active || amount_active in
                let locus_label = if r.locus = "" then "（未選択）" else B.label book r.locus in
                let amt_val = if amount_active && text_field s then with_cursor r.amount else r.amount in
                let tag = Printf.sprintf "出金元 %d" (i + 1) in
                let locus_display = if locus_active then "[" ^ locus_label ^ "]" else locus_label in
                let amt_display = if amount_active then "[" ^ (if amt_val = "" then " " else amt_val) ^ "]" else if r.amount = "" then "—" else r.amount in
                let row_text = Printf.sprintf "%s%s  %s  %s %s" (if active then "> " else "  ") tag locus_display amt_display measure in
                let st = if active then Panel_active else Panel in
                let cats = if locus_active && s.adding = None then catalog_rows r.locus else [] in
                (active, line st row_text) :: cats)
              sp.sources
            |> List.concat
          in
          let dst_lines =
            List.mapi
              (fun j (r : split_row) ->
                let locus_active = s.focus = Split (Destination_locus j) in
                let amount_active = s.focus = Split (Destination_amount j) in
                let active = locus_active || amount_active in
                let locus_label = if r.locus = "" then "（未選択）" else B.label book r.locus in
                let amt_val = if amount_active && text_field s then with_cursor r.amount else r.amount in
                let tag = Printf.sprintf "入金先 %d" (j + 1) in
                let locus_display = if locus_active then "[" ^ locus_label ^ "]" else locus_label in
                let amt_display = if amount_active then "[" ^ (if amt_val = "" then " " else amt_val) ^ "]" else if r.amount = "" then "—" else r.amount in
                let row_text = Printf.sprintf "%s%s  %s  %s %s" (if active then "> " else "  ") tag locus_display amt_display measure in
                let st = if active then Panel_active else Panel in
                let cats = if locus_active && s.adding = None then catalog_rows r.locus else [] in
                (active, line st row_text) :: cats)
              sp.destinations
            |> List.concat
          in
          let m_active, m_line = field Memo "メモ" s.form.memo in
          let residual_status =
            let draft = split_to_draft measure sp in
            match R.residual book draft with
            | Error why -> "下書き差額: 計算不可 (" ^ R.format_residual_error why ^ ")"
            | Ok n ->
                "下書き差額: " ^ B.format book measure n ^ " " ^ measure
                ^ if Z.equal n Z.zero then "（0・数量のみ整合）" else "（0でない・記帳不可）"
          in
          [ (d_active, d_line); (c_active, c_line) ]
          @ src_lines
          @ dst_lines
          @ [ (m_active, m_line); (false, line Panel residual_status) ]
      | None ->
          let d_active, d_line = field Date "日付" s.form.day in
          let c_active, c_line = field Currency "通貨" s.form.measure in
          let s_active, s_line = field Source "出金元" (B.label s.session.book s.form.from_locus) in
          let s_cats = if s.focus = Source && s.adding = None then catalog_rows s.form.from_locus else [] in
          let t_active, t_line = field Destination "入金先・科目" (B.label s.session.book s.form.to_locus) in
          let t_cats = if s.focus = Destination && s.adding = None then catalog_rows s.form.to_locus else [] in
          let a_active, a_line = field Amount "金額" s.form.amount in
          let m_active, m_line = field Memo "メモ" s.form.memo in
          [ (d_active, d_line); (c_active, c_line); (s_active, s_line) ]
          @ s_cats
          @ [ (t_active, t_line) ]
          @ t_cats
          @ [ (a_active, a_line); (m_active, m_line) ]
    in
    let adding_lines =
      match s.adding with
      | Some name -> [ line Panel_active ("追加する科目: " ^ with_cursor name ^ " (Enter:追加 Esc:取消)") ]
      | None -> []
    in
    let bal_hint =
      if s.postings = None && List.mem s.focus [ Source; Destination; Amount ] then
        Printf.sprintf "出金元: %s / 入金先: %s %s" (quantity s s.form.from_locus) (quantity s s.form.to_locus) s.form.measure
      else ""
    in
    let status_text =
      if s.blocked then s.message
      else if s.message <> "" then s.message
      else if bal_hint <> "" then bal_hint
      else ""
    in
    let hint_lines =
      [
        line Panel "Tab/↑↓:項目移動  ←→:カーソル  Enter:候補選択/次へ";
        line Panel "Ctrl-S:確認保存  Esc:閉じる  Ctrl-N:新規  Ctrl-T:複数行";
      ]
    in
    let fixed_bottom_lines =
      (if status_text <> "" then [ line (if s.blocked then Panel_active else Panel) status_text ] else [ line Panel "" ])
      @ hint_lines
    in
    let available_slots = max 4 (pane_height - 2 - List.length adding_lines - List.length fixed_bottom_lines) in
    let total_fields = List.length form_fields in
    let visible_field_lines =
      if total_fields <= available_slots then
        let actual = List.map snd form_fields in
        let pad_count = available_slots - total_fields in
        let padding = List.init pad_count (fun _ -> line Panel "") in
        actual @ padding
      else
        let active_idx =
          let rec find_idx i = function
            | [] -> 0
            | (is_active, _) :: rest -> if is_active then i else find_idx (i + 1) rest
          in
          find_idx 0 form_fields
        in
        let start = max 0 (min (total_fields - available_slots) (max 0 (active_idx - available_slots / 2))) in
        form_fields
        |> List.filteri (fun i _ -> i >= start && i < start + available_slots)
        |> List.map snd
    in
    [ border_top ]
    @ adding_lines
    @ visible_field_lines
    @ fixed_bottom_lines
    @ [ panel_bottom ~width:pane_width () ]

let overlay_screen ~dimensions ~width_of s =
  match s.overlay with
  | No_overlay when s.focus <> History -> (
      match s.postings with
      | Some e when e.visible ->
          Some (posting_panel ~dimensions ~width_of s e)
      | _ ->
          Some (floating_create_editor ~dimensions ~width_of s))
  | _ ->
      O.overlay_screen ~dimensions ~width_of ~book:s.session.book
        ~day:s.form.day ~measure:s.form.measure ~memo:s.form.memo
        ~blocked:s.blocked ~editable:(editable s)
        ~can_choose_locus:(can_choose_locus s) ~message:s.message
        ~has_draft:(has_draft s) ?postings:s.postings s.overlay

let screen ?(width_of = String.length) ~frontend (width, height) s =
  let line style value = (style, clip_text ~width_of width value) in
  let plain = line Plain in
  let browsing = s.focus = History in
  if width < 64 || height < 20 then
    let rows = [ plain ("Bakhlo / " ^ frontend); plain "端末を64桁×20行以上に広げてください" ] in
    if s.blocked then
      rows @ List.init (max 0 (height - 3)) (fun _ -> plain "") @ [ line Status s.message ]
    else
      rows @ List.init (max 0 (height - List.length rows)) (fun _ -> plain "")
  else
    let title_row = line Heading ("Bakhlo / " ^ frontend ^ " — S式の家計簿（試用）") in
    let summary_rows = summary_lines ~width_of ~width ~height s in
    let workspace_heading =
      line
        (if browsing then Active else Heading)
        ((if browsing then "> " else "  ")
        ^ "閲覧 (Workspace) — "
        ^ (match s.view with Entries -> "【明細】  予定" | Plans -> "明細  【予定】")
        ^ " "
        ^ String.make (max 0 (width - 32)) '-')
    in
    let status_rows =
      (if s.message <> "" then [ line Status s.message ] else [])
      @ (match s.ui_notice with Some n when n <> "" -> [ line Status n ] | _ -> [])
    in
    let footer =
      if s.blocked then line Status s.message
      else if browsing then
        plain "←→:表示切替  ↑↓/jk:選択  Enter:詳細  Ctrl-E:編集  r/n:新規  Space:コマンド  q:終了"
      else if s.postings <> None then
        plain "Ctrl-T:複数行入力へ戻る（下書き保持）  Tab:上下切替  Esc:閉じる"
      else
        plain "Tab:上下切替  ↑↓:項目移動  Enter:候補選択/確認  Ctrl-S:保存  Esc:閉じる"
    in
    let fixed_count = 1 + List.length summary_rows + 1 + List.length status_rows + 1 in
    let room = max 1 (height - fixed_count) in
    let rows =
      Br.visible_slice ~book:s.session.book (browser_of_state s) ~room
      |> List.map (fun (n, text) ->
          let active = browsing && s.selected = n in
          line (if active then Active else Plain) ((if active then "> " else "  ") ^ text))
    in
    let workspace_rows = if rows = [] then [ plain "記録なし" ] else rows in
    let top_and_workspace =
      [ title_row ]
      @ summary_rows
      @ [ workspace_heading ]
      @ workspace_rows
      @ status_rows
    in
    let pad_count = max 0 (height - List.length top_and_workspace - 1) in
    let padding = List.init pad_count (fun _ -> plain "") in
    let full = top_and_workspace @ padding @ [ footer ] in
    if List.length full = height then full
    else if List.length full > height then
      let kept = List.filteri (fun i _ -> i < height - 1) full in
      kept @ [ footer ]
    else
      full @ List.init (height - List.length full) (fun _ -> plain "")
