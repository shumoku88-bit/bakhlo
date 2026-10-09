(** Pure IEEE 802.3 CRC32 (Ethernet, gzip, PNG standard polynomial 0xEDB88320).
    Self-contained, deterministic, and dependency-free. *)

type t = int32

val table : int32 array
(** Precomputed 256-entry lookup table. *)

val of_string : string -> t
(** Compute 32-bit CRC over an arbitrary byte string. *)

val of_substring : string -> int -> int -> t
(** Compute 32-bit CRC over a substring [pos .. pos + len - 1]. *)

val to_hex : t -> string
(** Format CRC32 as an 8-character lowercase hexadecimal string (e.g. "cbf43926"). *)

val of_hex : string -> t option
(** Parse an 8-character hexadecimal string into a CRC32 value. *)
