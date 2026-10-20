(* Cold-equivalence oracle for Daily_book mutations.

   Any book reached in memory must be indistinguishable from the book cold-loaded
   from its own serialization (a whole admission), and every mutation must give the
   same result on both: same refusal reason, or the same observable book. This is
   the safety net for incremental paths: a shortcut that leaves derived state stale
   shows up as a difference here even when its own result looks plausible. *)
open Base
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query
module M = Bakhlo_application.Event_merchants
module X = Bakhlo_presentation.Current_quantity_explanation
module R = Stdlib.Random.State

let get = function Ok x -> x | Error why -> failwith why

let fixture =
  "(bakhlo-daily 1) (scope corrected-entries explicit-plans)\n\
   (measures (measure jpy 0) (measure usd 2))\n\
   (labels (provided (label wallet 財布 現金) (label bank 銀行 預金)))\n\
   (approved-loci (provided wallet food bank expense))\n\
   (entries\n\
     (entry init (date 2026-10-01) (memo (some initial))\n\
       (postings (posting bank jpy 50000 (none)) (posting wallet jpy -50000 (none)))\n\
       (reversal-of (none))))\n\
   (plans\n\
     (plan rent (date 2026-10-25) (measure jpy) (changes (bank -10000) (expense 10000))\n\
       (paid-by (none)))\n\
     (plan sub (date 2026-10-20) (measure usd) (changes (wallet -15) (expense 15))\n\
       (paid-by (none))))\n\
   (support (zero-origin (food jpy) (expense jpy) (expense usd))\n\
     (openings (bank jpy init))\n\
     (observations (observation (reflected) (quantities (wallet jpy 100000) (wallet usd 500))))\n\
     (presence (not-supplied)))\n"

let loci = [| "wallet"; "bank"; "food"; "expense"; "ghost" |]
let measures = [| "jpy"; "usd"; "xxx" |]
let entry_ids = [| "init"; "e0"; "e1"; "e2"; "e3"; "e4"; "e5"; "e6" |]
let plan_ids = [| "rent"; "sub"; "p0"; "p1" |]
let pick st a = a.(R.int st (Array.length a))
let chance st n = R.int st 100 < n

let ident of_string s = Result.ok_or_failwith (Result.map_error (of_string s) ~f:(fun _ -> s))
let locus s = ident D.Identifier.Locus.of_string s
let measure s = ident D.Identifier.Measure.of_string s
let coordinate l m : D.Effect_coordinate.t = { locus = locus l; measure = measure m }

let posting ?key l m n =
  D.Effect.create
    ~key:(Option.map key ~f:(ident D.Identifier.Effect_key.of_string)) ~locus:(locus l) ~measure:(measure m)
    ~quantity:(D.Quantity.of_quanta (Z.of_int n))

let day st =
  if chance st 3 then "2026-02-30" else Printf.sprintf "2026-10-%02d" (1 + R.int st 28)

let amount st = if chance st 3 then 0 else 1 + R.int st 5000

(* Mostly balanced single-Measure postings; occasionally zero or unbalanced. *)
let effects st =
  let m = if chance st 5 then "xxx" else pick st [| "jpy"; "usd" |] in
  let a = amount st in
  let other = pick st loci in
  let base = [ posting "wallet" m (-a); posting other m a ] in
  if chance st 4 then [ posting ~key:"k" "wallet" m (-a); posting ~key:"k" other m a ]
  else if chance st 5 then [ posting "wallet" m (-a); posting other m (a + 1) ]
  else if chance st 20 then [ posting "wallet" m (-a); posting other m (a - 1); posting "food" m 1 ]
  else base

let inverse (e : B.entry) =
  List.map e.effects ~f:(fun p ->
      D.Effect.create ~key:(D.Effect.key p) ~locus:(D.Effect.locus p) ~measure:(D.Effect.measure p)
        ~quantity:(D.Quantity.neg (D.Effect.quantity p)))

