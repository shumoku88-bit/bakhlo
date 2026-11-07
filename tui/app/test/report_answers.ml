(* Reports and the Actual's day totals as language-neutral answers.

   Each sample in test/reports is a book (and, for cycles, a boundary-presets.tsv)
   with question blocks. A block names a report and its inputs and is followed by
   the answer; this runner prints the whole block again from Bakhlo's own report
   code and compares the text. The files are the specification a rewrite must
   pass (test/reports/README.md). *)
module B = Bakhlo_household.Book
module IncExp = Income_expense_report

let dir = Sys.argv.(1)
let read name = In_channel.with_open_bin (Filename.concat dir name) In_channel.input_all
let lines text = List.filter (fun l -> l <> "") (String.split_on_char '\n' text)
let fields = String.split_on_char '\t'
let money = Z.to_string

exception Bad_sample of string

let bad why = raise (Bad_sample why)

(* 1. The Actual's EXPENSE total of the entries in [start, end): per Measure, the
   nonzero sums, and PARTIAL when an effect has no role. *)
let expense_total book ~start ~stop =
  let entries =
    List.filter (fun (e : B.entry) -> start <= e.day && e.day < stop) (B.entries book)
  in
  let sums, partial =
    Actual_workspace.expense_sums (Actual_workspace.expense_roles ~book (B.roles book)) entries
  in
  List.filter_map
    (fun (measure, n) ->
      if Z.equal n Z.zero then None else Some ("TOTAL\t" ^ measure ^ "\t" ^ money n))
    sums
  @ if partial then [ "PARTIAL" ] else []

(* 2. Income & Expense of [start, end): every Measure of the book, its classified
   Loci by ID, the totals and the Scheduled split, then the unresolved effects. *)
let income_expense book ~start ~stop =
  let period =
    { IncExp.preset = IncExp.Month; start_day = start; end_exclusive = stop; label = "" }
  in
  let r = IncExp.compute_report ~book ~roles:(B.roles book) ~period in
  let items kind (list : IncExp.line_item list) =
    List.sort (fun (a : IncExp.line_item) b -> String.compare a.locus b.locus) list
    |> List.map (fun (it : IncExp.line_item) -> kind ^ "\t" ^ it.locus ^ "\t" ^ money it.amount)
  in
  List.concat_map
    (fun (m : IncExp.measure_summary) ->
      (("MEASURE\t" ^ m.measure) :: items "INCOME" m.income_items)
      @ items "EXPENSE" m.expense_items
      @ [
          "TOTAL-INCOME\t" ^ money m.total_income;
          "TOTAL-EXPENSE\t" ^ money m.total_expense;
          "SCHEDULED\t" ^ money m.scheduled_expense;
          "ORDINARY\t" ^ money m.ordinary_expense;
          "NET\t" ^ money m.net_savings;
        ])
    r.summaries
  @ List.map
      (fun (day, locus, measure, n) ->
        String.concat "\t" [ "UNRESOLVED"; day; locus; measure; money n ])
      r.unresolved_effects

let period start stop =
  { IncExp.preset = IncExp.Month; start_day = start; end_exclusive = stop; label = "" }

let known = function Some n -> money n | None -> "?"
let refused why = [ "REFUSED\t" ^ why ]

(* 3. Transactions Flow of [start, end): every touched (Locus, Measure) by gross
   volume, then each Effect that moved it. *)
let transactions_flow book ~start ~stop =
  let r = Transactions_flow_report.compute_report ~book ~period:(period start stop) in
  List.concat_map
    (fun (row : Transactions_flow_report.row_activity) ->
      String.concat "\t"
        [
          "ROW";
          row.locus;
          row.measure;
          money row.positive;
          money row.negative;
          money row.net;
          money row.gross;
          string_of_int row.active_events;
        ]
      :: List.map
           (fun (day, n, _memo, id) -> String.concat "\t" [ "FROM"; day; id; money n ])
           row.contributions)
    r.rows

