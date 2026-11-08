(* The settings files beside the book (daily-pace.tsv, boundary-presets.tsv,
   balance-view.tsv, scheduled-coverage.tsv): in config/ when that holds the file,
   else beside the book. A file is replaced only if it still holds what was read. *)
module F = Book_file

let path ~book_path name =
  let dir = Filename.dirname book_path in
  let nested = Filename.concat (Filename.concat dir "config") name in
  let present =
    try
      ignore (Unix.lstat nested);
      true
    with
    | Unix.Unix_error (Unix.ENOENT, _, _) -> false
    | Unix.Unix_error _ -> true
  in
  if present then nested else Filename.concat dir name

let unix_error err fn arg = Printf.sprintf "%s (%s %s)" (Unix.error_message err) fn arg

let read ~book_path name =
  let path = path ~book_path name in
  try
    let exists =
      try
        ignore (Unix.lstat path);
        true
      with Unix.Unix_error (Unix.ENOENT, _, _) -> false
    in
    if exists then Ok (Some (F.read path)) else Ok None
  with
  | F.Refused why | Sys_error why -> Error why
  | Unix.Unix_error (err, fn, arg) -> Error (unix_error err fn arg)

let write ~book_path name ~expected content =
  let file = path ~book_path name in
  try
    F.with_writer file (fun () ->
        match read ~book_path name with
        | Error why -> Error why
        | Ok current when current <> expected -> Error "The file changed meanwhile; run it again."
        | Ok _ ->
            F.write_atomic file content;
            Ok ())
  with
  | F.Refused why | Sys_error why -> Error why
  | Unix.Unix_error (err, fn, arg) -> Error (unix_error err fn arg)
