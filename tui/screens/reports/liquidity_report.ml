(* Liquidity: CONDITIONAL selected-balance path under one explicit assumption.
   Unlike Daily Pace this keeps future conditional inflows and refuses overdue
   selected changes; it never claims a forecast path or a known low-water mark. *)
module B = Bakhlo_household.Book
module L = Bakhlo_household.Liquidity
module O = Ui_render
module A = Draft

let display_point_rows = 12

let signed book measure n =
  (if Z.sign n > 0 then "+" else "") ^ Book_display.format_money book measure n

let render_lines ~book (snapshot : L.snapshot) =
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
            (fun (point : L.point) ->
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
        ^ Book_display.format_money book measure (L.final_at_horizon snapshot)
        ^ " " ^ measure );
      ( O.Heading,
        "Conditional day-boundary low-water: "
        ^ Book_display.format_money book measure (L.low_water snapshot)
        ^ " " ^ measure );
    ]
  in
  header @ path @ totals
