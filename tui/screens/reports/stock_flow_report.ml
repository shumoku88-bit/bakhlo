(* Stock-Flow Report: single-measure tracked balance motion review matching LOAM. *)
module B = Bakhlo_sexp.Daily_book
module IncExp = Income_expense_report
module O = Daily_overlays
module A = Daily_draft
module D = Bakhlo_domain

type coordinate_activity = {
  locus : string;
  start_balance : Z.t;
  increases : Z.t;
  decreases : Z.t;
  net_change : Z.t;
  end_balance : Z.t;
  current_balance : Z.t;
}

type snapshot = {
  period : IncExp.period;
  measure : string;
  reconstructed_start : Z.t;
  reconstructed_end : Z.t;
  increases_across_events : Z.t;
  decreases_across_events : Z.t;
  net_change : Z.t;
  current_tracked : Z.t;
  coordinates : coordinate_activity list;
}

type report = snapshot
type t = { preset : IncExp.period_preset; period_offset : int }

let initial () = { preset = IncExp.Month; period_offset = 0 }

let compute_report ~book ~measure ~tracked_coords ~(period : IncExp.period) =
  if
    (not (A.is_valid_canonical_date period.start_day))
    || not (A.is_valid_canonical_date period.end_exclusive)
  then Error "loam: stock-flow endpoints must be real YYYY-MM-DD calendar dates"
  else if String.compare period.start_day period.end_exclusive >= 0 then
    Error "loam: stock-flow start must be earlier than end"
  else if tracked_coords = [] then
    Error "Stock–Flow requires a nonempty configured coordinate selection."
  else if List.exists (fun (_, m) -> m <> measure) tracked_coords then
    Error "Stock–Flow selected balances span multiple measures."
  else if List.length (List.sort_uniq compare tracked_coords) <> List.length tracked_coords then
    Error "Stock–Flow selected coordinates contain duplicates."
  else
    let rec qualify acc = function
      | [] -> Ok (List.rev acc)
      | (locus, _) :: rest -> (
          match O.quantity_value ~book ~measure locus with
          | O.Unsupported -> Error ("Current balance unsupported: " ^ locus ^ "/" ^ measure)
          | O.Known_present -> Error ("Current balance amount unknown: " ^ locus ^ "/" ^ measure)
          | O.Exact current ->
              if not (B.has_zero_origin book ~locus ~measure) then
                Error
                  ("Historical start unsupported: " ^ locus ^ "/" ^ measure
                 ^ "; current quantity alone does not justify history.")
              else qualify ((locus, current) :: acc) rest)
    in
    Result.bind (qualify [] tracked_coords) (fun balances ->
        let activities = Hashtbl.create (List.length balances) in
        List.iter (fun (locus, _) -> Hashtbl.add activities locus (Z.zero, Z.zero, Z.zero)) balances;
        let cells = Hashtbl.create (List.length balances) in
        let increases = ref Z.zero and decreases = ref Z.zero in
        let rec scan = function
          | [] -> Ok ()
          | (entry : B.entry) :: rest ->
              Hashtbl.clear cells;
              List.iter
                (fun posting ->
                  let locus = A.lstr (D.Effect.locus posting) in
                  if A.mstr (D.Effect.measure posting) = measure && Hashtbl.mem activities locus
                  then
                    let prior = Option.value ~default:Z.zero (Hashtbl.find_opt cells locus) in
                    Hashtbl.replace cells locus (Z.add prior (A.quanta posting)))
                entry.effects;
              if Hashtbl.length cells > 0 && not (A.is_valid_canonical_date entry.day) then
                Error ("Invalid occurrence date: " ^ entry.id)
              else begin
                let in_window = entry.day >= period.start_day && entry.day < period.end_exclusive in
                let event_net = ref Z.zero in
                Hashtbl.iter
                  (fun locus quantity ->
                    let start, positive, negative = Hashtbl.find activities locus in
                    let start =
                      if entry.day < period.start_day then Z.add start quantity else start
                    in
                    let positive =
                      if in_window && Z.sign quantity > 0 then Z.add positive quantity else positive
                    in
                    let negative =
                      if in_window && Z.sign quantity < 0 then Z.add negative quantity else negative
                    in
                    Hashtbl.replace activities locus (start, positive, negative);
                    event_net := Z.add !event_net quantity)
                  cells;
                if in_window then
                  begin if Z.sign !event_net > 0 then increases := Z.add !increases !event_net
                  else if Z.sign !event_net < 0 then decreases := Z.add !decreases !event_net
                  end;
                scan rest
              end
        in
        Result.map
          (fun () ->
            let coordinates =
              List.map
                (fun (locus, current_balance) ->
                  let start_balance, increases, decreases = Hashtbl.find activities locus in
                  let net_change = Z.add increases decreases in
                  {
                    locus;
                    start_balance;
                    increases;
                    decreases;
                    net_change;
                    end_balance = Z.add start_balance net_change;
                    current_balance;
                  })
                balances
            in
            let reconstructed_start =
              List.fold_left (fun total c -> Z.add total c.start_balance) Z.zero coordinates
            in
            let current_tracked =
              List.fold_left (fun total c -> Z.add total c.current_balance) Z.zero coordinates
            in
            let net_change = Z.add !increases !decreases in
            {
              period;
              measure;
              reconstructed_start;
              reconstructed_end = Z.add reconstructed_start net_change;
              increases_across_events = !increases;
              decreases_across_events = !decreases;
              net_change;
              current_tracked;
              coordinates;
            })
          (scan (B.entries book)))

