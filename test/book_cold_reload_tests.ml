(* Cold-equivalence oracle for Book mutations.

   The store keeps the in-memory book after a save instead of reading book.txt back,
   so any book reached in memory must be indistinguishable from the cold reload of its
   book.txt, and every mutation must give the same result on both: the same refusal
   reason, or the same observable book. A change that leaves the entries, the balance
   totals or the printed TXs stale shows up as a difference here. *)
open Base
module B = Bakhlo_household.Book
module D = Bakhlo_domain
module R = Stdlib.Random.State

let get = function Ok x -> x | Error why -> failwith why

(* Test books are written in book.txt, the household format. *)
let book_of_txt text = get (B.read text)
let text_of = B.print

let fixture =
  "BOOK\t1\n\
   MEASURE\tjpy\t0\n\
   MEASURE\tusd\t2\n\
   LOCUS\twallet\t財布\t現金\n\
   LOCUS\tbank\t銀行\t預金\n\
   LOCUS\tfood\tfood\t\n\
   LOCUS\texpense\texpense\t\n\
   TX\tinit\t2026-10-01\tDESC\tinitial\n\
   EFFECT\tbank\tjpy\t50000\n\
   EFFECT\twallet\tjpy\t-50000\n\
   ENDTX\n\
   PLAN\trent\t2026-10-25\tjpy\n\
   CHANGE\tbank\t-10000\n\
   CHANGE\texpense\t10000\n\
   ENDPLAN\n\
   PLAN\tsub\t2026-10-20\tusd\n\
   CHANGE\twallet\t-15\n\
   CHANGE\texpense\t15\n\
   ENDPLAN\n\
   ZERO-ORIGIN\tfood\tjpy\n\
   ZERO-ORIGIN\texpense\tjpy\n\
   ZERO-ORIGIN\texpense\tusd\n\
   OPENING\tbank\tjpy\tinit\n\
   ANCHOR\t-\n\
   ASSERT\twallet\tjpy\t100000\n\
   ASSERT\twallet\tusd\t500\n\
   ENDANCHOR\n\
   END\n"

(* The fixture with wallet and bank kept but no longer offered for new entries. *)
let hidden_fixture =
  String.substr_replace_first
    (String.substr_replace_first fixture ~pattern:"LOCUS\twallet\t財布\t現金\n"
       ~with_:"LOCUS\twallet\t財布\t現金\tHIDDEN\n")
    ~pattern:"LOCUS\tbank\t銀行\t預金\n" ~with_:"LOCUS\tbank\t銀行\t預金\tHIDDEN\n"

let loci = [| "wallet"; "bank"; "food"; "expense"; "ghost" |]
let measures = [| "jpy"; "usd"; "xxx" |]
let entry_ids = [| "init"; "e0"; "e1"; "e2"; "e3"; "e4"; "e5"; "e6" |]
let plan_ids = [| "rent"; "sub"; "p0"; "p1" |]
let pick st a = a.(R.int st (Array.length a))
let roles : Bakhlo_book_txt.Book_txt.role array = [| Asset; Liability; Equity; Income; Expense |]
let attention_ids = [| "attention-1"; "attention-2"; "bad id"; "" |]
let chance st n = R.int st 100 < n
let ident of_string s = Result.ok_or_failwith (Result.map_error (of_string s) ~f:(fun _ -> s))
let locus s = ident D.Identifier.Locus.of_string s
let measure s = ident D.Identifier.Measure.of_string s
let coordinate l m : D.Effect_coordinate.t = { locus = locus l; measure = measure m }

let posting ?key l m n =
  D.Effect.create
    ~key:(Option.map key ~f:(ident D.Identifier.Effect_key.of_string))
    ~locus:(locus l) ~measure:(measure m)
    ~quantity:(D.Quantity.of_quanta (Z.of_int n))

let day st = if chance st 3 then "2026-02-30" else Printf.sprintf "2026-10-%02d" (1 + R.int st 28)

(* Attention as the Attention screen writes it, and the odd item it must not. *)
let attention_item st : Bakhlo_book_txt.Book_txt.item =
  {
    id = pick st attention_ids;
    due = (match R.int st 3 with 0 -> Due_on (day st) | 1 -> No_due_date | _ -> Due_undetermined);
    context = pick st [| "Call the bank"; "two\nlines"; "tab\there"; "日本語"; "" |];
  }

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
    memo = (if chance st 10 then Some "" else if chance st 50 then Some "memo" else None);
    effects = effects st;
    reversal_of = None;
    exchange = None;
    original_amount =
      (if chance st 10 then
         Some (pick st [| "jpy"; "usd"; "xxx" |], Z.of_int (pick st [| -5; 0; 120 |]))
       else None);
    merchant = None;
  }

(* The oracle drives exactly the changes the Shell publishes. *)

