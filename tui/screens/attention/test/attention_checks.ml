(* Suspense never silently stays pending: one derived Attention signal for the
   unresolved holding Locus, and Manage Loci never counts it as unassigned. *)
module B = Bakhlo_household.Daily_book
module D = Bakhlo_domain
module Att = Attention_screen
module Roles = Locus_roles

let get = function Ok x -> x | Error why -> failwith why
let id_of = function Ok value -> value | Error _ -> failwith "synthetic identifier"
let require condition why = if not condition then failwith why
let z = Z.of_int

let posting locus amount =
  D.Effect.create ~key:None
    ~locus:(id_of (D.Identifier.Locus.of_string locus))
    ~measure:(id_of (D.Identifier.Measure.of_string "jpy"))
    ~quantity:(D.Quantity.of_quanta amount)

let entry id day effects : B.entry =
  {
    id;
    day;
    memo = None;
    effects;
    reversal_of = None;
    exchange = None;
    original_amount = None;
    merchant = None;
  }

(* A book.txt with these entries recorded in order and, by default, zero-origin
   support for suspense. *)
let book ?(zero = true) entries =
  let base =
    "BOOK\t1\n\
     MEASURE\tjpy\t0\n\
     MEASURE\teur\t2\n\
     LOCUS\tsuspense\tsuspense\t\n\
     LOCUS\tcash\tcash\t\n\
     LOCUS\tfood\tfood\t\n\
     END\n"
  in
  let recorded =
    List.fold_left
      (fun b e -> get (B.put_entry b ~replace:false e ~plan:None))
      (Bakhlo_household.Daily_txt.book base)
      entries
  in
  if not zero then recorded
  else
    let text = Bakhlo_household.Daily_txt.text recorded in
    Bakhlo_household.Daily_txt.book
      (String.sub text 0 (String.length text - 4)
      ^ "ZERO-ORIGIN\tsuspense\tjpy\nZERO-ORIGIN\tsuspense\teur\nEND\n")

let env ?(roles = [ ("cash", Roles.Asset) ]) book =
  Screen.env_for_checks ~accounting_roles:roles ~book ~measure:"jpy" ~today:"2026-10-22" ()

let contains text needle =
  let length = String.length needle in
  let rec loop index =
    index + length <= String.length text
    && (String.sub text index length = needle || loop (index + 1))
  in
  length = 0 || loop 0

