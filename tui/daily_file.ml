(* One selected S-expression file and separate pre-edit backups.
   Cooperative writers/stable parent namespaces; not a security sandbox or a
   qualified power-loss protocol. No background retry, recovery or pruning. *)
module B = Bakhlo_sexp.Daily_book

exception Refused of string

let require p why = if not p then raise (Refused why)
let get why = function Ok x -> x | Error _ -> raise (Refused why)

type t = { path : string; bytes : string; book : B.t }
type outcome = Written of t | Conflict | Refused_input of string | Uncertain

let read path =
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
      let b = Buffer.create 4096 and chunk = Bytes.create 4096 in
      let rec loop () =
        let n = Unix.read fd chunk 0 4096 in
        if n > 0 then (
          Buffer.add_subbytes b chunk 0 n;
          loop ())
      in
      loop ();
      require (check (Unix.fstat fd) && check (Unix.lstat path)) "changed-during-read";
      Buffer.contents b)

let load path =
  let bytes = read path in
  { path; bytes; book = get "book-refused" (B.of_string bytes) }

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

let write_new path bytes =
  let fd = Unix.openfile path [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_EXCL; Unix.O_CLOEXEC ] 0o600 in
  Fun.protect
    ~finally:(fun () -> Unix.close fd)
    (fun () ->
      let rec loop n =
        if n < String.length bytes then (
          let count = Unix.write_substring fd bytes n (String.length bytes - n) in
          require (count > 0) "zero-write";
          loop (n + count))
      in
      loop 0;
      Unix.fsync fd);
  require (read path = bytes) "readback-changed"

let sync_parent path =
  let fd = Unix.openfile (Filename.dirname path) [ Unix.O_RDONLY; Unix.O_CLOEXEC ] 0 in
  Fun.protect ~finally:(fun () -> Unix.close fd) (fun () -> Unix.fsync fd)

let create_copy ~source ~target =
  let original = load source in
  let bytes = B.to_string original.book in
  ignore (get "printed-book-refused" (B.of_string bytes));
  write_new target bytes;
  sync_parent target;
  require (read source = original.bytes) "source-changed-during-copy"

let publish session book =
  let attempted = ref false in
  try
    let bytes = B.to_string book in
    let checked = get "printed-book-refused" (B.of_string bytes) in
    require (B.to_string checked = bytes) "unstable-printer";
    let lockpath = session.path ^ ".lock" in
    (try require ((Unix.lstat lockpath).st_kind = Unix.S_REG) "nonregular-lock"
     with Unix.Unix_error (Unix.ENOENT, _, _) -> ());
    let fd = Unix.openfile lockpath [ Unix.O_RDWR; Unix.O_CREAT; Unix.O_CLOEXEC ] 0o600 in
    Fun.protect
      ~finally:(fun () -> Unix.close fd)
      (fun () ->
        require
          ((Unix.fstat fd).st_kind = Unix.S_REG
          && (Unix.lstat lockpath).st_kind = Unix.S_REG
          && (Unix.fstat fd).st_ino = (Unix.lstat lockpath).st_ino)
          "changed-lock";
        Unix.lockf fd Unix.F_TLOCK 0;
        if read session.path <> session.bytes then Conflict
        else
          let suffix = nonce () in
          let pending = session.path ^ ".pending-" ^ suffix in
          let backup = session.path ^ ".before-" ^ suffix ^ ".sexp" in
          attempted := true;
          write_new pending bytes;
          write_new backup session.bytes;
          sync_parent session.path;
          if read session.path <> session.bytes then Conflict
          else (
            Unix.rename pending session.path;
            sync_parent session.path;
            require (read session.path = bytes) "selected-readback-changed";
            Written { session with bytes; book = checked }))
  with
  | Refused why -> if !attempted then Uncertain else Refused_input why
  | Unix.Unix_error _ | Sys_error _ ->
      if !attempted then Uncertain else Refused_input "file-or-writer-unavailable"

let today () =
  let tm = Unix.localtime (Unix.time ()) in
  Printf.sprintf "%04d-%02d-%02d" (tm.Unix.tm_year + 1900) (tm.Unix.tm_mon + 1) tm.Unix.tm_mday