let render_summary_lines ~width ~width_of ~book ~(report : report) =
  let pad_w = max 0 (width - 4) in
  let m = report.measure in
  let signed_val z = (if Z.sign z > 0 then "+" else "") ^ B.format book m z ^ " " ^ m in
  let unsigned_val z = B.format book m z ^ " " ^ m in
  let header =
    [
      (O.Heading, Printf.sprintf "Stock–Flow  [%s • %s]" report.period.label m);
      ( O.Chrome,
        Printf.sprintf "Window: %s .. %s (exclusive)" report.period.start_day
          report.period.end_exclusive );
      (O.Plain, "Why did the tracked balance change between two boundaries?");
      (O.Plain, "");
      ( O.Plain,
        Printf.sprintf "  %-36s %16s" "Reconstructed at start:"
          (unsigned_val report.reconstructed_start) );
      ( O.Plain,
        Printf.sprintf "  %-36s %16s" "Reconstructed at end:"
          (unsigned_val report.reconstructed_end) );
      (O.Plain, "");
      ( O.Plain,
        Printf.sprintf "  %-36s %16s" "Tracked increases across Events:"
          (signed_val report.increases_across_events) );
      ( O.Plain,
        Printf.sprintf "  %-36s %16s" "Tracked decreases across Events:"
          (signed_val report.decreases_across_events) );
      ( O.Active,
        Printf.sprintf "  %-36s %16s" "Net change in tracked balance:"
          (signed_val report.net_change) );
      (O.Plain, "");
      ( O.Chrome,
        Printf.sprintf "  %-36s %16s" "Current tracked balance now:"
          (unsigned_val report.current_tracked) );
      (O.Plain, "");
    ]
  in
  let col_name = max 14 (min 22 (pad_w * 25 / 100)) in
  let col_num = max 9 (min 12 ((pad_w - col_name - 8) / 5)) in
  let th =
    "  "
    ^ O.pad ~width_of col_name "Coordinate"
    ^ " "
    ^ O.pad_left ~width_of col_num "Start"
    ^ " "
    ^ O.pad_left ~width_of col_num "+In"
    ^ " "
    ^ O.pad_left ~width_of col_num "-Out"
    ^ " "
    ^ O.pad_left ~width_of col_num "End"
    ^ " "
    ^ O.pad_left ~width_of col_num "Net"
  in
  let rule = (O.Chrome, O.rule ~width_of pad_w) in
  let rows =
    List.map
      (fun (c : coordinate_activity) ->
        let label = B.label book c.locus in
        let name = if label <> "" && label <> c.locus then label ^ "/" ^ m else c.locus ^ "/" ^ m in
        let line =
          "  " ^ O.pad ~width_of col_name name ^ " "
          ^ O.pad_left ~width_of col_num (B.format book m c.start_balance)
          ^ " "
          ^ O.pad_left ~width_of col_num ("+" ^ B.format book m c.increases)
          ^ " "
          ^ O.pad_left ~width_of col_num (B.format book m c.decreases)
          ^ " "
          ^ O.pad_left ~width_of col_num (B.format book m c.end_balance)
          ^ " "
          ^ O.pad_left ~width_of col_num
              ((if Z.sign c.net_change > 0 then "+" else "") ^ B.format book m c.net_change)
        in
        (O.Plain, line))
      report.coordinates
  in
  let total_line =
    "  "
    ^ O.pad ~width_of col_name ("Total (" ^ m ^ ")")
    ^ " "
    ^ O.pad_left ~width_of col_num (B.format book m report.reconstructed_start)
    ^ " "
    ^ O.pad_left ~width_of col_num ("+" ^ B.format book m report.increases_across_events)
    ^ " "
    ^ O.pad_left ~width_of col_num (B.format book m report.decreases_across_events)
    ^ " "
    ^ O.pad_left ~width_of col_num (B.format book m report.reconstructed_end)
    ^ " "
    ^ O.pad_left ~width_of col_num
        ((if Z.sign report.net_change > 0 then "+" else "") ^ B.format book m report.net_change)
  in
  header @ [ (O.Chrome, th); rule ] @ rows @ [ rule; (O.Heading, total_line); (O.Plain, "") ]