let describe = function
  | B.Put_entry { replace; entry; plan } ->
      Printf.sprintf "put replace=%b id=%s day=%s rev=%s plan=%s effects=%d" replace entry.id
        entry.day
        (Option.value entry.reversal_of ~default:"-")
        (Option.value plan ~default:"-") (List.length entry.effects)
  | B.Correct_entry_date { id; day } -> Printf.sprintf "correct_date %s %s" id day
  | B.Observe rows ->
      "observe "
      ^ String.concat ~sep:","
          (List.map rows ~f:(fun (l, m, q) -> Printf.sprintf "%s/%s=%s" l m (Z.to_string q)))
  | B.Put_plan { replace; plan } -> Printf.sprintf "put_plan replace=%b id=%s" replace plan.id
  | B.Cancel_plan { id; day } -> Printf.sprintf "cancel_plan %s %s" id day
  | B.Add_locus l -> "add_locus " ^ l
  | B.Classify_merchant { id; _ } -> "classify " ^ id
  | B.Set_locus_label { id; label; _ } -> Printf.sprintf "label %s %S" id label
  | B.Set_roles roles -> Printf.sprintf "roles %d" (List.length roles)
  | B.Set_attention { items; closes } ->
      Printf.sprintf "attention %d items %d closes" (List.length items) (List.length closes)

