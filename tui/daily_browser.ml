(* Pure browser component for ledger entries and plans.
   Independent state model, navigation actions, line formatting and selection.
   Usable both as a pure model and as an independent Bonsai component. *)
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module F = Daily_file

type view = Entries | Plans

type model = {
  view : view;
  entries_selected : int;
  plans_selected : int;
  entries_scroll_top : int;
  plans_scroll_top : int;
  selected_entry_id : string option;
  selected_plan_id : string option;
  plans_initialized : bool;
}

type action =
  | Select of int
  | Switch_view
  | Set_view of view
  | Reset_plans_selection

let initial = {
  view = Entries;
  entries_selected = 0;
  plans_selected = 0;
  entries_scroll_top = 0;
  plans_scroll_top = 0;
  selected_entry_id = None;
  selected_plan_id = None;
  plans_initialized = false;
}

let create ?(view = Entries) ?(entries_selected = 0) ?(plans_selected = 0)
    ?(entries_scroll_top = 0) ?(plans_scroll_top = 0) ?selected_entry_id
    ?selected_plan_id ?(plans_initialized = false) () =
  {
    view;
    entries_selected;
    plans_selected;
    entries_scroll_top;
    plans_scroll_top;
    selected_entry_id;
    selected_plan_id;
    plans_initialized;
  }

let is_cancelled (p : B.plan) = p.cancelled_on <> None
let is_paid (p : B.plan) = p.paid_by <> None
let is_closed (p : B.plan) = is_cancelled p || is_paid p
let is_open (p : B.plan) = not (is_closed p)

let plan_category ?(today = F.today ()) (p : B.plan) =
  if p.day < today then
    if is_closed p then 1
    else 2
  else 3

let compare_plans ?(today = F.today ()) (p1 : B.plan) (p2 : B.plan) =
  let c1 = plan_category ~today p1 in
  let c2 = plan_category ~today p2 in
  if c1 <> c2 then Int.compare c1 c2
  else
    let d = String.compare p1.day p2.day in
    if d <> 0 then d
    else
      let o1 = if is_open p1 then 0 else 1 in
      let o2 = if is_open p2 then 0 else 1 in
      if o1 <> o2 then Int.compare o1 o2
      else String.compare p1.id p2.id

let entries book = B.entries_rev book

let plans ?(today = F.today ()) book =
  List.sort (compare_plans ~today) (B.plans book)

let initial_plan_index ?(today = F.today ()) plans_list =
  let total = List.length plans_list in
  if total = 0 then 0
  else
    let find_first_index pred list =
      let rec loop i = function
        | [] -> None
        | x :: rest -> if pred x then Some i else loop (i + 1) rest
      in
      loop 0 list
    in
    match find_first_index (fun p -> plan_category ~today p = 2) plans_list with
    | Some idx -> idx
    | None -> (
        match find_first_index (fun p -> plan_category ~today p = 3 && is_open p) plans_list with
        | Some idx -> idx
        | None -> (
            match find_first_index (fun p -> plan_category ~today p = 3) plans_list with
            | Some idx -> idx
            | None -> (
                let rec find_last_closed last_idx cur_idx = function
                  | [] -> last_idx
                  | p :: rest ->
                      let next_last = if is_closed p then cur_idx else last_idx in
                      find_last_closed next_last (cur_idx + 1) rest
                in
                find_last_closed 0 0 plans_list)))

let adjust_scroll ~room ~selected scroll_top =
  if room <= 0 then 0
  else
    let selected = max 0 selected in
    let scroll_top = max 0 scroll_top in
    if selected < scroll_top then selected
    else if selected >= scroll_top + room then selected - room + 1
    else scroll_top

let find_plan_index_by_id id plans_list =
  let rec loop i = function
    | [] -> None
    | (p : B.plan) :: rest -> if p.id = id then Some i else loop (i + 1) rest
  in
  loop 0 plans_list

let find_entry_index_by_id id entries_list =
  let rec loop i = function
    | [] -> None
    | (e : B.entry) :: rest -> if e.id = id then Some i else loop (i + 1) rest
  in
  loop 0 entries_list

let selected_index model =
  match model.view with
  | Entries -> model.entries_selected
  | Plans -> model.plans_selected

let count ?today ~book model =
  match model.view with
  | Entries -> B.entry_count book
  | Plans -> List.length (plans ?today book)

