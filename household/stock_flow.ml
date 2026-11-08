(* Stock and flow: why the watched balances changed between two days.

   For each chosen (Locus, Measure) the window gives a start balance, what came
   in and went out, and the end balance:

     bank  start 300000  in +10000  out -96300  net -86300  end 213700

   A balance is only known where the book can prove it. Bakhlo reconstructs it on
   one of three routes: zero-origin (history starts at nothing), bounded history
   (a known count from a day on), or an opening entry (exact from its own day).
   Before that, the start is unknown, never zero, and the row stays in the
   report. A Locus with no route is listed with the reason, never used to refuse
   the whole report. An opening entry sets balances rather than moving money, so
   it is left out of the flows, and a window that contains it has an unknown net.
   Pinned in test/reports ([STOCK-FLOW]). *)

type missing_support = Empty_cell | No_support | History_refused of string

let missing_code = function
  | Empty_cell -> "empty-cell"
  | No_support -> "no-support"
  | History_refused code -> code

let missing_message = function
  | Empty_cell -> "invalid coordinate token"
  | No_support -> "no zero-origin, bounded, opening or observation support"
  | History_refused "history-support-missing" -> "no zero-origin or bounded history"
  | History_refused "history-support-conflict" -> "zero-origin and bounded history overlap"
  | History_refused "history-bounded-anchor-missing" ->
      "bounded history needs an exact current quantity"
  | History_refused other -> other

type support =
  | Zero_origin
  | Bounded of string  (** Bounded history start. *)
  | Before_start of string  (** Bounded start lies after the window start. *)
  | Opening of string  (** Opening entry dated here: the balance is exact from then. *)
  | Opening_after of string  (** The window ends before the opening entry. *)
  | Opening_on of string  (** Opening entry is dated on the window's first day. *)
  | Opening_inside of string  (** The window contains the opening entry. *)
  | Observation_undated  (** An exact confirmation with no dated boundary. *)
  | Unsupported of missing_support

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
  start_day : string;
  end_exclusive : string;
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
  unsupported : (string * missing_support) list;
  excluded_openings : (string * string) list;
      (** The id and the day of each opening entry left out of the flows. *)
}

let code_of_refusal code =
  match String.index_opt code ':' with Some index -> String.sub code 0 index | None -> code

let day_before day =
  match Day.shift_days day (-1) with Ok previous -> Some previous | Error _ -> None

let coordinate_of ~measure locus : (Book.coordinate, missing_support) result =
  if locus = "" || measure = "" then Error Empty_cell else Ok { locus; measure }

(* Start or end balance for one coordinate through the shared support rule. *)
let balance_at ~book ~measure ~coordinate ~day =
  match day with
  | None -> Error "invalid boundary"
  | Some day -> (
      match Book.pool_at_end_of_day book ~measure ~pool:[ coordinate ] ~day with
      | Ok value -> Ok value
      | Error code -> Error (code_of_refusal code))

(* An opening entry fixes the coordinate from its own date: the recorded Effects
   from there on are then exact, exactly like a bounded start. *)
let opening_day ~book ~(coordinate : Book.coordinate) =
  match List.assoc_opt (coordinate.locus, coordinate.measure) (Book.openings book) with
  | None -> None
  | Some tx -> Option.map (fun (entry : Book.entry) -> entry.day) (Book.find_entry book tx)

(* An observation is exact from an undated confirmation: no per-day boundary can
   be derived from the stored group, so it never back-fills a window start. *)
let observation_exact ~book ~(coordinate : Book.coordinate) =
  match Book.quantity book ~locus:coordinate.locus ~measure:coordinate.measure with
  | Some { support = Book.T.Counted _; _ } -> true
  | _ -> false

type refusal = Bad_day | Empty_window | No_selection | Mixed_measures | Duplicate_selection

let code = function
  | Bad_day -> "bad-day"
  | Empty_window -> "empty-window"
  | No_selection -> "no-selection"
  | Mixed_measures -> "mixed-measures"
  | Duplicate_selection -> "duplicate-selection"

let message = function
  | Bad_day -> "Stock–Flow endpoints must be real YYYY-MM-DD calendar dates."
  | Empty_window -> "Stock–Flow start must be earlier than end."
  | No_selection -> "Stock–Flow requires a nonempty configured coordinate selection."
  | Mixed_measures -> "Stock–Flow selected balances span multiple measures."
  | Duplicate_selection -> "Stock–Flow selected coordinates contain duplicates."

