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
                (* Keep the current answer; past-day reconstruction stays unchanged. *)
                let horizon_pace =
                  if end_exclusive > today then
                    match
                      B.daily_pace book ~measure ~pool:coords ~observed_at:today ~end_exclusive
                    with
                    | Ok pace -> Ok (Some pace)
                    | Error why -> Error (format_pace_error why)
                  else Ok None
                in
                match horizon_pace with
                | Error why -> Error why
                | Ok today_pace ->
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
                            (match today_pace with
                            | Some pace when day = today ->
                                {
                                  day;
                                  pace_quanta = Some pace.B.daily_pace_quanta;
                                  available_through_end = pace.B.available_through_end;
                                  pool_balance = pace.B.eligible_pool;
                                  deductions = pace.B.automatic_deductions;
                                  remaining_days = pace.B.remaining_days;
                                  end_exclusive;
                                }
                            | _ ->
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
                            }))
                        days
                    in
                    Ok (start_day, through_day, samples))))

(* Cursor within the actually rendered range: clamp the stored index to the
   real last row before stepping. Range failure stays an explicit error. *)
let move_selection ~today ~preset ~boundary_presets_text ~position delta =
  match resolve_range ~today ~preset ~boundary_presets_text with
  | Error msg -> Error msg
  | Ok (start_day, through_day, _) ->
      let last = max 0 (day_number through_day - day_number start_day) in
      Ok (Panel.move ~last ~position delta)

(* Braille 2x4 subcell plot with integer-only nice ticks.
   Amounts use the book's Measure scale with 3-digit grouping, never raw
   quanta; a value that cannot fit is omitted whole, never cut mid-number. *)
let group_digits text =
  let len = String.length text in
  let out = Buffer.create (len + len / 3) in
  String.iteri (fun i ch ->
    if i > 0 && (len - i) mod 3 = 0 then Buffer.add_char out ',';
    Buffer.add_char out ch) text;
  Buffer.contents out

let format_money book measure q =
  let raw = B.format book measure q in
  let sign = String.starts_with ~prefix:"-" raw in
  let digits = if sign then String.sub raw 1 (String.length raw - 1) else raw in
  let int_part, frac =
    match String.index_opt digits '.' with
    | None -> (digits, None)
    | Some dot ->
        ( String.sub digits 0 dot,
          Some (String.sub digits (dot + 1) (String.length digits - dot - 1)) )
  in
  (if sign then "-" else "") ^ group_digits int_part
  ^ (match frac with None -> "" | Some f -> "." ^ f)

let ceil_div a b = if Z.sign a >= 0 then Z.div (Z.add a (Z.sub b Z.one)) b else Z.div a b

let nice_ceiling raw =
  (* raw is positive; 1/2/5×10^n cover, all in Z so 400-digit spans stay bounded. *)
  assert (Z.sign raw > 0);
  let digits = String.length (Z.to_string raw) - 1 in
  let unit = Z.pow (Z.of_int 10) digits in
  if Z.compare raw unit <= 0 then unit
  else if Z.compare raw (Z.mul unit (Z.of_int 2)) <= 0 then Z.mul unit (Z.of_int 2)
  else if Z.compare raw (Z.mul unit (Z.of_int 5)) <= 0 then Z.mul unit (Z.of_int 5)
  else Z.mul unit (Z.of_int 10)

let short_day day = if String.length day >= 10 then String.sub day 5 5 else day

let braille_mask =
  [| (0, 0, 0x01); (0, 1, 0x02); (0, 2, 0x04); (1, 0, 0x08); (1, 1, 0x10); (1, 2, 0x20); (0, 3, 0x40); (1, 3, 0x80) |]

