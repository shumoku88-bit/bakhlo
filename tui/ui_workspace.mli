module B = Bakhlo_sexp.Daily_book

type route = Home | Calendar | Selected_day of string | Actual | Scheduled | Balances | Daily_pace | Attention | Loci | Settlements
type pane = Calendar | Detail
type family = Actual_row | Scheduled_row
type row = Actual_entry of B.entry | Scheduled_plan of B.plan
type order = Newest | Oldest
type schedule_view = Groups | Months | List_view

type browser = {
  selected : int;
  selected_id : (family * string) option;
  query : string;
  locus : string option;
  day : string option;
  order : order;
}

type t = {
  route : route;
  calendar : Daily_calendar.t;
  pane : pane;
  actual : browser;
  scheduled : browser;
  selected_day : browser;
  detail : browser;
  attention : browser;
  loci : browser;
  settlements : browser;
  schedule_view : schedule_view;
  balance_selected : int;
  measure : string;
}

val create : today:string -> measure:string -> (t, string) result
val identity : row -> family * string
val date : row -> string
val row_matches : book:B.t -> browser -> row -> bool
val rows : book:B.t -> t -> row list
val home_rows : book:B.t -> t -> row list
val browser : t -> browser
val update_browser : t -> browser -> t
val selected_row : book:B.t -> t -> row option
val move_selection : book:B.t -> t -> int -> t
val sync : book:B.t -> t -> t
val enter : t -> route -> t
val back : t -> t
val has_parent : t -> bool
val cycle_order : t -> t
val set_query : t -> string -> t
val set_locus : t -> string option -> t
val toggle_day_filter : t -> t
val cycle_schedule_view : t -> t
