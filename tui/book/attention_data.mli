(** attention_data.mli - Attention model, serialization, and lifecycle operations *)

type due = Due_on of string | No_due_date | Due_undetermined
type closure_kind = Resolved | Dropped
type item = { id : string; context : string; due : due }
type closure = { attention : string; known_on : string; kind : closure_kind }
type t = { items : item list; closures : closure list }

val empty : t
val open_items : t -> item list
val next_id : t -> string
val add_item : t -> id:string -> context:string -> due:due -> (t, string) result
val close_item : t -> id:string -> known_on:string -> kind:closure_kind -> (t, string) result
val due_label : due -> string

type summary = { open_count : int; overdue_count : int; due_today_count : int }

val summarize : today:string -> t -> summary
val badge : ?width:int -> summary -> string
val due_display : today:string -> due -> string
val of_string : string -> (t, string) result
val to_string : t -> string
