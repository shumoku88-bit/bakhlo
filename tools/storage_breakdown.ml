(* Same workload for original control and observed source copies. Synthetic only. *)
module S = Storage_study
module B = S.B
module F = Daily_file
module A = Daily_actions
module D = Bakhlo_domain
module P = Storage_profile
let get = S.get
let require = S.require
let selected dir = Filename.concat dir "state.sexp"
let publish session candidate = S.published (A.publish_candidate ~session candidate)
let worker dir n =
  Printf.printf "columns: stage case name calls inclusive_ms self_ms allocated_words self_allocated_words promoted_words major_words\n";
  Printf.printf "columns: operation case ms allocated_words rss_kib read_bytes write_bytes\n%!";
  let current = ref (P.operation "load" (fun () -> F.load (selected dir))) in
  S.check (!current).book n;
  let wallet = S.exact (!current).book "wallet" "jpy" in
  let eur = S.exact (!current).book "wallet" "eur" in
  let apply label tx = current := P.operation label (fun () -> S.published
    (A.commit_transaction ~session:!current ~base_bytes:(!current).bytes tx)) in
  for i = 1 to 3 do apply (Printf.sprintf "record-%d" i)
    {entry=S.new_entry (Printf.sprintf "new-%d" i); replace=false; plan=None} done;
  let old = Option.get (B.find_entry (!current).book "tx-000010") in
  let effects = List.map (fun p ->
    let locus = D.Identifier.Locus.to_string (D.Effect.locus p) in
    let q = D.Quantity.quanta (D.Effect.quantity p) in
    S.posting "eur" locus (if locus="wallet" then Z.pred q else if locus="food" then Z.succ q else q)) old.effects in
  let edit = {old with effects; memo=Some "synthetic amount correction"} in
  apply "correct-amount" {entry=edit; replace=true; plan=None};
  let effects = List.map (fun p -> if D.Identifier.Locus.to_string (D.Effect.locus p)="food"
    then S.posting "eur" "food" (Z.pred (D.Quantity.quanta (D.Effect.quantity p))) else p) edit.effects
    @ [S.posting "eur" "fees" Z.one] in
  let split = {edit with effects} in
  apply "correct-posting-count" {entry=split; replace=true; plan=None};
  apply "correct-date" {entry={split with day="1999-12-31"}; replace=true; plan=None};
  apply "pay-plan" {entry=S.new_entry "payment"; replace=false; plan=Some "plan-040"};
  let plan id = List.find (fun (p : B.plan) -> p.id=id) (B.plans (!current).book) in
  let changed = { (plan "plan-041") with day="2030-02-01";
    changes=["wallet",Z.of_int (-2000); "food",Z.of_int 2000] } in
  current := P.operation "replace-plan" (fun () ->
    let candidate = P.measure "candidate.put-plan" (fun () -> get (B.put_plan (!current).book ~replace:true changed)) in
    publish !current candidate);
  current := P.operation "cancel-plan" (fun () ->
    let candidate = P.measure "candidate.cancel-plan" (fun () -> get (B.cancel_plan (!current).book ~id:"plan-042" ~day:"2030-01-01")) in
    publish !current candidate);
  let cold = P.operation "reload" (fun () -> F.load (selected dir)) in
  let wire = B.to_string cold.book in
  require (wire = B.to_string (!current).book) "cold-facts";
  require (B.entry_count cold.book=n+4) "cold-count";
  require (Z.equal (S.exact cold.book "wallet" "jpy") (Z.sub wallet (Z.of_int 4000))) "exact-jpy";
  require (Z.equal (S.exact cold.book "wallet" "eur") (Z.pred eur)) "exact-eur";
  require (Result.is_error (S.Q.query (B.image cold.book) (S.coordinate "bank" "jpy"))) "unknown-became-zero";
  let old = Option.get (B.find_entry cold.book old.id) in
  require (old.day="1999-12-31" && List.length old.effects=4) "correction-fields";
  let find id = List.find (fun (p : B.plan) -> p.id=id) (B.plans cold.book) in
  require ((find "plan-040").paid_by=Some "payment") "payment-link";
  require ((find "plan-041").day=changed.day && (find "plan-041").changes=changed.changes) "plan-replacement";
  require ((find "plan-042").cancelled_on=Some "2030-01-01") "plan-cancellation";
  let original = get (Bakhlo_sexp.Daily_book.of_string wire) in
  require (Bakhlo_sexp.Daily_book.to_string original=wire) "original-owner-parity";
  let restored = Filename.concat dir "restored.sexp" in
  P.operation "restore" (fun () -> F.restore_copy ~source:(selected dir) ~target:restored);
  require (F.read restored = cold.bytes) "restore-bytes";
  let backups = Sys.readdir dir |> Array.to_list |> List.filter
    (fun name -> String.starts_with ~prefix:"state.sexp.before-" name) in
  require (List.length backups=9) "backup-count";
  let backup_bytes = List.fold_left (fun acc name -> acc + (Unix.stat (Filename.concat dir name)).st_size) 0 backups in
  Printf.printf "retention\t%d\t%d\t%d\nPASS: cold facts, original owner parity, exact quanta/unknown, correction/payment/terminal links and fresh restore.\n%!"
    (String.length cold.bytes) (List.length backups) backup_bytes
let qualify dir =
  let initial = F.read (Filename.concat dir "initial.sexp") in
  let base = get (B.of_string initial) in
  let candidate = get (B.put_entry base ~replace:false (S.new_entry "qualified-new") ~plan:None) in
  let steps = [F.Attempt_synced; F.Pending_written; F.Backup_written; F.Outputs_synced;
    F.Selected_replaced; F.Selected_synced; F.Attempt_removed] in
  List.iteri (fun i target ->
    let sub = Filename.concat dir (Printf.sprintf "checkpoint-%d" i) in
    Unix.mkdir sub 0o700;
    let path = selected sub in F.write_new path initial;
    let session = F.load path in
    let result = F.publish ~checkpoint:(fun step -> if step=target then raise (Sys_error "synthetic checkpoint fault")) session candidate in
    require (result=F.Uncertain) "checkpoint-uncertainty-changed";
    let cold = F.load path in
    require (B.entry_count cold.book=B.entry_count base + if i >= 4 then 1 else 0) "checkpoint-selection-changed";
    match F.publish session candidate with
    | F.Refused_input "recovery-required" when i < 6 -> ()
    | F.Conflict when i=6 -> ()
    | _ -> failwith "checkpoint-retry-guard-changed") steps;
  let sub = Filename.concat dir "conflict" in Unix.mkdir sub 0o700;
  let path = selected sub in F.write_new path initial;
  let session = F.load path in
  require (F.publish {session with bytes=session.bytes ^ " "} candidate=F.Conflict) "conflict-guard";
  require (F.read path=initial && F.unfinished_names path=[]) "conflict-mutated";
  require (Result.is_error (B.of_string (initial ^ "("))) "malformed-accepted";
  Printf.printf "PASS: seven returned checkpoint faults preserve uncertainty/selection/retry guards; conflict and malformed refusal. Not new SIGKILL/power-loss/P7 qualification.\n%!"
let () =
  ignore (Unix.umask 0o077);
  match Array.to_list Sys.argv with
  | [_; "generate"; dir; n] -> S.generate dir (int_of_string n)
  | [_; "worker"; dir; n] -> worker dir (int_of_string n)
  | [_; "qualify"; dir] -> qualify dir
  | _ -> failwith "Usage: breakdown generate DIR N | worker DIR N | qualify DIR"
