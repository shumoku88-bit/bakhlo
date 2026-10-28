(* Trend / Locus report: exact recorded Effect flow per Locus x Measure over
   explicitly configured cycle history. Read-only; no balance, support,
   role or household-coverage inference. *)
module B = Bakhlo_household.Book
module D = Bakhlo_domain
module IncExp = Income_expense_report
module Roles = Locus_roles

type grain = Cycle | Month | Day
type scope = All_history | Current_cycle | Current_month | Last_30_days
type coordinate = { locus : string; measure : string }

type point = {
  start_day : string;
  end_exclusive : string;
  observed_days : int;
  complete : bool;
  total : Z.t;
  value : Z.t;
}

type series = { coordinate : coordinate; label : string; points : point array }

type snapshot = {
  measure : string;
  observed_at : string;
  source : string;
  scope_start : string;
  scope_end_exclusive : string;
  grain : grain;
  scope : scope;
  series : series array;
}

let ( let* ) = Result.bind
let grain_label = function Cycle -> "Cycle" | Month -> "Month" | Day -> "Day"

let scope_label = function
  | All_history -> "All history"
  | Current_cycle -> "Current cycle"
  | Current_month -> "Current month"
  | Last_30_days -> "Last 30 days"

let month_starts = [| 0; 31; 59; 90; 120; 151; 181; 212; 243; 273; 304; 334 |]

(* Proleptic Gregorian ordinal, used only for exact window day counts. *)
let day_ordinal day =
  match Day.parts day with
  | Error _ -> None
  | Ok (year, month, day_of_month) ->
      let prior = year - 1 in
      let leap = year mod 400 = 0 || (year mod 4 = 0 && year mod 100 <> 0) in
      Some
        ((365 * prior) + (prior / 4) - (prior / 100) + (prior / 400)
        + month_starts.(month - 1)
        + day_of_month
        + if leap && month > 2 then 1 else 0)

let days_between start_day end_exclusive =
  match (day_ordinal start_day, day_ordinal end_exclusive) with
  | Some start, Some stop when stop > start -> stop - start
  | _ -> invalid_arg "Trend_locus_report: point window is not a real date range"

let canonical_date day =
  match Day.normalize day with Ok canonical -> canonical = day | Error _ -> false

type bounds = {
  preset : string;
  history_start : string;
  cycle_start : string;
  windows : (string * string * string) list;
}

(* One explicit preset must own the observation day; its first boundary is the
   only history start, and every scope is clipped to it. *)
let configured_bounds ~observed_at ~text =
  let* text =
    match text with
    | None -> Error "Period not configured (boundary-presets.tsv missing)."
    | Some text -> Ok text
  in
  let* windows = IncExp.parse_boundary_presets text in
  let containing =
    List.filter
      (fun (_, start_day, end_exclusive) -> start_day <= observed_at && observed_at < end_exclusive)
      windows
  in
  let* preset, cycle_start =
    match List.sort_uniq String.compare (List.map (fun (name, _, _) -> name) containing) with
    | [ preset ] -> (
        match List.find_opt (fun (name, _, _) -> name = preset) containing with
        | Some (_, start_day, _) -> Ok (preset, start_day)
        | None -> Error "No explicit boundary preset contains the observation day.")
    | [] -> Error "No explicit boundary preset contains the observation day."
    | _ -> Error "Multiple boundary presets contain the observation day; selection is ambiguous."
  in
  let windows = List.filter (fun (name, _, _) -> name = preset) windows in
  let history_start =
    List.fold_left (fun first (_, start_day, _) -> min first start_day) cycle_start windows
  in
  Ok { preset; history_start; cycle_start; windows }

let catalog ~book ~measure =
  let historical =
    List.concat_map
      (fun (entry : B.entry) ->
        List.filter_map
          (fun (posting : D.Effect.t) ->
            if D.Identifier.Measure.to_string (D.Effect.measure posting) = measure then
              Some (D.Identifier.Locus.to_string (D.Effect.locus posting))
            else None)
          entry.effects)
      (B.entries book)
  in
  let admitted = Option.value ~default:[] (B.approved_loci book) in
  List.sort_uniq String.compare (admitted @ historical)
  |> List.map (fun locus -> { locus; measure })

