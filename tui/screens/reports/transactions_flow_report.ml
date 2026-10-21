(* Transactions Flow Report: incidence matrix of activity per coordinate, sorted by gross volume. *)
module B = Bakhlo_sexp.Daily_book
module IncExp = Income_expense_report
module O = Daily_overlays
module A = Daily_draft
module D = Bakhlo_domain

type row_activity = {
  locus : string;
  measure : string;
  positive : Z.t;
  negative : Z.t;
  net : Z.t;
  gross : Z.t;
  active_events : int;
  contributions : (string * Z.t * string * string) list;
}

type report = { period : IncExp.period; rows : row_activity list }

type t = {
  preset : IncExp.period_preset;
  period_offset : int;
  selected_row : int;
  detail_focused : bool;
  detail_scroll : int;
}

let initial () =
  {
    preset = IncExp.Month;
    period_offset = 0;
    selected_row = 0;
    detail_focused = false;
    detail_scroll = 0;
  }

let compute_report ~book ~(period : IncExp.period) =
  let entries = B.entries book in
  let in_period (e : B.entry) = e.day >= period.start_day && e.day < period.end_exclusive in
  let period_entries = List.filter in_period entries in
  let table = Hashtbl.create 16 in

  List.iter
    (fun (e : B.entry) ->
      List.iter
        (fun eff ->
          let locus = A.lstr (D.Effect.locus eff) in
          let measure = A.mstr (D.Effect.measure eff) in
          let quanta = A.quanta eff in
          let key = (locus, measure) in
          let pos, neg, ev_count, contribs =
            match Hashtbl.find_opt table key with
            | Some (p, n, c, cb) -> (p, n, c, cb)
            | None -> (Z.zero, Z.zero, 0, [])
          in
          let new_pos = if Z.sign quanta > 0 then Z.add pos quanta else pos in
          let new_neg = if Z.sign quanta < 0 then Z.add neg quanta else neg in
          let new_ev = ev_count + 1 in
          let desc = Option.value ~default:"" e.memo in
          let new_contribs = (e.day, quanta, desc, e.id) :: contribs in
          Hashtbl.replace table key (new_pos, new_neg, new_ev, new_contribs))
        e.effects)
    period_entries;

  let raw_rows =
    Hashtbl.fold
      (fun (locus, measure) (positive, negative, active_events, contributions) acc ->
        let net = Z.add positive negative in
        let gross = Z.sub positive negative in
        {
          locus;
          measure;
          positive;
          negative;
          net;
          gross;
          active_events;
          contributions = List.rev contributions;
        }
        :: acc)
      table []
  in
  let sorted_rows =
    List.sort
      (fun a b ->
        let cmp_gross = Z.compare b.gross a.gross in
        if cmp_gross <> 0 then cmp_gross
        else
          let cmp_locus = String.compare a.locus b.locus in
          if cmp_locus <> 0 then cmp_locus else String.compare a.measure b.measure)
      raw_rows
  in
  { period; rows = sorted_rows }

let render_summary_lines ~width ~width_of ~book ~report ~selected_row =
  let pad_w = max 0 (width - 4) in
  let header =
    [
      (O.Heading, Printf.sprintf "Transactions Flow  [%s]" report.period.label);
      ( O.Chrome,
        Printf.sprintf "Window: %s .. %s (exclusive)" report.period.start_day
          report.period.end_exclusive );
      ( O.Plain,
        Printf.sprintf "%d active coordinate(s); zero cells omitted. Sorted by gross volume."
          (List.length report.rows) );
      (O.Plain, "");
    ]
  in
  if report.rows = [] then header @ [ (O.Chrome, "  (no transaction activity in this window)") ]
  else
    let col_coord = max 14 (min 24 (pad_w * 30 / 100)) in
    let col_num = max 9 (min 13 ((pad_w - col_coord - 10) / 4)) in
    let col_ev = max 6 (pad_w - col_coord - (col_num * 4) - 4) in

    let th =
      "  "
      ^ O.pad ~width_of col_coord "Coordinate"
      ^ " "
      ^ O.pad_left ~width_of col_num "Net"
      ^ " "
      ^ O.pad_left ~width_of col_num "Gross"
      ^ " "
      ^ O.pad_left ~width_of col_num "+In"
      ^ " "
      ^ O.pad_left ~width_of col_num "-Out"
      ^ " "
      ^ O.pad_left ~width_of col_ev "Events"
    in
    let rule = (O.Chrome, O.rule ~width_of pad_w) in

    let rows_text =
      List.mapi
        (fun idx (r : row_activity) ->
          let is_sel = idx = selected_row in
          let marker = if is_sel then "> " else "  " in
          let coord_token =
            let label = B.label book r.locus in
            if label <> "" && label <> r.locus then Printf.sprintf "%s/%s" label r.measure
            else Printf.sprintf "%s/%s" r.locus r.measure
          in
          let net_str = (if Z.sign r.net > 0 then "+" else "") ^ B.format book r.measure r.net in
          let gross_str = B.format book r.measure r.gross in
          let pos_str = "+" ^ B.format book r.measure r.positive in
          let neg_str = B.format book r.measure r.negative in
          let ev_str = string_of_int r.active_events in
          let line_text =
            marker
            ^ O.pad ~width_of col_coord coord_token
            ^ " "
            ^ O.pad_left ~width_of col_num net_str
            ^ " "
            ^ O.pad_left ~width_of col_num gross_str
            ^ " "
            ^ O.pad_left ~width_of col_num pos_str
            ^ " "
            ^ O.pad_left ~width_of col_num neg_str
            ^ " "
            ^ O.pad_left ~width_of col_ev ev_str
          in
          let style = if is_sel then O.Active else O.Plain in
          (style, line_text))
        report.rows
    in
    header @ [ (O.Chrome, th); rule ] @ rows_text

