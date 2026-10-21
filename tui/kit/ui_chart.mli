(* Braille charts following LOAM Tui.Chart: nice ticks, value rows, subpixel
   interpolation, markers and a left value axis. Exact Z values in, painted
   text out; nothing feeds back into a calculation. *)

type range = { low : Z.t; high : Z.t }
type scale = { range : range; step : Z.t; ticks : Z.t list }

val scale_for : ?intervals:int -> Z.t list -> scale
(** Bounds rounded outward to 1/2/5×10^n steps; a flat series gets a tenth of
    its magnitude (at least one quantum) of room on each side. *)

val row_for_value : int -> range -> Z.t -> int
(** Row 0 is the top. *)

val axis_width : width_of:(string -> int) -> int -> scale -> (Z.t -> string) -> int
(** Widest tick label (at least 3), at most a quarter of the width (at least 3). *)

val qualified_rows :
  width:int ->
  height:int ->
  values:Z.t option list ->
  joins:bool list ->
  selected:int ->
  range:range ->
  connect:bool ->
  grid_rows:int list ->
  string list
(** Day-aligned known values: [joins.(i)] allows a line between day [i] and
    [i + 1]; unknown days are never interpolated. Known days are [●], the
    selected known day [◆], empty grid cells [┄]. *)

val line_rows :
  width:int ->
  height:int ->
  values:Z.t list ->
  selected:int ->
  range:range ->
  grid_rows:int list ->
  string list
(** One continuous series with a quiet guide at the selected point. *)

val with_value_axis :
  width_of:(string -> int) ->
  axis:int ->
  height:int ->
  scale:scale ->
  label:(Z.t -> string) ->
  ?note:(int -> string) ->
  string list ->
  string list
(** Prefix [label ┤ ] on tick rows (a label that does not fit is […]) and
    [note │ ] elsewhere. *)

val multi_line_rows :
  width:int ->
  height:int ->
  series:Z.t list list ->
  selected:int ->
  range:range ->
  grid_rows:int list ->
  markers:string list ->
  ?guides:int list ->
  ?annotations:(string * int list) list ->
  unit ->
  string list
(** Several series on one braille grid. Masks are unioned, so a column never
    overwrites another series; each series' marker sits on its selected value
    when that cell carries no line. [guides] mark columns and [annotations]
    mark a glyph at every listed x. *)
