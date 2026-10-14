(* Opt-in synthetic observer. No GC tuning, I/O decisions or semantic predicates.
   Inclusive rows nest: sum self_ms, not inclusive_ms. Observer overhead is charged
   to enclosing self time; compare with the separately compiled original control. *)
type totals = {
  mutable calls : int; mutable inclusive : float; mutable self : float;
  mutable allocated : float; mutable self_allocated : float;
  mutable promoted : float; mutable major : float;
}
type span = { mutable children : float; mutable child_allocated : float }
let stack : span list ref = ref []
let totals : (string, totals) Hashtbl.t = Hashtbl.create 32
let traffic : (string, int) Hashtbl.t = Hashtbl.create 8
let allocated (minor, promoted, major) = minor +. major -. promoted
let measure name f =
  let frame = {children=0.; child_allocated=0.} in
  stack := frame :: !stack;
  let counters = Gc.counters () in
  let start = Unix.gettimeofday () in
  let finish () =
    let elapsed = Unix.gettimeofday () -. start in
    let after = Gc.counters () in
    let allocation = allocated after -. allocated counters in
    let _, p0, m0 = counters and _, p1, m1 = after in
    stack := List.tl !stack;
    (match !stack with
     | parent :: _ -> parent.children <- parent.children +. elapsed;
         parent.child_allocated <- parent.child_allocated +. allocation
     | [] -> ());
    let row = match Hashtbl.find_opt totals name with
      | Some row -> row
      | None -> let row = {calls=0; inclusive=0.; self=0.; allocated=0.; self_allocated=0.; promoted=0.; major=0.} in
          Hashtbl.add totals name row; row in
    row.calls <- row.calls + 1;
    row.inclusive <- row.inclusive +. elapsed;
    row.self <- row.self +. elapsed -. frame.children;
    row.allocated <- row.allocated +. allocation;
    row.self_allocated <- row.self_allocated +. allocation -. frame.child_allocated;
    row.promoted <- row.promoted +. p1 -. p0;
    row.major <- row.major +. m1 -. m0
  in
  match f () with
  | result -> finish (); result
  | exception exn -> finish (); raise exn
let bytes direction n = Hashtbl.replace traffic direction
  (n + Option.value ~default:0 (Hashtbl.find_opt traffic direction))
let role path =
  let base = Filename.basename path in
  if Base.String.is_substring base ~substring:".attempt-" then "attempt"
  else if Base.String.is_substring base ~substring:".pending-" then "pending"
  else if Base.String.is_substring base ~substring:".before-" then "before"
  else if String.starts_with ~prefix:"restored" base then "restore"
  else "selected"
let rss_kib () =
  let ic = Unix.open_process_in (Printf.sprintf "ps -o rss= -p %d" (Unix.getpid ())) in
  let text = input_line ic in
  if Unix.close_process_in ic <> Unix.WEXITED 0 then failwith "rss-observation-failed";
  int_of_string (String.trim text)
let operation name f =
  if !stack <> [] then failwith "nested-operation";
  Hashtbl.clear totals; Hashtbl.clear traffic;
  let result = measure "operation" f in
  let root = Hashtbl.find totals "operation" in
  let sum_self = Hashtbl.fold (fun _ row sum -> sum +. row.self) totals 0. in
  if abs_float (sum_self -. root.inclusive) > 0.000001 then failwith "profile-time-does-not-close";
  let sum_alloc = Hashtbl.fold (fun _ row sum -> sum +. row.self_allocated) totals 0. in
  if abs_float (sum_alloc -. root.allocated) > 1. then failwith "profile-allocation-does-not-close";
  Hashtbl.to_seq totals |> List.of_seq |> List.sort (fun (a, _) (b, _) -> String.compare a b)
  |> List.iter (fun (stage, row) ->
    if row.self < -.0.000001 || row.self_allocated < -.1. then failwith "negative-exclusive-observation";
    Printf.printf "stage\t%s\t%s\t%d\t%.3f\t%.3f\t%.0f\t%.0f\t%.0f\t%.0f\n"
      name stage row.calls (1000. *. row.inclusive) (1000. *. row.self)
      row.allocated row.self_allocated row.promoted row.major);
  let observed direction = match Hashtbl.find_opt traffic direction with
    | Some n -> string_of_int n | None -> "NA" in
  Printf.printf "operation\t%s\t%.3f\t%.0f\t%d\t%s\t%s\n%!" name
    (1000. *. root.inclusive) root.allocated (rss_kib ())
    (observed "read") (observed "write");
  result
