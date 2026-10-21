open Base
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module I = Bakhlo_migrate.Loam_import

let print_endline = Stdlib.print_endline

(* Tiny synthetic LOAM household; ASCII bodies so the byte count is the scalar count. *)
let household ?(actual_rows = []) ?(attention = true) () =
  let lines rows = String.concat ~sep:"" (List.map rows ~f:(fun row -> row ^ "\n")) in
  let actual =
    lines
      ([
         "LOAM-NORMALIZED-ACTUAL\t4";
         "TX\ta\t2026-10-03\tDESC\tbefore";
         "MERCHANT\tshop";
         "ORIGINAL-AMOUNT\tusd\t100";
         "EFFECT\twallet\tjpy\t-150";
         "EFFECT\tfood\tjpy\t150";
         "ENDTX";
         "TX\tb\t2026-10-04\tDESC\tafter";
         "REPLACES\ta";
         "EFFECT\twallet\tjpy\t-160";
         "EFFECT\tfood\tjpy\t160";
         "ENDTX";
         "TX\te\t2026-10-05\tNODESC";
         "NONMERCHANT";
         "EXCHANGE\tfrom\tto";
         "KEYED-EFFECT\tfrom\twallet\tjpy\t-300";
         "KEYED-EFFECT\tto\twallet\tusd\t200";
         "ENDTX";
         "TX\tx\t2026-10-06\tNODESC";
         "REVERSAL-OF\tb";
         "EFFECT\twallet\tjpy\t160";
         "EFFECT\tfood\tjpy\t-160";
         "ENDTX";
       ]
      @ actual_rows)
  in
  let inner name rows = lines ((("BEGIN\t" ^ name) :: rows) @ [ "END\t" ^ name ]) in
  let plan id day =
    [ "SCHEDULED\t" ^ id ^ "\t" ^ day ^ "\tjpy"; "CHANGE\twallet\t-20"; "CHANGE\tfood\t20" ]
  in
  let scheduled =
    "LOAM-SCHEDULED-LIFECYCLE\t1\n"
    ^ inner "Scheduled"
        (("LOAM-SCHEDULED-MEMORY\t1" :: plan "paid" "2026-10-03")
        @ plan "retired" "2026-10-07" @ plan "old" "2026-10-08" @ plan "new" "2026-10-09")
    ^ inner "Completion" [ "LOAM-SCHEDULED-COMPLETION-MEMORY\t1"; "COMPLETION\tpaid\tb" ]
    ^ inner "Retirement" [ "LOAM-SCHEDULED-RETIREMENT-MEMORY\t1"; "RETIREMENT\tretired" ]
    ^ inner "Replacement" [ "LOAM-SCHEDULED-REPLACEMENT-MEMORY\t1"; "REPLACEMENT\told\tnew" ]
  in
  let sections =
    [
      ("Actual", actual);
      ("Scheduled", scheduled);
      ("ZeroOrigin", "LOAM-ZERO-ORIGIN-COVERAGE\t1\nCOORDINATE\tfood\tjpy\n");
      ("OpeningSupport", "LOAM-OPENING-SUPPORT\t1\n");
      ( "CurrentQuantityAnchor",
        "LOAM-CURRENT-QUANTITY-ANCHOR\t2\nGROUP\nASSERT\twallet\tjpy\t1000\nEND\n" );
      ("CurrentQuantityPresence", "LOAM-CURRENT-QUANTITY-PRESENCE\t1\n");
      ( "BoundedHistorySupport",
        "LOAM-BOUNDED-HISTORY-SUPPORT\t1\nSUPPORT\twallet\tjpy\t2026-10-01\n" );
      ("LocusAdmission", "LOAM-LOCUS-ADMISSION-VOCABULARY\t1\nLOCUS\twallet\nLOCUS\tfood\n");
      ("Capacity", "LOAM-NORMALIZED-CAPACITY\t1\n");
    ]
    @
    if attention then
      [ ("Attention", "LOAM-ATTENTION-MEMORY\t1\nITEM\tt1\tNO_DUE_DATE\t-\tcheck\n") ]
    else []
  in
  "LOAM-HOUSEHOLD-IMAGE\t2\n"
  ^ String.concat ~sep:""
      (List.map sections ~f:(fun (name, body) ->
           Printf.sprintf "SECTION\t%s\t%d\n%s" name (String.length body) body))

