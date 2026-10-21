(* Stock-Flow Report: single-measure tracked balance motion over explicit
   boundaries. Support follows the one history rule Daily Pace uses
   (Daily_book.pool_at_end_of_day): zero-origin or bounded history, never a
   fabricated zero. Unsupported coordinates are listed, not used to refuse the
   whole report. *)
module B = Bakhlo_sexp.Daily_book
module IncExp = Income_expense_report
module O = Daily_overlays
module A = Daily_draft
module D = Bakhlo_domain

type support =
  | Zero_origin
  | Bounded of string  (** Bounded history start. *)
  | Before_start of string  (** Bounded start lies after the window start. *)
  | Unsupported of string

type coordinate_activity = {
  locus : string;
  support : support;
  start_balance : Z.t option;
  increases : Z.t;
  decreases : Z.t;
  net_change : Z.t;
  end_balance : Z.t option;
  current_balance : Z.t option;
}

type snapshot = {
  period : IncExp.period;
  measure : string;
  reconstructed_start : Z.t;  (** Sum of the known starts only. *)
  reconstructed_end : Z.t;  (** Sum of the known ends only. *)
  unknown_starts : int;
  increases_across_events : Z.t;
  decreases_across_events : Z.t;
  net_change : Z.t;
  current_tracked : Z.t;  (** Sum of the known current quantities. *)
  coordinates : coordinate_activity list;
  liabilities : coordinate_activity list;
  unsupported : (string * string) list;  (** Locus and its support state. *)
}

type report = snapshot
type t = { preset : IncExp.period_preset; period_offset : int }

(* The configured cycle is the default Stock–Flow window. *)
let initial () = { preset = IncExp.Cycle; period_offset = 0 }

let code_of_refusal code =
  match String.index_opt code ':' with Some index -> String.sub code 0 index | None -> code

let support_reason = function
  | "history-support-missing" -> "no zero-origin or bounded history"
  | "history-support-conflict" -> "zero-origin and bounded history overlap"
  | "history-precedes-bounded-start" -> "window starts before the bounded history start"
  | "history-bounded-anchor-missing" -> "bounded history needs an exact current quantity"
  | other -> other

let day_before day =
  match Daily_calendar.shift_days day (-1) with Ok previous -> Some previous | Error _ -> None

let coordinate_of ~measure locus : (D.Effect_coordinate.t, string) result =
  match (D.Identifier.Locus.of_string locus, D.Identifier.Measure.of_string measure) with
  | Ok locus, Ok measure -> Ok { D.Effect_coordinate.locus; measure }
  | _ -> Error "invalid coordinate token"

(* Start or end balance for one coordinate through the shared support rule. *)
let balance_at ~book ~measure ~coordinate ~day =
  match day with
  | None -> Error "invalid boundary"
  | Some day -> (
      match B.pool_at_end_of_day book ~measure ~pool:[ coordinate ] ~day with
      | Ok value -> Ok value
      | Error code -> Error (code_of_refusal code))

