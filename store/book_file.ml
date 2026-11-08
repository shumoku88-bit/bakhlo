(* From an admitted book to a confirmed save.

   Suppose a new entry reaches book.txt, then an I/O error prevents [Written]
   from reaching the caller. Reporting an ordinary refusal would invite the
   caller to record it again. Instead, keep the candidate's revision and
   report [Uncertain]: reload to find out what is there, do not repeat the write.
   test/book_file_tests.ml makes this interruption concrete on synthetic files.

   The file is the common book.txt, including roles and Attention. Book owns
   what may be recorded; this module owns reading and replacing the file.
   We prepare the whole new file before replacing the old one, keeping the old
   file as .prev. The session ties an admitted book to the file it last saw.

   These checks assume cooperative writers and stable parent namespaces, not
   a security sandbox. Flushes request durability; physical power loss remains
   untested. There is no background retry or automatic repair. *)
module B = Bakhlo_household.Book
module T = Bakhlo_book_txt.Book_txt

exception Refused of string

let require p why = if not p then raise (Refused why)
let get why = function Ok x -> x | Error _ -> raise (Refused why)

(* Request the platform's durable flush: F_FULLFSYNC where available on macOS,
   fsync elsewhere. The implementation is in full_sync_stubs.c. *)
external full_sync : Unix.file_descr -> unit = "bakhlo_full_sync"

(* Send a file's bytes to the drive, ordered before any later write (such as the
   rename that names them), without waiting for the drive cache: F_BARRIERFSYNC
   on macOS, fsync elsewhere. Only a later [full_sync] makes them durable. *)
external barrier_sync : Unix.file_descr -> unit = "bakhlo_barrier_sync"

type stamp = { dev : int; ino : int; size : int; mtime : float }

type t = {
  path : string;
  revision : string;  (** {!revision_of_bytes} of the file this session last saw. *)
  book : B.t;
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

(* 1. Read one file, not pieces of two versions.

   The pathname can change between inspecting it and opening it. Check the
   opened descriptor against the initial file, read exactly its size, then
   check both the descriptor and pathname again. The returned stamp belongs
   to the bytes we accepted; it will help detect a stale session at save time. *)
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

(* The lock has its own stable name because publishing replaces the book's
   inode. It serializes cooperative writers, but does not prove that a session
   is current: [publish] must check that separately while holding the lock.
   Nested calls in this process reuse the lock via [writer_locks]. *)
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

(* A revision is a length-and-digest token for comparing observed contents.
   It is not a backup, an audit history or a security boundary. *)
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
      | Ok book -> { path; revision = revision_of_bytes bytes; book; stamp })

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

(* 2. Finish the candidate before giving it the book's name.

   Exclusive creation prevents overwriting an existing file. A successful
   write only fills the OS buffers: send the bytes to the drive ahead of the
   rename that will name them, and check them too. This orders the contents; it
   does not make them durable. Every caller then renames or names the file and
   fully syncs its directory, which flushes the drive cache, these bytes
   included, before anything is reported (about 20 ms saved per save here). *)
let write_new path bytes =
  let fd = Unix.openfile path [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_EXCL; Unix.O_CLOEXEC ] 0o600 in
  Fun.protect
    ~finally:(fun () -> Unix.close fd)
    (fun () ->
      write_all fd bytes;
      barrier_sync fd);
  require (read path = bytes) "readback-changed"

(* File contents and directory names are different things to flush. After
   creating or replacing a name, request a flush of its containing directory. *)
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

let create_empty ~path ~measure ~scale =
  let book = get "empty-book-refused" (B.empty ~measure ~scale) in
  let bytes = T.print (B.txt book) in
  write_new path bytes;
  sync_parent path;
  let session = load path in
  require (session.revision = revision_of_bytes bytes) "first-run-cold-readback-changed";
  session

(* 3. Do not overwrite a book somebody else has saved.

   A matching stamp is a first check, not enough on its own: compare the
   contents' revision too. A changed stamp is refused even if the contents
   happen to match, because this is no longer the file the session observed. *)
let unchanged session =
  match Unix.lstat session.path with
  | s when stamp_of s = session.stamp && s.st_kind = Unix.S_REG ->
      read_revision session.path = session.revision
  | _ -> false
  | exception Unix.Unix_error (Unix.ENOENT, _, _) -> false

let prev_path path = path ^ ".prev"
let temp_prefix path = Filename.basename path ^ ".publish-"

type publication_step = Temp_written | Previous_kept | Replaced

(* Keep the old book reachable throughout replacement. Moving it to .prev
   first would leave a moment with no book.txt. Instead, hard-link it under a
   temporary name, replace .prev with that link, then rename the completed
   candidate onto book.txt. The names stay in the same directory/filesystem.

   Discard leftovers from interrupted publications; do not try to infer that
   a temporary file should become the book. The current book remains the
   authority. [checkpoint] exposes the three steps to interruption tests. *)
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

(* 4. Admit first, then publish, then report what we know.

   Applying changes is pure: an invalid batch never begins replacement. This
   also lets [revision_after] predict the candidate's revision without writing. *)
let saved session changes =
  match B.apply session.book changes with
  | Ok book -> book
  | Error why ->
      (* Keep the publication wording; detailed admission codes belong to Book. *)
      raise
        (Refused
           (if String.starts_with ~prefix:"entry-admission:" why then "entry-admission" else why))

(* The revision the file has once [publish] writes [changes]. *)
let revision_after session changes = revision_of_bytes (T.print (B.txt (saved session changes)))

(* Checkpoints are for deterministic fault/child-process interruption checks;
   ordinary callers use the no-op default and cannot bypass any gate. *)
let publish ?(checkpoint = fun _ -> ()) session changes =
  let attempted = ref None in
  try
    let book = saved session changes in
    let bytes = T.print (B.txt book) in
    with_writer session.path (fun () ->
        if not (unchanged session) then Conflict
        else
          let expected = revision_of_bytes bytes in
          (* From here an I/O failure cannot tell the caller whether the new
             book landed. Mark the attempt before any replacement work, even
             though a failure at its first step may still leave the old book. *)
          attempted := Some expected;
          replace ~checkpoint session.path bytes;
          (* The in-memory book equals its book.txt reload (test/book_cold_reload_tests.ml),
             so only the bytes are read back. *)
          require (read session.path = bytes) "published-readback-changed";
          Written
            { session with revision = expected; book; stamp = stamp_of (Unix.lstat session.path) })
  with
  | Refused why -> (
      match !attempted with Some expected -> Uncertain { expected } | None -> Refused_input why)
  | Unix.Unix_error _ | Sys_error _ -> (
      match !attempted with
      | Some expected -> Uncertain { expected }
      | None -> Refused_input "file-or-writer-unavailable")

(* A fresh load can establish that the candidate is now present, not how far
   the interrupted call got or whether its success was shown to the user. A
   non-match leaves it unconfirmed; it is not authorization to repeat it. *)
let confirms ~expected session = session.revision = expected

(* 5. Recovery makes a separate copy; it does not choose a new authority.

   A .prev file is evidence, not an instruction to roll back. Copy only to an
   explicitly fresh target, preserving original bytes. Checking that copy is
   neither automatic adoption, reconciliation nor a format upgrade. *)
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