let history_start ~observed_at ~boundary_presets_text =
  Result.map
    (fun (bounds : bounds) -> bounds.history_start)
    (configured_bounds ~observed_at ~text:boundary_presets_text)

(* The default series: the three Expense-role Loci with the most recorded
   entries in the shown history. Ties go to the larger recorded movement first,
   then to the token, so the choice is deterministic and derived from data. *)
let initial_series ~book ~measure ~roles ~start_day ~end_exclusive =
  let role locus = List.assoc_opt locus roles in
  let table = Hashtbl.create 16 in
  List.iter
    (fun (entry : B.entry) ->
      if entry.day >= start_day && entry.day < end_exclusive then
        let seen = Hashtbl.create 4 in
        List.iter
          (fun (posting : D.Effect.t) ->
            let locus = D.Identifier.Locus.to_string (D.Effect.locus posting) in
            if
              D.Identifier.Measure.to_string (D.Effect.measure posting) = measure
              && role locus = Some Roles.Expense
              && not (Hashtbl.mem seen locus)
            then (
              Hashtbl.replace seen locus ();
              let entries, total =
                Option.value ~default:(0, Z.zero) (Hashtbl.find_opt table locus)
              in
              Hashtbl.replace table locus
                (entries + 1, Z.add total (Z.abs (D.Quantity.quanta (D.Effect.quantity posting))))))
          entry.effects)
    (B.entries book);
  Hashtbl.fold (fun locus (entries, total) acc -> (locus, entries, total) :: acc) table []
  |> List.sort (fun (a, entries_a, total_a) (b, entries_b, total_b) ->
      let by_entries = compare entries_b entries_a in
      if by_entries <> 0 then by_entries
      else
        let by_total = Z.compare total_b total_a in
        if by_total <> 0 then by_total else String.compare a b)
  |> List.filteri (fun index _ -> index < 3)
  |> List.map (fun (locus, _, _) -> { locus; measure })

let validate_coordinates ~book ~(coordinates : coordinate list) =
  match coordinates with
  | [] -> Error "Select at least one Locus."
  | first :: _ ->
      let measure = first.measure in
      if measure = "" then Error "No Measure is selected."
      else if List.length coordinates > 5 then Error "At most five Loci can be compared."
      else if not (List.exists (fun (name, _) -> name = measure) (B.measures book)) then
        Error ("Measure is not configured in the book: " ^ measure)
      else
        let rec loop seen = function
          | [] -> Ok measure
          | { locus; measure = selected } :: rest ->
              if locus = "" then Error "A selected Locus is empty."
              else if selected <> measure then
                Error "Every selected Locus must use the same Measure."
              else if List.mem locus seen then Error ("Locus is selected twice: " ^ locus)
              else loop (locus :: seen) rest
        in
        loop [] coordinates

let lower_bound days key =
  let low = ref 0 and high = ref (Array.length days) in
  while !low < !high do
    let middle = (!low + !high) / 2 in
    if String.compare days.(middle) key < 0 then low := middle + 1 else high := middle
  done;
  !low

let window_total (days, sums) start_day end_exclusive =
  Z.sub sums.(lower_bound days end_exclusive) sums.(lower_bound days start_day)

