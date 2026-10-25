(* book.txt -> Daily_book -> book.txt is the identity, the Daily_book in between
   answers like the book.txt value through a separate implementation (entries, plans
   and every current quantity), and what book.txt cannot represent refuses. *)
module X = Bakhlo_sexp.Daily_txt
module T = Bakhlo_book_txt.Book_txt
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query
module M = Bakhlo_application.Event_merchants

let read path = In_channel.with_open_bin path In_channel.input_all
let locus = D.Identifier.Locus.to_string
let measure = D.Identifier.Measure.to_string

(* The book's entries, plans and current quantities against the book.txt value, read
   through Daily_book's own query and Book_txt.balance. *)
let answers_agree book (t : T.t) =
  let entry_equal (e : B.entry) (tx : T.tx) =
    List.length e.effects = List.length tx.effects
    && List.for_all2
         (fun p (q : T.posting) ->
           locus (D.Effect.locus p) = q.locus
           && measure (D.Effect.measure p) = q.measure
           && Z.equal (D.Quantity.quanta (D.Effect.quantity p)) q.amount
           && Option.map D.Identifier.Effect_key.to_string (D.Effect.key p) = q.key)
         e.effects tx.effects
    && e.id = tx.id && e.day = tx.day && e.memo = tx.memo && e.reversal_of = tx.reversal_of
    && e.original_amount = tx.original
    && Option.map
         (function M.Merchant p -> Some (D.Identifier.External_party.to_string p) | M.Nonmerchant -> None)
         e.merchant
       = Option.map (function T.Merchant s -> Some s | T.Nonmerchant -> None) tx.merchant
    && Option.is_some e.exchange = Option.is_some tx.exchange
  in
  let plan_equal (p : B.plan) (q : T.plan) =
    let ending =
      match q.ending with
      | Some (T.Paid_by t) -> (Some t, None)
      | Some (T.Cancelled d) -> (None, Some d)
      | None -> (None, None)
    in
    p.id = q.id && p.day = q.day && p.measure = q.measure && p.changes = q.changes
    && (p.paid_by, p.cancelled_on) = ending
  in
  let same_length a b = List.length a = List.length b in
  let coordinates =
    List.concat_map (fun (tx : T.tx) -> List.map (fun (e : T.posting) -> (e.locus, e.measure)) tx.effects) t.txs
    @ t.zero_origins @ List.map fst t.openings @ List.map fst t.history_from
    @ List.concat_map (fun (a : T.anchor) -> List.map fst a.asserts) t.anchors
    |> List.sort_uniq compare
  in
  let quantity (l, m) =
    let c : D.Effect_coordinate.t =
      { locus = Result.get_ok (D.Identifier.Locus.of_string l); measure = Result.get_ok (D.Identifier.Measure.of_string m) }
    in
    match (Q.query (B.image book) c, T.balance t ~locus:l ~measure:m) with
    | Ok (Q.Exact x), T.Known b -> Z.equal (D.Quantity.quanta (Q.quantity x)) b
    | Error (Q.Support_unknown _), T.Unknown -> true
    | _ -> false
  in
  same_length (B.entries book) t.txs
  && List.for_all2 entry_equal (B.entries book) t.txs
  && same_length (B.plans book) t.plans
  && List.for_all2 plan_equal (B.plans book) t.plans
  && List.for_all quantity coordinates

let round_trip text =
  match T.of_string text with
  | Error e -> Error (Printf.sprintf "not admitted: %s at %d" (T.code_name e.code) e.line)
  | Ok t -> (
      match X.of_txt t with
      | Error why -> Error ("of_txt: " ^ why)
      | Ok (book, sidecars) -> (
          if not (answers_agree book t) then Error "answers differ"
          else
            match X.to_txt book sidecars with
            | Error why -> Error ("to_txt: " ^ why)
            | Ok back -> if T.to_string back = text then Ok () else Error "reprinted text differs"))

let%expect_test "every accepted fixture survives Daily_book unchanged" =
  List.iter
    (fun name ->
      let result = round_trip (read (Filename.concat "common_format" name)) in
      Printf.printf "%s: %s\n" name (match result with Ok () -> "same bytes, same answers" | Error why -> why))
    [ "ok-empty.txt"; "ok-full.txt"; "ok-anchor-delta.txt"; "ok-anchor-start.txt"; "ok-exchange-reversal.txt" ];
  [%expect {|
    ok-empty.txt: same bytes, same answers
    ok-full.txt: same bytes, same answers
    ok-anchor-delta.txt: same bytes, same answers
    ok-anchor-start.txt: same bytes, same answers
    ok-exchange-reversal.txt: same bytes, same answers
    |}]

let%expect_test "generated books survive Daily_book unchanged" =
  let checks = ref 0 and failures = ref [] in
  Base_quickcheck.Test.run_exn
    (module Book_txt_tests.Generated)
    ~config:{ Base_quickcheck.Test.default_config with seed = Deterministic "daily-txt-v1"; test_count = 2_000 }
    ~f:(fun t ->
      incr checks;
      match round_trip (T.to_string t) with
      | Ok () -> ()
      | Error why -> if List.length !failures < 3 then failures := why :: !failures);
  Printf.printf "%d generated books; failures: %s\n" !checks
    (match !failures with [] -> "none" | fs -> String.concat " | " (List.rev fs));
  [%expect {| 2000 generated books; failures: none |}]

let%expect_test "what book.txt cannot represent refuses instead of disappearing" =
  let t = Result.get_ok (T.of_string (read "common_format/ok-full.txt")) in
  let book, sidecars = Result.get_ok (X.of_txt t) in
  let show label book sidecars =
    Printf.printf "%s: %s\n" label (match X.to_txt book sidecars with Ok _ -> "converted" | Error why -> why)
  in
  let p = B.export_payload book in
  (* A coordinate with no support of its own, observed after every entry. *)
  let supported =
    t.zero_origins @ List.map fst t.openings @ List.concat_map (fun (a : T.anchor) -> List.map fst a.asserts) t.anchors
  in
  let l, m =
    List.find
      (fun c -> not (List.mem c supported))
      (List.concat_map (fun (l : T.locus) -> List.map (fun (m, _) -> (l.id, m)) t.measures) t.loci)
  in
  let presence : Q.presence =
    {
      reflected_roots = List.map (fun (tx : T.tx) -> Result.get_ok (D.Identifier.Event.of_string tx.id)) t.txs;
      coordinates = [ { locus = Result.get_ok (D.Identifier.Locus.of_string l); measure = Result.get_ok (D.Identifier.Measure.of_string m) } ];
    }
  in
  (match B.of_payload { p with presence = Some presence } with
  | Ok with_presence -> show "presence" with_presence sidecars
  | Error why -> Printf.printf "presence: not admitted by Daily_book (%s)\n" why);
  show "roles header" book { sidecars with roles = "ROLE\tbank\tASSET\n" };
  show "suspense role" book { sidecars with roles = sidecars.roles ^ "ROLE\tsuspense\tASSET\n" };
  show "attention header" book { sidecars with attention = "ITEM\tx\tNO_DUE_DATE\t-\tc\n" };
  [%expect {|
    presence: presence
    roles header: accounting-roles-bad-header
    suspense role: book-txt-suspense-role-line-26
    attention header: attention-bad-header
    |}]

(* book.txt names an exchange by its Measures; an exchange with a second positive
   Effect in its destination Measure cannot be read back as the same entry, so it is
   refused by the whole conversion and by a save instead of being written. *)
let%expect_test "an exchange book.txt cannot read back is refused, never written" =
  let t = Result.get_ok (T.of_string (read "common_format/ok-full.txt")) in
  let book, sidecars = Result.get_ok (X.of_txt t) in
  let leg ?key l m q =
    D.Effect.create
      ~key:(Option.map (fun k -> Result.get_ok (D.Identifier.Effect_key.of_string k)) key)
      ~locus:(Result.get_ok (D.Identifier.Locus.of_string l))
      ~measure:(Result.get_ok (D.Identifier.Measure.of_string m))
      ~quantity:(D.Quantity.of_quanta (Z.of_int q))
  in
  let entry : B.entry =
    {
      id = "fx-extra";
      day = "2027-02-01";
      memo = None;
      effects =
        [ leg ~key:"s" "wallet" "jpy" (-1500); leg ~key:"d" "wallet" "usd" 1000; leg "food" "usd" 50; leg "fee" "usd" (-50) ];
      reversal_of = None;
      exchange = Some ("s", "d");
      original_amount = None;
      merchant = None;
    }
  in
  let op = Bakhlo_sexp.Book_log.Put_entry { replace = false; entry; plan = None } in
  match B.put_entry book ~replace:false entry ~plan:None with
  | Error why -> Printf.printf "Daily_book refused: %s\n" why
  | Ok after ->
      Printf.printf "whole conversion: %s\n" (match X.to_txt after sidecars with Ok _ -> "written" | Error why -> why);
      let txt = Result.get_ok (T.read (T.to_string t)) in
      Printf.printf "save: %s\n" (match X.changes txt after [ op ] with Ok _ -> "written" | Error why -> why);
      [%expect {|
        whole conversion: exchange-ambiguous
        save: exchange-ambiguous
        |}]
