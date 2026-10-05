type t = { id : Identifier.Event.t; effects : Effect.t list }

type error =
  | Duplicate_effect_key of { key : Identifier.Effect_key.t; first_position : int; position : int }

let create ~id ~effects =
  match
    Base.List.fold_result effects
      ~init:(Base.Map.empty (module Identifier.Effect_key), 1)
      ~f:(fun (seen, position) change ->
        match Effect.key change with
        | None -> Ok (seen, position + 1)
        | Some key -> (
            match Base.Map.find seen key with
            | Some first_position -> Error (Duplicate_effect_key { key; first_position; position })
            | None -> Ok (Base.Map.set seen ~key ~data:position, position + 1)))
  with
  | Error error -> Error error
  | Ok _ -> Ok { id; effects }

let id event = event.id
let effects event = event.effects
