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

type command =
  [ `Record
  | `Pay
  | `Balances
  | `Pace
  | `Plans of [ `List | `More | `Amount | `Cancel ]
  | `Find of string list
  | `Last of string list
  | `Edit of string list
  | `Date of string list
  | `Refund of string list
  | `Shop of string list
  | `Check
  | `Loci of [ `List | `Add | `Name | `Role ]
  | `Pace_pool
  | `Pace_cycle
  | `Pace_if of string list
  | `Pace_target
  | `Fx
  | `Todo of [ `List | `Add | `Done | `Drop ]
  | `Register of string list
  | `Month of string list
  | `Report_ie of string list
  | `Day of string list ]

exception Quit

let say io line = io.print (line ^ "\n")

(* Book's refusals in words; the codes stay Book's (one place for the wording). *)
let not_saved why =
  "Not saved: "
  ^
  match why with
  | "merchant-token" -> "a shop name is one word, without spaces or tabs."
  | "merchant-classified" -> "this record's shop is already set."
  | "merchant-unknown" | "unknown-entry" -> "the record is no longer in the book."
  | "unknown-plan" -> "the plan is no longer in the book."
  | "plan-already-paid" -> "the plan is already paid."
  | "plan-cancelled" -> "the plan is cancelled."
  | "invalid-date" -> "that is not a real date."
  | "locus-unapproved" -> "an account is hidden or not in the book."
  | why when String.starts_with ~prefix:"entry-admission" why ->
      "the book refuses this record (" ^ why ^ ")."
  | why -> why

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
  let width = Width.of_string in
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

(* 1. Choosing one of several, the same way for every kind (an account, a plan, a
   series, a record, a matter), as qemacs completes every kind of name in one
   minibuffer:

     1  2026-11-05  Bank  -80,000  Food   +80,000  jpy  overdue
     2  2026-11-20  Bank   -3,000  Water   +3,000  jpy
     Plan [1]: wa       -> only the plan moving Water is left, and is taken

   An item is one or more lines; its number stands on the first. The first nine
   are numbered and Enter takes the first. Any other answer narrows
   the list by [narrow] ([by] says how to the household); one match is taken at
   once, none asks again. *)
let rec choose io ~what ~by ?heading ~cells ~narrow items =
  let shown = List.filteri (fun i _ -> i < 9) items in
  print_table io
    (Option.to_list heading
    @ List.concat
        (List.mapi
           (fun i item ->
             List.mapi
               (fun j line -> (if j = 0 then Right (string_of_int (i + 1)) else Left "") :: line)
               (cells item))
           shown));
  if List.length items > 9 then say io ("  … type " ^ by ^ " to narrow");
  let rec answer () =
    let text = ask io ~default:"1" what in
    match int_of_string_opt text with
    | Some n when n >= 1 && n <= List.length shown -> List.nth shown (n - 1)
    | _ -> (
        match narrow text items with
        | Error why ->
            say io why;
            answer ()
        | Ok [] ->
            say io (Printf.sprintf "Nothing matches %S. Type a number or %s; Ctrl-D quits." text by);
            answer ()
        | Ok [ item ] -> item
        | Ok narrowed -> choose io ~what ~by ?heading ~cells ~narrow narrowed)
  in
  answer ()

(* Text that starts a name, ignoring case. *)
let starts text name =
  String.starts_with ~prefix:(String.lowercase_ascii text) (String.lowercase_ascii name)

(* A Locus: the screens' candidates (approved Loci whose ID or label starts with
   the answer), an exact ID taken at once. *)
let locus_matches book query =
  match Book_display.locus_candidates book query with
  | id :: _ when String.lowercase_ascii id = String.lowercase_ascii query -> [ id ]
  | candidates -> candidates

let choose_locus io book query =
  match locus_matches book query with
  | [] ->
      say io (Printf.sprintf "No Locus starts with %S." query);
      None
  | [ id ] -> Some id
  | many ->
      Some
        (choose io ~what:"Account" ~by:"more letters"
           ~cells:(fun id -> [ [ Left (name book id) ] ])
           ~narrow:(fun text _ -> Ok (locus_matches book text))
           many)

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
       e.effects);
  match e.original_amount with
  | Some (m, q) -> say io (Printf.sprintf "  original amount %s %s" (money book m q) m)
  | None -> ()

(* What a save tells the household, the same for every command. *)
let published io = function
  | F.Written session ->
      say io "Saved.";
      `Saved session
  | F.Conflict ->
      say io "The book changed while you were typing; nothing was saved. Run it again.";
      `Stopped
  | F.Refused_input why ->
      say io (not_saved why);
      `Stopped
  | F.Uncertain _ ->
      say io
        "The save could not be confirmed. Do not repeat it: open the book (bk) and check whether \
         it is there.";
      `Stopped

let save io (session : F.t) (tx : R.transaction) =
  let book = session.book in
  say io "";
  preview io book tx;
  say io "";
  let question =
    if tx.replace then "Save? (y / n / e to edit)"
    else "Save? (y / n / e to edit / o for the original amount)"
  in
  match String.lowercase_ascii (ask io ~default:"y" question) with
  | "o" when (not tx.replace) && tx.plan = None -> (
      let others =
        List.filter
          (fun (m, _) -> not (List.exists (fun (p : B.posting) -> p.measure = m) tx.entry.effects))
          (B.measures book)
      in
      let default = match others with (m, _) :: _ -> m | [] -> "" in
      let measure = ask io ~default "Original Measure (what was paid in)" in
      match List.assoc_opt measure (B.measures book) with
      | None ->
          say io ("The book has no Measure " ^ measure ^ ".");
          `Edit
      | Some scale -> (
          match
            Bakhlo_household.Amount.parse_positive ~decimals:scale (ask io "Original amount")
          with
          | Ok q -> `Original (measure, q)
          | Error _ ->
              say io "Enter a positive amount in that Measure.";
              `Edit))
  | "y" | "yes" ->
      let put = B.Put_entry { replace = tx.replace; entry = tx.entry; plan = tx.plan } in
      published io (F.publish session [ put ])
  | "e" | "edit" -> `Edit
  | _ ->
      say io "Nothing was saved.";
      `Stopped

(* Rows are edited, then reviewed: a refusal or `e` edits them again, `o` adds the
   original amount and reviews the same rows again. *)
let rec compose io (session : F.t) ~mode ~day ~memo ~original_amount measure rows =
  let rows = edit_rows io session.book measure rows in
  review io session ~mode ~day ~memo ~original_amount measure rows

