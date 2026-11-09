(* The command line: the bk commands on a household book, and the book checks and
   checked copies. *)
module F = Book_file

type command = Line_commands.command

(* The bk commands: one table both dispatches them and lists them (bk help). A
   command either takes no more words or takes the rest as find terms. *)
let fixed command = function [] -> Some command | _ :: _ -> None
let terms make words = Some (make words)

let commands =
  [
    ([ "r" ], fixed `Record, "record an Actual");
    ([ "pay" ], fixed `Pay, "pay a plan");
    ([ "bal" ], fixed `Balances, "balances");
    ([ "pace" ], fixed `Pace, "today's pace and its breakdown");
    ([ "pace"; "pool" ], fixed `Pace_pool, "choose the accounts Daily Pace spends from");
    ([ "pace"; "cycle" ], fixed `Pace_cycle, "edit the current cycle's boundary dates");
    ( [ "pace"; "if" ],
      terms (fun t -> `Pace_if t),
      "today's pace after a purchase (+amount: income)" );
    ([ "pace"; "target" ], fixed `Pace_target, "plan a daily spend that keeps a target pace");
    ([ "plans" ], fixed (`Plans `List), "plans in series: how far each is filled");
    ([ "plans"; "more" ], fixed (`Plans `More), "fill the coming months of a series");
    ([ "plans"; "amount" ], fixed (`Plans `Amount), "change a series' amount from a day on");
    ([ "plans"; "cancel" ], fixed (`Plans `Cancel), "cancel plans of a series");
    ( [ "find" ],
      terms (fun t -> `Find t),
      "records matching every term: a name or memo, 2026-10, A..B, acct:, memo:, amt:1000.." );
    ( [ "last" ],
      terms (fun t -> `Last t),
      "the records saved last, newest at the bottom [how many; default 10]" );
    ( [ "month" ],
      terms (fun t -> `Month t),
      "income and expense by month [2026 or A..B; default 6 months]" );
    ( [ "report"; "ie" ],
      terms (fun t -> `Report_ie t),
      "income and expense by account [period; default this cycle]" );
    ([ "day" ], terms (fun t -> `Day t), "one day's records and due plans [date; default today]");
    ( [ "reg" ],
      terms (fun t -> `Register t),
      "an account's records with the balance after each day: bk reg <account> [find terms]" );
    ([ "edit" ], terms (fun t -> `Edit t), "correct a record's rows, memo or date [find terms]");
    ([ "date" ], terms (fun t -> `Date t), "move a record to another date [find terms]");
    ([ "refund" ], terms (fun t -> `Refund t), "record the refund of a record [find terms]");
    ([ "shop" ], terms (fun t -> `Shop t), "set where a record was bought, once [find terms]");
    ([ "fx" ], fixed `Fx, "record an exchange between two Measures");
    ([ "todo" ], fixed (`Todo `List), "household matters with due dates (Attention)");
    ([ "todo"; "add" ], fixed (`Todo `Add), "add a matter with its due date");
    ([ "todo"; "done" ], fixed (`Todo `Done), "mark a matter done");
    ([ "todo"; "drop" ], fixed (`Todo `Drop), "drop a matter");
    ([ "check" ], fixed `Check, "save the balances you see (a bank app, the wallet)");
    ([ "loci" ], fixed (`Loci `List), "accounts with their roles and balances");
    ([ "loci"; "add" ], fixed (`Loci `Add), "add an account");
    ([ "loci"; "name" ], fixed (`Loci `Name), "rename an account");
    ([ "loci"; "role" ], fixed (`Loci `Role), "give an account its role (once)");
  ]

let line_command words =
  let rec after prefix words =
    match (prefix, words) with
    | [], rest -> Some rest
    | p :: prefix, w :: words when p = w -> after prefix words
    | _ -> None
  in
  List.find_map (fun (w, make, _) -> Option.bind (after w words) make) commands

let help =
  let rows =
    ("bk", "today's pace, then this list")
    :: List.map (fun (words, _, what) -> (String.concat " " ("bk" :: words), what)) commands
    @ [ ("bk help", "this list") ]
  in
  let width = List.fold_left (fun n (name, _) -> max n (String.length name)) 0 rows in
  String.concat ""
    (List.map
       (fun (name, what) ->
         Printf.sprintf "  %s%s  %s\n" name (String.make (width - String.length name) ' ') what)
       rows)

(* Plain bk in a terminal with fzf (user decision 2026-11-09; optional): the person
   picks a command by typing part of its words, as `sh` leaves shop and `to` the
   todo commands. fzf matches the words only, not the line about them; Esc picks
   nothing. Without fzf, or outside a terminal, the list is printed as before. *)
let menu = List.map (fun (words, _, what) -> String.concat " " words ^ "\t" ^ what) commands

let fzf_on_path () =
  String.split_on_char ':' (Option.value ~default:"" (Sys.getenv_opt "PATH"))
  |> List.map (fun dir -> Filename.concat dir "fzf")
  |> List.find_opt (fun path ->
      try
        Unix.access path [ Unix.X_OK ];
        true
      with Unix.Unix_error _ -> false)

let pick fzf =
  let width =
    List.fold_left
      (fun n (words, _, _) -> max n (String.length (String.concat " " words)))
      0 commands
  in
  let args =
    [|
      fzf;
      "--height=~60%";
      "--layout=reverse";
      "--no-multi";
      "--delimiter=\t";
      "--nth=1";
      Printf.sprintf "--tabstop=%d" (width + 2);
      "--prompt=bk ";
    |]
  in
  let from_fzf, to_fzf = Unix.open_process_args fzf args in
  List.iter (fun line -> output_string to_fzf (line ^ "\n")) menu;
  close_out to_fzf;
  let chosen = In_channel.input_line from_fzf in
  match (Unix.close_process (from_fzf, to_fzf), chosen) with
  | Unix.WEXITED 0, Some line -> (
      match String.split_on_char '\t' line with
      | words :: _ -> Some (List.filter (( <> ) "") (String.split_on_char ' ' words))
      | [] -> None)
  | _ -> None

(* The rest of a picked command that takes words, asked as the line after it. *)
let completed words =
  match List.find_opt (fun (w, _, _) -> w = words) commands with
  | Some (_, make, _) when make [ "_" ] <> None -> (
      print_string (String.concat " " ("bk" :: words) ^ " ");
      flush stdout;
      match In_channel.input_line stdin with
      | Some rest -> Some (words @ List.filter (( <> ) "") (String.split_on_char ' ' rest))
      | None -> None)
  | _ -> Some words

let today () =
  let tm = Unix.localtime (Unix.time ()) in
  Printf.sprintf "%04d-%02d-%02d" (tm.Unix.tm_year + 1900) (tm.Unix.tm_mon + 1) tm.Unix.tm_mday

(* Plain bk: today's pace, then what else there is. *)
let main () =
  try
    match Array.to_list Sys.argv with
    | [ _; "--book"; path ] -> (
        ignore (Line_commands.run Line_commands.terminal `Pace (F.load path) ~today:(today ()));
        print_newline ();
        match fzf_on_path () with
        | Some fzf when Unix.isatty Unix.stdin && Unix.isatty Unix.stdout -> (
            match Option.bind (Option.bind (pick fzf) completed) line_command with
            | Some command ->
                ignore
                  (Line_commands.run Line_commands.terminal command (F.load path) ~today:(today ()))
            | None -> ())
        | _ -> print_string help)
    | _ :: "--book" :: path :: words when line_command words <> None ->
        let command = Option.get (line_command words) in
        ignore (Line_commands.run Line_commands.terminal command (F.load path) ~today:(today ()))
    | [ _; "--book"; _; "help" ] -> print_string help
    | _ :: "--book" :: _ :: words ->
        prerr_endline ("Unknown command: bk " ^ String.concat " " words);
        prerr_string help;
        exit 2
    | [ _; "--check"; path ] ->
        ignore (F.load path);
        print_endline "PASS: household book admitted (no payload output)."
    | [ _; "--copy-from"; source; "--book"; target ] ->
        F.create_copy ~source ~target;
        print_endline "PASS: fresh trial copy created; original unchanged."
    | [ _; "--restore-copy-from"; source; "--book"; target ] ->
        F.restore_copy ~source ~target;
        print_endline
          "Checked byte-exact recovery copy created. Original/artifacts unchanged; adoption is \
           explicit."
    | _ ->
        prerr_endline
          "Usage: bakhlo --book FILE [COMMAND] (bakhlo --book FILE help lists them) | --check FILE \
           | --copy-from SOURCE --book FRESH_FILE | --restore-copy-from SOURCE --book FRESH_FILE";
        exit 2
  with
  | F.Refused why when Array.length Sys.argv > 1 && List.mem Sys.argv.(1) [ "--restore-copy-from" ]
    ->
      prerr_endline ("Recovery refused: " ^ why ^ "; no automatic adoption or retry.");
      exit 1
  | F.Refused _ | Unix.Unix_error _ | Sys_error _ ->
      prerr_endline "Refused: the book or a file is unavailable; nothing was changed or adopted.";
      exit 1