let fresh_entry st id : B.entry =
  {
    id;
    day = day st;
    memo = (if chance st 50 then Some "memo" else None);
    effects = effects st;
    reversal_of = None;
    exchange = None;
    original_amount =
      (if chance st 10 then Some (pick st [| "jpy"; "usd"; "xxx" |], Z.of_int (pick st [| -5; 0; 120 |]))
       else None);
    merchant = None;
  }

type op =
  | Put of { replace : bool; entry : B.entry; plan : string option }
  | Observe of (string * string * Z.t) list
  | Put_plan of { replace : bool; plan : B.plan }
  | Cancel_plan of { id : string; day : string }
  | Add_locus of string
  | Classify of { id : string; disposition : M.disposition }

let describe = function
  | Put { replace; entry; plan } ->
      Printf.sprintf "put replace=%b id=%s day=%s rev=%s plan=%s effects=%d" replace entry.id
        entry.day
        (Option.value entry.reversal_of ~default:"-")
        (Option.value plan ~default:"-") (List.length entry.effects)
  | Observe rows ->
      "observe "
      ^ String.concat ~sep:","
          (List.map rows ~f:(fun (l, m, q) -> Printf.sprintf "%s/%s=%s" l m (Z.to_string q)))
  | Put_plan { replace; plan } -> Printf.sprintf "put_plan replace=%b id=%s" replace plan.id
  | Cancel_plan { id; day } -> Printf.sprintf "cancel_plan %s %s" id day
  | Add_locus l -> "add_locus " ^ l
  | Classify { id; _ } -> "classify " ^ id

let generate st book =
  let existing () =
    match B.entries book with
    | [] -> None
    | es -> Some (List.nth_exn es (R.int st (List.length es)))
  in
  match R.int st 100 with
  | n when n < 35 ->
      let plan = if chance st 15 then Some (pick st plan_ids) else None in
      Put { replace = false; entry = fresh_entry st (pick st entry_ids); plan }
  | n when n < 55 -> (
      match existing () with
      | None -> Add_locus "ghost"
      | Some old ->
          let entry =
            if chance st 50 then { old with memo = Some "edited" }
            else if chance st 50 then { old with day = day st }
            else { (fresh_entry st old.id) with reversal_of = old.reversal_of }
          in
          Put { replace = true; entry; plan = (if chance st 5 then Some (pick st plan_ids) else None) })
  | n when n < 68 -> (
      match existing () with
      | None -> Add_locus "ghost"
      | Some target ->
          let entry =
            {
              (fresh_entry st (pick st entry_ids)) with
              effects = (if chance st 85 then inverse target else effects st);
              reversal_of = Some target.id;
              original_amount = None;
            }
          in
          Put { replace = false; entry; plan = None })
  | n when n < 80 ->
      let row () = (pick st loci, pick st measures, Z.of_int (R.int st 200_000 - 50_000)) in
      Observe (if chance st 30 then [ row (); row () ] else [ row () ])
  | n when n < 88 ->
      let a = Z.of_int (1 + R.int st 9000) in
      let plan : B.plan =
        {
          id = pick st plan_ids;
          day = day st;
          measure = pick st [| "jpy"; "usd" |];
          changes = [ ("bank", Z.neg a); ("expense", a) ];
          paid_by = None;
          cancelled_on = None;
        }
      in
      Put_plan { replace = chance st 50; plan }
  | n when n < 94 -> Cancel_plan { id = pick st plan_ids; day = day st }
  | n when n < 97 -> Add_locus "ghost"
  | _ ->
      let id = match existing () with Some e when chance st 80 -> e.id | _ -> "nobody" in
      let disposition =
        if chance st 50 then M.Nonmerchant
        else M.Merchant (ident D.Identifier.External_party.of_string "shop")
      in
      Classify { id; disposition }

