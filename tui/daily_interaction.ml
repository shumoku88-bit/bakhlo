(* Shared daily-book drafts and actions; no terminal-provider dependency.
   A draft is not a fact. Only explicit Enter requests checked publication. *)
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query
module F = Daily_file
module P = Ui_preferences

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
type locus_target = From_locus | To_locus

type locus_picker = {
  target : locus_target;
  query : string;
  selected : int;
  notice : string option;
}

type overlay =
  | No_overlay
  | Commands of int
  | Themes of { selected : int; original : P.theme }
  | Loci of locus_picker

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
  view : view;
  selected : int;
  mode : mode;
  message : string;
  blocked : bool;
  pending : string option;
  adding : string option;
  paste : (string * bool) option;
  theme : P.theme;
  overlay : overlay;
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
    focus = Amount;
    view = Entries;
    selected = 0;
    mode = New;
    message = "試用コピー。Enterで記帳、編集前は別ファイルに保管します。";
    blocked = false;
    pending = None;
    adding = None;
    paste = None;
    theme = P.load_theme ?config_home ();
    overlay = No_overlay;
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

let field s =
  match s.adding with
  | Some name -> name
  | None -> (
      match s.focus with
      | Date -> s.form.day
      | Amount -> s.form.amount
      | Memo -> s.form.memo
      | Currency | Source | Destination | History -> "")

let set_field s value =
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
      { s with form }

let next = function
  | Date -> Currency
  | Currency -> Source
  | Source -> Destination
  | Destination -> Amount
  | Amount -> Memo
  | Memo -> History
  | History -> Date

let previous = function
  | Date -> History
  | Currency -> Date
  | Source -> Currency
  | Destination -> Source
  | Amount -> Destination
  | Memo -> Amount
  | History -> Memo

let count s =
  match s.view with Entries -> List.length (entries s) | Plans -> List.length (plans s)

let select s step =
  { s with focus = History; selected = max 0 (min (max 0 (count s - 1)) (s.selected + step)) }

let change s step =
  if s.focus = History then select s step
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

let entry_form s (e : B.entry) =
  match pair e.effects with
  | None -> { s with message = "複数通貨／複数postingは保持・表示できます。この簡易入力での編集は未対応です。" }
  | Some (from_, to_) ->
      if
        e.exchange <> None || e.reversal_of <> None
        || List.exists
             (fun (row : B.entry) -> row.reversal_of = Some e.id)
             (B.entries s.session.book)
      then { s with message = "両替・返金の対応を持つ明細は、この簡易入力では編集しません。" }
      else
        let measure = mstr (D.Effect.measure from_) in
        {
          s with
          mode = Edit e;
          focus = Amount;
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

let edit_selected s =
  match s.view with
  | Entries -> (
      match List.nth_opt (entries s) s.selected with None -> s | Some e -> entry_form s e)
  | Plans -> { s with message = "予定を選んでEnterで支払い入力へ。" }

let pay_selected s =
  match List.nth_opt (plans s) s.selected with
  | None -> s
  | Some p when p.paid_by <> None -> { s with message = "この予定は支払い済みです。" }
  | Some p when p.cancelled_on <> None -> { s with message = "この予定は取消済みです。" }
  | Some p -> (
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
      | None -> { s with message = "この複数posting予定は保持・表示します。簡易支払い入力は未対応です。" }
      | Some (from_, to_) ->
          {
            s with
            mode = Pay p.id;
            focus = Amount;
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
            message = "予定の支払い入力。実際の日付・金額を確認しEnter。予定の元日付は保持します。";
          })

let finish s candidate =
  let bytes = B.to_string candidate in
  match F.publish s.session candidate with
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
          F.require (s.form.from_locus <> s.form.to_locus) "same-locus";
          let amount = get (B.parse_amount s.session.book s.form.measure s.form.amount) in
          let effects =
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
                [ effect_ s.form.from_locus (Z.neg amount); effect_ s.form.to_locus amount ]
          in
          ignore
            (get
               (match D.Movement.validate effects with
               | Ok m -> Ok m
               | Error _ -> Error "invalid-movement"));
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
          | Ok book -> finish s book)
    with
    | F.Refused why -> { s with message = "入力拒否: " ^ why }
    | Unix.Unix_error _ | Sys_error _ -> { s with message = "入出力を開始できませんでした。下書きは保持しています。" }

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

