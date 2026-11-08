(** The one reader of the language-neutral answer files (test/README.md).

    It knows the shape, not the household: notes, [USE] context, one-line and
    block questions, reprinting with the computed answers and comparing the text.
    Each runner supplies only [answer] for its kinds. *)

type context = (string * string option) list
(** The files named by [USE <name> <file|->] lines so far; [-] is no file. *)

type question = { header : string list; body : string list; line : int }
(** A question's header fields, its block lines without notes (empty for a
    one-line question) and the line it starts on. *)

type counts = { mutable answers : int; mutable failures : int; kinds : (string, int) Hashtbl.t }

exception Bad_sample of string

val bad : string -> 'a
(** Refuse a sample that does not follow its question's shape. *)

val fields : string -> string list
val row : string list -> string
val read : string -> string -> string
val create : unit -> counts
val count : counts -> string -> unit
val counted : counts -> string -> int
val context : context -> string -> string option

val split_at : (string list -> bool) -> string list -> string list * string list
(** The lines before the first whose fields satisfy the test, and the rest. *)

val values : string -> string list -> string list
(** The values of [KEY value] lines. *)

val equal : counts -> path:string -> want:string -> got:string -> unit
(** Count a failure at the first differing line. *)

val render :
  counts ->
  path:string ->
  line:int ->
  use:context ->
  blocks:string list ->
  answer:(context -> question -> string list) ->
  string ->
  string
(** The text again, each question replaced by [answer]'s lines (a block's
    [END<KIND>] is added here). [answer] reprints the header and input lines. *)

val check :
  counts ->
  dir:string ->
  file:string ->
  blocks:string list ->
  answer:(context -> question -> string list) ->
  unit

val run :
  counts -> dir:string -> blocks:string list -> answer:(context -> question -> string list) -> unit
(** [check] every [.answers] file of [dir] in name order. *)
