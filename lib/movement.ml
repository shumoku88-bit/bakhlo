(* Qualify collections: opening Base would shadow the domain Effect module. *)

type t = { measure : Identifier.Measure.t; effects : Effect.t list }

type error =
  | Empty
  | Zero_quantity of { position : int }
  | Measure_mismatch of {
      position : int;
      expected : Identifier.Measure.t;
      actual : Identifier.Measure.t;
    }
  | Unbalanced of { measure : Identifier.Measure.t; residual : Quantity.t }

let validate effects =
  match effects with
  | [] -> Error [ Empty ]
  | first :: _ -> (
      let measure = Effect.measure first in
      let shape_errors =
        Base.List.concat_mapi effects ~f:(fun index change ->
            let position = index + 1 in
            let zero =
              if Quantity.equal (Effect.quantity change) Quantity.zero then
                [ Zero_quantity { position } ]
              else []
            in
            let actual = Effect.measure change in
            let mismatch =
              if Identifier.Measure.equal measure actual then []
              else [ Measure_mismatch { position; expected = measure; actual } ]
            in
            zero @ mismatch)
      in
      match shape_errors with
      | _ :: _ -> Error shape_errors
      | [] ->
          let residual = Quantity.sum (Base.List.map effects ~f:Effect.quantity) in
          if Quantity.equal residual Quantity.zero then Ok { measure; effects }
          else Error [ Unbalanced { measure; residual } ])

let measure movement = movement.measure
let effects movement = movement.effects

let positive_total movement =
  Base.List.fold movement.effects ~init:Quantity.zero ~f:(fun total change ->
      let quantity = Effect.quantity change in
      if Quantity.compare quantity Quantity.zero > 0 then Quantity.add total quantity else total)
