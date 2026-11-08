(* Language-neutral changes for Scheduled and Actual. The hand-written books
   and answers, not this runner, are the contract a rewrite must pass. *)
module B = Bakhlo_household.Book

let read dir name = In_channel.with_open_bin (Filename.concat dir name) In_channel.input_all
let exists dir name = Sys.file_exists (Filename.concat dir name)
let lines text = List.filter (fun l -> l <> "") (String.split_on_char '\n' text)
let fields = String.split_on_char '\t'

exception Bad_sample of string

let bad why = raise (Bad_sample why)
let amount s = try Z.of_string s with Invalid_argument _ -> bad ("amount " ^ s)
let option = function "-" -> None | s -> Some s
let mode = function "NEW" -> false | "REPLACE" -> true | other -> bad ("mode " ^ other)

(* 1. A TX block, with exchange legs named by Effect keys (records/README.md).
   Memos with escapes stay in the common-format conformance fixtures. *)
let entry_block = function
  | header :: rest ->
      let id, day, memo =
        match fields header with
        | [ "TX"; id; day ] -> (id, day, None)
        | [ "TX"; id; day; "DESC"; memo ] when not (String.contains memo '\\') ->
            (id, day, Some memo)
        | _ -> bad ("TX line " ^ header)
      in
      let rec body (e : B.entry) = function
        | "ENDTX" :: rest -> ({ e with effects = List.rev e.effects }, rest)
        | line :: rest ->
            let e =
              match fields line with
              | [ "EFFECT"; locus; measure; q ] ->
                  {
                    e with
                    effects = { locus; measure; amount = amount q; key = None } :: e.effects;
                  }
              | [ "EFFECT"; locus; measure; q; key ] ->
                  {
                    e with
                    effects = { locus; measure; amount = amount q; key = Some key } :: e.effects;
                  }
              | [ "REVERSAL-OF"; id ] -> { e with reversal_of = Some id }
              | [ "ORIGINAL"; measure; q ] -> { e with original_amount = Some (measure, amount q) }
              | [ "MERCHANT"; party ] -> { e with merchant = Some (B.Merchant party) }
              | [ "NONMERCHANT" ] -> { e with merchant = Some B.Nonmerchant }
              | [ "EXCHANGE"; source; destination ] ->
                  { e with exchange = Some (source, destination) }
              | _ -> bad ("TX body " ^ line)
            in
            body e rest
        | [] -> bad "TX without ENDTX"
      in
      body
        {
          id;
          day;
          memo;
          effects = [];
          reversal_of = None;
          exchange = None;
          original_amount = None;
          merchant = None;
        }
        rest
  | [] -> bad "missing TX block"

(* 2. A PLAN block. An ending is accepted here so a sample can show that a plan
   is never put already paid or cancelled. *)
let plan_block = function
  | header :: rest ->
      let id, day, measure =
        match fields header with
        | [ "PLAN"; id; day; measure ] -> (id, day, measure)
        | _ -> bad ("PLAN line " ^ header)
      in
      let rec body (p : B.plan) = function
        | "ENDPLAN" :: rest -> ({ p with changes = List.rev p.changes }, rest)
        | line :: rest ->
            let p =
              match fields line with
              | [ "CHANGE"; locus; q ] -> { p with changes = (locus, amount q) :: p.changes }
              | [ "PAID-BY"; tx ] -> { p with paid_by = Some tx }
              | [ "CANCELLED"; day ] -> { p with cancelled_on = Some day }
              | _ -> bad ("PLAN body " ^ line)
            in
            body p rest
        | [] -> bad "PLAN without ENDPLAN"
      in
      body { id; day; measure; changes = []; paid_by = None; cancelled_on = None } rest
  | [] -> bad "missing PLAN block"

(* 3. The changes, in order; Book.apply takes all of them or none. *)
let rec changes = function
  | [] -> []
  | line :: rest -> (
      match fields line with
      | [ "PUT-ENTRY"; m; plan ] ->
          let entry, rest = entry_block rest in
          B.Put_entry { replace = mode m; entry; plan = option plan } :: changes rest
      | [ "PUT-PLAN"; m ] ->
          let plan, rest = plan_block rest in
          B.Put_plan { replace = mode m; plan } :: changes rest
      | [ "CANCEL-PLAN"; id; day ] -> B.Cancel_plan { id; day } :: changes rest
      | [ "CORRECT-ENTRY-DATE"; id; day ] -> B.Correct_entry_date { id; day } :: changes rest
      | [ "CLASSIFY-MERCHANT"; id; "MERCHANT"; name ] ->
          B.Classify_merchant { id; disposition = B.Merchant (Amounts_tests.text name) }
          :: changes rest
      | [ "CLASSIFY-MERCHANT"; id; "NONMERCHANT" ] ->
          B.Classify_merchant { id; disposition = B.Nonmerchant } :: changes rest
      | _ -> bad ("change " ^ line))

(* 4. The Daily Pace questions over the book after the changes. A block names its
   question and pool Loci and is followed by the answer; the runner prints the whole
   block again and compares the text.

   PACE asks today's guide (Measure, observed day, exclusive end). PAST asks the
   guide at the end of a past day, restated from current truth. ACTIVITY asks what
   moved the pool on each day. *)
let money n = Z.to_string n

