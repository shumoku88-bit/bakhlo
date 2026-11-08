(* Daily Pace from the settings files beside the book: today's answer
   (Book.daily_pace over the pool in daily-pace.tsv and the current cycle of
   boundary-presets.tsv), a purchase or income priced against it, and a daily spend
   that keeps a target pace. Read-only; exact quanta; floors like the pace itself. *)
module B = Bakhlo_household.Book
module Day = Bakhlo_household.Day
module Period = Bakhlo_household.Period

let config_lines text =
  String.split_on_char '\n' text
  |> List.filter (fun line ->
      let s = String.trim line in
      s <> "" && not (String.starts_with ~prefix:"#" s))

let config_token s = s <> "" && String.for_all (fun c -> Char.code c > 32 && Char.code c <> 127) s

let window_of ~config ~today =
  Result.bind (config "boundary-presets.tsv") (function
    | None -> Error "Period not configured (boundary-presets.tsv missing)."
    | Some text -> (
        match Result.bind (Period.parse text) (Period.cycle ~day:today) with
        | Error why -> Error (Period.message ~today why)
        | Ok cycle -> Ok (List.nth cycle.windows cycle.index)))

let pool_of ~config ~measure =
  let rec coordinates acc = function
    | [] -> if acc = [] then Error "Daily Pace pool is empty." else Ok (List.rev acc)
    | line :: rest -> (
        match String.split_on_char '\t' line with
        | [ locus; m ] when config_token locus && m = measure ->
            let coordinate = { B.locus; measure = m } in
            if List.mem coordinate acc then Error "Duplicate Daily Pace coordinate."
            else coordinates (coordinate :: acc) rest
        | _ -> Error "Malformed daily-pace.tsv or mismatched Measure; no rows were skipped.")
  in
  Result.bind (config "daily-pace.tsv") (function
    | None -> Error "Daily Pace pool not configured (daily-pace.tsv missing)."
    | Some text -> coordinates [] (config_lines text))

let format_pace_error why =
  let coordinate () =
    match String.split_on_char ':' why with
    | [ _; locus; measure ] -> Some (locus ^ " " ^ measure)
    | _ -> None
  in
  let balance label = match coordinate () with Some c -> label ^ ": " ^ c | None -> label ^ "." in
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

let today ~book ~measure ~today ~config =
  Result.bind (pool_of ~config ~measure) (fun pool ->
      Result.bind (window_of ~config ~today) (fun (start_day, end_exclusive) ->
          Result.map
            (fun p -> (p, start_day, end_exclusive))
            (Result.map_error format_pace_error
               (B.daily_pace book ~measure ~pool ~observed_at:today ~end_exclusive))))

(* What-if: [+] is an income, [-] or no sign a purchase. *)
type projection = {
  current_per_day : Z.t;
  projected_per_day : Z.t;
  change_per_day : Z.t;
  available_after : Z.t;
}

let scale book measure = Option.value ~default:0 (List.assoc_opt measure (B.measures book))
let unit_name (p : B.daily_pace) = String.uppercase_ascii p.measure

(* [+] is an income, [-] or no sign a purchase; the rest is the amount. *)
let split_sign input =
  let rest () = String.sub input 1 (String.length input - 1) in
  if String.starts_with ~prefix:"+" input then (true, rest ())
  else if String.starts_with ~prefix:"-" input then (false, rest ())
  else (false, input)

let project ~book (p : B.daily_pace) input =
  let income, digits = split_sign input in
  let valid =
    digits <> ""
    && String.length digits <= 18
    && String.for_all
         (fun c -> (c >= '0' && c <= '9') || (c = '.' && scale book p.measure > 0))
         digits
  in
  if p.remaining_days <= 0 then Error "No remaining days in this cycle."
  else if not valid then
    Error ("Enter a " ^ unit_name p ^ " amount, +amount for income (up to 18 digits).")
  else
    match B.parse_signed_amount book ~measure:p.measure digits with
    | Error _ -> Error ("Invalid " ^ unit_name p ^ " amount.")
    | Ok quanta ->
        let after = (if income then Z.add else Z.sub) p.available_through_end quanta in
        let projected = Z.ediv after (Z.of_int p.remaining_days) in
        Ok
          {
            current_per_day = p.daily_pace_quanta;
            projected_per_day = projected;
            change_per_day = Z.sub projected p.daily_pace_quanta;
            available_after = after;
          }

(* Target pace: the largest whole daily spend that still reaches a target. *)
type plan = {
  target_per_day : Z.t;
  target_date : string;
  purchase : Z.t;
  days : int;
  daily_spend : Z.t;
  reachable : bool;
  path : Z.t list;
}

type options = { horizons : plan list; earliest : plan option }

