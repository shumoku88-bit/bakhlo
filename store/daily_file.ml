(* One book file: a snapshot followed by appended records (Bakhlo_sexp.Book_log).
   Publication appends one record and flushes it to stable storage (F_FULLFSYNC on
   macOS) before reporting it written; compaction atomically replaces the file
   with a fresh snapshot and keeps the previous file as [.prev]. Cooperative writers
   and stable parent namespaces are assumed; not a security sandbox. Power loss was
   not physically tested. No background retry or automatic repair. *)
module B = Bakhlo_sexp.Daily_book
module L = Bakhlo_sexp.Book_log

exception Refused of string

let require p why = if not p then raise (Refused why)
let get why = function Ok x -> x | Error _ -> raise (Refused why)

(* fsync(2), plus the drive-cache flush macOS needs for durability (full_sync_stubs.c). *)
external full_sync : Unix.file_descr -> unit = "bakhlo_full_sync"

type stamp = { dev : int; ino : int; size : int; mtime : float }

(* A session does not keep the file text: its revision names the file by size and
   final bytes, enough to tell successive saves apart without copying the file. *)
type t = {
  path : string;
  revision : string;  (** {!revision_of_bytes} of the file this session last saw. *)
  size : int;
  tail : string;  (** The file's last [tail_check] bytes (fewer for a short file). *)
  book : B.t;
  records : int;  (** Complete records after the snapshot. *)
  torn : bool;  (** An interrupted final append follows the complete records. *)
  torn_bytes : int;  (** Length of that unterminated final line, else 0. *)
  stamp : stamp;
}

type outcome =
  | Written of t
  | Conflict
  | Refused_input of string
  | Uncertain of { expected : string }
      (** The append may or may not have reached the file; [expected] is the revision
          the file has if it did. *)

let stamp_of (s : Unix.stats) =
  { dev = s.st_dev; ino = s.st_ino; size = s.st_size; mtime = s.st_mtime }

let read_stamped path =
  let initial = Unix.lstat path in
  require (initial.st_kind = Unix.S_REG) "regular-file-required";
  let fd = Unix.openfile path [ Unix.O_RDONLY; Unix.O_CLOEXEC ] 0 in
  Fun.protect
    ~finally:(fun () -> Unix.close fd)
    (fun () ->
      let check s =
        s.Unix.st_kind = Unix.S_REG && s.st_dev = initial.st_dev && s.st_ino = initial.st_ino
        && s.st_size = initial.st_size && s.st_mtime = initial.st_mtime
        && s.st_ctime = initial.st_ctime
      in
      require (check (Unix.fstat fd)) "changed-at-open";
      let b = Buffer.create (max 4096 initial.st_size) and chunk = Bytes.create 65536 in
      let rec loop () =
        let n = Unix.read fd chunk 0 65536 in
        if n > 0 then (
          Buffer.add_subbytes b chunk 0 n;
          loop ())
      in
      loop ();
      require (check (Unix.fstat fd) && check (Unix.lstat path)) "changed-during-read";
      (Buffer.contents b, stamp_of initial))

let read path = fst (read_stamped path)
let writer_locks : (string, int) Hashtbl.t = Hashtbl.create 8

let with_writer path f =
  let lockpath = path ^ ".lock" in
  match Hashtbl.find_opt writer_locks lockpath with
  | Some count ->
      Hashtbl.replace writer_locks lockpath (count + 1);
      Fun.protect ~finally:(fun () -> Hashtbl.replace writer_locks lockpath count) f
  | None ->
      (try require ((Unix.lstat lockpath).st_kind = Unix.S_REG) "nonregular-lock"
       with Unix.Unix_error (Unix.ENOENT, _, _) -> ());
      let fd = Unix.openfile lockpath [ Unix.O_RDWR; Unix.O_CREAT; Unix.O_CLOEXEC ] 0o600 in
      Hashtbl.replace writer_locks lockpath 1;
      Fun.protect
        ~finally:(fun () ->
          Hashtbl.remove writer_locks lockpath;
          Unix.close fd)
        (fun () ->
          let stat = Unix.fstat fd and named = Unix.lstat lockpath in
          require
            (stat.st_kind = Unix.S_REG && named.st_kind = Unix.S_REG && stat.st_dev = named.st_dev
           && stat.st_ino = named.st_ino)
            "changed-lock";
          Unix.lockf fd Unix.F_TLOCK 0;
          f ())

let tail_check = 4096

let tail_of bytes =
  let n = min tail_check (String.length bytes) in
  String.sub bytes (String.length bytes - n) n

let revision_of ~size ~tail = Printf.sprintf "%d:%s" size (Digest.to_hex (Digest.string tail))
let revision_of_bytes bytes = revision_of ~size:(String.length bytes) ~tail:(tail_of bytes)
let read_revision path = revision_of_bytes (read path)

let of_bytes path bytes stamp =
  match L.load bytes with
  | Error why -> raise (Refused ("book-refused: " ^ why))
  | Ok loaded ->
      let size = String.length bytes and tail = tail_of bytes in
      {
        path;
        revision = revision_of ~size ~tail;
        size;
        tail;
        book = loaded.book;
        records = loaded.records;
        torn = loaded.torn;
        torn_bytes = size - loaded.valid_length;
        stamp;
      }

let load path =
  let bytes, stamp = read_stamped path in
  of_bytes path bytes stamp

let reload session = load session.path

let load_result path =
  try Ok (load path) with
  | Refused why -> Error why
  | Unix.Unix_error _ | Sys_error _ -> Error "file-unavailable"

let nonce () =
  let fd = Unix.openfile "/dev/urandom" [ Unix.O_RDONLY; Unix.O_CLOEXEC ] 0 in
  Fun.protect
    ~finally:(fun () -> Unix.close fd)
    (fun () ->
      let b = Bytes.create 12 in
      let rec loop n =
        if n < 12 then (
          let count = Unix.read fd b n (12 - n) in
          require (count > 0) "entropy-read";
          loop (n + count))
      in
      loop 0;
      String.concat "" (List.init 12 (fun n -> Printf.sprintf "%02x" (Char.code (Bytes.get b n)))))

let new_id () = "entry-" ^ nonce ()

let write_all fd bytes =
  let rec loop n =
    if n < String.length bytes then (
      let count = Unix.write_substring fd bytes n (String.length bytes - n) in
      require (count > 0) "zero-write";
      loop (n + count))
  in
  loop 0

let write_new path bytes =
  let fd = Unix.openfile path [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_EXCL; Unix.O_CLOEXEC ] 0o600 in
  Fun.protect
    ~finally:(fun () -> Unix.close fd)
    (fun () ->
      write_all fd bytes;
      full_sync fd);
  require (read path = bytes) "readback-changed"

let sync_parent path =
  let fd = Unix.openfile (Filename.dirname path) [ Unix.O_RDONLY; Unix.O_CLOEXEC ] 0 in
  Fun.protect ~finally:(fun () -> Unix.close fd) (fun () -> full_sync fd)

let create_empty ~path ~measure ~scale =
  let book = get "empty-book-refused" (B.empty ~measure ~scale) in
  let bytes = B.to_string book in
  write_new path bytes;
  sync_parent path;
  let session = load path in
  require (session.revision = revision_of_bytes bytes) "first-run-cold-readback-changed";
  session

(* The last [n] bytes of the file, read through one descriptor. *)
let read_tail path n =
  let fd = Unix.openfile path [ Unix.O_RDONLY; Unix.O_CLOEXEC ] 0 in
  Fun.protect
    ~finally:(fun () -> Unix.close fd)
    (fun () ->
      let size = (Unix.fstat fd).st_size in
      let n = min n size in
      ignore (Unix.lseek fd (size - n) Unix.SEEK_SET);
      let b = Bytes.create n in
      let rec loop k =
        if k < n then (
          let count = Unix.read fd b k (n - k) in
          require (count > 0) "short-tail-read";
          loop (k + count))
      in
      loop 0;
      Bytes.to_string b)

(* The file is still exactly what this session last saw: same inode, size and
   modification time, and the same final bytes. *)
let unchanged session =
  match Unix.lstat session.path with
  | s when stamp_of s = session.stamp && s.st_kind = Unix.S_REG ->
      read_tail session.path (String.length session.tail) = session.tail
  | _ -> false
  | exception Unix.Unix_error (Unix.ENOENT, _, _) -> false

type publication_step = Appended | Synced

(* What [append] writes for [ops]: the record line, on a line of its own. *)
let appended_bytes session ops =
  let line = L.record_line ~seq:(session.records + 1) ops in
  if session.tail = "" || String.ends_with ~suffix:"\n" session.tail then line else "\n" ^ line

(* The revision the file has once [append] writes [ops]. *)
let revision_after session ops =
  let line = appended_bytes session ops in
  revision_of ~size:(session.size + String.length line) ~tail:(tail_of (session.tail ^ line))

(* Checkpoints are for deterministic fault/child-process interruption checks;
   ordinary callers use the no-op default and cannot bypass any gate. *)
let append ?(checkpoint = fun _ -> ()) session ops =
  let attempted = ref None in
  try
    require (not session.torn) "torn-tail";
    let book =
      match L.apply_all session.book ops with Ok book -> book | Error why -> raise (Refused why)
    in
    let seq = session.records + 1 in
    require (L.decode_record_line ~seq (L.record_line ~seq ops) = Ok ops) "unstable-record";
    let line = appended_bytes session ops in
    with_writer session.path (fun () ->
        if not (unchanged session) then Conflict
        else
          let size = session.size + String.length line in
          let tail = tail_of (session.tail ^ line) in
          let expected = revision_of ~size ~tail in
          attempted := Some expected;
          let fd = Unix.openfile session.path [ Unix.O_WRONLY; Unix.O_APPEND; Unix.O_CLOEXEC ] 0 in
          Fun.protect
            ~finally:(fun () -> Unix.close fd)
            (fun () ->
              write_all fd line;
              checkpoint Appended;
              full_sync fd;
              checkpoint Synced);
          let s = Unix.lstat session.path in
          require (s.st_size = size) "appended-size-changed";
          require (read_tail session.path (String.length line) = line) "appended-readback-changed";
          Written
            {
              session with
              revision = expected;
              size;
              tail;
              book;
              records = seq;
              stamp = stamp_of s;
            })
  with
  | Refused why -> (
      match !attempted with Some expected -> Uncertain { expected } | None -> Refused_input why)
  | Unix.Unix_error _ | Sys_error _ -> (
      match !attempted with
      | Some expected -> Uncertain { expected }
      | None -> Refused_input "file-or-writer-unavailable")

(* Whether a reloaded session shows the revision an uncertain append promised. *)
let confirms ~expected session = session.revision = expected

type compaction_step = Snapshot_written | Previous_kept | Replaced

type compaction =
  | Compacted of t
  | Not_compacted of string  (** Nothing was written; the file is as it was. *)
  | Compaction_uncertain  (** The file holds the old or the new snapshot (same book); reload. *)

let prev_path path = path ^ ".prev"
let compact_prefix path = Filename.basename path ^ ".compact-"

(* Replace the file with a fresh snapshot of the same book. The book file exists at
   every instant (old or new, same book); the replaced file becomes [.prev]. Stale
   temporaries of an interrupted compaction are redundant and removed first. *)
let compact ?(checkpoint = fun _ -> ()) session =
  let attempted = ref false in
  try
    require (not session.torn) "torn-tail";
    let snapshot = B.to_string session.book in
    require
      (B.to_string (get "snapshot-refused" (B.of_string snapshot)) = snapshot)
      "unstable-printer";
    with_writer session.path (fun () ->
        if not (unchanged session) then Not_compacted "changed-on-disk"
        else
          let dir = Filename.dirname session.path in
          Sys.readdir dir
          |> Array.iter (fun name ->
              if String.starts_with ~prefix:(compact_prefix session.path) name then
                Unix.unlink (Filename.concat dir name));
          attempted := true;
          let suffix = nonce () in
          let tmp = session.path ^ ".compact-" ^ suffix in
          write_new tmp snapshot;
          checkpoint Snapshot_written;
          let prev_tmp = session.path ^ ".compact-" ^ suffix ^ ".prev" in
          Unix.link session.path prev_tmp;
          Unix.rename prev_tmp (prev_path session.path);
          (* rename(2) does nothing when both names already link the same file, as
             after a compaction interrupted here; the spare link is then redundant. *)
          (try Unix.unlink prev_tmp with Unix.Unix_error (Unix.ENOENT, _, _) -> ());
          checkpoint Previous_kept;
          Unix.rename tmp session.path;
          sync_parent session.path;
          checkpoint Replaced;
          let loaded = load session.path in
          require
            (loaded.revision = revision_of_bytes snapshot && loaded.records = 0)
            "compacted-readback-changed";
          Compacted loaded)
  with
  | Refused why -> if !attempted then Compaction_uncertain else Not_compacted why
  | Unix.Unix_error _ | Sys_error _ ->
      if !attempted then Compaction_uncertain else Not_compacted "file-or-writer-unavailable"

let compaction_threshold = 200

let compact_if_due session =
  if session.records >= compaction_threshold && not session.torn then Some (compact session)
  else None

(* Explicit, user-confirmed removal of an interrupted final append. Only an
   unterminated last line is removed; the complete records stay. *)
let discard_torn_tail path =
  with_writer path (fun () ->
      let bytes, _ = read_stamped path in
      let loaded = match L.load bytes with Ok l -> l | Error why -> raise (Refused why) in
      require loaded.torn "no-torn-tail";
      Unix.truncate path loaded.valid_length;
      let fd = Unix.openfile path [ Unix.O_RDONLY; Unix.O_CLOEXEC ] 0 in
      Fun.protect ~finally:(fun () -> Unix.close fd) (fun () -> full_sync fd);
      let after = load path in
      require ((not after.torn) && after.records = loaded.records) "discard-readback-changed";
      (String.length bytes - loaded.valid_length, after))

type recovery_report = { selected : (t, string) result; torn_bytes : int }

(* Read-only description, not publication permission or proof of a past outcome. *)
let inspect_recovery path =
  let selected = load_result path in
  { selected; torn_bytes = (match selected with Ok s -> s.torn_bytes | Error _ -> 0) }

(* Restore only to an explicitly fresh target, preserving original bytes. A
   checked copy is not automatic adoption, reconciliation or a format upgrade. *)
let restore_copy ~source ~target =
  let bytes, _ = read_stamped source in
  let original = of_bytes source bytes (stamp_of (Unix.lstat source)) in
  write_new target bytes;
  sync_parent target;
  require (read source = bytes) "source-changed-during-restore";
  require ((load target).revision = original.revision) "restored-readback-changed"

let create_copy ~source ~target =
  let original = load source in
  require (not original.torn) "torn-tail";
  let bytes = B.to_string original.book in
  ignore (get "printed-book-refused" (B.of_string bytes));
  write_new target bytes;
  sync_parent target;
  require (revision_of_bytes (read source) = original.revision) "source-changed-during-copy"

let today () =
  let tm = Unix.localtime (Unix.time ()) in
  Printf.sprintf "%04d-%02d-%02d" (tm.Unix.tm_year + 1900) (tm.Unix.tm_mon + 1) tm.Unix.tm_mday
