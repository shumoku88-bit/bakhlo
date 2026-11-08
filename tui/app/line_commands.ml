(* `bk r` and `bk pay`: record an Actual, or pay a plan, by answering one line at
   a time instead of opening the full-screen TUI.

     $ bk r
     Date [2026-11-08]:
     Memo: lunch
     Locus 1: wa            -> wallet (the only Locus starting with "wa")
     Amount 1 (+in / -out): -1200
     Locus 2: fo            -> food
     Amount 2 [+1,200]:     -> Enter takes what balances the rows
     Locus 3:               -> Enter ends the rows

   Each answer is a whole line, so an input method composes it as usual. The
   rules are the household core's (Record), the refusals are worded as on the
   screens (Draft), the Preview names things by display name only and the save is
   Book_file's, against the book as it was loaded: a book changed meanwhile is a
   conflict, never overwritten. Nothing is saved before the Preview is
   confirmed; end of input (Ctrl-D) leaves the book as it was. *)
module B = Bakhlo_household.Book
module R = Bakhlo_household.Record
module F = Book_file

type io = { read : unit -> string option; print : string -> unit }

exception Quit

let say io line = io.print (line ^ "\n")

let ask io ?(default = "") prompt =
  io.print (if default = "" then prompt ^ ": " else Printf.sprintf "%s [%s]: " prompt default);
  match io.read () with
  | None ->
      say io "";
      raise Quit
  | Some answer -> if String.trim answer = "" then default else String.trim answer

let money book measure q = Book_display.format_money book measure q
let signed book measure q = (if Z.sign q > 0 then "+" else "") ^ money book measure q

(* Lists are tables padded by display width (a wide character takes two cells):
   text to the left, amounts to the right, two spaces between columns. *)
type cell = Left of string | Right of string

let table rows =
  let text = function Left s | Right s -> s in
  let width = Notty_render.width_of in
  let widths = Array.make (List.fold_left (fun n row -> max n (List.length row)) 0 rows) 0 in
  List.iter (List.iteri (fun i c -> widths.(i) <- max widths.(i) (width (text c)))) rows;
  let rec trim s =
    let n = String.length s in
    if n > 0 && s.[n - 1] = ' ' then trim (String.sub s 0 (n - 1)) else s
  in
  List.map
    (fun row ->
      trim
        ("  "
        ^ String.concat "  "
            (List.mapi
               (fun i c ->
                 let gap = String.make (widths.(i) - width (text c)) ' ' in
                 match c with Left s -> s ^ gap | Right s -> gap ^ s)
               row)))
    rows

let print_table io rows = List.iter (say io) (table rows)

(* A Locus by its display name; the ID is the book's internal name, shown only
   when there is no label or another Locus has the same one. *)
let name book locus =
  let label = B.label book locus in
  let shared =
    List.exists
      (fun other -> other <> locus && B.label book other = label)
      (Option.value ~default:[] (B.approved_loci book))
  in
  if label = "" || label = locus then locus
  else if shared then label ^ " [" ^ locus ^ "]"
  else label

(* 1. Choosing a Locus: the screens' candidates (approved Loci whose ID or label
   starts with the answer, an exact ID first). One candidate is taken at once;
   several are numbered, and the next answer is a number or a longer start. *)
let rec choose_locus io book query =
  match Book_display.locus_candidates book query with
  | [ id ] -> Some id
  | id :: _ when String.lowercase_ascii id = String.lowercase_ascii query -> Some id
  | [] ->
      say io (Printf.sprintf "No Locus starts with %S." query);
      None
  | many -> (
      let shown = List.filteri (fun i _ -> i < 9) many in
      print_table io
        (List.mapi (fun i id -> [ Right (string_of_int (i + 1)); Left (name book id) ]) shown);
      if List.length many > 9 then say io "  … type more letters to narrow";
      let answer = ask io "Number or more letters" in
      match int_of_string_opt answer with
      | Some n when n >= 1 && n <= List.length shown -> Some (List.nth shown (n - 1))
      | _ -> if answer = "" then None else choose_locus io book answer)