let can_choose_locus s = (not s.blocked) && s.adding = None && editable s && s.form.amount = ""

let open_locus_picker s target =
  let current = match target with From_locus -> s.form.from_locus | To_locus -> s.form.to_locus in
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

let overlay_key s (button, mods) =
  match s.overlay with
  | No_overlay -> None
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
              let form =
                match picker.target with
                | From_locus -> { s.form with from_locus = id }
                | To_locus -> { s.form with to_locus = id }
              in
              Some { s with form; overlay = No_overlay }
          | Some _ | None -> Some s)
      | `ASCII c, [] when Char.code c >= 32 && Char.code c <> 127 ->
          Some (search_loci s picker (picker.query ^ String.make 1 c))
      | `Uchar c, [] when printable_uchar c -> Some (search_loci s picker (picker.query ^ utf8 c))
      | _ -> Some s)

let is_space = function `ASCII ' ' -> true | `Uchar c -> Uchar.to_int c = 0x20 | _ -> false
let accepts_free_text s = s.adding <> None || s.focus = Memo

let key s (button, mods) =
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
      match overlay_key s (button, mods) with
      | Some s -> Some s
      | None -> (
          match (button, mods) with
          | button, [] when is_space button && not (accepts_free_text s) ->
              Some { s with overlay = Commands 0 }
          | `ASCII 'n', [ `Ctrl ] ->
              Some
                {
                  (initial ?config_home:s.config_home s.session) with
                  theme = s.theme;
                  ui_notice = s.ui_notice;
                  message = "新しい下書き。過去の不確かな試行は再送・回復しません。";
                }
          | `ASCII 'e', [ `Ctrl ] -> Some (if s.blocked then s else edit_selected s)
          | `ASCII 'r', [ `Ctrl ] -> Some (reload s)
          | `ASCII 'p', [ `Ctrl ] ->
              Some
                {
                  s with
                  view = (match s.view with Entries -> Plans | Plans -> Entries);
                  focus = History;
                  selected = 0;
                }
          | `ASCII 'a', [ `Ctrl ] ->
              Some
                (if s.blocked then s
                 else { s with adding = Some ""; message = "新しい科目名を入力しEnter（残高ゼロは作りません）。" })
          | `ASCII 'u', [ `Ctrl ] -> Some (set_field s "")
          | `Escape, [] -> Some { s with adding = None }
          | `Tab, [] -> Some { s with focus = next s.focus }
          | `Tab, [ `Shift ] -> Some { s with focus = previous s.focus }
          | `Arrow `Up, [] -> Some (select s (-1))
          | `Arrow `Down, [] -> Some (select s 1)
          | `Arrow `Left, [] -> Some (change s (-1))
          | `Arrow `Right, [] -> Some (change s 1)
          | `Backspace, [] -> Some (set_field s (backspace (field s)))
          | `Enter, [] ->
              Some
                (if s.adding <> None then submit s
                 else
                   match s.focus with
                   | Source -> open_locus_picker s From_locus
                   | Destination -> open_locus_picker s To_locus
                   | History when s.view = Plans -> pay_selected s
                   | Date | Currency | Amount | Memo | History -> submit s)
          | `ASCII c, [] when Char.code c >= 32 && Char.code c <> 127 ->
              Some (set_field s (field s ^ String.make 1 c))
          | `Uchar c, [] -> Some (set_field s (field s ^ utf8 c))
          | _ -> Some s))

let handle s (input : input) =
  match input with
  | `Key event -> key s event
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
  | `Paste `End -> (
      match s.paste with
      | None -> Some s
      | Some (text, invalid) ->
          Some
            (if invalid then { s with paste = None; message = "改行・制御キー入りの貼付を拒否しました。自動記帳しません。" }
             else set_field { s with paste = None } (field s ^ text)))
  | `End -> None
  | `Resize _ | `Mouse _ -> Some s

