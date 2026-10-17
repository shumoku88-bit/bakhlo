(* Daily Pace Trend: retrospective current-truth spending pace analysis over 10d, 30d, month, cycle. *)
module B = Bakhlo_sexp.Daily_book
module O = Daily_overlays
module Cal = Daily_calendar
module A = Daily_actions
module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query
module F = Daily_file
module Panel = Ui_panel

type preset =
  | Ten_days
  | Thirty_days
  | Month
  | Cycle
  | Previous_cycle

type sample = {
  day : string;
  pace_quanta : Z.t option;
  available_through_end : Z.t;
  pool_balance : Z.t;
  deductions : Z.t;
  remaining_days : int;
  end_exclusive : string;
}

type graph_style = Line | Dots

type t = {
  preset : preset;
  selected_index : int;
  graph_style : graph_style;
  detail_focused : bool;
  detail_scroll : int;
}

let initial () =
  {
    preset = Ten_days;
    selected_index = 0;
    graph_style = Line;
    detail_focused = false;
    detail_scroll = 0;
  }

let preset_label = function
  | Ten_days -> "10d"
  | Thirty_days -> "30d"
  | Month -> "Month"
  | Cycle -> "Cycle"
  | Previous_cycle -> "Previous Cycle"

let presets = [ Ten_days; Thirty_days; Month; Cycle; Previous_cycle ]

let next_graph_style = function Line -> Dots | Dots -> Line

let graph_style_label = function Line -> "line" | Dots -> "dots"

let config_lines text =
  String.split_on_char '\n' text
  |> List.filter_map (fun line ->
         let s = String.trim line in
         if s = "" || String.starts_with ~prefix:"#" s then None else Some s)

let config_token s =
  s <> "" && String.for_all (fun c -> Char.code c > 32 && Char.code c <> 127) s

let canonical_date day =
  match A.normalize_date day with Ok c -> c = day | Error _ -> false

let rec increasing = function
  | a :: b :: rest -> a < b && increasing (b :: rest)
  | [] | [ _ ] -> true

let parse_boundary_presets text =
  let lines = config_lines text in
  let rec loop names acc = function
    | [] -> Ok acc
    | line :: rest ->
        match String.split_on_char '\t' line with
        | name :: dates
          when config_token name && not (List.mem name names)
               && List.length dates >= 2
               && List.for_all canonical_date dates
               && increasing dates ->
            let rec windows = function
              | a :: b :: tail -> (name, a, b) :: windows (b :: tail)
              | _ -> []
            in
            loop (name :: names) (acc @ windows dates) rest
        | _ -> Error "Malformed boundary-presets.tsv; no period was inferred."
  in
  loop [] [] lines

let resolve_range ~today ~preset ~boundary_presets_text =
  match preset with
  | Ten_days ->
      let start = match Cal.shift_days today (-9) with Ok d -> d | Error e -> failwith e in
      Ok (start, today, None)
  | Thirty_days ->
      let start = match Cal.shift_days today (-29) with Ok d -> d | Error e -> failwith e in
      Ok (start, today, None)
  | Month ->
      let start = String.sub today 0 8 ^ "01" in
      Ok (start, today, None)
  | Cycle -> (
      match boundary_presets_text with
      | None -> Error "Period not configured (boundary-presets.tsv missing)."
      | Some text -> (
          match parse_boundary_presets text with
          | Error e -> Error e
          | Ok windows -> (
              let matching = List.filter (fun (_, a, b) -> a <= today && today < b) windows in
              match matching with
              | [ (_, a, b) ] -> Ok (a, today, Some b)
              | [] -> Error "No explicit boundary preset contains today."
              | _ -> Error "Multiple boundary presets contain today; selection is ambiguous.")))
  | Previous_cycle -> (
      match boundary_presets_text with
      | None -> Error "Period not configured (boundary-presets.tsv missing)."
      | Some text -> (
          match parse_boundary_presets text with
          | Error e -> Error e
          | Ok windows -> (
              let current = List.filter (fun (_, a, b) -> a <= today && today < b) windows in
              match current with
              | [ (name, a, _) ] -> (
                  let prev_through = match Cal.shift_days a (-1) with Ok d -> d | Error e -> failwith e in
                  let prev = List.filter (fun (n, pa, pb) -> n = name && pa <= prev_through && prev_through < pb) windows in
                  match prev with
                  | [ (_, pa, pb) ] when pb = a -> Ok (pa, prev_through, Some pb)
                  | _ -> Error "Previous cycle boundary is not explicitly configured or not adjacent.")
              | [] -> Error "No explicit boundary preset contains today."
              | _ -> Error "Multiple boundary presets contain today; selection is ambiguous.")))