let apply book = function
  | Put { replace; entry; plan } -> B.put_entry book ~replace entry ~plan
  | Observe rows -> B.observe_quantities book rows
  | Put_plan { replace; plan } -> B.put_plan book ~replace plan
  | Cancel_plan { id; day } -> B.cancel_plan book ~id ~day
  | Add_locus l -> B.add_locus book l
  | Classify { id; disposition } -> B.classify_merchant book ~id ~disposition

(* The whole-book reference for the same operation; observation is already whole. *)
let apply_full book = function
  | Put { replace; entry; plan } -> B.Full.put_entry book ~replace entry ~plan
  | Observe rows -> B.observe_quantities book rows
  | Put_plan { replace; plan } -> B.Full.put_plan book ~replace plan
  | Cancel_plan { id; day } -> B.Full.cancel_plan book ~id ~day
  | Add_locus l -> B.Full.add_locus book l
  | Classify { id; disposition } -> B.Full.classify_merchant book ~id ~disposition

(* Everything a caller can read from a book, rendered for exact comparison. *)
let observable book =
  let answers =
    List.concat_map (Array.to_list loci) ~f:(fun l ->
        List.map [ "jpy"; "usd" ] ~f:(fun m ->
            let answer =
              match Q.query (B.image book) (coordinate l m) with
              | Ok (Q.Exact x) ->
                  let premise =
                    match Q.premise x with
                    | Q.Zero_origin -> "zero-origin"
                    | Q.Opening _ -> "opening"
                    | Q.Current_assertion _ -> "observation"
                  in
                  Printf.sprintf "%s (%s)" (Z.to_string (D.Quantity.quanta (Q.quantity x))) premise
              | Ok (Q.Known_present _) -> "present"
              | Error (Q.Support_unknown _) -> "unknown"
            in
            Printf.sprintf "%s/%s: %s" l m answer))
  in
  let pace =
    match
      B.daily_pace book ~measure:"jpy" ~pool:[ coordinate "wallet" "jpy" ]
        ~observed_at:"2026-10-15" ~end_exclusive:"2026-11-01"
    with
    | Ok p ->
        Printf.sprintf "pace %s deductions %s" (Z.to_string p.daily_pace_quanta)
          (String.concat ~sep:"," (List.map p.plan_deductions ~f:(fun (id, q) -> id ^ "=" ^ Z.to_string q)))
    | Error why -> "pace refused " ^ why
  in
  String.concat ~sep:"\n"
    ((B.to_string book :: answers)
    @ [ pace; Printf.sprintf "entries %d" (B.entry_count book) ]
    @ List.map (B.open_plans book) ~f:(fun p -> "open " ^ p.id))

let cold book = get (B.of_string (B.to_string book))

(* First differing line with a little context, so a failure stays readable. *)
let first_difference a b =
  let a = Array.of_list (String.split_lines a) and b = Array.of_list (String.split_lines b) in
  let n = Int.max (Array.length a) (Array.length b) in
  let line xs i = if i < Array.length xs then xs.(i) else "<end>" in
  let rec find i = if i >= n || not (String.equal (line a i) (line b i)) then i else find (i + 1) in
  let i = find 0 in
  let around xs = List.init 4 ~f:(fun k -> line xs (i - 1 + k)) |> String.concat ~sep:"\n" in
  Printf.sprintf "line %d\n--- in-memory ---\n%s\n--- cold ---\n%s" (i + 1) (around a) (around b)

let check ~seed ~step ~trace label a b =
  if not (String.equal a b) then
    failwith
      (Printf.sprintf "seed %d step %d: %s\ntrace:\n%s\n%s" seed step label
         (String.concat ~sep:"\n" (List.rev trace))
         (first_difference a b))

(* Kind of each operation, to show the generator admits every family. *)
let kind = function
  | Put { replace = true; _ } -> "replace"
  | Put { entry = { reversal_of = Some _; _ }; _ } -> "reversal"
  | Put { plan = Some _; _ } -> "plan payment"
  | Put _ -> "record"
  | Observe _ -> "observe"
  | Put_plan _ -> "put_plan"
  | Cancel_plan _ -> "cancel_plan"
  | Add_locus _ -> "add_locus"
  | Classify _ -> "classify"

