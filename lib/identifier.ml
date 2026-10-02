open Base

type error = Empty

let nonempty value = if String.is_empty value then Error Empty else Ok value

module Measure = struct
  type t = string

  let of_string = nonempty
  let to_string value = value
  let equal = String.equal
end

module Locus = struct
  type t = string

  let of_string = nonempty
  let to_string value = value
  let equal = String.equal
end
