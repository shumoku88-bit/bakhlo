(* Pure browser component for ledger entries and plans.
   Independent state model, navigation actions, line formatting and selection.
   Usable both as a pure model and as an independent Bonsai component. *)
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain

type view = Entries | Plans

type model = {
  view : view;
  entries_selected : int;
  plans_selected : int;
}

type action =
  | Select of int
  | Switch_view
  | Set_view of view

let initial = {
  view = Entries;
  entries_selected = 0;
  plans_selected = 0;
}

let entries book = List.rev (B.entries book)
let plans book = B.plans book

let selected_index model =
  match model.view with
  | Entries -> model.entries_selected
  | Plans -> model.plans_selected

let count ~book model =
  match model.view with
  | Entries -> List.length (B.entries book)
  | Plans -> List.length (plans book)

let apply_action ~book model = function
  | Select step ->
      let len = count ~book model in
      let clamp cur = max 0 (min (max 0 (len - 1)) (cur + step)) in
      (match model.view with
       | Entries -> { model with entries_selected = clamp model.entries_selected }
       | Plans -> { model with plans_selected = clamp model.plans_selected })
  | Switch_view ->
      let view = match model.view with Entries -> Plans | Plans -> Entries in
      let len = match view with
        | Entries -> List.length (B.entries book)
        | Plans -> List.length (plans book)
      in
      let target_selected = match view with
        | Entries -> min (max 0 (len - 1)) model.entries_selected
        | Plans -> min (max 0 (len - 1)) model.plans_selected
      in
      (match view with
       | Entries -> { model with view; entries_selected = target_selected }
       | Plans -> { model with view; plans_selected = target_selected })
  | Set_view view ->
      let len = match view with
        | Entries -> List.length (B.entries book)
        | Plans -> List.length (plans book)
      in
      let target_selected = match view with
        | Entries -> min (max 0 (len - 1)) model.entries_selected
        | Plans -> min (max 0 (len - 1)) model.plans_selected
      in
      (match view with
       | Entries -> { model with view; entries_selected = target_selected }
       | Plans -> { model with view; plans_selected = target_selected })

let posting_text book p =
  let locus = D.Identifier.Locus.to_string (D.Effect.locus p) in
  let measure = D.Identifier.Measure.to_string (D.Effect.measure p) in
  let quanta = D.Quantity.quanta (D.Effect.quantity p) in
  B.label book locus ^ ":" ^ B.format book measure quanta ^ " " ^ measure

let entry_text book (e : B.entry) =
  e.day ^ " "
  ^ String.concat " / " (List.map (posting_text book) e.effects)
  ^ (match e.memo with None -> "" | Some text -> "  " ^ text)
  ^ (if e.reversal_of <> None then " [返金・取消対応]" else if e.exchange <> None then " [両替]" else "")

let plan_text book (p : B.plan) =
  p.day ^ " "
  ^ (match p.cancelled_on with
    | Some day -> "[取消 " ^ day ^ "] "
    | None -> if p.paid_by = None then "[未払い] " else "[支払い済] ")
  ^ String.concat " / "
      (List.map
         (fun (loc, n) ->
           B.label book loc ^ ":"
           ^ B.format book p.measure n
           ^ " " ^ p.measure)
         p.changes)

let history_lines ~book model =
  match model.view with
  | Entries -> List.map (entry_text book) (entries book)
  | Plans -> List.map (plan_text book) (plans book)

let visible_slice ~book model ~room =
  let lines = history_lines ~book model in
  let selected = selected_index model in
  let start = max 0 (selected - room + 1) in
  lines
  |> List.mapi (fun n text -> (n, text))
  |> List.filter (fun (n, _) -> n >= start && n < start + room)

let selected_entry ~book model =
  match model.view with
  | Entries -> List.nth_opt (entries book) model.entries_selected
  | Plans -> None

let selected_plan ~book model =
  match model.view with
  | Plans -> List.nth_opt (plans book) model.plans_selected
  | Entries -> None