(* 2. The rows. Each row is a Locus and a signed amount; Enter on an amount takes
   whatever balances the rows so far, and Enter on a Locus ends them (the core
   refuses rows that do not balance, in the screens' words, and they come back). Earlier rows (from a plan or a refused try) are the defaults;
   "-" removes one. *)
let balance book measure (rows : R.form_row list) =
  List.fold_left
    (fun sum (row : R.form_row) ->
      let negative, text = R.split_sign row.amount in
      match B.parse_amount book ~measure text with
      | Ok q -> Z.add sum (if negative then Z.neg q else q)
      | Error _ -> sum)
    Z.zero rows

let edit_rows io book measure (given : R.form_row list) =
  let rec row n given acc =
    let rows = List.rev acc in
    let previous, rest = match given with r :: rest -> (Some r, rest) | [] -> (None, []) in
    let default = match previous with Some (r : R.form_row) -> r.locus | None -> "" in
    let answer = ask io ~default (Printf.sprintf "Locus %d" n) in
    if answer = "-" then row n rest acc
    else if answer = "" then rows
    else
      match choose_locus io book answer with
      | None -> row n given acc
      | Some locus ->
          let rest_of_rows = Z.neg (balance book measure rows) in
          (* An earlier row keeps its amount, except the last one, which balances
             whatever was changed above it. *)
          let default =
            match previous with
            | Some r when r.amount <> "" && (rest <> [] || Z.equal rest_of_rows Z.zero) -> r.amount
            | _ -> if Z.equal rest_of_rows Z.zero then "" else signed book measure rest_of_rows
          in
          let prompt =
            if default = "" then Printf.sprintf "Amount %d (+in / -out)" n
            else Printf.sprintf "Amount %d" n
          in
          let amount = ask io ~default prompt in
          let key = Option.bind previous (fun (r : R.form_row) -> r.key) in
          row (n + 1) rest ({ R.key; locus; amount } :: acc)
  in
  row 1 given []

(* 3. Preview and save. The Preview names what is saved by display names only (the
   IDs are internal): the plan it pays, the day and memo, and each row. Enter saves. *)
let preview io book (tx : R.transaction) =
  let e = tx.entry in
  (match tx.plan with
  | None -> ()
  | Some id -> (
      match List.find_opt (fun (p : B.plan) -> p.id = id) (B.plans book) with
      | Some p -> say io ("  Pays the plan due " ^ p.day)
      | None -> say io "  Pays a plan"));
  say io (Printf.sprintf "  %s  %s" e.day (Option.value ~default:"(no memo)" e.memo));
  print_table io
    (List.map
       (fun (p : B.posting) ->
         [ Left (name book p.locus); Right (signed book p.measure p.amount); Left p.measure ])
       e.effects)

let save io (session : F.t) (tx : R.transaction) =
  let book = session.book in
  say io "";
  preview io book tx;
  say io "";
  match String.lowercase_ascii (ask io ~default:"y" "Save? (y / n / e to edit)") with
  | "y" | "yes" -> (
      match
        F.publish session [ B.Put_entry { replace = tx.replace; entry = tx.entry; plan = tx.plan } ]
      with
      | F.Written _ ->
          say io "Saved.";
          `Saved
      | F.Conflict ->
          say io "The book changed while you were typing; nothing was saved. Run it again.";
          `Stopped
      | F.Refused_input why ->
          say io ("Not saved: " ^ why);
          `Stopped
      | F.Uncertain _ ->
          say io
            "The save could not be confirmed. Do not repeat it: open the book (bk) and check \
             whether it is there.";
          `Stopped)
  | "e" | "edit" -> `Edit
  | _ ->
      say io "Nothing was saved.";
      `Stopped

let rec compose io (session : F.t) ~mode ~day ~memo ~original_amount measure rows =
  let book = session.book in
  let rows = edit_rows io book measure rows in
  let content = { R.day; memo; draft = R.form ~editing:None ~measure rows; original_amount } in
  match Draft.build_transaction ~new_id:F.new_id ~book ~mode content with
  | Error error ->
      say io error.Draft.message;
      compose io session ~mode ~day ~memo ~original_amount measure rows
  | Ok tx -> (
      match save io session tx with
      | `Edit -> compose io session ~mode ~day ~memo ~original_amount measure rows
      | (`Saved | `Stopped) as finished -> finished)

(* 4. `bk r`. A memo recorded before offers its earlier rows, newest first. *)
let earlier_rows book memo =
  let same (e : B.entry) = e.memo = Some memo in
  List.fold_left
    (fun found (e : B.entry) ->
      if List.length found >= 3 || not (same e) then found
      else
        match R.open_edit ~book e with
        | Ok draft when not (List.exists (fun (d : R.t) -> d = draft) found) -> found @ [ draft ]
        | Ok _ | Error _ -> found)
    [] (B.entries_rev book)

(* A form row's signed amount, grouped by three like the lists. *)
let signed_row book (draft : R.t) (r : R.row) =
  let sign = if r.negative then "-" else "+" in
  match B.parse_amount book ~measure:draft.measure r.amount with
  | Ok q -> sign ^ money book draft.measure q
  | Error _ -> sign ^ r.amount

let as_form_rows book (draft : R.t) =
  List.map
    (fun (r : R.row) -> { R.key = None; locus = r.locus; amount = signed_row book draft r })
    draft.rows

let record io (session : F.t) ~today =
  let book = session.book in
  let day = ask io ~default:today "Date" in
  let memo = ask io "Memo" in
  let earlier = if memo = "" then [] else earlier_rows book memo in
  let chosen =
    match earlier with
    | [] -> None
    | _ ->
        print_table io
          (List.mapi
             (fun i (d : R.t) ->
               Right (string_of_int (i + 1))
               :: List.concat_map
                    (fun (r : R.row) -> [ Left (name book r.locus); Right (signed_row book d r) ])
                    d.rows)
             earlier);
        Option.bind
          (int_of_string_opt (ask io "Same rows as before? (number, Enter for new)"))
          (fun n -> List.nth_opt earlier (n - 1))
  in
  let measure =
    match (chosen, B.measures book) with
    | Some d, _ -> d.measure
    | None, [ (only, _) ] -> only
    | None, (first, _) :: _ -> ask io ~default:first "Measure"
    | None, [] -> ""
  in
  let rows = match chosen with Some d -> as_form_rows book d | None -> [] in
  compose io session ~mode:R.New ~day ~memo ~original_amount:None measure rows

(* 5. `bk pay`. Open plans oldest first, by day, Loci and amounts (the plan's ID is
   internal and not shown); the chosen plan's rows are the defaults, so Enter
   through the Preview pays it as planned. A name narrows the list to the plans
   moving a Locus whose display name or ID starts with it. *)
let plan_cells book (p : B.plan) ~today =
  [ Left p.day ]
  @ List.concat_map
      (fun (locus, q) -> [ Left (name book locus); Right (signed book p.measure q) ])
      p.changes
  @ [ Left p.measure ]
  @ if p.day < today then [ Left "overdue" ] else []

let nothing_matches answer =
  Printf.sprintf "Nothing matches %S. Type a number or the start of a name; Ctrl-D quits." answer

let rec choose_plan io book plans ~today =
  let shown = List.filteri (fun i _ -> i < 9) plans in
  print_table io
    (List.mapi (fun i p -> Right (string_of_int (i + 1)) :: plan_cells book p ~today) shown);
  if List.length plans > 9 then say io "  … type the start of a name to narrow";
  ask_plan io book plans shown ~today

and ask_plan io book plans shown ~today =
  let answer = ask io ~default:"1" "Plan" in
  match int_of_string_opt answer with
  | Some n when n >= 1 && n <= List.length shown -> Some (List.nth shown (n - 1))
  | _ -> (
      let starts text =
        String.starts_with ~prefix:(String.lowercase_ascii answer) (String.lowercase_ascii text)
      in
      let moves (p : B.plan) =
        List.exists (fun (locus, _) -> starts locus || starts (B.label book locus)) p.changes
      in
      match List.filter moves plans with
      | [] ->
          say io (nothing_matches answer);
          ask_plan io book plans shown ~today
      | [ p ] -> Some p
      | narrowed -> choose_plan io book narrowed ~today)

let pay io (session : F.t) ~today =
  let book = session.book in
  let plans = List.stable_sort (fun (a : B.plan) b -> compare a.day b.day) (B.open_plans book) in
  match plans with
  | [] ->
      say io "No open plans.";
      `Stopped
  | _ -> (
      match choose_plan io book plans ~today with
      | None -> `Stopped
      | Some plan -> (
          match Draft.open_plan ~book plan with
          | Error why ->
              say io why;
              `Stopped
          | Ok draft -> (
              let day = ask io ~default:today "Date paid" in
              let memo = ask io "Memo" in
              let content = { R.day; memo; draft; original_amount = None } in
              let mode = R.Pay plan.id in
              match Draft.build_transaction ~new_id:F.new_id ~book ~mode content with
              | Error error ->
                  say io error.Draft.message;
                  compose io session ~mode ~day ~memo ~original_amount:None draft.measure
                    (as_form_rows book draft)
              | Ok tx -> (
                  match save io session tx with
                  | `Edit ->
                      compose io session ~mode ~day ~memo ~original_amount:None draft.measure
                        (as_form_rows book draft)
                  | (`Saved | `Stopped) as finished -> finished))))

(* 6. `bk bal` and `bk pace` print what the Balances screen (Current) and Daily
   Pace's breakdown (`?`) show, from the same configuration files, and exit. *)
let config (session : F.t) name =
  Shell_files.read_config ~config_home:None ~book_path:session.path name

let balances io (session : F.t) =
  let book = session.book in
  let account = function
    | Balance_items.Account_row { locus; measure; value; _ } ->
        let shown = name book locus in
        Some
          (match value with
          | Book_display.Exact n -> [ Left shown; Right (signed book measure n); Left measure ]
          | Book_display.Unsupported -> [ Left shown; Right "?"; Left measure; Left "unsupported" ])
    | _ -> None
  in
  (* Accounts are one table; anything else (a refused balance view) is printed as is. *)
  let rec print pending = function
    | [] -> print_table io (List.rev pending)
    | item :: rest -> (
        match account item with
        | Some row -> print (row :: pending) rest
        | None ->
            print_table io (List.rev pending);
            say io (Balance_items.balance_item_line ~width_of:Notty_render.width_of ~book item);
            print [] rest)
  in
  print []
    (Balances_screen.current_items ~book ~balance_view_text:(config session "balance-view.tsv"));
  `Stopped

let pace io (session : F.t) ~today =
  let book = session.book in
  let measure = match B.measures book with (m, _) :: _ -> m | [] -> "" in
  (match Daily_pace_screen.today_pace ~book ~measure ~today ~config:(config session) with
  | Error why -> say io ("Daily Pace unavailable: " ^ why)
  | Ok (p, start_day, end_exclusive) ->
      say io
        (Printf.sprintf "Daily Pace %s  (cycle %s .. %s, end excluded)" today start_day
           end_exclusive);
      List.iter
        (fun (_, line) -> say io line)
        (Daily_pace_why.lines ~width_of:Notty_render.width_of ~width:80 ~book p));
  `Stopped

(* 7. `bk plans`: plans in series (Schedule). `bk plans` prints each series: who
   receives, who pays, the next amount, the next and last day filled and how many
   are open, with the monitored cadence and first missing month when
   scheduled-coverage.tsv watches that series. `more` fills the coming months,
   `amount` changes the amount from a day on, `cancel` cancels chosen plans; each
   shows a Preview and saves its changes together, all or none. *)
module Sch = Bakhlo_household.Schedule
module Cov = Scheduled_coverage

let names book loci = String.concat " + " (List.map (name book) loci)

let monitoring (session : F.t) book ~today =
  match config session "scheduled-coverage.tsv" with
  | Ok (Some text) -> (
      match Cov.of_string text with
      | Error _ -> []
      | Ok rules -> (
          match Cov.project rules ~plans:(B.plans book) ~today ~months:12 with
          | Ok (_, rows) -> rows
          | Error _ -> []))
  | Ok None | Error _ -> []

let series_cells book rows ~today (plans : B.plan list) =
  let first = List.hd plans and last = List.nth plans (List.length plans - 1) in
  let shape = Sch.shape first in
  let watched = List.find_opt (fun (r : Cov.row) -> Cov.matches r.rule first) rows in
  [
    Left (names book shape.positive);
    Left (names book shape.negative);
    Right
      (match Sch.simple_amount first with Some q -> money book first.measure q | None -> "split");
    Left first.measure;
    Left first.day;
    Left last.day;
    Right (string_of_int (List.length plans));
    Left
      (String.concat ", "
         ((if first.day < today then [ "overdue" ] else [])
         @
         match watched with
         | None -> []
         | Some r ->
             Cov.cadence_label r.rule.every_months
             :: (match r.first_missing with Some m -> [ "missing " ^ m ] | None -> [])));
  ]

(* The heading names each column of a series. *)
let series_heading =
  [
    Left ""; Left "to"; Left "from"; Right "amount"; Left ""; Left "next"; Left "last"; Right "open";
  ]

let rec choose_series io book rows ~today all =
  let shown = List.filteri (fun i _ -> i < 9) all in
  print_table io
    (series_heading
    :: List.mapi (fun i s -> Right (string_of_int (i + 1)) :: series_cells book rows ~today s) shown
    );
  if List.length all > 9 then say io "  … type the start of a name to narrow";
  ask_series io book rows ~today all shown

and ask_series io book rows ~today all shown =
  let answer = ask io ~default:"1" "Series" in
  match int_of_string_opt answer with
  | Some n when n >= 1 && n <= List.length shown -> List.nth shown (n - 1)
  | _ -> (
      let starts text =
        String.starts_with ~prefix:(String.lowercase_ascii answer) (String.lowercase_ascii text)
      in
      let moves (p : B.plan) =
        List.exists (fun (locus, _) -> starts locus || starts (B.label book locus)) p.changes
      in
      match List.filter (fun s -> moves (List.hd s)) all with
      | [] ->
          say io (nothing_matches answer);
          ask_series io book rows ~today all shown
      | [ s ] -> s
      | narrowed -> choose_series io book rows ~today narrowed)

let plan_rows book plans =
  List.map
    (fun (p : B.plan) ->
      Left p.day
      :: List.concat_map
           (fun (locus, q) -> [ Left (name book locus); Right (signed book p.measure q) ])
           p.changes)
    plans

(* Saving several plan changes: a Preview, then Enter saves them together. *)
let publish_plans io (session : F.t) ~title changes rows =
  say io "";
  say io ("  " ^ title);
  print_table io rows;
  say io "";
  match String.lowercase_ascii (ask io ~default:"y" "Save? (y / n)") with
  | "y" | "yes" -> (
      match F.publish session changes with
      | F.Written _ ->
          say io "Saved.";
          `Saved
      | F.Conflict ->
          say io "The book changed while you were typing; nothing was saved. Run it again.";
          `Stopped
      | F.Refused_input why ->
          say io ("Not saved: " ^ why);
          `Stopped
      | F.Uncertain _ ->
          say io
            "The save could not be confirmed. Do not repeat it: open the book (bk) and check \
             whether it is there.";
          `Stopped)
  | _ ->
      say io "Nothing was saved.";
      `Stopped

(* Numbers like "1-3 5", or Enter for all. *)
let pick_numbers answer count =
  if String.trim answer = "" then Some (List.init count (fun i -> i + 1))
  else
    let one word =
      match String.split_on_char '-' word with
      | [ n ] -> Option.map (fun n -> [ n ]) (int_of_string_opt n)
      | [ a; b ] -> (
          match (int_of_string_opt a, int_of_string_opt b) with
          | Some a, Some b when a <= b -> Some (List.init (b - a + 1) (fun i -> a + i))
          | _ -> None)
      | _ -> None
    in
    let words = List.filter (( <> ) "") (String.split_on_char ' ' answer) in
    let picked = List.map one words in
    if List.exists Option.is_none picked then None
    else
      let numbers = List.sort_uniq compare (List.concat_map Option.get picked) in
      if List.for_all (fun n -> n >= 1 && n <= count) numbers then Some numbers else None

let rec ask_day io ~default prompt =
  match Bakhlo_household.Day.normalize (ask io ~default prompt) with
  | Ok day -> day
  | Error _ ->
      say io "Enter a real date (YYYY-MM-DD).";
      ask_day io ~default prompt

let plans_more io (session : F.t) book series rows =
  let source = List.nth series (List.length series - 1) in
  let watched = List.find_opt (fun (r : Cov.row) -> Cov.matches r.rule source) rows in
  let every =
    let default =
      match watched with
      | Some r when r.rule.every_months > 0 -> string_of_int r.rule.every_months
      | _ -> "1"
    in
    let rec months () =
      match int_of_string_opt (ask io ~default "Every how many months") with
      | Some n when n >= 1 && n <= 12 -> n
      | _ ->
          say io "Enter 1 to 12.";
          months ()
    in
    months ()
  in
  let rec count () =
    match int_of_string_opt (ask io ~default:"3" "How many more") with
    | Some n when n >= 1 && n <= 24 -> n
    | _ ->
        say io "Enter 1 to 24.";
        count ()
  in
  let count = count () in
  (* A month without the last plan's day is dated by the person, or skipped. *)
  let rec days k acc =
    if k > count then List.rev acc
    else
      match Sch.slot ~anchor:source.day ~every_months:every k with
      | None -> List.rev acc
      | Some (Sch.Dated day) -> days (k + 1) (day :: acc)
      | Some (Sch.Missing { year; month; day }) -> (
          let prompt =
            Printf.sprintf "%04d-%02d has no day %d. Date (Enter skips that month)" year month day
          in
          match ask io prompt with
          | "" -> days (k + 1) acc
          | text -> (
              match Bakhlo_household.Day.normalize text with
              | Ok date when date > source.day -> days (k + 1) (date :: acc)
              | _ ->
                  say io "Enter a real date after the last plan, or Enter to skip.";
                  days k acc))
  in
  match days 1 [] with
  | [] ->
      say io "No plans to add.";
      `Stopped
  | days ->
      let plans =
        List.map
          (fun day -> { source with B.id = F.new_id (); day; paid_by = None; cancelled_on = None })
          days
      in
      publish_plans io session ~title:"New plans"
        (List.map (fun plan -> B.Put_plan { replace = false; plan }) plans)
        (plan_rows book plans)

let plans_amount io (session : F.t) book series ~today =
  let from = ask_day io ~default:today "From" in
  match List.filter (fun (p : B.plan) -> p.day >= from) series with
  | [] ->
      say io ("No open plan in this series from " ^ from ^ ".");
      `Stopped
  | plans -> (
      let measure = (List.hd plans).measure in
      let rec amount () =
        match B.parse_amount book ~measure (ask io "New amount") with
        | Ok q -> q
        | Error _ ->
            say io "Enter a positive amount (digits grouped by three, or arithmetic).";
            amount ()
      in
      let amount = amount () in
      match Sch.change_amount plans ~amount with
      | Error "unchanged" ->
          say io "Every plan already has that amount.";
          `Stopped
      | Error _ ->
          say io "A split plan cannot be changed in bulk; change it on its own.";
          `Stopped
      | Ok changed ->
          publish_plans io session
            ~title:(Printf.sprintf "New amount %s from %s" (money book measure amount) from)
            (List.map (fun plan -> B.Put_plan { replace = true; plan }) changed)
            (List.map
               (fun (p : B.plan) ->
                 let before =
                   match List.find_opt (fun (o : B.plan) -> o.id = p.id) plans with
                   | Some o -> Option.value ~default:Z.zero (Sch.simple_amount o)
                   | None -> Z.zero
                 in
                 [
                   Left p.day;
                   Right (money book measure before);
                   Left "->";
                   Right (money book measure amount);
                   Left measure;
                 ])
               changed))

let plans_cancel io (session : F.t) book series ~today =
  print_table io
    (List.mapi (fun i row -> Right (string_of_int (i + 1)) :: row) (plan_rows book series));
  let rec chosen () =
    match
      pick_numbers
        (ask io "Cancel which? (Enter for all, or numbers like 1-3 5)")
        (List.length series)
    with
    | Some numbers -> List.map (fun n -> List.nth series (n - 1)) numbers
    | None ->
        say io "Enter numbers from the list, like 1-3 5.";
        chosen ()
  in
  let plans = chosen () in
  let day = ask_day io ~default:today "Cancelled on" in
  publish_plans io session
    ~title:(Printf.sprintf "Cancel %d plan(s) on %s" (List.length plans) day)
    (List.map (fun (p : B.plan) -> B.Cancel_plan { id = p.id; day }) plans)
    (plan_rows book plans)

let plans io (session : F.t) ~today action =
  let book = session.book in
  let rows = monitoring session book ~today in
  match Sch.series book with
  | [] ->
      say io "No open plans.";
      `Stopped
  | all -> (
      match action with
      | `List ->
          print_table io
            (series_heading
            :: List.mapi
                 (fun i s -> Right (string_of_int (i + 1)) :: series_cells book rows ~today s)
                 all);
          `Stopped
      | (`More | `Amount | `Cancel) as action -> (
          let series = choose_series io book rows ~today all in
          match action with
          | `More -> plans_more io session book series rows
          | `Amount -> plans_amount io session book series ~today
          | `Cancel -> plans_cancel io session book series ~today))

let run io command (session : F.t) ~today =
  try
    match command with
    | `Record -> record io session ~today
    | `Pay -> pay io session ~today
    | `Balances -> balances io session
    | `Pace -> pace io session ~today
    | `Plans action -> plans io session ~today action
  with Quit ->
    say io "Nothing was saved.";
    `Stopped

let terminal =
  {
    read = (fun () -> In_channel.input_line stdin);
    print =
      (fun s ->
        print_string s;
        flush stdout);
  }
