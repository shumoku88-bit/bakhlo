(* The book.txt store on synthetic files: every save rewrites the whole file and keeps
   the previous one as .prev, a cold load always yields the saved book, interruptions
   and killed writers never yield a partial book, and nothing but book.txt is read. *)
open Base
module F = Daily_file
module B = Bakhlo_household.Daily_book
module X = Bakhlo_household.Daily_txt
module O = Daily_book_oracle_tests

let get = function Ok x -> x | Error why -> failwith why

let fresh_path () =
  let dir = Stdlib.Filename.temp_dir "bakhlo-store-" "" in
  Stdlib.Filename.concat dir "book.txt"

let start () =
  let path = fresh_path () in
  F.write_new path O.fixture;
  F.load path

let entry n : B.entry =
  {
    id = Printf.sprintf "e%d" n;
    day = "2026-10-05";
    memo = Some "lunch \"x\"\n";
    reversal_of = None;
    effects = [ O.posting "wallet" "jpy" (-100); O.posting "food" "jpy" 100 ];
    exchange = None;
    original_amount = None;
    merchant = None;
  }

let put n = B.Put_entry { replace = false; entry = entry n; plan = None }
let book_text (s : F.t) = O.text_of s.book
let written = function F.Written s -> s | _ -> failwith "expected Written"

let describe = function
  | F.Written _ -> "written"
  | F.Conflict -> "conflict"
  | F.Refused_input why -> "refused " ^ why
  | F.Uncertain _ -> "uncertain"

let historical_start () =
  let path = fresh_path () in
  F.write_new path O.hidden_fixture;
  F.load path

let find_entry book id =
  List.find_exn (B.entries book) ~f:(fun (candidate : B.entry) -> String.equal candidate.id id)

let temporaries path =
  Stdlib.Sys.readdir (Stdlib.Filename.dirname path)
  |> Array.to_list
  |> List.count ~f:(String.is_substring ~substring:".publish-")

let%expect_test "auxiliary file replacement shares cleanup, never a book previous copy" =
  let path = fresh_path () in
  F.with_writer path (fun () -> F.write_atomic path "first\n");
  F.with_writer path (fun () -> F.write_atomic path "second\n");
  Stdio.printf "replaced: %b; previous copy: %b\n"
    (String.equal (F.read path) "second\n")
    (Stdlib.Sys.file_exists (F.prev_path path));
  let blocked = fresh_path () in
  Unix.mkdir blocked 0o700;
  let before = Stdlib.Sys.readdir (Stdlib.Filename.dirname blocked) |> Array.length in
  let refused =
    match F.write_atomic blocked "refused\n" with
    | () -> false
    | exception Unix.Unix_error _ -> true
  in
  let after = Stdlib.Sys.readdir (Stdlib.Filename.dirname blocked) |> Array.length in
  Stdio.printf "rename refused: %b; target retained: %b; temporary removed: %b\n" refused
    (Poly.equal (Unix.lstat blocked).st_kind Unix.S_DIR)
    (before = after);
  [%expect
    {|
    replaced: true; previous copy: false
    rename refused: true; target retained: true; temporary removed: true
    |}]

let%expect_test "each save rewrites book.txt, keeps the previous file and a cold load yields it" =
  let s = ref (start ()) in
  let before = ref (F.read !s.path) in
  let prev_ok = ref true in
  for n = 1 to 5 do
    s := written (F.publish !s [ put n ]);
    prev_ok := !prev_ok && String.equal (F.read (F.prev_path !s.path)) !before;
    before := F.read !s.path
  done;
  let cold = F.load !s.path in
  Stdio.printf "entries %d; bytes match file: %b; same book: %b; prev is the file before: %b; %s\n"
    (List.length (B.entries cold.book))
    (String.equal (F.revision_of_bytes (F.read !s.path)) !s.revision)
    (String.equal (book_text cold) (book_text !s))
    !prev_ok
    (O.observable cold.book |> String.split_lines
    |> List.find_exn ~f:(String.is_prefix ~prefix:"wallet/jpy"));
  [%expect
    {| entries 6; bytes match file: true; same book: true; prev is the file before: true; wallet/jpy: 49500 (observation) |}]

let%expect_test "a saved date correction survives a cold load and preserves the entry" =
  let s = historical_start () in
  let before = find_entry s.book "init" in
  let saved = written (F.publish s [ B.Correct_entry_date { id = "init"; day = "2026-10-09" } ]) in
  let cold = F.load saved.path in
  let after = find_entry cold.book "init" in
  Stdio.printf "date %s; all other fields preserved: %b; same book: %b\n" after.day
    (Poly.equal before { after with day = before.day })
    (String.equal (book_text cold) (book_text saved));
  [%expect {| date 2026-10-09; all other fields preserved: true; same book: true |}]

let%expect_test "a refused date correction writes nothing" =
  let s = historical_start () in
  let before = F.read s.path in
  Stdio.printf "unknown: %s\n"
    (describe (F.publish s [ B.Correct_entry_date { id = "missing"; day = "2026-10-09" } ]));
  Stdio.printf "invalid date: %s\n"
    (describe (F.publish s [ B.Correct_entry_date { id = "init"; day = "2026-02-30" } ]));
  Stdio.printf "unchanged: %b\n" (String.equal before (F.read s.path));
  [%expect
    {|
    unknown: refused unknown-entry
    invalid date: refused invalid-date
    unchanged: true
    |}]