let render_detail_lines ~book ~report ~selected_row =
  match List.nth_opt report.rows selected_row with
  | None ->
      [
        (O.Heading, "Transactions Flow Overview");
        (O.Plain, "Select an active coordinate from the table to view its transactions.");
        (O.Chrome, "");
        (O.Plain, "Keys & Navigation:");
        (O.Plain, "  1-5: Period presets (Month, Cycle, Prev Cycle, Year, All Time)");
        (O.Plain, "  [ / ]: Shift period back / forward");
        (O.Plain, "  j / k: Select coordinate row");
        (O.Plain, "  Tab: Toggle table / details");
        (O.Plain, "  p: Print preview");
        (O.Plain, "  Esc / q: Return to Home");
      ]
  | Some r ->
      let label = B.label book r.locus in
      let locus_name =
        if label <> "" && label <> r.locus then Printf.sprintf "%s [%s]" label r.locus else r.locus
      in
      let header =
        [
          (O.Heading, "Coordinate Flow Details");
          (O.Active, Printf.sprintf "Locus: %s   Measure: %s" locus_name r.measure);
          ( O.Plain,
            Printf.sprintf "Period: %s (%s .. %s)" report.period.label report.period.start_day
              report.period.end_exclusive );
          (O.Chrome, "");
          ( O.Plain,
            Printf.sprintf "Net Activity:   %s%s %s"
              (if Z.sign r.net > 0 then "+" else "")
              (B.format book r.measure r.net) r.measure );
          ( O.Plain,
            Printf.sprintf "Gross Volume:   %s %s" (B.format book r.measure r.gross) r.measure );
          ( O.Plain,
            Printf.sprintf "Total Inflows:  +%s %s" (B.format book r.measure r.positive) r.measure
          );
          ( O.Plain,
            Printf.sprintf "Total Outflows: %s %s" (B.format book r.measure r.negative) r.measure );
          (O.Plain, Printf.sprintf "Total Events:   %d transactions" r.active_events);
          (O.Chrome, "");
          (O.Heading, "Contributing Transactions:");
        ]
      in
      let contrib_lines =
        List.map
          (fun (date, quanta, memo, id) ->
            let amt =
              (if Z.sign quanta > 0 then "+" else "")
              ^ B.format book r.measure quanta ^ " " ^ r.measure
            in
            let desc = if memo = "" then "[" ^ id ^ "]" else memo ^ "  [" ^ id ^ "]" in
            (O.Plain, Printf.sprintf "  %s  %14s  %s" date amt desc))
          r.contributions
      in
      header @ contrib_lines

let print_summary ~book ~(report : report) =
  let lines = ref [] in
  let add s = lines := s :: !lines in
  add (Printf.sprintf "Transactions Flow Report - %s" report.period.label);
  add
    (Printf.sprintf "Window: %s through %s (exclusive)" report.period.start_day
       report.period.end_exclusive);
  add (Printf.sprintf "Active Coordinates: %d" (List.length report.rows));
  add "================================================================================";
  add "  Coordinate                 Net         Gross          +In         -Out  Events";
  add "--------------------------------------------------------------------------------";
  List.iter
    (fun (r : row_activity) ->
      let label = B.label book r.locus in
      let name =
        if label <> "" && label <> r.locus then label ^ "/" ^ r.measure
        else r.locus ^ "/" ^ r.measure
      in
      let net =
        (if Z.sign r.net > 0 then "+" else "") ^ B.format book r.measure r.net ^ " " ^ r.measure
      in
      let gross = B.format book r.measure r.gross ^ " " ^ r.measure in
      let pos = "+" ^ B.format book r.measure r.positive in
      let neg = B.format book r.measure r.negative in
      add (Printf.sprintf "  %-24s %12s %12s %12s %12s %6d" name net gross pos neg r.active_events))
    report.rows;
  List.rev !lines