and review io (session : F.t) ~mode ~day ~memo ~original_amount measure rows =
  let book = session.book in
  let editing = match mode with R.Edit e -> Some e | R.New | R.Pay _ -> None in
  let content = { R.day; memo; draft = R.form ~editing ~measure rows; original_amount } in
  match Draft.build_transaction ~new_id:F.new_id ~book ~mode content with
  | Error error ->
      say io error.Draft.message;
      compose io session ~mode ~day ~memo ~original_amount measure rows
  | Ok tx -> (
      match save io session tx with
      | `Edit -> compose io session ~mode ~day ~memo ~original_amount measure rows
      | `Original original ->
          review io session ~mode ~day ~memo ~original_amount:(Some original) measure rows
      | (`Saved _ | `Stopped) as finished -> finished)

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

(* A correction keeps each row's key (Record drops it when the Locus changes); a
   new record copied from earlier rows starts without keys. *)
let as_form_rows ?(keys = false) book (draft : R.t) =
  List.map
    (fun (r : R.row) ->
      { R.key = (if keys then r.key else None); locus = r.locus; amount = signed_row book draft r })
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

(* A plan is narrowed by the start of a Locus it moves. *)
let moves book text (p : B.plan) =
  List.exists (fun (locus, _) -> starts text locus || starts text (B.label book locus)) p.changes

let choose_plan io book plans ~today =
  choose io ~what:"Plan" ~by:"the start of a name"
    ~cells:(fun p -> [ plan_cells book p ~today ])
    ~narrow:(fun text plans -> Ok (List.filter (moves book text) plans))
    plans

let pay io (session : F.t) ~today =
  let book = session.book in
  let plans = List.stable_sort (fun (a : B.plan) b -> compare a.day b.day) (B.open_plans book) in
  match plans with
  | [] ->
      say io "No open plans.";
      `Stopped
  | _ -> (
      let plan = choose_plan io book plans ~today in
      match Draft.open_plan ~book plan with
      | Error why ->
          say io why;
          `Stopped
      | Ok draft ->
          let day = ask io ~default:today "Date paid" in
          let memo = ask io "Memo" in
          review io session ~mode:(R.Pay plan.id) ~day ~memo ~original_amount:None draft.measure
            (as_form_rows book draft))

