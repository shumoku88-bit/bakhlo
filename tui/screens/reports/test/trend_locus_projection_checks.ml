(* Trend / Locus projection checks: exact recorded Effect flow, explicit cycle
   history, effective scopes, window completeness and refusals. Synthetic books
   only; no wording, layout or default-count assertions. *)
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module T = Trend_locus_report
module O = Daily_overlays

let get = function Ok x -> x | Error why -> failwith why
let require condition why = if not condition then failwith why
let z = Z.of_int
let coord locus measure : T.coordinate = { locus; measure }
let posting locus measure n = Printf.sprintf "EFFECT\t%s\t%s\t%s\n" locus measure (Z.to_string n)

(* One balanced jpy pair: the signed effect lands on a, its counter-effect on b. *)
let ab n = posting "a" "jpy" n ^ posting "b" "jpy" (Z.neg n)
let row id day postings = Printf.sprintf "TX\t%s\t%s\n%sENDTX\n" id day postings

(* Loci in [approved] are offered for new entries; those in [hidden] are only recorded. *)
let fixture ?(approved = [ "a"; "b"; "c"; "gamma" ]) ?(hidden = []) entries =
  let locus suffix l = Printf.sprintf "LOCUS\t%s\t%s\t%s\n" l l suffix in
  Bakhlo_sexp.Daily_txt.book
    ("BOOK\t1\nMEASURE\tjpy\t0\nMEASURE\teur\t2\n"
    ^ String.concat "" (List.map (locus "") approved)
    ^ String.concat "" (List.map (locus "\tHIDDEN") hidden)
    ^ entries ^ "ZERO-ORIGIN\ta\tjpy\nZERO-ORIGIN\tb\tjpy\nEND\n")

let preset name dates = name ^ "\t" ^ String.concat "\t" dates ^ "\n"
let config = preset "household" [ "2026-10-01"; "2026-10-03"; "2026-11-01" ]
let observation = "2026-10-03"
let a_only = [ coord "a" "jpy" ]

let primary =
  fixture
    (row "sep" "2026-09-30" (ab (z 900))
    ^ row "oct1" "2026-10-01" (ab (z 5))
    ^ row "oct2" "2026-10-02"
        (ab (z (-2)) ^ posting "a" "eur" (z 12345) ^ posting "b" "eur" (z (-12345)))
    ^ row "oct3" "2026-10-03" (ab (z (-4)))
    ^ row "oct4" "2026-10-04" (ab (z 100)))

let project ?(config = Some config) ?(grain = T.Cycle) ?(scope = T.All_history) book observed
    coordinates =
  T.project ~book ~observed_at:observed ~boundary_presets_text:config ~grain ~scope ~coordinates

let series_of snapshot ~locus =
  match Array.find_opt (fun (s : T.series) -> s.coordinate.locus = locus) snapshot.T.series with
  | Some s -> s
  | None -> failwith ("missing series " ^ locus)

let point what (p : T.point) ~start ~stop ~days ~total ~value ~complete =
  require
    (p.start_day = start && p.end_exclusive = stop && p.observed_days = days
   && Z.equal p.total total && Z.equal p.value value && p.complete = complete)
    what

let refuses ?config ?(grain = T.Day) ?(scope = T.All_history) book observed coordinates why =
  require
    (Result.is_error
       (T.project ~book ~observed_at:observed ~boundary_presets_text:config ~grain ~scope
          ~coordinates))
    why

