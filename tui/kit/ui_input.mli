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

val key_ignoring_case : input -> (key * modifier list) option
(** The pressed key with ASCII letters lowercased, so a key works with Shift or Caps
    Lock alike; [None] for paste markers, resize, mouse and end of input. *)

val motion_delta : page:int -> key -> int
(** j/k and Up/Down, PgUp/PgDn (or u/d, as Ctrl-U/D arrive) and Home/End as a signed
    row delta with [page] rows per page; any other key moves down one row. *)
