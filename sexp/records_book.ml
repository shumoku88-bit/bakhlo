module D = Bakhlo_domain
module A = Bakhlo_application
module Q = A.Current_quantity_query
module X = Sexplib0.Sexp

exception Refused of string

let require p why = if not p then raise (Refused why)
let get why = function Ok x -> x | Error _ -> raise (Refused why)
let protect f = try Ok (f ()) with Refused why -> Error why | Failure msg -> Error msg

let eid s = get "invalid-entry-id" (D.Identifier.Event.of_string s)
let lid s = get "invalid-locus" (D.Identifier.Locus.of_string s)
let mid s = get "invalid-measure" (D.Identifier.Measure.of_string s)
let key s = get "invalid-posting-key" (D.Identifier.Effect_key.of_string s)
let estr = D.Identifier.Event.to_string
let lstr = D.Identifier.Locus.to_string
let mstr = D.Identifier.Measure.to_string

let integer_syntax s =
  let len = String.length s in
  let start = if len > 0 && (s.[0] = '-' || s.[0] = '+') then 1 else 0 in
  let rec digits n = n = len || (s.[n] >= '0' && s.[n] <= '9' && digits (n + 1)) in
  len > start && digits start

let integer s =
  require (integer_syntax s) "invalid-integer";
  Z.of_string s

let coord l m : D.Effect_coordinate.t = { locus = lid l; measure = mid m }
let qty s = D.Quantity.of_quanta (integer s)
let qstr q = Z.to_string (D.Quantity.quanta q)

let posting l m n k =
  D.Effect.create ~locus:(lid l) ~measure:(mid m) ~quantity:(qty n) ~key:(Option.map key k)

let a s = X.Atom s
let l xs = X.List xs
let f tag xs = X.List (X.Atom tag :: xs)
let opt = function None -> f "none" [] | Some s -> f "some" [ a s ]
let atom = function X.Atom s -> s | X.List _ -> raise (Refused "expected-atom")
let one = function [ x ] -> x | _ -> raise (Refused "expected-single-element")

let optional = function
  | X.List [ X.Atom "none" ] -> None
  | X.List [ X.Atom "some"; X.Atom s ] -> Some s
  | _ -> raise (Refused "invalid-option")

type header = {
  version : int;
  measures : (string * int) list;
  labels : (string * string * string) list option;
  approved_loci : string list option;
  origins : D.Effect_coordinate.t list;
  openings : Q.opening list;
  observations : A.Current_quantity_groups.group list;
  presence : Q.presence option;
  opaque : X.t list;
}

type entry = {
  id : string;
  day : string;
  token : string option;
  memo : string option;
  effects : D.Effect.t list;
  reversal_of : string option;
  exchange : (string * string) option;
  opaque : X.t list;
}

type plan = {
  id : string;
  day : string;
  measure : string;
  changes : (string * Z.t) list;
  paid_by : string option;
  cancelled_on : string option;
  opaque : X.t list;
}

type budget = {
  id : string;
  start_day : string;
  end_exclusive : string;
  measure : string;
  allocations : (string * Z.t) list;
  expense_loci : string list;
  actual_routes : (string * string option) list;
  plan_routes : (string * string * string option) list;
  opaque : X.t list;
}

type observation = {
  id : string option;
  reflected_roots : string list;
  quantities : (string * string * Z.t) list;
  opaque : X.t list;
}

type origin = {
  token : string;
  event_id : string;
  opaque : X.t list;
}

type add_locus = {
  locus : string;
  opaque : X.t list;
}

type payload =
  | Header of header
  | Entry of entry
  | Plan of plan
  | Budget of budget
  | Observation of observation
  | Origin of origin
  | Add_locus of add_locus
  | Opaque of X.t

type frame = {
  lsn : int;
  crc : string;
  payload : payload;
}

type t = {
  header : header;
  frames : frame list;
}

(* Field partitioning for unknown field preservation *)
let partition_fields known_tags rows =
  let known = Hashtbl.create 10 in
  let opaque = ref [] in
  List.iter
    (function
      | X.List (X.Atom tag :: args) as item ->
          if List.mem tag known_tags then Hashtbl.add known tag args
          else opaque := item :: !opaque
      | item -> opaque := item :: !opaque)
    rows;
  (known, List.rev !opaque)

