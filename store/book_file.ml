(* One book file: the common book.txt (docs/COMMON_FORMAT.ja.md), which also holds the
   accounting roles and Attention. Every publication rewrites the whole file: write a
   temporary file and flush it to stable storage (F_FULLFSYNC on macOS), keep the
   current file as [.prev], rename, flush the directory, and check the bytes read back.
   The session keeps the book, whose admitted book.txt equals the file, so a save checks
   and prints only what its operations change. Cooperative writers and stable parent namespaces are assumed;
   not a security sandbox. Power loss was not physically tested. No background retry or
   automatic repair. *)
module B = Bakhlo_household.Book
module X = Bakhlo_household.Daily_txt
module T = Bakhlo_book_txt.Book_txt

exception Refused of string

let require p why = if not p then raise (Refused why)
let get why = function Ok x -> x | Error _ -> raise (Refused why)

(* fsync(2), plus the drive-cache flush macOS needs for durability (full_sync_stubs.c). *)
external full_sync : Unix.file_descr -> unit = "bakhlo_full_sync"

type stamp = { dev : int; ino : int; size : int; mtime : float }

type t = {
  path : string;
  revision : string;  (** {!revision_of_bytes} of the file this session last saw. *)
  book : B.t;
  sidecars : X.sidecars;  (** The book's roles and Attention, as the TUI reads them. *)
  stamp : stamp;
}

type outcome =
  | Written of t
  | Conflict
  | Refused_input of string
  | Uncertain of { expected : string }
      (** The replacement may or may not have happened; [expected] is the revision the
          file has if it did. *)

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
      (* Exactly the size the file had when opened, then the end of the file. *)
      let size = initial.st_size in
      let b = Bytes.create size in
      let rec fill n =
        if n < size then match Unix.read fd b n (size - n) with 0 -> n | k -> fill (n + k) else n
      in
      require (fill 0 = size && Unix.read fd (Bytes.create 1) 0 1 = 0) "changed-during-read";
      require (check (Unix.fstat fd) && check (Unix.lstat path)) "changed-during-read";
      (Bytes.unsafe_to_string b, stamp_of initial))

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

let revision_of_bytes bytes =
  Printf.sprintf "%d:%s" (String.length bytes) (Digest.to_hex (Digest.string bytes))

let read_revision path = revision_of_bytes (read path)

let of_bytes path bytes stamp =
  match T.read bytes with
  | Error e ->
      raise (Refused (Printf.sprintf "book-refused: %s at line %d" (T.code_name e.code) e.line))
  | Ok txt -> (
      match B.of_txt txt with
      | Error why -> raise (Refused ("book-refused: " ^ why))
      | Ok book ->
          { path; revision = revision_of_bytes bytes; book; sidecars = X.sidecars_of book; stamp })

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

(* Configuration and settlements have their own admission and conflict checks.
   Under their writer lock, they share this replacement mechanism. Unlike a book
   publication, this makes no previous-book copy. Failure is reported to the
   caller even if rename has already happened; it never retries the write. *)
let write_atomic path bytes =
  let temporary = path ^ ".tmp-" ^ nonce () in
  Fun.protect
    ~finally:(fun () -> try Unix.unlink temporary with Unix.Unix_error _ -> ())
    (fun () ->
      write_new temporary bytes;
      Unix.rename temporary path;
      sync_parent path;
      require (read path = bytes) "replacement-readback-changed")

(* The book.txt text of a book with these roles and Attention. *)
let text_of book sidecars =
  match X.with_sidecars book sidecars with
  | Ok book -> T.print (B.txt book)
  | Error why -> raise (Refused why)

let create_empty ~path ~measure ~scale =
  let book = get "empty-book-refused" (B.empty ~measure ~scale) in
  let bytes = text_of book X.no_sidecars in
  write_new path bytes;
  sync_parent path;
  let session = load path in
  require (session.revision = revision_of_bytes bytes) "first-run-cold-readback-changed";
  session

