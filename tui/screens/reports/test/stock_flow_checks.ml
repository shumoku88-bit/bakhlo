(* Stock–Flow presentation and cold reload. Calculation rules live in
   test/reports; unknown boundaries stay visible here, never rendered as zero. *)
module B = Bakhlo_household.Book
module S = Stock_flow_report
module SF = Bakhlo_household.Stock_flow
module I = Income_expense_report

let get = function Ok x -> x | Error why -> failwith why
let require condition why = if not condition then failwith why

let fixture support =
  get
  @@ B.read
       ("BOOK\t1\nMEASURE\tjpy\t0\nMEASURE\teur\t2\nLOCUS\ta\ta\t\nLOCUS\tb\tb\t\nLOCUS\tc\tc\t\n"
      ^ "TX\tbefore\t2026-09-30\nEFFECT\ta\tjpy\t20\nEFFECT\tb\tjpy\t-20\nENDTX\n"
      ^ "TX\twithin\t2026-10-16\n\
         EFFECT\ta\tjpy\t10\n\
         EFFECT\ta\tjpy\t20\n\
         EFFECT\tb\tjpy\t-30\n\
         ENDTX\n" ^ "TX\tend\t2026-11-01\nEFFECT\ta\tjpy\t40\nEFFECT\tb\tjpy\t-40\nENDTX\n"
      ^ support ^ "END\n")

(* What a save and a cold load give. *)
let cold_of book = get (B.read (Bakhlo_household.Book.print book))

