open Base

module A = Loam_application.Movement_check
module D = Loam_domain

let signed quantity =
  let text = Z.to_string (D.Quantity.quanta quantity) in
  if D.Quantity.compare quantity D.Quantity.zero > 0 then "+" ^ text else text
;;

let describe_error = function
  | D.Movement.Empty -> "at least one Effect is required."
  | D.Movement.Zero_quantity { position } ->
    Stdlib.Printf.sprintf "Effect %d: quantity must be nonzero." position
  | D.Movement.Measure_mismatch { position; expected; actual } ->
    Stdlib.Printf.sprintf
      "Effect %d: Measure %S differs from %S."
      position
      (D.Identifier.Measure.to_string actual)
      (D.Identifier.Measure.to_string expected)
  | D.Movement.Unbalanced { measure; residual } ->
    Stdlib.Printf.sprintf
      "Measure %S: residual %s quanta; expected 0."
      (D.Identifier.Measure.to_string measure)
      (signed residual)
;;

let preview answer =
  let lines =
    List.mapi (A.effects answer) ~f:(fun index change ->
      Stdlib.Printf.sprintf
        "  %d. %S: %s quanta\n"
        (index + 1)
        (D.Identifier.Locus.to_string (D.Effect.locus change))
        (signed (D.Effect.quantity change)))
  in
  Stdlib.Printf.sprintf
    "Movement structurally valid (not recorded).\nMeasure: %S\nEffects:\n%sPositive total: %s quanta\n"
    (D.Identifier.Measure.to_string (A.measure answer))
    (String.concat lines)
    (Z.to_string (D.Quantity.quanta (A.positive_total answer)))
;;

let refusal errors =
  let lines = List.map errors ~f:(fun error -> "  " ^ describe_error error ^ "\n") in
  "Movement refused (not recorded).\n" ^ String.concat lines
;;
