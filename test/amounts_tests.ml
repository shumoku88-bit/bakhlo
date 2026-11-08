module A = Bakhlo_household.Amount

let text s =
  let b = Buffer.create (String.length s) in
  let rec loop i =
    if i < String.length s then
      if s.[i] = '\\' && i + 1 < String.length s then (
        Buffer.add_char b
          (match s.[i + 1] with
          | 't' -> '\t'
          | 'r' -> '\r'
          | 'n' -> '\n'
          | '\\' -> '\\'
          | _ -> failwith "unknown amount sample escape");
        loop (i + 2))
      else (
        Buffer.add_char b s.[i];
        loop (i + 1))
  in
  loop 0;
  Buffer.contents b

let answer _use (q : Samples.question) =
  let result =
    match q.header with
    | [ "FORMAT"; scale; quanta; _want ] ->
        [ "FORMAT"; scale; quanta; A.format ~decimals:(int_of_string scale) (Z.of_string quanta) ]
    | (("POSITIVE" | "SIGNED") as kind) :: scale :: input :: _ -> (
        let parse = if kind = "POSITIVE" then A.parse_positive else A.parse_signed in
        [ kind; scale; input ]
        @
        match parse ~decimals:(int_of_string scale) (text input) with
        | Ok n -> [ Z.to_string n ]
        | Error code -> [ "REFUSED"; code ])
    | _ -> Samples.bad "amount question"
  in
  [ Samples.row result ]

let%expect_test "typed amount samples" =
  let counts = Samples.create () in
  Samples.run counts ~dir:"amounts" ~blocks:[] ~answer;
  Printf.printf "%d amount answers, %d failures\n" counts.answers counts.failures;
  [%expect {| 78 amount answers, 0 failures |}]