(* 4. Stock–Flow of the TRACK and LIABILITY Loci in one Measure over [start, end). *)
let stock_flow book ~measure ~start ~stop ~track ~liabilities =
  let module S = Stock_flow_report in
  let pairs = List.map (fun l -> (l, measure)) in
  match
    S.compute_report ~book ~measure ~tracked_coords:(pairs track)
      ~liability_coords:(pairs liabilities) ~period:(period start stop)
  with
  | Error why -> refused why
  | Ok r ->
      let support = function
        | S.Zero_origin -> "zero-origin"
        | S.Bounded d -> "bounded:" ^ d
        | S.Before_start d -> "before-start:" ^ d
        | S.Opening d -> "opening:" ^ d
        | S.Opening_after d -> "opening-after:" ^ d
        | S.Opening_on d -> "opening-on:" ^ d
        | S.Opening_inside d -> "opening-inside:" ^ d
        | S.Observation_undated -> "observation-undated"
        | S.Unsupported why -> "unsupported:" ^ why
      in
      List.map
        (fun (c : S.coordinate_activity) ->
          String.concat "\t"
            [
              "COORD";
              c.locus;
              support c.support;
              known c.start_balance;
              money c.increases;
              money c.decreases;
              known c.net_change;
              known c.end_balance;
              known c.current_balance;
            ])
        r.coordinates
      @ List.map (fun (c : S.coordinate_activity) -> "LIABILITY-ROW\t" ^ c.locus) r.liabilities
      @ [
          "BALANCE-START\t" ^ money r.reconstructed_start;
          "BALANCE-END\t" ^ money r.reconstructed_end;
          "UNKNOWN-STARTS\t" ^ string_of_int r.unknown_starts;
          "INCREASES\t" ^ money r.increases_across_events;
          "DECREASES\t" ^ money r.decreases_across_events;
          "NET\t" ^ known r.net_change;
          "CURRENT\t" ^ money r.current_tracked;
        ]
      @ List.map (fun (l, why) -> "UNSUPPORTED\t" ^ l ^ "\t" ^ why) r.unsupported
      @ List.map (fun (id, day) -> "EXCLUDED-OPENING\t" ^ id ^ "\t" ^ day) r.excluded_openings

