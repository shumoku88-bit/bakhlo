(* Command-line entry: interactive TUI, recovery inspection and annual file tools. *)
module F = Daily_file
module Annual = Bakhlo_sexp.Annual_scope
module D = Bakhlo_domain
module Y = Bakhlo_sexp.Year_read
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

let print_annual_rollover_preview (p : F.annual_rollover_preview) =
  Printf.printf "Read-only prior-year closing preview (NOT target-year balance)\n";
  Printf.printf "Prior year: %04d (fingerprint %s)\n" p.prior_year p.prior_fingerprint;
  Printf.printf "Current year: %04d (fingerprint %s)\n" p.year p.current_fingerprint;
  List.iter
    (fun (coord, balance) ->
      let locus = D.Identifier.Locus.to_string coord.D.Effect_coordinate.locus in
      let measure = D.Identifier.Measure.to_string coord.D.Effect_coordinate.measure in
      let balance_str =
        match balance with
        | Y.Exact q ->
            Printf.sprintf "Exact %s %S" (Z.to_string (D.Quantity.quanta q)) measure
        | Y.Zero_origin -> "Zero_origin (distinct exact zero premise)"
        | Y.Known_present -> "Known_present (amount unknown)"
        | Y.Unknown -> "Unknown (not zero)"
      in
      Printf.printf "Coordinate (%S, %S): %s\n" locus measure balance_str)
    p.balances;
  if p.open_plans = [] then
    Printf.printf "Surviving open plans from %04d: none (read-only; not imported, not payable)\n" p.prior_year
  else (
    Printf.printf "Surviving open plans from %04d (read-only; not imported, not payable):\n" p.prior_year;
    List.iter
      (fun (plan : Bakhlo_sexp.Daily_book.plan) ->
        let changes_str =
          String.concat ", "
            (List.map (fun (loc, amt) -> Printf.sprintf "%S: %s" loc (Z.to_string amt)) plan.changes)
        in
        Printf.printf "  Plan ID: %S | Day: %S | Measure: %S | Changes: [%s]\n"
          plan.id plan.day plan.measure changes_str)
      p.open_plans)

let () =
  try
    match Array.to_list Sys.argv with
    | [ _; "--book"; path ] -> run path
    | [ _; "--annual-book"; year; "--book"; path ] ->
        let year = match Annual.of_string year with
          | Ok year -> year | Error why -> raise (F.Refused why) in
        run ~annual_year:year path
    | [ _; "--annual-rollover"; year; "--book"; path ] ->
        let year = match Annual.of_string year with
          | Ok year -> year | Error why -> raise (F.Refused why) in
        let next = F.rollover ~session:(F.load ~annual_year:year path) in
        Printf.printf "Created and cold-verified %s; predecessor is read-only.\n" next.path
    | [ _; "--annual-backup"; year; "--book"; path; "--output"; target ] ->
        let year = match Annual.of_string year with
          | Ok year -> year | Error why -> raise (F.Refused why) in
        let digest = Annual_backup.backup ~session:(F.load ~annual_year:year path) ~target in
        Printf.printf "Validated exact-byte annual backup: %s (fingerprint %s).\n" target digest
    | [ _; "--annual-restore"; source; "--directory"; directory ] ->
        let path = Annual_backup.restore ~source ~directory in
        Printf.printf "Validated restored copy: %s\nNot adopted. Explicitly open this copy to accept it.\n" path
    | [ _; "--annual-check"; year; "--book"; path ] ->
        let year = match Annual.of_string year with
          | Ok year -> year | Error why -> raise (F.Refused why) in
        ignore (F.load ~annual_year:year path);
        print_endline "PASS: annual book and any linked predecessor chain admitted."
    | [ _; "--annual-list"; directory ] ->
        let books = F.list_annual_books ~directory in
        if books = [] then
          print_endline "No YYYY.sexp books found. No opening balance is inferred."
        else
          List.iter (fun (book : F.annual_book_summary) ->
            Printf.printf "%04d  Actual %d  open Scheduled %d  (validated selected history)\n"
              book.year book.entries book.open_plans)
            books
    | [ _; "--annual-rollover-preview"; year; "--directory"; directory; "--coordinate"; locus; measure ] ->
        let year = match Annual.of_string year with
          | Ok year -> year | Error why -> raise (F.Refused why) in
        let locus = match D.Identifier.Locus.of_string locus with
          | Ok locus -> locus | Error _ -> raise (F.Refused "invalid-locus") in
        let measure = match D.Identifier.Measure.of_string measure with
          | Ok measure -> measure | Error _ -> raise (F.Refused "invalid-measure") in
        let coordinate : D.Effect_coordinate.t = { locus; measure } in
        let preview = F.preview_annual_rollover ~directory ~year ~coordinates:[ coordinate ] in
        print_annual_rollover_preview preview
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
          "Usage: tools/tui --book FILE | --annual-book YYYY --book YYYY.sexp | --annual-rollover YYYY --book YYYY.sexp | --annual-backup YYYY --book YYYY.sexp --output FRESH_ARCHIVE | --annual-restore ARCHIVE --directory FRESH_DIR | --annual-check YYYY --book YYYY.sexp | --annual-list DIR | --annual-rollover-preview YYYY --directory DIR --coordinate LOCUS MEASURE | --check FILE | --copy-from SOURCE --book FRESH_FILE | \
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
