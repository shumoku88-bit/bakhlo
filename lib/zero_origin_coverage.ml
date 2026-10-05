type t = (Effect_coordinate.t, Effect_coordinate.comparator_witness) Base.Set.t
type error = Duplicate_coordinate of { position : int; coordinate : Effect_coordinate.t }

let empty = Base.Set.empty (module Effect_coordinate)

let of_coordinates coordinates =
  match
    Base.List.fold_result coordinates ~init:(1, empty) ~f:(fun (position, covered) coordinate ->
        if Base.Set.mem covered coordinate then
          Error (Duplicate_coordinate { position; coordinate })
        else Ok (position + 1, Base.Set.add covered coordinate))
  with
  | Error error -> Error error
  | Ok (_, covered) -> Ok covered

let covers coverage coordinate = Base.Set.mem coverage coordinate
