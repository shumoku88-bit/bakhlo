(* Command-line entry: interactive TUI and recovery inspection. *)
module F = Daily_file
let run = Bonsai_terminal.run

let print_recovery path =
  let report = F.inspect_recovery path in
  (match report.selected with
  | Ok _ -> print_endline "selected: admitted (no payload output)"
  | Error why -> Printf.printf "selected: unavailable (%s)\n" why);
  List.iter
    (fun (item : F.recovery_item) ->
      let state =
        match item.comparison with
        | F.Candidate_current -> "candidate-is-current"
        | F.Before_current -> "before-is-current"
        | F.Unresolved -> "unresolved"
        | F.Unreadable why -> "unreadable: " ^ why
      in
      Printf.printf "artifact=%S attempt=%s state=%s\n" item.name
        (Option.value ~default:"unknown" item.attempt_id)
        state)
    report.items;
  if report.items <> [] then
    print_endline
      "REVIEW REQUIRED: no adoption/retry. Equality describes current bytes, not past outcome.";
  match (report.selected, report.items) with
  | Ok _, [] ->
      print_endline "No unfinished artifacts found.";
      0
  | Ok _, _ -> 3
  | Error _, _ -> 1

let () =
  try
    match Array.to_list Sys.argv with
    | [ _; "--book"; path ] -> run path
    | [ _; "--check"; path ] ->
        ignore (F.load path);
        print_endline "PASS: daily book admitted (no payload output)."
    | [ _; "--copy-from"; source; "--book"; target ] ->
        F.create_copy ~source ~target;
        print_endline "PASS: fresh trial copy created; original unchanged."
    | [ _; "--inspect-recovery"; "--book"; path ] -> exit (print_recovery path)
    | [ _; "--confirm-current-attempt"; id; "--book"; path ] ->
        ignore (F.confirm_current ~session:(F.load path) ~attempt_id:id);
        print_endline "Current candidate confirmed; backup files untouched. No retry."
    | [ _; "--restore-copy-from"; source; "--book"; target ] ->
        F.restore_copy ~source ~target;
        print_endline
          "Checked byte-exact recovery copy created. Original/artifacts unchanged; adoption is \
           explicit."
    | _ ->
        prerr_endline
          "Usage: tools/tui --book FILE | --check FILE | --copy-from SOURCE --book FRESH_FILE | \
           --inspect-recovery --book FILE | --confirm-current-attempt ID --book FILE | \
           --restore-copy-from SOURCE --book FRESH_FILE";
        exit 2
  with
  | F.Refused why
    when Array.length Sys.argv > 1
         && List.mem Sys.argv.(1)
              [ "--inspect-recovery"; "--confirm-current-attempt"; "--restore-copy-from" ] ->
      prerr_endline ("Recovery refused: " ^ why ^ "; no automatic adoption or retry.");
      exit 1
  | F.Refused _ | Unix.Unix_error _ | Sys_error _ ->
      prerr_endline
        "TUI/recovery refused: input/file/terminal unavailable; no empty fallback. Remaining \
         artifacts are not automatically adopted or pruned.";
      exit 1
