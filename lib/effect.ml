type t = {
  key : Identifier.Effect_key.t option;
  locus : Identifier.Locus.t;
  measure : Identifier.Measure.t;
  quantity : Quantity.t;
}

let create ~key ~locus ~measure ~quantity = { key; locus; measure; quantity }
let key change = change.key
let locus change = change.locus
let measure change = change.measure
let quantity change = change.quantity
