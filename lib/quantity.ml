open Base

type t = Z.t

let of_quanta quanta = quanta
let quanta quantity = quantity
let zero = Z.zero
let add = Z.add
let neg = Z.neg
let sub = Z.sub
let equal = Z.equal
let compare = Z.compare
let sum quantities = List.fold quantities ~init:zero ~f:add