(* The file is still exactly what this session last saw: same inode, size and
   modification time, and the same bytes. *)
let unchanged session =
  match Unix.lstat session.path with
  | s when stamp_of s = session.stamp && s.st_kind = Unix.S_REG ->
      read_revision session.path = session.revision
  | _ -> false
  | exception Unix.Unix_error (Unix.ENOENT, _, _) -> false

let prev_path path = path ^ ".prev"
let temp_prefix path = Filename.basename path ^ ".publish-"

type publication_step = Temp_written | Previous_kept | Replaced

(* Replace the whole file with [bytes]. The book file exists at every instant (old or
   new); the replaced file becomes [.prev]. Stale temporaries of an interrupted
   publication are redundant and removed first. *)
let replace ~checkpoint path bytes =
  let dir = Filename.dirname path in
  Sys.readdir dir
  |> Array.iter (fun name ->
      if String.starts_with ~prefix:(temp_prefix path) name then
        Unix.unlink (Filename.concat dir name));
  let suffix = nonce () in
  let tmp = path ^ ".publish-" ^ suffix in
  write_new tmp bytes;
  checkpoint Temp_written;
  let prev_tmp = path ^ ".publish-" ^ suffix ^ ".prev" in
  Unix.link path prev_tmp;
  Unix.rename prev_tmp (prev_path path);
  (* rename(2) does nothing when both names already link the same file, as after a
     publication interrupted here; the spare link is then redundant. *)
  (try Unix.unlink prev_tmp with Unix.Unix_error (Unix.ENOENT, _, _) -> ());
  checkpoint Previous_kept;
  Unix.rename tmp path;
  sync_parent path;
  checkpoint Replaced

(* The book after [changes] and, when given, these roles and Attention. *)
let saved ?sidecars session changes =
  let book =
    match B.apply session.book changes with Ok book -> book | Error why -> raise (Refused why)
  in
  match sidecars with
  | None -> book
  | Some s -> (
      match X.with_sidecars book s with Ok book -> book | Error why -> raise (Refused why))

(* The revision the file has once [publish] writes [changes] (and [sidecars]). *)
let revision_after ?sidecars session changes =
  revision_of_bytes (T.print (B.txt (saved ?sidecars session changes)))

(* Checkpoints are for deterministic fault/child-process interruption checks;
   ordinary callers use the no-op default and cannot bypass any gate. *)
let publish ?(checkpoint = fun _ -> ()) ?sidecars session changes =
  let attempted = ref None in
  try
    let book = saved ?sidecars session changes in
    let sidecars = X.sidecars_of book in
    let bytes = T.print (B.txt book) in
    with_writer session.path (fun () ->
        if not (unchanged session) then Conflict
        else
          let expected = revision_of_bytes bytes in
          attempted := Some expected;
          replace ~checkpoint session.path bytes;
          (* The in-memory book equals its book.txt reload (test/book_cold_reload_tests.ml),
             so only the bytes are read back. *)
          require (read session.path = bytes) "published-readback-changed";
          Written
            {
              session with
              revision = expected;
              book;
              sidecars;
              stamp = stamp_of (Unix.lstat session.path);
            })
  with
  | Refused why -> (
      match !attempted with Some expected -> Uncertain { expected } | None -> Refused_input why)
  | Unix.Unix_error _ | Sys_error _ -> (
      match !attempted with
      | Some expected -> Uncertain { expected }
      | None -> Refused_input "file-or-writer-unavailable")

(* Whether a reloaded session shows the revision an uncertain publication promised. *)
let confirms ~expected session = session.revision = expected

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
  let bytes, _ = read_stamped source in
  ignore (of_bytes source bytes (stamp_of (Unix.lstat source)));
  write_new target bytes;
  sync_parent target;
  require (read_revision source = revision_of_bytes bytes) "source-changed-during-copy"