let day_number text =
  match Cal.parts text with
  | Error _ -> 0
  | Ok (y, m, d) ->
      let prev = y - 1 in
      let months = [| 0; 31; 59; 90; 120; 151; 181; 212; 243; 273; 304; 334 |] in
      let leap = y mod 400 = 0 || (y mod 4 = 0 && y mod 100 <> 0) in
      (365 * prev) + (prev / 4) - (prev / 100) + (prev / 400)
      + months.(m - 1) + d + (if leap && m > 2 then 1 else 0)

let dates_between start_day through_day =
  let start_num = day_number start_day in
  let end_num = day_number through_day in
  let count = max 0 (end_num - start_num + 1) in
  List.init count (fun i ->
      match Cal.shift_days start_day i with Ok d -> d | Error _ -> start_day)

(* Exact cause of a refused pool balance, with its coordinate when recoverable. *)
let format_pace_error why =
  let coordinate () =
    match String.split_on_char ':' why with
    | _ :: locus :: measure :: [] -> Some (locus ^ " " ^ measure)
    | _ -> None
  in
  let balance label =
    match coordinate () with Some c -> label ^ ": " ^ c | None -> label ^ "."
  in
  if String.starts_with ~prefix:"daily-pace-balance-amount-unknown:" why then
    balance "Pool locus balance is unknown"
  else if String.starts_with ~prefix:"daily-pace-balance-support-unknown:" why then
    balance "Pool locus balance support is unknown"
  else if String.equal why "daily-pace-non-positive-horizon" then
    "Period end must be after observation date."
  else if String.equal why "daily-pace-duplicate-coordinate" then
    "Duplicate coordinate in Daily Pace pool."
  else if String.equal why "daily-pace-pool-measure-mismatch" then
    "Daily Pace pool contains mixed Measures."
  else if String.equal why "unknown-measure" then "Unknown Measure in Daily Pace pool."
  else why

(* Sum exact pool balances; unknown or unsupported balances refuse instead of defaulting. *)
let query_pool_balance book measure coords =
  let rec sum acc = function
    | [] -> Ok acc
    | (c : D.Effect_coordinate.t) :: rest -> (
        match Q.query (B.image book) c with
        | Ok (Q.Exact answer) -> sum (Z.add acc (D.Quantity.quanta (Q.quantity answer))) rest
        | Ok (Q.Known_present _) ->
            Error
              (format_pace_error
                 ("daily-pace-balance-amount-unknown:" ^ A.lstr c.locus ^ ":" ^ A.mstr c.measure))
        | Error (Q.Support_unknown _) ->
            Error
              (format_pace_error
                 ("daily-pace-balance-support-unknown:" ^ A.lstr c.locus ^ ":" ^ A.mstr c.measure)))
  in
  sum Z.zero coords

