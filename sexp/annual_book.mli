(** Pure wire codec for calendar-year S-expression envelopes linked to an
    immediately preceding annual book. Does not perform I/O or verify disk
    files; callers must verify the referenced predecessor bytes before decoding. *)

type reference = { year : int; fingerprint : string }
type t

val of_string : string -> (t, string) result
val reference : t -> reference
val year : t -> int

val decode : prior:Daily_book.t -> t -> (Daily_book.t, string) result
(** Reconstruct the full admitted ledger by prepending the verified predecessor's
    entries and checking monotonic plan and support invariants. *)

val encode :
  year:int -> reference:reference -> prior:Daily_book.t -> Daily_book.t -> (string, string) result
(** Project only the selected year's entries into an annual envelope while
    requiring all predecessor entries and closed plans to remain intact. *)

val start : year:int -> reference:reference -> prior:Daily_book.t -> (string, string) result
(** Create the initial successor envelope from a verified predecessor without
    inventing new observations or rewriting prior plans. *)
