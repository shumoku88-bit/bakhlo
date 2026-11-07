(* The household's days: YYYY-MM-DD in the proleptic Gregorian calendar, typed dates
   normalized to that form, and arithmetic over them. No clock, no local timestamps. *)

let halfwidth text =
  let len = String.length text in
  let b = Buffer.create len in
  let rec loop i =
    if i >= len then Buffer.contents b
    else if i + 2 < len && Char.code text.[i] = 0xEF && Char.code text.[i + 1] = 0xBC then
      let c3 = Char.code text.[i + 2] in
      if c3 >= 0x90 && c3 <= 0x99 then begin
        Buffer.add_char b (Char.chr (Char.code '0' + (c3 - 0x90)));
        loop (i + 3)
      end
      else if c3 = 0x8F then begin
        Buffer.add_char b '/';
        loop (i + 3)
      end
      else if c3 = 0x8E then begin
        Buffer.add_char b '.';
        loop (i + 3)
      end
      else if c3 = 0x8D then begin
        Buffer.add_char b '-';
        loop (i + 3)
      end
      else begin
        Buffer.add_substring b text i 3;
        loop (i + 3)
      end
    else begin
      Buffer.add_char b text.[i];
      loop (i + 1)
    end
  in
  loop 0

let is_leap_year y = y mod 400 = 0 || (y mod 4 = 0 && y mod 100 <> 0)

let days_in_month ~year ~month =
  match month with
  | 1 | 3 | 5 | 7 | 8 | 10 | 12 -> 31
  | 4 | 6 | 9 | 11 -> 30
  | 2 -> if is_leap_year year then 29 else 28
  | _ -> 0

let normalize text =
  let norm = halfwidth text in
  let count_char c s =
    let count = ref 0 in
    String.iter (fun ch -> if ch = c then incr count) s;
    !count
  in
  let dashes = count_char '-' norm in
  let slashes = count_char '/' norm in
  let dots = count_char '.' norm in
  let sep_opt =
    if dashes = 2 && slashes = 0 && dots = 0 then Some '-'
    else if slashes = 2 && dashes = 0 && dots = 0 then Some '/'
    else if dots = 2 && dashes = 0 && slashes = 0 then Some '.'
    else None
  in
  match sep_opt with
  | None -> Error "invalid-date"
  | Some sep -> (
      match String.split_on_char sep norm with
      | [ y_str; m_str; d_str ] ->
          let is_digit c = c >= '0' && c <= '9' in
          if String.length y_str <> 4 || not (String.for_all is_digit y_str) then
            Error "invalid-date"
          else if
            (String.length m_str < 1 || String.length m_str > 2)
            || not (String.for_all is_digit m_str)
          then Error "invalid-date"
          else if
            (String.length d_str < 1 || String.length d_str > 2)
            || not (String.for_all is_digit d_str)
          then Error "invalid-date"
          else
            let year = int_of_string y_str in
            let month = int_of_string m_str in
            let day = int_of_string d_str in
            if year < 1 || year > 9999 then Error "invalid-date"
            else if month < 1 || month > 12 then Error "invalid-date"
            else if day < 1 || day > days_in_month ~year ~month then Error "invalid-date"
            else Ok (Printf.sprintf "%04d-%02d-%02d" year month day)
      | _ -> Error "invalid-date")

let next (year, month, day) =
  let max_d = days_in_month ~year ~month in
  if day < max_d then (year, month, day + 1)
  else if month < 12 then (year, month + 1, 1)
  else (year + 1, 1, 1)

let previous (year, month, day) =
  if day > 1 then (year, month, day - 1)
  else if month > 1 then
    let prev_m = month - 1 in
    (year, prev_m, days_in_month ~year ~month:prev_m)
  else (year - 1, 12, 31)

let shift_days date_str step =
  match normalize date_str with
  | Error _ -> Error "invalid-date"
  | Ok canon ->
      let year = int_of_string (String.sub canon 0 4)
      and month = int_of_string (String.sub canon 5 2)
      and day = int_of_string (String.sub canon 8 2) in
      let rec loop (y, m, d) n =
        if n = 0 then (y, m, d)
        else if n > 0 then loop (next (y, m, d)) (n - 1)
        else loop (previous (y, m, d)) (n + 1)
      in
      let y, m, d = loop (year, month, day) step in
      if y < 1 || y > 9999 then Error "date-out-of-range"
      else Ok (Printf.sprintf "%04d-%02d-%02d" y m d)

let is_valid day = Bakhlo_book_txt.Book_txt.valid_date day

let parts text =
  match normalize text with
  | Error _ -> Error "Enter a real Gregorian date."
  | Ok day ->
      Ok
        ( int_of_string (String.sub day 0 4),
          int_of_string (String.sub day 5 2),
          int_of_string (String.sub day 8 2) )

let canonical y m d =
  if y < 1 || y > 9999 || m < 1 || m > 12 then Error "Date is outside 0001–9999."
  else normalize (Printf.sprintf "%04d-%02d-%02d" y m d)

let day_number y m d =
  let prior = y - 1 in
  let before = [| 0; 0; 31; 59; 90; 120; 151; 181; 212; 243; 273; 304; 334 |] in
  (prior * 365) + (prior / 4) - (prior / 100) + (prior / 400) + before.(m)
  + (if m > 2 && is_leap_year y then 1 else 0)
  + d - 1

let weekday day =
  match parts day with Error _ as error -> error | Ok (y, m, d) -> Ok (day_number y m d mod 7)

let shift_months day delta =
  match parts day with
  | Error _ as error -> error
  | Ok (y, m, d) ->
      let index = ((y - 1) * 12) + m - 1 + delta in
      if index < 0 || index >= 9999 * 12 then Error "Date is outside 0001–9999."
      else
        let year = (index / 12) + 1 and month = (index mod 12) + 1 in
        canonical year month (min d (days_in_month ~year ~month))

let shift_years day delta =
  match parts day with
  | Error _ as error -> error
  | Ok (y, m, d) ->
      let year = y + delta in
      canonical year m (min d (days_in_month ~year ~month:m))

let index text =
  match parts text with Ok (y, m, d) -> Ok (day_number y m d) | Error why -> Error why