let switch_to_view ?(today = F.today ()) ~book model view =
  match view with
  | Entries ->
      let len = B.entry_count book in
      let ent = entries book in
      let target_selected =
        match model.selected_entry_id with
        | Some id -> (
            match find_entry_index_by_id id ent with
            | Some idx -> idx
            | None -> min (max 0 (len - 1)) model.entries_selected)
        | None -> min (max 0 (len - 1)) model.entries_selected
      in
      let selected_entry_id =
        Option.map (fun (e : B.entry) -> e.id) (List.nth_opt ent target_selected)
      in
      { model with view = Entries; entries_selected = target_selected; selected_entry_id }
  | Plans ->
      let ps = plans ~today book in
      let len = List.length ps in
      if not model.plans_initialized then
        let init_idx = initial_plan_index ~today ps in
        let selected_plan_id =
          Option.map (fun (p : B.plan) -> p.id) (List.nth_opt ps init_idx)
        in
        {
          model with
          view = Plans;
          plans_selected = init_idx;
          plans_scroll_top = init_idx;
          selected_plan_id;
          plans_initialized = true;
        }
      else
        let target_selected =
          match model.selected_plan_id with
          | Some id -> (
              match find_plan_index_by_id id ps with
              | Some idx -> idx
              | None -> min (max 0 (len - 1)) model.plans_selected)
          | None -> min (max 0 (len - 1)) model.plans_selected
        in
        let selected_plan_id =
          Option.map (fun (p : B.plan) -> p.id) (List.nth_opt ps target_selected)
        in
        { model with view = Plans; plans_selected = target_selected; selected_plan_id }

let apply_action ?(today = F.today ()) ~book model = function
  | Select step ->
      let len = count ~today ~book model in
      let clamp cur = max 0 (min (max 0 (len - 1)) (cur + step)) in
      (match model.view with
       | Entries ->
           let next_sel = clamp model.entries_selected in
           let selected_entry_id =
             Option.map (fun (e : B.entry) -> e.id) (List.nth_opt (entries book) next_sel)
           in
           { model with entries_selected = next_sel; selected_entry_id }
       | Plans ->
           let next_sel = clamp model.plans_selected in
           let ps = plans ~today book in
           let selected_plan_id =
             Option.map (fun (p : B.plan) -> p.id) (List.nth_opt ps next_sel)
           in
           { model with plans_selected = next_sel; selected_plan_id })
  | Switch_view ->
      let next_view = match model.view with Entries -> Plans | Plans -> Entries in
      switch_to_view ~today ~book model next_view
  | Set_view view ->
      switch_to_view ~today ~book model view
  | Reset_plans_selection ->
      let ps = plans ~today book in
      let init_idx = initial_plan_index ~today ps in
      let selected_plan_id =
        Option.map (fun (p : B.plan) -> p.id) (List.nth_opt ps init_idx)
      in
      {
        model with
        plans_selected = init_idx;
        plans_scroll_top = init_idx;
        selected_plan_id;
        plans_initialized = true;
      }

let sync_selection ?(today = F.today ()) ~book model =
  let ent = entries book in
  let ps = plans ~today book in
  let entries_selected =
    match model.selected_entry_id with
    | Some id -> (
        match find_entry_index_by_id id ent with
        | Some idx -> idx
        | None -> min (max 0 (List.length ent - 1)) model.entries_selected)
    | None -> min (max 0 (List.length ent - 1)) model.entries_selected
  in
  let plans_selected, plans_scroll_top, plans_initialized =
    if not model.plans_initialized then
      let init_idx = initial_plan_index ~today ps in
      (init_idx, init_idx, model.plans_initialized)
    else
      let next_sel =
        match model.selected_plan_id with
        | Some id -> (
            match find_plan_index_by_id id ps with
            | Some idx -> idx
            | None -> min (max 0 (List.length ps - 1)) model.plans_selected)
        | None -> min (max 0 (List.length ps - 1)) model.plans_selected
      in
      (next_sel, model.plans_scroll_top, model.plans_initialized)
  in
  let selected_entry_id =
    Option.map (fun (e : B.entry) -> e.id) (List.nth_opt ent entries_selected)
  in
  let selected_plan_id =
    Option.map (fun (p : B.plan) -> p.id) (List.nth_opt ps plans_selected)
  in
  {
    model with
    entries_selected;
    plans_selected;
    plans_scroll_top;
    selected_entry_id;
    selected_plan_id;
    plans_initialized;
  }

