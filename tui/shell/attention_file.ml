(* Attention memory file: lookup, strict load and checked atomic save under the writer lock. *)
open Attention_data

let file_path ?config_home session_path =
  let dir = Filename.dirname session_path in
  let selected_dir = Option.value ~default:dir config_home in
  let candidates = List.map (Filename.concat selected_dir) [ "attention.loam"; "attention.tsv" ] in
  let present path =
    try
      let _ = Unix.lstat path in
      true
    with
    | Unix.Unix_error (Unix.ENOENT, _, _) -> false
    | Unix.Unix_error _ -> true
  in
  match List.find_opt present candidates with
  | Some existing -> existing
  | None -> Filename.concat selected_dir "attention.loam"

let load_file path =
  try
    let exists =
      try
        let _ = Unix.lstat path in
        true
      with Unix.Unix_error (Unix.ENOENT, _, _) -> false
    in
    if exists then of_string (Daily_file.read path) else Ok empty
  with
  | Daily_file.Refused why | Sys_error why -> Error why
  | Unix.Unix_error (err, fn, arg) ->
      Error (Printf.sprintf "%s (%s %s)" (Unix.error_message err) fn arg)

let save_file path ~expected t =
  let tmp = ref None in
  try
    Daily_file.with_writer path (fun () ->
        match load_file path with
        | Error why -> Error why
        | Ok current when current <> expected ->
            Error "Attention changed on disk. Reload before retrying."
        | Ok _ -> (
            let content = to_string t in
            match of_string content with
            | Error why -> Error why
            | Ok decoded when decoded <> t -> Error "Attention serialization would change evidence."
            | Ok _ ->
                let target = path ^ ".tmp-" ^ Daily_file.nonce () in
                tmp := Some target;
                Daily_file.write_new target content;
                Sys.rename target path;
                Daily_file.sync_parent path;
                Daily_file.require (Daily_file.read path = content) "attention-readback-changed";
                Ok ()))
  with
  | Daily_file.Refused why | Sys_error why ->
      Option.iter (fun p -> try Unix.unlink p with Unix.Unix_error _ -> ()) !tmp;
      Error why
  | Unix.Unix_error (err, fn, arg) ->
      Option.iter (fun p -> try Unix.unlink p with Unix.Unix_error _ -> ()) !tmp;
      Error (Printf.sprintf "%s (%s %s)" (Unix.error_message err) fn arg)
