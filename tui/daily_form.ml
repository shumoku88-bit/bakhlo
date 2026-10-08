(* Pure form component for single-transaction entry.
   Field navigation, candidate cycling, cursor tracking, and text editing.
   Usable both as a pure model and as an independent Bonsai component. *)
module A = Daily_actions

type field = Date | Currency | Source | Destination | Amount | Memo

type model = {
  form : A.single_form;
  focus : field;
  cursor : int option;
}

let is_text_field = function
  | Date | Amount | Memo -> true
  | Currency | Source | Destination -> false

let field_label = function
  | Date -> "日付"
  | Currency -> "通貨"
  | Source -> "出金元"
  | Destination -> "入金先・科目"
  | Amount -> "金額"
  | Memo -> "メモ"

let field_value form = function
  | Date -> form.A.day
  | Currency -> form.measure
  | Source -> form.from_locus
  | Destination -> form.to_locus
  | Amount -> form.amount
  | Memo -> form.memo

let set_field_value form field value =
  match field with
  | Date -> { form with A.day = value }
  | Currency -> { form with measure = value }
  | Source -> { form with from_locus = value }
  | Destination -> { form with to_locus = value }
  | Amount -> { form with amount = value }
  | Memo -> { form with memo = value }

let backspace value =
  if value = "" then value
  else
    let rec start n = if n > 0 && Char.code value.[n] land 0xc0 = 0x80 then start (n - 1) else n in
    String.sub value 0 (start (String.length value - 1))

let cursor_pos ~value = function
  | None -> String.length value
  | Some at -> min (String.length value) (max 0 at)

let move_cursor ~value ~cursor step =
  let at = cursor_pos ~value cursor in
  if step < 0 then String.length (backspace (String.sub value 0 at))
  else if at = String.length value then at
  else
    let rec after n =
      if n < String.length value && Char.code value.[n] land 0xc0 = 0x80 then after (n + 1) else n
    in
    after (at + 1)

let insert_at ~value ~cursor text =
  let at = cursor_pos ~value cursor in
  let updated = String.sub value 0 at ^ text ^ String.sub value at (String.length value - at) in
  (updated, at + String.length text)

let erase_at ~value ~cursor =
  let at = cursor_pos ~value cursor in
  let prefix = backspace (String.sub value 0 at) in
  let updated = prefix ^ String.sub value at (String.length value - at) in
  (updated, String.length prefix)

let pick choices current step =
  let count = List.length choices in
  if count = 0 then current
  else
    let rec index n = function
      | [] -> 0
      | x :: _ when x = current -> n
      | _ :: xs -> index (n + 1) xs
    in
    List.nth choices ((index 0 choices + step + count) mod count)

let next_field = function
  | Date -> Currency
  | Currency -> Source
  | Source -> Destination
  | Destination -> Amount
  | Amount | Memo -> Memo

let prev_field = function
  | Date | Currency -> Date
  | Source -> Currency
  | Destination -> Source
  | Amount -> Destination
  | Memo -> Amount

type action =
  | Next
  | Previous
  | Set_focus of field
  | Move_cursor of int
  | Insert of string
  | Backspace
  | Cycle_choice of { choices : string list; step : int }
  | Clear_current

let apply_action model action =
  match action with
  | Next ->
      let focus = next_field model.focus in
      if focus = model.focus then model
      else { model with focus; cursor = None }
  | Previous ->
      let focus = prev_field model.focus in
      if focus = model.focus then model
      else { model with focus; cursor = None }
  | Set_focus focus ->
      if focus = model.focus then model
      else { model with focus; cursor = None }
  | Move_cursor step ->
      let value = field_value model.form model.focus in
      let next = move_cursor ~value ~cursor:model.cursor step in
      { model with cursor = Some next }
  | Insert text ->
      let value = field_value model.form model.focus in
      let updated, next_cursor = insert_at ~value ~cursor:model.cursor text in
      let form = set_field_value model.form model.focus updated in
      { model with form; cursor = Some next_cursor }
  | Backspace ->
      let value = field_value model.form model.focus in
      let updated, next_cursor = erase_at ~value ~cursor:model.cursor in
      let form = set_field_value model.form model.focus updated in
      { model with form; cursor = Some next_cursor }
  | Cycle_choice { choices; step } ->
      if is_text_field model.focus then model
      else
        let current = field_value model.form model.focus in
        let chosen = pick choices current step in
        let form = set_field_value model.form model.focus chosen in
        { model with form; cursor = None }
  | Clear_current ->
      let form = set_field_value model.form model.focus "" in
      { model with form; cursor = Some 0 }
