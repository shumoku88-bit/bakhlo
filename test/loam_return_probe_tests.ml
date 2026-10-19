(* Synthetic, read-only feasibility probe. This is NOT a LOAM importer.
   It exercises Bakhlo's admitted Daily book and the documented LOAM v2
   Movement proposal *shape*. A real LOAM parser, admission, publication,
   IDs and full-household reconciliation are NOT tested here. *)
open Base
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain

let get = function Ok value -> value | Error why -> failwith why

let identifier make name =
  match make name with Ok value -> value | Error _ -> failwith "invalid synthetic identifier"

let posting locus quantity =
  D.Effect.create
    ~locus:(identifier D.Identifier.Locus.of_string locus)
    ~measure:(identifier D.Identifier.Measure.of_string "jpy")
    ~quantity:(D.Quantity.of_quanta (Z.of_int quantity))
    ~key:None

let ordinary_entry : B.entry =
  {
    id = "e1";
    day = "2026-10-03";
    memo = Some "groceries";
    effects = [ posting "wallet" (-120); posting "food" 120 ];
    reversal_of = None;
    exchange = None;
    original_amount = None;
    merchant = None;
  }

let base_book () =
  let book = get (B.empty ~measure:"jpy" ~scale:0) in
  let book = get (B.add_locus book "wallet") in
  get (B.add_locus book "food")

let canonical_trial () =
  let book = get (B.put_entry (base_book ()) ~replace:false ordinary_entry ~plan:None) in
  let cold = get (B.of_string (B.to_string book)) in
  let selected =
    match B.find_entry cold "e1" with
    | Some entry -> entry
    | None -> failwith "synthetic canonical entry missing"
  in
  (cold, selected)

let has_separator text =
  String.exists text ~f:(function '\n' | '\r' | '\t' -> true | _ -> false)

(* Reject any independent meaning this tiny transport cannot carry. The
   operation token is retry identity, NEVER the restored Event identity. *)
let proposal_shape ~operation (book : B.t) (entry : B.entry) =
  let paid_by_entry =
    List.exists (B.plans book) ~f:(fun (plan : B.plan) ->
        Option.value_map plan.paid_by ~default:false ~f:(String.equal entry.id))
  in
  if String.is_empty operation || has_separator operation then Error "operation-token"
  else if Option.is_some entry.reversal_of then Error "reversal-relation"
  else if Option.is_some entry.exchange then Error "exchange-evidence"
  else if Option.is_some entry.original_amount then Error "original-amount"
  else if Option.is_some entry.merchant then Error "merchant-classification"
  else if paid_by_entry then Error "scheduled-fulfillment"
  else if has_separator entry.day then Error "date-transport"
  else if Option.value_map entry.memo ~default:false ~f:(fun s -> String.is_empty s || has_separator s) then Error "memo-transport"
  else if List.exists entry.effects ~f:(fun e -> Option.is_some (D.Effect.key e)) then
    Error "keyed-effects-not-qualified"
  else
    match entry.effects with
    | [] -> Error "empty-effects"
    | first :: _ ->
        let measure = D.Effect.measure first in
        if not (List.for_all entry.effects ~f:(fun e ->
            D.Identifier.Measure.equal (D.Effect.measure e) measure)) then
          Error "multiple-measures"
        else if List.exists entry.effects ~f:(fun e ->
            Z.equal (D.Quantity.quanta (D.Effect.quantity e)) Z.zero) then
          Error "zero-posting"
        else
          let total =
            List.fold entry.effects ~init:Z.zero ~f:(fun acc e ->
                Z.add acc (D.Quantity.quanta (D.Effect.quantity e)))
          in
          if not (Z.equal total Z.zero) then Error "unbalanced"
          else
            let effect_lines =
              List.map entry.effects ~f:(fun e ->
                  String.concat ~sep:"\t"
                    [ "effect"; "-";
                      D.Identifier.Locus.to_string (D.Effect.locus e);
                      D.Identifier.Measure.to_string (D.Effect.measure e);
                      Z.to_string (D.Quantity.quanta (D.Effect.quantity e)) ])
            in
            let header =
              [ "LOAM-MOVEMENT-PROPOSAL\t2";
                "operation\t" ^ operation;
                "date\t" ^ entry.day ]
            in
            let memo = Option.value_map entry.memo ~default:[] ~f:(fun m -> ["description\t" ^ m]) in
            Ok (String.concat ~sep:"\n" (header @ memo @ effect_lines) ^ "\n")

let refusal = function Ok _ -> "UNEXPECTED ACCEPT" | Error reason -> reason

let%expect_test "Bakhlo canonical ordinary entry has a bounded LOAM proposal shape" =
  let book, entry = canonical_trial () in
  (match proposal_shape ~operation:"bakhlo-return-e1" book entry with
   | Error why -> Stdio.printf "refused: %s\n" why
   | Ok proposal -> Stdio.print_string proposal);
  [%expect {|
    LOAM-MOVEMENT-PROPOSAL	2
    operation	bakhlo-return-e1
    date	2026-10-03
    description	groceries
    effect	-	wallet	jpy	-120
    effect	-	food	jpy	120
  |}]

let%expect_test "loss-bearing special facts never degrade to ordinary Movement" =
  let book, entry = canonical_trial () in
  let check label e =
    Stdio.printf "%s: %s\n" label (refusal (proposal_shape ~operation:"bakhlo-return-e1" book e))
  in
  check "reversal" { entry with reversal_of = Some "original" };
  check "exchange" { entry with exchange = Some ("from", "to") };
  check "original amount" { entry with original_amount = Some ("eur", Z.of_int 150) };
  check "merchant" { entry with merchant = Some Bakhlo_application.Event_merchants.Nonmerchant };
  check "mixed measures"
    { entry with effects =
        [ List.hd_exn entry.effects;
          D.Effect.create
            ~locus:(identifier D.Identifier.Locus.of_string "food")
            ~measure:(identifier D.Identifier.Measure.of_string "eur")
            ~quantity:(D.Quantity.of_quanta (Z.of_int 120)) ~key:None ] };
  check "unbalanced" { entry with effects = [posting "wallet" (-100); posting "food" 120] };
  check "embedded newline" { entry with memo = Some "hello\nworld" };
  check "empty description" { entry with memo = Some "" };
  Stdio.printf "bad operation: %s\n" (refusal (proposal_shape ~operation:"" book entry));
  [%expect {|
    reversal: reversal-relation
    exchange: exchange-evidence
    original amount: original-amount
    merchant: merchant-classification
    mixed measures: multiple-measures
    unbalanced: unbalanced
    embedded newline: memo-transport
    empty description: memo-transport
    bad operation: operation-token
  |}]
