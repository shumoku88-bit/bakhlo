(* Stock-Flow Report: reconciliation of tracked balance changes (Stock) with window activity (Flow). *)
module B = Bakhlo_sexp.Daily_book
module IncExp = Income_expense_report
module O = Daily_overlays
module A = Daily_actions
module D = Bakhlo_domain

type coordinate_activity = {
  locus : string;
  measure : string;
  start_balance : Z.t;
  increases : Z.t;
  decreases : Z.t;
  net_change : Z.t;
  end_balance : Z.t;
  current_balance : Z.t;
}

type measure_summary = {
  measure : string;
  reconstructed_start : Z.t;
  reconstructed_end : Z.t;
  increases : Z.t;
  decreases : Z.t;
  net_change : Z.t;
  current_tracked : Z.t;
  net_income : Z.t;
  reconciliation_gap : Z.t;
  coordinates : coordinate_activity list;
}

type report = {
  period : IncExp.period;
  summaries : measure_summary list;
}

type t = {
  preset : IncExp.period_preset;
  period_offset : int;
  selected_measure : int;
  detail_focused : bool;
  detail_scroll : int;
}

let initial () =
  {
    preset = IncExp.Month;
    period_offset = 0;
    selected_measure = 0;
    detail_focused = false;
    detail_scroll = 0;
  }

let compute_report ~book ~roles ~tracked_coords ~(period : IncExp.period) =
  let coords =
    if tracked_coords <> [] then tracked_coords
    else
      let loci = Option.value ~default:[] (B.approved_loci book) in
      let measures = List.map fst (B.measures book) in
      List.concat_map (fun l -> List.map (fun m -> (l, m)) measures) loci
  in
  let measures =
    List.map fst (B.measures book)
    |> List.sort_uniq String.compare
  in
  let entries = B.entries book in
  let ie_report = IncExp.compute_report ~book ~roles ~period in

  let summaries =
    List.map
      (fun measure ->
        let measure_coords =
          List.filter (fun (_, m) -> m = measure) coords
        in
        let coord_activities =
          List.map
            (fun (locus, _) ->
              let cur_val =
                match O.quantity_value ~book ~measure locus with
                | O.Exact z -> z
                | O.Unsupported | O.Known_present -> Z.zero
              in
              let delta_after_start = ref Z.zero in
              let inc = ref Z.zero in
              let dec = ref Z.zero in
              List.iter
                (fun (e : B.entry) ->
                  List.iter
                    (fun eff ->
                      let l = A.lstr (D.Effect.locus eff) in
                      let m = A.mstr (D.Effect.measure eff) in
                      if l = locus && m = measure then
                        let q = A.quanta eff in
                        if e.day >= period.start_day then
                          delta_after_start := Z.add !delta_after_start q;
                        if e.day >= period.start_day && e.day < period.end_exclusive then
                          if Z.sign q > 0 then inc := Z.add !inc q
                          else if Z.sign q < 0 then dec := Z.add !dec q)
                    e.effects)
                entries;
              let start_bal = Z.sub cur_val !delta_after_start in
              let net = Z.add !inc !dec in
              let end_bal = Z.add start_bal net in
              {
                locus;
                measure;
                start_balance = start_bal;
                increases = !inc;
                decreases = !dec;
                net_change = net;
                end_balance = end_bal;
                current_balance = cur_val;
              })
            measure_coords
        in
        let rec_start =
          List.fold_left (fun acc (c : coordinate_activity) -> Z.add acc c.start_balance) Z.zero coord_activities
        in
        let rec_end =
          List.fold_left (fun acc (c : coordinate_activity) -> Z.add acc c.end_balance) Z.zero coord_activities
        in
        let total_inc =
          List.fold_left (fun acc (c : coordinate_activity) -> Z.add acc c.increases) Z.zero coord_activities
        in
        let total_dec =
          List.fold_left (fun acc (c : coordinate_activity) -> Z.add acc c.decreases) Z.zero coord_activities
        in
        let total_net = Z.add total_inc total_dec in
        let cur_tracked =
          List.fold_left (fun acc (c : coordinate_activity) -> Z.add acc c.current_balance) Z.zero coord_activities
        in
        let net_income =
          match List.find_opt (fun (r : IncExp.measure_summary) -> r.measure = measure) ie_report.summaries with
          | Some r -> r.net_savings
          | None -> Z.zero
        in
        let gap = Z.sub total_net net_income in
        {
          measure;
          reconstructed_start = rec_start;
          reconstructed_end = rec_end;
          increases = total_inc;
          decreases = total_dec;
          net_change = total_net;
          current_tracked = cur_tracked;
          net_income;
          reconciliation_gap = gap;
          coordinates = coord_activities;
        })
      measures
  in
  { period; summaries }

