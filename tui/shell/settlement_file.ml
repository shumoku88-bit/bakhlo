(* Settlements file: lookup, strict load and checked atomic save under the writer lock. *)
open Settlement_data

let file_path ?config_home base_path =
  match config_home with
  | Some dir -> Filename.concat dir "settlements.tsv"
  | None -> Filename.concat (Filename.dirname base_path) "settlements.tsv"

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

let serialize_row r =
  let opt_str = function None -> "" | Some s -> s in
  String.concat "\t"
    [
      r.id;
      opt_str r.label;
      r.debtor;
      r.creditor;
      r.measure;
      Z.to_string r.committed;
      Z.to_string r.settled;
      Z.to_string r.extinguished;
      r.source_event;
      r.source_effect;
      opt_str r.effective_on;
    ]

let save_file path ~expected t =
  let tmp = ref None in
  try
    Daily_file.with_writer path (fun () ->
        match load_file path with
        | Error why -> Error why
        | Ok current when current <> expected ->
            Error "Settlements changed on disk. Reload before retrying."
        | Ok _ -> (
            let content =
              "# settlements.tsv - household commitment trial\n"
              ^ String.concat "" (List.map (fun r -> serialize_row r ^ "\n") t.rows)
            in
            match of_string content with
            | Error why -> Error why
            | Ok decoded when decoded <> t ->
                Error "Settlement serialization would change evidence."
            | Ok _ ->
                let target = path ^ ".tmp-" ^ Daily_file.nonce () in
                tmp := Some target;
                Daily_file.write_new target content;
                Sys.rename target path;
                Daily_file.sync_parent path;
                Daily_file.require (Daily_file.read path = content) "settlements-readback-changed";
                Ok ()))
  with
  | Daily_file.Refused why | Sys_error why ->
      Option.iter (fun p -> try Unix.unlink p with Unix.Unix_error _ -> ()) !tmp;
      Error why
  | Unix.Unix_error (err, fn, arg) ->
      Option.iter (fun p -> try Unix.unlink p with Unix.Unix_error _ -> ()) !tmp;
      Error (Printf.sprintf "%s (%s %s)" (Unix.error_message err) fn arg)
