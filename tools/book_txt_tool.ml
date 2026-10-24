(* The household's move to book.txt (docs/COMMON_FORMAT.ja.md), run by tools/book-txt.
   trial COPY_DIR OUT_DIR: convert a copied household and compare it with the source;
     reads only COPY_DIR, writes only OUT_DIR (counts on the terminal, names and IDs in
     OUT_DIR/report.txt, ignored scratch).
   migrate HOUSEHOLD_DIR: under the writer lock of book.sexp, convert and compare, write
     book.txt, read it back through the store and compare again; any mismatch removes the
     new book.txt and leaves the household as it was. Git is the shell script's job. *)
module C = Bakhlo_migrate.Daily_to_book_txt
module T = Bakhlo_book_txt.Book_txt
module L = Bakhlo_sexp.Book_log
module X = Bakhlo_sexp.Daily_txt
module F = Daily_file

let read path = In_channel.with_open_bin path In_channel.input_all
let read_opt path = if Sys.file_exists path then Some (read path) else None
let write path s = Out_channel.with_open_bin path (fun oc -> output_string oc s)

let median k f =
  let xs =
    Array.init k (fun _ ->
        Gc.full_major ();
        let t0 = Unix.gettimeofday () in
        ignore (Sys.opaque_identity (f ()));
        Unix.gettimeofday () -. t0)
  in
  Array.sort compare xs;
  xs.(k / 2) *. 1000.

let () =
  match Sys.argv with
  | [| _; "trial"; copy; out |] -> (
      let at = Filename.concat copy in
      let roles =
        match read_opt (at "config/accounting-roles.tsv") with Some s -> Some s | None -> read_opt (at "accounting-roles.tsv")
      in
      let book = read (at "book.sexp") in
      let input : C.input =
        { book; accounting_roles = roles; attention = read_opt (at "attention.loam"); settlements = read_opt (at "settlements.tsv") }
      in
      match C.convert input with
      | Error why ->
          write (Filename.concat out "report.txt") ("refused: " ^ why ^ "\n");
          print_endline "Conversion refused; the reason is in report.txt. Nothing was written to the household.";
          exit 1
      | Ok (t, r) ->
          let text = T.to_string t in
          let round_trip =
            match Bakhlo_sexp.Daily_txt.of_txt t with
            | Error why -> "refused: " ^ why
            | Ok (daily, sidecars) -> (
                match (C.check daily t, Bakhlo_sexp.Daily_txt.to_txt daily sidecars) with
                | Error why, _ | _, Error why -> "refused: " ^ why
                | Ok _, Ok (back, _) -> if T.to_string back = text then "identical bytes, same answers" else "text differs")
          in
          write (Filename.concat out "book.txt") text;
          write (Filename.concat out "report.txt")
            (Printf.sprintf "added LOCUS lines: %s\nhidden loci: %s\n" (String.concat " " r.added_loci)
               (String.concat " " r.hidden_loci));
          Printf.printf "Converted and compared: %d entries, %d plans in the same order and content.\n" r.entries r.plans;
          Printf.printf "Current quantities equal at %d coordinates (%d exact, %d unknown in both).\n" r.coordinates r.known
            r.unknown;
          Printf.printf "LOCUS lines added for unlabelled loci: %d; hidden loci: %d; empty memos written as none: %d.\n"
            (List.length r.added_loci) (List.length r.hidden_loci) r.empty_memos;
          Printf.printf "book.txt -> Daily_book -> book.txt: %s.\n" round_trip;
          Printf.printf "Size: book.sexp %d bytes, book.txt %d bytes.\n" (String.length book) (String.length text);
          Printf.printf "Median of 7: Daily_book load %.1f ms; book.txt read %.1f ms, print %.1f ms.\n"
            (median 7 (fun () -> L.load book))
            (median 7 (fun () -> T.of_string text))
            (median 7 (fun () -> T.to_string t)))
  | [| _; "migrate"; dir |] -> (
      let at = Filename.concat dir in
      let target = at "book.txt" in
      if Sys.file_exists target then (
        prerr_endline "book.txt already exists; nothing migrated.";
        exit 2);
      let fail why =
        (try Sys.remove target with Sys_error _ -> ());
        prerr_endline ("Migration refused: " ^ why ^ ". The household is unchanged.");
        exit 1
      in
      try
        F.with_writer (at "book.sexp") (fun () ->
            let book = F.read (at "book.sexp") in
            let roles =
              match read_opt (at "config/accounting-roles.tsv") with
              | Some s -> Some s
              | None -> read_opt (at "accounting-roles.tsv")
            in
            let input : C.input =
              { book; accounting_roles = roles; attention = read_opt (at "attention.loam"); settlements = read_opt (at "settlements.tsv") }
            in
            match C.convert input with
            | Error why -> fail why
            | Ok (t, r) -> (
                let text = T.to_string t in
                F.write_new target text;
                F.sync_parent target;
                let session = F.load target in
                let source = match L.load book with Ok l -> l.book | Error why -> fail ("source-" ^ why) in
                match (C.check source t, C.check session.book t, X.to_text session.book session.sidecars) with
                | Error why, _, _ -> fail ("source-check-" ^ why)
                | _, Error why, _ -> fail ("reload-check-" ^ why)
                | _, _, Error why -> fail ("reprint-" ^ why)
                | Ok _, Ok _, Ok again when again <> text -> fail "reprint-differs"
                | Ok _, Ok _, Ok _ ->
                    Printf.printf "book.txt written and read back: %d entries, %d plans; %d coordinates equal (%d exact, %d unknown).\n"
                      r.entries r.plans r.coordinates r.known r.unknown;
                    Printf.printf "LOCUS lines added for unlabelled loci: %d; hidden loci: %d; empty memos written as none: %d.\n"
                      (List.length r.added_loci) (List.length r.hidden_loci) r.empty_memos))
      with
      | F.Refused why | Sys_error why -> fail why
      | Unix.Unix_error (e, _, _) -> fail (Unix.error_message e))
  | _ ->
      prerr_endline "usage: book-txt-tool trial COPY_DIR OUT_DIR | migrate HOUSEHOLD_DIR";
      exit 2
