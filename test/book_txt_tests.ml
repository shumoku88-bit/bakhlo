(* Book_txt against the shared conformance fixtures (test/common_format, see
   docs/COMMON_FORMAT.ja.md) and a generated print/read round trip. *)
module B = Bakhlo_book_txt.Book_txt
open B

let read path = In_channel.with_open_bin path In_channel.input_all
let rows text = List.filter (fun l -> l <> "") (String.split_on_char '\n' text)

let%expect_test "every conformance fixture is admitted or refused exactly as listed" =
  let cases = List.tl (rows (read "common_format/cases.tsv")) in
  let failures = ref 0 and accepted = ref 0 and refused = ref 0 in
  let fail name why =
    incr failures;
    Printf.printf "FAIL %s: %s\n" name why
  in
  List.iter
    (fun row ->
      match String.split_on_char '\t' row with
      | [ name; expect; line; _note ] -> (
          let data = read (Filename.concat "common_format" name) in
          match (B.of_string data, expect) with
          | Ok book, "ok" ->
              incr accepted;
              if B.to_string book <> data then fail name "reprinted text differs";
              let answers = Filename.concat "common_format" (Filename.chop_suffix name ".txt" ^ ".answers") in
              List.iter
                (fun a ->
                  match String.split_on_char '\t' a with
                  | [ "BALANCE"; locus; measure; want ] ->
                      let got =
                        match B.balance book ~locus ~measure with
                        | B.Known q -> Z.to_string q
                        | B.Unknown -> "UNKNOWN"
                      in
                      if got <> want then fail name (Printf.sprintf "%s %s: want %s, got %s" locus measure want got)
                  | _ -> fail name ("bad answers row: " ^ a))
                (rows (read answers))
          | Ok _, code -> fail name ("admitted, expected " ^ code)
          | Error e, "ok" -> fail name (Printf.sprintf "refused %s at %d" (B.code_name e.code) e.line)
          | Error e, code ->
              incr refused;
              if B.code_name e.code <> code || string_of_int e.line <> line then
                fail name (Printf.sprintf "want %s at %s, got %s at %d" code line (B.code_name e.code) e.line))
      | _ -> fail row "bad cases row")
    cases;
  Printf.printf "%d admitted, %d refused, %d failures\n" !accepted !refused !failures;
  [%expect {| 5 admitted, 59 refused, 0 failures |}]

(* Generated admissible books: balanced jpy TXs with awkward memos, optional
   Merchant and ORIGINAL, plans, and one anchor with ALSO lines after its pointer. *)
