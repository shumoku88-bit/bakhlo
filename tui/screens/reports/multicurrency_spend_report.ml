(* Multicurrency Spend: one explicit half-open Actual window kept as separate
   exact families. Current entry evidence is read directly; no FX rate,
   valuation, home currency or cross-Measure arithmetic is inferred. *)
module B = Bakhlo_household.Book
module MS = Bakhlo_household.Multicurrency_spend
module O = Ui_render
module A = Draft

let amount book measure quanta = Book_display.format_money book measure quanta ^ " " ^ measure

let signed_amount book measure quanta =
  (if Z.sign quanta > 0 then "+" else "") ^ amount book measure quanta

let reason_text = function
  | MS.Unresolved_roles -> "roles unresolved"
  | Exchange_event -> "exchange event"
  | No_positive_expense -> "no positive Expense Effect"

let effect_line book label (posting : B.posting) =
  let measure = posting.B.measure in
  let key = match posting.B.key with None -> "" | Some key -> "  key " ^ key in
  "  " ^ label ^ "  " ^ signed_amount book measure posting.B.amount ^ "  " ^ posting.B.locus ^ key

let render_lines ~book (snapshot : MS.snapshot) =
  let total_lines heading empty_text rows =
    (O.Heading, heading)
    ::
    (match rows with
    | [] -> [ (O.Chrome, "  " ^ empty_text) ]
    | rows ->
        List.map (fun (row : MS.total) -> (O.Plain, "  " ^ amount book row.measure row.quanta)) rows)
  in
  let occurrence_lines (occurrence : MS.exchange_occurrence) =
    let description = match occurrence.description with None -> "" | Some text -> "  " ^ text in
    (O.Plain, occurrence.date ^ description ^ "  [" ^ occurrence.event ^ "]")
    :: (O.Plain, effect_line book "source" occurrence.source)
    :: (O.Plain, effect_line book "destination" occurrence.destination)
    ::
    (match occurrence.extra_effects with
    | [] -> []
    | extras ->
        (O.Chrome, "  extra Effects")
        :: List.map (fun posting -> (O.Plain, effect_line book "extra" posting)) extras)
  in
  let unresolved_lines heading rows =
    (O.Heading, Printf.sprintf "%s: %d" heading (List.length rows))
    :: List.map
         (fun (row : MS.unresolved_effect) ->
           ( O.Plain,
             "? " ^ row.date ^ "  " ^ row.posting.B.locus ^ "  "
             ^ signed_amount book row.posting.B.measure row.posting.B.amount
             ^ "  [" ^ row.event ^ "]" ))
         rows
  in
  let witness_lines heading rows =
    (O.Heading, Printf.sprintf "%s: %d" heading (List.length rows))
    :: List.map
         (fun (row : MS.original_witness) ->
           ( O.Plain,
             "? " ^ row.date ^ "  original "
             ^ amount book row.measure row.quanta
             ^ "  [" ^ row.event ^ "]  " ^ reason_text row.reason ))
         rows
  in
  [
    (O.Heading, "Multicurrency Spend");
    (O.Chrome, Printf.sprintf "Window [%s, %s)" snapshot.start_day snapshot.end_exclusive);
    ( O.Chrome,
      "Distinct Measures remain separate. No FX rate, valuation, or home currency is inferred." );
    (O.Chrome, "This is a read lens over existing evidence, not a Trip transaction type.");
    (O.Plain, "");
  ]
  @ total_lines "Ordinary accounting Expense" "No classified ordinary Expense in this window."
      snapshot.ordinary_expense
  @ [ (O.Plain, "") ]
  @ total_lines "Original presented Expense" "No qualified OriginalAmount evidence in this window."
      snapshot.original_expense
  @ [ (O.Plain, "") ]
  @ total_lines "Exchange-associated Expense" "No classified Expense attached to Exchange Events."
      snapshot.exchange_expense
  @ [ (O.Plain, ""); (O.Heading, "Exchange occurrences") ]
  @ (match snapshot.exchanges with
    | [] -> [ (O.Chrome, "  No qualified Exchange Event in this window.") ]
    | exchanges -> List.concat_map occurrence_lines exchanges)
  @ [ (O.Plain, "") ]
  @ unresolved_lines "Unresolved ordinary Effects" snapshot.unresolved_ordinary
  @ unresolved_lines "Unresolved exchange Effects" snapshot.unresolved_exchange
  @ witness_lines "Unresolved original amounts" snapshot.unresolved_original
  @ witness_lines "Non-counted original observations" snapshot.uncounted_original
  @ (if snapshot.unresolved_ordinary = [] && snapshot.unresolved_exchange = [] then []
     else
       [
         ( O.Status,
           "Unresolved role evidence exists: classified figures above are not a complete spending \
            total." );
       ])
  @ [
      (O.Chrome, "Exchange quantities are evidence of the exchange occurrence, not spending totals.");
      ( O.Chrome,
        "Original presented amounts remain observations; they are not converted into accounting \
         Measure." );
    ]
