(** A book file: the ordinary single-file book (the snapshot) followed by appended
    record lines, one per publication. A file without records is an ordinary book.
    Pure; the store owns files, locking and durability. *)

type op =
  | Put_entry of { replace : bool; entry : Daily_book.entry; plan : string option }
  | Correct_entry_date of { id : string; day : string }
  | Put_plan of { replace : bool; plan : Daily_book.plan }
  | Cancel_plan of { id : string; day : string }
  | Observe of (string * string * Z.t) list
  | Add_locus of string
  | Set_locus_label of { id : string; label : string; help : string option }
  | Classify_merchant of { id : string; disposition : Bakhlo_application.Event_merchants.disposition }
(** Exactly the book mutations the application publishes, with every input they
    need (identities and dates included), so applying one is deterministic. *)

val apply : Daily_book.t -> op -> (Daily_book.t, string) result
(** The ordinary [Daily_book] mutation for this operation. *)

val apply_all : Daily_book.t -> op list -> (Daily_book.t, string) result
(** All operations in order, or the first refusal; never a partial book. *)

val record_line : seq:int -> op list -> string
(** One newline-terminated line: [(record SEQ DIGEST OP...)]. Sequence numbers start
    at 1 after each snapshot. Raises [Invalid_argument] for no operations. *)

val decode_record_line : seq:int -> string -> (op list, string) result
(** Decode one record line (trailing newline optional), checking sequence and digest. *)

type loaded = {
  book : Daily_book.t;
  snapshot : string;  (** Leading ordinary-book bytes. *)
  records : int;  (** Complete records replayed. *)
  valid_length : int;  (** Bytes of snapshot plus complete records. *)
  torn : bool;  (** An unterminated final line follows [valid_length]. *)
}

val load : string -> (loaded, string) result
(** Admit the snapshot, then replay records in order. Only a final line without its
    newline counts as torn (an interrupted append) and is reported, not applied.
    Any other damage, a wrong sequence number, a digest mismatch or a refused replay
    refuses the whole file: no partial book. *)
