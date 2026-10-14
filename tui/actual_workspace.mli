(* ActualWorkspace: LOAM-compatible 3-pane Actuals Workspace (UI-03 / UI-04).
   Owned by actual_workspace.ml. Controller routes here without losing stable identities. *)

module B = Bakhlo_sexp.Daily_book

type scope = Focus_day | All_current
type sort_order = Asc | Desc
type pane = Loci | Transactions | Details

type t

type command =
  | Stay
  | Open_selected of B.entry
  | Record_new
  | Back
  | Redraw

val create : focus_date:string -> t

val focus_date : t -> string
val scope : t -> scope
val sort_order : t -> sort_order
val pane : t -> pane
val locus_row : t -> int
val transaction_row : t -> int
val detail_scroll : t -> int
val search_query : t -> string
val search_editing : t -> bool
val notice : t -> string

val selected_locus : book:B.t -> t -> string option
val selected_entry : book:B.t -> t -> B.entry option
val visible_entries : book:B.t -> t -> B.entry list
val loci_for_scope : book:B.t -> t -> string list
val scope_text : t -> string
val current_locus_name : book:B.t -> t -> string

val returned_from_detail : before_book:B.t -> after_book:B.t -> t -> t

val normalize_for_bounds :
  book:B.t ->
  dimensions:int * int ->
  width_of:(string -> int) ->
  t ->
  t

val handle :
  book:B.t ->
  dimensions:int * int ->
  width_of:(string -> int) ->
  t ->
  Ui_input.input ->
  t * command

val screen :
  book:B.t ->
  dimensions:int * int ->
  width_of:(string -> int) ->
  t ->
  (Daily_overlays.style * string) list

val footer : dimensions:int * int -> width_of:(string -> int) -> t -> string list
val cursor_position : dimensions:int * int -> width_of:(string -> int) -> t -> (int * int) option