let effects_book_checks () =
  let cycle = get (project primary observation a_only) in
  require
    (cycle.T.measure = "jpy" && cycle.observed_at = observation && cycle.grain = T.Cycle
   && cycle.scope = T.All_history && cycle.scope_start = "2026-10-01"
    && cycle.scope_end_exclusive = "2026-10-04")
    "cycle snapshot keeps the explicit observation and clips history at its first boundary";
  let a = series_of cycle ~locus:"a" in
  require
    (Array.length a.points = 2)
    "explicit adjacent boundaries produce two clipped cycle windows";
  point "cycle first window totals recorded signed effects inside the clipped history" a.points.(0)
    ~start:"2026-10-01" ~stop:"2026-10-03" ~days:2 ~total:(z 3) ~value:(z 1) ~complete:true;
  point "cycle current window is clipped at observation+1 and partial" a.points.(1)
    ~start:"2026-10-03" ~stop:"2026-10-04" ~days:1 ~total:(z (-4)) ~value:(z (-4)) ~complete:false;
  let month = get (project ~grain:T.Month primary observation a_only) in
  point "month average of a negative flow floors instead of truncating to zero"
    (series_of month ~locus:"a").points.(0)
    ~start:"2026-10-01" ~stop:"2026-10-04" ~days:3 ~total:(z (-1)) ~value:(z (-1)) ~complete:false;
  let day = get (project ~grain:T.Day primary observation a_only) in
  require (day.scope_end_exclusive = "2026-10-04") "day scope ends at observation+1";
  let d = series_of day ~locus:"a" in
  require (Array.length d.points = 3) "day grain is one point per calendar day";
  point "prior day is a complete day window" d.points.(0) ~start:"2026-10-01" ~stop:"2026-10-02"
    ~days:1 ~total:(z 5) ~value:(z 5) ~complete:true;
  point "second prior day keeps its own signed effect" d.points.(1) ~start:"2026-10-02"
    ~stop:"2026-10-03" ~days:1 ~total:(z (-2)) ~value:(z (-2)) ~complete:true;
  point "observation day itself stays partial" d.points.(2) ~start:"2026-10-03" ~stop:"2026-10-04"
    ~days:1 ~total:(z (-4)) ~value:(z (-4)) ~complete:false;
  let gamma = get (project ~grain:T.Day primary observation [ coord "gamma" "jpy" ]) in
  require
    (Array.for_all
       (fun (p : T.point) -> Z.equal p.total Z.zero && Z.equal p.value Z.zero)
       (series_of gamma ~locus:"gamma").points)
    "an admitted locus with no entries records an exact zero flow";
  require
    (O.quantity_value ~book:primary ~measure:"jpy" "gamma" = O.Unsupported)
    "an empty recorded flow invents no balance support";
  let eur = get (project ~grain:T.Day primary observation [ coord "a" "eur" ]) in
  let e = series_of eur ~locus:"a" in
  require
    (Z.equal e.points.(1).total (z 12345) && B.format primary "eur" e.points.(1).total = "123.45")
    "other-measure postings project only under their own measure at their own scale"

let huge_book_checks () =
  let huge = Z.add (Z.pow (z 10) 600) (z 7) in
  let book = fixture (row "huge" "2026-10-01" (ab huge)) in
  let cycle = get (project book observation a_only) in
  let p = (series_of cycle ~locus:"a").points.(0) in
  require (Z.equal p.total huge) "a 601-digit recorded total survives projection exactly";
  require
    (Z.equal p.value (Z.add (Z.mul (z 5) (Z.pow (z 10) 599)) (z 3)))
    "huge totals divide with exact Euclidean floor, not machine-sized arithmetic";
  let day = get (project ~grain:T.Day book observation a_only) in
  require (Z.equal (series_of day ~locus:"a").points.(0).total huge) "huge day total is exact"

let catalog_checks () =
  require
    (T.catalog ~book:primary ~measure:"jpy"
    = [ coord "a" "jpy"; coord "b" "jpy"; coord "c" "jpy"; coord "gamma" "jpy" ])
    "catalog is admitted plus recorded identities, never inferred roles";
  let historical =
    fixture ~approved:[] ~hidden:[ "a"; "b"; "d" ]
      (row "h1" "2026-10-02" (ab (z 5) ^ posting "d" "eur" (z 700) ^ posting "a" "eur" (z (-700))))
  in
  require
    (T.catalog ~book:historical ~measure:"jpy" = [ coord "a" "jpy"; coord "b" "jpy" ])
    "historical effect loci supply catalog coordinates";
  require
    (T.catalog ~book:historical ~measure:"eur" = [ coord "a" "eur"; coord "d" "eur" ])
    "catalog never mixes measures"

