let parts text =
  match Daily_draft.normalize_date text with
  | Error _ -> Error "Enter a real Gregorian date."
  | Ok day ->
      Ok
        ( int_of_string (String.sub day 0 4),
          int_of_string (String.sub day 5 2),
          int_of_string (String.sub day 8 2) )

let canonical y m d =
  if y < 1 || y > 9999 || m < 1 || m > 12 then Error "Date is outside 0001–9999."
  else Daily_draft.normalize_date (Printf.sprintf "%04d-%02d-%02d" y m d)

let day_number y m d =
  let prior = y - 1 in
  let before = [| 0; 0; 31; 59; 90; 120; 151; 181; 212; 243; 273; 304; 334 |] in
  (prior * 365) + (prior / 4) - (prior / 100) + (prior / 400) + before.(m)
  + (if m > 2 && Daily_draft.is_leap_year y then 1 else 0)
  + d - 1

let weekday day =
  match parts day with Error _ as error -> error | Ok (y, m, d) -> Ok (day_number y m d mod 7)

let shift_days = Daily_draft.shift_calendar_day

let shift_months day delta =
  match parts day with
  | Error _ as error -> error
  | Ok (y, m, d) ->
      let index = ((y - 1) * 12) + m - 1 + delta in
      if index < 0 || index >= 9999 * 12 then Error "Date is outside 0001–9999."
      else
        let year = (index / 12) + 1 and month = (index mod 12) + 1 in
        canonical year month (min d (Daily_draft.days_in_month ~year ~month))

let shift_years day delta =
  match parts day with
  | Error _ as error -> error
  | Ok (y, m, d) ->
      let year = y + delta in
      canonical year m (min d (Daily_draft.days_in_month ~year ~month:m))

let day_index text =
  match parts text with Ok (y, m, d) -> Ok (day_number y m d) | Error why -> Error why