let field_opt known tag =
  match Hashtbl.find_all known tag with
  | [] -> None
  | [ x ] -> Some x
  | _ -> raise (Refused ("multiple-field-" ^ tag))

let field_req known tag =
  match field_opt known tag with
  | Some x -> x
  | None -> raise (Refused ("missing-field-" ^ tag))

(* Encoding / Decoding helpers *)

let encode_coord (c : D.Effect_coordinate.t) =
  f "coord" [ a (lstr c.locus); a (mstr c.measure) ]

let decode_coord = function
  | X.List [ X.Atom "coord"; X.Atom l; X.Atom m ] | X.List [ X.Atom l; X.Atom m ] -> coord l m
  | _ -> raise (Refused "invalid-coordinate")

let encode_header (h : header) =
  let supplied encode = function
    | None -> f "not-supplied" []
    | Some xs -> f "provided" (List.map encode xs)
  in
  f "header"
    ([
       f "format" [ a "bakhlo-records" ];
       f "version" [ a (string_of_int h.version) ];
       f "measures" (List.map (fun (m, n) -> f "measure" [ a m; a (string_of_int n) ]) h.measures);
       f "labels"
         [ supplied (fun (id, name, help) -> f "label" [ a id; a name; a help ]) h.labels ];
       f "approved-loci" [ supplied a h.approved_loci ];
       f "support"
         [
           f "zero-origin" (List.map encode_coord h.origins);
           f "openings"
             (List.map
                (fun (o : Q.opening) ->
                  f "opening"
                    [ a (lstr o.coordinate.locus); a (mstr o.coordinate.measure); a (estr o.opening_event) ])
                h.openings);
           f "observations"
             (List.map
                (fun (g : A.Current_quantity_groups.group) ->
                  f "observation"
                    [
                      f "reflected" (List.map (fun id -> a (estr id)) g.reflected_roots);
                      f "quantities"
                        (List.map
                           (fun (row : A.Current_quantity_projection.assertion) ->
                             f "coord"
                               [ a (lstr row.coordinate.locus); a (mstr row.coordinate.measure); a (qstr row.quantity) ])
                           g.assertions);
                    ])
                h.observations);
           f "presence"
             [
               (match h.presence with
               | None -> f "not-supplied" []
               | Some p ->
                   f "provided"
                     [
                       f "reflected" (List.map (fun id -> a (estr id)) p.reflected_roots);
                       f "coordinates" (List.map encode_coord p.coordinates);
                     ]);
             ];
         ];
     ]
    @ h.opaque)

