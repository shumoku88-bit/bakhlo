type key =
  [ `ASCII of char
  | `Uchar of Uchar.t
  | `Escape
  | `Enter
  | `Tab
  | `Backspace
  | `Insert
  | `Delete
  | `Home
  | `End
  | `Arrow of [ `Up | `Down | `Left | `Right ]
  | `Page of [ `Up | `Down ]
  | `Function of int ]

type modifier = [ `Meta | `Ctrl | `Shift ]

type input =
  [ `Key of key * modifier list
  | `Paste of [ `Start | `End ]
  | `End
  | `Resize of unit
  | `Mouse of unit ]

let key_ignoring_case = function
  | `Key (`ASCII c, mods) -> Some (`ASCII (Char.lowercase_ascii c), mods)
  | `Key (key, mods) -> Some (key, mods)
  | `Paste _ | `End | `Resize _ | `Mouse _ -> None

let motion_delta ~page = function
  | `Home -> -max_int
  | `End -> max_int
  | `Page `Up | `ASCII 'u' -> -page
  | `Page `Down | `ASCII 'd' -> page
  | `ASCII 'k' | `Arrow `Up -> -1
  | _ -> 1
