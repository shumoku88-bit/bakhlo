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
  [%expect {| 4 admitted, 58 refused, 0 failures |}]

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
                            List.map
                              (fun (locus, q) : B.posting -> { locus; measure = "jpy"; amount = Z.of_int q })
                              lines
                          in
                          let total = List.fold_left (fun s (_, q) -> s + q) 0 lines in
                          ({
                             id = Printf.sprintf "tx-%03d" i;
                             day = Printf.sprintf "2027-%02d-%02d" (1 + (i mod 12)) (1 + (i mod 28));
                             memo;
                             effects = effects @ [ { locus = "wallet"; measure = "jpy"; amount = Z.of_int (-total) } ];
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