(* 5. Trend / Locus: the chosen Loci's recorded flow by Cycle, Month or Day. *)
let trend book ~presets ~measure ~observed_at ~grain ~scope ~loci =
  let module T = Trend_locus_report in
  let grain =
    match grain with
    | "CYCLE" -> T.Cycle
    | "MONTH" -> T.Month
    | "DAY" -> T.Day
    | other -> bad ("grain " ^ other)
  and scope_name = function
    | T.All_history -> "ALL-HISTORY"
    | T.Current_cycle -> "CURRENT-CYCLE"
    | T.Current_month -> "CURRENT-MONTH"
    | T.Last_30_days -> "LAST-30-DAYS"
  in
  let scope =
    match scope with
    | "ALL-HISTORY" -> T.All_history
    | "CURRENT-CYCLE" -> T.Current_cycle
    | "CURRENT-MONTH" -> T.Current_month
    | "LAST-30-DAYS" -> T.Last_30_days
    | other -> bad ("scope " ^ other)
  in
  match
    T.project ~book ~observed_at ~boundary_presets_text:presets ~grain ~scope
      ~coordinates:(List.map (fun locus -> { T.locus; measure }) loci)
  with
  | Error why -> refused why
  | Ok s ->
      String.concat "\t" [ "SCOPE"; s.scope_start; s.scope_end_exclusive; scope_name s.scope ]
      :: List.concat_map
           (fun (series : T.series) ->
             ("SERIES\t" ^ series.coordinate.locus)
             :: List.map
                  (fun (p : T.point) ->
                    String.concat "\t"
                      [
                        "POINT";
                        p.start_day;
                        p.end_exclusive;
                        string_of_int p.observed_days;
                        (if p.complete then "COMPLETE" else "PARTIAL");
                        money p.total;
                        money p.value;
                      ])
                  (Array.to_list series.points))
           (Array.to_list s.series)

(* 6. Trend / Locus's default Loci for [start, end). *)
let trend_default book ~measure ~start ~stop =
  Trend_locus_report.initial_series ~book ~measure ~roles:(B.roles book) ~start_day:start
    ~end_exclusive:stop
  |> List.map (fun (c : Trend_locus_report.coordinate) -> "DEFAULT\t" ^ c.locus)

(* 7. Liquidity: today's selected balance and the open plans through a day. *)
let liquidity book ~today ~through ~pool =
  let module L = Liquidity_report in
  match L.compute ~book ~today ~coords:pool ~assumed_complete_through:through with
  | Error why -> refused why
  | Ok s ->
      ("CURRENT\t" ^ money s.current_selected)
      :: List.map
           (fun (p : L.point) ->
             String.concat "\t" [ "POINT"; p.date; money p.scheduled_change; money p.balance ])
           s.points
      @ [ "FINAL\t" ^ money (L.final_at_horizon s); "LOW\t" ^ money (L.low_water s) ]

(* 8. Multicurrency Spend of [start, end): separate exact families per Measure. *)
let multicurrency book ~start ~stop =
  let module M = Multicurrency_spend_report in
  match M.compute ~book ~roles:(B.roles book) ~start_day:start ~end_exclusive:stop with
  | Error why -> refused why
  | Ok s ->
      let totals kind =
        List.map (fun (t : M.total) -> String.concat "\t" [ kind; t.measure; money t.quanta ])
      in
      let posting (p : B.posting) = [ p.locus; p.measure; money p.amount ] in
      let unresolved kind (u : M.unresolved_effect) =
        String.concat "\t" ([ kind; u.event; u.date ] @ posting u.posting)
      in
      let witness kind (w : M.original_witness) =
        let reason =
          match w.reason with
          | M.Unresolved_roles -> "unresolved-roles"
          | M.Exchange_event -> "exchange"
          | M.No_positive_expense -> "no-positive-expense"
        in
        String.concat "\t" [ kind; w.event; w.date; w.measure; money w.quanta; reason ]
      in
      totals "ORDINARY" s.ordinary_expense
      @ totals "ORIGINAL" s.original_expense
      @ totals "EXCHANGE-EXPENSE" s.exchange_expense
      @ List.concat_map
          (fun (x : M.exchange_occurrence) ->
            String.concat "\t"
              ([ "EXCHANGE"; x.event; x.date ] @ posting x.source @ posting x.destination)
            :: List.map
                 (fun p -> String.concat "\t" ([ "EXCHANGE-EXTRA"; x.event ] @ posting p))
                 x.extra_effects)
          s.exchanges
      @ List.map (unresolved "UNRESOLVED-ORDINARY") s.unresolved_ordinary
      @ List.map (unresolved "UNRESOLVED-EXCHANGE") s.unresolved_exchange
      @ List.map (witness "UNRESOLVED-ORIGINAL") s.unresolved_original
      @ List.map (witness "UNCOUNTED-ORIGINAL") s.uncounted_original

(* The input lines a question carries after its header, by keyword. *)
let inputs keyword body =
  List.filter_map
    (fun l -> match fields l with [ k; v ] when k = keyword -> Some v | _ -> None)
    body

let answer ~presets book header body =
  match fields header with
  | [ "EXPENSE-TOTAL"; start; stop ] -> expense_total book ~start ~stop
  | [ "INCOME-EXPENSE"; start; stop ] -> income_expense book ~start ~stop
  | [ "TRANSACTIONS-FLOW"; start; stop ] -> transactions_flow book ~start ~stop
  | [ "STOCK-FLOW"; measure; start; stop ] ->
      stock_flow book ~measure ~start ~stop ~track:(inputs "TRACK" body)
        ~liabilities:(inputs "LIABILITY" body)
  | [ "TREND"; measure; observed_at; grain; scope ] ->
      trend book ~presets ~measure ~observed_at ~grain ~scope ~loci:(inputs "LOCUS" body)
  | [ "TREND-DEFAULT"; measure; start; stop ] -> trend_default book ~measure ~start ~stop
  | [ "LIQUIDITY"; today; through ] ->
      let pool =
        List.filter_map
          (fun l -> match fields l with [ "POOL"; locus; m ] -> Some (locus, m) | _ -> None)
          body
      in
      liquidity book ~today ~through ~pool
  | [ "MULTICURRENCY"; start; stop ] -> multicurrency book ~start ~stop
  | _ -> bad ("question " ^ header)

(* The question's own input lines, kept in the printed block. *)
let question_inputs body =
  List.filter
    (fun l ->
      match fields l with ("TRACK" | "LIABILITY" | "LOCUS" | "POOL") :: _ -> true | _ -> false)
    body

let kind header = List.hd (fields header)

(* A block runs from its header to END followed by the header's first field. *)
let blocks text =
  let rec split acc = function
    | [] -> if acc = [] then [] else bad "question without its END line"
    | line :: rest when acc <> [] && line = "END" ^ kind (List.nth acc (List.length acc - 1)) ->
        List.rev (line :: acc) :: split [] rest
    | line :: rest -> split (line :: acc) rest
  in
  split [] (lines text)

let () =
  let failures = ref 0 and answers = ref 0 in
  let fail name why =
    incr failures;
    Printf.printf "FAIL %s: %s\n" name why
  in
  List.iter
    (fun row ->
      match fields row with
      | [ name; book; presets; _note ] -> (
          try
            let book = match B.read (read book) with Ok b -> b | Error why -> bad why in
            let presets = if presets = "-" then None else Some (read presets) in
            List.iter
              (fun block ->
                incr answers;
                let header = List.hd block and body = List.tl block in
                let printed =
                  (header :: question_inputs body) @ answer ~presets book header body
                  @ [ "END" ^ kind header ]
                in
                if printed <> block then fail name ("answer differs:\n" ^ String.concat "\n" printed))
              (blocks (read (name ^ ".answers")))
          with Bad_sample why -> fail name ("bad sample: " ^ why))
      | _ -> fail row "bad cases row")
    (List.tl (lines (read "cases.tsv")));
  Printf.printf "%d report answers, %d failures\n" !answers !failures;
  if !failures > 0 then exit 1
