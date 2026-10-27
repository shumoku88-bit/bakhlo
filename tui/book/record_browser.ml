(* A browsable list of Actual entries and Scheduled plans: text / Locus / day
   filters, order, and a selection that follows the stable record identity. *)
module B = Bakhlo_household.Daily_book
module A = Daily_draft

type family = Actual_row | Scheduled_row
type row = Actual_entry of B.entry | Scheduled_plan of B.plan
type order = Newest | Oldest

type t = {
  selected : int;
  selected_id : (family * string) option;
  query : string;
  locus : string option;
  day : string option;
  order : order;
}

let empty =
  { selected = 0; selected_id = None; query = ""; locus = None; day = None; order = Newest }

let identity = function
  | Actual_entry e -> (Actual_row, e.B.id)
  | Scheduled_plan p -> (Scheduled_row, p.B.id)

let date = function Actual_entry e -> e.B.day | Scheduled_plan p -> p.B.day

let matches ~book t row =
  let day = date row in
  let loci =
    match row with
    | Actual_entry e -> List.map (fun p -> A.lstr (Bakhlo_domain.Effect.locus p)) e.effects
    | Scheduled_plan p -> List.map fst p.changes
  in
  (match t.day with None -> true | Some d -> day = d)
  && (match t.locus with None -> true | Some id -> List.mem id loci)
  && (t.query = ""
     ||
     let text =
       match row with
       | Actual_entry e -> day ^ " " ^ e.id ^ " " ^ Option.value ~default:"" e.memo ^ " "
       | Scheduled_plan p -> day ^ " " ^ p.id ^ " "
     in
     let text = text ^ String.concat " " (List.map (fun id -> id ^ " " ^ B.label book id) loci) in
     Base.String.is_substring (String.lowercase_ascii text)
       ~substring:(String.lowercase_ascii t.query))

let all_rows book =
  List.map (fun e -> Actual_entry e) (B.entries book)
  @ List.map (fun p -> Scheduled_plan p) (B.open_plans book)

let sorted order rows =
  List.sort
    (fun a b ->
      let compare_day = String.compare (date a) (date b) in
      let comparison = if compare_day = 0 then compare (identity a) (identity b) else compare_day in
      match order with Newest -> -comparison | Oldest -> comparison)
    rows

let visible ~book t candidates = candidates |> List.filter (matches ~book t) |> sorted t.order

(* Re-select the remembered identity in [rows], clamping when it is gone. *)
let sync t rows =
  let selected =
    match t.selected_id with
    | None -> t.selected
    | Some wanted ->
        let rec find i = function
          | [] -> t.selected
          | row :: rest -> if wanted = identity row then i else find (i + 1) rest
        in
        find 0 rows
  in
  let selected = max 0 (min (max 0 (List.length rows - 1)) selected) in
  { t with selected; selected_id = Option.map identity (List.nth_opt rows selected) }

let selected_row t rows = List.nth_opt rows t.selected

let move t rows delta =
  let last = max 0 (List.length rows - 1) in
  let current = max 0 (min last t.selected) in
  let selected =
    if delta > 0 then current + min delta (last - current)
    else if delta < -current then 0
    else current + delta
  in
  { t with selected; selected_id = Option.map identity (List.nth_opt rows selected) }

let reset t = { t with selected = 0; selected_id = None }

let cycle_order t =
  reset { t with order = (match t.order with Newest -> Oldest | Oldest -> Newest) }

let with_query t query = reset { t with query }
let with_locus t locus = reset { t with locus }

let toggle_day t ~focus_day =
  reset { t with day = (match t.day with None -> Some focus_day | Some _ -> None) }

(* The search pane shared by Selected Day and Scheduled, editing [value]. *)
let search_overlay ~width_of ~screen ~body:((body_w, _) as body) value =
  Ui_overlay.form ~width_of ~screen ~body
    ~pane_width:(min 54 (max 8 (body_w - 4)))
    (Ui_form.create ~id:"search"
       ~title:(Ui_text.tr "Search Actual / Scheduled")
       ~fields:[ Ui_form.text_field ~id:"value" ~label:"" ~value () ]
       ~notice:(Ui_text.tr "Enter apply; Esc clear")
       ())
