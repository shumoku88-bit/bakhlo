module D = Bakhlo_domain
module Q = Current_quantity_query

type premise = Zero_origin | Opening | Current_assertion
type exact = { coordinate : D.Effect_coordinate.t; quantity : D.Quantity.t; premise : premise }
type present = { coordinate : D.Effect_coordinate.t }
type outcome = Exact of exact | Known_present of present
type unavailable = Q.unavailable = Support_unknown of { coordinate : D.Effect_coordinate.t }
type answer = (outcome, unavailable) result

let project = function
  | Ok (Q.Exact original) ->
      let premise =
        match Q.premise original with
        | Zero_origin -> Zero_origin
        | Opening _ -> Opening
        | Current_assertion _ -> Current_assertion
      in
      Ok (Exact { coordinate = Q.coordinate original; quantity = Q.quantity original; premise })
  | Ok (Known_present original) -> Ok (Known_present { coordinate = Q.present_coordinate original })
  | Error (Support_unknown { coordinate }) -> Error (Support_unknown { coordinate })

let coordinate (answer : exact) = answer.coordinate
let quantity (answer : exact) = answer.quantity
let premise (answer : exact) = answer.premise
let present_coordinate (answer : present) = answer.coordinate