let render_summary_lines ~width ~width_of ~book ~report ~selected_measure =
  let pad_w = max 0 (width - 4) in
  let header =
    [
      (O.Heading, Printf.sprintf "Stock–Flow  [%s]" report.period.label);
      (O.Chrome, Printf.sprintf "Window: %s .. %s (exclusive)" report.period.start_day report.period.end_exclusive);
      (O.Plain, "Why did the tracked balance change between two boundaries?");
      (O.Plain, "");
    ]
  in
  let summary_lines =
    List.concat_map
      (fun (s : measure_summary) ->
        let m = s.measure in
        let fmt z = B.format book m z ^ " " ^ m in
        let fmt_signed z = (if Z.sign z > 0 then "+" else "") ^ B.format book m z ^ " " ^ m in
        let block =
          [
            (O.Heading, Printf.sprintf "--- Tracked Balance Motion (%s) ---" m);
            (O.Plain, Printf.sprintf "  %-34s %16s" "Reconstructed at start:" (fmt s.reconstructed_start));
            (O.Plain, Printf.sprintf "  %-34s %16s" "Reconstructed at end:" (fmt s.reconstructed_end));
            (O.Plain, "");
            (O.Plain, Printf.sprintf "  %-34s %16s" "Tracked increases across Events:" (fmt_signed s.increases));
            (O.Plain, Printf.sprintf "  %-34s %16s" "Tracked decreases across Events:" (fmt_signed s.decreases));
            (O.Active, Printf.sprintf "  %-34s %16s" "Net change in tracked balance:" (fmt_signed s.net_change));
            (O.Plain, "");
            (O.Chrome, Printf.sprintf "  %-34s %16s" "Current tracked balance now:" (fmt s.current_tracked));
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
                "  "
                ^ O.pad ~width_of col_name name
                ^ " "
                ^ O.pad_left ~width_of col_num (B.format book m c.start_balance)
                ^ " "
                ^ O.pad_left ~width_of col_num ("+" ^ B.format book m c.increases)
                ^ " "
                ^ O.pad_left ~width_of col_num (B.format book m c.decreases)
                ^ " "
                ^ O.pad_left ~width_of col_num (B.format book m c.end_balance)
                ^ " "
                ^ O.pad_left ~width_of col_num ((if Z.sign c.net_change > 0 then "+" else "") ^ B.format book m c.net_change)
              in
              (O.Plain, line))
            s.coordinates
        in
        let total_line =
          "  "
          ^ O.pad ~width_of col_name ("Total (" ^ m ^ ")")
          ^ " "
          ^ O.pad_left ~width_of col_num (B.format book m s.reconstructed_start)
          ^ " "
          ^ O.pad_left ~width_of col_num ("+" ^ B.format book m s.increases)
          ^ " "
          ^ O.pad_left ~width_of col_num (B.format book m s.decreases)
          ^ " "
          ^ O.pad_left ~width_of col_num (B.format book m s.reconstructed_end)
          ^ " "
          ^ O.pad_left ~width_of col_num ((if Z.sign s.net_change > 0 then "+" else "") ^ B.format book m s.net_change)
        in
        block @ [ (O.Chrome, th); rule ] @ rows @ [ rule; (O.Heading, total_line); (O.Plain, "") ])
      report.summaries
  in
  header @ summary_lines

