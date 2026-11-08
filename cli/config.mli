(** Settings files beside the book: in [config/] when it holds them, else beside it. *)

val read : book_path:string -> string -> (string option, string) result
(** A settings file's bytes; [None] when it does not exist. *)

val write : book_path:string -> string -> expected:string option -> string -> (unit, string) result
(** Replace a settings file under the writer lock only if it still holds [expected]. *)
