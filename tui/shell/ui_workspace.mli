module B = Bakhlo_sexp.Daily_book

type route = Screen.route =
  | Home | Calendar | Selected_day of string | Actual | Scheduled | Balances | Daily_pace
  | Attention | Loci | Settlements | Income_expense | Transactions_flow | Stock_flow
type family = Record_browser.family = Actual_row | Scheduled_row
type row = Record_browser.row = Actual_entry of B.entry | Scheduled_plan of B.plan

type t = { route : route; calendar : Daily_calendar.t; measure : string }

val create : today:string -> measure:string -> (t, string) result
val enter : t -> route -> t
val date : row -> string
val identity : row -> family * string
