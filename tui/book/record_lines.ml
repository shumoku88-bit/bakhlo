(* One-line presentations of Actual entries and Scheduled plans for record lists:
   exact amounts, never a guessed total for split or multi-Measure entries. *)
module B = Bakhlo_household.Book
module D = Bakhlo_domain
module A = Draft
module O = Ui_render
module W = Record_browser

let tr = Ui_text.tr

let row_title book = function
  | W.Actual_entry entry ->
      let amount =
        match entry.B.effects with
        | [ a; b ] when a.B.measure = b.B.measure ->
            let positive = if Z.sign a.B.amount > 0 then a else b in
            let measure = positive.B.measure in
            let amount = B.format book measure positive.B.amount in
            if String.length amount > 20 then tr "see details" else amount ^ " " ^ measure
        | _ -> tr "split / see details"
      in
      entry.day ^ "  " ^ Option.value ~default:"(no description)" entry.memo ^ "  " ^ amount
  | W.Scheduled_plan plan ->
      let total =
        List.fold_left (fun n (_, v) -> if Z.sign v > 0 then Z.add n v else n) Z.zero plan.changes
      in
      let status =
        if plan.paid_by <> None then "[Paid]"
        else if plan.cancelled_on <> None then "[Cancelled]"
        else "[Open]"
      in
      let amt = B.format book plan.measure total in
      plan.day ^ "  " ^ plan.id ^ "  " ^ amt ^ " " ^ plan.measure ^ "  " ^ status

(* A simple receiving amount shown by [format], never a sum across split Effects or
   Measures. *)
let amount_summary ~format (entry : B.entry) =
  let measures =
    List.sort_uniq String.compare (List.map (fun (p : B.posting) -> p.B.measure) entry.effects)
  in
  let positive = List.filter (fun (p : B.posting) -> Z.sign p.B.amount > 0) entry.effects
  and negative = List.filter (fun (p : B.posting) -> Z.sign p.B.amount < 0) entry.effects in
  if List.length measures > 1 then Printf.sprintf "multi (%d)" (List.length measures)
  else if List.length positive > 1 || List.length negative > 1 then "split"
  else
    match (positive, entry.effects) with
    | p :: _, _ | [], [ p ] -> format p
    | [], [] -> "—"
    | [], _ -> "see details"

let actual_amount book entry =
  let format (p : B.posting) =
    let measure = p.B.measure and quanta = p.B.amount in
    (if Z.sign quanta < 0 then "-" else if Z.sign quanta > 0 then "+" else "")
    ^ Book_display.format_money book measure (Z.abs quanta)
    ^ " " ^ measure
  in
  amount_summary ~format entry

let actual_table ~width_of ~width book rows =
  let room = max 0 (width - 6) in
  let amount_width =
    min 22
      (max 12
         (List.fold_left
            (fun n row ->
              match row with W.Actual_entry e -> max n (width_of (actual_amount book e)) | _ -> n)
            0 rows))
  in
  let table date description amount =
    if room < 40 then O.pad ~width_of room description
    else
      let amount = if width_of amount <= amount_width then amount else "see details" in
      O.pad ~width_of 10 date ^ "  "
      ^ O.pad ~width_of (room - 14 - amount_width) description
      ^ "  "
      ^ String.make (max 0 (amount_width - width_of amount)) ' '
      ^ amount
  in
  let titles =
    List.map
      (function
        | W.Actual_entry e ->
            table e.day (Option.value ~default:"(no description)" e.memo) (actual_amount book e)
        | row -> row_title book row)
      rows
  in
  ("  " ^ table "Date" "Description" "Amount", titles)

let scheduled_table ~width_of ~width book rows =
  let room = max 0 (width - 8) in
  let plans = List.filter_map (function W.Scheduled_plan p -> Some p | _ -> None) rows in
  let amount_w =
    min 20
      (max 10
         (List.fold_left
            (fun n (p : B.plan) ->
              let total =
                List.fold_left
                  (fun acc (_, v) -> if Z.sign v > 0 then Z.add acc v else acc)
                  Z.zero p.changes
              in
              let amt_str = B.format book p.measure total ^ " " ^ p.measure in
              max n (width_of amt_str))
            0 plans))
  in
  let status_w = 11 in
  let row_line (p : B.plan) =
    let total =
      List.fold_left (fun n (_, v) -> if Z.sign v > 0 then Z.add n v else n) Z.zero p.changes
    in
    let status =
      if p.paid_by <> None then "[Paid]"
      else if p.cancelled_on <> None then "[Cancelled]"
      else "[Open]"
    in
    let amt = B.format book p.measure total ^ " " ^ p.measure in
    if room < 40 then
      O.clip_text ~width_of room (p.day ^ "  " ^ O.visible p.id ^ "  " ^ amt ^ "  " ^ status)
    else
      let id_w = max 6 (room - 10 - 2 - amount_w - 2 - status_w) in
      O.pad ~width_of 10 p.day ^ "  "
      ^ O.pad ~width_of id_w (O.visible p.id)
      ^ "  " ^ O.pad_left ~width_of amount_w amt ^ "  " ^ status
  in
  List.map (function W.Scheduled_plan p -> row_line p | row -> row_title book row) rows