let render_detail_lines ~width ~width_of ~book ~(report : report) =
  let m = report.measure in
  let signed_val z = (if Z.sign z > 0 then "+" else "") ^ B.format book m z ^ " " ^ m in
  let unsigned_val z = B.format book m z ^ " " ^ m in
  [
    (O.Heading, "Stock–Flow Principles & Evidence");
    ( O.Plain,
      Printf.sprintf "Period: %s (%s .. %s)" report.period.label report.period.start_day
        report.period.end_exclusive );
    (O.Plain, Printf.sprintf "Tracked Measure:                   %s" m);
    (O.Chrome, "");
    ( O.Plain,
      Printf.sprintf "Reconstructed at Start:            %16s"
        (unsigned_val report.reconstructed_start) );
    ( O.Plain,
      Printf.sprintf "Reconstructed at End:              %16s"
        (unsigned_val report.reconstructed_end) );
    ( O.Plain,
      Printf.sprintf "Tracked Increases across Events:   %16s"
        (signed_val report.increases_across_events) );
    ( O.Plain,
      Printf.sprintf "Tracked Decreases across Events:   %16s"
        (signed_val report.decreases_across_events) );
    ( O.Active,
      Printf.sprintf "Net Change in Tracked Balance:     %16s" (signed_val report.net_change) );
    ( O.Chrome,
      Printf.sprintf "Current Tracked Balance Now:       %16s" (unsigned_val report.current_tracked)
    );
    (O.Chrome, "");
    (O.Heading, "Principles & Integrity Notes:");
    ( O.Plain,
      "  - Historical boundaries require admitted zero-origin support; current quantities alone \
       are insufficient." );
    (O.Plain, "  - They are not archived historical balance snapshots.");
    (O.Plain, "  - Increases/decreases are tracked-balance movements, not income/spending.");
    (O.Plain, "  - Reconstructed end equals reconstructed start plus net change.");
    (O.Plain, "  - Single-measure observation only; unlike measures are never summed.");
    (O.Chrome, "");
    (O.Plain, "Keys & Navigation:");
    (O.Plain, "  1-5: Period presets (Month, Cycle, Prev Cycle, Year, All Time)");
    (O.Plain, "  [ / ]: Shift period back / forward");
    (O.Plain, "  Tab: Toggle report / detail pane");
    (O.Plain, "  p: Print preview");
    (O.Plain, "  Esc / q: Return to Home");
  ]

let print_summary ~book ~(report : report) =
  let lines = ref [] in
  let add s = lines := s :: !lines in
  let m = report.measure in
  let signed_val z = (if Z.sign z > 0 then "+" else "") ^ B.format book m z ^ " " ^ m in
  let unsigned_val z = B.format book m z ^ " " ^ m in
  add (Printf.sprintf "Stock–Flow Report - %s (%s)" report.period.label m);
  add
    (Printf.sprintf "Window: %s through %s (exclusive)" report.period.start_day
       report.period.end_exclusive);
  add "================================================================================";
  add
    (Printf.sprintf "  Reconstructed at start:           %16s"
       (unsigned_val report.reconstructed_start));
  add
    (Printf.sprintf "  Reconstructed at end:             %16s"
       (unsigned_val report.reconstructed_end));
  add
    (Printf.sprintf "  Tracked increases across Events:  %16s"
       (signed_val report.increases_across_events));
  add
    (Printf.sprintf "  Tracked decreases across Events:  %16s"
       (signed_val report.decreases_across_events));
  add (Printf.sprintf "  Net change in tracked balance:    %16s" (signed_val report.net_change));
  add
    (Printf.sprintf "  Current tracked balance now:      %16s"
       (unsigned_val report.current_tracked));
  add "--------------------------------------------------------------------------------";
  add "  Coordinate                 Start          +In         -Out          End          Net";
  add "--------------------------------------------------------------------------------";
  List.iter
    (fun (c : coordinate_activity) ->
      let label = B.label book c.locus in
      let name = if label <> "" && label <> c.locus then label ^ "/" ^ m else c.locus ^ "/" ^ m in
      add
        (Printf.sprintf "  %-22s %12s %12s %12s %12s %12s" name (B.format book m c.start_balance)
           ("+" ^ B.format book m c.increases)
           (B.format book m c.decreases) (B.format book m c.end_balance)
           ((if Z.sign c.net_change > 0 then "+" else "") ^ B.format book m c.net_change)))
    report.coordinates;
  add "--------------------------------------------------------------------------------";
  add
    (Printf.sprintf "  %-22s %12s %12s %12s %12s %12s"
       ("Total (" ^ m ^ ")")
       (B.format book m report.reconstructed_start)
       ("+" ^ B.format book m report.increases_across_events)
       (B.format book m report.decreases_across_events)
       (B.format book m report.reconstructed_end)
       ((if Z.sign report.net_change > 0 then "+" else "") ^ B.format book m report.net_change));
  add "================================================================================";
  List.rev !lines