(* 6. `bk bal` and `bk pace` print what the Balances screen (Current) and Daily
   Pace's breakdown (`?`) show, from the same configuration files, and exit. *)
let config (session : F.t) name = Config.read ~book_path:session.path name

let balances io (session : F.t) =
  let book = session.book in
  (* balance-view.tsv chooses the rows; without it, every offered Locus in every Measure. *)
  let rows =
    match config session "balance-view.tsv" with
    | Error why -> Error why
    | Ok None ->
        let measures = List.map fst (B.measures book) in
        Ok
          (List.concat_map
             (fun l -> List.map (fun m -> (l, m)) measures)
             (Option.value ~default:[] (B.approved_loci book)))
    | Ok (Some text) ->
        Result.map
          (List.map (fun (c : Balance_view_data.coordinate) -> (c.locus, c.measure)))
          (Balance_view_data.of_string text)
  in
  (match rows with
  | Error why -> say io ("balance-view.tsv cannot be read: " ^ why)
  | Ok rows ->
      print_table io
        ([ Left "account"; Right "balance"; Left "" ]
        :: List.map
             (fun (locus, measure) ->
               match Book_display.quantity_value ~book ~measure locus with
               | Book_display.Exact n ->
                   [ Left (name book locus); Right (money book measure n); Left measure ]
               | Book_display.Unsupported ->
                   [ Left (name book locus); Right "?"; Left measure; Left "unsupported" ])
             rows));
  `Stopped

(* Why today's pace is what it is: the pool balances and what each rests on, the
   plans protected before the cycle ends, and the division. Only the terms of the
   same Book.daily_pace answer; no arithmetic of its own. *)
let why io book (p : B.daily_pace) =
  let fmt q = money book p.measure q in
  let support (c : B.coordinate) =
    match B.quantity book ~locus:c.locus ~measure:c.measure with
    | Some { support = Zero_origin; _ } -> "recorded history"
    | Some { support = Opening _; _ } -> "opening balance"
    | Some { support = Counted _; _ } -> "observed"
    | None -> "unsupported"
  in
  let pool = List.stable_sort (fun (_, a) (_, b) -> Z.compare b a) p.pool_balances in
  let pool_loci = List.map (fun ((c : B.coordinate), _) -> c.locus) p.pool_balances in
  let plan id = List.find_opt (fun (plan : B.plan) -> plan.id = id) (B.plans book) in
  let deductions =
    List.stable_sort
      (fun (a, _) (b, _) ->
        let day id = match plan id with Some (p : B.plan) -> p.day | None -> "" in
        compare (day a) (day b))
      p.plan_deductions
  in
  (* What a protected plan pays into: its receiving Loci outside the pool. *)
  let payee id =
    match plan id with
    | None -> ""
    | Some (plan : B.plan) ->
        String.concat " + "
          (List.filter_map
             (fun (l, q) ->
               if Z.sign q > 0 && not (List.mem l pool_loci) then Some (name book l) else None)
             plan.changes)
  in
  say io (Printf.sprintf " Today %s: %s %s/day" p.observed_at (fmt p.daily_pace_quanta) p.measure);
  say io
    (Printf.sprintf " = %s free ÷ %d days left (cycle ends %s, exclusive)"
       (fmt p.available_through_end) p.remaining_days p.end_exclusive);
  say io "";
  print_table io
    ([
       Left "Pool";
       Right (fmt p.eligible_pool);
       Left (Printf.sprintf "%d balances" (List.length pool));
     ]
     :: List.map
          (fun (c, q) -> [ Left ("  " ^ name book c.B.locus); Right (fmt q); Left (support c) ])
          pool
    @ [ [ Left "" ] ]
    @ [
        Left "Protected Scheduled";
        Right ("-" ^ fmt p.automatic_deductions);
        Left (Printf.sprintf "%d before cycle end" (List.length deductions));
      ]
      ::
      (match deductions with
      | [] -> [ [ Left "  (none)" ] ]
      | _ ->
          List.map
            (fun (id, q) ->
              let day = match plan id with Some (pl : B.plan) -> pl.day | None -> "" in
              [
                Left
                  ("  "
                  ^ (if String.length day > 5 then String.sub day 5 5 else day)
                  ^ "  " ^ payee id);
                Right (fmt q);
                Left (if day <> "" && day < p.observed_at then "overdue, still open" else "");
              ])
            deductions)
    @ [ [ Left "" ]; [ Left "Free through cycle end"; Right (fmt p.available_through_end) ] ])

let pace io (session : F.t) ~today =
  let book = session.book in
  let measure = match B.measures book with (m, _) :: _ -> m | [] -> "" in
  (match Pace.today ~book ~measure ~today ~config:(config session) with
  | Error why -> say io ("Daily Pace unavailable: " ^ why)
  | Ok (p, start_day, end_exclusive) ->
      say io
        (Printf.sprintf "Daily Pace %s  (cycle %s .. %s, end excluded)" today start_day
           end_exclusive);
      why io book p);
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
    Left (names book shape.negative);
    Left (names book shape.positive);
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
    Left ""; Left "from"; Left "to"; Right "amount"; Left ""; Left "next"; Left "last"; Right "open";
  ]

let choose_series io book rows ~today all =
  choose io ~what:"Series" ~by:"the start of a name" ~heading:series_heading
    ~cells:(fun s -> [ series_cells book rows ~today s ])
    ~narrow:(fun text all -> Ok (List.filter (fun s -> moves book text (List.hd s)) all))
    all

let plan_rows book plans =
  List.map
    (fun (p : B.plan) ->
      Left p.day
      :: List.concat_map
           (fun (locus, q) -> [ Left (name book locus); Right (signed book p.measure q) ])
           p.changes)
    plans

(* A Preview of what is saved; Enter saves it. *)
let confirmed io ~title rows =
  say io "";
  say io ("  " ^ title);
  print_table io rows;
  say io "";
  match String.lowercase_ascii (ask io ~default:"y" "Save? (y / n)") with
  | "y" | "yes" -> true
  | _ ->
      say io "Nothing was saved.";
      false

(* Saving several changes together. *)
let publish_changes io (session : F.t) ~title changes rows =
  if not (confirmed io ~title rows) then `Stopped
  else
    match published io (F.publish session changes) with `Saved _ -> `Saved | `Stopped -> `Stopped

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
      publish_changes io session ~title:"New plans"
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
          publish_changes io session
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
  publish_changes io session
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

(* 9. `bk find`: records matching every term (Query), oldest first, each row by
   display name, then how many there are. *)
let query_refusal why =
  let after prefix =
    String.sub why (String.length prefix) (String.length why - String.length prefix)
  in
  match why with
  | _ when String.starts_with ~prefix:"bad-date:" why ->
      Printf.sprintf "Not a period: %S. Use 2026, 2026-10, 2026-10-05 or A..B." (after "bad-date:")
  | _ when String.starts_with ~prefix:"bad-amount:" why ->
      Printf.sprintf "Not an amount: %S. Use amt:1200, amt:>1000 or amt:<=500."
        (after "bad-amount:")
  | _ when String.starts_with ~prefix:"unknown-field:" why ->
      Printf.sprintf "Unknown field %S. Use acct:, memo:, date: or amt:." (after "unknown-field:")
  | _ when String.starts_with ~prefix:"empty-term:" why ->
      Printf.sprintf "%S needs something after the colon." (after "empty-term:")
  | _ -> why

(* A record as a passbook writes it: in each Measure the money leaves [from] and
   arrives [to], and its amount is written once, without a sign.

     date        memo        from    to        amount
     2026-11-02  lunch       Wallet  Food         700  jpy
                                     Fees         300  jpy
     2026-08-03  exchange    Bank              16,000  jpy
                                     USD cash  100.00  usd

   One account paying several (or several paying one) continues on the next
   lines, the date and memo not repeated. Anything else, such as the two sides of
   an exchange, puts each account on its own line under [from] or [to]. *)
let record_heading = [ Left "date"; Left "memo"; Left "from"; Left "to"; Right "amount"; Left "" ]

let record_lines book (e : B.entry) =
  let measures =
    List.fold_left
      (fun seen (p : B.posting) -> if List.mem p.measure seen then seen else seen @ [ p.measure ])
      [] e.effects
  in
  let lines measure =
    let rows = List.filter (fun (p : B.posting) -> p.measure = measure) e.effects in
    let leaving, arriving = List.partition (fun (p : B.posting) -> Z.sign p.amount < 0) rows in
    let line from into (p : B.posting) =
      (from, into, money book measure (Z.abs p.amount), measure)
    in
    let first i text = if i = 0 then text else "" in
    match (leaving, arriving) with
    | [ (from : B.posting) ], _ :: _ ->
        List.mapi
          (fun i (p : B.posting) -> line (first i (name book from.locus)) (name book p.locus) p)
          arriving
    | _ :: _, [ (into : B.posting) ] ->
        List.mapi
          (fun i (p : B.posting) -> line (name book p.locus) (first i (name book into.locus)) p)
          leaving
    | _ ->
        List.map
          (fun (p : B.posting) ->
            if Z.sign p.amount < 0 then line (name book p.locus) "" p
            else line "" (name book p.locus) p)
          rows
  in
  List.mapi
    (fun i (from, into, amount, measure) ->
      (if i = 0 then [ Left e.day; Left (Option.value ~default:"" e.memo) ]
       else [ Left ""; Left "" ])
      @ [ Left from; Left into; Right amount; Left measure ])
    (List.concat_map lines measures)

(* Records under one heading; no heading over no records. *)
let record_table book = function
  | [] -> []
  | entries -> record_heading :: List.concat_map (record_lines book) entries

let find io (session : F.t) words =
  let book = session.book in
  (match Bakhlo_household.Query.parse words with
  | Error why -> say io (query_refusal why)
  | Ok query ->
      let found = Bakhlo_household.Query.find book query in
      print_table io (record_table book found);
      say io
        (Printf.sprintf "%d record%s" (List.length found)
           (if List.length found = 1 then "" else "s")));
  `Stopped

(* `bk last [N]`: the records saved last, as on a passbook: the newest at the
   bottom, next to where the next one will be typed. The order is the order of
   saving, not of dates, so a record dated last week but saved just now is the
   last line; a correction keeps its place. *)
let last io (session : F.t) words =
  let book = session.book in
  let count =
    match words with
    | [] -> Some 10
    | [ n ] -> Option.bind (int_of_string_opt n) (fun n -> if n > 0 then Some n else None)
    | _ -> None
  in
  (match count with
  | None -> say io "Type how many records, like bk last 20."
  | Some n ->
      let all = B.entries book in
      let shown = List.filteri (fun i _ -> i >= List.length all - n) all in
      print_table io (record_table book shown);
      say io
        (Printf.sprintf "%d of %d record%s, newest at the bottom" (List.length shown)
           (List.length all)
           (if List.length all = 1 then "" else "s")));
  `Stopped

(* 10. Correcting records. A record is chosen with the same terms as `bk find`,
   newest first: a number takes it, more terms narrow the list. `edit` corrects
   rows, memo and date (Record), `date` moves only the date, `refund` adds the
   refund (Record), `shop` sets the shop once (Book). *)
let chosen_entry io book terms =
  match Bakhlo_household.Query.parse terms with
  | Error why ->
      say io (query_refusal why);
      None
  | Ok query -> (
      match List.rev (Bakhlo_household.Query.find book query) with
      | [] ->
          say io "No record matches.";
          None
      | newest_first ->
          let narrow text entries =
            let words = List.filter (( <> ) "") (String.split_on_char ' ' text) in
            match Bakhlo_household.Query.parse words with
            | Error why -> Error (query_refusal why)
            | Ok query -> Ok (List.filter (Bakhlo_household.Query.matches book query) entries)
          in
          Some
            (choose io ~what:"Record" ~by:"more terms" ~heading:(Left "" :: record_heading)
               ~cells:(record_lines book) ~narrow newest_first))

let edit io (session : F.t) terms =
  let book = session.book in
  match chosen_entry io book terms with
  | None -> `Stopped
  | Some e -> (
      match Draft.open_edit ~book e with
      | Error why ->
          say io why;
          `Stopped
      | Ok draft ->
          let day = ask_day io ~default:e.day "Date" in
          let memo =
            match ask io ~default:(Option.value ~default:"" e.memo) "Memo (- clears it)" with
            | "-" -> ""
            | memo -> memo
          in
          compose io session ~mode:(R.Edit e) ~day ~memo ~original_amount:e.original_amount
            draft.measure
            (as_form_rows ~keys:true book draft))

