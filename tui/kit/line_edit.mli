(** One line of UTF-8 text being typed, with a byte-offset cursor that always sits
    on a scalar boundary. Shared by the Record and workspace inputs. Pure. *)

val backspace : string -> string
(** The text without its last scalar. *)

val position : value:string -> int option -> int
(** The cursor's byte offset in [value]: the end when absent, clamped otherwise. *)

val move : value:string -> cursor:int option -> int -> int
(** One scalar left (a negative step) or right, stopping at either end. *)

val insert : value:string -> cursor:int option -> string -> string * int
(** The text with [text] inserted at the cursor, and the cursor after it. *)

val erase : value:string -> cursor:int option -> string * int
(** The text without the scalar before the cursor, and the cursor where that scalar began. *)
