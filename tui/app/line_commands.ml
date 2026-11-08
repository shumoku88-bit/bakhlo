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
   screens (Draft), the Preview is the screens' Preview and the save is
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
          let default =
            match previous with
            | Some r when r.amount <> "" -> r.amount
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

(* 3. Preview and save. The Preview lines are the screens'; Enter saves. *)
let save io (session : F.t) (tx : R.transaction) =
  let book = session.book in
  say io "";
  List.iter (fun (_, line) -> say io ("  " ^ line)) (Book_display.preview_rows book tx);
  say io "";
  match String.lowercase_ascii (ask io ~default:"y" "Save? (y / n / e to edit)") with
  | "y" | "yes" -> (
      match
        F.publish session [ B.Put_entry { replace = tx.replace; entry = tx.entry; plan = tx.plan } ]
      with
      | F.Written _ ->
          say io ("Saved " ^ tx.entry.id ^ ".");
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

let as_form_rows (draft : R.t) =
  List.map
    (fun (r : R.row) ->
      { R.key = None; locus = r.locus; amount = (if r.negative then "-" else "+") ^ r.amount })
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
                    (fun (r : R.row) ->
                      [
                        Left (name book r.locus);
                        Right ((if r.negative then "-" else "+") ^ r.amount);
                      ])
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
  let rows = match chosen with Some d -> as_form_rows d | None -> [] in
  compose io session ~mode:R.New ~day ~memo ~original_amount:None measure rows

(* 5. `bk pay`. Open plans oldest first; the chosen plan's rows are the
   defaults, so Enter through the Preview pays it as planned. *)
let plan_cells book (p : B.plan) ~today =
  [ Left p.day; Left p.id ]
  @ List.concat_map
      (fun (locus, q) -> [ Left (name book locus); Right (signed book p.measure q) ])
      p.changes
  @ [ Left p.measure ]
  @ if p.day < today then [ Left "overdue" ] else []

let rec choose_plan io book plans ~today =
  let shown = List.filteri (fun i _ -> i < 9) plans in
  print_table io
    (List.mapi (fun i p -> Right (string_of_int (i + 1)) :: plan_cells book p ~today) shown);
  if List.length plans > 9 then say io "  … type the start of an ID to narrow";
  let answer = ask io ~default:"1" "Plan" in
  match int_of_string_opt answer with
  | Some n when n >= 1 && n <= List.length shown -> Some (List.nth shown (n - 1))
  | _ -> (
      match List.filter (fun (p : B.plan) -> String.starts_with ~prefix:answer p.id) plans with
      | [] ->
          say io (Printf.sprintf "No open plan starts with %S." answer);
          choose_plan io book plans ~today
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
                    (as_form_rows draft)
              | Ok tx -> (
                  match save io session tx with
                  | `Edit ->
                      compose io session ~mode ~day ~memo ~original_amount:None draft.measure
                        (as_form_rows draft)
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

let run io command (session : F.t) ~today =
  try
    match command with
    | `Record -> record io session ~today
    | `Pay -> pay io session ~today
    | `Balances -> balances io session
    | `Pace -> pace io session ~today
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