let redate io (session : F.t) terms =
  let book = session.book in
  match chosen_entry io book terms with
  | None -> `Stopped
  | Some e ->
      let day = ask_day io ~default:e.day "New date" in
      if day = e.day then (
        say io "The date is unchanged; nothing to save.";
        `Stopped)
      else
        publish_changes io session ~title:(Printf.sprintf "Move to %s" day)
          [ B.Correct_entry_date { id = e.id; day } ]
          (record_table book [ e ])

let refund io (session : F.t) ~today terms =
  let book = session.book in
  match chosen_entry io book terms with
  | None -> `Stopped
  | Some e -> (
      let day = ask_day io ~default:today "Refund date" in
      match R.refund ~book ~new_id:F.new_id ~id:e.id ~day with
      | Error "already-refund" ->
          say io "This record is a refund; it is not refunded again.";
          `Stopped
      | Error "already-refunded" ->
          say io "This record has already been refunded.";
          `Stopped
      | Error why ->
          say io why;
          `Stopped
      | Ok r ->
          publish_changes io session ~title:"Refund"
            [ B.Put_entry { replace = false; entry = r; plan = None } ]
            (record_table book [ r ]))

let shop io (session : F.t) terms =
  let book = session.book in
  match chosen_entry io book terms with
  | None -> `Stopped
  | Some e -> (
      match e.merchant with
      | Some _ ->
          say io "This record's shop is already set; it is not changed.";
          `Stopped
      | None ->
          let disposition =
            match ask io "Shop name (- if it is not a shop purchase)" with
            | "-" -> B.Nonmerchant
            | name -> B.Merchant name
          in
          publish_changes io session
            ~title:
              (match disposition with
              | B.Nonmerchant -> "Not a shop purchase"
              | B.Merchant name -> "Shop: " ^ name)
            [ B.Classify_merchant { id = e.id; disposition } ]
            (record_table book [ e ]))

(* 11. `bk check`: the balances seen outside (a bank app, the wallet) are saved as
   observed quantities (Book.Observe), one or more accounts at a time. The Preview
   shows what the book says next to what was seen. *)
let measure_of book = match B.measures book with (m, _) :: _ -> m | [] -> ""

let current book measure locus =
  match Book_display.quantity_value ~book ~measure locus with
  | Book_display.Exact q -> money book measure q
  | Book_display.Unsupported -> "unknown"

let check io (session : F.t) =
  let book = session.book in
  let measure =
    match B.measures book with
    | [ (m, _) ] -> m
    | (m, _) :: _ -> ask io ~default:m "Measure"
    | [] -> ""
  in
  let scale = Option.value ~default:0 (List.assoc_opt measure (B.measures book)) in
  let rec rows acc =
    match ask io "Account (Enter when done)" with
    | "" -> List.rev acc
    | answer -> (
        match choose_locus io book answer with
        | None -> rows acc
        | Some locus when List.exists (fun (l, _) -> l = locus) acc ->
            say io "That account is already in this check.";
            rows acc
        | Some locus ->
            let rec seen () =
              match
                Bakhlo_household.Amount.parse_signed ~decimals:scale
                  (ask io
                     (Printf.sprintf "%s now (the book says %s)" (name book locus)
                        (current book measure locus)))
              with
              | Ok q -> q
              | Error _ ->
                  say io "Enter the balance you see, like 12,345 or -500.";
                  seen ()
            in
            rows ((locus, seen ()) :: acc))
  in
  match rows [] with
  | [] ->
      say io "Nothing to check.";
      `Stopped
  | seen -> (
      (* A balance that rests on the records is compared, never overwritten: its
         difference is something to record. *)
      let from_records locus = B.observation_refusal book ~locus ~measure <> None in
      let difference locus q =
        match Book_display.quantity_value ~book ~measure locus with
        | Book_display.Exact b when not (Z.equal b q) -> signed book measure (Z.sub q b)
        | Book_display.Exact _ -> "same"
        | Book_display.Unsupported -> ""
      in
      let table =
        [ Left ""; Right "book"; Right "seen"; Right "difference"; Left ""; Left "" ]
        :: List.map
             (fun (locus, q) ->
               [
                 Left (name book locus);
                 Right (current book measure locus);
                 Right (money book measure q);
                 Right (difference locus q);
                 Left measure;
                 Left
                   (if from_records locus then "from records: record a difference with bk r" else "");
               ])
             seen
      in
      match List.filter (fun (locus, _) -> not (from_records locus)) seen with
      | [] ->
          say io "";
          print_table io table;
          say io "These balances come from the records; nothing is saved.";
          `Stopped
      | saved ->
          publish_changes io session ~title:"Balances seen (saved where not from records)"
            [ B.Observe (List.map (fun (locus, q) -> (locus, measure, q)) saved) ]
            table)

