open Base
module M = Discharge_model

let require condition = if not condition then failwith "independent discharge counterexample"
let f event target quantity : M.fact = { event; target; quantity = Z.of_int quantity }

let%expect_test
    "independent discharge model preserves partial amounts, pair identity and target-local totals" =
  let shapes = M.shapes () in
  let count = List.count shapes ~f:(M.admitted M.events M.targets) in
  require (List.length shapes = 5776 && count = 109);
  require (M.admitted M.events M.targets [ f "c" "r" 1; f "d" "r" 1 ]);
  require (not (M.admitted M.events M.targets [ f "c" "r" 1; f "c" "r" 1 ]));
  require (M.admitted M.events M.targets [ f "c" "r" 2; f "c" "q" 2 ]);
  require (not (M.admitted M.events M.targets [ f "c" "r" 2; f "d" "r" 1 ]));
  require (not (M.admitted M.events M.targets [ f "a" "r" 1 ]));
  require (not (M.admitted M.events M.targets [ f "missing" "r" 1 ]));
  require (not (M.admitted M.events M.targets [ f "c" "unknown" 1 ]));
  require (Option.equal Z.equal (M.remaining M.targets [] "r") (Some (Z.of_int 2)));
  require (Option.equal Z.equal (M.remaining M.targets [ f "c" "r" 1 ] "r") (Some Z.one));
  require (Option.equal Z.equal (M.remaining M.targets [ f "c" "r" 2 ] "r") (Some Z.zero));
  require (Option.is_none (M.remaining M.targets [] "unknown"));
  Stdlib.Printf.printf
    "5776 two-slot original discharges: 109 admitted; partial/full/no-row/unknown, duplicate \
     correspondence != independent target, closure/self/aggregate counterexamples\n";
  [%expect
    {| 5776 two-slot original discharges: 109 admitted; partial/full/no-row/unknown, duplicate correspondence != independent target, closure/self/aggregate counterexamples |}]
