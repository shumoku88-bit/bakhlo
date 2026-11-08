(* The household's periods.

   A month or a year is the calendar's. A cycle is the household's own: a pay
   period, say, from the 25th to the 24th. Bakhlo never guesses one; it reads
   boundary-presets.tsv, where each line names a preset and lists its boundary
   dates:

     pay	2027-01-25	2027-02-25	2027-03-25

   That line gives two windows, [01-25, 02-25) and [02-25, 03-25). The cycle of a
   day is the one window that contains it. When no preset covers the day, or two
   presets do, there is no cycle, and every screen says so instead of picking one. *)

type preset = string * string list

type refusal =
  | Not_configured
  | Malformed
  | No_cycle of string
  | Ambiguous of string
  | Outside_presets
  | Out_of_range

let code = function
  | Not_configured -> "not-configured"
  | Malformed -> "malformed"
  | No_cycle day -> "no-cycle:" ^ day
  | Ambiguous day -> "ambiguous:" ^ day
  | Outside_presets -> "outside-presets"
  | Out_of_range -> "out-of-range"

let message ?today refusal =
  let named day = if Some day = today then "today" else day in
  match refusal with
  | Not_configured -> "Period not configured (boundary-presets.tsv missing)."
  | Malformed -> "Malformed boundary-presets.tsv; no period was inferred."
  | No_cycle day -> "No explicit boundary preset contains " ^ named day ^ "."
  | Ambiguous day -> "Multiple boundary presets contain " ^ named day ^ "; selection is ambiguous."
  | Outside_presets -> "Cycle boundary is outside configured presets."
  | Out_of_range -> "Date is outside 0001–9999."

let ( let* ) = Result.bind

(* 1. Reading the file. *)

let token text = text <> "" && String.for_all (fun c -> Char.code c > 32 && Char.code c <> 127) text
let canonical day = Day.normalize day = Ok day

let rec increasing = function
  | a :: (b :: _ as rest) -> a < b && increasing rest
  | [] | [ _ ] -> true

let parse text =
  let rec read names presets = function
    | [] -> Ok (List.rev presets)
    | line :: rest -> (
        match String.split_on_char '\t' line with
        | name :: dates
          when token name
               && (not (List.mem name names))
               && List.length dates >= 2
               && List.for_all canonical dates && increasing dates ->
            read (name :: names) ((name, dates) :: presets) rest
        | _ -> Error Malformed)
  in
  String.split_on_char '\n' text |> List.map String.trim
  |> List.filter (fun line -> line <> "" && not (String.starts_with ~prefix:"#" line))
  |> read [] []

let windows presets =
  let rec pairs name = function
    | a :: (b :: _ as rest) -> (name, a, b) :: pairs name rest
    | [] | [ _ ] -> []
  in
  List.concat_map (fun (name, dates) -> pairs name dates) presets

(* 2. The cycle of a day: exactly one preset must cover it. *)

type cycle = { name : string; windows : (string * string) list; index : int }

let contains day (start, stop) = start <= day && day < stop

let read config =
  let* text = Option.to_result ~none:Not_configured config in
  parse text

let cycle presets ~day =
  let own (name, dates) =
    let ws = List.map (fun (_, a, b) -> (a, b)) (windows [ (name, dates) ]) in
    Option.map (fun index -> { name; windows = ws; index }) (List.find_index (contains day) ws)
  in
  match List.filter_map own presets with
  | [ cycle ] -> Ok cycle
  | [] -> Error (No_cycle day)
  | _ -> Error (Ambiguous day)

let window_of cycle day = List.find_opt (contains day) cycle.windows

(* 3. A window of a span, moved by whole spans. Months and years keep the day of
   the month only to find the start; a window always starts on the 1st. *)

type span = Day | Month | Year | Cycle | Previous_cycle | All

let calendar step = Result.map_error (fun _ -> Out_of_range) step

let window ~config ~day span ~offset =
  match span with
  | All -> Ok ("0001-01-01", "9999-12-31")
  | Day ->
      let* start = calendar (Day.shift_days day offset) in
      let* stop = calendar (Day.shift_days start 1) in
      Ok (start, stop)
  | Month ->
      let* start = calendar (Day.shift_months (String.sub day 0 8 ^ "01") offset) in
      let* stop = calendar (Day.shift_months start 1) in
      Ok (start, stop)
  | Year ->
      let* start = calendar (Day.shift_years (String.sub day 0 4 ^ "-01-01") offset) in
      let* stop = calendar (Day.shift_years start 1) in
      Ok (start, stop)
  | Cycle | Previous_cycle ->
      let* presets = read config in
      let* cycle = cycle presets ~day in
      let target = cycle.index + offset - if span = Previous_cycle then 1 else 0 in
      if target < 0 then Error Outside_presets
      else Option.to_result ~none:Outside_presets (List.nth_opt cycle.windows target)

(* 4. The days Daily Pace History lists, through today or through the end of the
   previous cycle. *)

type range = Last_days of int | Month_to_date | Cycle_to_date | Whole_previous_cycle

let range ~config ~today = function
  | Last_days n ->
      let* first = calendar (Day.shift_days today (1 - n)) in
      Ok (first, today)
  | Month_to_date -> Ok (String.sub today 0 8 ^ "01", today)
  | Cycle_to_date ->
      let* first, _ = window ~config ~day:today Cycle ~offset:0 in
      Ok (first, today)
  | Whole_previous_cycle ->
      let* first, stop = window ~config ~day:today Previous_cycle ~offset:0 in
      let* last = calendar (Day.shift_days stop (-1)) in
      Ok (first, last)

(* 5. Comparison windows: include today in the elapsed count; zero days is an
   empty window, not the whole previous window. *)

let elapsed ~today (start, stop) =
  match (Day.index today, Day.index start, Day.index stop) with
  | Ok now, Ok start, Ok stop ->
      let total = max 0 (stop - start) in
      (max 0 (min total (now - start + 1)), total)
  | _ -> (0, 0)

let same_age (start, stop) days =
  if days <= 0 then (start, start)
  else match Day.shift_days start days with Ok day -> (start, day) | Error _ -> (start, stop)
