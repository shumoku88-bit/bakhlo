(** Reading a book and knowing whether its replacement succeeded.

    A session couples admitted contents to the revision and stamp observed on
    disk. Loading or a confirmed publication creates that evidence; callers
    cannot construct it themselves.

    An exception after replacement can leave the new book on disk without
    returning [Written]. That is [Uncertain], not permission to write again:
    reload and compare the candidate's expected revision. The synthetic
    examples in [test/book_file_tests.ml] distinguish these outcomes. *)

exception Refused of string

type stamp
type t = private { path : string; revision : string; book : Bakhlo_household.Book.t; stamp : stamp }

type outcome =
  | Written of t  (** Replacement, flush and byte readback completed; use the returned session. *)
  | Conflict  (** The file no longer matches the session. No replacement was attempted. *)
  | Refused_input of string
      (** Admission or file/lock access failed before replacement was attempted.
          This includes storage errors, not only invalid household input. *)
  | Uncertain of { expected : string }
      (** Replacement was attempted but could not be confirmed. The old or new
          book may be present. Reload and compare [expected]; do not retry blindly. *)

val load : string -> t
val load_result : string -> (t, string) result
val reload : t -> t
val create_empty : path:string -> measure:string -> scale:int -> t

type publication_step = Temp_written | Previous_kept | Replaced

val publish :
  ?checkpoint:(publication_step -> unit) -> t -> Bakhlo_household.Book.change list -> outcome
(** Admit changes, then check the session's file under the writer lock.
    Prepare and flush a whole candidate file, keep the old book as [.prev],
    rename the candidate onto the book, flush the directory and read back bytes.

    Cooperative writers and stable parent namespaces are assumed. This is not
    a security sandbox or a physical power-loss qualification.
    [checkpoint] is for deterministic fault and interruption checks. *)

val revision_after : t -> Bakhlo_household.Book.change list -> string
(** The expected revision of the admitted candidate, without writing it. *)

val confirms : expected:string -> t -> bool
(** Compare a freshly reloaded session with an uncertain candidate's revision.
    A match confirms its presence, not a past acknowledgement to the user.
    A non-match does not authorize a retry. *)

val revision_of_bytes : string -> string
(** Length-and-digest token for content comparison, not a security guarantee. *)

val read_revision : string -> string
val prev_path : string -> string
val create_copy : source:string -> target:string -> unit

val restore_copy : source:string -> target:string -> unit
(** Copy to a fresh target only; neither copy operation adopts or modifies the
    source. In particular, [.prev] is not automatically selected as the book. *)

val read : string -> string
(** File primitives shared by the Shell's configuration writers. *)

val write_new : string -> string -> unit
val with_writer : string -> (unit -> 'a) -> 'a

val write_atomic : string -> string -> unit
(** Durably replace and read back under a caller-held writer lock. *)

val require : bool -> string -> unit
val new_id : unit -> string