module Generated = struct
  type t = B.t

  let sexp_of_t t = Base.Sexp.Atom (B.to_string t)
  let quickcheck_shrinker = Base_quickcheck.Shrinker.atomic

  let quickcheck_generator =
    let open Base_quickcheck.Generator in
    let pieces = [ "a"; "パン"; "\\"; "\t"; "\n"; "\r"; " "; "-"; "\\t"; "x\\n" ] in
    let memo =
      bind (int_inclusive 1 4) ~f:(fun length ->
          map (list_with_length (of_list pieces) ~length) ~f:(String.concat ""))
    in
    let spends = [ "food"; "fee"; "phone" ] in
    let tx i =
      bind (int_inclusive 1 3) ~f:(fun count ->
          bind (list_with_length (both (of_list spends) (int_inclusive 1 9999)) ~length:count) ~f:(fun lines ->
              bind (option memo) ~f:(fun memo ->
                  bind (int_inclusive 0 2) ~f:(fun m ->
                      map (option (int_inclusive 1 500)) ~f:(fun original ->
                          let effects =
                            List.mapi
                              (fun j (locus, q) : B.posting ->
                                {
                                  locus;
                                  measure = "jpy";
                                  amount = Z.of_int q;
                                  key = (if q mod 7 = 0 then Some (Printf.sprintf "k%d" j) else None);
                                })
                              lines
                          in
                          let total = List.fold_left (fun s (_, q) -> s + q) 0 lines in
                          ({
                             id = Printf.sprintf "tx-%03d" i;
                             day = Printf.sprintf "2027-%02d-%02d" (1 + (i mod 12)) (1 + (i mod 28));
                             memo;
                             effects = effects @ [ { locus = "wallet"; measure = "jpy"; amount = Z.of_int (-total); key = Some "paid-from" } ];
                             reversal_of = None;
                             original = Option.map (fun q -> ("usd", Z.of_int q)) original;
                             merchant = (match m with 0 -> None | 1 -> Some (B.Merchant "shop-1") | _ -> Some B.Nonmerchant);
                             exchange = None;
                           }
                            : B.tx))))))
    in
    bind (int_inclusive 0 12) ~f:(fun count ->
        bind (all (List.init count tx)) ~f:(fun txs ->
            bind (int_inclusive (-1) (count - 1)) ~f:(fun pointer ->
                bind (list_with_length bool ~length:count) ~f:(fun picks ->
                    map (int_inclusive (-5000) 5000) ~f:(fun counted ->
                        let ids = List.map (fun (tx : B.tx) -> tx.id) txs in
                        let also = List.filteri (fun i _ -> i > pointer + 1 && List.nth picks i) ids in
                        let plans : B.plan list =
                          List.filteri (fun i _ -> i mod 3 = 0) ids
                          |> List.mapi (fun j id : B.plan ->
                                 {
                                   id = Printf.sprintf "plan-%d" j;
                                   day = "2027-06-01";
                                   measure = "jpy";
                                   changes = [ ("wallet", Z.of_int (-100)); ("phone", Z.of_int 100) ];
                                   ending = (if j mod 2 = 0 then Some (B.Paid_by id) else Some (B.Cancelled "2027-05-01"));
                                 })
                        in
                        let locus id label : B.locus = { id; label; help = ""; hidden = false } in
                        {
                          B.measures = [ ("jpy", 0); ("usd", 2) ];
                          loci = [ locus "wallet" "財布"; locus "food" "食費"; locus "fee" "手数料"; locus "phone" "電話" ];
                          roles = [ ("wallet", B.Asset); ("food", B.Expense) ];
                          txs;
                          plans;
                          zero_origins = [ ("food", "jpy") ];
                          openings = [];
                          history_from = (if txs = [] then [] else [ (("wallet", "jpy"), "2027-01-01") ]);
                          anchors =
                            (if txs = [] then []
                             else [ { last = (if pointer < 0 then None else Some (List.nth ids pointer)); also; asserts = [ (("wallet", "jpy"), Z.of_int counted) ] } ]);
                          items = [ { id = "attention-1"; due = B.Due_on "2027-02-28"; context = "check\tthis" } ];
                          closes = [];
                        })))))
end

let%expect_test "generated books print, read back equal and reprint to the same bytes" =
  let checks = ref 0 in
  Base_quickcheck.Test.run_exn
    (module Generated)
    ~config:{ Base_quickcheck.Test.default_config with seed = Deterministic "book-txt-v1"; test_count = 10_000 }
    ~f:(fun book ->
      incr checks;
      let text = B.to_string book in
      match B.of_string text with
      | Ok back ->
          if back <> book then failwith ("read back differs:\n" ^ text);
          if B.to_string back <> text then failwith "reprint differs"
      | Error e -> failwith (Printf.sprintf "refused %s at %d:\n%s" (B.code_name e.code) e.line text));
  Printf.printf "%d generated books round-tripped\n" !checks;
  [%expect {| 10000 generated books round-tripped |}]

(* Changes against the whole-file reader: from a generated book, random batches of
   changes (valid and invalid: duplicate and unknown IDs, unbalanced or non-inverse
   reversals, reused reversal endpoints, unknown Loci, dropped Loci, bad tokens,
   anchors and Attention) are admitted by [B.change] exactly when the changed value
   prints to a text the whole-file reader admits as that same value; then [B.print]
   is that text. Each admitted batch is the start of the next. *)
let posting ?key locus amount : B.posting = { locus; measure = "jpy"; amount = Z.of_int amount; key }

let pick xs s = List.nth xs (s mod List.length xs)

