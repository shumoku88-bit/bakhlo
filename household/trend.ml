(* Trend: how one Locus's recorded flow moves over time.

   The household picks up to five Loci of one Measure and asks how much moved
   through each per cycle, month or day. History starts at the first boundary of
   the household's own cycle preset (test/periods), so a chart never reaches back
   to a guess. A cycle or month point is its daily average, floored:

     food  2027-01-25 .. 2027-02-25   31 days   total 9300   value 300

   while a day point is that day's total. The window containing the observation
   day is partial. Refunds count with their own sign; nothing is read as a
   balance. Pinned in test/reports ([TREND], [TREND-DEFAULT]). *)

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
  preset : string;
  scope_start : string;
  scope_end_exclusive : string;
  grain : grain;
  scope : scope;
  series : series array;
}

let ( let* ) = Result.bind

let days_between start_day end_exclusive =
  match (Day.index start_day, Day.index end_exclusive) with
  | Ok start, Ok stop when stop > start -> stop - start
  | _ -> invalid_arg "Trend: point window is not a real date range"

let canonical_date day =
  match Day.normalize day with Ok canonical -> canonical = day | Error _ -> false

type bounds = {
  preset : string;
  history_start : string;
  cycle_start : string;
  windows : (string * string * string) list;
}

type refusal =
  | Bad_observation_day
  | No_locus
  | No_measure
  | Too_many_loci
  | Unknown_measure of string
  | Empty_locus
  | Mixed_measures
  | Duplicate_locus of string
  | Period of Period.refusal

let code = function
  | Bad_observation_day -> "bad-observation-day"
  | No_locus -> "no-locus"
  | No_measure -> "no-measure"
  | Too_many_loci -> "too-many-loci"
  | Unknown_measure m -> "unknown-measure:" ^ m
  | Empty_locus -> "empty-locus"
  | Mixed_measures -> "mixed-measures"
  | Duplicate_locus l -> "duplicate-locus:" ^ l
  | Period why -> Period.code why

let message = function
  | Bad_observation_day -> "Observation day is not a real Gregorian date."
  | No_locus -> "Select at least one Locus."
  | No_measure -> "No Measure is selected."
  | Too_many_loci -> "At most five Loci can be compared."
  | Unknown_measure m -> "Measure is not configured in the book: " ^ m
  | Empty_locus -> "A selected Locus is empty."
  | Mixed_measures -> "Every selected Locus must use the same Measure."
  | Duplicate_locus l -> "Locus is selected twice: " ^ l
  | Period (No_cycle _) -> "No explicit boundary preset contains the observation day."
  | Period (Ambiguous _) ->
      "Multiple boundary presets contain the observation day; selection is ambiguous."
  | Period why -> Period.message why

let out_of_range = Period Period.Out_of_range

(* One explicit preset must own the observation day; its first boundary is the
   only history start, and every scope is clipped to it. *)
let configured_bounds ~observed_at ~text =
  match Result.bind (Period.read text) (Period.cycle ~day:observed_at) with
  | Error why -> Error (Period why)
  | Ok cycle ->
      let cycle_start = fst (List.nth cycle.windows cycle.index) in
      Ok
        {
          preset = cycle.name;
          history_start = fst (List.hd cycle.windows);
          cycle_start;
          windows = List.map (fun (a, b) -> (cycle.name, a, b)) cycle.windows;
        }

let catalog book ~measure =
  let historical =
    List.concat_map
      (fun (entry : Book.entry) ->
        List.filter_map
          (fun (posting : Book.posting) ->
            if posting.measure = measure then Some posting.locus else None)
          entry.effects)
      (Book.entries book)
  in
  let admitted = Option.value ~default:[] (Book.approved_loci book) in
  List.sort_uniq String.compare (admitted @ historical)
  |> List.map (fun locus -> { locus; measure })

let history_start ~observed_at ~boundary_presets_text =
  Result.map
    (fun (bounds : bounds) -> bounds.history_start)
    (configured_bounds ~observed_at ~text:boundary_presets_text)

(* The default series: the three Expense-role Loci with the most recorded
   entries in the shown history. Ties go to the larger recorded movement first,
   then to the token, so the choice is deterministic and derived from data. *)
let initial_series book ~measure ~start_day ~end_exclusive =
  let roles = Book.roles book in
  let role locus = List.assoc_opt locus roles in
  let table = Hashtbl.create 16 in
  List.iter
    (fun (entry : Book.entry) ->
      if entry.day >= start_day && entry.day < end_exclusive then
        let seen = Hashtbl.create 4 in
        List.iter
          (fun (posting : Book.posting) ->
            let locus = posting.locus in
            if
              posting.measure = measure
              && role locus = Some Book.T.Expense
              && not (Hashtbl.mem seen locus)
            then (
              Hashtbl.replace seen locus ();
              let entries, total =
                Option.value ~default:(0, Z.zero) (Hashtbl.find_opt table locus)
              in
              Hashtbl.replace table locus (entries + 1, Z.add total (Z.abs posting.amount))))
          entry.effects)
    (Book.entries book);
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
  | [] -> Error No_locus
  | first :: _ ->
      let measure = first.measure in
      if measure = "" then Error No_measure
      else if List.length coordinates > 5 then Error Too_many_loci
      else if not (List.exists (fun (name, _) -> name = measure) (Book.measures book)) then
        Error (Unknown_measure measure)
      else
        let rec loop seen = function
          | [] -> Ok measure
          | { locus; measure = selected } :: rest ->
              if locus = "" then Error Empty_locus
              else if selected <> measure then Error Mixed_measures
              else if List.mem locus seen then Error (Duplicate_locus locus)
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

let project book ~observed_at ~boundary_presets_text ~grain ~scope ~coordinates =
  if not (canonical_date observed_at) then Error Bad_observation_day
  else
    let* measure = validate_coordinates ~book ~coordinates in
    let* scope_end_exclusive =
      match Day.shift_days observed_at 1 with Ok day -> Ok day | Error _ -> Error out_of_range
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
          | Error _ -> Error out_of_range)
    in
    let* windows =
      match grain with
      | Day ->
          let rec loop day acc =
            if day >= scope_end_exclusive then Ok (List.rev acc)
            else
              match Day.shift_days day 1 with
              | Error _ -> Error out_of_range
              | Ok next -> loop next ((day, next, day, next) :: acc)
          in
          loop scope_start []
      | Month ->
          let rec loop natural_start acc =
            if natural_start >= scope_end_exclusive then Ok (List.rev acc)
            else
              match Day.shift_months natural_start 1 with
              | Error _ -> Error out_of_range
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
      (fun (entry : Book.entry) ->
        if entry.day >= scope_start && entry.day < scope_end_exclusive then
          List.iter
            (fun (posting : Book.posting) ->
              let locus = posting.locus in
              if Hashtbl.mem selected locus && posting.measure = measure then
                let table = Hashtbl.find daily locus in
                let quantity = posting.amount in
                let prior = Option.value ~default:Z.zero (Hashtbl.find_opt table entry.day) in
                Hashtbl.replace table entry.day (Z.add prior quantity))
            entry.effects)
      (Book.entries book);
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
          { coordinate; label = Book.label book coordinate.locus; points })
        coordinates
      |> Array.of_list
    in
    Ok
      {
        measure;
        observed_at;
        preset = bounds.preset;
        scope_start;
        scope_end_exclusive;
        grain;
        scope = effective_scope;
        series;
      }
