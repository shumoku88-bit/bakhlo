type t =
  { locus : Identifier.Locus.t
  ; measure : Identifier.Measure.t
  ; quantity : Quantity.t
  }

let create ~locus ~measure ~quantity = { locus; measure; quantity }
let locus change = change.locus
let measure change = change.measure
let quantity change = change.quantity
