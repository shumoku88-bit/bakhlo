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
