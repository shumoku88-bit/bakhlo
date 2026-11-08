(** Attention as the book holds it, and adding and closing items. *)

module T = Bakhlo_book_txt.Book_txt

type due = T.due = Due_on of string | No_due_date | Due_undetermined
type close_kind = T.close_kind = Resolved | Dropped
type item = T.item = { id : string; due : due; context : string }
type close = T.close = { item : string; day : string; kind : close_kind }
type t = { items : item list; closes : close list }

val empty : t
val open_items : t -> item list
val next_id : t -> string
val add_item : t -> id:string -> context:string -> due:due -> (t, string) result
val close_item : t -> id:string -> known_on:string -> kind:close_kind -> (t, string) result
val due_label : due -> string

type summary = { open_count : int; overdue_count : int; due_today_count : int }

val summarize : today:string -> t -> summary
val badge : ?width:int -> summary -> string
val due_display : today:string -> due -> string
