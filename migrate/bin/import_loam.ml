(* Cutover-day import (user decision 2026-10-21): read one quiet LOAM generation and
   create a NEW Bakhlo household directory. LOAM is only read; an existing
   destination is never touched; a failed run leaves no destination. *)
module L = Bakhlo_migrate.Loam_import
module B = Bakhlo_sexp.Daily_book

exception Refused of string

let require p why = if not p then raise (Refused why)
let budget = 64 * 1024 * 1024
let stat path = try Some (Unix.lstat path) with Unix.Unix_error (Unix.ENOENT, _, _) -> None

let stamp (s : Unix.stats) = (s.st_dev, s.st_ino, s.st_kind, s.st_size, s.st_mtime, s.st_ctime)

let read path =
  match stat path with
  | None -> None
  | Some s ->
      require (s.st_kind = Unix.S_REG && s.st_size <= budget) ("not-a-regular-file " ^ path);
      let bytes = In_channel.with_open_bin path In_channel.input_all in
      Some (stamp s, bytes)

(* Budget-only configuration and LOAM's own files stay in the LOAM record;
   accounting-roles.tsv comes from the household section. *)
let skipped name =
  List.mem name [ "accounting-roles.tsv"; "purpose-catalog.tsv"; "cycle-funding.tsv" ]
  || Filename.check_suffix name ".loam-writer-lock"

let snapshot source =
  let config = Filename.concat source "config" in
  let names =
    match stat config with
    | None -> []
    | Some s ->
        require (s.st_kind = Unix.S_DIR) "config-not-a-directory";
        Array.to_list (Sys.readdir config) |> List.sort String.compare
  in
  List.map (fun name -> (name, read (Filename.concat source name)))
    ("household.loam" :: List.map (fun n -> "config/" ^ n) names)

let bytes_of snapshot name =
  match List.assoc_opt name snapshot with Some (Some (_, b)) -> Some b | _ -> None

let needed snapshot name =
  match bytes_of snapshot name with Some b -> b | None -> raise (Refused ("missing " ^ name))

let write_new path bytes =
  let fd = Unix.openfile path [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_EXCL; Unix.O_CLOEXEC ] 0o600 in
  Fun.protect ~finally:(fun () -> Unix.close fd) (fun () ->
      let rec loop offset =
        if offset < String.length bytes then
          loop (offset + Unix.write_substring fd bytes offset (String.length bytes - offset))
      in
      loop 0;
      Unix.fsync fd)

let note ~source ~revision ~now =
  String.concat "\n"
    [ "# LOAMの記録について";
      "";
      Printf.sprintf "- 取り込んだ日時: %s" now;
      Printf.sprintf "- 取り込み元（LOAM、読み取りのみ・変更していない）: %s" source;
      Printf.sprintf "- 取り込み元のGitの版: %s" revision;
      "";
      "この日より前の家計簿はLOAMで付けていた。Bakhloには取り込んだ時点の現在の状態だけがある。";
      "次の情報はLOAMの記録（上の場所とそのGit履歴）にだけ残っている。";
      "";
      "- 明細の訂正の途中経過（訂正前の値）";
      "- 取り消した予定、置き換えた予定";
      "- 訂正前の明細に付いていたMerchant";
      "- 予算（Capacity、ActualRouting、ScheduledRouting、purpose-catalog、cycle-funding）";
      "";
      "AIに家計を相談するときは、この案内も一緒に渡す。";
      "" ]

let run ~source ~destination ~revision =
  let source = Unix.realpath source in
  require (stat destination = None) "destination-exists";
  let parent = Unix.realpath (Filename.dirname destination) in
  let destination = Filename.concat parent (Filename.basename destination) in
  require
    (not (String.starts_with ~prefix:(source ^ "/") (destination ^ "/")))
    "destination-inside-source";
  let before = snapshot source in
  let household = needed before "household.loam" in
  let ok = function Ok x -> x | Error why -> raise (Refused why) in
  let book =
    ok (L.book { household; measure_presentation = needed before "config/measure-presentation.tsv";
                 locus_catalog = bytes_of before "config/locus-catalog.tsv" })
  in
  let roles = ok (L.accounting_roles household) and attention = ok (L.attention household) in
  let printed = B.to_string book in
  require (Result.map B.to_string (B.of_string printed) = Ok printed) "book-roundtrip-changed";
  let staging = Printf.sprintf "%s.partial-%d" destination (Unix.getpid ()) in
  Unix.mkdir staging 0o700;
  Unix.mkdir (Filename.concat staging "config") 0o700;
  let into name = Filename.concat staging name in
  write_new (into "book.sexp") printed;
  Option.iter (write_new (into "attention.loam")) attention;
  write_new (into "config/accounting-roles.tsv") roles;
  List.iter (fun (name, value) ->
      match value with
      | Some (_, b) when String.starts_with ~prefix:"config/" name
                         && not (skipped (Filename.basename name)) ->
          write_new (into name) b
      | _ -> ())
    before;
  let now =
    let t = Unix.localtime (Unix.time ()) in
    Printf.sprintf "%04d-%02d-%02d %02d:%02d" (t.tm_year + 1900) (t.tm_mon + 1) t.tm_mday t.tm_hour t.tm_min
  in
  write_new (into "LOAM-RECORD.md") (note ~source ~revision ~now);
  (* The book written to disk must read back as the same book. *)
  require (Result.map B.to_string (B.of_string (In_channel.with_open_bin (into "book.sexp") In_channel.input_all))
           = Ok printed) "written-book-differs";
  require (snapshot source = before) "source-changed-during-import";
  require (stat destination = None) "destination-appeared";
  Unix.rename staging destination;
  Printf.printf
    "PASS: imported %d entries, %d open plans%s into %s. LOAM was only read.\n"
    (B.entry_count book) (List.length (B.open_plans book))
    (if attention = None then "" else ", Attention")
    destination

let () =
  match Array.to_list Sys.argv with
  | [ _; source; destination; revision ] -> (
      try run ~source ~destination ~revision with
      | Refused why ->
          prerr_endline ("Import refused: " ^ why ^ ". LOAM untouched; no destination created.");
          exit 2
      | Unix.Unix_error (e, op, arg) ->
          prerr_endline
            (Printf.sprintf "Import stopped: %s %s %s. LOAM untouched; any .partial directory is kept for inspection."
               (Unix.error_message e) op arg);
          exit 2)
  | _ ->
      prerr_endline "Usage: import_loam LOAM_DIRECTORY NEW_BAKHLO_DIRECTORY REVISION";
      exit 2
