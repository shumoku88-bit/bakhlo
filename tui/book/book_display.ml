(* How book values read on screen: exact quantities and grouped amounts, Locus
   candidates, and the detail lines of Actual entries, Scheduled plans and Previews.
   Read-only; nothing here publishes. *)
module B = Bakhlo_household.Book
module D = Bakhlo_domain
module A = Draft

let tr = Ui_text.tr
let visible = Ui_render.visible

type quantity_value = Unsupported | Exact of Z.t

let quantity_value ~book ~measure locus =
  match B.quantity book ~locus ~measure with Some q -> Exact q.amount | None -> Unsupported

let quantity ~book ~measure locus =
  match quantity_value ~book ~measure locus with
  | Unsupported -> tr "Unknown"
  | Exact n -> B.format book measure n

let format_money book measure q =
  let raw = B.format book measure q in
  let negative = String.starts_with ~prefix:"-" raw in
  let start = if negative then 1 else 0 in
  let stop = Option.value ~default:(String.length raw) (String.index_opt raw '.') in
  let out = Buffer.create (String.length raw + ((stop - start) / 3)) in
  if negative then Buffer.add_char out '-';
  for i = start to stop - 1 do
    if i > start && (stop - i) mod 3 = 0 then Buffer.add_char out ',';
    Buffer.add_char out raw.[i]
  done;
  Buffer.add_substring out raw stop (String.length raw - stop);
  Buffer.contents out

let locus_candidates book query =
  let query = String.lowercase_ascii (String.trim query) in
  let choices = Option.value ~default:[] (B.approved_loci book) in
  if query = "" then choices
  else
    let is_prefix text = Base.String.is_prefix (String.lowercase_ascii text) ~prefix:query in
    let matches = List.filter (fun id -> is_prefix id || is_prefix (B.label book id)) choices in
    let exact, rest = List.partition (fun id -> String.lowercase_ascii id = query) matches in
    exact @ rest

let signed book measure amount =
  (if Z.sign amount > 0 then "+" else "") ^ B.format book measure amount ^ " " ^ measure

let entry_lines book (entry : B.entry) =
  [ tr "Effects (exact quantities):" ]
  @ List.concat
      (List.mapi
         (fun n (p : B.posting) ->
           let locus = p.B.locus and measure = p.B.measure in
           [
             Ui_text.format_message "Posting %d: %s [%s]" (n + 1)
               (visible (B.label book locus))
               (visible locus);
             ("  " ^ signed book measure p.B.amount
             ^ match p.B.key with None -> "" | Some key -> " / " ^ tr "Key:" ^ " " ^ visible key);
           ])
         entry.effects)
  @ [
      "";
      (tr "Description:" ^ " "
      ^ match entry.memo with None -> tr "(no description)" | Some text -> visible text);
      tr "Date:" ^ " " ^ entry.day;
      "ID: " ^ visible entry.id;
    ]
  @ (match entry.original_amount with
    | None -> []
    | Some (m, q) -> [ tr "Original amount:" ^ " " ^ B.format book m q ^ " " ^ visible m ])
  @ (match entry.reversal_of with
    | None -> []
    | Some id -> [ tr "Reversal of:" ^ " " ^ visible id ])
  @ [
      (tr "Merchant:" ^ " "
      ^
      match entry.merchant with
      | None -> tr "Unresolved"
      | Some Nonmerchant -> tr "Nonmerchant"
      | Some (Merchant p) -> tr "Merchant " ^ visible (D.Identifier.External_party.to_string p));
    ]
  @ (match entry.exchange with
    | None -> []
    | Some (a, b) -> [ tr "Exchange keys:" ^ " " ^ visible a ^ " → " ^ visible b ])
  @ (B.plans book
    |> List.filter_map (fun (p : B.plan) ->
        if p.paid_by = Some entry.id then
          Some (tr "Completed Scheduled:" ^ " " ^ visible p.id ^ " / " ^ p.day)
        else None))

let plan_lines book (plan : B.plan) =
  [ tr "Expected Effects (exact quantities):" ]
  @ List.mapi
      (fun n (locus, amount) ->
        Ui_text.format_message "Posting %d: %s [%s]  %s" (n + 1)
          (visible (B.label book locus))
          (visible locus) (signed book plan.measure amount))
      plan.changes
  @ [ "Due: " ^ plan.day; "ID: " ^ visible plan.id; "Measure: " ^ visible plan.measure ]
  @
  match (plan.cancelled_on, plan.paid_by) with
  | Some day, _ -> [ tr "Cancelled on:" ^ " " ^ day ]
  | None, Some id -> [ tr "Completed by Actual:" ^ " " ^ visible id ]
  | None, None -> [ tr "Open Scheduled occurrence" ]

let preview_lines book (transaction : A.transaction) =
  (match transaction.plan with
    | Some id -> (
        [
          tr "Complete Scheduled:" ^ " " ^ visible id;
          tr "Actual and completion link publish together.";
        ]
        @
        match List.find_opt (fun (p : B.plan) -> p.id = id) (B.plans book) with
        | None -> []
        | Some p -> [ tr "Original due date (kept):" ^ " " ^ p.day ])
    | None ->
        [
          (if transaction.replace then tr "Correct Actual (same ID)" else tr "Record new Movement");
        ])
  @ entry_lines book transaction.entry
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
      [ tr "Balanced total:" ^ " " ^ B.format book measure total ^ " " ^ measure ]

let plan_preview_lines book ~replace (plan : B.plan) =
  [ (if replace then tr "Edit Scheduled (same ID)" else tr "Create new Scheduled") ]
  @ plan_lines book plan
  @
  let total =
    List.fold_left
      (fun n (_, value) -> if Z.sign value > 0 then Z.add n value else n)
      Z.zero plan.changes
  in
  [ tr "Balanced total:" ^ " " ^ B.format book plan.measure total ^ " " ^ plan.measure ]
