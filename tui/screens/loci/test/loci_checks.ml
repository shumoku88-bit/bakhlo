(* Manage Loci: the unresolved holding Locus is never counted as unassigned and
   its detail names the way to resolve it, not a role. *)
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module Loci = Loci_screen
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

let book =
  get
    (B.of_payload
       {
         measures = [ ("jpy", 0) ];
         labels = None;
         approved = Some [ "suspense"; "cash"; "food" ];
         entries =
           [
             {
               B.id = "a";
               day = "2026-10-04";
               memo = None;
               effects = [ posting "suspense" (z 10); posting "food" (z (-10)) ];
               reversal_of = None;
               exchange = None;
               original_amount = None;
               merchant = None;
             };
           ];
         plans = [];
         origins = [];
         openings = [];
         observations = [];
         presence = None;
         bounded = [];
       })

let geometry : Screen.geometry =
  { screen = (120, 36); body = (120, 33); content = (120, 32); width_of = String.length }

let contains text needle =
  let length = String.length needle in
  let rec loop index =
    index + length <= String.length text
    && (String.sub text index length = needle || loop (index + 1))
  in
  length = 0 || loop 0

let () =
  let env =
    Screen.env_for_checks
      ~accounting_roles:[ ("cash", Roles.Asset) ]
      ~book ~measure:"jpy" ~today:"2026-10-22" ()
  in
  let rows =
    let view = Loci.view env geometry (Loci.create ()) in
    Lazy.force view.Screen.rows |> List.map snd
  in
  require
    (List.exists (fun line -> contains line "1 without role") rows)
    "only the food Locus is counted without a role";
  require
    (not (List.exists (fun line -> contains line "2 without role") rows))
    "suspense is never counted without a role";
  require
    (List.exists (fun line -> contains line "unresolved recording") rows)
    "the suspense detail names its kind";
  require
    (List.exists (fun line -> contains line "takes no accounting role") rows)
    "the suspense detail says it takes no role";
  require
    (List.exists (fun line -> contains line "Correct the entry") rows)
    "the suspense detail names the Actual correction route";
  require
    (List.exists (fun line -> contains line "unresolved role gap") rows)
    "the suspense detail says the accounting view lists it as a role gap";
  require
    (not (List.exists (fun line -> contains line "excluded from role summaries") rows))
    "the suspense detail does not claim it is excluded from role summaries";

  (* The holding Locus never takes a role: r refuses, and so does admission. *)
  let suspense_index =
    let rec find index = function
      | [] -> failwith "suspense is not admitted"
      | locus :: rest -> if locus = "suspense" then index else find (index + 1) rest
    in
    find 0 (Loci.admitted_loci book)
  in
  let selected =
    List.fold_left
      (fun state _ -> fst (Loci.handle env geometry state (`Key (`ASCII 'j', []))))
      (Loci.create ()) (List.init suspense_index Fun.id)
  in
  let refused, request = Loci.handle env geometry selected (`Key (`ASCII 'r', [])) in
  (match request with
  | Screen.Message why ->
      require (contains why "unresolved holding") "r refuses a role for suspense";
      require (contains why "correcting the entries") "the refusal names the correction route"
  | _ -> failwith "r on suspense must be refused with a message");
  require (Loci.form refused = None) "r on suspense opens no role form";

  let opened, _ = Loci.handle env geometry (Loci.create ()) (`Key (`ASCII 'n', [])) in
  let admit_form = Option.get (Loci.form opened) in
  let ready =
    Ui_form.set_focused
      (Ui_form.set_choice (Ui_form.set_text admit_form "token" "suspense") "role" 1)
      2
  in
  let submitted, request =
    Loci.handle env geometry (Loci.with_form ready opened) (`Key (`Enter, []))
  in
  (match request with
  | Screen.Stay -> ()
  | _ -> failwith "admitting suspense must be refused");
  (match Loci.form submitted with
  | Some form ->
      require
        (contains (Ui_form.notice form) "unresolved holding")
        "admission refuses a role for suspense"
  | None -> failwith "the admit form stays open with the refusal");
  print_endline
    "PASS: Manage Loci excludes the suspense holding from the unassigned count, names its \
     resolution route and refuses an accounting role for it."
