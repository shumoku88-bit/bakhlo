(* The append-only store on synthetic files: every save is one fsynced record, a
   cold load always yields the saved book, interruptions never yield a partial book,
   and compaction keeps the same book while retaining one previous file. *)
open Base
module F = Daily_file
module B = Bakhlo_sexp.Daily_book
module L = Bakhlo_sexp.Book_log
module O = Daily_book_oracle_tests

let get = function Ok x -> x | Error why -> failwith why

let fresh_path () =
  let dir = Stdlib.Filename.temp_dir "bakhlo-store-" "" in
  Stdlib.Filename.concat dir "book.sexp"

let start () =
  let path = fresh_path () in
  F.write_new path (B.to_string (get (B.of_string O.fixture)));
  F.load path

let entry n : B.entry =
  { id = Printf.sprintf "e%d" n; day = "2026-10-05"; memo = Some "lunch \"x\"\n"; reversal_of = None;
    effects = [ O.posting "wallet" "jpy" (-100); O.posting "food" "jpy" 100 ];
    exchange = None; original_amount = None; merchant = None }

let put n = L.Put_entry { replace = false; entry = entry n; plan = None }
let book_text (s : F.t) = B.to_string s.book
let written = function F.Written s -> s | _ -> failwith "expected Written"
let describe = function
  | F.Written _ -> "written" | F.Conflict -> "conflict" | F.Refused_input why -> "refused " ^ why
  | F.Uncertain _ -> "uncertain"

let%expect_test "each save appends one record and a cold load yields the saved book" =
  let s = ref (start ()) in
  for n = 1 to 5 do
    s := written (F.append !s [ put n ])
  done;
  let cold = F.load !s.path in
  Stdio.printf "records %d; bytes match file: %b; same book: %b; wallet %s\n" cold.records
    (String.equal (F.revision_of_bytes (F.read !s.path)) !s.revision)
    (String.equal (book_text cold) (book_text !s))
    (O.observable cold.book |> String.split_lines |> List.find_exn ~f:(String.is_prefix ~prefix:"wallet/jpy"));
  [%expect {| records 5; bytes match file: true; same book: true; wallet wallet/jpy: 49500 (observation) |}]

let%expect_test "a refused operation or a changed file writes nothing" =
  let s = written (F.append (start ()) [ put 1 ]) in
  let before = F.read s.path in
  Stdio.printf "duplicate: %s\n" (describe (F.append s [ put 1 ]));
  Stdio.printf "batch with a refused op: %s\n" (describe (F.append s [ put 2; put 1 ]));
  Stdio.printf "unchanged: %b\n" (String.equal (F.read s.path) before);
  let other = written (F.append (F.load s.path) [ put 7 ]) in
  Stdio.printf "stale session: %s; other writer kept: %b\n" (describe (F.append s [ put 8 ]))
    (String.equal (F.revision_of_bytes (F.read s.path)) other.revision);
  [%expect {|
    duplicate: refused duplicate-entry
    batch with a refused op: refused duplicate-entry
    unchanged: true
    stale session: conflict; other writer kept: true
    |}]

let%expect_test "an interruption after the line is sent is uncertain and confirmable" =
  List.iter [ F.Appended; F.Synced ] ~f:(fun step ->
      let s = start () in
      match F.append ~checkpoint:(fun r -> if Poly.equal r step then raise (Sys_error "fault")) s [ put 1 ] with
      | F.Uncertain { expected } ->
          let cold = F.load s.path in
          Stdio.printf "uncertain; confirmed on reload: %b; not torn: %b\n"
            (F.confirms ~expected cold) (not cold.torn)
      | other -> Stdio.printf "%s\n" (describe other));
  [%expect {|
    uncertain; confirmed on reload: true; not torn: true
    uncertain; confirmed on reload: true; not torn: true
    |}]