let render_trend ~width ~height ~width_of ~book ~today ~measure ~samples ~selected_index ~graph_style =
  if width < 8 || height < 1 || samples = [] then []
  else
    let count = List.length samples in
    let arr = Array.of_list samples in
    let selected = Panel.move ~last:(count - 1) ~position:selected_index 0 in
    let sel = arr.(selected) in
    let money q = format_money book measure q ^ " " ^ measure ^ "/day" in
    let mark = if sel.day = today then " (today)" else "" in
    let full_summary =
      match sel.pace_quanta with
      | Some q -> sel.day ^ mark ^ " ◆ " ^ money q
      | None -> sel.day ^ mark ^ " unavailable"
    in
    let summary =
      if width_of full_summary <= width then full_summary
      else
        let compact =
          match sel.pace_quanta with
          | Some q -> sel.day ^ mark ^ " ◆ " ^ format_money book measure q
          | None -> sel.day ^ mark ^ " unavailable"
        in
        let bare =
          match sel.pace_quanta with
          | Some q -> sel.day ^ " ◆ " ^ money q
          | None -> sel.day ^ " unavailable"
        in
        let cue = sel.day ^ " ◆ … (i detail)" in
        if width_of bare <= width then bare
        else if width_of compact <= width then compact
        else if width_of cue <= width then cue
        else O.clip_text ~width_of width (sel.day ^ " ◆ …")
    in
    let summary_row = (O.Active, O.pad ~width_of width summary) in
    (* The sample list yields to graph and selection: change drops before
       amounts, and an unfit amount becomes an explicit detail cue. *)
    let list_rows cap start =
      List.init cap (fun k ->
          let i = start + k in
          let s = arr.(i) in
          let marker = if i = selected then "◆ " else if s.pace_quanta = None then "  " else "● " in
          let pace_text =
            match s.pace_quanta with
            | None -> "unavailable"
            | Some q ->
                let base = money q in
                let change =
                  if i = 0 then ""
                  else
                    match arr.(i - 1).pace_quanta with
                    | None -> ""
                    | Some p ->
                        let diff = Z.sub q p in
                        if Z.equal diff Z.zero then ""
                        else " (" ^ (if Z.sign diff > 0 then "+" else "") ^ format_money book measure diff ^ ")"
                in
                if width_of (marker ^ s.day ^ "  " ^ base ^ change) <= width then base ^ change
                else if width_of (marker ^ s.day ^ "  " ^ base) <= width then base
                else "…"
          in
          let full_row = marker ^ s.day ^ "  " ^ pace_text in
          let row_text = if width_of full_row <= width then full_row else marker ^ s.day ^ "  …" in
          ((if i = selected then O.Active else O.Plain), O.pad ~width_of width row_text))
    in
    if height < 3 then [ summary_row ]
    else
      let plot_h = max 1 (min 12 (if height >= 10 then (height - 2) / 2 else height - 2)) in
      let valid =
        Array.fold_left (fun acc s -> match s.pace_quanta with None -> acc | Some q -> q :: acc) [] arr
      in
      match valid with
      | [] ->
          let list_cap = max 0 (min count (height - 2)) in
          let start = max 0 (min (count - list_cap) (selected - list_cap / 2)) in
          (O.Chrome, O.pad ~width_of width "No valid pace data in this period.")
          :: summary_row :: list_rows list_cap start
      | _ ->
          let min_q = List.fold_left Z.min (List.hd valid) valid in
          let max_q = List.fold_left Z.max (List.hd valid) valid in
          let span = Z.sub max_q min_q in
          let step = if Z.equal span Z.zero then Z.one else
            nice_ceiling (ceil_div span (Z.of_int (max 1 (min 4 (plot_h - 1))))) in
          let lower, upper =
            if Z.equal span Z.zero then Z.pred min_q, Z.succ max_q
            else Z.mul (Z.ediv min_q step) step, Z.mul (ceil_div max_q step) step in
          let range = Z.sub upper lower in
          let rec ticks_from t acc =
            if Z.compare t upper > 0 then List.rev acc
            else ticks_from (Z.add t step) (t :: acc) in
          let ticks = ticks_from lower [] in
          let tick_row t =
            Z.to_int (Z.ediv (Z.mul (Z.sub upper t) (Z.of_int (plot_h - 1))) range) in
          let tick_at =
            List.fold_left
              (fun acc t ->
                let r = tick_row t in
                if List.mem_assoc r acc then acc else (r, t) :: acc)
              [] ticks
          in
          let natural_axis = List.fold_left (fun w t -> max w (width_of (format_money book measure t))) 0 ticks in
          let axis_w = min natural_axis (max 1 (min 12 (width / 3))) in
          let plot_w = max 1 (width - axis_w - 3) in
          let sub_w = 2 * plot_w and sub_h = 4 * plot_h in
          let dots = Array.make (sub_w * sub_h) false in
          let set_dot sx sy =
            if sx >= 0 && sy >= 0 && sx < sub_w && sy < sub_h then dots.(sy * sub_w + sx) <- true
          in
          let col_of i = if count <= 1 then 0 else i * (sub_w - 1) / (count - 1) in
          let sub_row_of q =
            Z.to_int (Z.ediv (Z.mul (Z.sub upper q) (Z.of_int (sub_h - 1))) range) in
          let points = Array.mapi (fun i s ->
            Option.map (fun q -> col_of i, sub_row_of q) s.pace_quanta) arr in
          Array.iter (Option.iter (fun (x, y) -> set_dot x y)) points;
          (* Joins are display-only interpolation: adjacent valid days sharing
             one end_exclusive only, never across holes or cycle resets. *)
          let joinable i =
            i + 1 < count && arr.(i).pace_quanta <> None && arr.(i + 1).pace_quanta <> None
            && arr.(i).end_exclusive = arr.(i + 1).end_exclusive
            && day_number arr.(i + 1).day = day_number arr.(i).day + 1
          in
          (match graph_style with
          | Dots -> ()
          | Line ->
              for i = 0 to count - 2 do
                if joinable i then
                  match points.(i), points.(i + 1) with
                  | Some (x0, y0), Some (x1, y1) ->
                      let steps = max (abs (x1 - x0)) (abs (y1 - y0)) in
                      if steps > 1 then
                        for s = 1 to steps - 1 do
                          set_dot (x0 + (x1 - x0) * s / steps) (y0 + (y1 - y0) * s / steps)
                        done
                  | None, _ | _, None -> ()
              done);
          let plot_text = Array.init plot_h (fun _ -> Array.make plot_w " ") in
          for y = 0 to plot_h - 1 do
            let grid = List.mem_assoc y tick_at in
            for x = 0 to plot_w - 1 do
              let mask = ref 0 in
              Array.iter
                (fun (dx, dy, bit) ->
                  if dots.((4 * y + dy) * sub_w + (2 * x + dx)) then mask := !mask lor bit)
                braille_mask;
              plot_text.(y).(x) <-
                (if !mask = 0 then (if grid then "·" else " ") else O.utf8 (Uchar.of_int (0x2800 + !mask)))
            done
          done;
          (* Each sample is drawn once; the selected cell always wins. *)
          let draw_marker i glyph =
            match points.(i) with
            | None -> ()
            | Some (x, y) -> plot_text.(y / 4).(x / 2) <- glyph
          in
          for i = 0 to count - 1 do
            if i <> selected then draw_marker i "●"
          done;
          draw_marker selected "◆";
          let plot_rows =
            List.init plot_h (fun y ->
                let label =
                  match List.assoc_opt y tick_at with
                  | None -> ""
                  | Some t ->
                      let full = format_money book measure t in
                      if width_of full <= axis_w then full else if axis_w >= width_of "…" then "…" else ""
                in
                let row_text = String.concat "" (Array.to_list plot_text.(y)) in
                (O.Plain, O.pad_left ~width_of axis_w label ^ " │ " ^ row_text))
          in
          let start_day = short_day arr.(0).day and end_day = short_day arr.(count - 1).day in
          let rule_line =
            let prefix = String.make axis_w ' ' ^ " ╰─" ^ start_day in
            let room = width - width_of prefix - width_of end_day in
            if room >= 0 then prefix ^ O.rule ~width_of room ^ end_day
            else
              let compact = start_day ^ "–" ^ end_day in
              if width_of compact <= width then O.pad ~width_of width compact
              else O.pad ~width_of width start_day
          in
          let list_cap = max 0 (min count (height - plot_h - 2)) in
          let start = max 0 (min (count - list_cap) (selected - list_cap / 2)) in
          plot_rows @ [ (O.Chrome, O.pad ~width_of width rule_line); summary_row ] @ list_rows list_cap start

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
