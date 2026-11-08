module P = Bakhlo_household.Period

let bad = Samples.bad

let span = function
  | "DAY" -> P.Day
  | "MONTH" -> P.Month
  | "YEAR" -> P.Year
  | "CYCLE" -> P.Cycle
  | "PREVIOUS-CYCLE" -> P.Previous_cycle
  | "ALL" -> P.All
  | other -> bad ("span " ^ other)

let range name =
  match name with
  | "MONTH-TO-DATE" -> P.Month_to_date
  | "CYCLE-TO-DATE" -> P.Cycle_to_date
  | "PREVIOUS-CYCLE" -> P.Whole_previous_cycle
  | _ -> (
      match String.split_on_char '-' name with
      | [ "LAST"; "DAYS"; n ] -> (
          match int_of_string_opt n with Some n -> P.Last_days n | None -> bad ("range " ^ name))
      | _ -> bad ("range " ^ name))

(* The answer to one question, printed as the line that should hold it. *)
let answer_line use (q : Samples.question) =
  let config = Option.map (Samples.read "periods") (Samples.context use "PRESETS") in
  let line = Samples.row q.header in
  let pair = function Ok (a, b) -> a ^ "\t" ^ b | Error why -> "REFUSED\t" ^ P.code why in
  match q.header with
  | "CYCLE" :: day :: _ ->
      String.concat "\t"
        [
          "CYCLE";
          day;
          (match Result.bind (P.read config) (P.cycle ~day) with
          | Ok c ->
              let start, stop = List.nth c.windows c.index in
              String.concat "\t" [ c.name; start; stop ]
          | Error why -> "REFUSED\t" ^ P.code why);
        ]
  | "WINDOW" :: day :: s :: offset :: _ ->
      let offset = match int_of_string_opt offset with Some n -> n | None -> bad "offset" in
      String.concat "\t"
        [ "WINDOW"; day; s; string_of_int offset; pair (P.window ~config ~day (span s) ~offset) ]
  | "RANGE" :: today :: r :: _ ->
      String.concat "\t" [ "RANGE"; today; r; pair (P.range ~config ~today (range r)) ]
  | "ELAPSED" :: today :: start :: stop :: _ ->
      let elapsed, total = P.elapsed ~today (start, stop) in
      String.concat "\t"
        [ "ELAPSED"; today; start; stop; string_of_int elapsed; string_of_int total ]
  | "SAME-AGE" :: start :: stop :: days :: _ ->
      let days = match int_of_string_opt days with Some n -> n | None -> bad "days" in
      let first, last = P.same_age (start, stop) days in
      String.concat "\t" [ "SAME-AGE"; start; stop; string_of_int days; first; last ]
  | _ -> bad ("question " ^ line)

let answer use q = [ answer_line use q ]

let%expect_test "every period sample gives its listed answer" =
  let counts = Samples.create () in
  Samples.run counts ~dir:"periods" ~blocks:[] ~answer;
  Printf.printf "%d answers, %d failures\n" counts.answers counts.failures;
  [%expect {| 73 answers, 0 failures |}]