let scope_checks () =
  let long = Some (preset "long" [ "2026-01-01"; "2026-11-01" ]) in
  let last30 =
    get (project ~config:long ~grain:T.Day ~scope:T.Last_30_days primary "2026-10-31" a_only)
  in
  let l = series_of last30 ~locus:"a" in
  require
    (last30.scope_start = "2026-10-02"
    && last30.scope_end_exclusive = "2026-11-01"
    && Array.length l.points = 30
    && l.points.(0).start_day = "2026-10-02"
    && l.points.(29).start_day = "2026-10-31")
    "last 30 days is exactly 30 calendar days including the observation";
  require
    (Z.equal l.points.(0).total (z (-2)) && Z.equal l.points.(29).total Z.zero)
    "last 30 days keeps recorded days only";
  let short = Some (preset "short" [ "2026-10-20"; "2026-11-01" ]) in
  let clamped =
    get (project ~config:short ~grain:T.Day ~scope:T.Last_30_days primary "2026-10-31" a_only)
  in
  let c = series_of clamped ~locus:"a" in
  require
    (clamped.scope_start = "2026-10-20" && Array.length c.points = 12)
    "last 30 days clamps to the first configured history day";
  let current_month =
    get (project ~config:long ~grain:T.Day ~scope:T.Current_month primary "2026-10-31" a_only)
  in
  require (current_month.scope_start = "2026-10-01") "current month starts at the calendar month";
  let current_cycle =
    get (project ~config:long ~grain:T.Day ~scope:T.Current_cycle primary "2026-10-31" a_only)
  in
  require
    (current_cycle.scope_start = "2026-01-01")
    "current cycle starts at the containing boundary";
  let ignored =
    get (project ~config:long ~grain:T.Month ~scope:T.Current_month primary "2026-10-31" a_only)
  in
  require
    (ignored.scope = T.All_history && ignored.scope_start = "2026-01-01")
    "month grain always projects all history";
  let ignored_cycle =
    get (project ~config:long ~grain:T.Cycle ~scope:T.Last_30_days primary "2026-10-31" a_only)
  in
  require
    (ignored_cycle.scope = T.All_history && ignored_cycle.scope_start = "2026-01-01")
    "cycle grain always projects all history"

let window_checks () =
  let partial_config = Some (preset "partial" [ "2026-10-15"; "2026-11-20" ]) in
  let book =
    fixture
      (row "early" "2026-10-10" (ab (z 99))
      ^ row "mid" "2026-10-15" (ab (z 10))
      ^ row "end" "2026-10-31" (ab (z 20))
      ^ row "next" "2026-11-01" (ab (z 7))
      ^ row "last" "2026-11-05" (ab (z (-2))))
  in
  let month = get (project ~config:partial_config ~grain:T.Month book "2026-11-05" a_only) in
  let m = series_of month ~locus:"a" in
  require
    (month.scope_start = "2026-10-15" && Array.length m.points = 2)
    "history starting midmonth clips the first calendar bucket";
  point "partial first month keeps only recorded days inside the clipped history" m.points.(0)
    ~start:"2026-10-15" ~stop:"2026-11-01" ~days:17 ~total:(z 30) ~value:(z 1) ~complete:false;
  point "later month clipped at observation+1 stays partial" m.points.(1) ~start:"2026-11-01"
    ~stop:"2026-11-06" ~days:5 ~total:(z 5) ~value:(z 1) ~complete:false;
  let leap_config = Some (preset "leap" [ "2028-02-01"; "2028-03-01" ]) in
  let leap = fixture (row "feb" "2028-02-29" (ab (z 3)) ^ row "mar" "2028-03-01" (ab (z 100))) in
  let day = get (project ~config:leap_config ~grain:T.Day leap "2028-02-29" a_only) in
  let d = series_of day ~locus:"a" in
  require
    (Array.length d.points = 29 && d.points.(0).start_day = "2028-02-01")
    "leap February day scope spans 29 real days";
  point "first leap day is a complete day window" d.points.(0) ~start:"2028-02-01"
    ~stop:"2028-02-02" ~days:1 ~total:Z.zero ~value:Z.zero ~complete:true;
  point "leap observation day stays partial" d.points.(28) ~start:"2028-02-29" ~stop:"2028-03-01"
    ~days:1 ~total:(z 3) ~value:(z 3) ~complete:false;
  let month = get (project ~config:leap_config ~grain:T.Month leap "2028-02-29" a_only) in
  point "a month ending at observation+1 is a full natural window"
    (series_of month ~locus:"a").points.(0)
    ~start:"2028-02-01" ~stop:"2028-03-01" ~days:29 ~total:(z 3) ~value:Z.zero ~complete:true;
  let cycle = get (project ~config:leap_config ~grain:T.Cycle leap "2028-02-29" a_only) in
  point "a cycle ending at observation+1 is a full natural window"
    (series_of cycle ~locus:"a").points.(0)
    ~start:"2028-02-01" ~stop:"2028-03-01" ~days:29 ~total:(z 3) ~value:Z.zero ~complete:true

