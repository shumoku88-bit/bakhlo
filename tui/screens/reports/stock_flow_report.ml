(* Stock-Flow Report: single-measure tracked balance motion over explicit
   boundaries. A coordinate is reconstructed on one of the supported routes:
   zero-origin, bounded history, or an opening entry (exact from the opening
   entry's own day). An observation is exact only at its confirmation, so it
   never yields a window boundary. Never a fabricated zero; unsupported
   coordinates are listed, not used to refuse the whole report. *)
module B = Bakhlo_household.Book
module SF = Bakhlo_household.Stock_flow
module IncExp = Income_expense_report
module O = Ui_render
module A = Draft

type t = { preset : IncExp.period_preset; period_offset : int }

(* The configured cycle is the default Stock–Flow window. *)
let initial () = { preset = IncExp.Cycle; period_offset = 0 }

let signed_amount ~book m z =
  (if Z.sign z > 0 then "+" else "") ^ Book_display.format_money book m z

let signed_val ~book m z =
  (if Z.sign z > 0 then "+" else "") ^ Book_display.format_money book m z ^ " " ^ m

let unsigned_val ~book m z = Book_display.format_money book m z ^ " " ^ m

let coordinate_label ~book ~measure (c : SF.coordinate_activity) =
  let label = B.label book c.locus in
  if label <> "" && label <> c.locus then label ^ "/" ^ measure else c.locus ^ "/" ^ measure

let support_note (c : SF.coordinate_activity) =
  match c.support with
  | SF.Before_start start_day ->
      Some (Printf.sprintf "start unknown; bounded history starts %s" start_day)
  | Opening day -> Some (Printf.sprintf "start known from the opening entry dated %s" day)
  | Opening_after day ->
      Some
        (Printf.sprintf "start and end unknown; the window ends before the opening entry dated %s"
           day)
  | Opening_on day ->
      Some
        (Printf.sprintf
           "start unknown; the window starts on the opening entry dated %s, whose whole entry is \
            not a flow"
           day)
  | Opening_inside day ->
      Some
        (Printf.sprintf
           "start unknown; the window contains the opening entry dated %s, whose whole entry is \
            not a flow"
           day)
  | Observation_undated ->
      Some
        "start unknown; the confirmation is exact, but the balance before it is not derivable, so \
         the window boundaries stay unknown"
  | Zero_origin | Bounded _ | Unsupported _ -> None

let table_columns pad_w =
  let col_name = max 14 (min 26 (pad_w * 25 / 100)) in
  let col_num = max 9 (min 12 ((pad_w - col_name - 8) / 5)) in
  (col_name, col_num)

let cell ~width_of col text = O.pad_left ~width_of col text

let row_text ~width_of ~col_name ~col_num ~book ~measure (c : SF.coordinate_activity) =
  let amount = function
    | Some value -> Book_display.format_money book measure value
    | None -> "—"
  in
  let net =
    match c.net_change with Some value -> signed_amount ~book measure value | None -> "—"
  in
  "  "
  ^ O.pad ~width_of col_name (coordinate_label ~book ~measure c)
  ^ " "
  ^ cell ~width_of col_num (amount c.start_balance)
  ^ " "
  ^ cell ~width_of col_num ("+" ^ Book_display.format_money book measure c.increases)
  ^ " "
  ^ cell ~width_of col_num (Book_display.format_money book measure c.decreases)
  ^ " "
  ^ cell ~width_of col_num (amount c.end_balance)
  ^ " " ^ cell ~width_of col_num net

let header_text ~width_of ~col_name ~col_num =
  "  "
  ^ O.pad ~width_of col_name "Coordinate"
  ^ " " ^ cell ~width_of col_num "Start" ^ " " ^ cell ~width_of col_num "+In" ^ " "
  ^ cell ~width_of col_num "-Out" ^ " " ^ cell ~width_of col_num "End" ^ " "
  ^ cell ~width_of col_num "Net"

let footnote_lines ~book ~measure (report : SF.snapshot) =
  let notes =
    List.filter_map
      (fun (c : SF.coordinate_activity) ->
        Option.map
          (fun note -> Printf.sprintf "  %s: %s" (coordinate_label ~book ~measure c) note)
          (support_note c))
      report.coordinates
  in
  let unsupported =
    List.map
      (fun (locus, reason) ->
        Printf.sprintf "  %s/%s: %s" locus report.measure (SF.missing_message reason))
      report.unsupported
  in
  let excluded =
    List.map
      (fun (id, day) ->
        Printf.sprintf
          "  The opening entry %s dated %s is left out of the in-window flows on both sides." id day)
      report.excluded_openings
  in
  let excluded_note =
    if report.excluded_openings = [] then []
    else [ "  Start and End include those entries; +In and -Out do not." ]
  in
  (if report.unknown_starts > 0 then
     [
       Printf.sprintf "  The start total excludes %d coordinate(s) whose start is unknown."
         report.unknown_starts;
       "  The end total still adds every known end.";
     ]
   else [])
  @ excluded @ excluded_note @ notes
  @ if unsupported = [] then [] else "  Unsupported coordinates (not reconstructed):" :: unsupported

let render_summary_lines ~width ~width_of ~book ~(period : IncExp.period) ~(report : SF.snapshot) =
  let pad_w = max 0 (width - 4) in
  let m = report.measure in
  let col_name, col_num = table_columns pad_w in
  let header =
    [
      (O.Heading, Printf.sprintf "Stock–Flow  [%s • %s]" period.label m);
      (O.Chrome, Printf.sprintf "Window: %s .. %s (exclusive)" period.start_day period.end_exclusive);
      (O.Plain, "Why did the tracked balance change between two boundaries?");
      (O.Plain, "");
      ( O.Plain,
        Printf.sprintf "  %-36s %16s" "Reconstructed at start:"
          (unsigned_val ~book m report.reconstructed_start) );
      ( O.Plain,
        Printf.sprintf "  %-36s %16s" "Reconstructed at end:"
          (unsigned_val ~book m report.reconstructed_end) );
      (O.Plain, "");
      ( O.Plain,
        Printf.sprintf "  %-36s %16s" "Tracked increases across Events:"
          (signed_val ~book m report.increases_across_events) );
      ( O.Plain,
        Printf.sprintf "  %-36s %16s" "Tracked decreases across Events:"
          (signed_val ~book m report.decreases_across_events) );
      ( O.Active,
        Printf.sprintf "  %-36s %16s" "Net change in tracked balance:"
          (match report.net_change with Some value -> signed_val ~book m value | None -> "—") );
      (O.Plain, "");
      ( O.Chrome,
        Printf.sprintf "  %-36s %16s" "Current tracked balance now:"
          (unsigned_val ~book m report.current_tracked) );
      (O.Plain, "");
    ]
  in
  let rule = (O.Chrome, O.rule ~width_of pad_w) in
  let rows =
    List.map
      (fun (c : SF.coordinate_activity) ->
        (O.Plain, row_text ~width_of ~col_name ~col_num ~book ~measure:m c))
      report.coordinates
  in
  let total_line =
    "  "
    ^ O.pad ~width_of col_name ("Total (" ^ m ^ ")")
    ^ " "
    ^ cell ~width_of col_num (Book_display.format_money book m report.reconstructed_start)
    ^ " "
    ^ cell ~width_of col_num ("+" ^ Book_display.format_money book m report.increases_across_events)
    ^ " "
    ^ cell ~width_of col_num (Book_display.format_money book m report.decreases_across_events)
    ^ " "
    ^ cell ~width_of col_num (Book_display.format_money book m report.reconstructed_end)
    ^ " "
    ^ cell ~width_of col_num
        (match report.net_change with Some value -> signed_amount ~book m value | None -> "—")
  in
  let liabilities =
    match report.liabilities with
    | [] -> []
    | rows_of ->
        let known_start =
          List.filter_map (fun (c : SF.coordinate_activity) -> c.start_balance) rows_of
        in
        let known_end =
          List.filter_map (fun (c : SF.coordinate_activity) -> c.end_balance) rows_of
        in
        let known_now =
          List.filter_map
            (fun (c : SF.coordinate_activity) ->
              match (c.end_balance, c.current_balance) with
              | Some _, _ -> None
              | None, current -> current)
            rows_of
        in
        let total = List.fold_left Z.add Z.zero (known_end @ known_now) in
        let total_label =
          if known_end <> [] then "Debt remaining"
          else if known_now <> [] then "Debt remaining (now)"
          else "Debt remaining"
        in
        ( O.Chrome,
          if known_end <> [] then "  Liabilities (start / +In / -Out / end)"
          else "  Liabilities (end unknown; current quantity only)" )
        :: List.map
             (fun (c : SF.coordinate_activity) ->
               let amount = function
                 | Some value -> Book_display.format_money book m value
                 | None -> "—"
               in
               let now =
                 match (c.end_balance, c.current_balance) with
                 | Some _, _ -> ""
                 | None, Some value -> "  now " ^ Book_display.format_money book m value
                 | None, None -> ""
               in
               let support =
                 match support_note c with Some note -> "  (" ^ note ^ ")" | None -> ""
               in
               ( O.Plain,
                 Printf.sprintf "    %-22s %10s %10s %10s %10s%s%s"
                   (coordinate_label ~book ~measure:m c)
                   (amount c.start_balance)
                   ("+" ^ Book_display.format_money book m c.increases)
                   (Book_display.format_money book m c.decreases)
                   (amount c.end_balance) now support ))
             rows_of
        @ [
            ( O.Plain,
              Printf.sprintf "    %-22s %10s %10s %10s %10s" total_label
                (if known_start = [] then "—"
                 else signed_amount ~book m (List.fold_left Z.add Z.zero known_start))
                ("+"
                ^ Book_display.format_money book m
                    (List.fold_left
                       (fun total (c : SF.coordinate_activity) -> Z.add total c.increases)
                       Z.zero rows_of))
                (Book_display.format_money book m
                   (List.fold_left
                      (fun total (c : SF.coordinate_activity) -> Z.add total c.decreases)
                      Z.zero rows_of))
                (if known_end = [] && known_now = [] then "—" else signed_amount ~book m total) );
          ]
  in
  header
  @ [ (O.Chrome, header_text ~width_of ~col_name ~col_num); rule ]
  @ rows
  @ [ rule; (O.Heading, total_line); (O.Plain, "") ]
  @ (if liabilities = [] then [] else liabilities @ [ (O.Plain, "") ])
  @ List.map (fun text -> (O.Chrome, text)) (footnote_lines ~book ~measure:m report)

let print_summary ~book ~(period : IncExp.period) ~(report : SF.snapshot) =
  let lines = ref [] in
  let add s = lines := s :: !lines in
  let m = report.measure in
  let col_name, col_num = (22, 12) in
  add (Printf.sprintf "Stock–Flow Report - %s (%s)" period.label m);
  add (Printf.sprintf "Window: %s through %s (exclusive)" period.start_day period.end_exclusive);
  add "================================================================================";
  add
    (Printf.sprintf "  Reconstructed at start:           %16s"
       (unsigned_val ~book m report.reconstructed_start));
  add
    (Printf.sprintf "  Reconstructed at end:             %16s"
       (unsigned_val ~book m report.reconstructed_end));
  add
    (Printf.sprintf "  Tracked increases across Events:  %16s"
       (signed_val ~book m report.increases_across_events));
  add
    (Printf.sprintf "  Tracked decreases across Events:  %16s"
       (signed_val ~book m report.decreases_across_events));
  add
    (Printf.sprintf "  Net change in tracked balance:    %16s"
       (match report.net_change with Some value -> signed_val ~book m value | None -> "—"));
  add
    (Printf.sprintf "  Current tracked balance now:      %16s"
       (unsigned_val ~book m report.current_tracked));
  add "--------------------------------------------------------------------------------";
  add
    ("  "
    ^ Printf.sprintf "%-*s %*s %*s %*s %*s %*s" col_name "Coordinate" col_num "Start" col_num "+In"
        col_num "-Out" col_num "End" col_num "Net");
  add "--------------------------------------------------------------------------------";
  List.iter
    (fun (c : SF.coordinate_activity) ->
      let amount = function Some value -> Book_display.format_money book m value | None -> "—" in
      let net = match c.net_change with Some value -> signed_val ~book m value | None -> "—" in
      add
        (Printf.sprintf "  %-*s %*s %*s %*s %*s %*s" col_name
           (coordinate_label ~book ~measure:m c)
           col_num (amount c.start_balance) col_num
           ("+" ^ Book_display.format_money book m c.increases)
           col_num
           (Book_display.format_money book m c.decreases)
           col_num (amount c.end_balance) col_num net))
    report.coordinates;
  List.iter
    (fun (id, day) ->
      add
        (Printf.sprintf
           "  The opening entry %s dated %s is left out of the in-window flows on both sides." id
           day))
    report.excluded_openings;
  if report.excluded_openings <> [] then
    add "  Start and End include those entries; +In and -Out do not.";
  List.iter
    (fun (c : SF.coordinate_activity) ->
      match support_note c with
      | Some note -> add (Printf.sprintf "  %s: %s" (coordinate_label ~book ~measure:m c) note)
      | None -> ())
    report.coordinates;
  List.iter
    (fun (locus, reason) -> add (Printf.sprintf "  %s/%s: %s" locus m (SF.missing_message reason)))
    report.unsupported;
  add "================================================================================";
  List.rev !lines
