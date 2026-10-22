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

let create ~today ~measure =
  Result.map
    (fun focus_day -> { route = Home; focus_day; measure })
    (Daily_draft.normalize_date today)

let enter state route = { state with route }