let refusal_checks () =
  refuses primary observation a_only "missing boundary configuration is unavailable, never inferred";
  refuses ?config:(Some "") primary observation a_only "empty boundary configuration is unavailable";
  refuses
    ?config:(Some (preset "only" [ "2026-10-01" ]))
    primary observation a_only "a boundary line with one date is malformed";
  refuses
    ?config:(Some (preset "bad" [ "2026-1-01"; "2026-11-01" ]))
    primary observation a_only "a noncanonical boundary date is malformed";
  refuses
    ?config:(Some (preset "down" [ "2026-11-01"; "2026-10-01" ]))
    primary observation a_only "nonincreasing boundaries refuse";
  refuses
    ?config:
      (Some
         (preset "dup" [ "2026-10-01"; "2026-11-01" ] ^ preset "dup" [ "2026-10-01"; "2026-11-01" ]))
    primary observation a_only "a duplicate preset name refuses";
  refuses
    ?config:
      (Some (preset "x" [ "2026-10-01"; "2026-11-01" ] ^ preset "y" [ "2026-10-01"; "2026-11-01" ]))
    primary observation a_only "two covering presets make the history ambiguous";
  refuses ?config:(Some config) primary "2026-12-01" a_only
    "an observation outside every window refuses";
  refuses ?config:(Some config) primary "2026-02-29" a_only
    "a nonexistent Gregorian observation refuses";
  refuses ?config:(Some config) primary "2026-13-01" a_only "an invalid observation month refuses";
  refuses ?config:(Some config) primary observation [] "no coordinate refuses";
  refuses ?config:(Some config) primary observation
    [ coord "a" "jpy"; coord "b" "eur" ]
    "mixed measures refuse";
  refuses ?config:(Some config) primary observation
    [ coord "a" "jpy"; coord "a" "jpy" ]
    "a duplicated locus refuses";
  refuses ?config:(Some config) primary observation
    (List.map (fun id -> coord id "jpy") [ "a"; "b"; "c"; "gamma"; "d"; "e" ])
    "more than five coordinates refuse";
  refuses ?config:(Some config) primary observation [ coord "a" "usd" ] "an unknown measure refuses"

let make_effect locus measure quanta =
  let identifier what = function Ok x -> x | Error _ -> failwith ("invalid " ^ what) in
  D.Effect.create ~key:None
    ~locus:(identifier "locus" (D.Identifier.Locus.of_string locus))
    ~measure:(identifier "measure" (D.Identifier.Measure.of_string measure))
    ~quantity:(D.Quantity.of_quanta quanta)

let mutation_checks () =
  let row ~id ~day n : B.entry =
    {
      id;
      day;
      memo = None;
      effects = [ make_effect "a" "jpy" n; make_effect "b" "jpy" (Z.neg n) ];
      reversal_of = None;
      exchange = None;
      original_amount = None;
      merchant = None;
    }
  in
  let base = fixture "" in
  let oct2 =
    get (B.put_entry base ~replace:false ~plan:None (row ~id:"e" ~day:"2026-10-02" (z 5)))
  in
  let corrected =
    get (B.put_entry oct2 ~replace:true ~plan:None (row ~id:"e" ~day:"2026-10-01" (z 5)))
  in
  let corrected_day = get (project ~grain:T.Day corrected observation a_only) in
  let cd = series_of corrected_day ~locus:"a" in
  point "a date correction moves the dated effect" cd.points.(0) ~start:"2026-10-01"
    ~stop:"2026-10-02" ~days:1 ~total:(z 5) ~value:(z 5) ~complete:true;
  point "the corrected entry's old date carries no stale effect" cd.points.(1) ~start:"2026-10-02"
    ~stop:"2026-10-03" ~days:1 ~total:Z.zero ~value:Z.zero ~complete:true;
  let reversed =
    get
      (B.put_entry corrected ~replace:false ~plan:None
         { (row ~id:"rev" ~day:"2026-10-01" (z (-5))) with reversal_of = Some "e" })
  in
  require (B.entry_count reversed = 2) "a reversal is its own retained entry";
  let reversed_day = get (project ~grain:T.Day reversed observation a_only) in
  require
    (Array.for_all
       (fun (p : T.point) -> Z.equal p.total Z.zero)
       (series_of reversed_day ~locus:"a").points)
    "a true reversal nets the dated effect to exact recorded zero, not a double count";
  let cycle = get (project reversed observation a_only) in
  require
    (Z.equal (series_of cycle ~locus:"a").points.(0).total Z.zero)
    "cycle totals follow current corrected entries"

let () =
  effects_book_checks ();
  huge_book_checks ();
  catalog_checks ();
  scope_checks ();
  window_checks ();
  refusal_checks ();
  mutation_checks ();
  print_endline
    "PASS: Trend/Locus exact recorded flow, explicit cycle history, floor division, scopes, window \
     completeness and configuration refusals."
