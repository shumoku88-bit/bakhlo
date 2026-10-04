open Base
module M = Relation_model
let require condition = if not condition then failwith "relation model counterexample"
let f ?(id = "r") ?(event = "a") ?(key = "s") ?(debtor = M.Household) ?(creditor = M.External "p") n : M.fact =
  { id; event; key; debtor; creditor; quantity = Z.of_int n }
;;
let%expect_test "independent relation units distinguish source coverage, identities and explicit direction" =
  let shapes = M.shapes () in
  let admitted = List.count shapes ~f:(M.admitted M.sources) in
  require (List.length shapes = 40401 && admitted = 265);
  require (M.admitted M.sources [ f 1; f ~id:"q" 1 ]);
  require (not (M.admitted M.sources [ f 1; f 1 ]));
  require (not (M.admitted M.sources [ f 2; f ~id:"q" ~debtor:(M.External "q") ~creditor:M.Household 1 ]));
  require (M.admitted M.sources [ f 2; f ~id:"q" ~key:"t" 2 ]);
  require (M.admitted M.sources [ f 2; f ~id:"q" ~event:"b" 2 ]);
  require (M.admitted M.sources [ f ~debtor:(M.External "p") ~creditor:M.Household 2 ]);
  require (not (M.admitted M.sources [ f ~event:"missing" 1 ]));
  require (not (M.admitted M.sources [ f ~creditor:M.Household 1 ]));
  require (not (M.admitted M.sources [ f (-1) ]));
  require (M.admitted M.sources []);
  Stdlib.Printf.printf "40401 two-slot original facts: 265 admitted; equal-field independent IDs, same-Effect opposite-direction overcoverage, Event-local keys and explicit roles\n";
  [%expect {| 40401 two-slot original facts: 265 admitted; equal-field independent IDs, same-Effect opposite-direction overcoverage, Event-local keys and explicit roles |}]
;;
