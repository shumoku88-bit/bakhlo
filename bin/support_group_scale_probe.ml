(* Bounded research-only native probe. Synthetic data only.
   All measured updates operate on the same admitted immutable baseline.
   No LOAM originals, no persistence, no product optimization. *)
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module A = Bakhlo_application
module Q = A.Current_quantity_query

let get = function Ok value -> value | Error why -> failwith why

let id s parse = match parse s with Ok x -> x | Error _ -> failwith ("bad ID " ^ s)
let coordinate l m : D.Effect_coordinate.t =
  { locus = id l D.Identifier.Locus.of_string;
    measure = id m D.Identifier.Measure.of_string }
let posting locus amount =
  D.Effect.create ~locus:(id locus D.Identifier.Locus.of_string)
    ~measure:(id "jpy" D.Identifier.Measure.of_string)
    ~quantity:(D.Quantity.of_quanta (Z.of_int amount)) ~key:None
let entry key : B.entry =
  { id = key; day = "2026-10-08"; memo = None;
    effects = [posting "wallet" (-1); posting "food" 1];
    reversal_of = None; exchange = None }

let fixture ~history ~groups =
  if history <= 0 || groups <= 0 || groups > 400 then failwith "bounded sizes only";
  let buf = Buffer.create (history * 175 + groups * 130) in
  let add = Buffer.add_string buf in
  add "(bakhlo-daily 3)\n(scope corrected-entries explicit-plans)\n";
  add "(measures (measure jpy 0))\n(labels (not-supplied))\n";
  add "(approved-loci (provided wallet food";
  for i = 1 to groups - 1 do
    add (Printf.sprintf " probe-%04d" i)
  done;
  add "))\n(entries\n";
  for i = 1 to history do
    add (Printf.sprintf
      " (entry tx-%06d (date 2026-10-08) (memo (none)) (postings (posting wallet jpy -1 (none)) (posting food jpy 1 (none))) (reversal-of (none)) (exchange (none)))\n"
      i)
  done;
  add ")\n(plans)\n(support (zero-origin (food jpy)) (openings) (observations\n";
  add " (observation (reflected) (quantities (wallet jpy 100000)))\n";
  for i = 1 to groups - 1 do
    add (Printf.sprintf
      " (observation (reflected) (quantities (probe-%04d jpy 0)))\n" i)
  done;
  add ") (presence (not-supplied)))\n";
  Buffer.contents buf

let quantity book locus =
  match Q.query (B.image book) (coordinate locus "jpy") with
  | Ok (Q.Exact value) -> D.Quantity.quanta (Q.quantity value)
  | Ok (Q.Known_present _) -> failwith ("unexpected presence " ^ locus)
  | Error _ -> failwith ("unexpected unsupported " ^ locus)

let check ~history ~groups ~added book =
  if B.entry_count book <> history + added then failwith "entry count";
  if not (Z.equal (quantity book "wallet") (Z.of_int (100000 - history - added))) then
    failwith "wallet quantity";
  if not (Z.equal (quantity book "food") (Z.of_int (history + added))) then
    failwith "food quantity";
  if groups > 1 && not (Z.equal (quantity book "probe-0001") Z.zero) then
    failwith "unrelated asserted group changed";
  if not (List.length (A.Current_quantity_groups.groups
    (Q.source_groups (B.image book))) = groups) then
    failwith "group evidence dropped"

let median = function
  | [a; b; c; d; e] ->
      let sorted = List.sort Float.compare [a; b; c; d; e] in
      List.nth sorted 2
  | _ -> failwith "five trials required"

let sample_ms ~reps f =
  let samples = ref [] in
  for _ = 1 to 5 do
    let counter = ref 0 in
    let start = Unix.gettimeofday () in
    for _ = 1 to reps do
      let updated = get (f ()) in
      counter := !counter + B.entry_count updated
    done;
    let elapsed = Unix.gettimeofday () -. start in
    if !counter <= 0 then failwith "result not consumed";
    samples := ((elapsed *. 1000.) /. float_of_int reps) :: !samples
  done;
  median !samples

let one_case history groups =
  let input = fixture ~history ~groups in
  let parsed = get (B.of_string input) in
  check ~history ~groups ~added:0 parsed;
  let fresh = entry "fresh-test" in
  let one = get (B.put_entry parsed ~replace:false fresh ~plan:None) in
  let full = get (B.put_entry_full parsed ~replace:false fresh ~plan:None) in
  check ~history ~groups ~added:1 one;
  check ~history ~groups ~added:1 full;
  if not (String.equal (B.to_string one) (B.to_string full)) then
    failwith "incremental and full serialized results differ";
  let current_groups = A.Current_quantity_groups.groups
    (Q.source_groups (B.image parsed)) in
  if List.length current_groups <> groups then failwith "evidence count changed";
  let reps = if groups >= 400 then 100
    else if groups >= 100 then 250
    else if groups >= 10 then 1200 else 5000 in
  let append_ms = sample_ms ~reps (fun () ->
    B.put_entry parsed ~replace:false fresh ~plan:None) in
  let cold_ms = sample_ms ~reps:3 (fun () -> B.of_string input) in
  Printf.printf "history=%d groups=%d append_ms=%.6f cold_admit_ms=%.5f bytes=%d CHECK=PASS\n%!"
    history groups append_ms cold_ms (String.length input)

let () =
  let sizes = [(1000,1);(1000,10);(1000,100);(1000,400);
               (10000,1);(10000,10);(10000,100)] in
  List.iter (fun (n,g) -> one_case n g) sizes
