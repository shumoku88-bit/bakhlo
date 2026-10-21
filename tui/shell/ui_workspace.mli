type route = Screen.route =
  | Home | Calendar | Selected_day of string | Actual | Scheduled | Balances | Daily_pace
  | Attention | Loci | Settlements | Income_expense | Transactions_flow | Stock_flow | Liquidity
  | Trend_locus

type t = { route : route; calendar : Daily_calendar.t; measure : string }

val create : today:string -> measure:string -> (t, string) result
val enter : t -> route -> t
