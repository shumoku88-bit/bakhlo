(* Liquidity: CONDITIONAL selected-balance path under one explicit assumption.
   Unlike Daily Pace this keeps future conditional inflows and refuses overdue
   selected changes; it never claims a forecast path or a known low-water mark. *)
module B = Bakhlo_household.Book
module O = Ui_render
module A = Daily_draft

type point = { date : string; scheduled_change : Z.t; balance : Z.t }

type snapshot = {
  as_of : string;
  assumed_complete_through : string;
  measure : string;
  current_selected : Z.t;
  points : point list;
}

let display_point_rows = 12

let signed book measure n =
  (if Z.sign n > 0 then "+" else "") ^ Book_display.format_money book measure n

let compute ~book ~today ~coords ~assumed_complete_through =
  let horizon = assumed_complete_through in
  if not (Day.is_valid today) then Error "Liquidity requires a real canonical today date."
  else if not (Day.is_valid horizon) then
    Error "The assumed complete-through date must be a real YYYY-MM-DD calendar date."
  else if String.compare horizon today < 0 then
    Error "The assumed complete-through date is inclusive and cannot precede today."
  else if coords = [] then Error "Liquidity requires a nonempty balance-view.tsv selection."
  else if List.length (List.sort_uniq compare coords) <> List.length coords then
    Error "Liquidity selection contains duplicate coordinates; no partial sum is used."
  else
    let measure = snd (List.hd coords) in
    if List.exists (fun (_, m) -> m <> measure) coords then
      Error "Liquidity selection spans multiple Measures; exactly one is required."
    else
      let selected = Hashtbl.create (List.length coords) in
      List.iter (fun (locus, _) -> Hashtbl.add selected locus ()) coords;
      let rec quantities total = function
        | [] -> Ok total
        | (locus, _) :: rest -> (
            match Book_display.quantity_value ~book ~measure locus with
            | Book_display.Exact n -> quantities (Z.add total n) rest
            | Book_display.Unsupported ->
                Error
                  (Printf.sprintf
                     "Selected coordinate %s (%s) has no supported current quantity; Liquidity \
                      never infers zero."
                     locus measure))
      in
      Result.bind (quantities Z.zero coords) (fun current_selected ->
          let rec changes acc = function
            | [] -> Ok acc
            | (plan : B.plan) :: rest ->
                let net =
                  if plan.measure <> measure then Z.zero
                  else
                    List.fold_left
                      (fun sum (locus, amount) ->
                        if Hashtbl.mem selected locus then Z.add sum amount else sum)
                      Z.zero plan.changes
                in
                if Z.equal net Z.zero then changes acc rest
                else if not (Day.is_valid plan.day) then
                  Error
                    (Printf.sprintf
                       "Selected Scheduled plan %s has an invalid due date; Liquidity refuses."
                       plan.id)
                else if String.compare plan.day today < 0 then
                  Error
                    (Printf.sprintf
                       "Selected Scheduled plan %s is overdue (%s before today %s); Liquidity \
                        refuses to move or settle it."
                       plan.id plan.day today)
                else if String.compare plan.day horizon > 0 then changes acc rest
                else changes ((plan.day, net) :: acc) rest
          in
          Result.map
            (fun dated ->
              let buckets = Hashtbl.create (List.length dated) in
              List.iter
                (fun (day, net) ->
                  let previous = Option.value ~default:Z.zero (Hashtbl.find_opt buckets day) in
                  Hashtbl.replace buckets day (Z.add previous net))
                dated;
              let changes =
                Hashtbl.fold (fun day net rows -> (day, net) :: rows) buckets []
                |> List.sort (fun (left, _) (right, _) -> String.compare left right)
              in
              let rec build running acc = function
                | [] -> List.rev acc
                | (date, scheduled_change) :: rest ->
                    let balance = Z.add running scheduled_change in
                    build balance ({ date; scheduled_change; balance } :: acc) rest
              in
              {
                as_of = today;
                assumed_complete_through = horizon;
                measure;
                current_selected;
                points = build current_selected [] changes;
              })
            (changes [] (B.open_plans book)))

let final_at_horizon snapshot =
  List.fold_left (fun _ (point : point) -> point.balance) snapshot.current_selected snapshot.points

let low_water snapshot =
  List.fold_left
    (fun low (point : point) -> if Z.compare point.balance low < 0 then point.balance else low)
    snapshot.current_selected snapshot.points

let render_lines ~book (snapshot : snapshot) =
  let measure = snapshot.measure in
  let header =
    [
      (O.Heading, "CONDITIONAL selected-balance outlook");
      (O.Plain, "As of: " ^ snapshot.as_of);
      ( O.Plain,
        Printf.sprintf "Assumption: no additional Scheduled items through %s"
          snapshot.assumed_complete_through );
      ( O.Plain,
        "Current selected balance: "
        ^ Book_display.format_money book measure snapshot.current_selected
        ^ " " ^ measure );
      (O.Chrome, "Selection is replaceable; this is not canonical liquidity.");
      ( O.Chrome,
        "Numbers are conditional on the explicit assumption; nothing is stored or evidence." );
      (O.Chrome, "Same-day changes are netted; no intraday ordering is claimed.");
      (O.Plain, "");
    ]
  in
  let path =
    match snapshot.points with
    | [] -> [ (O.Plain, "No selected Scheduled changes fall within the assumption date.") ]
    | points ->
        let shown = List.filteri (fun i _ -> i < display_point_rows) points in
        let rows =
          List.map
            (fun (point : point) ->
              ( O.Plain,
                Printf.sprintf "%s  Scheduled %s  -> %s %s" point.date
                  (signed book measure point.scheduled_change)
                  (Book_display.format_money book measure point.balance)
                  measure ))
            shown
        in
        let omitted = List.length points - List.length shown in
        rows
        @
        if omitted <= 0 then []
        else
          [
            ( O.Plain,
              Printf.sprintf "… %d later change point(s) omitted; totals include all points."
                omitted );
          ]
  in
  let totals =
    [
      (O.Plain, "");
      ( O.Heading,
        "Conditional balance at horizon: "
        ^ Book_display.format_money book measure (final_at_horizon snapshot)
        ^ " " ^ measure );
      ( O.Heading,
        "Conditional day-boundary low-water: "
        ^ Book_display.format_money book measure (low_water snapshot)
        ^ " " ^ measure );
    ]
  in
  header @ path @ totals