let compute_samples ~book ~measure ~pool ~boundary_presets_text ~today ~preset =
  if pool = [] then Error "Daily Pace pool is empty."
  else
    match resolve_range ~today ~preset ~boundary_presets_text with
    | Error msg -> Error msg
    | Ok (start_day, through_day, cycle_end_opt) -> (
        let end_exclusive_res =
          match cycle_end_opt with
          | Some e -> Ok e
          | None -> (
              match boundary_presets_text with
              | None -> Error "Period not configured (boundary-presets.tsv missing)."
              | Some text -> (
                  match parse_boundary_presets text with
                  | Error e -> Error e
                  | Ok windows -> (
                      let matching =
                        List.filter (fun (_, a, b) -> a <= today && today < b) windows
                      in
                      match matching with
                      | [ (_, _, b) ] -> Ok b
                      | [] -> Error "No explicit boundary preset contains today."
                      | _ ->
                          Error
                            "Multiple boundary presets contain today; selection is ambiguous.")))
        in
        match end_exclusive_res with
        | Error why -> Error why
        | Ok end_exclusive -> (
            let coords =
              List.map
                (fun locus ->
                  {
                    D.Effect_coordinate.locus = A.get_id (D.Identifier.Locus.of_string locus);
                    measure = A.get_id (D.Identifier.Measure.of_string measure);
                  })
                pool
            in
            match query_pool_balance book measure coords with
            | Error why -> Error why
            | Ok current_pool_balance -> (
                let horizon_res =
                  if end_exclusive > today then
                    match
                      B.daily_pace book ~measure ~pool:coords ~observed_at:today ~end_exclusive
                    with
                    | Ok _ -> Ok ()
                    | Error why -> Error (format_pace_error why)
                  else Ok ()
                in
                match horizon_res with
                | Error why -> Error why
                | Ok () ->
                    let entries = B.entries book in
                    let plans = B.open_plans book in
                    let days = dates_between start_day through_day in
                    let samples =
                      List.map
                        (fun day ->
                          let remaining_days =
                            let d_num = day_number day in
                            let e_num = day_number end_exclusive in
                            max 0 (e_num - d_num)
                          in
                          if remaining_days <= 0 then
                            {
                              day;
                              pace_quanta = None;
                              available_through_end = Z.zero;
                              pool_balance = Z.zero;
                              deductions = Z.zero;
                              remaining_days = 0;
                              end_exclusive;
                            }
                          else
                            (* 1. Pool balance at date 'day' = current_pool_balance - sum(effects where entry.day > day) *)
                            let post_effects =
                              List.filter
                                (fun (e : B.entry) -> e.day > day && e.day <= today)
                                entries
                              |> List.concat_map (fun (e : B.entry) -> e.effects)
                              |> List.filter (fun eff ->
                                     A.mstr (D.Effect.measure eff) = measure
                                     && List.mem (A.lstr (D.Effect.locus eff)) pool)
                            in
                            let post_sum =
                              List.fold_left
                                (fun acc eff -> Z.add acc (A.quanta eff))
                                Z.zero post_effects
                            in
                            let pool_balance = Z.sub current_pool_balance post_sum in

                            (* 2. Plan deductions at date 'day' *)
                            let active_plans =
                              List.filter
                                (fun (p : B.plan) ->
                                  p.measure = measure && p.day >= day
                                  && p.day < end_exclusive && p.cancelled_on = None
                                  && p.paid_by = None)
                                plans
                            in
                            let deductions =
                              List.fold_left
                                (fun total (p : B.plan) ->
                                  let plan_net =
                                    List.fold_left
                                      (fun acc (loc, q) ->
                                        if List.mem loc pool then Z.add acc q else acc)
                                      Z.zero p.changes
                                  in
                                  if Z.sign plan_net < 0 then Z.add total (Z.neg plan_net)
                                  else total)
                                Z.zero active_plans
                            in
                            let available_through_end = Z.sub pool_balance deductions in
                            let pace_quanta =
                              if remaining_days > 0 then
                                Some (Z.ediv available_through_end (Z.of_int remaining_days))
                              else None
                            in
                            {
                              day;
                              pace_quanta;
                              available_through_end;
                              pool_balance;
                              deductions;
                              remaining_days;
                              end_exclusive;
                            })
                        days
                    in
                    Ok (start_day, through_day, samples))))

