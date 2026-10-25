(* Manage Loci: the unresolved holding Locus is never counted as unassigned and
   its detail names the way to resolve it, not a role. *)
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module Loci = Loci_screen
module Roles = Locus_roles

let require condition why = if not condition then failwith why

let book =
  Bakhlo_sexp.Daily_txt.book
    "BOOK\t1\nMEASURE\tjpy\t0\nLOCUS\tsuspense\tsuspense\t\nLOCUS\tcash\tcash\t\nLOCUS\tfood\tfood\t\n\
     TX\ta\t2026-10-04\nEFFECT\tsuspense\tjpy\t10\nEFFECT\tfood\tjpy\t-10\nENDTX\nEND\n"

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
      let notice = Ui_form.notice form in
      require (contains notice "unresolved holding") "admission refuses a role for suspense";
      require
        (contains notice "enable unresolved recording")
        "the admission refusal names Record's enable unresolved recording";
      require
        (not (contains notice "Correct the entry"))
        "the admission refusal does not point at the Actual correction"
  | None -> failwith "the admit form stays open with the refusal");
  print_endline
    "PASS: Manage Loci excludes the suspense holding from the unassigned count, names its \
     resolution route and refuses an accounting role for it."
