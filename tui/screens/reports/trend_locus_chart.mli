(* Owner-local multi-series chart for the Trend / Locus comparison.
   Exact amounts, integer pixel scaling, distinct marker glyphs only. *)

type series = { marker : string; values : Z.t array }
(** One exact recorded value per shared x position. *)

type annotation = { glyph : string; at : int list }
(** A session-only annotation: its distinct marker glyph and the x positions it
    marks. Positions use the same x mapping as the plotted series. *)

type t = {
  series : series array;
  count : int;  (** Number of x positions the series share. *)
  selected : int;  (** The selected x position. *)
  guides : int list;  (** x positions that carry a vertical guide. *)
  annotations : annotation list;  (** Marked positions, one glyph per annotation. *)
}

type rendered = {
  rows : string list;  (** Painted plot rows, value axis column included. *)
  axis_exact : bool;  (** [false] when an exact axis label did not fit; the
      caller then asks for a wider terminal instead of showing a cut number. *)
}

val markers : string array
(** The five distinct series markers, in slot order. *)

val collision : string
(** The glyph drawn where two marks share one cell. *)

val render :
  width:int ->
  height:int ->
  width_of:(string -> int) ->
  label:(Z.t -> string) ->
  t ->
  rendered
(** Paint the chart. [label] renders an exact amount for an axis value. At
    most one extra row carries annotation glyphs for the same x positions;
    every row fits [width] and the result has at most [height] rows. *)
