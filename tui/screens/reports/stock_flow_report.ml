(* Stock-Flow Report: single-measure tracked balance motion over explicit
   boundaries. A coordinate is reconstructed on one of the supported routes:
   zero-origin, bounded history, or an opening entry (exact from the opening
   entry's own day). An observation is exact only at its confirmation, so it
   never yields a window boundary. Never a fabricated zero; unsupported
   coordinates are listed, not used to refuse the whole report. *)
module B = Bakhlo_sexp.Daily_book
module IncExp = Income_expense_report
module O = Daily_overlays
module A = Daily_draft
module D = Bakhlo_domain

type support =
  | Zero_origin
  | Bounded of string  (** Bounded history start. *)
  | Before_start of string  (** Bounded start lies after the window start. *)
  | Opening of string  (** Opening entry dated here: the balance is exact from then. *)
  | Opening_after of string  (** The window ends before the opening entry. *)
  | Opening_on of string  (** Opening entry is dated on the window's first day. *)
  | Opening_inside of string  (** The window contains the opening entry. *)
  | Observation_undated  (** An exact confirmation with no dated boundary. *)
  | Unsupported of string

type coordinate_activity = {
  locus : string;
  support : support;
  start_balance : Z.t option;
  increases : Z.t;
  decreases : Z.t;
  net_change : Z.t option;  (** End minus start; unknown when a boundary is. *)
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
  net_change : Z.t option;
  (** The tracked motion. Unknown when an opening entry was left out of the
      flows: Start and End still carry it, so the motion is not the sum of the
      in-window flows. *)
  current_tracked : Z.t;  (** Sum of the known current quantities. *)
  coordinates : coordinate_activity list;
  liabilities : coordinate_activity list;
  unsupported : (string * string) list;  (** Locus and its support state. *)
  excluded_openings : (string * string) list;
  (** The id and the day of each opening entry left out of the flows. *)
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

module Q = Bakhlo_application.Current_quantity_query

(* An opening entry fixes the coordinate from its own date: the recorded Effects
   from there on are then exact, exactly like a bounded start. *)
let opening_of ~book ~coordinate =
  List.find_opt
    (fun (opening : Q.opening) -> D.Effect_coordinate.equal opening.coordinate coordinate)
    (Q.openings (B.image book))

let opening_day ~book ~coordinate =
  match opening_of ~book ~coordinate with
  | None -> None
  | Some opening -> (
      match B.find_entry book (D.Identifier.Event.to_string opening.opening_event) with
      | Some entry -> Some entry.day
      | None -> None)

(* An observation is exact from an undated confirmation: no per-day boundary can
   be derived from the stored group, so it never back-fills a window start. *)
let observation_exact ~book ~coordinate =
  match Q.query (B.image book) coordinate with
  | Ok answer -> (
      match Q.premise answer with Q.Current_assertion _ -> true | _ -> false)
  | Error _ -> false

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
    (* Every opening entry sets balances, so the whole entry is never a flow of
       the window that contains it: neither the opening coordinate's posting nor
       its counterpart's. The exclusion is keyed by (Measure, entry): an opening
       of another Measure never removes this Measure's flows. *)
    let opening_entries = Hashtbl.create 8 in
    (match D.Identifier.Measure.of_string measure with
    | Error _ -> ()
    | Ok measure_id ->
        List.iter
          (fun (opening : Q.opening) ->
            if D.Identifier.Measure.equal opening.coordinate.D.Effect_coordinate.measure measure_id
            then
              Hashtbl.replace opening_entries
                (D.Identifier.Event.to_string opening.opening_event)
                ())
          (Q.openings (B.image book)));
    (* The opening entries that the window excludes, named in the note, and the
       rows whose Start and End still carry their effect. *)
    let excluded_openings = ref [] in
    let excluded_loci = Hashtbl.create (List.length pool) in
    (* Every recorded Effect of a pooled Locus with its day, so a boundary can be
       reconstructed from Core's exact current quantity. *)
    let dated = Hashtbl.create (List.length pool) in
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
            Hashtbl.iter
              (fun locus quantity ->
                let previous = Option.value ~default:[] (Hashtbl.find_opt dated locus) in
                Hashtbl.replace dated locus ((entry.day, quantity) :: previous))
              cells;
            if entry.day >= period.start_day && entry.day < period.end_exclusive then
              if Hashtbl.mem opening_entries entry.id then begin
                (* An opening entry sets the balances: it is not a flow, on
                   either side. The rows it touches keep its effect in Start
                   and End, so their Net stays unknown. *)
                if Hashtbl.length cells > 0 then begin
                  excluded_openings := (entry.id, entry.day) :: !excluded_openings;
                  Hashtbl.iter (fun locus _ -> Hashtbl.replace excluded_loci locus ()) cells
                end
              end else
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
    (* The recorded Effects of one Locus dated on or after a boundary day. *)
    let recorded_on_or_after locus day =
      List.fold_left
        (fun total (entry_day, quantity) ->
          if entry_day >= day then Z.add total quantity else total)
        Z.zero (Option.value ~default:[] (Hashtbl.find_opt dated locus))
    in
    Result.map
      (fun () ->
        let classify (locus, _) =
          let positive, negative = Hashtbl.find activities locus in
          let current_balance =
            match O.quantity_value ~book ~measure locus with
            | O.Exact quantity -> Some quantity
            | O.Unsupported -> None
          in
          let base support start_balance end_balance =
            (* The Net cell is the balance motion between the two boundaries: it
               stays unknown when a boundary is unknown, and when an excluded
               opening entry still sits in Start and End. *)
            let net_change =
              match (start_balance, end_balance) with
              | Some start, Some stop when not (Hashtbl.mem excluded_loci locus) ->
                  Some (Z.sub stop start)
              | _ -> None
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
              match (zero, bounded) with
              | true, Some _ ->
                  base (Unsupported "zero-origin and bounded history overlap") None None
              | true, None ->
                  (* Zero-origin: no Effect can precede the first calendar day, so a
                     window that starts before all history starts at exactly zero. *)
                  let start_result =
                    match start_day with
                    | None -> Ok Z.zero
                    | Some day -> balance_at ~book ~measure ~coordinate ~day:(Some day)
                  in
                  let end_result = balance_at ~book ~measure ~coordinate ~day:end_day in
                  base Zero_origin
                    (match start_result with Ok value -> Some value | Error _ -> None)
                    (match end_result with Ok value -> Some value | Error _ -> None)
              | false, None -> (
                  (* An opening entry or an observation makes the coordinate exact
                     without zero-origin/bounded history. *)
                  match opening_day ~book ~coordinate with
                  | Some opening ->
                      (* The balance at a boundary day d is Core's exact current
                         quantity minus the recorded Effects dated on or after d.
                         It is exact only from the opening entry's own day, so a
                         window starting on that day has an unknown start. *)
                      let boundary day =
                        match current_balance with
                        | None -> None
                        | Some quantity ->
                            if day <= opening then None
                            else Some (Z.sub quantity (recorded_on_or_after locus day))
                      in
                      (* A window that contains the opening entry has no flow for
                         it: the opening posting sets the balance. *)
                      let contains_opening =
                        period.start_day <= opening && opening < period.end_exclusive
                      in
                      let support =
                        if period.start_day > opening then Opening opening
                        else if period.start_day = opening then Opening_on opening
                        else if contains_opening then Opening_inside opening
                        else Opening_after opening
                      in
                      base support (boundary period.start_day) (boundary period.end_exclusive)
                  | None ->
                      if observation_exact ~book ~coordinate then
                        base Observation_undated None None
                      else
                        base
                          (Unsupported
                             "no zero-origin, bounded, opening or observation support")
                          None None)
              | false, Some first_day ->
                  let start_result =
                    match start_day with
                    | None -> Error "history-precedes-bounded-start"
                    | Some day -> balance_at ~book ~measure ~coordinate ~day:(Some day)
                  in
                  let end_result = balance_at ~book ~measure ~coordinate ~day:end_day in
                  let support =
                    match start_result with
                    | Error "history-precedes-bounded-start" -> Before_start first_day
                    | Error code -> Unsupported (support_reason code)
                    | Ok _ -> Bounded first_day
                  in
                  (match support with
                  | Unsupported _ -> base support None None
                  | Zero_origin | Bounded _ | Before_start _ | Opening _ | Opening_after _
                  | Opening_on _ | Opening_inside _ | Observation_undated ->
                      base support
                        (match start_result with Ok value -> Some value | Error _ -> None)
                        (match end_result with Ok value -> Some value | Error _ -> None)))
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
              | Zero_origin | Bounded _ | Before_start _ | Opening _ | Opening_after _
              | Opening_on _ | Opening_inside _ | Observation_undated -> (c.locus, ""))
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
          net_change =
            (* The motion is unknown when an opening entry was left out of the
               flows: Start and End still carry it. *)
            (if !excluded_openings = [] then
               Some (Z.add increases_across_events decreases_across_events)
             else None);
          current_tracked = sum_known (fun c -> c.current_balance);
          coordinates = supported;
          liabilities;
          unsupported;
          excluded_openings = List.sort compare !excluded_openings;
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
  | Before_start start_day ->
      Some (Printf.sprintf "start unknown; bounded history starts %s" start_day)
  | Opening day -> Some (Printf.sprintf "start known from the opening entry dated %s" day)
  | Opening_after day ->
      Some
        (Printf.sprintf
           "start and end unknown; the window ends before the opening entry dated %s" day)
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
        "start unknown; the confirmation is exact, but the balance before it is not derivable, \
         so the window boundaries stay unknown"
  | Zero_origin | Bounded _ | Unsupported _ -> None

let table_columns pad_w =
  let col_name = max 14 (min 26 (pad_w * 25 / 100)) in
  let col_num = max 9 (min 12 ((pad_w - col_name - 8) / 5)) in
  (col_name, col_num)

let cell ~width_of col text = O.pad_left ~width_of col text

let row_text ~width_of ~col_name ~col_num ~book ~measure (c : coordinate_activity) =
  let amount = function Some value -> O.format_money book measure value | None -> "—" in
  let net =
    match c.net_change with Some value -> signed_amount ~book measure value | None -> "—"
  in
  "  " ^ O.pad ~width_of col_name (coordinate_label ~book ~measure c)
  ^ " " ^ cell ~width_of col_num (amount c.start_balance)
  ^ " " ^ cell ~width_of col_num ("+" ^ O.format_money book measure c.increases)
  ^ " " ^ cell ~width_of col_num (O.format_money book measure c.decreases)
  ^ " " ^ cell ~width_of col_num (amount c.end_balance)
  ^ " " ^ cell ~width_of col_num net

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
  let excluded =
    List.map
      (fun (id, day) ->
        Printf.sprintf
          "  The opening entry %s dated %s is left out of the in-window flows on both sides."
          id day)
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
  @ excluded
  @ excluded_note
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
          (match report.net_change with
          | Some value -> signed_val ~book m value
          | None -> "—") );
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
    ^ " "
    ^ cell ~width_of col_num
        (match report.net_change with
        | Some value -> signed_amount ~book m value
        | None -> "—")
  in
  let liabilities =
    match report.liabilities with
    | [] -> []
    | rows_of ->
        let known_start =
          List.filter_map (fun (c : coordinate_activity) -> c.start_balance) rows_of
        in
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
          if known_end <> [] then "  Liabilities (start / +In / -Out / end)"
          else "  Liabilities (end unknown; current quantity only)" )
        :: List.map
             (fun (c : coordinate_activity) ->
               let amount = function
                 | Some value -> O.format_money book m value
                 | None -> "—"
               in
               let now =
                 match (c.end_balance, c.current_balance) with
                 | Some _, _ -> ""
                 | None, Some value -> "  now " ^ O.format_money book m value
                 | None, None -> ""
               in
               let support =
                 match support_note c with Some note -> "  (" ^ note ^ ")" | None -> ""
               in
               ( O.Plain,
                 Printf.sprintf "    %-22s %10s %10s %10s %10s%s%s"
                   (coordinate_label ~book ~measure:m c)
                   (amount c.start_balance)
                   ("+" ^ O.format_money book m c.increases)
                   (O.format_money book m c.decreases)
                   (amount c.end_balance) now support ))
             rows_of
        @ [
            ( O.Plain,
              Printf.sprintf "    %-22s %10s %10s %10s %10s" total_label
                (if known_start = [] then "—"
                 else signed_amount ~book m (List.fold_left Z.add Z.zero known_start))
                ("+" ^ O.format_money book m
                   (List.fold_left (fun total c -> Z.add total c.increases) Z.zero rows_of))
                (O.format_money book m
                   (List.fold_left (fun total c -> Z.add total c.decreases) Z.zero rows_of))
                (if known_end = [] && known_now = [] then "—"
                 else signed_amount ~book m total) );
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
  add
    (Printf.sprintf "  Net change in tracked balance:    %16s"
       (match report.net_change with
       | Some value -> signed_val ~book m value
       | None -> "—"));
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
      let net =
        match c.net_change with Some value -> signed_val ~book m value | None -> "—"
      in
      add
        (Printf.sprintf "  %-*s %*s %*s %*s %*s %*s" col_name
           (coordinate_label ~book ~measure:m c)
           col_num (amount c.start_balance) col_num
           ("+" ^ O.format_money book m c.increases)
           col_num (O.format_money book m c.decreases) col_num (amount c.end_balance) col_num
           net))
    report.coordinates;
  List.iter
    (fun (id, day) ->
      add
        (Printf.sprintf
           "  The opening entry %s dated %s is left out of the in-window flows on both sides."
           id day))
    report.excluded_openings;
  if report.excluded_openings <> [] then
    add "  Start and End include those entries; +In and -Out do not.";
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
