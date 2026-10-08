(* Shared daily-book drafts and actions; no terminal-provider dependency.
   Transaction input opens a preview; only its explicit confirmation publishes. *)
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query
module F = Daily_file
module P = Ui_preferences
module R = Posting_draft

let get = function Ok x -> x | Error why -> raise (F.Refused why)
let get_id = function Ok x -> x | Error D.Identifier.Empty -> raise (F.Refused "empty-identity")
let lstr = D.Identifier.Locus.to_string
let mstr = D.Identifier.Measure.to_string
let quanta p = D.Quantity.quanta (D.Effect.quantity p)

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
type view = Entries | Plans
type mode = New | Edit of B.entry | Pay of string
type posting_focus = Posting_day | Posting_memo | Posting_locus | Posting_sign | Posting_amount

type posting_editor = {
  draft : R.t;
  row : int;
  field : posting_focus;
  visible : bool;
  notice : string option;
}

type locus_target = From_locus | To_locus | Posting_locus_at of int

type locus_picker = {
  target : locus_target;
  query : string;
  selected : int;
  notice : string option;
}

type transaction = { entry : B.entry; replace : bool; plan : string option }

type overlay =
  | No_overlay
  | Commands of int
  | Themes of { selected : int; original : P.theme }
  | Loci of locus_picker
  | Preview of { transaction : transaction; base_bytes : string; scroll : int }
  | Detail of { entry : B.entry; scroll : int }
  | Plan_detail of { plan : B.plan; scroll : int }

type command = Theme

let commands = [ Theme ]
let command_label = function Theme -> "Theme"