let agree ~seed ~step ~trace label a b =
  match (a, b) with
  | Ok a, Ok b -> check ~seed ~step ~trace (label ^ ": result differs") (observable a) (observable b)
  | Error a, Error b -> check ~seed ~step ~trace (label ^ ": refusal differs") a b
  | Ok _, Error b -> check ~seed ~step ~trace (label ^ ": only one admitted") "admitted" b
  | Error a, Ok _ -> check ~seed ~step ~trace (label ^ ": only one admitted") a "admitted"

let run ~fixture ~seed ~steps ~admitted =
  let st = R.make [| seed |] in
  let book = ref (get (B.of_string fixture)) in
  let trace = ref [] in
  for step = 1 to steps do
    let op = generate st !book in
    trace := describe op :: !trace;
    let result = apply !book op in
    agree ~seed ~step ~trace:!trace "cold twin" result (apply (cold !book) op);
    agree ~seed ~step ~trace:!trace "whole-book reference" result (apply_full !book op);
    match result with
    | Ok next ->
        Hashtbl.incr admitted (kind op);
        check ~seed ~step ~trace:!trace "not cold-equivalent" (observable next)
          (observable (cold next));
        book := next
    | Error _ -> ()
  done

let%expect_test "every mutation agrees with its cold-loaded twin and its whole-book reference" =
  let admitted = Hashtbl.create (module String) in
  (* The second fixture supplies presence evidence, which corrections cannot
     update in place: it pins the whole-book fallback. *)
  let with_presence =
    String.substr_replace_first fixture ~pattern:"(presence (not-supplied))"
      ~with_:"(presence (provided (reflected) (coordinates (bank usd))))"
  in
  List.iter [ fixture; with_presence ] ~f:(fun fixture ->
      for seed = 1 to 200 do
        run ~fixture ~seed ~steps:30 ~admitted
      done);
  (* Guard against a generator that only exercises refusals. *)
  List.iter
    [ "record"; "plan payment"; "replace"; "reversal"; "observe"; "put_plan"; "cancel_plan";
      "add_locus"; "classify" ]
    ~f:(fun k ->
      Stdio.printf "%s admitted at least 20 times: %b\n" k
        (Hashtbl.find admitted k |> Option.value ~default:0 >= 20));
  [%expect {|
    record admitted at least 20 times: true
    plan payment admitted at least 20 times: true
    replace admitted at least 20 times: true
    reversal admitted at least 20 times: true
    observe admitted at least 20 times: true
    put_plan admitted at least 20 times: true
    cancel_plan admitted at least 20 times: true
    add_locus admitted at least 20 times: true
    classify admitted at least 20 times: true
    |}]

(* KNOWN GAP, pinned on purpose: the in-place record and correction paths update
   balances but not the image's admitted source, so the evidence explanation omits the
   new entry until the next whole admission. Answers agree (oracle above). The
   incremental redesign must make both lines say true. *)
let%expect_test "known gap: incremental record leaves the evidence explanation stale" =
  let base = get (B.of_string fixture) in
  let entry : B.entry =
    { id = "late"; day = "2026-10-05"; memo = None;
      effects = [ posting "wallet" "jpy" (-100); posting "food" "jpy" 100 ];
      reversal_of = None; exchange = None; original_amount = None; merchant = None }
  in
  let book = get (B.put_entry base ~replace:false entry ~plan:None) in
  let explain b = snd (X.explain (B.image b) (coordinate "wallet" "jpy")) in
  let mentions b = String.is_substring (explain b) ~substring:"\"late\"" in
  Stdio.printf "answers agree: %b\n"
    (String.equal (observable book) (observable (cold book)));
  Stdio.printf "explanation mentions new entry: in-memory %b, cold %b\n" (mentions book)
    (mentions (cold book));
  [%expect {|
    answers agree: true
    explanation mentions new entry: in-memory false, cold true
    |}]
