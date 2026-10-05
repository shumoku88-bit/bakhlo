open Base
module M = Exchange_model

let require condition message = if not condition then failwith message
let change key measure quantity : M.change = { key; measure; quanta = Z.of_int quantity }

let%expect_test
    "independent Exchange model separates selected signs, Measure totals and source nonzero policy"
    =
  let shapes = M.shapes () in
  let exchanged = List.count shapes ~f:(fun changes -> M.admitted changes M.selected) in
  let sourced =
    List.count shapes ~f:(fun changes -> M.admitted changes M.selected && M.nonzero changes)
  in
  let ordinary = List.count shapes ~f:M.ordinary in
  require
    (List.length shapes = 9216 && exchanged = 122 && sourced = 74 && ordinary = 80)
    "finite model counts";
  let source = change (Some "source") "jpy" (-1)
  and destination = change (Some "destination") "usd" 1 in
  require
    (M.admitted [ source; destination; change None "jpy" (-2) ] M.selected)
    "additional source-side effects allowed";
  require
    (M.admitted [ source; destination; change None "usd" 0 ] M.selected
    && not (M.nonzero [ source; destination; change None "usd" 0 ]))
    "Exchange selection does not erase source zero policy";
  require
    (not (M.admitted [ source; destination; change None "jpy" 1 ] M.selected))
    "selected negative alone does not justify source net zero";
  require
    (not (M.admitted [ source; destination; change None "usd" (-2) ] M.selected))
    "selected positive alone does not justify destination net negative";
  require
    (not (M.admitted [ source; destination; change None "eur" 0 ] M.selected))
    "third Measure cannot disappear even at zero";
  require
    (not (M.admitted [ change None "jpy" (-1); destination ] M.selected))
    "anonymous coordinate is not selected key";
  require
    (not
       (M.admitted
          [ change (Some "source") "jpy" 1; destination; change None "jpy" (-2) ]
          M.selected))
    "negative total does not repair positive selected source";
  Stdlib.Printf.printf
    "9216 list/Measure/sign/extra shapes; 122 Exchange, 74 nonzero source, 80 \
     ordinary-without-claim admissions\n";
  [%expect
    {| 9216 list/Measure/sign/extra shapes; 122 Exchange, 74 nonzero source, 80 ordinary-without-claim admissions |}]
