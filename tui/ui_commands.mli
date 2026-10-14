type page = Root | Transactions | Planning | Analysis | Setup
type action = Record | Actual | Scheduled | New_plan | Balances | Daily_pace | Theme | Home | Calendar | Attention
type item = Group of page | Action of action
type t = { page : page; selected : int }
type outcome = Updated of t | Chosen of action | Closed

val initial : t
val items : page -> (item * string) list
val title : page -> string
val move : t -> int -> t
val select : t -> outcome
val back : t -> outcome
val open_group : t -> t
val handle : t -> Ui_input.input -> outcome