let decode_header rows =
  let known, opaque =
    partition_fields
      [ "format"; "version"; "measures"; "labels"; "approved-loci"; "support" ]
      rows
  in
  let format = atom (one (field_req known "format")) in
  require (format = "bakhlo-records") "unsupported-format";
  let version = int_of_string (atom (one (field_req known "version"))) in
  require (version = 1) "unsupported-version";
  let measures =
    List.map
      (function
        | X.List [ X.Atom "measure"; X.Atom m; X.Atom n ] ->
            let n = integer n in
            require (Z.geq n Z.zero && Z.leq n (Z.of_int 9)) "invalid-scale";
            (m, Z.to_int n)
        | _ -> raise (Refused "invalid-measure"))
      (field_req known "measures")
  in
  let supplied decode = function
    | [ X.List [ X.Atom "not-supplied" ] ] -> None
    | [ X.List (X.Atom "provided" :: xs) ] -> Some (List.map decode xs)
    | _ -> raise (Refused "invalid-supply")
  in
  let labels =
    match field_opt known "labels" with
    | None -> None
    | Some xs ->
        supplied
          (function
            | X.List [ X.Atom "label"; X.Atom id; X.Atom label; X.Atom help ] ->
                (id, label, help)
            | _ -> raise (Refused "invalid-label"))
          xs
  in
  let approved_loci =
    match field_opt known "approved-loci" with
    | None -> None
    | Some xs -> supplied atom xs
  in
  let support_fields =
    match field_opt known "support" with
    | None -> raise (Refused "missing-support")
    | Some xs -> xs
  in
  let sup_known, _ =
    partition_fields [ "zero-origin"; "openings"; "observations"; "presence" ] support_fields
  in
  let origins =
    match field_opt sup_known "zero-origin" with
    | None -> []
    | Some xs -> List.map decode_coord xs
  in
  let openings =
    match field_opt sup_known "openings" with
    | None -> []
    | Some xs ->
        List.map
          (function
            | X.List [ X.Atom "opening"; X.Atom l; X.Atom m; X.Atom e ]
            | X.List [ X.Atom l; X.Atom m; X.Atom e ] ->
                ({ Q.coordinate = coord l m; opening_event = eid e } : Q.opening)
            | _ -> raise (Refused "invalid-opening"))
          xs
  in
  let observations =
    match field_opt sup_known "observations" with
    | None -> []
    | Some xs ->
        List.map
          (function
            | X.List (X.Atom "observation" :: obs_rows) ->
                let obs_k, _ = partition_fields [ "reflected"; "quantities" ] obs_rows in
                let reflected_roots =
                  List.map (fun x -> eid (atom x)) (field_req obs_k "reflected")
                in
                let assertions =
                  List.map
                    (function
                      | X.List [ X.Atom "coord"; X.Atom l; X.Atom m; X.Atom q ]
                      | X.List [ X.Atom l; X.Atom m; X.Atom q ] ->
                          ({ coordinate = coord l m; quantity = qty q } : A.Current_quantity_projection.assertion)
                      | _ -> raise (Refused "invalid-assertion"))
                    (field_req obs_k "quantities")
                in
                ({ reflected_roots; assertions } : A.Current_quantity_groups.group)
            | _ -> raise (Refused "invalid-observation-group"))
          xs
  in
  let presence =
    match field_opt sup_known "presence" with
    | None | Some [ X.List [ X.Atom "not-supplied" ] ] -> None
    | Some [ X.List (X.Atom "provided" :: pres_rows) ] ->
        let pres_k, _ = partition_fields [ "reflected"; "coordinates" ] pres_rows in
        Some
          {
            Q.reflected_roots = List.map (fun x -> eid (atom x)) (field_req pres_k "reflected");
            coordinates = List.map decode_coord (field_req pres_k "coordinates");
          }
    | _ -> raise (Refused "invalid-presence")
  in
  { version; measures; labels; approved_loci; origins; openings; observations; presence; opaque }

let encode_entry (e : entry) =
  f "entry"
    ([
       f "id" [ a e.id ];
       f "day" [ a e.day ];
       f "token" [ opt e.token ];
       f "memo" [ (match e.memo with None -> f "absent" [] | Some m -> f "text" [ a m ]) ];
       f "reversal-of" [ opt e.reversal_of ];
       f "exchange"
         [
           (match e.exchange with
           | None -> f "none" []
           | Some (x, y) -> f "keys" [ a x; a y ]);
         ];
       f "effects"
         (List.map
            (fun p ->
              f "posting"
                [
                  a (lstr (D.Effect.locus p));
                  a (mstr (D.Effect.measure p));
                  a (qstr (D.Effect.quantity p));
                  opt (Option.map D.Identifier.Effect_key.to_string (D.Effect.key p));
                ])
            e.effects);
     ]
    @ e.opaque)

let decode_entry rows =
  let known, opaque =
    partition_fields
      [ "id"; "day"; "token"; "memo"; "reversal-of"; "exchange"; "effects" ]
      rows
  in
  let id = atom (one (field_req known "id")) in
  let day = atom (one (field_req known "day")) in
  let token =
    match field_opt known "token" with
    | None -> None
    | Some xs -> optional (one xs)
  in
  let memo =
    match field_opt known "memo" with
    | None | Some [ X.List [ X.Atom "absent" ] ] -> None
    | Some [ X.List [ X.Atom "text"; X.Atom m ] ] -> Some m
    | _ -> raise (Refused "invalid-memo")
  in
  let reversal_of =
    match field_opt known "reversal-of" with
    | None -> None
    | Some xs -> optional (one xs)
  in
  let exchange =
    match field_opt known "exchange" with
    | None | Some [ X.List [ X.Atom "none" ] ] -> None
    | Some [ X.List [ X.Atom "keys"; X.Atom x; X.Atom y ] ] -> Some (x, y)
    | _ -> raise (Refused "invalid-exchange")
  in
  let effects =
    List.map
      (function
        | X.List [ X.Atom "posting"; X.Atom l; X.Atom m; X.Atom n; opt_k ] ->
            posting l m n (optional opt_k)
        | _ -> raise (Refused "invalid-posting"))
      (field_req known "effects")
  in
  { id; day; token; memo; effects; reversal_of; exchange; opaque }

