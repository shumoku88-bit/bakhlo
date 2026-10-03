module D = Loam_domain
module Coordinate = D.Effect_coordinate
module Q = D.Quantity

type t = (Coordinate.t, Q.t, Coordinate.comparator_witness) Base.Map.t

let empty = Base.Map.empty (module Coordinate)

let add_effects totals effects =
  Base.List.fold effects ~init:totals ~f:(fun totals change ->
    let coordinate : Coordinate.t =
      { locus = D.Effect.locus change; measure = D.Effect.measure change }
    in
    Base.Map.update totals coordinate ~f:(function
      | None -> D.Effect.quantity change
      | Some total -> Q.add total (D.Effect.quantity change)))
;;

let at totals coordinate =
  match Base.Map.find totals coordinate with
  | None -> Q.zero
  | Some quantity -> quantity
;;
