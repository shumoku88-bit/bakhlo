(* Standard Irmin HEAD only. No root manifest, GC, merge or production changes. *)
open Lwt.Syntax
module T=Trial_image
module Conf=struct
  let entries=32 let stable_hash=0 let contents_length_header=Some `Varint
  let inode_child_order=`Hash_bits let forbid_empty_dir_persistence=true
end
module Maker=Irmin_pack_unix.KV(Conf)
module S=Maker.Make(Irmin.Contents.String)
let require=T.require
let head_id c=Fmt.str "%a" S.Commit.pp_hash c
let config root readonly=Irmin_pack.config ~readonly ~use_fsync:true ~no_migrate:true
  ~indexing_strategy:Irmin_pack.Indexing_strategy.minimal ~index_log_size:1000 root
let rec all_cells tree p =
  let* kind=S.Tree.kind tree p in match kind with
  | None -> Lwt.return []
  | Some `Contents -> let+ v=S.Tree.get tree p in [p,v]
  | Some `Node -> let* children=S.Tree.list tree p in
      let+ groups=Lwt_list.map_s(fun(step,_)->all_cells tree (p@[step]))children in List.concat groups
let load tree = let+ cells=all_cells tree [] in
  let x=T.from_cells(fun p->match List.assoc_opt p cells with Some s->s|None->failwith "required-cell-missing") in
  let actual=List.sort compare cells and expected=List.sort compare(T.cells x) in
  require(actual=expected) "unknown-or-extra-tree-cell-refused";x
let checkpoint name =
  Printf.printf "checkpoint\t%s\n%!" name;
  match Sys.getenv_opt "TRIAL_CHECKPOINT" with
  | Some wanted when wanted=name ->
      (match Sys.getenv_opt "TRIAL_STOP" with Some "kill"->Unix.kill(Unix.getpid()) Sys.sigkill
       | _->failwith("injected-returned-fault:"^name))
  | _ -> ()
let mutate root op expected output =
  let lock=root^".writer" in
  let fd=Unix.openfile lock [Unix.O_CREAT;Unix.O_RDWR] 0o600 in
  Unix.lockf fd Unix.F_TLOCK 0;
  let* repo=S.Repo.v(config root false) in
  Lwt.finalize (fun()->
    let* store=S.main repo in let* old=S.Head.find store in
    let* present=S.Branch.mem repo S.Branch.main in
    require(not(present && Option.is_none old)) "dangling-selected-branch";
    require((op="initial")=Option.is_none old) "explicit-initialization-required-or-already-initialized";
    let observed=match old with None->"none"|Some h->head_id h in
    if observed<>expected then (Printf.printf "outcome\tconflict\t%s\n%!" observed;Lwt.return_unit)
    else
      let* current=match old with None->Lwt.return(T.fixture())|Some h->load(S.Commit.tree h) in
      let candidate=if op="initial" then current else
        let b=T.change(T.get(T.B.of_string current.book))op in T.check b op;
        {current with book=T.B.to_string b;parent=observed;operation=op} in
      T.verify_complete candidate;
      let base=match old with None->S.Tree.empty()|Some h->S.Commit.tree h in
      let changes=ref 0 in
      let* tree=Lwt_list.fold_left_s(fun tree (p,v)->let* before=S.Tree.find tree p in
        if before=Some v then Lwt.return tree else (incr changes;S.Tree.add tree p v))base(T.cells candidate) in
      checkpoint "tree-ready";
      Unix.putenv "TRIAL_FAULT_ARMED" "1";
      checkpoint "before-commit";
      let* committed=S.Commit.v repo ~info:S.Info.empty ~parents:(match old with None->[]|Some h->[S.Commit.key h])tree in
      let candidate_id=head_id committed in
      Printf.printf "candidate\t%s\tchanged_cells=%d\n%!" candidate_id !changes;
      checkpoint "commit-returned";
      S.flush repo;checkpoint "flush-returned";
      checkpoint "before-head";
      let* chosen=S.Head.test_and_set store ~test:old ~set:(Some committed) in
      require chosen "head-CAS-rejected";checkpoint "head-returned";
      let* seen=S.Head.get store in require(head_id seen=candidate_id) "head-readback";
      let* checked=load(S.Commit.tree seen) in
      require(checked=candidate) "tree-readback-mismatch";
      checkpoint "readback";
      T.write_new output (T.archive ~head:candidate_id checked);
      Printf.printf "outcome\thead-update-success-not-durability\t%s\n%!" candidate_id;
      checkpoint "before-close";Lwt.return_unit)
    (fun()->let+ ()=S.Repo.close repo in Unix.close fd;checkpoint "closed")
let inspect root output =
  let* repo=S.Repo.v(config root true) in
  Lwt.finalize(fun()->let* store=S.main repo in let* head=S.Head.find store in
    match head with
    | None -> let* present=S.Branch.mem repo S.Branch.main in
        Printf.printf "selection\tno-resolved-head\tbranch-present=%b\n%!" present;
        if present then failwith "dangling-selected-branch" else Lwt.return_unit
    | Some h -> let* x=load(S.Commit.tree h) in T.write_new output(T.archive ~head:(head_id h)x);
        Printf.printf "selection\tvalid\t%s\toperation=%s\n%!" (head_id h) x.operation;Lwt.return_unit)
    (fun()->S.Repo.close repo)
let stale root output =
  let fd=Unix.openfile(root^".writer")[Unix.O_CREAT;Unix.O_RDWR]0o600 in Unix.lockf fd Unix.F_TLOCK 0;
  let* repo=S.Repo.v(config root false) in
  Lwt.finalize(fun()->let* store=S.main repo in let* old=S.Head.get store in let* x=load(S.Commit.tree old) in
    let* t1=S.Tree.add(S.Commit.tree old)["publication"] (T.sx(T.X.List[T.atom(head_id old);T.atom "branch-a"])) in
    let* c1=S.Commit.v repo ~info:S.Info.empty ~parents:[S.Commit.key old] t1 in
    let* t2=S.Tree.add(S.Commit.tree old)["publication"] (T.sx(T.X.List[T.atom(head_id old);T.atom "branch-b"])) in
    let* c2=S.Commit.v repo ~info:S.Info.empty ~parents:[S.Commit.key old] t2 in
    let* a=S.Head.test_and_set store ~test:(Some old) ~set:(Some c1) in
    let* b=S.Head.test_and_set store ~test:(Some old) ~set:(Some c2) in
    require(a && not b) "stale-CAS-not-rejected";
    let* selected=S.Head.get store in require(head_id selected=head_id c1) "CAS-failure-changed-head";
    T.write_new output(T.archive ~head:(head_id selected){x with parent=head_id old;operation="branch-a"});
    print_endline "PASS: stock head CAS accepts first writer and rejects stale second candidate.";Lwt.return_unit)
    (fun()->let+ ()=S.Repo.close repo in Unix.close fd)
let () =
  ignore(Unix.umask 0o077);
  try Lwt_main.run(match Array.to_list Sys.argv with
    | [_;"mutate";root;op;expected;output]->mutate root op expected output
    | [_;"inspect";root;output]->inspect root output
    | [_;"stale";root;output]->stale root output
    | _->failwith "usage: mutate/inspect/stale")
  with exn -> Printf.eprintf "trial-refused\t%s\n%!" (Printexc.to_string exn);exit 2
