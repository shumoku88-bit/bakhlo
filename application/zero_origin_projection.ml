module D = Loam_domain
module Coordinate = D.Effect_coordinate
module Q = D.Quantity

type t =
  { totals : Effect_sum.t
  ; coverage : D.Zero_origin_coverage.t
  }

type answer =
  { coordinate : Coordinate.t
  ; quantity : Q.t
  }

type unavailable = Origin_unknown of { coordinate : Coordinate.t }

let create ~movements ~coverage =
  let totals =
    Base.List.fold
      movements
      ~init:Effect_sum.empty
      ~f:(fun totals movement -> Effect_sum.add_effects totals (D.Movement.effects movement))
  in
  { totals; coverage }
;;

let query model coordinate =
  if D.Zero_origin_coverage.covers model.coverage coordinate
  then
    let quantity = Effect_sum.at model.totals coordinate in
    Ok { coordinate; quantity }
  else Error (Origin_unknown { coordinate })
;;

let coordinate answer = answer.coordinate
let quantity answer = answer.quantity
