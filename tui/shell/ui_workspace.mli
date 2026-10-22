type route = Screen.route =
  | Home
  | Selected_day of string
  | Actual
  | Scheduled
  | Balances
  | Daily_pace
  | Attention
  | Loci
  | Settlements
  | Income_expense
  | Transactions_flow
  | Stock_flow
  | Liquidity
  | Trend_locus
  | Multicurrency_spend

type t = { route : route; focus_day : string; measure : string }
(** [focus_day]: the day the session started on, the default date of a new
    Record or plan outside Selected Day. *)

val create : today:string -> measure:string -> (t, string) result
(** Refuses a [today] that is not a real calendar date. *)

val enter : t -> route -> t
