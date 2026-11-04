module B = Bakhlo_household.Book

let get = function Ok x -> x | Error why -> failwith why
let result_text = function Ok n -> Z.to_string n | Error why -> why

let%expect_test "amount entry points preserve their distinct input policies and refusal order" =
  let book = get (B.empty ~measure:"unit" ~scale:2) in
  let check measure text =
    Printf.printf "%s / %s\n"
      (result_text (B.parse_amount book ~measure text))
      (result_text (B.parse_signed_amount book ~measure text))
  in
  check "missing" "";
  check "missing" " ";
  check "missing" "0";
  check "unit" "0";
  check "unit" " 1 ";
  check "unit" "-1";
  check "unit" "１．２３";
  check "unit" "－１";
  check "unit" "1.000";
  check "unit" "1.000+0";
  check "unit" "1/3";
  [%expect
    {|
    unknown-measure / empty-amount
    unknown-measure / empty-amount
    unknown-measure / unknown-measure
    non-positive-amount / 0
    invalid-amount / 100
    invalid-amount / -100
    123 / 123
    invalid-amount / invalid-amount
    amount-precision / amount-precision
    100 / invalid-amount
    indivisible-amount / invalid-amount
    |}]

(* These receipt examples accompany Amount's explanation: a fraction during
   calculation is fine; a fraction of the final currency unit is not. *)
let%expect_test "receipt arithmetic stays exact until the final currency check" =
  let book = get (B.empty ~measure:"unit" ~scale:0) in
  List.iter
    (fun text ->
      Printf.printf "%s -> %s\n" text (result_text (B.parse_amount book ~measure:"unit" text)))
    [ "500+300"; "(500+300)/2"; "(100/3)*3"; "100/3"; "20/2/2"; "1/(2-2)"; "10-10" ];
  [%expect
    {|
    500+300 -> 800
    (500+300)/2 -> 400
    (100/3)*3 -> 100
    100/3 -> indivisible-amount
    20/2/2 -> 5
    1/(2-2) -> division-by-zero
    10-10 -> non-positive-amount
    |}]

(* Convenient spellings do not relax precision or repair malformed grouping.
   Adding an operator deliberately selects the final-value rule instead. *)
let%expect_test "literal precision differs from expression precision, not from input spelling" =
  let book = get (B.empty ~measure:"unit" ~scale:2) in
  List.iter
    (fun text ->
      Printf.printf "%s -> %s\n" text (result_text (B.parse_amount book ~measure:"unit" text)))
    [ "1.000"; "1.000+0"; "１．０００"; "１．０００＋０"; "１，２００＋３００"; "12,34" ];
  [%expect
    {|
    1.000 -> amount-precision
    1.000+0 -> 100
    １．０００ -> amount-precision
    １．０００＋０ -> 100
    １，２００＋３００ -> 150000
    12,34 -> invalid-amount
    |}]

let%expect_test "displayed exact quanta parse back at every admitted scale" =
  let values =
    [ Z.zero; Z.one; Z.of_int 12345; Z.of_string "123456789012345678901234567890123456789" ]
  in
  for decimals = 0 to 9 do
    let book = get (B.empty ~measure:"unit" ~scale:decimals) in
    List.iter
      (fun n ->
        List.iter
          (fun signed ->
            let text = B.format book "unit" signed in
            if not (Z.equal signed (get (B.parse_signed_amount book ~measure:"unit" text))) then
              failwith "signed display round trip";
            if
              Z.sign signed > 0
              && not (Z.equal signed (get (B.parse_amount book ~measure:"unit" text)))
            then failwith "positive display round trip")
          [ n; Z.neg n ])
      values
  done;
  print_endline "exact across scales 0..9";
  [%expect {| exact across scales 0..9 |}]
