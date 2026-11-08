(* Finding records (queries/find.answers) by Bakhlo_household.Query alone. *)
module B = Bakhlo_household.Book
module Q = Bakhlo_household.Query
open Samples

let answer use (q : question) =
  let book =
    match context use "BOOK" with
    | Some name -> ( match B.read (read "queries" name) with Ok b -> b | Error why -> bad why)
    | None -> bad "USE BOOK required"
  in
  match q.header with
  | "FIND" :: terms ->
      row q.header
      ::
      (match Q.parse terms with
      | Error why -> [ "REFUSED\t" ^ why ]
      | Ok query -> List.map (fun (e : B.entry) -> "ENTRY\t" ^ e.id) (Q.find book query))
  | _ -> bad ("question " ^ row q.header)

let%expect_test "record queries give their listed answers" =
  let counts = create () in
  check counts ~dir:"queries" ~file:"find.answers" ~blocks:[ "FIND" ] ~answer;
  Printf.printf "%d queries, %d failures\n" counts.answers counts.failures;
  [%expect {| 32 queries, 0 failures |}]
