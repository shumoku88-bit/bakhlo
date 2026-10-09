module X = Sexplib0.Sexp

type client_session = {
  session_id : string;
  mutable last_acknowledged_token : string option;
  mutable last_acknowledged_lsn : int;
}

type commit_result =
  | Commit_success of { lsn : int; event_id : string }
  | Idempotent_duplicate of { lsn : int; event_id : string }
  | Lsn_conflict of { expected : int; actual : int }
  | Payload_drift_refused of string
  | Storage_error of string
  | Sync_uncertain of { lsn : int; event_id : string; error : string }

type in_doubt_status =
  | In_doubt_none
  | In_doubt_detected of {
      unacknowledged_token : string;
      lsn : int;
      event_id : string;
    }

type recovery_action =
  | Clean of { last_lsn : int; total_frames : int }
  | Torn_write_truncated of { valid_lsn : int; truncated_bytes : int }
  | Corrupt_fail_closed of { offset : int; reason : string }
  | Truncate_failed of string

type token_record = {
  token : string;
  event_id : string;
  lsn : int;
  payload_summary : string;
}

type engine = {
  path : string;
  lock_path : string;
  mutable current_lsn : int;
  mutable last_file_size : int;
  mutable last_mtime : float;
  token_index : (string, token_record) Hashtbl.t;
  mutable latest_token : string option;
  mutable latest_event_id : string option;
}

let create_session ~session_id ?last_token ?(last_lsn = -1) () =
  { session_id; last_acknowledged_token = last_token; last_acknowledged_lsn = last_lsn }

let acknowledge_session session ~token ~lsn =
  session.last_acknowledged_token <- Some token;
  session.last_acknowledged_lsn <- lsn

let current_lsn engine = engine.current_lsn
let path engine = engine.path
let latest_token engine = engine.latest_token
let latest_event_id engine = engine.latest_event_id

let with_lock lock_path f =
  let fd = Unix.openfile lock_path [ Unix.O_RDWR; Unix.O_CREAT; Unix.O_CLOEXEC ] 0o600 in
  Fun.protect
    ~finally:(fun () -> Unix.close fd)
    (fun () ->
      Unix.lockf fd Unix.F_LOCK 0;
      f ())

let sync_parent path =
  let parent = Filename.dirname path in
  let fd_opt =
    try Some (Unix.openfile parent [ Unix.O_RDONLY; Unix.O_CLOEXEC ] 0)
    with
    | Unix.Unix_error ((Unix.EACCES | Unix.EINVAL | Unix.EOPNOTSUPP | Unix.ENOSYS | Unix.EPERM), _, _) ->
        None
    | Unix.Unix_error (e, _, _) ->
        raise (Failure (Printf.sprintf "open-parent-failed: %s" (Unix.error_message e)))
  in
  match fd_opt with
  | None -> ()
  | Some fd ->
      Fun.protect
        ~finally:(fun () -> Unix.close fd)
        (fun () ->
          try Unix.fsync fd
          with
          | Unix.Unix_error ((Unix.EINVAL | Unix.EOPNOTSUPP | Unix.ENOSYS | Unix.EISDIR | Unix.EBADF), _, _) ->
              ()
          | Unix.Unix_error (e, _, _) ->
              raise (Failure (Printf.sprintf "fsync-parent-failed: %s" (Unix.error_message e))))

let rec write_all fd buf pos len =
  if len > 0 then
    let n = Unix.write_substring fd buf pos len in
    if n <= 0 then failwith "zero-bytes-written"
    else write_all fd buf (pos + n) (len - n)

let read_file_contents path =
  if not (Sys.file_exists path) then ""
  else
    let ic = open_in_bin path in
    Fun.protect
      ~finally:(fun () -> close_in ic)
      (fun () ->
        let len = in_channel_length ic in
        really_input_string ic len)

let payload_summary_of payload =
  X.to_string (Records_book.encode_payload payload)

let payload_token_and_event = function
  | Records_book.Entry e -> (e.token, e.id)
  | Records_book.Plan p -> (None, p.id)
  | Records_book.Budget b -> (None, b.id)
  | Records_book.Observation o -> (None, Option.value ~default:"obs" o.id)
  | Records_book.Origin orig -> (Some orig.token, orig.event_id)
  | Records_book.Header _ -> (None, "header")
  | Records_book.Add_locus al -> (None, al.locus)
  | Records_book.Opaque _ -> (None, "opaque")