let self_check () =
  let zero = fixture "ZERO-ORIGIN\ta\tjpy\nZERO-ORIGIN\tb\tjpy\n" in
  let anchored = fixture "ZERO-ORIGIN\tb\tjpy\nANCHOR\t-\nASSERT\ta\tjpy\t10\nENDANCHOR\n" in
  let bounded = get (B.with_bounded_history anchored [ ("a", "jpy", "2026-09-15") ]) in
  let period : I.period =
    { preset = I.Month; start_day = "2026-10-01"; end_exclusive = "2026-11-01"; label = "October" }
  in
  let compute ?(liabilities = []) book tracked_coords =
    SF.compute book ~measure:"jpy" ~tracked_coords ~liability_coords:liabilities
      ~start:period.start_day ~stop:period.end_exclusive
    |> Result.map_error SF.message
  in
  let before_period : I.period =
    { period with start_day = "2026-09-01"; end_exclusive = "2026-10-01" }
  in
  let before =
    get
      (Result.map_error SF.message
      @@ SF.compute bounded ~measure:"jpy"
           ~tracked_coords:[ ("a", "jpy") ]
           ~liability_coords:[] ~start:before_period.start_day ~stop:before_period.end_exclusive)
  in

  (* A cold reload agrees with the in-memory book. *)
  let reloaded = cold_of zero in
  let cold = get (compute reloaded [ ("a", "jpy"); ("b", "jpy") ]) in
  let warm = get (compute zero [ ("a", "jpy"); ("b", "jpy") ]) in
  require
    (List.map
       (fun (c : SF.coordinate_activity) -> (c.locus, c.start_balance, c.end_balance))
       cold.SF.coordinates
    = List.map
        (fun (c : SF.coordinate_activity) -> (c.locus, c.start_balance, c.end_balance))
        warm.SF.coordinates)
    "a cold reload reconstructs the same boundaries";

  (* The footnote names which total is partial. *)
  let contains text needle =
    let length = String.length needle in
    let rec loop index =
      index + length <= String.length text
      && (String.sub text index length = needle || loop (index + 1))
    in
    length = 0 || loop 0
  in
  let before_lines =
    List.map snd
      (S.render_summary_lines ~width:120 ~width_of:String.length ~period ~book:bounded
         ~report:before)
  in
  require
    (List.exists (fun line -> contains line "start total excludes") before_lines
    && List.exists (fun line -> contains line "end total still adds every known end") before_lines)
    "the footnote says which total excludes unknown starts";

  (* The debt section is built from the book's roles. *)
  let screen_env =
    Screen.env_for_checks
      ~config:(fun name ->
        if name = "balance-view.tsv" then Ok (Some "a\tjpy\n")
        else if name = "boundary-presets.tsv" then Ok (Some "household\t2026-10-01\t2026-11-01\n")
        else Error ("undeclared " ^ name))
      ~book:zero ~measure:"jpy" ~today:"2026-10-22" ()
  in
  let screen = Stock_flow_screen.create () in
  require
    (Result.is_ok (Stock_flow_screen.result screen_env screen))
    "the debt section is built from the book's roles";

  (* Opening support: exact from the opening entry's date, unknown before it. *)
  let opening_book =
    get
    @@ B.read
         "BOOK\t1\n\
          MEASURE\tjpy\t0\n\
          MEASURE\teur\t2\n\
          LOCUS\tdebt\tdebt\t\n\
          LOCUS\tcash\tcash\t\n\
          LOCUS\topening-equity\topening-equity\t\n\
          LOCUS\teur-debt\teur-debt\t\n\
          TX\topen\t2026-09-01\n\
          EFFECT\tdebt\tjpy\t1000\n\
          EFFECT\topening-equity\tjpy\t-1000\n\
          ENDTX\n\
          TX\teur-open\t2026-09-02\n\
          EFFECT\tcash\tjpy\t-100\tfrom\n\
          EFFECT\teur-debt\teur\t500\tto\n\
          EXCHANGE\tjpy\teur\n\
          ENDTX\n\
          TX\trepay\t2026-10-10\n\
          EFFECT\tdebt\tjpy\t-300\n\
          EFFECT\tcash\tjpy\t300\n\
          ENDTX\n\
          ZERO-ORIGIN\topening-equity\tjpy\n\
          ZERO-ORIGIN\tcash\tjpy\n\
          OPENING\tdebt\tjpy\topen\n\
          OPENING\teur-debt\teur\teur-open\n\
          END\n"
  in
  let before_open : I.period =
    { period with start_day = "2026-08-01"; end_exclusive = "2026-09-15" }
  in
  let early =
    get
      (Result.map_error SF.message
      @@ SF.compute opening_book ~measure:"jpy"
           ~tracked_coords:[ ("debt", "jpy") ]
           ~liability_coords:[] ~start:before_open.start_day ~stop:before_open.end_exclusive)
  in
  let early_lines =
    List.map snd
      (S.render_summary_lines ~width:120 ~width_of:String.length ~period ~book:opening_book
         ~report:early)
  in
  require
    (List.exists (fun line -> contains line "the window contains the opening entry") early_lines)
    "the row note says the window contains the opening entry";

  (* The opening entry is not a flow on either side: its counterpart posting
     does not show as a decrease, so the tracked increases and decreases
     cancel. *)
  let inside_opening =
    get
      (Result.map_error SF.message
      @@ SF.compute opening_book ~measure:"jpy"
           ~tracked_coords:[ ("debt", "jpy"); ("opening-equity", "jpy") ]
           ~liability_coords:[] ~start:before_open.start_day ~stop:before_open.end_exclusive)
  in
  let inside_lines =
    List.map snd
      (S.render_summary_lines ~width:120 ~width_of:String.length ~period ~book:opening_book
         ~report:inside_opening)
  in
  require
    (List.exists
       (fun line ->
         contains line
           "The opening entry open dated 2026-09-01 is left out of the in-window flows on both \
            sides")
       inside_lines)
    "the note names the excluded entry";
  require
    (List.exists
       (fun line -> contains line "Start and End include those entries; +In and -Out do not")
       inside_lines)
    "the note says Start and End include the entry while +In and -Out do not";

  (* Start and End still carry the excluded opening entry, so the motion is
     unknown: the Net cell of the affected row, of the Total row and of the
     "Net change in tracked balance" line stay unknown. *)
  let counterpart_only =
    get
      (Result.map_error SF.message
      @@ SF.compute opening_book ~measure:"jpy"
           ~tracked_coords:[ ("opening-equity", "jpy") ]
           ~liability_coords:[] ~start:before_open.start_day ~stop:before_open.end_exclusive)
  in
  let counterpart_lines =
    List.map snd
      (S.render_summary_lines ~width:120 ~width_of:String.length ~period ~book:opening_book
         ~report:counterpart_only)
  in
  require
    (List.exists
       (fun line -> contains line "Net change in tracked balance:" && contains line "—")
       counterpart_lines)
    "the Net change in tracked balance line stays unknown";
  let total_line = List.find_opt (fun line -> contains line "Total (jpy)") counterpart_lines in
  (match total_line with
  | None -> failwith "the total row must be rendered"
  | Some line ->
      let fields = List.filter (fun word -> word <> "") (String.split_on_char ' ' line) in
      require (List.hd (List.rev fields) = "—") "the total row's Net stays unknown");
  (* A window that ends before the opening entry: start and end stay unknown. *)
  let before_open : I.period =
    { period with start_day = "2026-07-01"; end_exclusive = "2026-08-15" }
  in
  let earlier =
    get
      (Result.map_error SF.message
      @@ SF.compute opening_book ~measure:"jpy"
           ~tracked_coords:[ ("debt", "jpy") ]
           ~liability_coords:[] ~start:before_open.start_day ~stop:before_open.end_exclusive)
  in
  let earlier_lines =
    List.map snd
      (S.render_summary_lines ~width:120 ~width_of:String.length ~period ~book:opening_book
         ~report:earlier)
  in
  require
    (List.exists
       (fun line -> contains line "the window ends before the opening entry")
       earlier_lines)
    "the row note says the window ends before the opening entry";

  (* A cold reload of an opening book agrees with the in-memory book. *)
  let opening_cold = cold_of opening_book in
  let cold = get (compute opening_cold [ ("debt", "jpy") ]) in
  let warm = get (compute opening_book [ ("debt", "jpy") ]) in
  require
    (List.map
       (fun (c : SF.coordinate_activity) -> (c.locus, c.support, c.start_balance, c.end_balance))
       cold.SF.coordinates
    = List.map
        (fun (c : SF.coordinate_activity) -> (c.locus, c.support, c.start_balance, c.end_balance))
        warm.SF.coordinates)
    "a cold reload of an opening book reconstructs the same boundaries";

  (* The liability row prints start / +In / -Out / end in that order. *)
  let debt_rows =
    List.map snd
      (S.render_summary_lines ~width:120 ~width_of:String.length ~period ~book:opening_book
         ~report:(get (compute ~liabilities:[ ("debt", "jpy") ] opening_book [ ("debt", "jpy") ])))
  in
  let debt_line =
    List.find_opt
      (fun line -> String.length line > 12 && String.sub line 4 8 = "debt/jpy")
      debt_rows
  in
  (match debt_line with
  | None -> failwith "the liability row must be rendered"
  | Some line ->
      let fields = List.filter (fun word -> word <> "") (String.split_on_char ' ' line) in
      require
        (List.filteri (fun index _ -> index < 5) fields
        = [ "debt/jpy"; "1,000"; "+0"; "-300"; "700" ])
        "the liability row keeps the start / +In / -Out / end columns");
  require
    (List.exists (fun line -> contains line "Liabilities (start / +In / -Out / end)") debt_rows)
    "the liabilities heading names neutral columns";
  require
    (not (List.exists (fun line -> contains line "repaid" || contains line "borrowed") debt_rows))
    "the liabilities heading names no repayment or borrowing";

  (* Observation support is exact but undated: it never back-fills a start. *)
  let observation_book =
    get
    @@ B.read
         "BOOK\t1\n\
          MEASURE\tjpy\t0\n\
          LOCUS\tdebt\tdebt\t\n\
          LOCUS\tcash\tcash\t\n\
          TX\tborrow\t2026-10-10\n\
          EFFECT\tdebt\tjpy\t400\n\
          EFFECT\tcash\tjpy\t-400\n\
          ENDTX\n\
          ANCHOR\tborrow\n\
          ASSERT\tdebt\tjpy\t400\n\
          ENDANCHOR\n\
          END\n"
  in
  let observed = get (compute observation_book [ ("debt", "jpy") ]) in
  let lines =
    List.map snd
      (S.render_summary_lines ~width:120 ~width_of:String.length ~period ~book:observation_book
         ~report:observed)
  in
  require
    (List.exists (fun line -> contains line "the balance before it is not derivable") lines)
    "the note says the balance before the confirmation is not derivable";

  (* The Net cell is the motion between the two boundaries: with an unknown
     boundary it stays unknown instead of showing the in-window motion. *)
  let observed_row =
    List.find_opt
      (fun line ->
        String.length line > 10 && String.sub line 2 8 = "debt/jpy" && contains line "+400")
      lines
  in
  (match observed_row with
  | None -> failwith "the observed debt row must be rendered"
  | Some line ->
      let words = List.filter (fun word -> word <> "") (String.split_on_char ' ' line) in
      require (List.hd (List.rev words) = "—") "an unknown boundary leaves the Net cell unknown";
      require (List.mem "+400" words) "the in-window motion stays in its own column");
  print_endline
    "PASS: Stock-Flow unknown-boundary notes, opening exclusions, liability columns and \
     cold-reload agreement (synthetic)."
