(* The Shell's own file access besides the ledger writer: screen configuration
   files (captured reads and admission-checked atomic saves). Screens only see captured bytes through Screen.env. *)
open Shell_state

let read_config state name =
  let directory = Filename.dirname state.session.F.path in
  let candidates =
    List.filter_map Fun.id
      [
        Option.map (fun home -> Filename.concat home name) state.config_home;
        Some (Filename.concat directory name);
        Some (Filename.concat (Filename.concat directory "config") name);
      ]
  in
  let rec read = function
    | [] -> None
    | filename :: rest -> (
        if not (Sys.file_exists filename) then read rest
        else
          try Some (F.read filename) with F.Refused _ | Unix.Unix_error _ | Sys_error _ -> Some "")
  in
  read candidates

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

let accounting_roles state =
  match read_config state Locus_roles.file_name with
  | Some text -> O.parse_accounting_roles text
  | None -> []

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