let encode_plan (p : plan) =
  f "plan"
    ([
       f "id" [ a p.id ];
       f "day" [ a p.day ];
       f "measure" [ a p.measure ];
       f "changes" (List.map (fun (loc, n) -> l [ a loc; a (Z.to_string n) ]) p.changes);
       f "paid-by" [ opt p.paid_by ];
       f "cancelled-on" [ opt p.cancelled_on ];
     ]
    @ p.opaque)

let decode_plan rows =
  let known, opaque =
    partition_fields [ "id"; "day"; "measure"; "changes"; "paid-by"; "cancelled-on" ] rows
  in
  let id = atom (one (field_req known "id")) in
  let day = atom (one (field_req known "day")) in
  let measure = atom (one (field_req known "measure")) in
  let changes =
    List.map
      (function
        | X.List [ X.Atom l; X.Atom n ] -> (l, integer n)
        | _ -> raise (Refused "invalid-change"))
      (field_req known "changes")
  in
  let paid_by =
    match field_opt known "paid-by" with
    | None -> None
    | Some xs -> optional (one xs)
  in
  let cancelled_on =
    match field_opt known "cancelled-on" with
    | None -> None
    | Some xs -> optional (one xs)
  in
  { id; day; measure; changes; paid_by; cancelled_on; opaque }

let encode_budget (b : budget) =
  f "budget"
    ([
       f "id" [ a b.id ];
       f "start" [ a b.start_day ];
       f "end-exclusive" [ a b.end_exclusive ];
       f "measure" [ a b.measure ];
       f "allocations" (List.map (fun (p, n) -> l [ a p; a (Z.to_string n) ]) b.allocations);
       f "expense-loci" (List.map a b.expense_loci);
       f "actual-routes"
         (List.map (fun (loc, target) -> l [ a loc; opt target ]) b.actual_routes);
       f "plan-routes"
         (List.map (fun (id, loc, target) -> l [ a id; a loc; opt target ]) b.plan_routes);
     ]
    @ b.opaque)

let decode_budget rows =
  let known, opaque =
    partition_fields
      [ "id"; "start"; "end-exclusive"; "measure"; "allocations"; "expense-loci"; "actual-routes"; "plan-routes" ]
      rows
  in
  let id = atom (one (field_req known "id")) in
  let start_day = atom (one (field_req known "start")) in
  let end_exclusive = atom (one (field_req known "end-exclusive")) in
  let measure = atom (one (field_req known "measure")) in
  let allocations =
    List.map
      (function
        | X.List [ X.Atom p; X.Atom n ] -> (p, integer n)
        | _ -> raise (Refused "invalid-budget-allocation"))
      (field_req known "allocations")
  in
  let expense_loci = List.map atom (field_req known "expense-loci") in
  let actual_routes =
    List.map
      (function
        | X.List [ X.Atom loc; target ] -> (loc, optional target)
        | _ -> raise (Refused "invalid-budget-actual-route"))
      (field_req known "actual-routes")
  in
  let plan_routes =
    List.map
      (function
        | X.List [ X.Atom id; X.Atom loc; target ] -> (id, loc, optional target)
        | _ -> raise (Refused "invalid-budget-plan-route"))
      (field_req known "plan-routes")
  in
  { id; start_day; end_exclusive; measure; allocations; expense_loci; actual_routes; plan_routes; opaque }

let encode_observation (o : observation) =
  f "observation"
    ([
       f "id" [ opt o.id ];
       f "reflected" (List.map a o.reflected_roots);
       f "quantities"
         (List.map (fun (locus, measure, q) ->
              f "coord" [ a locus; a measure; a (Z.to_string q) ])
            o.quantities);
     ]
    @ o.opaque)

