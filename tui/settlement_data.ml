type row = {
  id : string;
  label : string option;
  debtor : string;
  creditor : string;
  measure : string;
  committed : Z.t;
  settled : Z.t;
  extinguished : Z.t;
  source_event : string;
  source_effect : string;
  effective_on : string option;
}

type scope = Open_only | All

type t = {
  rows : row list;
}

let empty = { rows = [] }

let outstanding r =
  Z.sub (Z.sub r.committed r.settled) r.extinguished

let is_open r =
  Z.gt (outstanding r) Z.zero

let open_rows t =
  List.filter is_open t.rows

let visible_rows t = function
  | Open_only -> open_rows t
  | All -> t.rows

let find_row t id =
  List.find_opt (fun r -> String.equal r.id id) t.rows

let next_id t =
  let count = List.length t.rows + 1 in
  let rec find_unused n =
    let candidate = Printf.sprintf "comm-%d" n in
    if List.exists (fun r -> String.equal r.id candidate) t.rows then
      find_unused (n + 1)
    else candidate
  in
  find_unused count

let add_row t ~id ?label ~debtor ~creditor ~measure ~committed ?(source_event = "") ?(source_effect = "") ?effective_on () =
  if List.exists (fun r -> String.equal r.id id) t.rows then
    Error (Printf.sprintf "Commitment with ID %s already exists." id)
  else if Z.leq committed Z.zero then
    Error "Committed amount must be greater than zero."
  else
    let new_row = {
      id;
      label;
      debtor;
      creditor;
      measure;
      committed;
      settled = Z.zero;
      extinguished = Z.zero;
      source_event;
      source_effect;
      effective_on;
    } in
    Ok { rows = t.rows @ [ new_row ] }

let settle_row t ~id ~amount =
  if Z.leq amount Z.zero then
    Error "Settlement amount must be greater than zero."
  else
    match find_row t id with
    | None -> Error (Printf.sprintf "Commitment %s not found." id)
    | Some r ->
        let rem = outstanding r in
        if Z.gt amount rem then
          Error (Printf.sprintf "Amount %s exceeds remaining balance %s." (Z.to_string amount) (Z.to_string rem))
        else
          let updated = { r with settled = Z.add r.settled amount } in
          let rows = List.map (fun x -> if String.equal x.id id then updated else x) t.rows in
          Ok { rows }

let reduce_row t ~id ~amount =
  if Z.leq amount Z.zero then
    Error "Reduction amount must be greater than zero."
  else
    match find_row t id with
    | None -> Error (Printf.sprintf "Commitment %s not found." id)
    | Some r ->
        let rem = outstanding r in
        if Z.gt amount rem then
          Error (Printf.sprintf "Reduction amount %s exceeds remaining balance %s." (Z.to_string amount) (Z.to_string rem))
        else
          let updated = { r with extinguished = Z.add r.extinguished amount } in
          let rows = List.map (fun x -> if String.equal x.id id then updated else x) t.rows in
          Ok { rows }

let retract_row t ~id =
  match find_row t id with
  | None -> Error (Printf.sprintf "Commitment %s not found." id)
  | Some r ->
      if Z.gt r.settled Z.zero then
        Error "Cannot retract commitment with existing settlements."
      else
        let rows = List.filter (fun x -> not (String.equal x.id id)) t.rows in
        Ok { rows }

let file_path ?config_home base_path =
  match config_home with
  | Some dir -> Filename.concat dir "settlements.tsv"
  | None -> Filename.concat (Filename.dirname base_path) "settlements.tsv"

let clean_line s =
  let len = String.length s in
  let rec drop_end i =
    if i >= 0 && (s.[i] = '\r' || s.[i] = '\n') then drop_end (i - 1)
    else i
  in
  let last = drop_end (len - 1) in
  if last < 0 then "" else String.sub s 0 (last + 1)

let parse_line raw_line =
  let line = clean_line raw_line in
  if line = "" || String.starts_with ~prefix:"#" line then None
  else
    match String.split_on_char '\t' line with
    | id :: label :: debtor :: creditor :: measure :: committed :: settled :: extinguished :: rest ->
        let parse_z s = try Z.of_string s with _ -> Z.zero in
        let source_event = match rest with ev :: _ -> ev | [] -> "" in
        let source_effect = match rest with _ :: eff :: _ -> eff | _ -> "" in
        let effective_on = match rest with _ :: _ :: d :: _ when d <> "" -> Some d | _ -> None in
        let label = if label = "" then None else Some label in
        Some {
          id;
          label;
          debtor;
          creditor;
          measure;
          committed = parse_z committed;
          settled = parse_z settled;
          extinguished = parse_z extinguished;
          source_event;
          source_effect;
          effective_on;
        }
    | _ -> None

let load_file path =
  if not (Sys.file_exists path) then empty
  else
    try
      let ic = open_in path in
      let rec loop acc =
        match input_line ic with
        | line ->
            (match parse_line line with
            | Some r -> loop (r :: acc)
            | None -> loop acc)
        | exception End_of_file ->
            close_in ic;
            { rows = List.rev acc }
      in
      loop []
    with _ -> empty

let serialize_row r =
  let opt_str = function None -> "" | Some s -> s in
  String.concat "\t" [
    r.id;
    opt_str r.label;
    r.debtor;
    r.creditor;
    r.measure;
    Z.to_string r.committed;
    Z.to_string r.settled;
    Z.to_string r.extinguished;
    r.source_event;
    r.source_effect;
    opt_str r.effective_on;
  ]

let save_file path t =
  let dir = Filename.dirname path in
  let temp_path = Filename.temp_file ~temp_dir:dir ".settlements" ".tmp" in
  try
    let oc = open_out temp_path in
    output_string oc "# settlements.tsv - canonical household settlement commitments\n";
    output_string oc "# id\tlabel\tdebtor\tcreditor\tmeasure\tcommitted\tsettled\textinguished\tsource_event\tsource_effect\teffective_on\n";
    List.iter (fun r -> output_string oc (serialize_row r ^ "\n")) t.rows;
    close_out oc;
    Sys.rename temp_path path;
    Ok ()
  with exn ->
    (try Sys.remove temp_path with _ -> ());
    Error (Printexc.to_string exn)