let quantity s locus =
  if locus = "" || s.form.measure = "" then "不明"
  else
    let coordinate : D.Effect_coordinate.t =
      {
        locus = get_id (D.Identifier.Locus.of_string locus);
        measure = get_id (D.Identifier.Measure.of_string s.form.measure);
      }
    in
    match Q.query (B.image s.session.book) coordinate with
    | Error (Q.Support_unknown _) -> "不明"
    | Ok (Q.Known_present _) -> "存在あり・金額不明"
    | Ok (Q.Exact e) -> B.format s.session.book s.form.measure (D.Quantity.quanta (Q.quantity e))

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

let overlay_screen ~dimensions:(width, height) ~width_of s =
  let panel_line = panel_line ~width_of and panel_border = panel_border ~width_of in
  match s.overlay with
  | No_overlay -> None
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
            else if s.form.amount <> "" then "閲覧のみ: 戻って金額を消すと変更できます"
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
             (match picker.target with From_locus -> "出金元" | To_locus -> "入金先・科目");
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

let screen ~frontend (width, height) s =
  let plain value = (Plain, visible value) in
  let field focus title value =
    ( (if s.focus = focus then Active else Plain),
      visible ((if s.focus = focus then "> " else "  ") ^ title ^ "  " ^ value) )
  in
  if width < 64 || height < 20 then [ plain ("Bakhlo / " ^ frontend); plain "端末を64桁×20行以上に広げてください" ]
  else
    let room = max 1 (height - 15) in
    let start = max 0 (s.selected - room + 1) in
    let rows =
      history s
      |> List.mapi (fun n text -> (n, text))
      |> List.filter (fun (n, _) -> n >= start && n < start + room)
      |> List.map (fun (n, text) ->
          let active = s.focus = History && s.selected = n in
          ((if active then Active else Plain), visible ((if active then "> " else "  ") ^ text)))
    in
    let content =
      [
        (Heading, "Bakhlo / " ^ frontend ^ " — S式の家計簿（試用）");
        plain "Tab:項目  ←→:通貨/科目  Enter:科目選択/記帳  Ctrl-N:新規  Space:コマンド";
        plain "Ctrl-P:予定/明細  予定でEnter:支払い入力  Ctrl-A:科目追加  Ctrl-R:再読込  Ctrl-Q:終了";
        plain
          (match s.mode with
          | New -> "新規記帳"
          | Edit _ -> "訂正済み明細を編集（旧版は別バックアップ）"
          | Pay _ -> "予定の支払いを記帳");
        field Date "日付" s.form.day;
        field Currency "通貨" s.form.measure;
        field Source "出金元" (B.label s.session.book s.form.from_locus);
        field Destination "入金先・科目" (B.label s.session.book s.form.to_locus);
        field Amount "金額" s.form.amount;
        field Memo "メモ" s.form.memo;
        (match s.adding with
        | Some name -> plain ("追加する科目: " ^ name)
        | None -> (Status, visible (Option.value ~default:"" s.ui_notice)));
        (Status, visible s.message);
        plain
          ("出金元: " ^ quantity s s.form.from_locus ^ " / 入金先: " ^ quantity s s.form.to_locus ^ " "
         ^ s.form.measure);
        plain
          (match s.view with
          | Entries -> "明細（↑↓で選択、Ctrl-Eで編集）"
          | Plans -> "明示された予定（↑↓、Enterで支払い入力。記録がない日は義務なしとは限りません）");
      ]
      @ if rows = [] then [ plain "記録なし" ] else rows
    in
    if s.blocked && s.overlay <> No_overlay then
      (* A centered pane must not conceal household conflict/uncertain-write warnings. *)
      content
      @ List.init (max 0 (height - List.length content - 1)) (fun _ -> plain "")
      @ [ (Status, visible s.message) ]
    else content

let self_check () =
  let require p why = F.require p why in
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
        | [ (_, text) ] -> String.starts_with ~prefix:"> " text
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
    | Some s -> s.form.amount = "" && s.focus = Amount)
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
  (* Return a deterministic Unicode/long-list renderer fixture. *)
  print_endline
    "PASS: synthetic shared record/reopen/edit, backups, plan lifecycle/payment, budget \
     publication, unknown, conflict/stale draft, focus markers, ASCII/Unicode Space, theme \
     preview/cancel/save/fallback, palette contrast, UI-only failure, locus picker and modal \
     paste.";
  { base with theme = P.Terminal; overlay = No_overlay }