(* 12. `bk loci`: the accounts, with their roles and balances; `add` offers a new
   one (ID, display name, role), `name` renames one, `role` gives one without a
   role its role (once: Book.role_refusal). *)
let role_names =
  [
    ("asset", Locus_roles.Asset);
    ("liability", Liability);
    ("equity", Equity);
    ("income", Income);
    ("expense", Expense);
  ]

let role_of book locus =
  match List.assoc_opt locus (B.roles book) with
  | Some r -> String.lowercase_ascii (Locus_roles.role_label r)
  | None -> "-"

let rec ask_role io =
  match
    String.lowercase_ascii
      (ask io "Role (asset, liability, equity, income, expense, or - for none)")
  with
  | "-" -> None
  | text -> (
      match List.filter (fun (n, _) -> String.starts_with ~prefix:text n) role_names with
      | [ (_, role) ] when text <> "" -> Some role
      | _ ->
          say io "Type a role (its first letters are enough) or -.";
          ask_role io)

(* The Measures an account is in: those it has records or plans in, or a known
   balance in, in the book's order; the book's first Measure when none (a new
   account). A dollar account is shown in dollars, not as an unknown yen balance. *)
let measures_of book =
  let used = Hashtbl.create 64 in
  List.iter
    (fun (e : B.entry) ->
      List.iter (fun (p : B.posting) -> Hashtbl.replace used (p.locus, p.measure) ()) e.effects)
    (B.entries book);
  List.iter
    (fun (p : B.plan) ->
      List.iter (fun (locus, _) -> Hashtbl.replace used (locus, p.measure) ()) p.changes)
    (B.plans book);
  fun locus ->
    match
      List.filter
        (fun (measure, _) ->
          Hashtbl.mem used (locus, measure) || B.quantity book ~locus ~measure <> None)
        (B.measures book)
    with
    | [] -> [ measure_of book ]
    | found -> List.map fst found

let loci io (session : F.t) action =
  let book = session.book in
  match action with
  | `List ->
      let measures = measures_of book in
      print_table io
        ([ Left "name"; Left "ID"; Left "role"; Right "balance"; Left "" ]
        :: List.concat_map
             (fun locus ->
               List.mapi
                 (fun i measure ->
                   (if i = 0 then [ Left (name book locus); Left locus; Left (role_of book locus) ]
                    else [ Left ""; Left ""; Left "" ])
                   @ [ Right (current book measure locus); Left measure ])
                 (measures locus))
             (Option.value ~default:[] (B.approved_loci book)));
      `Stopped
  | `Add ->
      let id = ask io "ID (one word, used inside the book)" in
      let label = ask io ~default:id "Display name" in
      let role = ask_role io in
      publish_changes io session ~title:"New account"
        ([ B.Add_locus id ]
        @ (if label = id then [] else [ B.Set_locus_label { id; label; help = None } ])
        @
        match role with
        | None -> []
        | Some role -> [ B.Set_roles (Locus_roles.set_role (B.roles book) id (Some role)) ])
        [
          [
            Left label;
            Left id;
            Left
              (match role with
              | Some r -> String.lowercase_ascii (Locus_roles.role_label r)
              | None -> "-");
          ];
        ]
  | `Name -> (
      match choose_locus io book (ask io "Account") with
      | None -> `Stopped
      | Some id ->
          let label = ask io ~default:(B.label book id) "New display name" in
          publish_changes io session ~title:"Rename"
            [ B.Set_locus_label { id; label; help = None } ]
            [ [ Left (name book id); Left "->"; Left label ] ])
  | `Role -> (
      match choose_locus io book (ask io "Account") with
      | None -> `Stopped
      | Some id -> (
          match B.role_refusal book id with
          | Some "role-already-set" ->
              say io "This account already has a role; roles are never replaced.";
              `Stopped
          | Some _ ->
              say io "The unresolved holding account takes no role.";
              `Stopped
          | None -> (
              match ask_role io with
              | None -> `Stopped
              | Some role ->
                  publish_changes io session ~title:"Role"
                    [ B.Set_roles (Locus_roles.set_role (B.roles book) id (Some role)) ]
                    [
                      [
                        Left (name book id);
                        Left (String.lowercase_ascii (Locus_roles.role_label role));
                      ];
                    ])))

(* 13. Daily Pace settings and questions. `pool` chooses the accounts Daily Pace
   spends from (Book.pool_candidates), `cycle` edits the current preset's
   boundaries (Period.set_preset), `if` prices a purchase or income against today's
   pace and `target` plans a daily spend that keeps a target pace. Settings files are
   replaced only if they still hold what was read. *)