let compute_report ~book ~measure ~tracked_coords ~liability_coords ~(period : IncExp.period) =
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
    let pool =
      List.fold_left
        (fun acc ((_, coordinate_measure) as item) ->
          if coordinate_measure <> measure || List.mem item acc then acc else acc @ [ item ])
        [] (tracked_coords @ liability_coords)
    in
    let start_day = day_before period.start_day in
    let end_day = day_before period.end_exclusive in
    let activities = Hashtbl.create (List.length pool) in
    List.iter (fun (locus, _) -> Hashtbl.add activities locus (Z.zero, Z.zero)) pool;
    let cells = Hashtbl.create (List.length pool) in
    let rec scan = function
      | [] -> Ok ()
      | (entry : B.entry) :: rest ->
          Hashtbl.clear cells;
          List.iter
            (fun posting ->
              let locus = A.lstr (D.Effect.locus posting) in
              if A.mstr (D.Effect.measure posting) = measure && Hashtbl.mem activities locus then
                let prior = Option.value ~default:Z.zero (Hashtbl.find_opt cells locus) in
                Hashtbl.replace cells locus (Z.add prior (A.quanta posting)))
            entry.effects;
          if Hashtbl.length cells > 0 && not (A.is_valid_canonical_date entry.day) then
            Error ("Invalid occurrence date: " ^ entry.id)
          else begin
            if entry.day >= period.start_day && entry.day < period.end_exclusive then
              Hashtbl.iter
                (fun locus quantity ->
                  let positive, negative = Hashtbl.find activities locus in
                  let positive =
                    if Z.sign quantity > 0 then Z.add positive quantity else positive
                  in
                  let negative =
                    if Z.sign quantity < 0 then Z.add negative quantity else negative
                  in
                  Hashtbl.replace activities locus (positive, negative))
                cells;
            scan rest
          end
    in
    Result.map
      (fun () ->
        let classify (locus, _) =
          let positive, negative = Hashtbl.find activities locus in
          let current_balance =
            match O.quantity_value ~book ~measure locus with
            | O.Exact quantity -> Some quantity
            | O.Known_present | O.Unsupported -> None
          in
          let base support start_balance end_balance =
            let net_change =
              match (start_balance, end_balance) with
              | Some start, Some stop -> Z.sub stop start
              | _ -> Z.add positive negative
            in
            {
              locus;
              support;
              start_balance;
              increases = positive;
              decreases = negative;
              net_change;
              end_balance;
              current_balance;
            }
          in
          let zero = B.has_zero_origin book ~locus ~measure in
          let bounded = B.bounded_history_start book ~locus ~measure in
          match coordinate_of ~measure locus with
          | Error why -> base (Unsupported why) None None
          | Ok coordinate -> (
              let start_result = balance_at ~book ~measure ~coordinate ~day:start_day in
              let end_result = balance_at ~book ~measure ~coordinate ~day:end_day in
              match (zero, bounded) with
              | true, Some _ ->
                  base (Unsupported "zero-origin and bounded history overlap") None None
              | false, None -> base (Unsupported "no zero-origin or bounded history") None None
              | _ -> (
                  match start_result with
                  | Error code
                    when code <> "history-precedes-bounded-start" && code <> "invalid boundary" ->
                      base (Unsupported (support_reason code)) None None
                  | _ ->
                      let support =
                        match (zero, bounded, start_result) with
                        | true, None, _ -> Zero_origin
                        | false, Some start_day, Error "history-precedes-bounded-start" ->
                            Before_start start_day
                        | false, Some start_day, _ -> Bounded start_day
                        | _ -> Unsupported "support unknown"
                      in
                      let start_balance =
                        match start_result with Ok value -> Some value | Error _ -> None
                      in
                      let end_balance =
                        match end_result with Ok value -> Some value | Error _ -> None
                      in
                      base support start_balance end_balance))
        in
        let coordinates = List.map classify pool in
        let supported, unsupported =
          List.partition
            (fun (c : coordinate_activity) ->
              match c.support with Unsupported _ -> false | _ -> true)
            coordinates
        in
        let unsupported =
          List.map
            (fun (c : coordinate_activity) ->
              match c.support with
              | Unsupported reason -> (c.locus, reason)
              | Zero_origin | Bounded _ | Before_start _ -> (c.locus, ""))
            unsupported
        in
        let sum_known pick =
          List.fold_left
            (fun total (c : coordinate_activity) ->
              match pick c with Some value -> Z.add total value | None -> total)
            Z.zero supported
        in
        let increases_across_events =
          List.fold_left (fun total c -> Z.add total c.increases) Z.zero supported
        in
        let decreases_across_events =
          List.fold_left (fun total c -> Z.add total c.decreases) Z.zero supported
        in
        let unknown_starts =
          List.fold_left
            (fun total (c : coordinate_activity) ->
              match c.start_balance with Some _ -> total | None -> total + 1)
            0 supported
        in
        let liabilities =
          List.filter
            (fun (c : coordinate_activity) -> List.mem_assoc c.locus liability_coords)
            coordinates
        in
        {
          period;
          measure;
          reconstructed_start = sum_known (fun c -> c.start_balance);
          reconstructed_end = sum_known (fun c -> c.end_balance);
          unknown_starts;
          increases_across_events;
          decreases_across_events;
          net_change = Z.add increases_across_events decreases_across_events;
          current_tracked = sum_known (fun c -> c.current_balance);
          coordinates = supported;
          liabilities;
          unsupported;
        })
      (scan (B.entries book))

