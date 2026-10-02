module D = Loam_domain
module Coordinate = D.Effect_coordinate
module Q = D.Quantity

type t =
  { totals : (Coordinate.t, Q.t, Coordinate.comparator_witness) Base.Map.t
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
      ~init:(Base.Map.empty (module Coordinate))
      ~f:(fun totals movement ->
        Base.List.fold (D.Movement.effects movement) ~init:totals ~f:(fun totals change ->
          let coordinate : Coordinate.t =
            { locus = D.Effect.locus change; measure = D.Effect.measure change }
          in
          Base.Map.update totals coordinate ~f:(function
            | None -> D.Effect.quantity change
            | Some total -> Q.add total (D.Effect.quantity change))))
  in
  { totals; coverage }
;;

let query model coordinate =
  if D.Zero_origin_coverage.covers model.coverage coordinate
  then
    let quantity =
      match Base.Map.find model.totals coordinate with
      | None -> Q.zero
      | Some quantity -> quantity
    in
    Ok { coordinate; quantity }
  else Error (Origin_unknown { coordinate })
;;

let coordinate answer = answer.coordinate
let quantity answer = answer.quantity
