let backspace value =
  if value = "" then value
  else
    let rec start n = if n > 0 && Char.code value.[n] land 0xc0 = 0x80 then start (n - 1) else n in
    String.sub value 0 (start (String.length value - 1))

let position ~value = function
  | None -> String.length value
  | Some at -> min (String.length value) (max 0 at)

let move ~value ~cursor step =
  let at = position ~value cursor in
  if step < 0 then String.length (backspace (String.sub value 0 at))
  else if at = String.length value then at
  else
    let rec after n =
      if n < String.length value && Char.code value.[n] land 0xc0 = 0x80 then after (n + 1) else n
    in
    after (at + 1)

let insert ~value ~cursor text =
  let at = position ~value cursor in
  let updated = String.sub value 0 at ^ text ^ String.sub value at (String.length value - at) in
  (updated, at + String.length text)

let erase ~value ~cursor =
  let at = position ~value cursor in
  let prefix = backspace (String.sub value 0 at) in
  let updated = prefix ^ String.sub value at (String.length value - at) in
  (updated, String.length prefix)

(* What a key types, if anything. A control character never reaches the text:
   below space, DEL and the C1 range (128-159) are refused, everything else is a
   character the household meant, Japanese included. *)
let printable c =
  let n = Uchar.to_int c in
  n >= 32 && (n < 127 || n > 159)

let typed : Ui_input.key -> string option = function
  | `ASCII c when printable (Uchar.of_char c) -> Some (String.make 1 c)
  | `Uchar c when printable c ->
      let b = Buffer.create 4 in
      Buffer.add_utf_8_uchar b c;
      Some (Buffer.contents b)
  | _ -> None

(* One key on one line of text, the same in every input box:

     ← →        one character left or right
     Home End   to the start or the end
     Backspace  the character before the cursor
     a, あ, 1   typed at the cursor

   [None] for any other key, which stays the screen's to decide (Enter, Tab, ↑↓). *)
let edit ~value ~cursor (key : Ui_input.key) =
  let at (text, cursor) = Some (text, Some cursor) in
  match key with
  | `Arrow `Left -> Some (value, Some (move ~value ~cursor (-1)))
  | `Arrow `Right -> Some (value, Some (move ~value ~cursor 1))
  | `Home -> Some (value, Some 0)
  | `End -> Some (value, None)
  | `Backspace -> at (erase ~value ~cursor)
  | key -> Option.bind (typed key) (fun text -> at (insert ~value ~cursor text))

(* A small box typed only at its end, such as a search or a date filter: a
   printable key is added, Backspace takes the last character back. [None] for
   any other key. Boxes whose text is corrected in the middle use [edit]. *)
let at_end value (key : Ui_input.key) =
  match key with
  | `Backspace -> Some (backspace value)
  | key -> Option.map (fun text -> value ^ text) (typed key)