let render_trend ~width ~height ~width_of ~measure ~samples ~selected_index ~graph_style =
  if width < 8 || height < 4 || samples = [] then []
  else
    let count = List.length samples in
    let quant_list = List.filter_map (fun s -> s.pace_quanta) samples in
    if quant_list = [] then [ (O.Chrome, "No valid pace data in this period.") ]
    else
      let min_q = List.fold_left Z.min (List.hd quant_list) quant_list in
      let max_q = List.fold_left Z.max (List.hd quant_list) quant_list in
      let chart_h = max 3 (min 6 (height / 2 - 1)) in
      let axis_w = max 6 (min 10 (width_of (Z.to_string max_q))) in
      let plot_w = max 1 (width - axis_w - 4) in

      (* 1. Plot rows *)
      let plot_rows =
        List.init chart_h (fun row_idx ->
            let y_ratio =
              if chart_h <= 1 then 0.5
              else float_of_int (chart_h - 1 - row_idx) /. float_of_int (chart_h - 1)
            in
            let tick_val =
              let span = Z.to_float (Z.sub max_q min_q) in
              Z.add min_q (Z.of_float (span *. y_ratio))
            in
            let tick_str = O.pad_left ~width_of axis_w (Z.to_string tick_val) in
            let cols =
              String.init plot_w (fun col_idx ->
                  let sample_idx =
                    if plot_w <= 1 then 0
                    else col_idx * (count - 1) / (plot_w - 1)
                  in
                  let sample = List.nth samples (min (count - 1) sample_idx) in
                  let is_sel = sample_idx = selected_index in
                  match sample.pace_quanta with
                  | None -> ' '
                  | Some q ->
                      let target_row =
                        if Z.equal max_q min_q then chart_h / 2
                        else
                          let frac =
                            Z.to_float (Z.sub q min_q) /. Z.to_float (Z.sub max_q min_q)
                          in
                          chart_h - 1 - int_of_float (frac *. float_of_int (chart_h - 1))
                      in
                      if target_row = row_idx then
                        if is_sel then '^'
                        else match graph_style with Line -> '*' | Dots -> '.'
                      else if is_sel && row_idx > target_row then '|'
                      else ' ')
            in
            (O.Plain, tick_str ^ " │ " ^ cols))
      in

      (* 2. Axis rule *)
      let axis_rule =
        (O.Chrome, String.make axis_w ' ' ^ " ╰─" ^ O.rule ~width_of plot_w)
      in

      (* 3. Timeline samples list *)
      let list_capacity = max 0 (height - chart_h - 2) in
      let start_idx = max 0 (min (count - list_capacity) (selected_index - list_capacity / 2)) in
      let visible_samples =
        samples
        |> List.filteri (fun i _ -> i >= start_idx && i < start_idx + list_capacity)
      in
      let sample_lines =
        List.mapi
          (fun local_idx (s : sample) ->
            let global_idx = start_idx + local_idx in
            let is_sel = global_idx = selected_index in
            let marker = if is_sel then "> " else "  " in
            let pace_str =
              match s.pace_quanta with
              | Some q -> Z.to_string q ^ " " ^ measure ^ "/day"
              | None -> "unavailable"
            in
            let change_str =
              if global_idx = 0 then ""
              else
                let prev = List.nth samples (global_idx - 1) in
                match s.pace_quanta, prev.pace_quanta with
                | Some cur, Some prv ->
                    let diff = Z.sub cur prv in
                    let sign = if Z.sign diff > 0 then "+" else "" in
                    " (" ^ sign ^ Z.to_string diff ^ ")"
                | _ -> ""
            in
            let line_text =
              marker ^ s.day ^ "  " ^ O.pad_left ~width_of 16 pace_str ^ change_str
            in
            let style = if is_sel then O.Active else O.Plain in
            (style, O.pad ~width_of width line_text))
          visible_samples
      in
      plot_rows @ [ axis_rule ] @ sample_lines

let render_detail ~width ~width_of ~book ~measure ~sample ~prev_sample ~today ~preset =
  match sample with
  | None -> [ (O.Chrome, "No sample selected.") ]
  | Some s ->
      let header =
        [
          (O.Heading, "Daily Pace Detail");
          (O.Plain, "Selected date: " ^ s.day ^ (if s.day = today then " (Today)" else ""));
          (O.Plain, "Period: " ^ preset_label preset);
          (O.Chrome, "");
        ]
      in
      let pace_line =
        match s.pace_quanta with
        | Some q ->
            let change =
              match prev_sample with
              | Some ps -> (
                  match ps.pace_quanta with
                  | Some pq ->
                      let diff = Z.sub q pq in
                      let sign = if Z.sign diff > 0 then "+" else "" in
                      " (change: " ^ sign ^ Z.to_string diff ^ " " ^ measure ^ "/day)"
                  | None -> "")
              | None -> ""
            in
            [ (O.Active, "Daily Pace: " ^ B.format book measure q ^ " " ^ measure ^ "/day" ^ change) ]
        | None -> [ (O.Status, "Daily Pace: unavailable") ]
      in
      let breakdown =
        [
          (O.Chrome, "");
          (O.Plain, "Through end: " ^ B.format book measure s.available_through_end ^ " " ^ measure ^ " (Available)");
          (O.Plain, Printf.sprintf "Period progress: %d days remaining to cycle end" s.remaining_days);
          (O.Plain, "Pool accounts balance: " ^ B.format book measure s.pool_balance ^ " " ^ measure);
          (O.Plain, "Protected scheduled:   -" ^ B.format book measure s.deductions ^ " " ^ measure);
          (O.Plain, "Days remaining:        " ^ string_of_int s.remaining_days ^ " days");
          (O.Plain, "Cycle end (exclusive): " ^ s.end_exclusive);
          (O.Plain, "Source: Pool [config/daily-pace.tsv] | Window [config/boundary-presets.tsv]");
          (O.Chrome, "");
          (O.Chrome, "Reconstructed current truth; no separate daily snapshot is kept.");
        ]
      in
      header @ pace_line @ breakdown