let%expect_test "a refused operation or a changed file writes nothing" =
  let s = written (F.publish (start ()) [ put 1 ]) in
  let before = F.read s.path in
  Stdio.printf "duplicate: %s\n" (describe (F.publish s [ put 1 ]));
  Stdio.printf "batch with a refused op: %s\n" (describe (F.publish s [ put 2; put 1 ]));
  Stdio.printf "unchanged: %b\n" (String.equal (F.read s.path) before);
  let other = written (F.publish (F.load s.path) [ put 7 ]) in
  Stdio.printf "stale session: %s; other writer kept: %b\n"
    (describe (F.publish s [ put 8 ]))
    (String.equal (F.revision_of_bytes (F.read s.path)) other.revision);
  [%expect
    {|
    duplicate: refused duplicate-entry
    batch with a refused op: refused duplicate-entry
    unchanged: true
    stale session: conflict; other writer kept: true
    |}]

let%expect_test
    "an interrupted save is uncertain, leaves the old or the new book and is confirmable" =
  List.iter [ F.Temp_written; F.Previous_kept; F.Replaced ] ~f:(fun step ->
      let s = start () in
      let old_text = book_text s in
      match
        F.publish
          ~checkpoint:(fun r -> if Poly.equal r step then raise (Sys_error "fault"))
          s
          [ put 1 ]
      with
      | F.Uncertain { expected } ->
          let cold = F.load s.path in
          let next = written (F.publish cold [ put 2 ]) in
          Stdio.printf
            "uncertain; new book on disk: %b; old book otherwise: %b; next save leaves %d \
             temporaries\n"
            (F.confirms ~expected cold)
            (F.confirms ~expected cold || String.equal (book_text cold) old_text)
            (temporaries next.path)
      | other -> Stdio.printf "%s\n" (describe other));
  [%expect
    {|
    uncertain; new book on disk: false; old book otherwise: true; next save leaves 0 temporaries
    uncertain; new book on disk: false; old book otherwise: true; next save leaves 0 temporaries
    uncertain; new book on disk: true; old book otherwise: true; next save leaves 0 temporaries
    |}]

(* A writer killed while holding the lock: the file still loads to the old or the
   new book, never a partial one, and the lock is released. *)
let%expect_test "a killed writer leaves the old or the new book" =
  List.iter [ F.Temp_written; F.Previous_kept; F.Replaced ] ~f:(fun step ->
      let s = start () in
      let old_text = book_text s in
      let input, output = Unix.pipe () in
      match Unix.fork () with
      | 0 ->
          Unix.close input;
          ignore
            (F.publish
               ~checkpoint:(fun r ->
                 if Poly.equal r step then (
                   ignore (Unix.write_substring output "!" 0 1);
                   Unix.sleep 3600))
               s
               [ put 1 ]);
          Unix._exit 2
      | pid ->
          Unix.close output;
          let ready, _, _ = Unix.select [ input ] [] [] 10. in
          if List.is_empty ready then failwith "child never reached checkpoint";
          Unix.kill pid Stdlib.Sys.sigkill;
          ignore (Unix.waitpid [] pid);
          Unix.close input;
          let cold = F.load s.path in
          let has_e1 =
            List.exists (B.entries cold.book) ~f:(fun (e : B.entry) -> String.equal e.id "e1")
          in
          Stdio.printf "%s book; next save: %s\n"
            (if has_e1 then "new"
             else if String.equal (book_text cold) old_text then "old"
             else "OTHER")
            (describe (F.publish cold [ put 2 ])));
  [%expect
    {|
    old book; next save: written
    old book; next save: written
    new book; next save: written
    |}]

let%expect_test "only book.txt is read: an S-expression book refuses, nothing is converted" =
  let path = fresh_path () in
  F.write_new path "(bakhlo-daily 3) (scope corrected-entries explicit-plans)\n";
  let before = F.read path in
  Stdio.printf "%s; file unchanged: %b\n"
    (match F.load path with _ -> "loaded" | exception F.Refused why -> "refused " ^ why)
    (String.equal before (F.read path));
  [%expect {| refused book-refused: bad-header at line 1; file unchanged: true |}]

let%expect_test "roles and Attention are saved in book.txt and read back as written" =
  let s = start () in
  let sidecars : X.sidecars =
    {
      roles = "LOAM-ACCOUNTING-ROLE-MAP\t1\nROLE\twallet\tASSET\nROLE\tfood\tEXPENSE\n";
      attention = "LOAM-ATTENTION-MEMORY\t1\nITEM\tattention-1\tNO_DUE_DATE\t-\tcheck\\tthis\n";
    }
  in
  let saved = written (F.publish ~sidecars s []) in
  let cold = F.load saved.path in
  Stdio.printf "same roles: %b; same Attention: %b; same book: %b; in book.txt: %b\n"
    (String.equal cold.sidecars.roles saved.sidecars.roles)
    (String.equal cold.sidecars.attention saved.sidecars.attention)
    (String.equal (book_text cold) (book_text saved))
    (String.is_substring (F.read saved.path) ~substring:"ROLE\twallet\tASSET\n");
  let cleared = written (F.publish ~sidecars:X.no_sidecars saved []) in
  let cold = F.load cleared.path in
  Stdio.printf "cleared: %b\n"
    (String.equal cold.sidecars.roles "" && String.equal cold.sidecars.attention "");
  [%expect
    {|
    same roles: true; same Attention: true; same book: true; in book.txt: true
    cleared: true
    |}]
