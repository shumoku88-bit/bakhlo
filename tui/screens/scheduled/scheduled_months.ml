module B = Bakhlo_sexp.Daily_book
module O = Daily_overlays
module C = Daily_calendar
module P = Ui_panel

type t = { floor : int; ordinal : int; first : string }

let month day =
  match C.parts day with
  | Error _ as error -> error
  | Ok (year, month, _) ->
      Ok (Printf.sprintf "%04d-%02d-01" year month, (year - 1) * 12 + month - 1)

let create ~today =
  match month today with
  | Error _ as error -> error
  | Ok (first, ordinal) -> Ok { floor = ordinal; ordinal; first }

let first_month t = t.first

let shift t delta =
  if delta < t.floor - t.ordinal then Error "Already at the current calendar month."
  else if delta > (9999 * 12 - 1) - t.ordinal then Error "Month is outside 0001–9999."
  else
    match C.shift_months t.first delta with
    | Error _ as error -> error
    | Ok first -> Ok { t with first; ordinal = t.ordinal + delta }

let follow t day =
  match month day with
  | Error _ -> t
  | Ok (_, selected) ->
      let target =
        if selected < t.floor then t.floor
        else if selected < t.ordinal then selected
        else if selected >= t.ordinal + 6 then selected - 5
        else t.ordinal
      in
      match shift t (target - t.ordinal) with Ok t -> t | Error _ -> t

let visible_months t =
  let rec collect offset =
    if offset = 6 then []
    else match C.shift_months t.first offset with
      | Error _ -> []
      | Ok day -> day :: collect (offset + 1)
  in
  collect 0

let selected_index selected plans =
  match selected with
  | None -> None
  | Some (selected : B.plan) ->
      List.find_index (fun (plan : B.plan) -> plan.id = selected.id) plans

let shape (plan : B.plan) =
  let loci sign = plan.changes |> List.filter_map (fun (locus, amount) ->
    if Z.sign amount = sign then Some locus else None) |> String.concat "," in
  loci (-1) ^ " -> " ^ loci 1

let quantity book (plan : B.plan) =
  let negative = List.filter (fun (_, amount) -> Z.sign amount < 0) plan.changes in
  let positive = List.filter (fun (_, amount) -> Z.sign amount > 0) plan.changes in
  match negative, positive with
  | [_], [(_, amount)] -> B.format book plan.measure amount ^ " " ^ plan.measure
  | _ -> Printf.sprintf "split (%d)" (List.length plan.changes)

let month_card ~book ~plans ~width_of ~width ~height ~selected month =
  let plans = List.filter (fun (plan : B.plan) ->
    String.sub plan.day 0 7 = String.sub month 0 7) plans in
  let index = selected_index selected plans in
  let quantities = List.map (quantity book) plans in
  let content_width = max 0 (width - 2) in
  let quantity_width = min (max 0 (content_width - 16))
    (min 22 (max 12 (List.fold_left (fun n value -> max n (width_of (O.visible value))) 0 quantities))) in
  let shape_width = max 0 (content_width - 8 - quantity_width) in
  let capacity = P.capacity ~height ~heading:false in
  let start = match index with
    | None -> 0
    | Some i -> min (max 0 (List.length plans - capacity)) (max 0 (i - capacity / 2)) in
  let rows = List.map2 (fun (plan : B.plan) quantity ->
    let quantity = O.visible quantity in
    let quantity = if width_of quantity > quantity_width then "too wide" else quantity in
    let active = match selected with Some p -> p.B.id = plan.id | None -> false in
    let marker = if active then "> " else "  " in
    (if active then O.Active else O.Plain),
    marker ^ String.sub plan.day 8 2 ^ "  " ^ O.pad ~width_of shape_width (shape plan) ^ "  "
    ^ O.pad_left ~width_of quantity_width quantity) plans quantities
    |> List.filteri (fun i _ -> i >= start && i - start < capacity) in
  let count = List.length plans in
  let more = (if start > 0 then " ▲" else "")
    ^ (if start + capacity < count then " ▼" else "") in
  P.frame_rows ~inset:0 ~width_of ~width ~height ~focused:(index <> None)
    ~title:(String.sub month 0 7) ~bottom_label:(Printf.sprintf "%d explicit%s" count more)
    (if count = 0 then [O.Chrome, " No explicit plan"] else rows)

let board ~book ~plans ~width_of ~width ~height ~selected months =
  let left_width = (width - 1) / 2 in
  let right_width = width - left_width - 1 in
  let card_height = height / 3 in
  let card width = function
    | None -> List.init card_height (fun _ -> O.Plain, "")
    | Some month -> month_card ~book ~plans ~width_of ~width ~height:card_height ~selected month in
  let rec pairs row months =
    if row = 3 then []
    else
      let left, right, rest = match months with
        | left :: right :: rest -> Some left, Some right, rest
        | [left] -> Some left, None, []
        | [] -> None, None, [] in
      List.map2 (fun (left_style, left) (right_style, right) ->
        O.Columns (left_width, left_style, right_style),
        O.pad ~width_of left_width left ^ " " ^ O.pad ~width_of right_width right)
        (card left_width left) (card right_width right)
      @ pairs (row + 1) rest
  in
  pairs 0 months @ List.init (height mod 3) (fun _ -> O.Plain, "")

let screen ~book ~plans ~dimensions:(width, height) ~width_of ~selected t =
  let width = max 0 width and height = max 0 height in
  if width = 0 || height = 0 then []
  else
    let months = visible_months t in
    let context_height = if height >= 4 then 1 else 0 in
    let available = height - context_height in
    let context =
      let last = List.fold_left (fun _ month -> month) t.first months in
      [O.Chrome, String.sub t.first 0 7 ^ " .. " ^ String.sub last 0 7
         ^ " | no completeness horizon claimed"]
      |> List.filteri (fun i _ -> i < context_height)
      |> List.map (fun (style, text) -> style, O.clip_text ~width_of width text) in
    let can_show_board = width >= 80 && available >= 9 in
    let detail_room =
      if width <= 6 then 0
      else if can_show_board then available - 9 else available / 2 in
    let detail_content =
      if detail_room < 3 then [] else
        (match selected with
         | None -> ["No Scheduled occurrence selected."]
         | Some plan -> O.plan_lines book plan)
        |> List.concat_map (O.wrap_text ~width_of (width - 2))
        |> List.map (fun text -> O.Plain, text) in
    let detail_height = if detail_room >= 3 then min 8 detail_room else 0 in
    let board_height = available - detail_height in
    let surface =
      if can_show_board then
        board ~book ~plans ~width_of ~width ~height:board_height ~selected months
      else
        let message = "v opens List. The six-month board needs 80 columns and more height. Only explicit plans are shown." in
        if width <= 6 || board_height < 3 then
          O.wrap_text ~width_of width message
          |> List.filteri (fun i _ -> i < board_height)
          |> List.map (fun text -> O.Chrome, text)
        else
          P.frame_rows ~width_of ~width ~height:board_height ~focused:false ~title:"Months [compact]"
            (O.wrap_text ~width_of (width - 6) message |> List.map (fun text -> O.Chrome, text)) in
    let details = if detail_height = 0 then [] else
      let capacity = P.capacity ~height:detail_height ~heading:false in
      let bottom_label = if List.length detail_content > capacity then
          Printf.sprintf "%d/%d lines ▼" capacity (List.length detail_content)
        else "" in
      P.frame_rows ~inset:0 ~width_of ~width ~height:detail_height ~focused:false
        ~title:"Selected Scheduled" ~bottom_label detail_content in
    context @ surface @ details