let project ~book ~observed_at ~boundary_presets_text ~grain ~scope ~coordinates =
  if not (canonical_date observed_at) then Error "Observation day is not a real Gregorian date."
  else
    let* measure = validate_coordinates ~book ~coordinates in
    let* scope_end_exclusive =
      match Day.shift_days observed_at 1 with Ok day -> Ok day | Error why -> Error why
    in
    let effective_scope = match grain with Day -> scope | Cycle | Month -> All_history in
    let* bounds = configured_bounds ~observed_at ~text:boundary_presets_text in
    let* scope_start =
      match effective_scope with
      | All_history -> Ok bounds.history_start
      | Current_cycle -> Ok bounds.cycle_start
      | Current_month -> Ok (max (String.sub observed_at 0 8 ^ "01") bounds.history_start)
      | Last_30_days -> (
          match Day.shift_days observed_at (-29) with
          | Ok from -> Ok (max from bounds.history_start)
          | Error why -> Error why)
    in
    let* windows =
      match grain with
      | Day ->
          let rec loop day acc =
            if day >= scope_end_exclusive then Ok (List.rev acc)
            else
              match Day.shift_days day 1 with
              | Error why -> Error why
              | Ok next -> loop next ((day, next, day, next) :: acc)
          in
          loop scope_start []
      | Month ->
          let rec loop natural_start acc =
            if natural_start >= scope_end_exclusive then Ok (List.rev acc)
            else
              match Day.shift_months natural_start 1 with
              | Error why -> Error why
              | Ok natural_end ->
                  let start_day = max natural_start scope_start in
                  let end_exclusive = min natural_end scope_end_exclusive in
                  if start_day >= end_exclusive then loop natural_end acc
                  else
                    loop natural_end ((start_day, end_exclusive, natural_start, natural_end) :: acc)
          in
          loop (String.sub scope_start 0 8 ^ "01") []
      | Cycle ->
          let rec loop acc = function
            | [] -> Ok (List.rev acc)
            | (_, start, stop) :: rest ->
                if stop <= scope_start || start >= scope_end_exclusive then loop acc rest
                else
                  let start_day = max start scope_start in
                  let end_exclusive = min stop scope_end_exclusive in
                  if start_day >= end_exclusive then loop acc rest
                  else loop ((start_day, end_exclusive, start, stop) :: acc) rest
          in
          loop [] bounds.windows
    in
    let selected = Hashtbl.create 8 in
    let daily : (string, (string, Z.t) Hashtbl.t) Hashtbl.t = Hashtbl.create 8 in
    List.iter
      (fun coordinate ->
        Hashtbl.replace selected coordinate.locus ();
        Hashtbl.replace daily coordinate.locus (Hashtbl.create 8))
      coordinates;
    List.iter
      (fun (entry : B.entry) ->
        if entry.day >= scope_start && entry.day < scope_end_exclusive then
          List.iter
            (fun (posting : D.Effect.t) ->
              let locus = D.Identifier.Locus.to_string (D.Effect.locus posting) in
              if
                Hashtbl.mem selected locus
                && D.Identifier.Measure.to_string (D.Effect.measure posting) = measure
              then
                let table = Hashtbl.find daily locus in
                let quantity = D.Quantity.quanta (D.Effect.quantity posting) in
                let prior = Option.value ~default:Z.zero (Hashtbl.find_opt table entry.day) in
                Hashtbl.replace table entry.day (Z.add prior quantity))
            entry.effects)
      (B.entries book);
    let prefix_of locus =
      let table = Hashtbl.find daily locus in
      let days =
        Hashtbl.fold (fun day _ acc -> day :: acc) table []
        |> List.sort String.compare |> Array.of_list
      in
      let sums = Array.make (Array.length days + 1) Z.zero in
      Array.iteri
        (fun index day -> sums.(index + 1) <- Z.add sums.(index) (Hashtbl.find table day))
        days;
      (days, sums)
    in
    let make_point ~days ~natural_start ~natural_end start_day end_exclusive =
      let observed_days = days_between start_day end_exclusive in
      let total = window_total days start_day end_exclusive in
      let value =
        match grain with Day -> total | Month | Cycle -> Z.ediv total (Z.of_int observed_days)
      in
      {
        start_day;
        end_exclusive;
        observed_days;
        total;
        value;
        complete =
          start_day = natural_start && end_exclusive = natural_end
          && (grain <> Day || start_day < observed_at);
      }
    in
    let series =
      List.map
        (fun coordinate ->
          let days = prefix_of coordinate.locus in
          let points =
            List.map
              (fun (start_day, end_exclusive, natural_start, natural_end) ->
                make_point ~days ~natural_start ~natural_end start_day end_exclusive)
              windows
            |> Array.of_list
          in
          { coordinate; label = B.label book coordinate.locus; points })
        coordinates
      |> Array.of_list
    in
    Ok
      {
        measure;
        observed_at;
        source = Printf.sprintf "%s (boundary-presets.tsv)" bounds.preset;
        scope_start;
        scope_end_exclusive;
        grain;
        scope = effective_scope;
        series;
      }