let change_of (v : B.t) s : B.change =
  let ids = List.map (fun (tx : B.tx) -> tx.id) v.txs in
  let some_tx () = List.find (fun (tx : B.tx) -> tx.id = pick ids (s / 13)) v.txs in
  let fresh = Printf.sprintf "new-%d" s in
  let plain id day effects : B.tx =
    { id; day; memo = None; effects; reversal_of = None; original = None; merchant = None; exchange = None }
  in
  let spend locus q = [ posting locus q; posting "wallet" (-q) ] in
  let inverse (tx : B.tx) = List.rev_map (fun (e : B.posting) -> { e with amount = Z.neg e.amount }) tx.effects in
  match s mod 14 with
  | 0 | 1 -> Add_tx (plain fresh "2027-03-01" (spend (pick [ "food"; "fee"; "phone"; "nowhere" ] (s / 7)) (1 + (s mod 900))))
  | 2 when ids <> [] -> Add_tx (plain (pick ids s) "2027-03-02" (spend "food" 5))
  | 3 when ids <> [] -> Add_tx { (plain fresh "2027-03-03" (inverse (some_tx ()))) with reversal_of = Some (some_tx ()).id }
  | 4 when ids <> [] ->
      Add_tx { (plain fresh "2027-03-04" (spend "fee" 3)) with reversal_of = Some (pick (ids @ [ "missing" ]) s) }
  | 5 when ids <> [] ->
      let tx = some_tx () in
      Replace_tx { tx with day = "2027-04-05"; memo = Some "fixed"; effects = spend "phone" (2 + (s mod 50)) }
  | 6 when ids <> [] ->
      let tx = some_tx () in
      Replace_tx
        (match s / 7 mod 4 with
        | 0 -> { tx with effects = [ posting "food" 10; posting "wallet" (-9) ] }
        | 1 -> { tx with effects = [ posting "food" 0; posting "wallet" 0 ] }
        | 2 -> { tx with day = "2027-02-30" }
        | _ -> { tx with effects = [ posting "fo od" 1; posting "wallet" (-1) ] })
  | 7 when ids <> [] && s mod 5 = 0 ->
      let tx = some_tx () in
      Replace_tx { tx with effects = [ posting "food" 5; posting "food" (-5) ]; reversal_of = Some tx.id; exchange = None }
  | 7 when ids <> [] ->
      let tx = some_tx () in
      let target = List.find (fun (t : B.tx) -> t.id = pick ids (s / 3)) v.txs in
      Replace_tx { tx with effects = inverse target; reversal_of = Some target.id; exchange = None }
  | 8 ->
      let p : B.plan =
        {
          id = pick [ "plan-0"; "plan-1"; fresh ] s;
          day = "2027-07-01";
          measure = "jpy";
          changes = [ ("wallet", Z.of_int (-7)); (pick [ "phone"; "nowhere" ] (s / 5), Z.of_int 7) ];
          ending = (if s mod 3 = 0 && ids <> [] then Some (Paid_by (pick ids s)) else None);
        }
      in
      Put_plan p
  | 9 -> (
      match s / 7 mod 3 with
      | 0 -> Set_loci (v.loci @ [ { id = "travel"; label = "旅行"; help = ""; hidden = s mod 2 = 0 } ])
      | 1 -> Set_loci (List.filteri (fun i _ -> i <> s mod List.length v.loci) v.loci)
      | _ -> Set_loci (List.map (fun (l : B.locus) -> { l with label = (if s mod 5 = 0 then "" else l.label ^ "!") }) v.loci))
  | 10 -> (
      match (s / 7 mod 4, v.anchors) with
      | 3, _ -> Set_anchors [ { last = Some "-"; also = []; asserts = [ (("wallet", "jpy"), Z.of_int 5) ] } ]
      | 0, a :: rest -> Set_anchors ({ a with asserts = List.map (fun (c, _) -> (c, Z.of_int s)) a.asserts } :: rest)
      | 1, _ -> Set_anchors []
      | _, _ ->
          Set_anchors
            [ { last = (if ids = [] then None else Some (pick ids s)); also = (if ids = [] then [] else [ pick ids (s / 11) ]); asserts = [ (("wallet", "jpy"), Z.of_int 5) ] } ])
  | 11 ->
      Set_attention
        ( v.items @ [ { id = fresh; due = No_due_date; context = "later" } ],
          v.closes @ [ { item = pick [ "attention-1"; "missing"; fresh ] s; day = "2027-08-01"; kind = Dropped } ] )
  | 12 -> Set_roles (v.roles @ [ (pick [ "phone"; "wallet"; "nowhere" ] s, B.Expense) ])
  | _ -> Replace_tx (plain "missing" "2027-01-01" (spend "food" 1))

