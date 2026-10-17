(* Synthetic-only Irmin Git storage boundary probe.
   This is not an accounting model, production publisher, or durable-Saved test. *)
open Lwt.Syntax

module Store = Irmin_git_unix.FS.KV (Irmin.Contents.String)

let info message =
  Irmin_git_unix.info ~author:"Bakhlo synthetic experiment <noreply@example.invalid>" "%s" message

let require label condition =
  if not condition then failwith ("irmin-year-spike: " ^ label)

let year_path year leaf = [ "years"; year; leaf ]

let publish store ~message changes =
  let* before = Store.tree store in
  let rec add_all tree = function
    | [] -> Lwt.return tree
    | (path, value) :: rest ->
        let* tree = Store.Tree.add tree path value in
        add_all tree rest
  in
  let* candidate = add_all before changes in
  (* One logical publication for all changed paths; no merge or silent retry.
     This does not itself establish disk durability or cross-process exclusion. *)
  Store.set_tree_exn store [] candidate ~info:(info message)

let check_value store path expected =
  let* actual = Store.get store path in
  require ("unexpected contents at " ^ String.concat "/" path) (String.equal expected actual);
  Lwt.return_unit

let run () =
  let root = Filename.temp_file "bakhlo-irmin-git-years-" "" in
  Sys.remove root;
  Unix.mkdir root 0o700;
  let config = Irmin_git.config ~bare:true root in
  let* repo = Store.Repo.v config in
  let* current = Store.main repo in

  (* A deliberately small, independently addressable object under each year. *)
  let* () =
    publish current ~message:"synthetic: seed independent years"
      [ (year_path "2026" "entry-a", "expense-2026-v1");
        (year_path "2027" "entry-b", "expense-2027-v1");
        (year_path "2027" "opening-source", "2026-revision-1") ]
  in
  let* original_commit = Store.Head.get current in
  let* old = Store.of_commit original_commit in

  (* Editing the current year does not overwrite the preceding year's entry. *)
  let* () =
    publish current ~message:"synthetic: edit only 2027"
      [ (year_path "2027" "entry-b", "expense-2027-v2") ]
  in
  let* () = check_value current (year_path "2026" "entry-a") "expense-2026-v1" in
  let* () = check_value old (year_path "2027" "entry-b") "expense-2027-v1" in
  let* () = check_value current (year_path "2027" "entry-b") "expense-2027-v2" in

  (* Two-year correction and dependent selection written as ONE new root. *)
  let* () =
    publish current ~message:"synthetic: cross-year publication"
      [ (year_path "2026" "entry-a", "expense-2026-corrected");
        (year_path "2027" "opening-source", "2026-revision-2") ]
  in
  let* () = check_value current (year_path "2026" "entry-a") "expense-2026-corrected" in
  let* () = check_value current (year_path "2027" "opening-source") "2026-revision-2" in
  let* () = check_value old (year_path "2026" "entry-a") "expense-2026-v1" in

  (* Reopen a separate repository handle; this is NOT a power-cut test. *)
  let* () = Store.Repo.close repo in
  let* reopened_repo = Store.Repo.v config in
  let* reopened = Store.main reopened_repo in
  let* () = check_value reopened (year_path "2026" "entry-a") "expense-2026-corrected" in
  let* () = check_value reopened (year_path "2027" "entry-b") "expense-2027-v2" in
  let* () = check_value reopened (year_path "2027" "opening-source") "2026-revision-2" in
  let* () = Store.Repo.close reopened_repo in
  print_endline "PASS: independent year paths; old commit; two-year root; reopen";
  print_endline "UNTESTED: actual household semantics, stale writers, fsync, crash, ack loss, restore";
  Lwt.return_unit

let () = Lwt_main.run (run ())
