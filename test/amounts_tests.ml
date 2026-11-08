module A = Bakhlo_household.Amount

(* The answers are hand-written; only input fields are interpreted here. *)
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

let%expect_test "typed amount samples" =
  let failures = ref 0 in
  let rows =
    In_channel.with_open_bin "amounts/input.answers" In_channel.input_all
    |> String.split_on_char '\n'
    |> List.filter (fun s -> s <> "")
  in
  List.iteri
    (fun index line ->
      let fields = String.split_on_char '\t' line in
      let got, want =
        match fields with
        | [ "FORMAT"; scale; quanta; want ] ->
            (A.format ~decimals:(int_of_string scale) (Z.of_string quanta), want)
        | (("POSITIVE" | "SIGNED") as kind) :: scale :: input :: answer ->
            let parse = if kind = "POSITIVE" then A.parse_positive else A.parse_signed in
            let got =
              match parse ~decimals:(int_of_string scale) (text input) with
              | Ok n -> [ Z.to_string n ]
              | Error code -> [ "REFUSED"; code ]
            in
            (String.concat "\t" got, String.concat "\t" answer)
        | _ -> failwith ("bad amount sample: " ^ line)
      in
      if got <> want then (
        incr failures;
        Printf.printf "FAIL amounts/input.answers:%d: want %s, got %s\n" (index + 1) want got))
    rows;
  Printf.printf "%d amount answers, %d failures\n" (List.length rows) !failures;
  [%expect {| 78 amount answers, 0 failures |}]