let decode_observation rows =
  let known, opaque =
    partition_fields [ "id"; "reflected"; "quantities" ] rows
  in
  let id =
    match field_opt known "id" with
    | None -> None
    | Some xs -> optional (one xs)
  in
  let reflected_roots = List.map atom (field_req known "reflected") in
  let quantities =
    List.map
      (function
        | X.List [ X.Atom "coord"; X.Atom l; X.Atom m; X.Atom q ]
        | X.List [ X.Atom l; X.Atom m; X.Atom q ] ->
            (l, m, integer q)
        | _ -> raise (Refused "invalid-observation-quantity"))
      (field_req known "quantities")
  in
  { id; reflected_roots; quantities; opaque }

let encode_origin (o : origin) =
  f "origin" ([ f "token" [ a o.token ]; f "event" [ a o.event_id ] ] @ o.opaque)

let decode_origin rows =
  let known, opaque = partition_fields [ "token"; "event" ] rows in
  let token = atom (one (field_req known "token")) in
  let event_id = atom (one (field_req known "event")) in
  { token; event_id; opaque }

let encode_add_locus (al : add_locus) =
  f "add-locus" ([ f "locus" [ a al.locus ] ] @ al.opaque)

let decode_add_locus rows =
  let known, opaque = partition_fields [ "locus" ] rows in
  let locus = atom (one (field_req known "locus")) in
  { locus; opaque }

let encode_payload = function
  | Header h -> encode_header h
  | Entry e -> encode_entry e
  | Plan p -> encode_plan p
  | Budget b -> encode_budget b
  | Observation o -> encode_observation o
  | Origin orig -> encode_origin orig
  | Add_locus al -> encode_add_locus al
  | Opaque sexp -> sexp

let decode_payload = function
  | X.List (X.Atom "header" :: rows) -> Header (decode_header rows)
  | X.List (X.Atom "entry" :: rows) -> Entry (decode_entry rows)
  | X.List (X.Atom "plan" :: rows) -> Plan (decode_plan rows)
  | X.List (X.Atom "budget" :: rows) -> Budget (decode_budget rows)
  | X.List (X.Atom "observation" :: rows) -> Observation (decode_observation rows)
  | X.List (X.Atom "origin" :: rows) -> Origin (decode_origin rows)
  | X.List (X.Atom "add-locus" :: rows) -> Add_locus (decode_add_locus rows)
  | other -> Opaque other

let encode_frame lsn payload =
  let payload_sexp = encode_payload payload in
  let payload_str = X.to_string payload_sexp in
  let crc = Crc32.to_hex (Crc32.of_string payload_str) in
  { lsn; crc; payload }

let serialize_frame frame =
  let payload_sexp = encode_payload frame.payload in
  let frame_sexp =
    f "frame"
      [
        f "lsn" [ a (string_of_int frame.lsn) ];
        f "crc" [ a frame.crc ];
        f "payload" [ payload_sexp ];
      ]
  in
  X.to_string frame_sexp

let parse_frame str =
  protect (fun () ->
      match Parsexp.Single.parse_string str with
      | Error err -> raise (Refused (Parsexp.Parse_error.message err))
      | Ok
          (X.List
            [
              X.Atom "frame";
              X.List [ X.Atom "lsn"; X.Atom lsn_s ];
              X.List [ X.Atom "crc"; X.Atom crc_s ];
              X.List [ X.Atom "payload"; payload_sexp ];
            ]) ->
          let lsn = int_of_string lsn_s in
          let computed_crc = Crc32.to_hex (Crc32.of_string (X.to_string payload_sexp)) in
          require (String.equal computed_crc crc_s)
            (Printf.sprintf "checksum-mismatch: expected %s, computed %s" crc_s computed_crc);
          let payload = decode_payload payload_sexp in
          { lsn; crc = crc_s; payload }
      | Ok _ -> raise (Refused "invalid-frame-structure"))

type corruption =
  | No_corruption
  | Mid_file of { byte_offset : int; reason : string }