let digits text = String.for_all (fun c -> c >= '0' && c <= '9') text

(* Spending [s] on each of [days] days leaves [available - s*days] for
   [remaining - days] days, so the largest [s] reaching target [n] is
   floor((available - n*(remaining - days)) / days). *)
let solve (p : B.daily_pace) available n purchase days date =
  let rest = Z.of_int (p.remaining_days - days) in
  let raw = Z.ediv (Z.sub available (Z.mul n rest)) (Z.of_int days) in
  let spend = Z.max Z.zero raw in
  {
    target_per_day = n;
    target_date = date;
    purchase;
    days;
    daily_spend = spend;
    reachable = Z.geq raw Z.zero;
    path =
      List.init (days + 1) (fun i ->
          Z.ediv (Z.sub available (Z.mul spend (Z.of_int i))) (Z.of_int (p.remaining_days - i)));
  }

let unit_quanta book measure =
  match List.assoc_opt measure (B.measures book) with
  | Some scale -> Ok (Z.pow (Z.of_int 10) scale)
  | None -> Error ("Unknown Measure " ^ measure ^ ".")

let amount ~book (p : B.daily_pace) label text =
  if String.length text > 18 || not (digits text) then
    Error
      (label ^ " accepts nonnegative " ^ String.uppercase_ascii p.measure
     ^ " digits only (up to 18).")
  else if text = "" then Error ("Invalid " ^ label ^ ".")
  else Result.map (Z.mul (Z.of_string text)) (unit_quanta book p.measure)

let available_after ~book (p : B.daily_pace) purchase =
  if purchase = "" then Ok p.available_through_end
  else Result.map (Z.sub p.available_through_end) (amount ~book p "Spend today" purchase)

let target_amount ~book (p : B.daily_pace) target =
  if target = "" then
    Error
      ("Enter a nonnegative target " ^ String.uppercase_ascii p.measure ^ "/day (up to 18 digits).")
  else amount ~book p ("Target " ^ String.uppercase_ascii p.measure ^ "/day") target

let day_number text = Result.value ~default:0 (Day.index text)
let shift day n = match Day.shift_days day n with Ok d -> Some d | Error _ -> None
let valid_date date = Day.normalize date = Ok date

(* [D]/[DD] and [M-D]/[MM-DD] name the first such day after today and before
   cycle end; any other spelling is returned unchanged for full validation. *)
let resolve_date (p : B.daily_pace) text =
  let part value =
    if String.length value >= 1 && String.length value <= 2 && digits value then
      int_of_string_opt value
    else None
  in
  let month, day =
    match String.split_on_char '-' text with
    | [ day ] -> (Some None, part day)
    | [ month; day ] -> (Option.map Option.some (part month), part day)
    | _ -> (None, None)
  in
  match (month, day) with
  | Some month, Some day ->
      let fits date =
        match Day.parts date with
        | Ok (_, m, d) -> d = day && Option.fold ~none:true ~some:(( = ) m) month
        | Error _ -> false
      in
      let rec find offset =
        if offset >= p.remaining_days - 1 then
          Error
            ("No day " ^ text ^ " after today and before cycle end " ^ p.end_exclusive
           ^ " (exclusive).")
        else
          match shift p.observed_at (offset + 1) with
          | Some date when fits date -> Ok date
          | _ -> find (offset + 1)
      in
      find 0
  | _ -> Ok text

let ( let* ) = Result.bind

let plan ~book (p : B.daily_pace) ~target ~date ~purchase =
  let* available = available_after ~book p purchase in
  let* n = target_amount ~book p target in
  let* date = resolve_date p date in
  if not (valid_date date) then Error "Enter a real target date as YYYY-MM-DD."
  else
    let distance = day_number date - day_number p.observed_at in
    if distance <= 0 || distance >= p.remaining_days then
      Error
        ("Target date must be after today and before cycle end " ^ p.end_exclusive ^ " (exclusive).")
    else Ok (solve p available n (Z.sub p.available_through_end available) distance date)

let options ~book (p : B.daily_pace) ~target ~purchase =
  let* available = available_after ~book p purchase in
  let* n = target_amount ~book p target in
  let last = max 0 (p.remaining_days - 1) in
  if last = 0 then Error "No later day remains in this cycle."
  else
    let plan_at days =
      Option.map
        (fun date -> solve p available n (Z.sub p.available_through_end available) days date)
        (shift p.observed_at days)
    in
    Ok
      {
        horizons =
          List.filter_map plan_at (List.filter (fun d -> d < last) [ 3; 7; 14; 21; 28; 42 ]);
        earliest =
          List.find_map
            (fun days ->
              Option.bind (plan_at days) (fun plan -> if plan.reachable then Some plan else None))
            (List.init last (fun i -> i + 1));
      }