let populate_index engine token_index frames =
  List.iter
    (fun (f : Records_book.frame) ->
      let tok_opt, eid = payload_token_and_event f.payload in
      Option.iter
        (fun tok ->
          Hashtbl.replace token_index tok
            {
              token = tok;
              event_id = eid;
              lsn = f.lsn;
              payload_summary = payload_summary_of f.payload;
            };
          engine.latest_token <- Some tok;
          engine.latest_event_id <- Some eid)
        tok_opt)
    frames

let sync_from_disk_locked engine =
  if not (Sys.file_exists engine.path) then Ok ()
  else
    let st = Unix.stat engine.path in
    if st.st_size = engine.last_file_size && Float.equal st.st_mtime engine.last_mtime then
      Ok ()
    else
      let content = read_file_contents engine.path in
      let insp = Records_book.inspect_string content in
      match insp.corruption with
      | Records_book.Mid_file { byte_offset; reason } ->
          Error (Printf.sprintf "corrupt-mid-file-at-%d: %s" byte_offset reason)
      | Records_book.No_corruption ->
          if insp.trailing_torn_bytes > 0 then
            Error (Printf.sprintf "trailing-torn-bytes-detected-in-live-session: %d bytes" insp.trailing_torn_bytes)
          else begin
            Hashtbl.clear engine.token_index;
            populate_index engine engine.token_index insp.valid_frames;
            engine.current_lsn <- insp.last_lsn;
            engine.last_file_size <- st.st_size;
            engine.last_mtime <- st.st_mtime;
            Ok ()
          end

let recover_and_open path =
  let lock_path = path ^ ".lock" in
  try
    with_lock lock_path (fun () ->
        let token_index = Hashtbl.create 100 in
        let engine =
          {
            path;
            lock_path;
            current_lsn = -1;
            last_file_size = 0;
            last_mtime = 0.0;
            token_index;
            latest_token = None;
            latest_event_id = None;
          }
        in
        if not (Sys.file_exists path) then
          Ok (engine, Clean { last_lsn = -1; total_frames = 0 })
        else
          let content = read_file_contents path in
          let insp = Records_book.inspect_string content in
          match insp.corruption with
          | Records_book.Mid_file { byte_offset; reason } ->
              Ok (engine, Corrupt_fail_closed { offset = byte_offset; reason })
          | Records_book.No_corruption ->
              let total_bytes = String.length content in
              let truncated_res =
                if insp.trailing_torn_bytes > 0 then begin
                  let valid_bytes = total_bytes - insp.trailing_torn_bytes in
                  try
                    let fd = Unix.openfile path [ Unix.O_RDWR; Unix.O_CLOEXEC ] 0o600 in
                    Fun.protect
                      ~finally:(fun () -> Unix.close fd)
                      (fun () ->
                        Unix.ftruncate fd valid_bytes;
                        Unix.fsync fd);
                    sync_parent path;
                    engine.last_file_size <- valid_bytes;
                    let st = Unix.stat path in
                    engine.last_mtime <- st.st_mtime;
                    Some (Torn_write_truncated { valid_lsn = insp.last_lsn; truncated_bytes = insp.trailing_torn_bytes })
                  with
                  | Unix.Unix_error (e, _, _) ->
                      Some (Truncate_failed (Unix.error_message e))
                  | Failure msg ->
                      Some (Truncate_failed msg)
                end else begin
                  engine.last_file_size <- total_bytes;
                  let st = Unix.stat path in
                  engine.last_mtime <- st.st_mtime;
                  None
                end
              in
              match truncated_res with
              | Some (Truncate_failed msg) ->
                  Error ("truncate-failed-fail-closed: " ^ msg)
              | Some (Torn_write_truncated _ as action) ->
                  populate_index engine token_index insp.valid_frames;
                  engine.current_lsn <- insp.last_lsn;
                  Ok (engine, action)
              | Some (Clean _ | Corrupt_fail_closed _) | None ->
                  populate_index engine token_index insp.valid_frames;
                  engine.current_lsn <- insp.last_lsn;
                  Ok (engine, Clean { last_lsn = insp.last_lsn; total_frames = List.length insp.valid_frames }))
  with
  | Unix.Unix_error (e, _, _) -> Error (Unix.error_message e)
  | Failure msg -> Error msg