type form = {
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
let entries s = List.rev (B.entries s.session.book)
let plans s = B.plans s.session.book

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

let backspace value =
  if value = "" then value
  else
    let rec start n = if n > 0 && Char.code value.[n] land 0xc0 = 0x80 then start (n - 1) else n in
    String.sub value 0 (start (String.length value - 1))

let editable s = match s.mode with New | Pay _ -> true | Edit _ -> false

let pick choices current step =
  let count = List.length choices in
  if count = 0 then current
  else
    let rec index n = function
      | [] -> 0
      | x :: _ when x = current -> n
      | _ :: xs -> index (n + 1) xs
    in
    List.nth choices ((index 0 choices + step + count) mod count)

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

let text_field s = s.adding <> None || (s.postings = None && List.mem s.focus [ Date; Amount; Memo ])

let cursor s =
  min (String.length (field s)) (max 0 (Option.value ~default:(String.length (field s)) s.cursor))

let move_cursor s step =
  let value = field s and at = cursor s in
  let next =
    if step < 0 then String.length (backspace (String.sub value 0 at))
    else if at = String.length value then at
    else
      let rec after n =
        if n < String.length value && Char.code value.[n] land 0xc0 = 0x80 then after (n + 1) else n
      in
      after (at + 1)
  in
  { s with cursor = Some next }

let insert_text s text =
  let value = field s and at = cursor s in
  let updated =
    set_field s (String.sub value 0 at ^ text ^ String.sub value at (String.length value - at))
  in
  { updated with cursor = Some (at + String.length text) }

let erase_before_cursor s =
  let value = field s and at = cursor s in
  let prefix = backspace (String.sub value 0 at) in
  let updated = set_field s (prefix ^ String.sub value at (String.length value - at)) in
  { updated with cursor = Some (String.length prefix) }

let count s =
  match s.view with
  | Entries -> List.length (B.entries s.session.book)
  | Plans -> List.length (plans s)

let select s step =
  { s with focus = History; selected = max 0 (min (max 0 (count s - 1)) (s.selected + step)) }

let switch_view s =
  let switched =
    {
      s with
      view = (match s.view with Entries -> Plans | Plans -> Entries);
      selected = s.other_selected;
      other_selected = s.selected;
    }
  in
  { switched with selected = min (max 0 (count switched - 1)) switched.selected }

let change s step =
  if s.adding <> None then move_cursor s step
  else if s.focus <> History && s.postings <> None then s
  else if s.focus = History then switch_view s
  else if text_field s then move_cursor s step
  else if (not (editable s)) || s.form.amount <> "" then
    { s with message = "金額入力中／編集中は通貨・科目を変えません。Ctrl-Nで新規。" }
  else
    let form =
      match s.focus with
      | Currency ->
          {
            s.form with
            measure = pick (List.map fst (B.measures s.session.book)) s.form.measure step;
          }
      | Source -> { s.form with from_locus = pick (loci s.session.book) s.form.from_locus step }
      | Destination -> { s.form with to_locus = pick (loci s.session.book) s.form.to_locus step }
      | Date | Amount | Memo | History -> s.form
    in
    { s with form }

let pair effects =
  match effects with
  | [ a; b ]
    when D.Identifier.Measure.equal (D.Effect.measure a) (D.Effect.measure b)
         && Z.sign (quanta a) * Z.sign (quanta b) = -1
         && Z.equal (Z.add (quanta a) (quanta b)) Z.zero ->
      Some (if Z.sign (quanta a) < 0 then (a, b) else (b, a))
  | [] | _ :: _ -> None

let with_postings s draft =
  {
    s with
    postings = Some { draft; row = 0; field = Posting_amount; visible = true; notice = None };
  }

let open_postings s =
  if s.adding <> None then s
  else
    match s.postings with
    | Some _ -> update_editor s (fun e -> { e with visible = true })
    | None -> (
        let draft =
          match s.mode with
          | Edit e -> (
              match R.of_effects s.session.book e.effects with
              | Error _ as error -> error
              | Ok draft ->
                  Ok
                    {
                      draft with
                      rows =
                        (match pair e.effects with
                        | None -> draft.rows
                        | Some _ ->
                            List.map
                              (fun (row : R.row) -> { row with amount = s.form.amount })
                              draft.rows);
                    })
          | New | Pay _ ->
              Ok
                {
                  R.measure = s.form.measure;
                  rows =
                    [
                      {
                        R.key = None;
                        locus = s.form.from_locus;
                        negative = true;
                        amount = s.form.amount;
                      };
                      {
                        R.key = None;
                        locus = s.form.to_locus;
                        negative = false;
                        amount = s.form.amount;
                      };
                    ];
                }
        in
        match draft with
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
  if
    e.exchange <> None || e.reversal_of <> None
    || List.exists (fun (row : B.entry) -> row.reversal_of = Some e.id) (B.entries s.session.book)
  then { s with message = "両替・返金の対応を持つ明細は、この入力では編集しません。" }
  else
    match pair e.effects with
    | None -> (
        match R.of_effects s.session.book e.effects with
        | Error why -> { s with message = "複数行編集拒否: " ^ why }
        | Ok draft ->
            with_postings
              {
                s with
                mode = Edit e;
                focus = Amount;
                record_focus = Amount;
                cursor = None;
                adding = None;
                form =
                  {
                    s.form with
                    day = e.day;
                    measure = draft.measure;
                    amount = "";
                    memo = Option.value ~default:"" e.memo;
                  };
                message = "複数行編集：日付・各金額・メモ。行構成・符号・科目・通貨・キーを保持します。";
              }
              draft)
    | Some (from_, to_) ->
        let measure = mstr (D.Effect.measure from_) in
        {
          s with
          mode = Edit e;
          focus = Amount;
          record_focus = Amount;
          cursor = None;
          adding = None;
          form =
            {
              day = e.day;
              measure;
              from_locus = lstr (D.Effect.locus from_);
              to_locus = lstr (D.Effect.locus to_);
              amount = B.format s.session.book measure (quanta to_);
              memo = Option.value ~default:"" e.memo;
            };
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
    | Some p when p.paid_by <> None -> { s with message = "この予定は支払い済みです。" }
    | Some p when p.cancelled_on <> None -> { s with message = "この予定は取消済みです。" }
    | Some _ when has_draft s -> keep_draft s
    | Some p -> (
        try
          let effects =
            List.map
              (fun (loc, n) ->
                D.Effect.create ~key:None
                  ~locus:(get_id (D.Identifier.Locus.of_string loc))
                  ~measure:(get_id (D.Identifier.Measure.of_string p.measure))
                  ~quantity:(D.Quantity.of_quanta n))
              p.changes
          in
          match pair effects with
          | None -> (
              match R.of_effects s.session.book effects with
              | Error why -> { s with message = "支払い入力拒否: " ^ why }
              | Ok draft ->
                  with_postings
                    {
                      s with
                      mode = Pay p.id;
                      focus = Amount;
                      record_focus = Amount;
                      cursor = None;
                      adding = None;
                      form =
                        {
                          s.form with
                          day = F.today ();
                          measure = p.measure;
                          amount = "";
                          memo = "";
                        };
                      message = "複数行の支払い入力。Ctrl-Sで全体プレビュー。予定の日付・内訳は保持します。";
                    }
                    draft)
          | Some (from_, to_) ->
              {
                s with
                mode = Pay p.id;
                focus = Amount;
                record_focus = Amount;
                cursor = None;
                adding = None;
                form =
                  {
                    day = F.today ();
                    measure = p.measure;
                    from_locus = lstr (D.Effect.locus from_);
                    to_locus = lstr (D.Effect.locus to_);
                    amount = B.format s.session.book p.measure (quanta to_);
                    memo = "";
                  };
                message = "予定の支払い入力。Enterで全体プレビュー。予定の元日付は保持します。";
              }
        with F.Refused why -> { s with message = "支払い入力不可: " ^ why })

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
    try
      match s.adding with
      | Some name -> (
          match B.add_locus s.session.book name with
          | Error why -> { s with message = "科目追加拒否: " ^ why }
          | Ok book -> finish s book)
      | None -> (
          let effects =
            match s.postings with
            | Some e -> get (R.effects s.session.book e.draft)
            | None -> (
                F.require (s.form.from_locus <> s.form.to_locus) "same-locus";
                let amount = get (B.parse_amount s.session.book s.form.measure s.form.amount) in
                match s.mode with
                | Edit e ->
                    List.map
                      (fun p ->
                        D.Effect.create ~key:(D.Effect.key p) ~locus:(D.Effect.locus p)
                          ~measure:(D.Effect.measure p)
                          ~quantity:
                            (D.Quantity.of_quanta
                               (if Z.sign (quanta p) < 0 then Z.neg amount else amount)))
                      e.effects
                | New | Pay _ ->
                    let effect_ loc n =
                      D.Effect.create ~key:None
                        ~locus:(get_id (D.Identifier.Locus.of_string loc))
                        ~measure:(get_id (D.Identifier.Measure.of_string s.form.measure))
                        ~quantity:(D.Quantity.of_quanta n)
                    in
                    [ effect_ s.form.from_locus (Z.neg amount); effect_ s.form.to_locus amount ])
          in
          (match D.Movement.validate effects with
          | Ok _ -> ()
          | Error _ -> raise (F.Refused "invalid-movement"));
          let memo =
            match s.mode with
            | Edit e when Option.value ~default:"" e.memo = s.form.memo -> e.memo
            | New | Pay _ | Edit _ -> if s.form.memo = "" then None else Some s.form.memo
          in
          let entry, replace, plan =
            match s.mode with
            | Edit e -> ({ e with day = s.form.day; memo; effects }, true, None)
            | New | Pay _ ->
                ( {
                    B.id = F.new_id ();
                    day = s.form.day;
                    memo;
                    effects;
                    reversal_of = None;
                    exchange = None;
                  },
                  false,
                  match s.mode with Pay id -> Some id | New | Edit _ -> None )
          in
          match B.put_entry s.session.book ~replace entry ~plan with
          | Error why -> { s with message = "記帳拒否: " ^ why }
          | Ok _ ->
              {
                s with
                overlay =
                  Preview
                    {
                      transaction = { entry; replace; plan };
                      base_bytes = s.session.bytes;
                      scroll = 0;
                    };
              })
    with
    | F.Refused why -> { s with message = "入力拒否: " ^ why }
    | Unix.Unix_error _ | Sys_error _ -> { s with message = "入出力を開始できませんでした。下書きは保持しています。" }

let confirm s =
  match s.overlay with
  | Preview { transaction = { entry; replace; plan }; base_bytes; _ } -> (
      let draft = { s with overlay = No_overlay } in
      if s.blocked then draft
      else if base_bytes <> s.session.bytes then
        { draft with blocked = true; message = "確認元が変わりました。下書きは保持。再読込して確認し直してください。" }
      else
        match B.put_entry s.session.book ~replace entry ~plan with
        | Error why -> { draft with message = "記帳拒否: " ^ why }
        | Ok book -> finish draft book)
  | No_overlay | Commands _ | Themes _ | Loci _ | Detail _ | Plan_detail _ -> s

let detail_selected s =
  match List.nth_opt (entries s) s.selected with
  | None -> s
  | Some entry -> { s with overlay = Detail { entry; scroll = 0 } }

let plan_detail_selected s =
  match List.nth_opt (plans s) s.selected with
  | None -> s
  | Some plan -> { s with overlay = Plan_detail { plan; scroll = 0 } }

let reload s =
  try
    let session = F.load s.session.path in
    match s.pending with
    | Some bytes when session.bytes = bytes ->
        {
          (initial ?config_home:s.config_home session) with
          theme = s.theme;
          ui_notice = s.ui_notice;
          message = "先ほどの記帳が現在のファイルにあります。再送しません。";
        }
    | Some _ -> { s with session; message = "現在のファイルを読みました。先ほどの書込は未確認。Ctrl-Nで下書きを破棄するまで再送を止めます。" }
    | None -> (
        match s.mode with
        | Edit _ when session.bytes <> s.session.bytes ->
            {
              s with
              session;
              blocked = true;
              message = "編集中の元ファイルが変わりました。下書きは保持。Ctrl-Nで破棄して明細を選び直してください。";
            }
        | New | Pay _ | Edit _ ->
            { s with session; blocked = false; message = "再読込しました。保存前の下書きは保持しています。" })
  with F.Refused _ | Unix.Unix_error _ | Sys_error _ ->
    { s with blocked = true; message = "再読込できません。空台帳にせず、表示と下書きを保持しています。" }

let utf8 c =
  let b = Buffer.create 4 in
  Uutf.Buffer.add_utf_8 b c;
  Buffer.contents b

let printable_uchar c =
  let n = Uchar.to_int c in
  n >= 32 && (n < 127 || n > 159)

let locus_candidates s query =
  (* Search only; identities/labels in the book are never normalized or rewritten. *)
  let query = String.lowercase_ascii query in
  let matches value = Base.String.is_substring (String.lowercase_ascii value) ~substring:query in
  List.filter (fun id -> matches id || matches (B.label s.session.book id)) (loci s.session.book)

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
let theme_at n = match List.nth_opt P.all_themes n with Some theme -> theme | None -> P.Terminal

let theme_index theme =
  let rec loop n = function
    | [] -> 0
    | candidate :: _ when candidate = theme -> n
    | _ :: rest -> loop (n + 1) rest
  in
  loop 0 P.all_themes

let cycle_index length current step = if length = 0 then 0 else (current + step + length) mod length

let entry_lines book (entry : B.entry) =
  [
    "ID: " ^ entry.id;
    "日付: " ^ entry.day;
    ("メモ: " ^ match entry.memo with None -> "（未指定）" | Some text -> "[" ^ text ^ "]");
  ]
  @ List.concat
      (List.mapi
         (fun n p ->
           let locus = lstr (D.Effect.locus p) and measure = mstr (D.Effect.measure p) in
           [
             Printf.sprintf "行%d: %s [%s]" (n + 1) (B.label book locus) locus;
             ("  "
             ^ (if Z.sign (quanta p) > 0 then "+" else "")
             ^ B.format book measure (quanta p)
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

let next_posting_field = function
  | Posting_day -> Posting_memo
  | Posting_memo -> Posting_locus
  | Posting_locus -> Posting_sign
  | Posting_sign -> Posting_amount
  | Posting_amount -> Posting_day

let previous_posting_field = function
  | Posting_day -> Posting_amount
  | Posting_memo -> Posting_day
  | Posting_locus -> Posting_memo
  | Posting_sign -> Posting_locus
  | Posting_amount -> Posting_sign

let editor_key s e (button, mods) =
  let notice text = update_editor s (fun e -> { e with notice = Some text }) in
  let move step =
    update_editor s (fun e ->
        { e with row = max 0 (min (max 0 (List.length e.draft.rows - 1)) (e.row + step)) })
  in
  let focus f = update_editor s (fun e -> { e with field = f e.field }) in
  let add () =
    if s.blocked then s
    else if not (editable s) then notice "編集中は行構成・科目・符号・キーを保持します"
    else
      update_editor s (fun e ->
          {
            e with
            draft =
              {
                e.draft with
                rows =
                  e.draft.rows @ [ { R.key = None; locus = ""; negative = false; amount = "" } ];
              };
            row = List.length e.draft.rows;
            field = Posting_locus;
            notice = None;
          })
  in
  let remove () =
    if s.blocked then s
    else if not (editable s) then notice "編集中は既存の行を削除しません"
    else
      update_editor s (fun e ->
          let rows = List.filteri (fun n _ -> n <> e.row) e.draft.rows in
          {
            e with
            draft = { e.draft with rows };
            row = min e.row (max 0 (List.length rows - 1));
            notice = None;
          })
  in
  let sign negative =
    if s.blocked then s
    else if not (editable s) then notice "編集中は符号を保持します"
    else update_posting_row s (fun row -> { row with negative })
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

let quantity s locus =
  if locus = "" || s.form.measure = "" then "不明"
  else
    match (D.Identifier.Locus.of_string locus, D.Identifier.Measure.of_string s.form.measure) with
    | Ok locus_id, Ok measure_id -> (
        let coordinate : D.Effect_coordinate.t = { locus = locus_id; measure = measure_id } in
        match Q.query (B.image s.session.book) coordinate with
        | Error (Q.Support_unknown _) -> "不明"
        | Ok (Q.Known_present _) -> "存在あり・金額不明"
        | Ok (Q.Exact e) ->
            B.format s.session.book s.form.measure (D.Quantity.quanta (Q.quantity e)))
    | Error _, _ | _, Error _ -> "不明"

let posting_text book p =
  B.label book (lstr (D.Effect.locus p))
  ^ ":"
  ^ B.format book (mstr (D.Effect.measure p)) (quanta p)
  ^ " "
  ^ mstr (D.Effect.measure p)

let history s =
  match s.view with
  | Entries ->
      List.map
        (fun (e : B.entry) ->
          e.day ^ " "
          ^ String.concat " / " (List.map (posting_text s.session.book) e.effects)
          ^ (match e.memo with None -> "" | Some text -> "  " ^ text)
          ^
          if e.reversal_of <> None then " [返金・取消対応]" else if e.exchange <> None then " [両替]" else "")
        (entries s)
  | Plans ->
      List.map
        (fun (p : B.plan) ->
          p.day ^ " "
          ^ (match p.cancelled_on with
            | Some day -> "[取消 " ^ day ^ "] "
            | None -> if p.paid_by = None then "[未払い] " else "[支払い済] ")
          ^ String.concat " / "
              (List.map
                 (fun (loc, n) ->
                   B.label s.session.book loc ^ ":"
                   ^ B.format s.session.book p.measure n
                   ^ " " ^ p.measure)
                 p.changes))
        (plans s)

type style = Plain | Active | Heading | Status | Panel | Panel_heading | Panel_active

let panel_width = 34

(* The renderer supplies cell measurement, not layout or interaction policy.
   Clip only at UTF-8 scalar boundaries and mark clipping explicitly. *)
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

let posting_status s e =
  match R.residual s.session.book e.draft with
  | Error why -> "下書き差額不明: " ^ why
  | Ok n ->
      "下書き差額: "
      ^ B.format s.session.book e.draft.measure n
      ^ " " ^ e.draft.measure
      ^ if Z.equal n Z.zero then "（0・数量のみ整合）" else "（0でない・記帳不可）"

let posting_line book n (row : R.row) measure =
  Printf.sprintf "%d %s%s %s %s [%s]" (n + 1)
    (if row.negative then "-" else "+")
    row.amount measure (B.label book row.locus) row.locus

let posting_panel ~dimensions:(width, height) ~width_of s e =
  let width = max 4 (min 76 (width - 4)) in
  let line = panel_line ~width ~width_of in
  let active field = if e.field = field then Panel_active else Panel in
  let slots = min 6 (max 1 (height - 14)) in
  let start = max 0 (e.row - slots + 1) in
  let row_focus =
    match e.field with
    | Posting_locus | Posting_sign | Posting_amount -> true
    | Posting_day | Posting_memo -> false
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
              ^ posting_line s.session.book n row e.draft.measure))
  in
  let chosen = List.nth_opt e.draft.rows e.row in
  let field_name =
    match e.field with
    | Posting_day -> "日付"
    | Posting_memo -> "メモ"
    | Posting_locus -> "科目"
    | Posting_sign -> "符号（← - / → +）"
    | Posting_amount -> "金額（正の値）"
  in
  [
    panel_border ~width ~width_of "複数posting下書き";
    line (active Posting_day) ("日付: " ^ s.form.day);
    line Panel ("通貨: " ^ e.draft.measure ^ "（固定・換算しません）");
    line (active Posting_memo) ("メモ: " ^ s.form.memo);
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
            ^ quantity { s with form = { s.form with measure = e.draft.measure } } row.locus);
      line Panel
        ("キー: "
        ^
        match chosen with
        | None -> "—"
        | Some { R.key = None; _ } -> "未指定（無名posting）"
        | Some { R.key = Some key; _ } -> D.Identifier.Effect_key.to_string key);
      line Panel (posting_status s e);
      line Panel (if s.blocked then s.message else Option.value ~default:s.message e.notice);
      line Panel "Tab:欄 ↑↓:行 Enter:科目/次欄 Ctrl-S:確認";
      line Panel "Ctrl-A:行追加 Ctrl-D:削除 Esc:閉じて保持";
      panel_bottom ~width ();
    ]

let overlay_screen ~dimensions:((width, height) as dimensions) ~width_of s =
  let panel_line = panel_line ~width_of and panel_border = panel_border ~width_of in
  match s.overlay with
  | No_overlay -> (
      match s.postings with
      | Some e when e.visible -> Some (posting_panel ~dimensions ~width_of s e)
      | Some _ | None -> None)
  | (Preview _ | Detail _ | Plan_detail _) as overlay ->
      let title, lines, scroll, hint =
        match overlay with
        | Preview p ->
            ( "取引全体の確認",
              preview_lines s.session.book p.transaction,
              p.scroll,
              "Ctrl-S:確定して保存  Esc:編集へ戻る" )
        | Detail d ->
            ("明細詳細（閲覧のみ）", entry_lines s.session.book d.entry, d.scroll, "Esc:一覧へ戻る（下書き保持）")
        | Plan_detail d ->
            ( "予定詳細",
              plan_lines s.session.book d.plan,
              d.scroll,
              if d.plan.paid_by <> None || d.plan.cancelled_on <> None then "Esc:一覧へ戻る（支払い不可）"
              else if s.blocked then "書込み停止中 / Esc:一覧へ戻る"
              else if has_draft s then "下書き保持中 / Escで戻りCtrl-Nで破棄してから支払い"
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
      let candidates = locus_candidates s picker.query in
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
                  ^ B.label s.session.book id ^ " [" ^ id ^ "]"))
      in
      let chosen = List.nth_opt candidates selected in
      let notice =
        match picker.notice with
        | Some text -> text
        | None ->
            if s.blocked then "閲覧のみ: 書込停止中。下書きは保持します"
            else if not (editable s) then "閲覧のみ: 編集中の科目は保持します"
            else if not (can_choose_locus s) then "閲覧のみ: 戻って金額を消すと変更できます"
            else "選択は下書きのみ。まだ記帳しません"
      in
      let count_text =
        match B.approved_loci s.session.book with
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
              | Some id -> "現在量: " ^ quantity s id ^ " " ^ s.form.measure);
            line Panel notice;
            line Panel
              (if can_choose_locus s then "↑↓ 選択  Enter 確定  Esc 戻る" else "↑↓ 閲覧  Esc 戻る（選択変更不可）");
            line Panel "文字検索 / Backspace / Ctrl-U 消去";
            panel_bottom ~width ();
          ])

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
  (* Return a deterministic Unicode/long-list renderer fixture. *)
  print_endline
    "PASS: synthetic shared record/reopen/edit, backups, plan lifecycle/payment, budget \
     publication, unknown, conflict/stale draft, focus markers, ASCII/Unicode Space, theme \
     preview/cancel/save/fallback, palette contrast, UI-only failure, locus picker and modal \
     paste.";
  { base with theme = P.Terminal; overlay = No_overlay }
