open Base
module D = Bakhlo_domain
module Id = D.Identifier.Event

(* Original-list/fuel oracle, independent of production maps, terminal getters
   and constructor-derived roots. Used only with supplied valid path specimens. *)
let expected_pairs source corrections =
  let roots =
    List.filter source ~f:(fun original ->
        not
          (List.exists corrections ~f:(fun (c : D.Event_correction.t) ->
               Id.equal c.replacement (D.Event.id original))))
  in
  let rec follow fuel current =
    match
      List.find corrections ~f:(fun (c : D.Event_correction.t) -> Id.equal c.target current)
    with
    | None -> (
        match List.find source ~f:(fun original -> Id.equal (D.Event.id original) current) with
        | Some original -> original
        | None -> failwith "oracle endpoint absent")
    | Some c ->
        if fuel <= 0 then failwith "oracle cycle/fuel exhausted"
        else follow (fuel - 1) c.replacement
  in
  List.map roots ~f:(fun root -> (D.Event.id root, follow (List.length source) (D.Event.id root)))

(* Membership, NOT a sum predicate: cancelling Effects still touch a coordinate. *)
let touches_events events (coordinate : D.Effect_coordinate.t) =
  List.exists events ~f:(fun original ->
      List.exists (D.Event.effects original) ~f:(fun change ->
          D.Identifier.Locus.equal coordinate.locus (D.Effect.locus change)
          && D.Identifier.Measure.equal coordinate.measure (D.Effect.measure change)))

(* Direct Zarith sum over original Effects, never Effect_sum or projection totals. *)
let sum_events events (coordinate : D.Effect_coordinate.t) =
  List.fold events ~init:Z.zero ~f:(fun total original ->
      List.fold (D.Event.effects original) ~init:total ~f:(fun total change ->
          if
            D.Identifier.Locus.equal coordinate.locus (D.Effect.locus change)
            && D.Identifier.Measure.equal coordinate.measure (D.Effect.measure change)
          then Z.add total (D.Quantity.quanta (D.Effect.quantity change))
          else total))