let close_engine _engine = ()

let check_in_doubt engine ~session =
  match engine.latest_token with
  | None -> In_doubt_none
  | Some tok ->
      let is_unacked =
        match session.last_acknowledged_token with
        | None -> true
        | Some last_tok -> not (String.equal tok last_tok)
      in
      if is_unacked then
        In_doubt_detected
          {
            unacknowledged_token = tok;
            lsn = engine.current_lsn;
            event_id = Option.value ~default:"" engine.latest_event_id;
          }
      else In_doubt_none

let append_payload engine ~session:_ ~expected_lsn ~token ~event_id ~payload =
  try
    with_lock engine.lock_path (fun () ->
        (* 0. Re-sync from disk under lock to observe any external committed updates *)
        match sync_from_disk_locked engine with
        | Error err -> Storage_error ("storage-corrupted-fail-closed: " ^ err)
        | Ok () ->
            (* 1. Request token machine idempotency check first *)
            let duplicate_opt =
              match token with
              | None -> None
              | Some tok -> (
                  match Hashtbl.find_opt engine.token_index tok with
                  | None -> None
                  | Some existing ->
                      let current_summary = payload_summary_of payload in
                      if String.equal existing.payload_summary current_summary then
                        Some (Idempotent_duplicate { lsn = existing.lsn; event_id = existing.event_id })
                      else
                        Some (Payload_drift_refused (Printf.sprintf "duplicate-token-%s-payload-drift" tok)))
            in
            match duplicate_opt with
            | Some res -> res
            | None ->
                (* 2. LSN conflict detection *)
                let next_lsn = engine.current_lsn + 1 in
                if expected_lsn <> next_lsn then
                  Lsn_conflict { expected = expected_lsn; actual = next_lsn }
                else
                  (* 3. Encode frame with CRC32 *)
                  let frame = Records_book.encode_frame next_lsn payload in
                  let line = Records_book.serialize_frame frame ^ "\n" in
                  let line_len = String.length line in

                  (* 4. Append & fsync *)
                  let fd =
                    Unix.openfile engine.path
                      [ Unix.O_WRONLY; Unix.O_APPEND; Unix.O_CREAT; Unix.O_CLOEXEC ]
                      0o600
                  in
                  Fun.protect
                    ~finally:(fun () -> Unix.close fd)
                    (fun () ->
                      write_all fd line 0 line_len;
                      Unix.fsync fd);

                  let sync_parent_res =
                    try
                      sync_parent engine.path;
                      Ok ()
                    with
                    | Unix.Unix_error (e, _, _) -> Error (Unix.error_message e)
                    | Failure msg -> Error msg
                  in

                  (* 5. Update engine in-memory state only AFTER file fsync *)
                  engine.current_lsn <- next_lsn;
                  let st = Unix.stat engine.path in
                  engine.last_file_size <- st.st_size;
                  engine.last_mtime <- st.st_mtime;
                  Option.iter
                    (fun tok ->
                      Hashtbl.replace engine.token_index tok
                        {
                          token = tok;
                          event_id;
                          lsn = next_lsn;
                          payload_summary = payload_summary_of payload;
                        };
                      engine.latest_token <- Some tok;
                      engine.latest_event_id <- Some event_id)
                    token;

                  match sync_parent_res with
                  | Ok () -> Commit_success { lsn = next_lsn; event_id }
                  | Error err -> Sync_uncertain { lsn = next_lsn; event_id; error = err })
  with
  | Unix.Unix_error (e, _, _) -> Storage_error (Unix.error_message e)
  | Failure msg -> Storage_error msg

let append_entry engine ~session ~expected_lsn (entry : Records_book.entry) =
  append_payload engine ~session ~expected_lsn ~token:entry.token ~event_id:entry.id
    ~payload:(Records_book.Entry entry)

let append_plan engine ~session ~expected_lsn (plan : Records_book.plan) =
  append_payload engine ~session ~expected_lsn ~token:None ~event_id:plan.id
    ~payload:(Records_book.Plan plan)

let append_budget engine ~session ~expected_lsn (budget : Records_book.budget) =
  append_payload engine ~session ~expected_lsn ~token:None ~event_id:budget.id
    ~payload:(Records_book.Budget budget)
