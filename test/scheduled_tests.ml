module B = Bakhlo_household.Book
open Samples

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

let pace_answer book (q : Samples.question) =
  let header = q.header in
  let measure =
    match header with
    | [ ("PACE" | "PAST"); m; _; _ ] | [ "ACTIVITY"; m ] -> m
    | _ -> bad "pace question"
  in
  let pool = List.map (fun locus -> { B.locus; measure }) (values "POOL" q.body) in
  let result =
    match header with
    | [ "PACE"; _; observed_at; end_exclusive ] -> (
        match B.daily_pace book ~measure ~pool ~observed_at ~end_exclusive with
        | Error why -> [ "REFUSED\t" ^ why ]
        | Ok r ->
            guide
              ~balances:
                (List.map
                   (fun ((c : B.coordinate), n) -> row [ "BALANCE"; c.locus; money n ])
                   r.pool_balances)
              ~deductions:r.plan_deductions ~available:r.available_through_end
              ~days:r.remaining_days ~daily:r.daily_pace_quanta)
    | [ "PAST"; _; day; end_exclusive ] -> (
        match B.past_paces book ~measure ~pool ~days:[ (day, end_exclusive) ] with
        | [ Error why ] -> [ "REFUSED\t" ^ why ]
        | [ Ok r ] ->
            guide
              ~balances:[ "RESTATED\t" ^ money r.restated_pool ]
              ~deductions:r.protected ~available:r.available ~days:r.remaining_days ~daily:r.pace
        | _ -> bad "one PAST answer per question")
    | [ "ACTIVITY"; _ ] ->
        List.concat_map
          (fun (day, a) -> ("ON\t" ^ day) :: activity_lines a)
          (B.day_activities book ~measure ~pool)
    | _ -> bad "pace question"
  in
  (row header :: List.map (fun (c : B.coordinate) -> "POOL\t" ^ c.locus) pool) @ result

let pace_kinds = [ "PACE"; "PAST"; "ACTIVITY" ]

let change_answer counts dir use (q : Samples.question) =
  let name = match q.header with [ "APPLY"; name ] -> name | _ -> bad "APPLY question" in
  let before =
    match context use "BOOK" with Some name -> name | None -> bad "USE BOOK required"
  in
  let book = match B.read (read dir before) with Ok b -> b | Error why -> bad ("before " ^ why) in
  let input, expected =
    split_at (function ("AFTER" | "REFUSED") :: _ -> true | _ -> false) q.body
  in
  if expected = [] then bad "APPLY needs AFTER or REFUSED";
  let result =
    match B.apply book (changes input) with
    | Error why ->
        count counts "refused";
        [ "REFUSED\t" ^ why ]
    | Ok after ->
        count counts "applied";
        let name = name ^ ".after.txt" in
        equal counts ~path:(Filename.concat dir name) ~want:(read dir name) ~got:(B.print after);
        let pace = match expected with _answer :: rest -> rest | [] -> assert false in
        let text = String.concat "\n" pace in
        let printed =
          render counts ~path:(dir ^ "/changes.answers")
            ~line:(q.line + List.length input + 2)
            ~use:[] ~blocks:pace_kinds
            ~answer:(fun _ q -> pace_answer after q)
            text
        in
        ("AFTER\t" ^ name) :: (if printed = "" then [] else String.split_on_char '\n' printed)
  in
  (row q.header :: input) @ result

let run dir =
  let counts = create () in
  check counts ~dir ~file:"changes.answers" ~blocks:[ "APPLY" ] ~answer:(change_answer counts dir);
  let paces = List.fold_left (fun n kind -> n + counted counts kind) 0 pace_kinds in
  Printf.printf "%d applied, %d refused, %d pace answers, %d failures\n" (counted counts "applied")
    (counted counts "refused") paces counts.failures

let%expect_test "every Scheduled sample gives its listed answer" =
  run "scheduled";
  [%expect {| 14 applied, 14 refused, 27 pace answers, 0 failures |}]

let%expect_test "every Actual change gives its listed answer" =
  run "records";
  [%expect {| 13 applied, 41 refused, 0 pace answers, 0 failures |}]

(* 5. Plans in series (series.answers): grouping, a batch amount change and the
   replenishment dates, by Bakhlo_household.Schedule. *)
module Sch = Bakhlo_household.Schedule

let series_answer use (q : question) =
  let book =
    match context use "BOOK" with
    | Some name -> ( match B.read (read "scheduled" name) with Ok b -> b | Error why -> bad why)
    | None -> bad "USE BOOK required"
  in
  let plan id =
    match List.find_opt (fun (p : B.plan) -> p.id = id) (B.plans book) with
    | Some p -> p
    | None -> bad ("plan " ^ id)
  in
  let ids plans = List.map (fun (p : B.plan) -> p.id) plans in
  match q.header with
  | [ "SERIES" ] -> row q.header :: List.map (fun s -> row ("GROUP" :: ids s)) (Sch.series book)
  | "SERIES-OF" :: id :: _ -> (
      match Sch.series_of book (plan id) with
      | Ok s -> [ row ("SERIES-OF" :: id :: ids s) ]
      | Error why -> [ row [ "SERIES-OF"; id; "REFUSED"; why ] ])
  | [ "AMOUNT"; amount ] ->
      let input, _ = split_at (fun fs -> fs = [ "ENDINPUT" ]) q.body in
      let plans = List.map plan (values "PLAN" input) in
      (row q.header :: input)
      @ "ENDINPUT"
        ::
        (match Sch.change_amount plans ~amount:(Z.of_string amount) with
        | Error why -> [ "REFUSED\t" ^ why ]
        | Ok changed ->
            List.map
              (fun (p : B.plan) ->
                row
                  ("PLAN" :: p.id
                  :: List.concat_map (fun (locus, q) -> [ locus; Z.to_string q ]) p.changes))
              changed)
  | "SLOT" :: anchor :: every :: k :: _ -> (
      let question = [ "SLOT"; anchor; every; k ] in
      match Sch.slot ~anchor ~every_months:(int_of_string every) (int_of_string k) with
      | Some (Sch.Dated day) -> [ row (question @ [ day ]) ]
      | Some (Sch.Missing { year; month; day }) ->
          [
            row (question @ [ "MISSING"; Printf.sprintf "%04d-%02d" year month; string_of_int day ]);
          ]
      | None -> [ row (question @ [ "NONE" ]) ])
  | _ -> bad ("series question " ^ row q.header)

let%expect_test "plans in series give their listed answers" =
  let counts = create () in
  check counts ~dir:"scheduled" ~file:"series.answers" ~blocks:[ "SERIES"; "AMOUNT" ]
    ~answer:series_answer;
  Printf.printf "%d series answers, %d failures\n" counts.answers counts.failures;
  [%expect {| 17 series answers, 0 failures |}]
