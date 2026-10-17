module B = Daily_book
module I = B.Annual_internal
module D = Bakhlo_domain

exception Refused of string
let require p why = if not p then raise (Refused why)
let get = function Ok x -> x | Error why -> raise (Refused why)
let protect f = try Ok (f ()) with Refused why -> Error why

type reference = { year : int; fingerprint : string }
type t = { year : int; reference : reference; payload : I.payload }

let valid_hex32 s =
  String.length s = 32
  && String.for_all (fun c -> (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')) s

let check_reference ~year (reference : reference) =
  require (year >= 2 && year <= 9999) "annual-year-out-of-range";
  require (reference.year = year - 1) "annual-prior-year-mismatch";
  require (valid_hex32 reference.fingerprint) "annual-invalid-fingerprint"

let in_year ~year day =
  String.starts_with ~prefix:(Printf.sprintf "%04d-" year) day

let effect_equal a b =
  D.Identifier.Locus.equal (D.Effect.locus a) (D.Effect.locus b)
  && D.Identifier.Measure.equal (D.Effect.measure a) (D.Effect.measure b)
  && D.Quantity.equal (D.Effect.quantity a) (D.Effect.quantity b)
  && Option.equal D.Identifier.Effect_key.equal (D.Effect.key a) (D.Effect.key b)

let entry_equal (a : B.entry) (b : B.entry) =
  a.id = b.id && a.day = b.day && a.memo = b.memo && a.reversal_of = b.reversal_of
  && a.exchange = b.exchange && a.original_amount = b.original_amount
  && a.merchant = b.merchant
  && List.equal effect_equal a.effects b.effects

let plan_equal (a : B.plan) (b : B.plan) =
  a.id = b.id && a.day = b.day && a.measure = b.measure && a.paid_by = b.paid_by
  && a.cancelled_on = b.cancelled_on
  && List.equal (fun (l1, q1) (l2, q2) -> l1 = l2 && Z.equal q1 q2) a.changes b.changes

let validate_against_prior ~year ~(prior : B.t) (payload : I.payload) =
  let prior_entries = B.entries prior in
  let prior_plans = B.plans prior in
  let local_ids = List.map (fun (e : B.entry) -> e.id) payload.entries in
  List.iter (fun (e : B.entry) ->
    require (in_year ~year e.day) ("annual-entry-outside-year:" ^ e.id);
    require (not (B.mem_entry prior e.id)) ("annual-duplicate-prior-entry:" ^ e.id);
    Option.iter (fun target ->
      require (not (B.mem_entry prior target)) "annual-cross-year-reversal-refused")
      e.reversal_of) payload.entries;
  List.iter (fun (old_plan : B.plan) ->
    match List.find_opt (fun (p : B.plan) -> p.id = old_plan.id) payload.plans with
    | None -> raise (Refused ("annual-prior-plan-missing:" ^ old_plan.id))
    | Some current when not (B.plan_is_open old_plan) ->
        require (plan_equal old_plan current) ("annual-closed-plan-modified:" ^ old_plan.id)
    | Some current ->
        require (old_plan.measure = current.measure) "annual-plan-measure-modified";
        Option.iter (fun paid ->
          require (List.mem paid local_ids) "annual-plan-paid-by-nonlocal-entry")
          current.paid_by;
        Option.iter (fun day ->
          require (in_year ~year day) "annual-plan-cancelled-outside-year")
          current.cancelled_on) prior_plans;
  List.iter (fun (p : B.plan) ->
    if not (List.exists (fun (old : B.plan) -> old.id = p.id) prior_plans) then (
      Option.iter (fun paid ->
        require (List.mem paid local_ids) "annual-plan-paid-by-nonlocal-entry") p.paid_by;
      Option.iter (fun day ->
        require (in_year ~year day) "annual-plan-cancelled-outside-year") p.cancelled_on))
    payload.plans;
  get (I.admit_payload { payload with entries = prior_entries @ payload.entries })

let of_string bytes =
  protect (fun () ->
    let year_str, prior_str, fingerprint, payload = get (I.parse_annual bytes) in
    let year = get (Annual_scope.of_string year_str) in
    let prior_year = get (Annual_scope.of_string prior_str) in
    let reference = { year = prior_year; fingerprint } in
    check_reference ~year reference;
    List.iter (fun (e : B.entry) ->
      require (in_year ~year e.day) ("annual-entry-outside-year:" ^ e.id)) payload.entries;
    { year; reference; payload })

let reference t = t.reference
let year t = t.year

let decode ~prior t =
  protect (fun () -> validate_against_prior ~year:t.year ~prior t.payload)

let encode ~year ~reference ~prior book =
  protect (fun () ->
    check_reference ~year reference;
    let prior_entries = B.entries prior in
    let full = I.export_payload book in
    let prior_len = List.length prior_entries in
    let full_len = List.length full.entries in
    require (full_len >= prior_len) "annual-prior-entries-removed";
    let rec split n acc xs =
      if n = 0 then (List.rev acc, xs)
      else match xs with
        | [] -> raise (Refused "annual-prior-entries-removed")
        | x :: rest -> split (n - 1) (x :: acc) rest
    in
    let prefix, local_entries = split prior_len [] full.entries in
    require (List.equal entry_equal prefix prior_entries) "annual-prior-entries-modified";
    let local = { full with entries = local_entries } in
    let recomposed = validate_against_prior ~year ~prior local in
    let rendered =
      I.render_annual ~year ~prior_year:reference.year ~prior_fingerprint:reference.fingerprint local
    in
    let parsed = get (of_string rendered) in
    let roundtrip = get (decode ~prior parsed) in
    require (B.to_string recomposed = B.to_string book && B.to_string roundtrip = B.to_string book)
      "annual-unstable-printer";
    rendered)

let start ~year ~reference ~prior =
  encode ~year ~reference ~prior prior
