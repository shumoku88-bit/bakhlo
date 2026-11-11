(** The Balances screen's rows: current balances by coordinate and LOAM's Role
    Balances with their evidence. Read-only; an unsupported quantity is never zero. *)

type balance_item =
  | Header_row of string
  | Account_row of {
      locus : string;
      measure : string;
      role : Locus_roles.role option;
      value : Book_display.quantity_value;
    }
  | Subtotal_row of { role : Locus_roles.role; measure : string; subtotal : Z.t }
  | Balance_sheet_status of { measure : string; complete : bool }
  | Net_worth_row of { measure : string; known_subtotal : Z.t; complete : bool }
  | Blank_row

val current_balance_items :
  book:Bakhlo_household.Book.t -> coords:(string * string) list option -> balance_item list
(** One row per (Locus, Measure); [None] is every offered Locus in every Measure. *)

val role_balance_items : book:Bakhlo_household.Book.t -> roles:Locus_roles.t -> balance_item list
(** Per-Measure stock sections, then the evidence shared by every Measure, over the
    coordinates the book represents (current Effects and support lines). *)

val balance_item_line :
  ?width_of:(string -> int) -> ?width:int -> book:Bakhlo_household.Book.t -> balance_item -> string

val balance_item_detail : book:Bakhlo_household.Book.t -> balance_item -> string list
