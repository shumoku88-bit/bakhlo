(* Stage 4 trial (docs/COMMON_FORMAT.ja.md): convert one copied household to book.txt
   with Daily_to_book_txt, which also compares it with the source. Usage:
   book-txt-trial COPY_DIR OUT_DIR. Reads only COPY_DIR; writes only OUT_DIR. The
   terminal gets counts; names and IDs go to OUT_DIR/report.txt (ignored scratch). *)
module C = Bakhlo_migrate.Daily_to_book_txt
module T = Bakhlo_book_txt.Book_txt
module L = Bakhlo_sexp.Book_log

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
  | [| _; copy; out |] -> (
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
  | _ ->
      prerr_endline "usage: book-txt-trial COPY_DIR OUT_DIR";
      exit 2
