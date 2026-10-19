(* LOAM Series Calendar: replaceable monitoring rules compared with explicit
   plans by exact signed-Locus shape. Read-only; no recurrence is inferred. *)
module B = Bakhlo_sexp.Daily_book
module A = Bakhlo_application

type rule = {
  name : string;
  anchor : string;
  every_months : int;
  negative : string list;
  positive : string list;
}

let token s = s <> "" && not (String.exists (fun c -> c = '\t' || c = '\n' || c = '\r') s)

let digits s =
  s <> "" && String.length s <= 9 && String.for_all (fun c -> c >= '0' && c <= '9') s

let loci text =
  let xs = List.sort String.compare (String.split_on_char ',' text) in
  if xs <> [] && List.for_all token xs
     && List.length (List.sort_uniq String.compare xs) = List.length xs
  then Some xs
  else None

let decode_row row =
  match String.split_on_char '\t' row with
  | [ name; anchor; every; negative; positive ]
    when token name && A.Actual_validity.valid_date anchor && digits every -> (
      match loci negative, loci positive with
      | Some negative, Some positive ->
          Some { name; anchor; every_months = int_of_string every; negative; positive }
      | _ -> None)
  | _ -> None

let of_string text =
  let rows = String.split_on_char '\n' text in
  let rows = match List.rev rows with "" :: rest -> List.rev rest | _ -> rows in
  let rec decode acc = function
    | [] -> Ok (List.rev acc)
    | row :: rest -> (
        match decode_row row with
        | Some rule -> decode (rule :: acc) rest
        | None -> Error ("Scheduled coverage config is malformed: row " ^ string_of_int (List.length acc + 1)))
  in
  match decode [] rows with
  | Error _ as e -> e
  | Ok rules ->
      let rec unique = function
        | [] -> true
        | r :: rest ->
            (not (List.exists (fun o -> o.name = r.name
                    || (o.negative = r.negative && o.positive = r.positive)) rest))
            && unique rest
      in
      if unique rules then Ok rules
      else Error "Scheduled coverage config repeats a plan name or shape."

let signed (p : B.plan) keep =
  List.sort_uniq String.compare
    (List.filter_map (fun (locus, q) -> if keep (Z.sign q) then Some locus else None) p.changes)

let matches rule (p : B.plan) =
  signed p (fun s -> s < 0) = rule.negative && signed p (fun s -> s > 0) = rule.positive

let month_index date =
  if not (A.Actual_validity.valid_date date) then None
  else Some ((int_of_string (String.sub date 0 4) * 12) + int_of_string (String.sub date 5 2) - 1)

let expected_at rule target =
  rule.every_months > 0
  && match month_index rule.anchor with
     | None -> false
     | Some anchor -> anchor <= target && (target - anchor) mod rule.every_months = 0

let expected_on rule date =
  match month_index date with None -> false | Some target -> expected_at rule target

type cell = { month : string; expected : bool; open_days : string list; completed_days : string list }

let missing c = c.expected && c.open_days = [] && c.completed_days = []

type row = { rule : rule; cells : cell list; first_missing : string option }

let month_text index = Printf.sprintf "%04d-%02d" (index / 12) ((index mod 12) + 1)

let row_before a b =
  match a.rule.every_months, b.rule.every_months with
  | 0, 0 -> a.rule.name <= b.rule.name
  | 0, _ -> false
  | _, 0 -> true
  | x, y when x = y -> a.rule.name <= b.rule.name
  | x, y -> x < y

let project rules ~plans ~today ~months =
  match month_index today with
  | None -> Error "Scheduled coverage observation must be a real YYYY-MM-DD date."
  | Some first ->
      let is_open (p : B.plan) = p.paid_by = None && p.cancelled_on = None in
      let open_plans = List.filter is_open plans
      and completed = List.filter (fun (p : B.plan) -> p.paid_by <> None) plans in
      let days rule plans index =
        List.sort String.compare
          (List.filter_map (fun (p : B.plan) ->
               if matches rule p && month_index p.day = Some index then Some (String.sub p.day 8 2)
               else None)
             plans)
      in
      let indices = List.init (max 0 months) (fun n -> first + n) in
      let row rule =
        let cells = List.map (fun index ->
            { month = month_text index; expected = expected_at rule index;
              open_days = days rule open_plans index; completed_days = days rule completed index })
            indices in
        { rule; cells;
          first_missing = Option.map (fun c -> c.month) (List.find_opt missing cells) }
      in
      let rows = List.map row rules in
      let ordered = List.stable_sort (fun a b -> if row_before a b then -1 else 1) rows in
      Ok (List.map month_text indices, ordered)

let cadence_label = function
  | 0 -> "undecided"
  | 1 -> "monthly"
  | 12 -> "yearly"
  | n -> "every " ^ string_of_int n ^ "m"

let cell_text c =
  let days = List.sort String.compare (c.open_days @ List.map (fun d -> d ^ "✓") c.completed_days) in
  let text = String.concat "," days in
  if days = [] then (if missing c then "!" else "")
  (* "✓" is one cell but three bytes. *)
  else if String.length text - (2 * List.length c.completed_days) <= 8 then text
  else
    String.concat "/"
      ((if c.open_days = [] then [] else [ string_of_int (List.length c.open_days) ^ "p" ])
       @ if c.completed_days = [] then [] else [ string_of_int (List.length c.completed_days) ^ "✓" ])

let month_label month =
  match String.sub month 5 2 with
  | "01" -> "Jan" | "02" -> "Feb" | "03" -> "Mar" | "04" -> "Apr" | "05" -> "May" | "06" -> "Jun"
  | "07" -> "Jul" | "08" -> "Aug" | "09" -> "Sep" | "10" -> "Oct" | "11" -> "Nov" | "12" -> "Dec"
  | m -> m
  | exception Invalid_argument _ -> month

let plans_for rule plans =
  List.filter (fun (p : B.plan) -> p.paid_by = None && p.cancelled_on = None && matches rule p) plans
  |> List.stable_sort (fun (a : B.plan) (b : B.plan) -> compare (a.day, a.id) (b.day, b.id))

let rule_for (p : B.plan) ~months =
  let negative = signed p (fun s -> s < 0) and positive = signed p (fun s -> s > 0) in
  if months <= 0 then Error "Monitoring cadence must be at least one month."
  else if negative = [] || positive = [] then
    Error "The selected Scheduled occurrence has no usable signed-Locus shape."
  else
    Ok { name = (match positive with [ only ] -> only | _ -> p.id); anchor = p.day;
         every_months = months; negative; positive }

let same_shape a b = a.negative = b.negative && a.positive = b.positive

let upsert rules rule =
  match List.find_opt (same_shape rule) rules with
  | Some existing ->
      Ok (List.map (fun r -> if same_shape r existing then { rule with name = existing.name } else r) rules)
  | None ->
      if List.exists (fun r -> r.name = rule.name) rules then
        Error ("Scheduled coverage name already monitors a different plan: " ^ rule.name)
      else Ok (rules @ [ rule ])

let to_string rules =
  String.concat "" (List.map (fun r ->
      String.concat "\t" [ r.name; r.anchor; string_of_int r.every_months;
                           String.concat "," r.negative; String.concat "," r.positive ] ^ "\n") rules)
