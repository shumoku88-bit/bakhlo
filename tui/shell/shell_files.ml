(* The Shell's own file access besides the ledger writer: screen configuration
   files (captured reads and admission-checked atomic saves). Screens only see captured bytes through Screen.env. *)
open Shell_state

let config_file_path state name =
  let dir = Option.value ~default:(Filename.dirname state.session.F.path) state.config_home in
  let nested = Filename.concat (Filename.concat dir "config") name in
  let present =
    try
      let _ = Unix.lstat nested in
      true
    with
    | Unix.Unix_error (Unix.ENOENT, _, _) -> false
    | Unix.Unix_error _ -> true
  in
  if present then nested else Filename.concat dir name

let read_pace_config state name =
  let path = config_file_path state name in
  try
    let exists =
      try
        let _ = Unix.lstat path in
        true
      with Unix.Unix_error (Unix.ENOENT, _, _) -> false
    in
    if exists then Ok (Some (F.read path)) else Ok None
  with
  | F.Refused why | Sys_error why -> Error why
  | Unix.Unix_error (err, fn, arg) ->
      Error (Printf.sprintf "%s (%s %s)" (Unix.error_message err) fn arg)

let write_config_file state name ~expected content =
  let path = config_file_path state name in
  try
    F.with_writer path (fun () ->
        match read_pace_config state name with
        | Error why -> Error why
        | Ok current when current <> expected -> Error "Configuration changed. Reopen the editor."
        | Ok _ ->
            F.write_atomic path content;
            Ok ())
  with
  | F.Refused why | Sys_error why -> Error why
  | Unix.Unix_error (err, fn, arg) ->
      Error (Printf.sprintf "%s (%s %s)" (Unix.error_message err) fn arg)

(* The accounting roles are a section of the book, admitted with it. *)
let accounting_roles state = Ok (B.roles state.session.book)

(* Roles and Attention are sections of the book: saving one rewrites the book through
   the single writer, with the same conflict and uncertainty outcomes as a record. *)
let section_result state result =
  let next =
    match result with
    | Publication.Published session -> sync { state with session }
    | _ -> apply_outcome state ~draft:state result
  in
  let saved =
    match result with
    | Publication.Published _ -> Ok ()
    | Publication.Conflict | Publication.Conflict_base_changed ->
        Error "The book changed on disk. Reload before retrying."
    | Publication.Refused why | Publication.Storage_failed why -> Error why
    | Publication.Uncertain _ -> Error "Save outcome is uncertain. Do not retry; reload to inspect."
  in
  (next, saved)

let save_roles state ~expected next =
  if B.roles state.session.book <> expected then
    (state, Error "Accounting roles changed. Reopen the editor.")
  else section_result state (Publication.roles ~session:state.session next)

let save_attention state ~expected (next : Att.t) =
  match attention state with
  | Error why -> (state, Error why)
  | Ok current when current <> expected ->
      (state, Error "Attention changed. Reload before retrying.")
  | Ok _ ->
      section_result state
        (Publication.attention ~session:state.session ~items:next.items ~closes:next.closes)

let save_config state ~file ~expected ~content ~admission =
  let admitted =
    match admission with
    | Screen.Unconditional -> Ok ()
    | Screen.Household_readable -> (
        try
          ignore (F.load state.session.path);
          Ok ()
        with
        | F.Refused why -> Error ("Household read refused: " ^ why)
        | Sys_error why -> Error why
        | Unix.Unix_error (err, _, _) -> Error (Unix.error_message err))
    | Screen.Vocabulary_unchanged -> (
        try
          let book = (F.reload state.session).book in
          if
            B.approved_loci book = B.approved_loci state.session.book
            && B.measures book = B.measures state.session.book
          then Ok ()
          else Error "Admitted Loci or Measures changed; reopen setup."
        with
        | F.Refused why | Sys_error why -> Error why
        | Unix.Unix_error (err, _, _) -> Error (Unix.error_message err))
  in
  Result.bind admitted (fun () -> write_config_file state file ~expected content)
