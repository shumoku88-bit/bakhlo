type route = Screen.route =
  | Home | Calendar | Selected_day of string | Actual | Scheduled | Balances | Daily_pace
  | Attention | Loci | Settlements | Income_expense | Transactions_flow | Stock_flow

type t = { route : route; calendar : Daily_calendar.t; measure : string }

let create ~today ~measure =
  Result.map (fun calendar -> { route = Home; calendar; measure }) (Daily_calendar.create today)
let enter state route = { state with route }
