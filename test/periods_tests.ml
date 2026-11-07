(* Periods as language-neutral answers.

   Each sample in test/periods is a boundary-presets.tsv (or none) and a list of
   questions, one per line, each followed on the same line by its answer. The
   files are the specification a rewrite must pass (test/periods/README.md); this
   runner only proves Bakhlo's Period agrees. *)
module P = Bakhlo_household.Period

let dir = "periods"
let read name = In_channel.with_open_bin (Filename.concat dir name) In_channel.input_all
let lines text = List.filter (fun l -> l <> "") (String.split_on_char '\n' text)
let fields = String.split_on_char '\t'

exception Bad_sample of string

let bad why = raise (Bad_sample why)

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
let answer config line =
  let pair = function Ok (a, b) -> a ^ "\t" ^ b | Error why -> "REFUSED\t" ^ P.code why in
  match fields line with
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
  | _ -> bad ("question " ^ line)

let%expect_test "every period sample gives its listed answer" =
  let failures = ref 0 and answers = ref 0 in
  let fail name why =
    incr failures;
    Printf.printf "FAIL %s: %s\n" name why
  in
  List.iter
    (fun row ->
      match fields row with
      | [ name; presets; _note ] -> (
          try
            let config = if presets = "-" then None else Some (read presets) in
            List.iter
              (fun line ->
                incr answers;
                let got = answer config line in
                if got <> line then fail name ("want " ^ line ^ "\n  got  " ^ got))
              (lines (read (name ^ ".answers")))
          with Bad_sample why -> fail name ("bad sample: " ^ why))
      | _ -> fail row "bad cases row")
    (List.tl (lines (read "cases.tsv")));
  Printf.printf "%d answers, %d failures\n" !answers !failures;
  [%expect {| 58 answers, 0 failures |}]
