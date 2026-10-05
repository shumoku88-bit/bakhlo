open Base
module D = Bakhlo_domain
module Q = D.Quantity

type t = (string, D.Identifier.Measure.t * Q.t, String.comparator_witness) Map.t

let empty = Map.empty (module String)

let add totals change =
  let measure = D.Effect.measure change in
  Map.update totals (D.Identifier.Measure.to_string measure) ~f:(function
    | None -> (measure, D.Effect.quantity change)
    | Some (original, total) -> (original, Q.add total (D.Effect.quantity change)))

let at totals measure =
  match Map.find totals (D.Identifier.Measure.to_string measure) with
  | None -> Q.zero
  | Some (_, total) -> total

let first_nonzero totals =
  Option.map
    (List.find (Map.to_alist totals) ~f:(fun (_, (_, total)) -> not (Q.equal total Q.zero)))
    ~f:snd
