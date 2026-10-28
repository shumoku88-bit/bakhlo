(** The book.txt writer. A session couples admitted contents to the file revision
    and stamp read from disk; only loading or a confirmed publication creates one. *)

exception Refused of string

type stamp

type t = private {
  path : string;
  revision : string;
  book : Bakhlo_household.Daily_book.t;
  sidecars : Bakhlo_household.Daily_txt.sidecars;
  stamp : stamp;
}

type outcome =
  | Written of t
  | Conflict
  | Refused_input of string
  | Uncertain of { expected : string }
      (** The replacement may have happened; reload and compare [expected]. *)

val load : string -> t
val load_result : string -> (t, string) result
val reload : t -> t
val create_empty : path:string -> measure:string -> scale:int -> t

type publication_step = Temp_written | Previous_kept | Replaced

val publish :
  ?checkpoint:(publication_step -> unit) ->
  ?sidecars:Bakhlo_household.Daily_txt.sidecars ->
  t ->
  Bakhlo_household.Daily_book.change list ->
  outcome
(** Admit changes, refuse a changed file, then durably replace and read back.
    [checkpoint] is for deterministic fault and interruption checks. *)

val revision_after :
  ?sidecars:Bakhlo_household.Daily_txt.sidecars ->
  t ->
  Bakhlo_household.Daily_book.change list ->
  string
(** The expected revision of the admitted candidate, without writing it. *)

val confirms : expected:string -> t -> bool
val revision_of_bytes : string -> string
val read_revision : string -> string
val prev_path : string -> string
val create_copy : source:string -> target:string -> unit

val restore_copy : source:string -> target:string -> unit
(** Copy to a fresh target only; neither operation adopts or modifies the source. *)

val read : string -> string
(** File primitives shared by the Shell's configuration writers. *)

val write_new : string -> string -> unit
val with_writer : string -> (unit -> 'a) -> 'a

val write_atomic : string -> string -> unit
(** Durably replace and read back under a caller-held writer lock. *)

val require : bool -> string -> unit
val new_id : unit -> string
val today : unit -> string
