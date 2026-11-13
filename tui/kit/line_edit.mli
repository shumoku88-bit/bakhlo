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

val printable : Uchar.t -> bool
(** A character the household can type: not a control character (C0, DEL, C1). *)

val typed : Ui_input.key -> string option
(** The text a key types: a printable ASCII character or Unicode scalar. *)

val edit : value:string -> cursor:int option -> Ui_input.key -> (string * int option) option
(** One key on one line, the same in every input box: ←/→ move one scalar,
    Home/End go to either end, Backspace erases before the cursor and a printable
    key is typed at it. [None] for any other key. *)

val at_end : string -> Ui_input.key -> string option
(** A box typed only at its end (a search, a date filter): a printable key is
    added, Backspace removes the last scalar; [None] for any other key. *)
