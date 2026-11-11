(* The detail lines of Actual entries, Scheduled plans and Previews on screen, over
   Book_display (cli/), which owns quantities, grouped amounts and Locus candidates.
   Read-only; nothing here publishes. *)
module B = Bakhlo_household.Book
module O = Ui_render

let tr = Ui_text.tr
let visible = Ui_render.visible

let quantity ~book ~measure locus =
  match Book_display.quantity_value ~book ~measure locus with
  | Book_display.Unsupported -> tr "Unknown"
  | Exact n -> B.format book measure n

let signed book measure amount =
  (if Z.sign amount > 0 then "+" else "") ^ B.format book measure amount ^ " " ^ measure

(* Preview's hierarchy comes from the book fields, never from parsing a memo or
   a printed label. Detail callers still take the same text without these styles. *)
let entry_rows book (entry : B.entry) =
  [ (O.Chrome, tr "Effects (exact quantities):") ]
  @ List.concat
      (List.mapi
         (fun n (p : B.posting) ->
           let locus = p.B.locus and measure = p.B.measure in
           [
             ( O.Plain,
               Ui_text.format_message "Posting %d: %s [%s]" (n + 1)
                 (visible (B.label book locus))
                 (visible locus) );
             ( O.Heading,
               "  " ^ signed book measure p.B.amount
               ^ match p.B.key with None -> "" | Some key -> " / " ^ tr "Key:" ^ " " ^ visible key
             );
           ])
         entry.effects)
  @ [
      (O.Plain, "");
      ( O.Plain,
        tr "Description:" ^ " "
        ^ match entry.memo with None -> tr "(no description)" | Some text -> visible text );
      (O.Heading, tr "Date:" ^ " " ^ entry.day);
      (O.Chrome, "ID: " ^ visible entry.id);
    ]
  @ (match entry.original_amount with
    | None -> []
    | Some (m, q) ->
        [ (O.Heading, tr "Original amount:" ^ " " ^ B.format book m q ^ " " ^ visible m) ])
  @ (match entry.reversal_of with
    | None -> []
    | Some id -> [ (O.Plain, tr "Reversal of:" ^ " " ^ visible id) ])
  @ [
      ( O.Plain,
        tr "Merchant:" ^ " "
        ^
        match entry.merchant with
        | None -> tr "Unresolved"
        | Some Nonmerchant -> tr "Nonmerchant"
        | Some (Merchant p) -> tr "Merchant " ^ visible p );
    ]
  @ (match entry.exchange with
    | None -> []
    | Some (a, b) -> [ (O.Plain, tr "Exchange keys:" ^ " " ^ visible a ^ " → " ^ visible b) ])
  @ (B.plans book
    |> List.filter_map (fun (p : B.plan) ->
        if p.paid_by = Some entry.id then
          Some (O.Plain, tr "Completed Scheduled:" ^ " " ^ visible p.id ^ " / " ^ p.day)
        else None))

let entry_lines book entry = List.map snd (entry_rows book entry)

let plan_rows book (plan : B.plan) =
  [ (O.Chrome, tr "Expected Effects (exact quantities):") ]
  @ List.mapi
      (fun n (locus, amount) ->
        ( O.Heading,
          Ui_text.format_message "Posting %d: %s [%s]  %s" (n + 1)
            (visible (B.label book locus))
            (visible locus) (signed book plan.measure amount) ))
      plan.changes
  @ [
      (O.Heading, "Due: " ^ plan.day);
      (O.Chrome, "ID: " ^ visible plan.id);
      (O.Chrome, "Measure: " ^ visible plan.measure);
    ]
  @
  match (plan.cancelled_on, plan.paid_by) with
  | Some day, _ -> [ (O.Plain, tr "Cancelled on:" ^ " " ^ day) ]
  | None, Some id -> [ (O.Plain, tr "Completed by Actual:" ^ " " ^ visible id) ]
  | None, None -> [ (O.Plain, tr "Open Scheduled occurrence") ]

let plan_lines book plan = List.map snd (plan_rows book plan)

let preview_rows book (transaction : Bakhlo_household.Record.transaction) =
  (match transaction.plan with
    | Some id -> (
        [
          (O.Plain, tr "Complete Scheduled:" ^ " " ^ visible id);
          (O.Plain, tr "Actual and completion link publish together.");
        ]
        @
        match List.find_opt (fun (p : B.plan) -> p.id = id) (B.plans book) with
        | None -> []
        | Some p -> [ (O.Heading, tr "Original due date (kept):" ^ " " ^ p.day) ])
    | None ->
        [
          ( O.Plain,
            if transaction.replace then tr "Correct Actual (same ID)" else tr "Record new Movement"
          );
        ])
  @ entry_rows book transaction.entry
  @
  match transaction.entry.effects with
  | [] -> []
  | first :: _ ->
      let measure = first.B.measure in
      let total =
        List.fold_left
          (fun n posting ->
            let value = posting.B.amount in
            if Z.sign value > 0 then Z.add n value else n)
          Z.zero transaction.entry.effects
      in
      [ (O.Heading, tr "Balanced total:" ^ " " ^ B.format book measure total ^ " " ^ measure) ]

let plan_preview_rows book ~replace (plan : B.plan) =
  [ (O.Plain, if replace then tr "Edit Scheduled (same ID)" else tr "Create new Scheduled") ]
  @ plan_rows book plan
  @
  let total =
    List.fold_left
      (fun n (_, value) -> if Z.sign value > 0 then Z.add n value else n)
      Z.zero plan.changes
  in
  [
    (O.Heading, tr "Balanced total:" ^ " " ^ B.format book plan.measure total ^ " " ^ plan.measure);
  ]