let%expect_test "a torn final line stops writes until it is explicitly discarded" =
  let s = written (F.append (start ()) [ put 1 ]) in
  let line = L.record_line ~seq:2 [ put 2 ] in
  let oc = Stdio.Out_channel.create ~append:true s.path in
  Stdio.Out_channel.output_string oc (String.prefix line (String.length line / 2));
  Stdio.Out_channel.close oc;
  let torn = F.load s.path in
  Stdio.printf "torn: %b; records %d; report %d bytes\n" torn.torn torn.records
    (F.inspect_recovery s.path).torn_bytes;
  Stdio.printf "append: %s\n" (describe (F.append torn [ put 3 ]));
  let removed, after = F.discard_torn_tail s.path in
  Stdio.printf "discarded %d bytes; same book as before: %b\n" removed
    (String.equal (book_text after) (book_text s));
  Stdio.printf "append after discard: %s\n" (describe (F.append after [ put 3 ]));
  [%expect {|
    torn: true; records 1; report 167 bytes
    append: refused torn-tail
    discarded 167 bytes; same book as before: true
    append after discard: written
    |}]

let%expect_test "compaction keeps the book and the previous file, even when interrupted" =
  let s = ref (start ()) in
  for n = 1 to 3 do
    s := written (F.append !s [ put n ])
  done;
  let old_bytes = F.read !s.path in
  (match F.compact !s with
  | F.Compacted c ->
      Stdio.printf "records %d; same book: %b; prev is old file: %b\n" c.records
        (String.equal (book_text c) (book_text !s))
        (String.equal (F.read (F.prev_path c.path)) old_bytes)
  | _ -> Stdio.printf "not compacted\n");
  List.iter [ F.Snapshot_written; F.Previous_kept; F.Replaced ] ~f:(fun step ->
      let s = ref (start ()) in
      s := written (F.append !s [ put 1 ]);
      let result = F.compact ~checkpoint:(fun r -> if Poly.equal r step then raise (Sys_error "fault")) !s in
      let cold = F.load !s.path in
      Stdio.printf "%s; same book: %b\n"
        (match result with F.Compaction_uncertain -> "uncertain" | F.Compacted _ -> "compacted"
                         | F.Not_compacted why -> "not compacted " ^ why)
        (String.equal (book_text cold) (book_text !s));
      match F.compact cold with
      | F.Compacted again ->
          let leftovers =
            Stdlib.Sys.readdir (Stdlib.Filename.dirname again.path) |> Array.to_list
            |> List.count ~f:(String.is_substring ~substring:".compact-")
          in
          Stdio.printf "retry compacted; temporaries left %d\n" leftovers
      | _ -> Stdio.printf "retry failed\n");
  [%expect {|
    records 0; same book: true; prev is old file: true
    uncertain; same book: true
    retry compacted; temporaries left 0
    uncertain; same book: true
    retry compacted; temporaries left 0
    uncertain; same book: true
    retry compacted; temporaries left 0
    |}]

(* A writer killed while holding the lock: the file still loads to the old or the
   new book, never a partial one, and the lock is released. *)
let%expect_test "a killed writer leaves the old or the new book" =
  List.iter [ F.Appended; F.Synced ] ~f:(fun step ->
      let s = start () in
      let input, output = Unix.pipe () in
      match Unix.fork () with
      | 0 ->
          Unix.close input;
          ignore
            (F.append
               ~checkpoint:(fun r ->
                 if Poly.equal r step then (
                   ignore (Unix.write_substring output "!" 0 1);
                   Unix.sleep 3600))
               s [ put 1 ]);
          Unix._exit 2
      | pid ->
          Unix.close output;
          let ready, _, _ = Unix.select [ input ] [] [] 10. in
          if List.is_empty ready then failwith "child never reached checkpoint";
          Unix.kill pid Stdlib.Sys.sigkill;
          ignore (Unix.waitpid [] pid);
          Unix.close input;
          let cold = F.load s.path in
          Stdio.printf "records %d; torn %b; next save: %s\n" cold.records cold.torn
            (describe (F.append cold [ put 2 ])));
  [%expect {|
    records 1; torn false; next save: written
    records 1; torn false; next save: written
    |}]

let%expect_test "a book without a final newline still gets records on their own lines" =
  let path = fresh_path () in
  F.write_new path (String.rstrip (B.to_string (get (B.of_string O.fixture))));
  let s = written (F.append (F.load path) [ put 1 ]) in
  let s = written (F.append s [ put 2 ]) in
  let cold = F.load path in
  Stdio.printf "records %d; same book: %b\n" cold.records (String.equal (book_text cold) (book_text s));
  [%expect {| records 2; same book: true |}]