let input ?(measures = "jpy\t0\nusd\t2\n") household : I.input =
  { household; measure_presentation = measures; locus_catalog = None }

let describe (e : B.entry) =
  Printf.sprintf "%s %s memo=%s effects=%s reversal=%s merchant=%s original=%s exchange=%s" e.id
    e.day
    (Option.value ~default:"-" e.memo)
    (String.concat ~sep:","
       (List.map e.effects ~f:(fun p ->
            D.Identifier.Locus.to_string (D.Effect.locus p)
            ^ ":"
            ^ Z.to_string (D.Quantity.quanta (D.Effect.quantity p)))))
    (Option.value ~default:"-" e.reversal_of)
    (match e.merchant with
    | None -> "-"
    | Some Nonmerchant -> "nonmerchant"
    | Some (Merchant p) -> D.Identifier.External_party.to_string p)
    (Option.value_map ~default:"-" e.original_amount ~f:(fun (m, q) -> m ^ ":" ^ Z.to_string q))
    (Option.value_map ~default:"-" e.exchange ~f:(fun (f, t) -> f ^ "->" ^ t))

let%expect_test "import keeps the current state and leaves history in LOAM" =
  (match I.book (input (household ())) with
  | Error why -> print_endline ("refused " ^ why)
  | Ok book -> (
      List.iter (B.entries book) ~f:(fun e -> print_endline (describe e));
      List.iter (B.plans book) ~f:(fun (p : B.plan) ->
          print_endline (p.id ^ " paid=" ^ Option.value ~default:"-" p.paid_by));
      print_endline
        ("bounded="
        ^ Option.value ~default:"-" (B.bounded_history_start book ~locus:"wallet" ~measure:"jpy"));
      print_endline
        ("approved=" ^ String.concat ~sep:"," (Option.value ~default:[] (B.approved_loci book)));
      match B.of_string (B.to_string book) with
      | Ok cold ->
          print_endline
            (if String.equal (B.to_string cold) (B.to_string book) then "cold same"
             else "cold differs")
      | Error why -> print_endline ("cold refused " ^ why)));
  [%expect
    {|
    a 2026-10-04 memo=after effects=wallet:-160,food:160 reversal=- merchant=- original=usd:100 exchange=-
    e 2026-10-05 memo=- effects=wallet:-300,wallet:200 reversal=- merchant=nonmerchant original=- exchange=from->to
    x 2026-10-06 memo=- effects=wallet:160,food:-160 reversal=a merchant=- original=- exchange=-
    paid paid=a
    new paid=-
    bounded=2026-10-01
    approved=wallet,food
    cold same
    |}]

let%expect_test "attention is the section body, or none" =
  let show = function
    | Ok (Some body) -> print_endline (String.escaped body)
    | Ok None -> print_endline "none"
    | Error why -> print_endline ("refused " ^ why)
  in
  show (I.attention (household ()));
  show (I.attention (household ~attention:false ()));
  [%expect {|
    LOAM-ATTENTION-MEMORY\t1\nITEM\tt1\tNO_DUE_DATE\t-\tcheck\n
    none |}]

let%expect_test "unrepresentable input refuses as a whole" =
  let show i =
    print_endline (match I.book i with Ok _ -> "imported" | Error why -> "refused " ^ why)
  in
  (* A Measure without a supplied scale is never defaulted. *)
  show (input ~measures:"jpy\t0\n" (household ()));
  (* Settlement relations have no place in the book. *)
  show
    (input
       (household
          ~actual_rows:
            [
              "TX\ts\t2026-10-07\tNODESC";
              "RELATION\tunit\tSOURCE\tk\thousehold\texternal:p\t10";
              "KEYED-EFFECT\tk\twallet\tjpy\t-10";
              "EFFECT\tfood\tjpy\t10";
              "ENDTX";
            ]
          ()));
  [%expect {|
    refused book-admission
    refused unsupported-settlement-relations |}]
