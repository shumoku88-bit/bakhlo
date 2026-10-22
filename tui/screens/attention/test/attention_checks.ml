(* Suspense never silently stays pending: one derived Attention signal for the
   unresolved holding Locus, and Manage Loci never counts it as unassigned. *)
module B = Bakhlo_sexp.Daily_book
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
  { id; day; memo = None; effects; reversal_of = None; exchange = None;
    original_amount = None; merchant = None }

let book ?(zero = true) entries =
  get
    (B.of_payload
       {
         measures = [ ("jpy", 0); ("eur", 2) ];
         labels = None;
         approved = Some [ "suspense"; "cash"; "food" ];
         entries;
         plans = [];
         origins =
           (if zero then [ "suspense/jpy"; "suspense/eur" ] else []) |> List.map (fun text ->
               match String.split_on_char '/' text with
               | [ locus; measure ] ->
                   {
                     D.Effect_coordinate.locus =
                       id_of (D.Identifier.Locus.of_string locus);
                     measure = id_of (D.Identifier.Measure.of_string measure);
                   }
               | _ -> failwith "bad fixture coordinate");
         openings = [];
         observations = [];
         presence = None;
         bounded = [];
       })

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
  (* A non-zero balance shows one signal with its count and oldest entry. *)
  let nonzero =
    book
      [
        entry "a" "2026-10-04" [ posting "suspense" (z 500); posting "cash" (z (-500)) ];
        entry "b" "2026-10-10" [ posting "suspense" (z (-100)); posting "food" (z 100) ];
      ]
  in
  let signal = Att.suspense_holding (env nonzero) in
  (match signal with
  | None -> failwith "a non-zero suspense balance must show a signal"
  | Some holding ->
      require (holding.Att.balances = [ ("jpy", "400 jpy") ]) "suspense balance is exact";
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
  | Some holding -> require (List.length holding.Att.balances = 2) "two Measures stay separate"
  | None -> failwith "multi-Measure suspense must show");

  (* Without support the amount is unknown, never zero. *)
  let unknown =
    book ~zero:false
      [ entry "a" "2026-10-04" [ posting "suspense" (z 300); posting "cash" (z (-300)) ] ]
  in
  (match Att.suspense_holding (env unknown) with
  | Some holding ->
      require
        (List.for_all
           (fun (_, text) -> contains text "unknown")
           holding.Att.balances)
        "an unsupported suspense balance is unknown, never zero"
  | None -> failwith "an unknown suspense balance must still show");


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
  require (List.exists (fun line -> contains line "suspense:") shown) "the row names suspense";
  require
    (List.exists (fun line -> contains line "Correct the entry") shown)
    "the detail names the Actual correction route";
  let hidden = view (env zero) in
  require
    (not (List.exists (fun line -> contains line "! holding") hidden))
    "a zero suspense balance hides the row";
  print_endline
    "PASS: suspense shows one exact/unknown Attention holding only when non-zero and keeps \
     Measures separate."