let guide ~balances ~deductions ~available ~days ~daily =
  balances
  @ List.map (fun (id, n) -> Printf.sprintf "DEDUCTION\t%s\t%s" id (money n)) deductions
  @ [ "AVAILABLE\t" ^ money available; "DAYS\t" ^ string_of_int days; "DAILY\t" ^ money daily ]

let activity_lines (a : B.day_activity) =
  List.filter_map
    (fun (label, n) -> if Z.equal n Z.zero then None else Some (label ^ "\t" ^ money n))
    [
      ("DISCRETIONARY-OUT", a.discretionary_outflow);
      ("DISCRETIONARY-IN", a.discretionary_inflow);
      ("SCHEDULED-OUT", a.scheduled_settled_outflow);
      ("SCHEDULED-IN", a.scheduled_settled_inflow);
      ("PROTECTION-RELEASED", a.scheduled_reserved_outflow);
    ]

let pace_blocks book text =
  let rec split acc = function
    | [] -> if acc = [] then [] else bad "question without its END line"
    | line :: rest when String.starts_with ~prefix:"END" line ->
        List.rev (line :: acc) :: split [] rest
    | line :: rest -> split (line :: acc) rest
  in
  List.map
    (fun block ->
      match block with
      | header :: body ->
          let measure, kind =
            match fields header with
            | [ ("PACE" | "PAST"); m; _; _ ] | [ "ACTIVITY"; m ] -> (m, List.hd (fields header))
            | _ -> bad ("question line " ^ header)
          in
          let pool =
            List.filter_map
              (fun l ->
                match fields l with [ "POOL"; locus ] -> Some { B.locus; measure } | _ -> None)
              body
          in
          let answer =
            match fields header with
            | [ "PACE"; _; observed_at; end_exclusive ] -> (
                match B.daily_pace book ~measure ~pool ~observed_at ~end_exclusive with
                | Error why -> [ "REFUSED\t" ^ why ]
                | Ok r ->
                    guide
                      ~balances:
                        (List.map
                           (fun ((c : B.coordinate), n) ->
                             Printf.sprintf "BALANCE\t%s\t%s" c.locus (money n))
                           r.pool_balances)
                      ~deductions:r.plan_deductions ~available:r.available_through_end
                      ~days:r.remaining_days ~daily:r.daily_pace_quanta)
            | [ "PAST"; _; day; end_exclusive ] -> (
                match B.past_paces book ~measure ~pool ~days:[ (day, end_exclusive) ] with
                | [ Error why ] -> [ "REFUSED\t" ^ why ]
                | [ Ok r ] ->
                    guide
                      ~balances:[ "RESTATED\t" ^ money r.restated_pool ]
                      ~deductions:r.protected ~available:r.available ~days:r.remaining_days
                      ~daily:r.pace
                | _ -> bad "one PAST answer per question")
            | _ ->
                List.concat_map
                  (fun (day, a) -> ("ON\t" ^ day) :: activity_lines a)
                  (B.day_activities book ~measure ~pool)
          in
          let printed =
            (header :: List.map (fun (c : B.coordinate) -> "POOL\t" ^ c.locus) pool)
            @ answer
            @ [ "END" ^ kind ]
          in
          (block, printed)
      | [] -> bad "empty question block")
    (split [] (lines text))

let refusal_code = function
  | "loam: Event Merchant is already classified; replacement is not qualified" ->
      "merchant-classified"
  | "loam: Merchant classification requires an existing Event" -> "merchant-unknown"
  | "loam: Merchant party token must be a non-empty single text field" -> "merchant-token"
  | code -> code

let run dir =
  let failures = ref 0 and accepted = ref 0 and refused = ref 0 and paces = ref 0 in
  let fail name why =
    incr failures;
    Printf.printf "FAIL %s/%s: %s\n" dir name why
  in
  List.iter
    (fun row ->
      match fields row with
      | [ name; before; expect; _note ] -> (
          try
            let book =
              match B.read (read dir before) with Ok b -> b | Error why -> bad ("before " ^ why)
            in
            let after_file = name ^ ".after.txt" and pace_file = name ^ ".pace" in
            match (B.apply book (changes (lines (read dir (name ^ ".changes")))), expect) with
            | Ok after, "ok" ->
                incr accepted;
                if B.print after <> read dir after_file then fail name "book.txt after differs";
                if exists dir pace_file then
                  List.iter
                    (fun (want, got) ->
                      incr paces;
                      if want <> got then
                        fail name ("pace answer differs:\n" ^ String.concat "\n" got))
                    (pace_blocks after (read dir pace_file))
            | Ok _, code -> fail name ("admitted, expected " ^ code)
            | Error why, "ok" -> fail name ("refused " ^ why)
            | Error why, code ->
                incr refused;
                if refusal_code why <> code then
                  fail name (Printf.sprintf "want %s, got %s" code why);
                if exists dir after_file || exists dir pace_file then
                  fail name "a refused sample has no book after it"
          with Bad_sample why -> fail name ("bad sample: " ^ why))
      | _ -> fail row "bad cases row")
    (List.tl (lines (read dir "cases.tsv")));
  Printf.printf "%d applied, %d refused, %d pace answers, %d failures\n" !accepted !refused !paces
    !failures

let%expect_test "every Scheduled sample gives its listed answer" =
  run "scheduled";
  [%expect {| 14 applied, 14 refused, 27 pace answers, 0 failures |}]

let%expect_test "every Actual change gives its listed answer" =
  run "records";
  [%expect {| 13 applied, 41 refused, 0 pace answers, 0 failures |}]
