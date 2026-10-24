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

(* The accounting roles are a section of the book: read them from the session in their
   former accounting-roles.tsv text. *)
let book_roles state =
  let text = state.session.F.sidecars.roles in
  if text = "" then None else Some text

let read_pace_config state name =
  if name = Locus_roles.file_name then Ok (book_roles state) else
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
  let tmp = ref None in
  try
    F.with_writer path (fun () ->
        match read_pace_config state name with
        | Error why -> Error why
        | Ok current when current <> expected -> Error "Configuration changed. Reopen the editor."
        | Ok _ ->
            let target = path ^ ".tmp-" ^ F.nonce () in
            tmp := Some target;
            F.write_new target content;
            Sys.rename target path;
            F.sync_parent path;
            F.require (F.read path = content) "config-readback-changed";
            Ok ())
  with
  | F.Refused why | Sys_error why ->
      Option.iter (fun p -> try Unix.unlink p with Unix.Unix_error _ -> ()) !tmp;
      Error why
  | Unix.Unix_error (err, fn, arg) ->
      Option.iter (fun p -> try Unix.unlink p with Unix.Unix_error _ -> ()) !tmp;
      Error (Printf.sprintf "%s (%s %s)" (Unix.error_message err) fn arg)

(* Read where saves write (config_file_path); never an empty list for a bad file. *)
let accounting_roles state =
  Result.bind (read_pace_config state Locus_roles.file_name) (function
    | None -> Ok []
    | Some text -> O.parse_accounting_roles text)
  |> Result.map_error (fun why -> Locus_roles.file_name ^ " " ^ why)

(* Roles and Attention are sections of the book: saving one rewrites the book through
   the single writer, with the same conflict and uncertainty outcomes as a record. *)
let publish_sidecars state sidecars =
  match F.publish ~sidecars state.session [] with
  | F.Written session -> ({ state with session }, Ok ())
  | F.Conflict -> (state, Error "The book changed on disk. Reload before retrying.")
  | F.Refused_input why -> (state, Error why)
  | F.Uncertain _ ->
      ({ state with blocked = true }, Error "Save outcome is uncertain. Do not retry; reload to inspect.")

let save_roles state ~expected ~content =
  if book_roles state <> expected then (state, Error "Configuration changed. Reopen the editor.")
  else
    (* Canonical text, and no roles as no section, as the book reads them back; a
       malformed text is passed on and refused by the book. *)
    let content =
      match O.parse_accounting_roles content with
      | Ok [] -> ""
      | Ok roles -> Locus_roles.to_string roles
      | Error _ -> content
    in
    publish_sidecars state { state.session.F.sidecars with roles = content }

let save_attention state ~expected next =
  match attention state with
  | Error why -> (state, Error why)
  | Ok current when current <> expected -> (state, Error "Attention changed. Reload before retrying.")
  | Ok _ -> (
      let content = Att.to_string next in
      match Att.of_string content with
      | Error why -> (state, Error why)
      | Ok decoded when decoded <> next -> (state, Error "Attention serialization would change evidence.")
      | Ok _ ->
          let content = if next = Att.empty then "" else content in
          publish_sidecars state { state.session.F.sidecars with attention = content })

let save_config_file state ~file ~expected ~content ~admission =
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

let save_config state ~file ~expected ~content ~admission =
  if file = Locus_roles.file_name then save_roles state ~expected ~content
  else (state, save_config_file state ~file ~expected ~content ~admission)
