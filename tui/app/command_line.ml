(* Command-line entry shared by the terminal adapters: interactive TUI, checks and
   checked copies. [run] opens the TUI on a household book. *)
module F = Book_file

let line_command = function
  | [ "r" ] -> Some `Record
  | [ "pay" ] -> Some `Pay
  | [ "bal" ] -> Some `Balances
  | [ "pace" ] -> Some `Pace
  | [ "plans" ] -> Some (`Plans `List)
  | [ "plans"; "more" ] -> Some (`Plans `More)
  | [ "plans"; "amount" ] -> Some (`Plans `Amount)
  | [ "plans"; "cancel" ] -> Some (`Plans `Cancel)
  | _ -> None

let main ~run =
  try
    match Array.to_list Sys.argv with
    | [ _; "--book"; path ] -> run path
    | _ :: "--book" :: path :: words when line_command words <> None ->
        let command = Option.get (line_command words) in
        let today =
          let tm = Unix.localtime (Unix.time ()) in
          Printf.sprintf "%04d-%02d-%02d" (tm.Unix.tm_year + 1900) (tm.Unix.tm_mon + 1)
            tm.Unix.tm_mday
        in
        ignore (Line_commands.run Line_commands.terminal command (F.load path) ~today)
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
          "Usage: tools/tui --book FILE [r | pay | bal | pace | plans [more | amount | cancel]] | \
           --check FILE | --copy-from SOURCE --book FRESH_FILE | --restore-copy-from SOURCE --book \
           FRESH_FILE";
        exit 2
  with
  | F.Refused why when Array.length Sys.argv > 1 && List.mem Sys.argv.(1) [ "--restore-copy-from" ]
    ->
      prerr_endline ("Recovery refused: " ^ why ^ "; no automatic adoption or retry.");
      exit 1
  | F.Refused _ | Unix.Unix_error _ | Sys_error _ ->
      prerr_endline
        "TUI/recovery refused: input/file/terminal unavailable; no empty fallback. Remaining \
         artifacts are not automatically adopted or pruned.";
      exit 1