type inspection = {
  valid_frames : frame list;
  last_lsn : int;
  trailing_torn_bytes : int;
  corruption : corruption;
}

let inspect_string text =
  let lines = String.split_on_char '\n' text in
  let total_len = String.length text in
  let valid = ref [] in
  let expected_lsn = ref 0 in
  let current_offset = ref 0 in
  let corruption = ref No_corruption in
  let trailing_torn = ref 0 in

  let num_lines = List.length lines in
  List.iteri
    (fun idx line ->
      let line_len = String.length line in
      let has_newline = idx < num_lines - 1 in
      let line_bytes = line_len + if has_newline then 1 else 0 in
      let trimmed = String.trim line in

      if !corruption = No_corruption then begin
        if trimmed = "" || String.starts_with ~prefix:";" trimmed then
          (* Skip blank lines or comments *)
          current_offset := !current_offset + line_bytes
        else begin
          match parse_frame trimmed with
          | Ok frame ->
              if frame.lsn <> !expected_lsn then
                corruption :=
                  Mid_file
                    {
                      byte_offset = !current_offset;
                      reason = Printf.sprintf "lsn-mismatch: expected %d, got %d" !expected_lsn frame.lsn;
                    }
              else begin
                valid := frame :: !valid;
                expected_lsn := frame.lsn + 1;
                current_offset := !current_offset + line_bytes
              end
          | Error err ->
              let is_last_chunk = idx = num_lines - 1 || (idx = num_lines - 2 && List.nth lines (idx + 1) = "") in
              if is_last_chunk then
                (* Trailing torn write: unclosed or incomplete trailing line *)
                trailing_torn := total_len - !current_offset
              else
                corruption :=
                  Mid_file
                    {
                      byte_offset = !current_offset;
                      reason = Printf.sprintf "corrupt-frame: %s" err;
                    }
        end
      end)
    lines;

  {
    valid_frames = List.rev !valid;
    last_lsn = (if !valid = [] then -1 else !expected_lsn - 1);
    trailing_torn_bytes = !trailing_torn;
    corruption = !corruption;
  }

let of_string str =
  let insp = inspect_string str in
  match insp.corruption with
  | Mid_file { byte_offset; reason } ->
      Error (Printf.sprintf "mid-file-corruption-at-%d: %s" byte_offset reason)
  | No_corruption ->
      if insp.trailing_torn_bytes > 0 then
        Error (Printf.sprintf "trailing-torn-write-%d-bytes" insp.trailing_torn_bytes)
      else
        match insp.valid_frames with
        | [] -> Error "empty-records-log"
        | first :: rest ->
            match first.payload with
            | Header h ->
                if first.lsn <> 0 then Error "header-lsn-not-zero"
                else Ok { header = h; frames = rest }
            | _ -> Error "first-frame-must-be-header"

let to_string (t : t) =
  let buf = Buffer.create (List.length t.frames * 200 + 500) in
  Buffer.add_string buf ";; Bakhlo Records S-expression v1\n";
  let h_frame = encode_frame 0 (Header t.header) in
  Buffer.add_string buf (serialize_frame h_frame);
  Buffer.add_char buf '\n';
  List.iter
    (fun f ->
      Buffer.add_string buf (serialize_frame f);
      Buffer.add_char buf '\n')
    t.frames;
  Buffer.contents buf

let header t = t.header
let frames t = t.frames

let entries t =
  List.filter_map (fun f -> match f.payload with Entry e -> Some e | _ -> None) t.frames

let plans t =
  List.filter_map (fun f -> match f.payload with Plan p -> Some p | _ -> None) t.frames

let budgets t =
  List.filter_map (fun f -> match f.payload with Budget b -> Some b | _ -> None) t.frames

let observations t =
  List.filter_map (fun f -> match f.payload with Observation o -> Some o | _ -> None) t.frames

let origins t =
  List.filter_map (fun f -> match f.payload with Origin o -> Some o | _ -> None) t.frames

let added_loci t =
  List.filter_map (fun f -> match f.payload with Add_locus al -> Some al.locus | _ -> None) t.frames

let opaque_records t =
  List.filter_map (fun f -> match f.payload with Opaque x -> Some x | _ -> None) t.frames