let posting_text book p =
  let locus = D.Identifier.Locus.to_string (D.Effect.locus p) in
  let measure = D.Identifier.Measure.to_string (D.Effect.measure p) in
  let quanta = D.Quantity.quanta (D.Effect.quantity p) in
  B.label book locus ^ ":" ^ B.format book measure quanta ^ " " ^ measure

let entry_text book (e : B.entry) =
  let content =
    match e.effects with
    | [ e1; e2 ] ->
        let q1 = D.Quantity.quanta (D.Effect.quantity e1) in
        let q2 = D.Quantity.quanta (D.Effect.quantity e2) in
        if Z.sign q1 < 0 && Z.sign q2 > 0 then
          let l1 = B.label book (D.Identifier.Locus.to_string (D.Effect.locus e1)) in
          let l2 = B.label book (D.Identifier.Locus.to_string (D.Effect.locus e2)) in
          let m = D.Identifier.Measure.to_string (D.Effect.measure e2) in
          Printf.sprintf "%s → %s  %s %s" l1 l2 (B.format book m q2) m
        else if Z.sign q2 < 0 && Z.sign q1 > 0 then
          let l1 = B.label book (D.Identifier.Locus.to_string (D.Effect.locus e1)) in
          let l2 = B.label book (D.Identifier.Locus.to_string (D.Effect.locus e2)) in
          let m = D.Identifier.Measure.to_string (D.Effect.measure e1) in
          Printf.sprintf "%s → %s  %s %s" l2 l1 (B.format book m q1) m
        else
          String.concat " / " (List.map (posting_text book) e.effects)
    | _ ->
        String.concat " / " (List.map (posting_text book) e.effects)
  in
  let memo_str = match e.memo with None -> "" | Some text -> "  " ^ text in
  let tag_str =
    if e.reversal_of <> None then " [返金・取消対応]"
    else if e.exchange <> None then " [両替]"
    else ""
  in
  Printf.sprintf "%s  %s%s%s" e.day content memo_str tag_str

let plan_status_label ?(today = F.today ()) (p : B.plan) =
  match p.cancelled_on with
  | Some day -> "[取消 " ^ day ^ "]"
  | None ->
      if p.paid_by <> None then "[支払済]"
      else if p.day < today then "[期限超過]"
      else if p.day = today then "[本日]"
      else "[未払い]"

let plan_text ?(today = F.today ()) book (p : B.plan) =
  let status = plan_status_label ~today p in
  let changes_str =
    String.concat " / "
      (List.map
         (fun (loc, n) ->
           B.label book loc ^ ":"
           ^ B.format book p.measure n
           ^ " " ^ p.measure)
         p.changes)
  in
  p.day ^ " " ^ status ^ " " ^ p.id ^ "  " ^ changes_str

let history_lines ?(today = F.today ()) ~book model =
  match model.view with
  | Entries -> List.map (entry_text book) (entries book)
  | Plans -> List.map (plan_text ~today book) (plans ~today book)

(* Skip without copying; collect only the requested rows in display order. *)
let take_slice ~drop ~count rows =
  let rec take left acc = function
    | _ when left <= 0 -> List.rev acc
    | [] -> List.rev acc
    | row :: rest -> take (left - 1) (row :: acc) rest
  in
  let rec skip left = function
    | rows when left <= 0 -> take count [] rows
    | [] -> []
    | _ :: rest -> skip (left - 1) rest
  in
  skip drop rows

let visible_slice ?(today = F.today ()) ~book model ~room =
  if room <= 0 then []
  else
    match model.view with
    | Entries ->
        let scroll_top =
          adjust_scroll ~room ~selected:model.entries_selected model.entries_scroll_top
        in
        let rows = B.entries_rev book in
        let slice = take_slice ~drop:scroll_top ~count:room rows in
        List.mapi (fun offset row -> (scroll_top + offset, entry_text book row)) slice
    | Plans ->
        let scroll_top =
          adjust_scroll ~room ~selected:model.plans_selected model.plans_scroll_top
        in
        let rows = plans ~today book in
        let slice = take_slice ~drop:scroll_top ~count:room rows in
        List.mapi (fun offset row -> (scroll_top + offset, plan_text ~today book row)) slice

let selected_entry ~book model =
  match model.view with
  | Entries -> List.nth_opt (entries book) model.entries_selected
  | Plans -> None

let selected_plan ?(today = F.today ()) ~book model =
  match model.view with
  | Plans -> List.nth_opt (plans ~today book) model.plans_selected
  | Entries -> None
