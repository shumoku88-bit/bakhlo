type zoom = Day | Month | Year
type t = { selected_day : string; zoom : zoom }
type action = Left | Right | Up | Down | Cycle_zoom | Drill | Today of string | Jump of string
type transition = Moved of t | Open_day of t | Refused of string

let parts text =
  match Daily_actions.normalize_date text with
  | Error _ -> Error "Enter a real Gregorian date."
  | Ok day ->
      Ok
        ( int_of_string (String.sub day 0 4),
          int_of_string (String.sub day 5 2),
          int_of_string (String.sub day 8 2) )

let canonical y m d =
  if y < 1 || y > 9999 || m < 1 || m > 12 then Error "Date is outside 0001–9999."
  else Daily_actions.normalize_date (Printf.sprintf "%04d-%02d-%02d" y m d)

let create day =
  match Daily_actions.normalize_date day with
  | Ok selected_day -> Ok { selected_day; zoom = Day }
  | Error _ -> Error "Enter a real Gregorian date."

let day_number y m d =
  let prior = y - 1 in
  let before = [| 0; 0; 31; 59; 90; 120; 151; 181; 212; 243; 273; 304; 334 |] in
  (prior * 365) + (prior / 4) - (prior / 100) + (prior / 400) + before.(m)
  + (if m > 2 && Daily_actions.is_leap_year y then 1 else 0)
  + d - 1

let weekday day =
  match parts day with Error _ as error -> error | Ok (y, m, d) -> Ok (day_number y m d mod 7)

let shift_days = Daily_actions.shift_calendar_day

let shift_months day delta =
  match parts day with
  | Error _ as error -> error
  | Ok (y, m, d) ->
      let index = ((y - 1) * 12) + m - 1 + delta in
      if index < 0 || index >= 9999 * 12 then Error "Date is outside 0001–9999."
      else
        let year = (index / 12) + 1 and month = (index mod 12) + 1 in
        canonical year month (min d (Daily_actions.days_in_month ~year ~month))

let shift_years day delta =
  match parts day with
  | Error _ as error -> error
  | Ok (y, m, d) ->
      let year = y + delta in
      canonical year m (min d (Daily_actions.days_in_month ~year ~month:m))

let parse_jump ~base input =
  let input = String.trim input |> String.map (fun c -> if c = '/' then '-' else c) in
  let digits text = text <> "" && String.for_all (fun c -> c >= '0' && c <= '9') text in
  match parts base with
  | Error _ as error -> error
  | Ok (y, m, _) -> (
      let date, zoom =
        match String.split_on_char '-' input with
        | [ year; month ]
          when String.length year = 4 && digits year && digits month && String.length month <= 2 ->
            (Printf.sprintf "%s-%02d-01" year (int_of_string month), Month)
        | [ month; day ]
          when digits month && digits day && String.length month <= 2 && String.length day <= 2 ->
            (Printf.sprintf "%04d-%02d-%02d" y (int_of_string month) (int_of_string day), Day)
        | _ -> (
            match String.length input with
            | (1 | 2) when digits input ->
                (Printf.sprintf "%04d-%02d-%02d" y m (int_of_string input), Day)
            | 4 when digits input -> (input ^ "-01-01", Year)
            | 6 when digits input ->
                (String.sub input 0 4 ^ "-" ^ String.sub input 4 2 ^ "-01", Month)
            | 8 when digits input ->
                (String.sub input 0 4 ^ "-" ^ String.sub input 4 2 ^ "-" ^ String.sub input 6 2, Day)
            | _ -> (input, Day))
      in
      match Daily_actions.normalize_date date with
      | Ok selected_day -> Ok { selected_day; zoom }
      | Error _ -> Error "Jump: use YYYY-MM-DD, YYYY-MM, YYYY, MM-DD or a day.")

let apply calendar action =
  let move shift delta =
    match shift calendar.selected_day delta with
    | Ok selected_day -> Moved { calendar with selected_day }
    | Error why -> Refused why
  in
  match action with
  | Cycle_zoom ->
      Moved
        {
          calendar with
          zoom = (match calendar.zoom with Day -> Month | Month -> Year | Year -> Day);
        }
  | Drill -> (
      match calendar.zoom with
      | Year -> Moved { calendar with zoom = Month }
      | Month -> Moved { calendar with zoom = Day }
      | Day -> Open_day calendar)
  | Today day -> (
      match create day with
      | Ok c -> Moved { c with zoom = calendar.zoom }
      | Error why -> Refused why)
  | Jump input -> (
      match parse_jump ~base:calendar.selected_day input with
      | Ok c -> Moved c
      | Error why -> Refused why)
  | Left | Right | Up | Down -> (
      let delta = match action with Left | Up -> -1 | Right | Down -> 1 | _ -> 0 in
      match calendar.zoom with
      | Day -> move shift_days (delta * match action with Up | Down -> 7 | _ -> 1)
      | Month -> move shift_months (delta * match action with Up | Down -> 3 | _ -> 1)
      | Year -> move shift_years delta)

let month_slots day =
  match parts day with
  | Error _ as error -> error
  | Ok (year, month, _) ->
      let first = day_number year month 1 mod 7 in
      let count = Daily_actions.days_in_month ~year ~month in
      let slots = (first + count + 6) / 7 * 7 in
      Ok
        (List.init slots (fun i ->
             if i < first || i >= first + count then None
             else Some (Printf.sprintf "%04d-%02d-%02d" year month (i - first + 1))))

let period_contains calendar day =
  let prefix n =
    String.length day >= n && String.sub day 0 n = String.sub calendar.selected_day 0 n
  in
  match calendar.zoom with
  | Day -> day = calendar.selected_day
  | Month -> prefix 7
  | Year -> prefix 4

let title calendar = match calendar.zoom with Day -> "Day" | Month -> "Month" | Year -> "Year"
