module T=Trial_image
let mkdir p=Unix.mkdir p 0o700
let fd_new p=Unix.openfile p [Unix.O_CREAT;Unix.O_EXCL;Unix.O_WRONLY] 0o600
let run ~dir ?(env=[]) exe args =
  let out=fd_new(Filename.concat dir "stdout.txt") and err=fd_new(Filename.concat dir "stderr.txt") in
  let inherited=Array.to_list(Unix.environment()) |> List.filter(fun s->not(String.starts_with ~prefix:"TRIAL_" s || String.starts_with ~prefix:"DYLD_INSERT_LIBRARIES=" s)) in
  let pid=Unix.create_process_env exe (Array.of_list(exe::args)) (Array.of_list(env@inherited)) Unix.stdin out err in
  Unix.close out;Unix.close err; snd(Unix.waitpid [] pid)
let good = function Unix.WEXITED 0->true|_->false
let status = function Unix.WEXITED n->"exit-"^string_of_int n|Unix.WSIGNALED n->"signal-"^string_of_int n|Unix.WSTOPPED n->"stopped-"^string_of_int n
let rec copy src dst= match (Unix.lstat src).Unix.st_kind with
  | Unix.S_DIR ->mkdir dst; Array.iter(fun n->copy(Filename.concat src n)(Filename.concat dst n))(Sys.readdir src)
  | Unix.S_REG ->T.write_new dst(T.read src)
  | _ ->failwith "trial-copy-nonregular"