(* The value the changes describe, without any check; [None] if a TX to replace is missing. *)
let raw_apply (v : B.t) changes =
  List.fold_left
    (fun v change ->
      Option.bind v (fun (v : B.t) ->
          match (change : B.change) with
          | Add_tx tx -> Some { v with txs = v.txs @ [ tx ] }
          | Replace_tx tx ->
              if List.exists (fun (t : B.tx) -> t.id = tx.id) v.txs then
                Some { v with txs = List.map (fun (t : B.tx) -> if t.id = tx.id then tx else t) v.txs }
              else None
          | Put_plan p ->
              Some
                {
                  v with
                  plans =
                    (if List.exists (fun (q : B.plan) -> q.id = p.id) v.plans then
                       List.map (fun (q : B.plan) -> if q.id = p.id then p else q) v.plans
                     else v.plans @ [ p ]);
                }
          | Set_loci loci -> Some { v with loci }
          | Set_roles roles -> Some { v with roles }
          | Set_anchors anchors -> Some { v with anchors }
          | Set_attention (items, closes) -> Some { v with items; closes }))
    (Some v) changes

let%expect_test "a change is admitted exactly when the whole file would admit its result" =
  let admitted = ref 0 and refused = ref 0 in
  Base_quickcheck.Test.run_exn
    (module struct
      type t = B.t * int list

      let sexp_of_t (book, seeds) =
        Base.Sexp.List (Base.Sexp.Atom (B.to_string book) :: List.map (fun s -> Base.Sexp.Atom (string_of_int s)) seeds)

      let quickcheck_shrinker = Base_quickcheck.Shrinker.atomic

      let quickcheck_generator =
        Base_quickcheck.Generator.(
          both Generated.quickcheck_generator (list_with_length (int_inclusive 0 1_000_000) ~length:12))
    end)
    ~config:{ Base_quickcheck.Test.default_config with seed = Deterministic "book-txt-change"; test_count = 3_000 }
    ~f:(fun (start, seeds) ->
      let book = ref (Result.get_ok (B.read (B.to_string start))) in
      let rec batches = function
        | [] -> ()
        | s :: rest ->
            let changes, rest =
              if s mod 3 = 0 then match rest with t :: rest -> ([ s; t ], rest) | [] -> ([ s ], [])
              else ([ s ], rest)
            in
            let before = B.value !book in
            let changes = List.map (change_of before) changes in
            let expected =
              match raw_apply before changes with
              | None -> None
              | Some raw -> ( match B.of_string (B.to_string raw) with Ok back when back = raw -> Some raw | _ -> None)
            in
            (match (B.change !book changes, expected) with
            | Ok after, Some raw ->
                incr admitted;
                if B.value after <> raw then failwith "admitted a different value";
                if B.print after <> B.to_string raw then failwith "printed text differs";
                book := after
            | Error _, None -> incr refused
            | Ok _, None ->
                let why =
                  match raw_apply before changes with
                  | None -> "a missing TX"
                  | Some raw -> (
                      match B.of_string (B.to_string raw) with
                      | Error e -> Printf.sprintf "%s at line %d" (B.code_name e.code) e.line
                      | Ok _ -> "a different value")
                in
                failwith (Printf.sprintf "admitted seeds %s, which the whole file refuses with %s"
                  (String.concat " " (List.map string_of_int (List.filteri (fun i _ -> i < List.length changes) (s :: rest)))) why)
            | Error why, Some _ -> failwith ("refused (" ^ why ^ ") what the whole file admits:\n" ^ B.to_string before));
            batches rest
      in
      batches seeds);
  Printf.printf "agreed with the whole-file reader: %b admitted, %b refused\n" (!admitted > 5000) (!refused > 5000);
  [%expect {| agreed with the whole-file reader: true admitted, true refused |}]
