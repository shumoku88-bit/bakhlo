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

module External_party = struct
  type t = string

  let of_string = nonempty
  let to_string value = value
  let equal = String.equal
end

module Effect_key = struct
  module Key = struct
    type t = string
    let compare = String.compare
    let sexp_of_t = String.sexp_of_t
  end
  include Key
  include Comparator.Make (Key)
  let of_string = nonempty
  let to_string value = value
  let equal = String.equal
end

module Relation = struct
  module Key = struct
    type t = string
    let compare = String.compare
    let sexp_of_t = String.sexp_of_t
  end
  include Key
  include Comparator.Make (Key)
  let of_string = nonempty
  let to_string value = value
  let equal = String.equal
end

module Validity_revision = struct
  module Key = struct
    type t = string
    let compare = String.compare
    let sexp_of_t = String.sexp_of_t
  end
  include Key
  include Comparator.Make (Key)
  let of_string = nonempty
  let to_string value = value
  let equal = String.equal
end

module Event = struct
  module Key = struct
    type t = string

    let compare = String.compare
    let sexp_of_t = String.sexp_of_t
  end

  include Key
  include Comparator.Make (Key)

  let of_string = nonempty
  let to_string value = value
  let equal = String.equal
end
