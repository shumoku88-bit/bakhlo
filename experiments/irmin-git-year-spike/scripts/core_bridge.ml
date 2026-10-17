(* Synthetic-only bridge between a pinned Irmin Git commit and Bakhlo Year_read.
   No production authority, durable Saved, or Core changes are claimed. *)
module Store = Irmin_git_unix.FS.KV (Irmin.Contents.String)
module Y = Bakhlo_sexp.Year_read
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain

let require message ok = if not ok then failwith ("core-bridge: " ^ message)
let get = function Ok x -> x | Error _ -> failwith "core admission refused"
let path year leaf = [ "years"; string_of_int year; leaf ]
let info message =
  Irmin_git_unix.info ~author:"Bakhlo synthetic experiment <noreply@example.invalid>" "%s" message

let fixture entries support =
  "(bakhlo-daily 3) (scope corrected-entries explicit-plans)\n\
   (measures (measure jpy 0)) (labels (not-supplied))\n\
   (approved-loci (not-supplied)) (entries " ^ entries ^ ") (plans)\n(support " ^ support ^ ")"

let prior amount =
  fixture
    (Printf.sprintf
       "(entry spend (date 2025-06-01) (memo (none))\n\
        (postings (posting wallet jpy -%d (none)) (posting food jpy %d (none)))\n\
        (reversal-of (none)) (exchange (none)))" amount amount)
    "(zero-origin (food jpy) (tax jpy)) (openings)\n\
     (observations (observation (reflected) (quantities (wallet jpy 10))))\n\
     (presence (provided (reflected) (coordinates (bank jpy))))"

let current =
  fixture "" "(zero-origin) (openings) (observations) (presence (not-supplied))"

let publish store ~message changes =
  let open Lwt.Syntax in
  Lwt_main.run
    (let* base = Store.tree store in
     let rec apply tree = function
       | [] -> Lwt.return tree
       | (key, value) :: rest ->
           let* updated = Store.Tree.add tree key value in
           apply updated rest
     in
     let* tree = apply base changes in
     Store.set_tree_exn store [] tree ~info:(info message))

(* In this limited fixture the observed Git HEAD is the selected root.
   All original bytes and revisions come from that ONE immutable commit,
   never from a mutable live head in read(). This does not certify its
   durability, independent authenticity, concurrency or external config. *)
module Source = struct
  type snapshot = { pinned : Store.t; selection : Y.selection }

  let opened : Store.t option ref = ref None

  let find pinned key = Lwt_main.run (Store.find pinned key)

  let required pinned key =
    match find pinned key with
    | Some value -> value
    | None -> failwith ("missing cell " ^ String.concat "/" key)

  let revision pinned year =
    try int_of_string (required pinned (path year "revision"))
    with Failure _ -> failwith ("invalid revision for " ^ string_of_int year)

  let acquire () =
    match !opened with
    | None -> Error Y.Selection_missing
    | Some store ->
        (try
           let commit = Lwt_main.run (Store.Head.get store) in
           let pinned = Lwt_main.run (Store.of_commit commit) in
           let generation = int_of_string (required pinned [ "meta"; "generation" ]) in
           let years =
             List.map
               (fun year ->
                  let revision = revision pinned year in
                  let contents = required pinned (path year "book") in
                  let selected : Y.selected =
                    { year; revision; fingerprint = Y.fingerprint contents }
                  in
                  selected)
               [ 2025; 2026 ]
           in
           let selection : Y.selection = { generation; years } in
           Ok { pinned; selection }
         with exn -> Error (Y.Selection_corrupt (Printexc.to_string exn)))

  let selection snapshot = snapshot.selection

  let read snapshot ~year =
    let selected =
      List.find_opt (fun (s : Y.selected) -> s.year = year) snapshot.selection.years
    in
    match selected with
    | None -> Error (Y.Year_missing year)
    | Some s ->
        (match find snapshot.pinned (path year "book") with
         | None -> Error (Y.Original_missing year)
         | Some contents ->
             (try
                let revision = revision snapshot.pinned year in
                let original : Y.original =
                  { generation = snapshot.selection.generation; year; revision; contents }
                in
                Ok original
              with exn -> Error (Y.Original_unavailable (Printexc.to_string exn))))
end

module Read = Y.Make (Source)

let coordinate locus =
  { D.Effect_coordinate.locus = get (D.Identifier.Locus.of_string locus);
    measure = get (D.Identifier.Measure.of_string "jpy") }

