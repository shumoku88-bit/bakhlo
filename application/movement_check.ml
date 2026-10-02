module M = Loam_domain.Movement

type command = { effects : Loam_domain.Effect.t list }

type preview =
  { movement : M.t
  ; positive_total : Loam_domain.Quantity.t
  }

let run { effects } =
  match M.validate effects with
  | Error errors -> Error errors
  | Ok movement -> Ok { movement; positive_total = M.positive_total movement }
;;

let measure preview = M.measure preview.movement
let effects preview = M.effects preview.movement
let positive_total preview = preview.positive_total
