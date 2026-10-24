(* book.txt -> Daily_book -> book.txt is the identity, and the Daily_book in between
   answers like the book.txt value (Daily_to_book_txt.check). *)
module X = Bakhlo_sexp.Daily_txt
module T = Bakhlo_book_txt.Book_txt
module C = Bakhlo_migrate.Daily_to_book_txt

let read path = In_channel.with_open_bin path In_channel.input_all

let round_trip text =
  match T.of_string text with
  | Error e -> Error (Printf.sprintf "not admitted: %s at %d" (T.code_name e.code) e.line)
  | Ok t -> (
      match X.of_txt t with
      | Error why -> Error ("of_txt: " ^ why)
      | Ok (book, sidecars) -> (
          match (C.check book t, X.to_txt book sidecars) with
          | Error why, _ -> Error ("check: " ^ why)
          | _, Error why -> Error ("to_txt: " ^ why)
          | Ok _, Ok (back, _) -> if T.to_string back = text then Ok () else Error "reprinted text differs"))

let%expect_test "every accepted fixture survives Daily_book unchanged" =
  List.iter
    (fun name ->
      let result = round_trip (read (Filename.concat "common_format" name)) in
      Printf.printf "%s: %s\n" name (match result with Ok () -> "same bytes, same answers" | Error why -> why))
    [ "ok-empty.txt"; "ok-full.txt"; "ok-anchor-delta.txt"; "ok-anchor-start.txt" ];
  [%expect {|
    ok-empty.txt: same bytes, same answers
    ok-full.txt: same bytes, same answers
    ok-anchor-delta.txt: same bytes, same answers
    ok-anchor-start.txt: same bytes, same answers
    |}]

let%expect_test "generated books survive Daily_book unchanged" =
  let checks = ref 0 and failures = ref [] in
  Base_quickcheck.Test.run_exn
    (module Book_txt_tests.Generated)
    ~config:{ Base_quickcheck.Test.default_config with seed = Deterministic "daily-txt-v1"; test_count = 2_000 }
    ~f:(fun t ->
      incr checks;
      match round_trip (T.to_string t) with
      | Ok () -> ()
      | Error why -> if List.length !failures < 3 then failures := why :: !failures);
  Printf.printf "%d generated books; failures: %s\n" !checks
    (match !failures with [] -> "none" | fs -> String.concat " | " (List.rev fs));
  [%expect {| 2000 generated books; failures: none |}]

let%expect_test "a converted household is already in the stable form" =
  let sidecars : X.sidecars =
    { roles = Daily_to_book_txt_tests.roles; attention = Daily_to_book_txt_tests.attention }
  in
  match Bakhlo_sexp.Book_log.load (Daily_to_book_txt_tests.book Daily_to_book_txt_tests.entries) with
  | Error why -> print_endline why
  | Ok loaded -> (
      match X.to_txt loaded.book sidecars with
      | Error why -> print_endline why
      | Ok (t, _) ->
          print_endline
            (match round_trip (T.to_string t) with Ok () -> "stable after one conversion" | Error why -> why);
          [%expect {| stable after one conversion |}])