let check_balances read ~wallet ~food =
  let exact locus expected =
    match Read.carry_balance read (coordinate locus) with
    | Y.Exact q -> require ("wrong " ^ locus)
                     (Z.equal (D.Quantity.quanta q) (Z.of_int expected))
    | _ -> failwith ("expected exact for " ^ locus)
  in
  exact "wallet" wallet;
  exact "food" food;
  require "lost explicit zero"
    (match Read.carry_balance read (coordinate "tax") with Y.Zero_origin -> true | _ -> false);
  require "known-present became a number"
    (match Read.carry_balance read (coordinate "bank") with Y.Known_present -> true | _ -> false);
  require "unknown became zero"
    (match Read.carry_balance read (coordinate "salary") with Y.Unknown -> true | _ -> false);
  require "current year silently inherited an independent observation"
    (Result.is_error
       (B.Q.query (B.image (Read.current_book read)) (coordinate "wallet")))

let run () =
  let root = Filename.temp_file "bakhlo-git-core-bridge-" "" in
  Sys.remove root;
  Unix.mkdir root 0o700;
  let config = Irmin_git.config ~bare:true root in
  let repo = Lwt_main.run (Store.Repo.v config) in
  let store = Lwt_main.run (Store.main repo) in
  Source.opened := Some store;
  publish store ~message:"synthetic: two real Bakhlo Daily books"
    [ [ "meta"; "generation" ], "1";
      path 2025 "revision", "1";
      path 2025 "book", prior 3;
      path 2026 "revision", "1";
      path 2026 "book", current ];
  let original = get (Read.begin_session ()) in
  let carry = get (Read.derive_carry_forward original (get (Read.load_year original ~year:2025))) in
  let original_read = get (Read.read_with_carry original ~year:2026 carry) in
  check_balances original_read ~wallet:7 ~food:3;

  (* One new Git root revises the 2025 source. 2026 is not re-written.
     Old pinned sessions remain historical; carrying them to a new session fails. *)
  publish store ~message:"synthetic: revise preceding year"
    [ [ "meta"; "generation" ], "2";
      path 2025 "revision", "2";
      path 2025 "book", prior 4 ];
  let fresh = get (Read.begin_session ()) in
  require "old carry was accepted with a new year revision"
    (match Read.read_with_carry fresh ~year:2026 carry with
     | Error (Y.Revision_mismatch { year = 2025; expected = 2; actual = 1 }) -> true
     | _ -> false);
  let fresh_carry = get (Read.derive_carry_forward fresh (get (Read.load_year fresh ~year:2025))) in
  check_balances (get (Read.read_with_carry fresh ~year:2026 fresh_carry))
    ~wallet:6 ~food:4;
  check_balances (get (Read.read_with_carry original ~year:2026 carry))
    ~wallet:7 ~food:3;
  Lwt_main.run (Store.Repo.close repo);

  (* Reopen: the reloaded commit still supplies Bakhlo's real Core input. *)
  let reopened_repo = Lwt_main.run (Store.Repo.v config) in
  let reopened = Lwt_main.run (Store.main reopened_repo) in
  Source.opened := Some reopened;
  let cold = get (Read.begin_session ()) in
  let cold_carry = get (Read.derive_carry_forward cold (get (Read.load_year cold ~year:2025))) in
  check_balances (get (Read.read_with_carry cold ~year:2026 cold_carry))
    ~wallet:6 ~food:4;

  (* An invalid commit is rejected by existing Bakhlo admission. *)
  publish reopened ~message:"synthetic: deliberately invalid year"
    [ [ "meta"; "generation" ], "3";
      path 2025 "revision", "3";
      path 2025 "book", "(bakhlo-daily 3)" ];
  let invalid = get (Read.begin_session ()) in
  require "malformed year passed Core admission"
    (match Read.load_year invalid ~year:2025 with
     | Error (Y.Admission_failed { year = 2025; reason = _ })
     | Error (Y.Unsupported_format 2025) -> true
     | _ -> false);
  Lwt_main.run (Store.Repo.close reopened_repo);
  print_endline "PASS: pinned Irmin Git -> Year_read -> Bakhlo Core";
  print_endline "PASS: exact/zero/presence/unknown; old carry rejected; cold reopen; bad year rejected";
  print_endline "UNTESTED: write CAS, cross-year plan completion, durable Saved, crash/ack loss, backup"

let () = run ()