let generate st book =
  let existing () =
    match B.entries book with
    | [] -> None
    | es -> Some (List.nth_exn es (R.int st (List.length es)))
  in
  match R.int st 100 with
  | n when n < 30 ->
      let plan = if chance st 15 then Some (pick st plan_ids) else None in
      B.Put_entry { replace = false; entry = fresh_entry st (pick st entry_ids); plan }
  | n when n < 35 ->
      (* Exchange: keyed source and destination in two Measures; sometimes malformed. *)
      let a = 1 + R.int st 5000 and b = 1 + R.int st 50 in
      let dest = if chance st 15 then "jpy" else "usd" in
      let entry =
        {
          (fresh_entry st (pick st entry_ids)) with
          effects =
            [
              posting ~key:"s" "wallet" "jpy" (-a);
              posting ~key:"d"
                (pick st [| "wallet"; "bank" |])
                dest
                (if chance st 10 then -b else b);
            ];
          exchange = Some ("s", if chance st 10 then "x" else "d");
          original_amount = None;
        }
      in
      B.Put_entry { replace = false; entry; plan = None }
  | n when n < 40 -> (
      match existing () with
      | None -> B.Correct_entry_date { id = "nobody"; day = day st }
      | Some old -> B.Correct_entry_date { id = old.id; day = day st })
  | n when n < 55 -> (
      match existing () with
      | None -> B.Add_locus "ghost"
      | Some old ->
          let entry =
            if chance st 15 then
              (* Change the Reversal link: drop it, or point it at another entry
                 with that entry's exact inverse. *)
              match (old.reversal_of, existing ()) with
              | Some _, _ | None, None -> { old with reversal_of = None }
              | None, Some target ->
                  { old with reversal_of = Some target.id; effects = inverse target }
            else if chance st 50 then { old with memo = Some "edited" }
            else if chance st 50 then { old with day = day st }
            else { (fresh_entry st old.id) with reversal_of = old.reversal_of }
          in
          B.Put_entry
            {
              replace = true;
              entry;
              plan = (if chance st 5 then Some (pick st plan_ids) else None);
            })
  | n when n < 68 -> (
      match existing () with
      | None -> B.Add_locus "ghost"
      | Some target ->
          let entry =
            {
              (fresh_entry st (pick st entry_ids)) with
              effects = (if chance st 85 then inverse target else effects st);
              reversal_of = Some target.id;
              original_amount = None;
            }
          in
          B.Put_entry { replace = false; entry; plan = None })
  | n when n < 80 ->
      let row () = (pick st loci, pick st measures, Z.of_int (R.int st 200_000 - 50_000)) in
      B.Observe (if chance st 30 then [ row (); row () ] else [ row () ])
  | n when n < 84 ->
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
      B.Put_plan { replace = chance st 50; plan }
  | n when n < 86 ->
      let roles = List.init (R.int st 4) ~f:(fun _ -> (pick st loci, pick st roles)) in
      B.Set_roles (if chance st 50 then List.dedup_and_sort roles ~compare:Poly.compare else roles)
  | n when n < 88 ->
      let items = List.init (R.int st 3) ~f:(fun _ -> attention_item st) in
      let closes =
        List.init (R.int st 2) ~f:(fun _ : Bakhlo_book_txt.Book_txt.close ->
            {
              item = pick st attention_ids;
              day = day st;
              kind = (if chance st 50 then Resolved else Dropped);
            })
      in
      B.Set_attention { items; closes }
  | n when n < 94 -> B.Cancel_plan { id = pick st plan_ids; day = day st }
  | n when n < 95 -> B.Add_locus "ghost"
  | n when n < 97 ->
      let label = pick st [| "Wallet"; ""; "  "; "Bad\nline" |] in
      B.Set_locus_label
        {
          id = pick st loci;
          label;
          help = (if chance st 50 then None else Some (pick st [| "Cash"; "" |]));
        }
  | _ ->
      let id = match existing () with Some e when chance st 80 -> e.id | _ -> "nobody" in
      let disposition =
        if chance st 50 then B.Nonmerchant
        else B.Merchant (ident D.Identifier.External_party.of_string "shop")
      in
      B.Classify_merchant { id; disposition }

let apply book change = B.apply book [ change ]

(* The book's facts: the exact book.txt it saves, sections included. *)
let facts_text book = Bakhlo_book_txt.Book_txt.print (B.txt book)

(* Everything a caller can read from a book, rendered for exact comparison. *)
let observable book =
  let answers =
    List.concat_map (Array.to_list loci) ~f:(fun l ->
        List.map [ "jpy"; "usd" ] ~f:(fun m ->
            let answer =
              match B.quantity book ~locus:l ~measure:m with
              | Some q ->
                  let support =
                    match q.support with
                    | Zero_origin -> "zero-origin"
                    | Opening _ -> "opening"
                    | Counted _ -> "observation"
                  in
                  Printf.sprintf "%s (%s)" (Z.to_string q.amount) support
              | None -> "unknown"
            in
            Printf.sprintf "%s/%s: %s" l m answer))
  in
  let pace =
    match
      B.daily_pace book ~measure:"jpy"
        ~pool:[ coordinate "wallet" "jpy" ]
        ~observed_at:"2026-10-15" ~end_exclusive:"2026-11-01"
    with
    | Ok p ->
        Printf.sprintf "pace %s deductions %s" (Z.to_string p.daily_pace_quanta)
          (String.concat ~sep:","
             (List.map p.plan_deductions ~f:(fun (id, q) -> id ^ "=" ^ Z.to_string q)))
    | Error why -> "pace refused " ^ why
  in
  String.concat ~sep:"\n"
    ((facts_text book :: answers)
    @ [ pace; Printf.sprintf "entries %d" (B.entry_count book) ]
    @ List.map (B.open_plans book) ~f:(fun p -> "open " ^ p.id))

(* What a cold load of its book.txt gives. *)
let cold book =
  match Bakhlo_book_txt.Book_txt.read (facts_text book) with
  | Ok txt -> get (B.of_txt txt)
  | Error e -> failwith (Bakhlo_book_txt.Book_txt.code_name e.code)

(* First differing line with a little context, so a failure stays readable. *)
let first_difference a b =
  let a = Array.of_list (String.split_lines a) and b = Array.of_list (String.split_lines b) in
  let n = Int.max (Array.length a) (Array.length b) in
  let line xs i = if i >= 0 && i < Array.length xs then xs.(i) else "<none>" in
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
  | B.Put_entry { replace = true; _ } -> "replace"
  | B.Put_entry { entry = { reversal_of = Some _; _ }; _ } -> "reversal"
  | B.Put_entry { entry = { exchange = Some _; _ }; replace = false; _ } -> "exchange"
  | B.Put_entry { plan = Some _; _ } -> "plan payment"
  | B.Put_entry _ -> "record"
  | B.Correct_entry_date _ -> "correct_date"
  | B.Observe _ -> "observe"
  | B.Put_plan _ -> "put_plan"
  | B.Cancel_plan _ -> "cancel_plan"
  | B.Add_locus _ -> "add_locus"
  | B.Set_locus_label _ -> "label"
  | B.Classify_merchant _ -> "classify"
  | B.Set_roles _ -> "roles"
  | B.Set_attention _ -> "attention"

let agree ~seed ~step ~trace label a b =
  match (a, b) with
  | Ok a, Ok b ->
      check ~seed ~step ~trace (label ^ ": result differs") (observable a) (observable b)
  | Error a, Error b -> check ~seed ~step ~trace (label ^ ": refusal differs") a b
  | Ok _, Error b -> check ~seed ~step ~trace (label ^ ": only one admitted") "admitted" b
  | Error a, Ok _ -> check ~seed ~step ~trace (label ^ ": only one admitted") a "admitted"

let run ~start ~seed ~steps ~admitted =
  let st = R.make [| seed |] in
  let book = ref start in
  let trace = ref [] in
  for step = 1 to steps do
    let op = generate st !book in
    trace := describe op :: !trace;
    let result = apply !book op in
    agree ~seed ~step ~trace:!trace "cold twin" result (apply (cold !book) op);
    match result with
    | Ok next ->
        Hashtbl.incr admitted (kind op);
        check ~seed ~step ~trace:!trace "not cold-equivalent" (observable next)
          (observable (cold next));
        book := next
    | Error _ -> ()
  done

let%expect_test "every mutation agrees with its book.txt cold-loaded twin" =
  let admitted = Hashtbl.create (module String) in
  let start = book_of_txt fixture in
  for seed = 1 to 200 do
    run ~start ~seed ~steps:30 ~admitted
  done;
  (* Guard against a generator that only exercises refusals. *)
  List.iter
    [
      "record";
      "plan payment";
      "replace";
      "reversal";
      "exchange";
      "correct_date";
      "observe";
      "put_plan";
      "cancel_plan";
      "add_locus";
      "classify";
      "label";
      "roles";
      "attention";
    ] ~f:(fun k ->
      Stdio.printf "%s admitted at least 20 times: %b\n" k
        (Hashtbl.find admitted k |> Option.value ~default:0 >= 20));
  [%expect
    {|
    record admitted at least 20 times: true
    plan payment admitted at least 20 times: true
    replace admitted at least 20 times: true
    reversal admitted at least 20 times: true
    exchange admitted at least 20 times: true
    correct_date admitted at least 20 times: true
    observe admitted at least 20 times: true
    put_plan admitted at least 20 times: true
    cancel_plan admitted at least 20 times: true
    add_locus admitted at least 20 times: true
    classify admitted at least 20 times: true
    label admitted at least 20 times: true
    roles admitted at least 20 times: true
    attention admitted at least 20 times: true
    |}]

let result_text = function Ok _ -> "ok" | Error why -> why

let%expect_test "date and Merchant-only changes accept retained unapproved Loci" =
  let base = book_of_txt hidden_fixture in
  let initial = Option.value_exn (B.find_entry base "init") in
  let dated = B.correct_entry_date base ~id:"init" ~day:"2026-10-02" in
  let dated_book = get dated in
  let after_date = Option.value_exn (B.find_entry dated_book "init") in
  Stdio.printf "date succeeds and changes only date: %b\n"
    (String.equal after_date.day "2026-10-02"
    && Poly.equal { after_date with day = initial.day } initial);
  let classified = B.classify_merchant base ~id:"init" ~disposition:B.Nonmerchant in
  let classified_book = get classified in
  let after_merchant = Option.value_exn (B.find_entry classified_book "init") in
  Stdio.printf "Merchant succeeds and changes only Merchant: %b\n"
    (Poly.equal after_merchant.merchant (Some B.Nonmerchant)
    && Poly.equal { after_merchant with merchant = initial.merchant } initial);
  let correction =
    B.put_entry base ~replace:true { initial with memo = Some "edited" } ~plan:None
  in
  let fresh = { initial with id = "fresh"; day = "2026-10-03" } in
  let reversal =
    { fresh with id = "refund"; effects = inverse initial; reversal_of = Some initial.id }
  in
  Stdio.printf "generic correction: %s\n" (result_text correction);
  Stdio.printf "new entry: %s\n" (result_text (B.put_entry base ~replace:false fresh ~plan:None));
  Stdio.printf "new reversal: %s\n"
    (result_text (B.put_entry base ~replace:false reversal ~plan:None));
  Stdio.printf "invalid date: %s\n"
    (result_text (B.correct_entry_date base ~id:"init" ~day:"2026-02-30"));
  Stdio.printf "invalid id: %s\n" (result_text (B.correct_entry_date base ~id:"" ~day:"2026-10-02"));
  Stdio.printf "unknown date target: %s\n"
    (result_text (B.correct_entry_date base ~id:"nobody" ~day:"2026-10-02"));
  Stdio.printf "unknown Merchant target: %s\n"
    (result_text (B.classify_merchant base ~id:"nobody" ~disposition:B.Nonmerchant));
  Stdio.printf "duplicate Merchant: %s\n"
    (result_text (B.classify_merchant classified_book ~id:"init" ~disposition:B.Nonmerchant));
  let bad_party = ident D.Identifier.External_party.of_string "bad\tparty" in
  Stdio.printf "invalid Merchant token: %s\n"
    (result_text (B.classify_merchant base ~id:"init" ~disposition:(B.Merchant bad_party)));
  [%expect
    {|
    date succeeds and changes only date: true
    Merchant succeeds and changes only Merchant: true
    generic correction: locus-unapproved
    new entry: locus-unapproved
    new reversal: locus-unapproved
    invalid date: invalid-date
    invalid id: invalid-entry-id
    unknown date target: unknown-entry
    unknown Merchant target: loam: Merchant classification requires an existing Event
    duplicate Merchant: loam: Event Merchant is already classified; replacement is not qualified
    invalid Merchant token: loam: Merchant party token must be a non-empty single text field
    |}]
