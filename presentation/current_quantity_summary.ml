module D = Bakhlo_domain
module A = Bakhlo_application.Current_quantity_answer

let location (coordinate : D.Effect_coordinate.t) =
  Printf.sprintf "%S / %S"
    (D.Identifier.Locus.to_string coordinate.locus)
    (D.Identifier.Measure.to_string coordinate.measure)

let render (answer : A.answer) =
  match answer with
  | Ok (A.Exact answer) ->
      let premise =
        match A.premise answer with
        | Zero_origin -> "明示されたゼロ起点"
        | Opening -> "明示された開始の根拠"
        | Current_assertion -> "明示された数量と、その根拠に未反映の差分"
      in
      Printf.sprintf "%s: この入力から求めた数量は %s quanta です。\n根拠の種類: %s。\n"
        (location (A.coordinate answer))
        (Z.to_string (D.Quantity.quanta (A.quantity answer)))
        premise
  | Ok (Known_present answer) ->
      Printf.sprintf
        "%s: この入力にはゼロではないという根拠がありますが、正確な数量はまだ分かりません。\n確認の手がかり: 正確な数量を示す根拠を確認してください（推測では埋めません）。\n"
        (location (A.present_coordinate answer))
  | Error (Support_unknown { coordinate }) ->
      Printf.sprintf "%s: この入力では数量を確定できません。0としては扱いません。\n確認の手がかり: 数量の根拠と、反映済みの記録の範囲を確認してください。\n"
        (location coordinate)