let save_config io (session : F.t) name ~expected content ~title rows =
  if not (confirmed io ~title rows) then `Stopped
  else
    match Config.write ~book_path:session.path name ~expected content with
    | Ok () ->
        say io "Saved.";
        `Saved
    | Error why ->
        say io ("Not saved: " ^ why);
        `Stopped

let pace_pool io (session : F.t) =
  let book = session.book in
  let measure = measure_of book in
  match config session "daily-pace.tsv" with
  | Error why ->
      say io ("daily-pace.tsv cannot be read: " ^ why);
      `Stopped
  | Ok expected -> (
      let chosen =
        match Pace.pool_of ~config:(fun _ -> Ok expected) ~measure with
        | Ok pool -> List.map (fun (c : B.coordinate) -> c.locus) pool
        | Error _ -> []
      in
      match B.pool_candidates book ~measure with
      | [] ->
          say io "No account has an exact balance yet; save one with bk check first.";
          `Stopped
      | candidates ->
          print_table io
            (List.mapi
               (fun i locus ->
                 [
                   Right (string_of_int (i + 1));
                   Left (name book locus);
                   Right (current book measure locus);
                   Left measure;
                   Left (if List.mem locus chosen then "in pool" else "");
                 ])
               candidates);
          let marked =
            String.concat " "
              (List.concat
                 (List.mapi
                    (fun i l -> if List.mem l chosen then [ string_of_int (i + 1) ] else [])
                    candidates))
          in
          let rec pick () =
            match
              pick_numbers
                (ask io ~default:marked "Pool accounts (numbers like 1 3-4)")
                (List.length candidates)
            with
            | Some numbers when numbers <> [] ->
                List.map (fun n -> List.nth candidates (n - 1)) numbers
            | _ ->
                say io "Enter numbers from the list, like 1 3-4.";
                pick ()
          in
          let pool = pick () in
          save_config io session "daily-pace.tsv" ~expected
            (String.concat "" (List.map (fun l -> l ^ "\t" ^ measure ^ "\n") pool))
            ~title:"Daily Pace pool"
            (List.map
               (fun l -> [ Left (name book l); Right (current book measure l); Left measure ])
               pool))

let pace_cycle io (session : F.t) ~today =
  match config session "boundary-presets.tsv" with
  | Error why ->
      say io ("boundary-presets.tsv cannot be read: " ^ why);
      `Stopped
  | Ok expected -> (
      let presets =
        match expected with None -> Ok [] | Some text -> Bakhlo_household.Period.parse text
      in
      match presets with
      | Error why ->
          say io (Bakhlo_household.Period.message ~today why);
          `Stopped
      | Ok presets -> (
          let name, dates =
            match Bakhlo_household.Period.cycle presets ~day:today with
            | Ok c ->
                let start, stop = List.nth c.windows c.index in
                say io
                  (Printf.sprintf "Today's cycle: %s, %s .. %s (end excluded)" c.name start stop);
                (c.name, List.assoc c.name presets)
            | Error why ->
                say io (Bakhlo_household.Period.message ~today why);
                ("pay", [])
          in
          let name = ask io ~default:name "Preset" in
          let dates =
            ask io ~default:(String.concat " " dates) "Boundary dates (YYYY-MM-DD, spaces between)"
            |> String.map (fun c -> if c = ',' then ' ' else c)
            |> String.split_on_char ' '
            |> List.filter (( <> ) "")
          in
          match Bakhlo_household.Period.set_preset presets ~name ~dates ~today with
          | Error why ->
              say io ("Not saved: " ^ Bakhlo_household.Period.message ~today why);
              `Stopped
          | Ok next ->
              save_config io session "boundary-presets.tsv" ~expected
                (Bakhlo_household.Period.print next)
                ~title:"Cycle boundaries"
                (List.map (fun (n, ds) -> Left n :: List.map (fun d -> Left d) ds) next)))

let today_pace io (session : F.t) ~today =
  let book = session.book in
  match Pace.today ~book ~measure:(measure_of book) ~today ~config:(config session) with
  | Ok (p, _, _) -> Some p
  | Error why ->
      say io ("Daily Pace unavailable: " ^ why);
      None

let pace_if io (session : F.t) ~today words =
  let book = session.book in
  (match today_pace io session ~today with
  | None -> ()
  | Some p -> (
      let amount =
        match words with
        | [] -> ask io "Amount (a purchase; +amount for income)"
        | _ -> String.concat "" words
      in
      match Pace.project ~book p amount with
      | Error why -> say io why
      | Ok r ->
          print_table io
            [
              [
                Left "today";
                Right (money book p.measure r.current_per_day);
                Left (p.measure ^ "/day");
              ];
              [
                Left "after";
                Right (money book p.measure r.projected_per_day);
                Left (p.measure ^ "/day");
              ];
              [
                Left "change";
                Right (signed book p.measure r.change_per_day);
                Left (p.measure ^ "/day");
              ];
              [
                Left "free through cycle end";
                Right (money book p.measure r.available_after);
                Left p.measure;
              ];
            ]));
  `Stopped

let pace_target io (session : F.t) ~today =
  let book = session.book in
  (match today_pace io session ~today with
  | None -> ()
  | Some p -> (
      let target = ask io "Target pace per day" in
      let date = ask io "By date (Enter for a few horizons)" in
      let purchase = ask io ~default:"0" "Spent today besides" in
      let plan_row (x : Pace.plan) =
        [
          Left x.target_date;
          Right (string_of_int x.days ^ " days");
          Right (money book p.measure x.daily_spend);
          Left (p.measure ^ "/day");
          Left (if x.reachable then "" else "not reachable");
        ]
      in
      match date with
      | "" -> (
          match Pace.options ~book p ~target ~purchase with
          | Error why -> say io why
          | Ok o -> (
              print_table io
                ([ Left "by"; Right ""; Right "spend"; Left ""; Left "" ]
                :: List.map plan_row o.horizons);
              match o.earliest with
              | Some e -> say io ("Earliest day the target is reached: " ^ e.target_date)
              | None -> say io "The target is not reached before the cycle ends."))
      | date -> (
          match Pace.plan ~book p ~target ~date ~purchase with
          | Error why -> say io why
          | Ok x -> print_table io [ plan_row x ])));
  `Stopped

(* 14. `bk fx`: one exchange between two Measures (Record.exchange): what left one
   account and what arrived in another, no rate computed. *)
