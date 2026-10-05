open Base

let parse text =
  let digits =
    if String.is_empty text then ""
    else
      match text.[0] with
      | '+' | '-' -> String.drop_prefix text 1
      | _ -> text
  in
  if String.is_empty digits || not (String.for_all digits ~f:Char.is_digit)
  then None
  else Some (Bakhlo_domain.Quantity.of_quanta (Z.of_string text))
;;
