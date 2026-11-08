(* Locus rules (loci/rules.answers): roles once, seen balances only where the
   records do not already decide the balance. *)
module B = Bakhlo_household.Book
open Samples

let answer use (q : question) =
  let book =
    match context use "BOOK" with
    | Some name -> ( match B.read (read "loci" name) with Ok b -> b | Error why -> bad why)
    | None -> bad "USE BOOK required"
  in
  let verdict = function None -> [ "OK" ] | Some why -> [ "REFUSED"; why ] in
  match q.header with
  | "ROLE" :: locus :: _ -> [ row ([ "ROLE"; locus ] @ verdict (B.role_refusal book locus)) ]
  | "OBSERVE" :: locus :: measure :: _ ->
      [ row ([ "OBSERVE"; locus; measure ] @ verdict (B.observation_refusal book ~locus ~measure)) ]
  | _ -> bad ("question " ^ row q.header)

let%expect_test "Locus rules give their listed answers" =
  let counts = create () in
  check counts ~dir:"loci" ~file:"rules.answers" ~blocks:[] ~answer;
  Printf.printf "%d answers, %d failures\n" counts.answers counts.failures;
  [%expect {| 7 answers, 0 failures |}]
