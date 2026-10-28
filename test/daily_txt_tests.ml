(* book.txt -> Book -> book.txt is the identity, the roles and Attention sections
   read and print in their text formats, and what book.txt cannot hold refuses. *)
module X = Bakhlo_household.Daily_txt
module T = Bakhlo_book_txt.Book_txt
module B = Bakhlo_household.Book
module D = Bakhlo_domain

let read path = In_channel.with_open_bin path In_channel.input_all

(* Read into a Book, then print it with the sections it read. *)
let round_trip text =
  match T.read text with
  | Error e -> Error (Printf.sprintf "not admitted: %s at %d" (T.code_name e.code) e.line)
  | Ok txt -> (
      match B.of_txt txt with
      | Error why -> Error ("of_txt: " ^ why)
      | Ok book ->
          let back = X.text ~sidecars:(X.sidecars_of book) book in
          if back = text then Ok () else Error "reprinted text differs")

let%expect_test "every accepted fixture survives Book unchanged" =
  List.iter
    (fun name ->
      let result = round_trip (read (Filename.concat "common_format" name)) in
      Printf.printf "%s: %s\n" name (match result with Ok () -> "same bytes" | Error why -> why))
    [
      "ok-empty.txt";
      "ok-full.txt";
      "ok-anchor-delta.txt";
      "ok-anchor-start.txt";
      "ok-exchange-reversal.txt";
    ];
  [%expect
    {|
    ok-empty.txt: same bytes
    ok-full.txt: same bytes
    ok-anchor-delta.txt: same bytes
    ok-anchor-start.txt: same bytes
    ok-exchange-reversal.txt: same bytes
    |}]

let%expect_test "generated books survive Book unchanged" =
  let checks = ref 0 and failures = ref [] in
  Base_quickcheck.Test.run_exn
    (module Book_txt_tests.Generated)
    ~config:
      {
        Base_quickcheck.Test.default_config with
        seed = Deterministic "daily-txt-v1";
        test_count = 2_000;
      }
    ~f:(fun t ->
      incr checks;
      match round_trip (T.to_string t) with
      | Ok () -> ()
      | Error why -> if List.length !failures < 3 then failures := why :: !failures);
  Printf.printf "%d generated books; failures: %s\n" !checks
    (match !failures with [] -> "none" | fs -> String.concat " | " (List.rev fs));
  [%expect {| 2000 generated books; failures: none |}]

let%expect_test "malformed sections refuse instead of disappearing" =
  let book = X.book (read "common_format/ok-full.txt") in
  let sidecars = X.sidecars_of book in
  let show label s =
    Printf.printf "%s: %s\n" label
      (match X.with_sidecars book s with Ok _ -> "kept" | Error why -> why)
  in
  show "roles header" { sidecars with roles = "ROLE\tbank\tASSET\n" };
  show "suspense role" { sidecars with roles = sidecars.roles ^ "ROLE\tsuspense\tASSET\n" };
  show "attention header" { sidecars with attention = "ITEM\tx\tNO_DUE_DATE\t-\tc\n" };
  [%expect
    {|
    roles header: accounting-roles-bad-header
    suspense role: book-txt-suspense-role
    attention header: attention-bad-header
    |}]

(* book.txt names an exchange by its Measures; an exchange with a second positive
   Effect in its destination Measure cannot be read back as the same entry, so a save
   refuses it instead of writing it. *)
let%expect_test "an exchange book.txt cannot read back is refused, never written" =
  let book = X.book (read "common_format/ok-full.txt") in
  let leg ?key l m q =
    D.Effect.create
      ~key:(Option.map (fun k -> Result.get_ok (D.Identifier.Effect_key.of_string k)) key)
      ~locus:(Result.get_ok (D.Identifier.Locus.of_string l))
      ~measure:(Result.get_ok (D.Identifier.Measure.of_string m))
      ~quantity:(D.Quantity.of_quanta (Z.of_int q))
  in
  let entry : B.entry =
    {
      id = "fx-extra";
      day = "2027-02-01";
      memo = None;
      effects =
        [
          leg ~key:"s" "wallet" "jpy" (-1500);
          leg ~key:"d" "wallet" "usd" 1000;
          leg "food" "usd" 50;
          leg "fee" "usd" (-50);
        ];
      reversal_of = None;
      exchange = Some ("s", "d");
      original_amount = None;
      merchant = None;
    }
  in
  Printf.printf "save: %s\n"
    (match B.put_entry book ~replace:false entry ~plan:None with
    | Ok _ -> "written"
    | Error why -> why);
  [%expect {| save: entry-admission |}]
