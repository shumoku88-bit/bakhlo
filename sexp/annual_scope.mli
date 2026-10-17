(** Calendar-year scope for an explicitly selected Daily S-expression file.
    This is a read/write admission guard, NOT a qualified rollover, historical
    resolver, annual account total or multi-file transaction. *)

val of_string : string -> (int, string) result
(** Parse precisely four ASCII year digits; 0000 is refused. *)

val file_name : int -> string

val check_path : year:int -> string -> (unit, string) result
(** The selected file's basename must be exactly YYYY.sexp. *)

val check_book : year:int -> Daily_book.t -> (unit, string) result
(** Every admitted Actual entry must be dated in the selected calendar year.
    Scheduled due dates may cross the year boundary. *)
