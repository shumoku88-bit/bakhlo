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
      List.iteri
        (fun i id -> say io (Printf.sprintf "  %d  %s  %s" (i + 1) id (B.label book id)))
        shown;
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
        List.iteri
          (fun i (d : R.t) ->
            say io
              (Printf.sprintf "  %d  %s" (i + 1)
                 (String.concat "  "
                    (List.map
                       (fun (r : R.row) ->
                         r.locus ^ " " ^ (if r.negative then "-" else "+") ^ r.amount)
                       d.rows))))
          earlier;
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
let plan_line book (p : B.plan) ~today =
  let rows =
    String.concat "  "
      (List.map (fun (locus, q) -> locus ^ " " ^ signed book p.measure q) p.changes)
  in
  Printf.sprintf "%s  %s  %s %s%s" p.day p.id rows p.measure
    (if p.day < today then "  overdue" else "")

let rec choose_plan io book plans ~today =
  let shown = List.filteri (fun i _ -> i < 9) plans in
  List.iteri (fun i p -> say io (Printf.sprintf "  %d  %s" (i + 1) (plan_line book p ~today))) shown;
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

let run io command (session : F.t) ~today =
  try match command with `Record -> record io session ~today | `Pay -> pay io session ~today
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
