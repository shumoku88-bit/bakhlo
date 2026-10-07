(* Shared daily-book drafts and actions; no terminal-provider dependency.
   A draft is not a fact. Only explicit Enter requests checked publication. *)
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query
module F = Daily_file

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
}

let loci book = match B.approved_loci book with Some xs -> xs | None -> []
let head = function x :: _ -> x | [] -> ""
let entries s = List.rev (B.entries s.session.book)
let plans s = B.plans s.session.book

let initial session =
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
        (initial session) with
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
        { (initial session) with message = "先ほどの記帳が現在のファイルにあります。再送しません。" }
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

let key s (button, mods) =
  (* Notty decodes control bytes as upper-case ASCII; plain memo text is untouched. *)
  let button =
    match (button, mods) with `ASCII c, [ `Ctrl ] -> `ASCII (Char.lowercase_ascii c) | _ -> button
  in
  match s.paste with
  | Some (text, invalid) -> (
      match (button, mods) with
      | `ASCII c, [] when Char.code c >= 32 && Char.code c <> 127 ->
          Some { s with paste = Some (text ^ String.make 1 c, invalid) }
      | `Uchar c, [] -> Some { s with paste = Some (text ^ utf8 c, invalid) }
      | _ -> Some { s with paste = Some (text, true) })
  | None -> (
      match (button, mods) with
      | `ASCII 'q', [ `Ctrl ] -> None
      | `ASCII 'n', [ `Ctrl ] ->
          Some { (initial s.session) with message = "新しい下書き。過去の不確かな試行は再送・回復しません。" }
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
            (if s.adding = None && s.focus = History && s.view = Plans then pay_selected s
             else submit s)
      | `ASCII c, [] when Char.code c >= 32 && Char.code c <> 127 ->
          Some (set_field s (field s ^ String.make 1 c))
      | `Uchar c, [] -> Some (set_field s (field s ^ utf8 c))
      | _ -> Some s)

let handle s (input : input) =
  match input with
  | `Key event -> key s event
  | `Paste `Start -> Some { s with paste = Some ("", false) }
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

type style = Plain | Active | Heading | Status

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
    [
      (Heading, "Bakhlo / " ^ frontend ^ " — S式の家計簿（試用）");
      plain "Tab:項目  ←→:通貨/科目  Enter:記帳  Ctrl-N:新規  Ctrl-E:編集";
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
      plain (match s.adding with None -> "" | Some name -> "追加する科目: " ^ name);
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

let self_check () =
  let require p why = F.require p why in
  let directory = "scratch/daily-tui-check-" ^ F.new_id () in
  Unix.mkdir directory 0o700;
  let path = directory ^ "/book.sexp" in
  F.create_copy ~source:"examples/daily-book.sexp" ~target:path;
  let s = initial (F.load path) in
  require (quantity s "wallet" = "1000" && quantity s "bank" = "不明") "initial-quantity";
  let before = F.read path in
  let invalid = submit { s with form = { s.form with amount = "0" } } in
  require (F.read path = before && invalid.form.amount = "0") "invalid-wrote-or-lost-draft";
  let s =
    submit { s with form = { s.form with day = "2026-10-03"; amount = "100"; memo = "架空の記帳" } }
  in
  require (quantity s "wallet" = "900" && List.length (B.entries s.session.book) = 1) "append";
  let reopened = initial (F.load path) in
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
  let stale = initial (F.load path) in
  let latest = submit { stale with form = { stale.form with amount = "1"; memo = "架空の別更新" } } in
  let conflict = submit { stale with form = { stale.form with amount = "2"; memo = "架空の競合" } } in
  require
    (conflict.blocked && conflict.form.amount = "2" && (F.load path).bytes = latest.session.bytes)
    "conflict";
  let editing = edit_selected latest in
  let next_write =
    submit { (initial (F.load path)) with form = { stale.form with amount = "1" } }
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
  let plan_state = initial (F.load plan_path) in
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
  print_endline
    "PASS: synthetic shared record/reopen/edit, backups, plan lifecycle/payment, budget \
     publication, unknown, conflict/stale draft, focus markers and paste controls.";
  s