let signed_amount ~book m z = (if Z.sign z > 0 then "+" else "") ^ O.format_money book m z

let signed_val ~book m z =
  (if Z.sign z > 0 then "+" else "") ^ O.format_money book m z ^ " " ^ m

let unsigned_val ~book m z = O.format_money book m z ^ " " ^ m

let coordinate_label ~book ~measure (c : coordinate_activity) =
  let label = B.label book c.locus in
  if label <> "" && label <> c.locus then label ^ "/" ^ measure else c.locus ^ "/" ^ measure

let support_note (c : coordinate_activity) =
  match c.support with
  | Before_start start_day -> Some (Printf.sprintf "start unknown; bounded history starts %s" start_day)
  | Zero_origin | Bounded _ | Unsupported _ -> None

let table_columns pad_w =
  let col_name = max 14 (min 26 (pad_w * 25 / 100)) in
  let col_num = max 9 (min 12 ((pad_w - col_name - 8) / 5)) in
  (col_name, col_num)

let cell ~width_of col text = O.pad_left ~width_of col text

let row_text ~width_of ~col_name ~col_num ~book ~measure (c : coordinate_activity) =
  let amount = function Some value -> O.format_money book measure value | None -> "—" in
  "  " ^ O.pad ~width_of col_name (coordinate_label ~book ~measure c)
  ^ " " ^ cell ~width_of col_num (amount c.start_balance)
  ^ " " ^ cell ~width_of col_num ("+" ^ O.format_money book measure c.increases)
  ^ " " ^ cell ~width_of col_num (O.format_money book measure c.decreases)
  ^ " " ^ cell ~width_of col_num (amount c.end_balance)
  ^ " " ^ cell ~width_of col_num (signed_amount ~book measure c.net_change)

let header_text ~width_of ~col_name ~col_num =
  "  " ^ O.pad ~width_of col_name "Coordinate"
  ^ " " ^ cell ~width_of col_num "Start"
  ^ " " ^ cell ~width_of col_num "+In"
  ^ " " ^ cell ~width_of col_num "-Out"
  ^ " " ^ cell ~width_of col_num "End"
  ^ " " ^ cell ~width_of col_num "Net"

let footnote_lines ~book ~measure report =
  let notes =
    List.filter_map
      (fun (c : coordinate_activity) ->
        Option.map
          (fun note -> Printf.sprintf "  %s: %s" (coordinate_label ~book ~measure c) note)
          (support_note c))
      report.coordinates
  in
  let unsupported =
    List.map
      (fun (locus, reason) -> Printf.sprintf "  %s/%s: %s" locus report.measure reason)
      report.unsupported
  in
  (if report.unknown_starts > 0 then
     [
       Printf.sprintf
         "  Start/end totals exclude %d coordinate(s) whose start is unknown." report.unknown_starts;
     ]
   else [])
  @ notes
  @
  if unsupported = [] then []
  else ("  Unsupported coordinates (not reconstructed):" :: unsupported)

