(** The book mutations the application publishes, with every input they need
    (identities and dates included), so applying one is deterministic. Pure; the store
    owns files, locking and durability. *)

type op =
  | Put_entry of { replace : bool; entry : Daily_book.entry; plan : string option }
  | Correct_entry_date of { id : string; day : string }
  | Put_plan of { replace : bool; plan : Daily_book.plan }
  | Cancel_plan of { id : string; day : string }
  | Observe of (string * string * Z.t) list
  | Add_locus of string
  | Set_locus_label of { id : string; label : string; help : string option }
  | Classify_merchant of {
      id : string;
      disposition : Bakhlo_application.Event_merchants.disposition;
    }

val apply : Daily_book.t -> op -> (Daily_book.t, string) result
(** The ordinary [Daily_book] mutation for this operation. *)

val apply_all : Daily_book.t -> op list -> (Daily_book.t, string) result
(** All operations in order, or the first refusal; never a partial book. *)
