(* Exact-byte annual backup, not import/adoption or an alternative ledger store. *)
module F = Daily_file
module B = Bakhlo_sexp.Daily_book
module Annual = Bakhlo_sexp.Annual_scope
module Wire = Bakhlo_sexp.Annual_book
module X = Sexplib0.Sexp

let fingerprint bytes = Digest.to_hex (Digest.string bytes)
let atom s = X.Atom s
let field tag xs = X.List (atom tag :: xs)
let require = F.require

let validate selected files =
  require (files <> []) "annual-backup-empty";
  let rec loop prior = function
    | [] -> ()
    | (year, bytes) :: rest ->
        let book =
          match prior with
          | None ->
              let book = F.get "annual-backup-root-invalid" (B.of_string bytes) in
              ignore (F.get "annual-backup-root-year" (Annual.check_book ~year book));
              book
          | Some (previous_year, previous_bytes, previous_book) ->
              require (year = previous_year + 1) "annual-backup-incomplete-chain";
              let wire = F.get "annual-backup-envelope-invalid" (Wire.of_string bytes) in
              let reference = Wire.reference wire in
              require (Wire.year wire = year && reference.year = previous_year
                       && reference.fingerprint = fingerprint previous_bytes)
                "annual-backup-provenance-mismatch";
              F.get "annual-backup-core-refused" (Wire.decode ~prior:previous_book wire)
        in
        loop (Some (year, bytes, book)) rest
  in
  loop None files;
  require (fst (List.hd (List.rev files)) = selected) "annual-backup-wrong-selection"

let encode selected files =
  X.to_string_hum (field "bakhlo-annual-backup"
      (atom "1" :: field "selected" [atom (string_of_int selected)]
       :: List.map (fun (year, bytes) ->
           field "file" [atom (string_of_int year); atom (fingerprint bytes); atom bytes]) files)) ^ "\n"

let decode bytes =
  let years s = F.get "annual-backup-invalid-year" (Annual.of_string s) in
  let files, selected =
    match F.get "annual-backup-syntax" (Parsexp.Many.parse_string bytes) with
    | [X.List (X.Atom "bakhlo-annual-backup" :: X.Atom "1"
              :: X.List [X.Atom "selected"; X.Atom selected] :: rows)] ->
        let files = List.map (function
          | X.List [X.Atom "file"; X.Atom year; X.Atom digest; X.Atom contents] ->
              require (fingerprint contents = digest) "annual-backup-bytes-replaced";
              (years year, contents)
          | _ -> raise (F.Refused "annual-backup-invalid-file")) rows in
        files, years selected
    | _ -> raise (F.Refused "annual-backup-unsupported")
  in
  validate selected files;
  selected, files

let backup ~session ~target =
  let selected = match session.F.annual_year with
    | Some year -> year
    | None -> raise (F.Refused "annual-backup-requires-annual-book") in
  let files = F.annual_sources session |> List.map (fun (path, bytes) ->
      let name = Filename.basename path in
      require (String.length name = 9 && Filename.check_suffix name ".sexp")
        "annual-backup-invalid-name";
      F.get "annual-backup-invalid-year" (Annual.of_string (String.sub name 0 4)), bytes) in
  validate selected files;
  let bytes = encode selected files in
  ignore (decode bytes);
  F.write_new target bytes;
  F.sync_parent target;
  require (F.read target = bytes) "annual-backup-readback-changed";
  fingerprint bytes

let restore ~source ~directory =
  let bytes = F.read source in
  let selected, files = decode bytes in
  (* Exclusive directory creation makes a partial restore non-adopted and protects originals. *)
  Unix.mkdir directory 0o700;
  F.sync_parent directory;
  List.iter (fun (year, contents) ->
      let path = Filename.concat directory (Annual.file_name year) in
      F.write_new path contents;
      F.sync_parent path;
      require (F.read path = contents) "annual-restore-readback-changed") files;
  let path = Filename.concat directory (Annual.file_name selected) in
  let session = F.load ~annual_year:selected path in
  let restored = F.annual_sources session |> List.map snd in
  require (restored = List.map snd files) "annual-restore-chain-changed";
  require (F.read source = bytes) "annual-backup-source-changed";
  path