let render_summary_lines ~width ~width_of ~book ~(report : report) =
  let pad_w = max 0 (width - 4) in
  let m = report.measure in
  let col_name, col_num = table_columns pad_w in
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
          (signed_val ~book m report.net_change) );
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
      (fun (c : coordinate_activity) ->
        (O.Plain, row_text ~width_of ~col_name ~col_num ~book ~measure:m c))
      report.coordinates
  in
  let total_line =
    "  " ^ O.pad ~width_of col_name ("Total (" ^ m ^ ")")
    ^ " " ^ cell ~width_of col_num (O.format_money book m report.reconstructed_start)
    ^ " " ^ cell ~width_of col_num ("+" ^ O.format_money book m report.increases_across_events)
    ^ " " ^ cell ~width_of col_num (O.format_money book m report.decreases_across_events)
    ^ " " ^ cell ~width_of col_num (O.format_money book m report.reconstructed_end)
    ^ " " ^ cell ~width_of col_num (signed_amount ~book m report.net_change)
  in
  let liabilities =
    match report.liabilities with
    | [] -> []
    | rows_of ->
        let known_end = List.filter_map (fun (c : coordinate_activity) -> c.end_balance) rows_of in
        let known_now =
          List.filter_map
            (fun (c : coordinate_activity) ->
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
          if known_end <> [] then "  Liabilities (remaining at window end)"
          else "  Liabilities (end unknown; current quantity only)" )
        :: List.map
             (fun (c : coordinate_activity) ->
               let end_text =
                 match (c.end_balance, c.current_balance) with
                 | Some value, _ -> O.format_money book m value ^ " " ^ m
                 | None, Some value -> O.format_money book m value ^ " " ^ m ^ " (now)"
                 | None, None -> "—"
               in
               let support =
                 match support_note c with Some note -> "  (" ^ note ^ ")" | None -> ""
               in
               ( O.Plain,
                 Printf.sprintf "    %-28s %18s%s"
                   (coordinate_label ~book ~measure:m c)
                   end_text support ))
             rows_of
        @ [
            ( O.Plain,
              Printf.sprintf "    %-28s %18s" total_label
                (if known_end = [] && known_now = [] then "—" else signed_amount ~book m total ^ " " ^ m) );
          ]
  in
  header @ [ (O.Chrome, header_text ~width_of ~col_name ~col_num); rule ] @ rows
  @ [ rule; (O.Heading, total_line); (O.Plain, "") ]
  @ (if liabilities = [] then [] else liabilities @ [ (O.Plain, "") ])
  @ List.map (fun text -> (O.Chrome, text)) (footnote_lines ~book ~measure:m report)

let print_summary ~book ~(report : report) =
  let lines = ref [] in
  let add s = lines := s :: !lines in
  let m = report.measure in
  let col_name, col_num = (22, 12) in
  add (Printf.sprintf "Stock–Flow Report - %s (%s)" report.period.label m);
  add
    (Printf.sprintf "Window: %s through %s (exclusive)" report.period.start_day
       report.period.end_exclusive);
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
  add (Printf.sprintf "  Net change in tracked balance:    %16s" (signed_val ~book m report.net_change));
  add
    (Printf.sprintf "  Current tracked balance now:      %16s"
       (unsigned_val ~book m report.current_tracked));
  add "--------------------------------------------------------------------------------";
  add
    ("  " ^ Printf.sprintf "%-*s %*s %*s %*s %*s %*s" col_name "Coordinate" col_num "Start"
       col_num "+In" col_num "-Out" col_num "End" col_num "Net");
  add "--------------------------------------------------------------------------------";
  List.iter
    (fun (c : coordinate_activity) ->
      let amount = function Some value -> O.format_money book m value | None -> "—" in
      add
        (Printf.sprintf "  %-*s %*s %*s %*s %*s %*s" col_name
           (coordinate_label ~book ~measure:m c)
           col_num (amount c.start_balance) col_num
           ("+" ^ O.format_money book m c.increases)
           col_num (O.format_money book m c.decreases) col_num (amount c.end_balance) col_num
           (signed_val ~book m c.net_change)))
    report.coordinates;
  List.iter
    (fun (c : coordinate_activity) ->
      match support_note c with
      | Some note ->
          add (Printf.sprintf "  %s: %s" (coordinate_label ~book ~measure:m c) note)
      | None -> ())
    report.coordinates;
  List.iter
    (fun (locus, reason) -> add (Printf.sprintf "  %s/%s: %s" locus m reason))
    report.unsupported;
  add "================================================================================";
  List.rev !lines
