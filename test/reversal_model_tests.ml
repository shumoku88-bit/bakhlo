open Base
module M = Reversal_model

let require condition = if not condition then failwith "independent Reversal model counterexample"
let c ?(locus = "here") ?(measure = "jpy") n : M.change = { locus; measure; quanta = Z.of_int n }

let%expect_test "independent physical occurrence model enumerates before product correspondence" =
  let words = M.words () in
  let exact = ref 0 and source = ref 0 in
  List.iter words ~f:(fun target ->
      List.iter words ~f:(fun reversal ->
          if M.exact target reversal then (
            Int.incr exact;
            if M.ordinary target && M.ordinary reversal then Int.incr source)));
  let relations = M.relations () in
  let unique = List.count relations ~f:M.unique_endpoints in
  require (List.length words = 85 && !exact = 289 && !source = 9);
  require (List.length relations = 273 && unique = 37);
  (* Total cancellation is strictly weaker than matching physical occurrences. *)
  require (not (M.exact [ c 1; c 1 ] [ c (-2) ]));
  require (not (M.exact [ c 1; c 1 ] [ c (-1) ]));
  require (not (M.exact [ c 1; c (-1) ] []));
  require (not (M.exact [ c 1 ] [ c ~locus:"elsewhere" (-1) ]));
  require (not (M.exact [ c 1 ] [ c ~measure:"usd" (-1) ]));
  require (M.exact [ c 1; c 1; c (-2) ] [ c 2; c (-1); c (-1) ]);
  require (M.exact [ c 1 ] [ c (-1) ] && not (M.ordinary [ c 1 ]));
  require (M.exact [] []);
  require (not (M.unique_endpoints [ (0, 1); (1, 2) ]));
  require (not (M.unique_endpoints [ (0, 1); (1, 0) ]));
  Stdlib.Printf.printf
    "7225 physical pairs: 289 exact, 9 ordinary source; 273 endpoint collections: 37 unique; \
     aggregate/occurrence/coordinate counterexamples retained\n";
  [%expect
    {| 7225 physical pairs: 289 exact, 9 ordinary source; 273 endpoint collections: 37 unique; aggregate/occurrence/coordinate counterexamples retained |}]