let () =
  ignore(Unix.umask 0o077);
  let base=Sys.argv.(1) in let worker=base^"/experiment/worker" and restore=base^"/experiment/restore" in
  let label=if Array.length Sys.argv=3 then Sys.argv.(2) else "run-1" in
  let result=base^"/results/"^label in mkdir result;
  let stage n=let p=result^"/"^n in mkdir p;p in
  let self=stage "core" in T.require(good(run ~dir:self restore ["self-check";self])) "core-self-check";
  let seed=stage "seed" in let repository=seed^"/repo" and archive=seed^"/archive.sexp" in
  T.require(good(run ~dir:seed worker ["mutate";repository;"initial";"none";archive])) "seed-failed";
  let initial_head,initial=T.of_archive(T.read archive) in
  let calls=ref 0 in
  let inspect directory root = incr calls; let d=directory^"/inspect-"^string_of_int !calls in mkdir d;
    let output=d^"/archive.sexp" in let s=run ~dir:d worker ["inspect";root;output] in s,output in
  let summary=ref [] in
  let note n s state =summary:=(n^"\t"^status s^"\t"^state)::!summary;Printf.printf "%s\t%s\t%s\n%!" n (status s) state in
  let classify dir root expected =let s,p=inspect dir root in
    if not(good s) then
      let log=T.read(Filename.dirname p^"/stderr.txt") in
      if String.split_on_char '\n' log |> List.exists(fun line->String.ends_with ~suffix:"Failure(\"dangling-selected-branch\")" line)
      then "corrupt-selected-branch-refused" else "unreadable-refused"
    else if not(Sys.file_exists p) then "uncertain-no-head"
    else let h,x=T.of_archive(T.read p) in
      if h=initial_head && x=initial then "old-valid"
      else if x=expected then "new-valid"
      else failwith("unexpected-mixed-generation:"^dir) in
  let current=ref initial and head=ref initial_head in
  List.iter(fun op->let d=stage("operation-"^op) in let output=d^"/archive.sexp" in
    let s=run ~dir:d worker ["mutate";repository;op;!head;output] in T.require(good s)("operation-failed:"^op);
    let h,x=T.of_archive(T.read output) in
    let b=T.change(T.get(T.B.of_string(!current).book))op in
    let expected={!current with book=T.B.to_string b;parent= !head;operation=op} in T.require(x=expected) "operation-diff";
    let state,p=inspect d repository in T.require(good state) "restart-failed";
    let h2,x2=T.of_archive(T.read p) in T.require(h=h2 && x=x2) "restart-diff";
    let portable=d^"/portable" in mkdir portable;T.write_new(portable^"/only.archive.sexp")(T.read output);
    T.require(good(run ~dir:portable restore ["restore";portable^"/only.archive.sexp";portable^"/restored"])) "standalone-restore";
    T.require(T.read(portable^"/restored/book.sexp")=x.book && T.read(portable^"/restored/basis.sexp")=x.basis) "restored-domain-bytes";
    let restored=portable^"/restored" in
    List.iter(fun(n,v)->match v with None->T.require(not(Sys.file_exists(restored^"/"^n))) "absent-file-drift"
      |Some s->T.require(T.read(restored^"/"^n)=s) "restored-config-or-unknown-bytes")x.extras;
    let rh,rx=T.of_archive(T.read(restored^"/complete.archive.sexp")) in T.require(rh=h && rx=x) "restored-publication-metadata";
    current:=x;head:=h;note op s "new-valid-restart-and-independent-restore")
    ["record";"correct";"pay";"replace-plan";"cancel-plan";"support"];
  (* Each fault starts from the CLOSED initial repository, not the advancing one. *)
  let seed2=stage "fault-seed" in let initial_repo=seed2^"/repo" and ia=seed2^"/archive.sexp" in
  T.require(good(run ~dir:seed2 worker ["mutate";initial_repo;"initial";"none";ia])) "fault-seed";
  let h0,x0=T.of_archive(T.read ia) in T.require(h0=initial_head && x0=initial) "deterministic-fixture";
  let expected={initial with book=T.B.to_string(T.change(T.get(T.B.of_string initial.book))"pay");parent=initial_head;operation="pay"} in
  let case ?(op="pay") n env=let d=stage n in let root=d^"/repo" in copy initial_repo root;
    let expected=if List.mem op ["unbalanced";"duplicate"] then initial else
      {initial with book=T.B.to_string(T.change(T.get(T.B.of_string initial.book))op);parent=initial_head;operation=op} in
    let s=run ~dir:d ~env worker ["mutate";root;op;initial_head;d^"/attempt.archive"] in
    let state=classify d root expected in note n s state;d,s,state in
  List.iter(fun point->List.iter(fun mode->let _,s,state=case (mode^"-"^point) ["TRIAL_CHECKPOINT="^point;"TRIAL_STOP="^mode] in
    T.require(not(good s)) "fault-not-triggered";
    let after=List.mem point ["head-returned";"readback";"before-close";"closed"] in
    T.require(state=(if after then "new-valid" else "old-valid")) "checkpoint-selection") ["returned";"kill"])
    ["tree-ready";"before-commit";"commit-returned";"flush-returned";"before-head";"head-returned";"readback";"before-close";"closed"];
  let cas=stage "stale-CAS" in let root=cas^"/repo" in copy initial_repo root;
  T.require(good(run ~dir:cas worker ["stale";root;cas^"/archive.sexp"])) "stock-CAS";
  note "stale-CAS" (Unix.WEXITED 0) "first-selected-second-rejected";
  let conflict=stage "stale-draft" in let root=conflict^"/repo" in copy initial_repo root;
  let s=run ~dir:conflict worker ["mutate";root;"pay";"stale";conflict^"/attempt.archive"] in
  T.require(good s && classify conflict root expected="old-valid" && not(Sys.file_exists(conflict^"/attempt.archive"))) "stale-draft-changed-data";
  note "stale-draft" s "conflict-old-valid";
  let ownership=stage "ownership" in let root=ownership^"/repo" in copy initial_repo root;
  let fd=Unix.openfile(root^".writer")[Unix.O_CREAT;Unix.O_RDWR]0o600 in Unix.lockf fd Unix.F_TLOCK 0;
  let s=run ~dir:ownership worker ["mutate";root;"pay";initial_head;ownership^"/attempt.archive"] in Unix.close fd;
  T.require(not(good s) && classify ownership root expected="old-valid") "writer-overlap-not-refused";
  note "ownership" s "second-RW-refused-old-valid";
  let dylib=base^"/experiment/io_fault.dylib" in
  let traced=stage "io-trace" in let root=traced^"/repo" in copy initial_repo root;
  let env=["DYLD_INSERT_LIBRARIES="^dylib;"TRIAL_FAULT_ROOT="^root;"TRIAL_FAULT_ACTION=trace"] in
  let s=run ~dir:traced ~env worker ["mutate";root;"pay";initial_head;traced^"/archive.sexp"] in
  T.require(good s) "traced-success";
  let trace=T.read(traced^"/stderr.txt") in
  T.require(String.split_on_char '\n' trace |> List.exists(fun s->String.starts_with ~prefix:"io-hook" s)) "io-hook-not-loaded";
  note "io-trace" s "trace-captured";
  List.iter(fun file->List.iter(fun action->let n="io-"^file^"-"^action in
    let d=stage n in let root=d^"/repo" in copy initial_repo root;
    let env=["DYLD_INSERT_LIBRARIES="^dylib;"TRIAL_FAULT_ROOT="^root;"TRIAL_FAULT_FILE="^file;"TRIAL_FAULT_OP=write";"TRIAL_FAULT_ACTION="^action] in
    let s=run ~dir:d ~env worker ["mutate";root;"pay";initial_head;d^"/attempt.archive"] in
    T.require(not(good s)) "syscall-fault-not-triggered";
    let state=classify d root expected in note n s state)
    ["eio";"short-eio";"partial-kill"]) ["suffix";"dict";"control";"branches"];
  List.iter(fun file->let n="fsync-"^file in let d=stage n in let root=d^"/repo" in copy initial_repo root;
    let env=["DYLD_INSERT_LIBRARIES="^dylib;"TRIAL_FAULT_ROOT="^root;"TRIAL_FAULT_FILE="^file;"TRIAL_FAULT_OP=fsync";"TRIAL_FAULT_ACTION=eio"] in
    let s=run ~dir:d ~env worker ["mutate";root;"pay";initial_head;d^"/attempt.archive"] in
    T.require(not(good s)) "fsync-fault-not-triggered";note n s (classify d root expected)) ["suffix";"dict";"control"];
  List.iter(fun point->List.iter(fun mode->let _,s,state=case ~op:"support" ("support-"^mode^"-"^point)
      ["TRIAL_CHECKPOINT="^point;"TRIAL_STOP="^mode] in
    T.require(not(good s)) "support-fault-not-triggered";
    let after=List.mem point ["head-returned";"readback";"before-close";"closed"] in
    T.require(state=(if after then "new-valid" else "old-valid")) "partial-support-selection") ["returned";"kill"])
    ["tree-ready";"before-commit";"commit-returned";"flush-returned";"before-head";"head-returned";"readback";"before-close";"closed"];
  List.iter(fun op->let _,s,state=case ~op ("refusal-"^op) [] in
    T.require(not(good s) && state="old-valid") "core-refusal-mutated-selection") ["unbalanced";"duplicate"];
  List.iter(fun damaged->let d=stage("no-reseed-"^damaged) in let root=d^"/repo" in
    copy (result^"/io-branches-"^damaged^"/repo")root;
    let s=run ~dir:d worker ["mutate";root;"initial";"none";d^"/attempt.archive"] in
    T.require(not(good s) && not(Sys.file_exists(d^"/attempt.archive"))) "dangling-branch-reinitialized";
    note ("no-reseed-"^damaged) s (classify d root expected)) ["short-eio";"partial-kill"];
  T.write_new(result^"/summary.tsv")(String.concat "\n"(List.rev !summary)^"\n");
  print_endline "PASS: synthetic normal/CAS/ownership/checkpoint/syscall trials; no power-loss qualification."