let compute book ~measure ~tracked_coords ~liability_coords ~start ~stop =
  if (not (Day.is_valid start)) || not (Day.is_valid stop) then Error Bad_day
  else if String.compare start stop >= 0 then Error Empty_window
  else if tracked_coords = [] then Error No_selection
  else if List.exists (fun (_, m) -> m <> measure) tracked_coords then Error Mixed_measures
  else if List.length (List.sort_uniq compare tracked_coords) <> List.length tracked_coords then
    Error Duplicate_selection
  else
    let pool =
      List.fold_left
        (fun acc ((_, coordinate_measure) as item) ->
          if coordinate_measure <> measure || List.mem item acc then acc else acc @ [ item ])
        []
        (tracked_coords @ liability_coords)
    in
    let start_day = day_before start in
    let end_day = day_before stop in
    let activities = Hashtbl.create (List.length pool) in
    List.iter (fun (locus, _) -> Hashtbl.add activities locus (Z.zero, Z.zero)) pool;
    (* Every opening entry sets balances, so the whole entry is never a flow of
       the window that contains it: neither the opening coordinate's posting nor
       its counterpart's. The exclusion is keyed by (Measure, entry): an opening
       of another Measure never removes this Measure's flows. *)
    let opening_entries = Hashtbl.create 8 in
    List.iter
      (fun ((_, m), tx) -> if m = measure then Hashtbl.replace opening_entries tx ())
      (Book.openings book);
    (* The opening entries that the window excludes, named in the note, and the
       rows whose Start and End still carry their effect. *)
    let excluded_openings = ref [] in
    let excluded_loci = Hashtbl.create (List.length pool) in
    (* Every recorded Effect of a pooled Locus with its day, so a boundary can be
       reconstructed from Core's exact current quantity. *)
    let dated = Hashtbl.create (List.length pool) in
    let cells = Hashtbl.create (List.length pool) in
    let rec scan = function
      | [] -> ()
      | (entry : Book.entry) :: rest ->
          Hashtbl.clear cells;
          List.iter
            (fun (posting : Book.posting) ->
              let locus = posting.locus in
              if posting.measure = measure && Hashtbl.mem activities locus then
                let prior = Option.value ~default:Z.zero (Hashtbl.find_opt cells locus) in
                Hashtbl.replace cells locus (Z.add prior posting.amount))
            entry.effects;
          begin
            Hashtbl.iter
              (fun locus quantity ->
                let previous = Option.value ~default:[] (Hashtbl.find_opt dated locus) in
                Hashtbl.replace dated locus ((entry.day, quantity) :: previous))
              cells;
            if entry.day >= start && entry.day < stop then
              if Hashtbl.mem opening_entries entry.id then
                (* An opening entry sets the balances: it is not a flow, on
                   either side. The rows it touches keep its effect in Start
                   and End, so their Net stays unknown. *)
                begin if Hashtbl.length cells > 0 then begin
                  excluded_openings := (entry.id, entry.day) :: !excluded_openings;
                  Hashtbl.iter (fun locus _ -> Hashtbl.replace excluded_loci locus ()) cells
                end
                end
              else
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
        Z.zero
        (Option.value ~default:[] (Hashtbl.find_opt dated locus))
    in
    scan (Book.entries book);
    Ok
      (let classify (locus, _) =
         let positive, negative = Hashtbl.find activities locus in
         let current_balance =
           Option.map (fun (q : Book.T.quantity) -> q.amount) (Book.quantity book ~locus ~measure)
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
         let zero = Book.has_zero_origin book ~locus ~measure in
         let bounded = Book.bounded_history_start book ~locus ~measure in
         match coordinate_of ~measure locus with
         | Error why -> base (Unsupported why) None None
         | Ok coordinate -> (
             match (zero, bounded) with
             | true, Some _ ->
                 (* Book refuses this pair on read (support-overlap), so it is kept
                    only as a named code, never guessed. *)
                 base (Unsupported (History_refused "history-support-conflict")) None None
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
                     let contains_opening = start <= opening && opening < stop in
                     let support =
                       if start > opening then Opening opening
                       else if start = opening then Opening_on opening
                       else if contains_opening then Opening_inside opening
                       else Opening_after opening
                     in
                     base support (boundary start) (boundary stop)
                 | None ->
                     if observation_exact ~book ~coordinate then base Observation_undated None None
                     else base (Unsupported No_support) None None)
             | false, Some first_day -> (
                 let start_result =
                   match start_day with
                   | None -> Error "history-precedes-bounded-start"
                   | Some day -> balance_at ~book ~measure ~coordinate ~day:(Some day)
                 in
                 let end_result = balance_at ~book ~measure ~coordinate ~day:end_day in
                 let support =
                   match start_result with
                   | Error "history-precedes-bounded-start" -> Before_start first_day
                   | Error code -> Unsupported (History_refused code)
                   | Ok _ -> Bounded first_day
                 in
                 match support with
                 | Unsupported _ -> base support None None
                 | Zero_origin | Bounded _ | Before_start _ | Opening _ | Opening_after _
                 | Opening_on _ | Opening_inside _ | Observation_undated ->
                     base support
                       (match start_result with Ok value -> Some value | Error _ -> None)
                       (match end_result with Ok value -> Some value | Error _ -> None)))
       in
       let coordinates = List.map classify pool in
       let supported =
         List.filter
           (fun (c : coordinate_activity) ->
             match c.support with Unsupported _ -> false | _ -> true)
           coordinates
       in
       let unsupported =
         List.filter_map
           (fun (c : coordinate_activity) ->
             match c.support with Unsupported reason -> Some (c.locus, reason) | _ -> None)
           coordinates
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
         start_day = start;
         end_exclusive = stop;
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