let render_detail_lines ~width ~width_of ~book ~report ~selected_measure =
  let summary_opt = List.nth_opt report.summaries selected_measure in
  let summary = match summary_opt with Some s -> s | None -> match report.summaries with s :: _ -> s | [] -> failwith "no summaries" in
  let m = summary.measure in
  let fmt_signed z = (if Z.sign z > 0 then "+" else "") ^ B.format book m z ^ " " ^ m in
  let is_balanced = Z.equal summary.reconciliation_gap Z.zero in
  let status_style, status_text =
    if is_balanced then (O.Heading, "Balanced: Exact reconciliation (ΔStock = Net Savings)")
    else (O.Status, Printf.sprintf "Unreconciled Gap: %s (difference between Stock and Flow)" (fmt_signed summary.reconciliation_gap))
  in
  [
    (O.Heading, "Stock–Flow Accounting Reconciliation");
    (O.Plain, Printf.sprintf "Period: %s (%s .. %s)" report.period.label report.period.start_day report.period.end_exclusive);
    (O.Chrome, "");
    (O.Plain, Printf.sprintf "Tracked Measure:                   %s" m);
    (O.Plain, Printf.sprintf "Net Change in Stock (ΔAssets):     %16s" (fmt_signed summary.net_change));
    (O.Plain, Printf.sprintf "Net Savings in Flow (Income-Exp):  %16s" (fmt_signed summary.net_income));
    (O.Plain, Printf.sprintf "Reconciliation Discrepancy:        %16s" (fmt_signed summary.reconciliation_gap));
    (O.Chrome, "");
    status_style, status_text;
    (O.Chrome, "");
    (O.Heading, "Principles & Integrity Notes:");
    (O.Plain, "  - Boundary values are reconstructed from current accepted evidence.");
    (O.Plain, "  - They are not archived historical balance snapshots.");
    (O.Plain, "  - Increases/decreases are tracked-balance movements, not income/spending.");
    (O.Plain, "  - In a closed double-entry ledger, ΔAssets equals Net Savings.");
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
  add (Printf.sprintf "Stock–Flow Report - %s" report.period.label);
  add (Printf.sprintf "Window: %s through %s (exclusive)" report.period.start_day report.period.end_exclusive);
  add "================================================================================";
  List.iter
    (fun (s : measure_summary) ->
      let m = s.measure in
      let fmt z = B.format book m z ^ " " ^ m in
      let fmt_signed z = (if Z.sign z > 0 then "+" else "") ^ B.format book m z ^ " " ^ m in
      add (Printf.sprintf "--- Tracked Balance Motion (%s) ---" m);
      add (Printf.sprintf "  Reconstructed at start:           %16s" (fmt s.reconstructed_start));
      add (Printf.sprintf "  Reconstructed at end:             %16s" (fmt s.reconstructed_end));
      add (Printf.sprintf "  Tracked increases across Events:  %16s" (fmt_signed s.increases));
      add (Printf.sprintf "  Tracked decreases across Events:  %16s" (fmt_signed s.decreases));
      add (Printf.sprintf "  Net change in tracked balance:    %16s" (fmt_signed s.net_change));
      add (Printf.sprintf "  Current tracked balance now:      %16s" (fmt s.current_tracked));
      add (Printf.sprintf "  Net Savings from Flow:            %16s" (fmt_signed s.net_income));
      add (Printf.sprintf "  Reconciliation Gap:               %16s" (fmt_signed s.reconciliation_gap));
      add "--------------------------------------------------------------------------------";
      add "  Coordinate                 Start          +In         -Out          End          Net";
      add "--------------------------------------------------------------------------------";
      List.iter
        (fun (c : coordinate_activity) ->
          let label = B.label book c.locus in
          let name = if label <> "" && label <> c.locus then label ^ "/" ^ m else c.locus ^ "/" ^ m in
          add (Printf.sprintf "  %-22s %12s %12s %12s %12s %12s"
                 name
                 (B.format book m c.start_balance)
                 ("+" ^ B.format book m c.increases)
                 (B.format book m c.decreases)
                 (B.format book m c.end_balance)
                 ((if Z.sign c.net_change > 0 then "+" else "") ^ B.format book m c.net_change)))
        s.coordinates;
      add "--------------------------------------------------------------------------------")
    report.summaries;
  List.rev !lines
