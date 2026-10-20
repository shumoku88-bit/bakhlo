(* A book file is a snapshot (the ordinary single-file book) followed by appended
   record lines. Each record holds operations applied all-or-nothing with the same
   Daily_book functions the application uses, so replay is the original admission.
   Pure: no file access. *)
module B = Daily_book
module M = Bakhlo_application.Event_merchants
module X = Sexplib0.Sexp

type op =
  | Put_entry of { replace : bool; entry : B.entry; plan : string option }
  | Put_plan of { replace : bool; plan : B.plan }
  | Cancel_plan of { id : string; day : string }
  | Observe of (string * string * Z.t) list
  | Add_locus of string
  | Set_locus_label of { id : string; label : string; help : string option }
  | Classify_merchant of { id : string; disposition : M.disposition }

let apply book = function
  | Put_entry { replace; entry; plan } -> B.put_entry book ~replace entry ~plan
  | Put_plan { replace; plan } -> B.put_plan book ~replace plan
  | Cancel_plan { id; day } -> B.cancel_plan book ~id ~day
  | Observe rows -> B.observe_quantities book rows
  | Add_locus id -> B.add_locus book id
  | Set_locus_label { id; label; help } -> B.set_locus_label book ~id ~label ?help ()
  | Classify_merchant { id; disposition } -> B.classify_merchant book ~id ~disposition

let apply_all book ops =
  List.fold_left (fun result op -> Result.bind result (fun book -> apply book op)) (Ok book) ops

exception Corrupt

let a s = X.Atom s
let f tag xs = X.List (a tag :: xs)
let opt = function None -> f "none" [] | Some s -> f "some" [ a s ]
let mode replace = a (if replace then "replace" else "new")

let op_to_sexp = function
  | Put_entry { replace; entry; plan } -> f "put-entry" [ mode replace; B.entry_to_sexp entry; opt plan ]
  | Put_plan { replace; plan } -> f "put-plan" [ mode replace; B.plan_to_sexp plan ]
  | Cancel_plan { id; day } -> f "cancel-plan" [ a id; a day ]
  | Observe rows -> f "observe" (List.map (fun (l, m, q) -> X.List [ a l; a m; a (Z.to_string q) ]) rows)
  | Add_locus id -> f "add-locus" [ a id ]
  | Set_locus_label { id; label; help } -> f "set-locus-label" [ a id; a label; opt help ]
  | Classify_merchant { id; disposition } ->
      f "classify-merchant"
        [ a id;
          (match disposition with
          | M.Nonmerchant -> f "nonmerchant" []
          | M.Merchant p -> f "party" [ a (Bakhlo_domain.Identifier.External_party.to_string p) ]) ]

let ok = function Ok x -> x | Error _ -> raise Corrupt

let op_of_sexp x =
  let atom = function X.Atom s -> s | X.List _ -> raise Corrupt in
  let replace = function
    | X.Atom "replace" -> true | X.Atom "new" -> false | _ -> raise Corrupt in
  let opt = function
    | X.List [ X.Atom "none" ] -> None
    | X.List [ X.Atom "some"; X.Atom s ] -> Some s
    | _ -> raise Corrupt
  in
  let amount s =
    match Z.of_string s with
    | q when Z.to_string q = s -> q
    | _ | (exception Invalid_argument _) -> raise Corrupt
  in
  match x with
  | X.List [ X.Atom "put-entry"; r; e; p ] ->
      Put_entry { replace = replace r; entry = ok (B.entry_of_sexp e); plan = opt p }
  | X.List [ X.Atom "put-plan"; r; p ] -> Put_plan { replace = replace r; plan = ok (B.plan_of_sexp p) }
  | X.List [ X.Atom "cancel-plan"; X.Atom id; X.Atom day ] -> Cancel_plan { id; day }
  | X.List (X.Atom "observe" :: rows) ->
      Observe
        (List.map
           (function
             | X.List [ X.Atom l; X.Atom m; X.Atom q ] -> (l, m, amount q)
             | _ -> raise Corrupt)
           rows)
  | X.List [ X.Atom "add-locus"; X.Atom id ] -> Add_locus id
  | X.List [ X.Atom "set-locus-label"; X.Atom id; X.Atom label; help ] ->
      Set_locus_label { id; label; help = opt help }
  | X.List [ X.Atom "classify-merchant"; X.Atom id; X.List [ X.Atom "nonmerchant" ] ] ->
      Classify_merchant { id; disposition = M.Nonmerchant }
  | X.List [ X.Atom "classify-merchant"; X.Atom id; X.List [ X.Atom "party"; p ] ] ->
      Classify_merchant
        { id; disposition = M.Merchant (ok (Bakhlo_domain.Identifier.External_party.of_string (atom p))) }
  | _ -> raise Corrupt

let digest body = Digest.to_hex (Digest.string body)
let prefix = "(record "

let record_line ~seq ops =
  if ops = [] || seq < 1 then invalid_arg "Book_log.record_line";
  let body = String.concat " " (List.map (fun op -> B.render_line (op_to_sexp op)) ops) in
  Printf.sprintf "%s%d %s %s)\n" prefix seq (digest body) body

(* [body] is re-rendered from the parsed operations, so the digest also proves the
   line decodes to exactly what was written. *)
let parse_record ~seq line =
  match Parsexp.Single.parse_string line with
  | Ok (X.List (X.Atom "record" :: X.Atom n :: X.Atom sum :: (_ :: _ as ops)))
    when n = string_of_int seq ->
      let ops = List.map op_of_sexp ops in
      let body = String.concat " " (List.map (fun op -> B.render_line (op_to_sexp op)) ops) in
      if digest body = sum then ops else raise Corrupt
  | _ -> raise Corrupt

type loaded = { book : B.t; snapshot : string; records : int; valid_length : int; torn : bool }

let snapshot_length bytes =
  let rec scan from =
    match String.index_from_opt bytes from '\n' with
    | None -> String.length bytes
    | Some n ->
        let next = n + 1 in
        let rest = String.length bytes - next in
        if String.starts_with ~prefix:(String.sub bytes next (min rest (String.length prefix))) prefix
           && rest > 0
        then next
        else scan next
  in
  if String.starts_with ~prefix bytes then 0 else scan 0

let load bytes =
  let cut = snapshot_length bytes in
  let snapshot = String.sub bytes 0 cut in
  match B.of_string snapshot with
  | Error why -> Error ("snapshot-refused: " ^ why)
  | Ok book ->
      let rec replay book seq at =
        if at = String.length bytes then
          Ok { book; snapshot; records = seq - 1; valid_length = at; torn = false }
        else
          match String.index_from_opt bytes at '\n' with
          | None -> Ok { book; snapshot; records = seq - 1; valid_length = at; torn = true }
          | Some n -> (
              match parse_record ~seq (String.sub bytes at (n - at)) with
              | exception Corrupt -> Error (Printf.sprintf "log-corrupt-at-record-%d" seq)
              | ops -> (
                  match apply_all book ops with
                  | Error why -> Error (Printf.sprintf "log-replay-refused-at-record-%d: %s" seq why)
                  | Ok book -> replay book (seq + 1) (n + 1)))
      in
      replay book 1 cut

let decode_record_line ~seq line =
  let line = if String.ends_with ~suffix:"\n" line then String.sub line 0 (String.length line - 1) else line in
  match parse_record ~seq line with ops -> Ok ops | exception Corrupt -> Error "record-undecodable"
