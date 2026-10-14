(* Instrument only fresh ignored source copies. Exact anchors refuse source drift.
   No source semantics, admission gate or publication ordering is removed. *)
let read path = let ic = open_in_bin path in
  Fun.protect ~finally:(fun () -> close_in ic) (fun () -> really_input_string ic (in_channel_length ic))
let write path text =
  let fd = Unix.openfile path [Unix.O_WRONLY; Unix.O_CREAT; Unix.O_EXCL] 0o600 in
  let oc = Unix.out_channel_of_descr fd in
  Fun.protect ~finally:(fun () -> close_out oc) (fun () -> output_string oc text)
let positions text needle =
  let rec loop at result =
    if at + String.length needle > String.length text then List.rev result
    else if String.sub text at (String.length needle) = needle then loop (at + String.length needle) (at :: result)
    else loop (at + 1) result
  in loop 0 []
let replace text old_text new_text = match positions text old_text with
  | [at] -> String.sub text 0 at ^ new_text ^
      String.sub text (at + String.length old_text) (String.length text - at - String.length old_text)
  | xs -> failwith (Printf.sprintf "instrumentation anchor count=%d: %S" (List.length xs) old_text)
let wrap text next name signature arguments label =
  replace text next (Printf.sprintf "let %s_unobserved = %s\nlet %s = Storage_profile.measure %S (fun () -> %s_unobserved %s)\n\n%s"
    name name signature label name arguments next)
let alias text = replace text "module B = Bakhlo_sexp.Daily_book" "module B = Measured_daily_book"
let book raw =
  let raw = replace raw "  let events =\n    List.map" "  let events = Storage_profile.measure \"admit.events\" (fun () ->\n    List.map" in
  let raw = replace raw "      entries\n  in\n  let source =" "      entries)\n  in\n  let source = Storage_profile.measure \"admit.actual-command-and-source\" (fun () ->" in
  let raw = replace raw "         })\n  in\n  unique (List.map (fun (p : plan)" "         }))\n  in\n  unique (List.map (fun (p : plan)" in
  let raw = replace raw "      get \"support-admission\"\n        (Q.create ~source ~zero_origins:data.origins ~openings:data.openings\n           ~groups:data.observations ~presence:data.presence);"
    "      Storage_profile.measure \"admit.quantity-support\" (fun () ->\n        get \"support-admission\"\n          (Q.create ~source ~zero_origins:data.origins ~openings:data.openings\n             ~groups:data.observations ~presence:data.presence));" in
  let raw = wrap raw "let empty_command :" "make_data"
    "make_data ~measures ~labels ~approved ~entries ~plans ~origins ~openings ~observations ~presence"
    "~measures ~labels ~approved ~entries ~plans ~origins ~openings ~observations ~presence" "book.make-data" in
  let raw = wrap raw "let protect f =" "admit" "admit ?entries_cached data" "?entries_cached data" "book.admit" in
  let raw = replace raw "Parsexp.Many.parse_string bytes) with"
    "Storage_profile.measure \"decode.parsexp\" (fun () -> Parsexp.Many.parse_string bytes)) with" in
  let raw = wrap raw "let source_format_of_string bytes =" "of_monolithic_string"
    "of_monolithic_string bytes" "bytes" "book.decode-and-admit" in
  let raw = wrap raw "let of_records (rb :" "source_format_of_string"
    "source_format_of_string bytes" "bytes" "decode.format-detection" in
  let raw = wrap raw "let quote s =" "sexps" "sexps t" "t" "print.ast" in
  let raw = wrap raw "let to_string t =" "render_into" "render_into out x" "out x" "print.render" in
  let raw = wrap raw "let entries t =" "to_string" "to_string t" "t" "book.to-string" in
  raw
let file raw =
  let raw = alias raw in
  let raw = wrap raw "let records_revision ~lsn ~crc =" "read" "read path" "path" "io.read" in
  (* Add byte/role observations inside the wrapper, not by changing read itself. *)
  let raw = replace raw "Storage_profile.measure \"io.read\" (fun () -> read_unobserved path)"
    "Storage_profile.measure (\"io.read.\" ^ Storage_profile.role path) (fun () -> let bytes = read_unobserved path in Storage_profile.bytes \"read\" (String.length bytes); bytes)" in
  let raw = wrap raw "let nonce () =" "load" "load path" "path" "file.load" in
  let raw = replace raw
    "      loop 0;\n      Unix.fsync fd);\n  require (read path = bytes) \"readback-changed\""
    "      Storage_profile.measure (\"io.write.\" ^ Storage_profile.role path) (fun () -> loop 0);\n      Storage_profile.bytes \"write\" (String.length bytes);\n      Storage_profile.measure (\"io.fsync.\" ^ Storage_profile.role path) (fun () -> Unix.fsync fd));\n  require (read path = bytes) \"readback-changed\"" in
  let raw = replace raw "(fun () -> Unix.fsync fd)\n\nlet unfinished_names"
    "(fun () -> Storage_profile.measure \"io.fsync.parent\" (fun () -> Unix.fsync fd))\n\nlet unfinished_names" in
  let raw = wrap raw "let sync_parent path =" "write_new" "write_new path bytes" "path bytes" "file.write-new" in
  let raw = wrap raw "let valid_attempt_id id =" "with_writer" "with_writer path f" "path f" "publication.writer-and-body" in
  let raw = replace raw "Unix.rename pending session.path;"
    "Storage_profile.measure \"io.rename\" (fun () -> Unix.rename pending session.path);" in
  let raw = replace raw "            Unix.unlink attempt;" "            Storage_profile.measure \"io.unlink-attempt\" (fun () -> Unix.unlink attempt);" in
  wrap raw "type append_outcome =" "publish" "publish ?checkpoint session book" "?checkpoint session book" "file.publish"
let actions raw =
  let raw = alias raw in
  replace raw "| F.Monolithic -> (\n        match B.put_entry session.book ~replace:tx.replace tx.entry ~plan:tx.plan with"
    "| F.Monolithic -> (\n        match Storage_profile.measure \"candidate.put-entry\" (fun () -> B.put_entry session.book ~replace:tx.replace tx.entry ~plan:tx.plan) with"
let study raw profiled =
  let main = "let () =\n  match Array.to_list Sys.argv with" in
  match positions raw main with
  | [at] -> let raw = String.sub raw 0 at in if profiled then alias raw else raw
  | _ -> failwith "study-main-anchor"
let () =
  ignore (Unix.umask 0o077);
  match Array.to_list Sys.argv with
  | [_; source; output] ->
      write (output ^ "/measured_daily_book.ml") (book (read (source ^ "/daily_book.ml")));
      write (output ^ "/daily_file.ml") (file (read (source ^ "/daily_file.ml")));
      write (output ^ "/daily_actions.ml") (actions (read (source ^ "/daily_actions.ml")));
      write (output ^ "/posting_draft.ml") (alias (read (source ^ "/posting_draft.ml")));
      write (output ^ "/storage_study.ml") (study (read (source ^ "/storage_study.ml")) true)
  | [_; "control"; source; output] ->
      write (output ^ "/storage_study.ml") (study (read (source ^ "/storage_study.ml")) false)
  | _ -> failwith "Usage: storage-instrument SOURCE OUTPUT | control SOURCE OUTPUT"