let () =
  (* A non-zero recorded net shows one signal with its count and oldest entry. *)
  let nonzero =
    book
      [
        entry "a" "2026-10-04" [ posting "suspense" (z 500); posting "cash" (z (-500)) ];
        entry "b" "2026-10-10" [ posting "suspense" (z (-100)); posting "food" (z 100) ];
      ]
  in
  let signal = Att.suspense_holding (env nonzero) in
  (match signal with
  | None -> failwith "a non-zero suspense recorded net must show a signal"
  | Some holding ->
      require (holding.Att.nets = [ ("jpy", "400") ]) "suspense recorded net is exact";
      require (holding.Att.entries = 2) "suspense entry count";
      require (holding.Att.oldest = Some "2026-10-04") "oldest suspense entry";
      require (holding.Att.age_days = Some 18) "suspense age in days");

  (* Zero hides: entries that net to zero are not a pending holding. *)
  let zero =
    book
      [
        entry "a" "2026-10-04" [ posting "suspense" (z 100); posting "cash" (z (-100)) ];
        entry "b" "2026-10-10" [ posting "suspense" (z (-100)); posting "cash" (z 100) ];
      ]
  in
  require (Att.suspense_holding (env zero) = None) "a zero suspense balance hides the signal";

  (* Several Measures stay separate. *)
  let multi =
    book
      [
        entry "a" "2026-10-04" [ posting "suspense" (z 400); posting "cash" (z (-400)) ];
        entry "b" "2026-10-05"
          [
            D.Effect.create ~key:None
              ~locus:(id_of (D.Identifier.Locus.of_string "suspense"))
              ~measure:(id_of (D.Identifier.Measure.of_string "eur"))
              ~quantity:(D.Quantity.of_quanta (z 500));
            D.Effect.create ~key:None
              ~locus:(id_of (D.Identifier.Locus.of_string "cash"))
              ~measure:(id_of (D.Identifier.Measure.of_string "eur"))
              ~quantity:(D.Quantity.of_quanta (z (-500)));
          ];
      ]
  in
  (match Att.suspense_holding (env multi) with
  | Some holding -> require (List.length holding.Att.nets = 2) "two Measures stay separate"
  | None -> failwith "multi-Measure suspense must show");

  (* Without history support the recorded net is still exact: it is a sum of
     recorded postings, never a balance. *)
  let unsupported =
    book ~zero:false
      [ entry "a" "2026-10-04" [ posting "suspense" (z 300); posting "cash" (z (-300)) ] ]
  in
  (match Att.suspense_holding (env unsupported) with
  | Some holding ->
      require
        (holding.Att.nets = [ ("jpy", "300") ])
        "a suspense coordinate without history support still has an exact recorded net"
  | None -> failwith "a recorded suspense net must show");

  (* A Measure whose recorded net is zero is not listed beside a non-zero one. *)
  let mixed =
    book
      [
        entry "a" "2026-10-04" [ posting "suspense" (z 400); posting "cash" (z (-400)) ];
        entry "b" "2026-10-05"
          [
            D.Effect.create ~key:None
              ~locus:(id_of (D.Identifier.Locus.of_string "suspense"))
              ~measure:(id_of (D.Identifier.Measure.of_string "eur"))
              ~quantity:(D.Quantity.of_quanta (z 500));
            D.Effect.create ~key:None
              ~locus:(id_of (D.Identifier.Locus.of_string "suspense"))
              ~measure:(id_of (D.Identifier.Measure.of_string "eur"))
              ~quantity:(D.Quantity.of_quanta (z (-500)));
          ];
      ]
  in
  (match Att.suspense_holding (env mixed) with
  | Some holding ->
      require
        (holding.Att.nets = [ ("jpy", "400") ])
        "a Measure whose recorded net is zero is not listed beside a non-zero one"
  | None -> failwith "a recorded suspense net must show");

  (* No suspense entry at all is nothing pending. *)
  let untouched =
    book [ entry "a" "2026-10-04" [ posting "cash" (z 300); posting "food" (z (-300)) ] ]
  in
  require
    (Att.suspense_holding (env untouched) = None)
    "a book without suspense entries hides the signal";

  (* The list shows the holding row and its detail names the correction route. *)
  let geometry : Screen.geometry =
    { screen = (120, 36); body = (120, 33); content = (120, 32); width_of = String.length }
  in
  let view env =
    let v = Att.view env geometry (Att.create ()) in
    Lazy.force v.Screen.rows |> List.map snd
  in
  let shown = view (env nonzero) in
  require (List.exists (fun line -> contains line "! holding") shown) "the holding row is listed";
  require
    (List.exists (fun line -> contains line "suspense recorded net:") shown)
    "the row names the recorded net";
  require
    (List.exists (fun line -> contains line "suspense recorded net: JPY") shown)
    "the row names the recorded net with its Measure";
  require
    (List.exists (fun line -> contains line "JPY: 400") shown)
    "the detail names the Measure and its amount once";
  require
    (not (List.exists (fun line -> contains line "400 jpy") shown))
    "the Measure is never named twice";
  require
    (List.exists (fun line -> contains line "Correct the entry") shown)
    "the detail names the Actual correction route";
  require
    (List.exists (fun line -> contains line "unresolved role gap") shown)
    "the detail says the holding is an unresolved role gap";
  let hidden = view (env zero) in
  require
    (not (List.exists (fun line -> contains line "! holding") hidden))
    "a zero suspense balance hides the row";
  print_endline
    "PASS: suspense shows one recorded-net Attention holding only when non-zero and keeps Measures \
     separate."
