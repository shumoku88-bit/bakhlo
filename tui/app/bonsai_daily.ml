(* Command-line entry: interactive TUI and recovery inspection. *)
module F = Daily_file
let run = Bonsai_terminal.run

let print_recovery path =
  let report = F.inspect_recovery path in
  match report.selected with
  | Error why ->
      Printf.printf "selected: unavailable (%s)\n" why;
      1
  | Ok session when session.torn ->
      Printf.printf
        "selected: %d complete records, then an incomplete final record (%d bytes) from an \
         interrupted save.\nThat save did not complete. Writes stay stopped until you run \
         --discard-torn-tail; no automatic repair.\n"
        session.records report.torn_bytes;
      3
  | Ok session ->
      Printf.printf "selected: admitted, %d records after the snapshot (no payload output)\n"
        session.records;
      print_endline "No interrupted save found.";
      0

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
    | [ _; "--discard-torn-tail"; "--book"; path ] ->
        let removed, session = F.discard_torn_tail path in
        Printf.printf "Removed the incomplete final record (%d bytes); %d complete records kept.\n"
          removed session.records
    | [ _; "--restore-copy-from"; source; "--book"; target ] ->
        F.restore_copy ~source ~target;
        print_endline
          "Checked byte-exact recovery copy created. Original/artifacts unchanged; adoption is \
           explicit."
    | _ ->
        prerr_endline
          "Usage: tools/tui --book FILE | --check FILE | --copy-from SOURCE --book FRESH_FILE | \
           --inspect-recovery --book FILE | --discard-torn-tail --book FILE | \
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