let fx io (session : F.t) ~today =
  let book = session.book in
  match B.measures book with
  | [] | [ _ ] ->
      say io "An exchange needs two Measures in the book.";
      `Stopped
  | (first, _) :: (second, _) :: _ -> (
      let day = ask_day io ~default:today "Date" in
      let memo = ask io "Memo" in
      let rec side label ~default =
        match choose_locus io book (ask io (label ^ " account")) with
        | None -> side label ~default
        | Some locus ->
            let rec measure () =
              let m = ask io ~default (label ^ " Measure") in
              if List.mem_assoc m (B.measures book) then m
              else (
                say io ("The book has no Measure " ^ m ^ ".");
                measure ())
            in
            let measure = measure () in
            let rec amount () =
              match B.parse_amount book ~measure (ask io (label ^ " amount")) with
              | Ok q -> q
              | Error _ ->
                  say io "Enter a positive amount in that Measure.";
                  amount ()
            in
            (locus, measure, amount ())
      in
      let ((_, from_measure, _) as from) = side "From" ~default:first in
      let into = side "Into" ~default:(if from_measure = first then second else first) in
      match R.exchange ~new_id:F.new_id ~day ~memo ~from ~into with
      | Error "same-measure" ->
          say io "An exchange is between two different Measures; nothing was saved.";
          `Stopped
      | Error why ->
          say io why;
          `Stopped
      | Ok e ->
          publish_changes io session ~title:"Exchange"
            [ B.Put_entry { replace = false; entry = e; plan = None } ]
            (record_table book [ e ]))

(* 15. `bk todo`: household matters with a due date (Attention). `add` adds one,
   `done` resolves and `drop` drops a chosen open one, on today's date. *)
module Att = Attention_data

let attention book =
  let items, closes = B.attention book in
  { Att.items; closes }

let todo_rows ~today items =
  List.mapi
    (fun i (item : Att.item) ->
      [ Right (string_of_int (i + 1)); Left (Att.due_display ~today item.due); Left item.context ])
    items

let todo io (session : F.t) ~today action =
  let book = session.book in
  let att = attention book in
  let save title next rows =
    publish_changes io session ~title
      [ B.Set_attention { items = next.Att.items; closes = next.closes } ]
      rows
  in
  match action with
  | `List ->
      (match Att.open_items att with
      | [] -> say io "Nothing open."
      | items -> print_table io (todo_rows ~today items));
      `Stopped
  | `Add -> (
      let context = ask io "What" in
      let rec due () =
        match ask io ~default:"-" "Due (YYYY-MM-DD, - for none, ? for not known yet)" with
        | "-" -> Att.No_due_date
        | "?" -> Att.Due_undetermined
        | text -> (
            match Bakhlo_household.Day.normalize text with
            | Ok day -> Att.Due_on day
            | Error _ ->
                say io "Enter a real date, - or ?.";
                due ())
      in
      let due = due () in
      match Att.add_item att ~id:(Att.next_id att) ~context ~due with
      | Error why ->
          say io ("Not saved: " ^ why);
          `Stopped
      | Ok next -> save "New" next [ [ Left (Att.due_display ~today due); Left context ] ])
  | (`Done | `Drop) as action -> (
      match Att.open_items att with
      | [] ->
          say io "Nothing open.";
          `Stopped
      | items -> (
          let item =
            choose io ~what:"Which" ~by:"the start of a matter"
              ~cells:(fun (item : Att.item) ->
                [ [ Left (Att.due_display ~today item.due); Left item.context ] ])
              ~narrow:(fun text items ->
                Ok (List.filter (fun (item : Att.item) -> starts text item.context) items))
              items
          in
          let kind = match action with `Done -> Att.Resolved | `Drop -> Att.Dropped in
          match Att.close_item att ~id:item.id ~known_on:today ~kind with
          | Error why ->
              say io ("Not saved: " ^ why);
              `Stopped
          | Ok next ->
              save
                (match kind with Att.Resolved -> "Done" | Att.Dropped -> "Dropped")
                next
                [ [ Left (Att.due_display ~today item.due); Left item.context ] ]))

(* 16. `bk reg <account> [terms]`: the account's records in date order, like a
   passbook: what moved against what, the amount once under out (the account
   decreases) or in (it increases), and the balance at the end of that day on the
   day's last row. The balance comes from Book.pools_at_end_of_days, so
   it is shown only where the book supports it (else ?), never guessed. *)
let register io (session : F.t) words =
  let book = session.book in
  match words with
  | [] ->
      say io "Name an account: bk reg <account> [find terms].";
      `Stopped
  | account :: terms -> (
      match (choose_locus io book account, Bakhlo_household.Query.parse terms) with
      | None, _ -> `Stopped
      | _, Error why ->
          say io (query_refusal why);
          `Stopped
      | Some locus, Ok query ->
          let rows =
            List.concat_map
              (fun (e : B.entry) ->
                let mine = List.filter (fun (p : B.posting) -> p.locus = locus) e.effects in
                let measures =
                  List.sort_uniq compare (List.map (fun (p : B.posting) -> p.measure) mine)
                in
                List.map
                  (fun measure ->
                    let amount =
                      List.fold_left
                        (fun s (p : B.posting) ->
                          if p.measure = measure then Z.add s p.amount else s)
                        Z.zero mine
                    in
                    let others =
                      List.sort_uniq compare
                        (List.filter_map
                           (fun (p : B.posting) ->
                             if p.locus <> locus then Some (name book p.locus) else None)
                           e.effects)
                    in
                    (e, measure, amount, String.concat ", " others))
                  measures)
              (List.filter
                 (fun (e : B.entry) ->
                   List.exists (fun (p : B.posting) -> p.locus = locus) e.effects)
                 (Bakhlo_household.Query.find book query))
            |> List.stable_sort (fun ((a : B.entry), _, _, _) ((b : B.entry), _, _, _) ->
                compare a.day b.day)
          in
          let balance_after =
            let keys =
              List.sort_uniq compare (List.map (fun ((e : B.entry), m, _, _) -> (m, e.day)) rows)
            in
            let by_measure = List.sort_uniq compare (List.map fst keys) in
            List.concat_map
              (fun measure ->
                let days =
                  List.filter_map (fun (m, d) -> if m = measure then Some d else None) keys
                in
                List.combine days
                  (B.pools_at_end_of_days book ~measure ~pool:[ { B.locus; measure } ] ~days)
                |> List.map (fun (d, r) -> ((measure, d), r)))
              by_measure
          in
          let rec cells = function
            | [] -> []
            | ((e : B.entry), measure, amount, others) :: rest ->
                let last_of_day =
                  match rest with
                  | ((n : B.entry), m, _, _) :: _ -> n.day <> e.day || m <> measure
                  | [] -> true
                in
                let balance =
                  if not last_of_day then ""
                  else
                    match List.assoc_opt (measure, e.day) balance_after with
                    | Some (Ok q) -> money book measure q
                    | Some (Error _) | None -> "?"
                in
                [
                  Left e.day;
                  Left (Option.value ~default:"" e.memo);
                  Left others;
                  Right (if Z.sign amount < 0 then money book measure (Z.neg amount) else "");
                  Right (if Z.sign amount >= 0 then money book measure amount else "");
                  Right balance;
                  Left measure;
                ]
                :: cells rest
          in
          (match rows with
          | [] -> say io "  no records"
          | _ ->
              print_table io
                ([
                   Left "date";
                   Left "memo";
                   Left "against";
                   Right "out";
                   Right "in";
                   Right "balance";
                   Left "";
                 ]
                :: cells rows));
          `Stopped)

(* 17. Income and expense (Income_expense) by month, and for one window by account,
   plus one day's records and due plans. A period is a find period word: a year,
   a month, a day or A..B (end excluded). *)
module Ie = Bakhlo_household.Income_expense

let month_of day = String.sub day 0 7

let next_month first =
  match Bakhlo_household.Day.shift_months first 1 with Ok d -> d | Error _ -> "9999-12-31"

let rec months first stop = if first >= stop then [] else first :: months (next_month first) stop

let unroled (t : Ie.t) =
  match t.unresolved with [] -> "" | u -> Printf.sprintf "+? %d without a role" (List.length u)

let month io (session : F.t) ~today words =
  let book = session.book in
  let window =
    match words with
    | [] ->
        let this = month_of today ^ "-01" in
        Ok
          ( (match Bakhlo_household.Day.shift_months this (-5) with Ok d -> d | Error _ -> this),
            next_month this )
    | [ word ] -> (
        match Bakhlo_household.Query.days word with
        | Some (Some from, Some until) -> Ok (month_of from ^ "-01", until)
        | _ -> Error word)
    | _ -> Error (String.concat " " words)
  in
  (match window with
  | Error word -> say io (query_refusal ("bad-date:" ^ word))
  | Ok (first, stop) ->
      let rows =
        List.concat_map
          (fun first ->
            let t = Ie.compute book ~start:first ~stop:(next_month first) in
            List.filter_map
              (fun (s : Ie.summary) ->
                if Z.equal s.total_income Z.zero && Z.equal s.total_expense Z.zero then None
                else
                  Some
                    [
                      Left (month_of first);
                      Right (money book s.measure s.total_income);
                      Right (money book s.measure s.total_expense);
                      Right (money book s.measure s.scheduled);
                      Right (money book s.measure s.other);
                      Right (signed book s.measure s.net);
                      Left s.measure;
                      Left (unroled t);
                    ])
              t.summaries)
          (months first stop)
      in
      print_table io
        ([
           Left "month";
           Right "income";
           Right "expense";
           Right "plans";
           Right "other";
           Right "net";
           Left "";
           Left "";
         ]
        :: rows));
  `Stopped

let report_ie io (session : F.t) ~today words =
  let book = session.book in
  let window =
    match words with
    | [] -> (
        match Pace.today ~book ~measure:(measure_of book) ~today ~config:(config session) with
        | Ok (_, start, stop) -> Ok (start, stop)
        | Error _ -> Ok (month_of today ^ "-01", next_month (month_of today ^ "-01")))
    | [ word ] -> (
        match Bakhlo_household.Query.days word with
        | Some (Some from, Some until) -> Ok (from, until)
        | _ -> Error word)
    | _ -> Error (String.concat " " words)
  in
  (match window with
  | Error word -> say io (query_refusal ("bad-date:" ^ word))
  | Ok (start, stop) -> (
      let t = Ie.compute book ~start ~stop in
      say io (Printf.sprintf "Income and expense %s .. %s (end excluded)" start stop);
      List.iteri
        (fun i (s : Ie.summary) ->
          if i > 0 then say io "";
          let line (l : Ie.line) =
            [
              Left ("  " ^ name book l.locus); Right (money book s.measure l.amount); Left s.measure;
            ]
          in
          print_table io
            ([ Left "Income"; Right (money book s.measure s.total_income); Left s.measure ]
             :: List.map line s.income
            @ [ Left "Expense"; Right (money book s.measure s.total_expense); Left s.measure ]
              :: List.map line s.expense
            @ [
                [
                  Left "  of which paid plans";
                  Right (money book s.measure s.scheduled);
                  Left s.measure;
                ];
                [ Left "Net"; Right (signed book s.measure s.net); Left s.measure ];
              ]))
        (List.filter
           (fun (s : Ie.summary) ->
             not (Z.equal s.total_income Z.zero && Z.equal s.total_expense Z.zero))
           t.summaries);
      match unroled t with "" -> () | note -> say io ("  " ^ note ^ " (bk loci role)")));
  `Stopped

let day io (session : F.t) ~today words =
  let book = session.book in
  let day =
    match words with [] -> Ok today | [ d ] -> Bakhlo_household.Day.normalize d | _ -> Error ""
  in
  (match day with
  | Error _ -> say io "Name one day: bk day 2026-11-08."
  | Ok day -> (
      let records = List.filter (fun (e : B.entry) -> e.day = day) (B.entries book) in
      let plans = List.filter (fun (p : B.plan) -> p.day = day) (B.open_plans book) in
      say io day;
      (match records with
      | [] -> say io "  no records"
      | _ -> print_table io (record_table book records));
      match plans with
      | [] -> ()
      | _ ->
          say io "Plans due";
          print_table io (List.map (plan_cells book ~today) plans)));
  `Stopped

(* 8. After a saved record or payment, another one may follow on the saved book. *)
let rec again io (session : F.t) ~today ~saved ~question step =
  match
    try step io session ~today
    with Quit ->
      say io "Nothing was saved.";
      `Stopped
  with
  | `Saved session -> (
      match String.lowercase_ascii (try ask io ~default:"n" question with Quit -> "n") with
      | "y" | "yes" -> again io session ~today ~saved:true ~question step
      | _ -> `Saved)
  | `Stopped -> if saved then `Saved else `Stopped

let run io (command : command) (session : F.t) ~today =
  try
    match command with
    | `Record -> again io session ~today ~saved:false ~question:"Record another? (y / n)" record
    | `Pay -> again io session ~today ~saved:false ~question:"Pay another? (y / n)" pay
    | `Balances -> balances io session
    | `Pace -> pace io session ~today
    | `Plans action -> plans io session ~today action
    | `Find words -> find io session words
    | `Last words -> last io session words
    | `Edit terms ->
        again io session ~today ~saved:false ~question:"Correct another? (y / n)"
          (fun io session ~today:_ -> edit io session terms)
    | `Date terms -> redate io session terms
    | `Refund terms -> refund io session ~today terms
    | `Shop terms -> shop io session terms
    | `Check -> check io session
    | `Loci action -> loci io session action
    | `Pace_pool -> pace_pool io session
    | `Pace_cycle -> pace_cycle io session ~today
    | `Pace_if words -> pace_if io session ~today words
    | `Pace_target -> pace_target io session ~today
    | `Fx -> fx io session ~today
    | `Todo action -> todo io session ~today action
    | `Register words -> register io session words
    | `Month words -> month io session ~today words
    | `Report_ie words -> report_ie io session ~today words
    | `Day words -> day io session ~today words
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
