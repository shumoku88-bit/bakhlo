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
type t = { rows : row list }

let empty = { rows = [] }
let outstanding r = Z.sub (Z.sub r.committed r.settled) r.extinguished
let is_open r = Z.gt (outstanding r) Z.zero
let open_rows t = List.filter is_open t.rows
let visible_rows t = function Open_only -> open_rows t | All -> t.rows
let find_row t id = List.find_opt (fun r -> String.equal r.id id) t.rows

let next_id t =
  let count = List.length t.rows + 1 in
  let rec find_unused n =
    let candidate = Printf.sprintf "comm-%d" n in
    if List.exists (fun r -> String.equal r.id candidate) t.rows then find_unused (n + 1)
    else candidate
  in
  find_unused count

let valid_token s = s <> "" && String.for_all (fun c -> Char.code c > 32 && Char.code c <> 127) s

let valid_row r =
  List.for_all valid_token [ r.id; r.debtor; r.creditor; r.measure ]
  && (match r.label with
    | None -> true
    | Some label -> not (String.exists (fun c -> c = '\t' || c = '\n' || c = '\r') label))
  && (match r.effective_on with
    | None -> true
    | Some day -> (
        match Day.normalize day with Ok canonical -> canonical = day | Error _ -> false))
  && ((r.source_event = "" && r.source_effect = "")
     || (valid_token r.source_event && valid_token r.source_effect))
  && Z.gt r.committed Z.zero && Z.geq r.settled Z.zero && Z.geq r.extinguished Z.zero
  && Z.geq (outstanding r) Z.zero

let add_row t ~id ?label ~debtor ~creditor ~measure ~committed ?(source_event = "")
    ?(source_effect = "") ?effective_on () =
  if List.exists (fun r -> String.equal r.id id) t.rows then
    Error (Printf.sprintf "Commitment with ID %s already exists." id)
  else if Z.leq committed Z.zero then Error "Committed amount must be greater than zero."
  else
    let new_row =
      {
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
      }
    in
    if valid_row new_row then Ok { rows = t.rows @ [ new_row ] }
    else Error "Invalid settlement commitment."

(* [apply] a positive [amount] no larger than the commitment's remaining balance;
   [noun] names the amount in the refusals. *)
let take_from_outstanding t ~id ~amount ~nonpositive ~noun apply =
  if Z.leq amount Z.zero then Error nonpositive
  else
    match find_row t id with
    | None -> Error (Printf.sprintf "Commitment %s not found." id)
    | Some r ->
        let rem = outstanding r in
        if Z.gt amount rem then
          Error
            (Printf.sprintf "%s %s exceeds remaining balance %s." noun (Z.to_string amount)
               (Z.to_string rem))
        else
          let updated = apply r in
          let rows = List.map (fun x -> if String.equal x.id id then updated else x) t.rows in
          Ok { rows }

let settle_row t ~id ~amount =
  take_from_outstanding t ~id ~amount ~nonpositive:"Settlement amount must be greater than zero."
    ~noun:"Amount" (fun r -> { r with settled = Z.add r.settled amount })

let reduce_row t ~id ~amount =
  take_from_outstanding t ~id ~amount ~nonpositive:"Reduction amount must be greater than zero."
    ~noun:"Reduction amount" (fun r -> { r with extinguished = Z.add r.extinguished amount })

let retract_row t ~id =
  match find_row t id with
  | None -> Error (Printf.sprintf "Commitment %s not found." id)
  | Some r ->
      if Z.gt r.settled Z.zero then Error "Cannot retract commitment with existing settlements."
      else
        let rows = List.filter (fun x -> not (String.equal x.id id)) t.rows in
        Ok { rows }

let clean_line s =
  let len = String.length s in
  let rec drop_end i = if i >= 0 && (s.[i] = '\r' || s.[i] = '\n') then drop_end (i - 1) else i in
  let last = drop_end (len - 1) in
  if last < 0 then "" else String.sub s 0 (last + 1)

let parse_line raw_line =
  let line = clean_line raw_line in
  if line = "" || String.starts_with ~prefix:"#" line then Ok None
  else
    match String.split_on_char '\t' line with
    | id :: label :: debtor :: creditor :: measure :: committed :: settled :: extinguished :: rest
      when List.length rest <= 3 -> (
        try
          let source_event = match rest with ev :: _ -> ev | [] -> "" in
          let source_effect = match rest with _ :: eff :: _ -> eff | _ -> "" in
          let effective_on =
            match rest with _ :: _ :: d :: _ when d <> "" -> Some d | _ -> None
          in
          let label = if label = "" then None else Some label in
          let row =
            {
              id;
              label;
              debtor;
              creditor;
              measure;
              committed = Z.of_string committed;
              settled = Z.of_string settled;
              extinguished = Z.of_string extinguished;
              source_event;
              source_effect;
              effective_on;
            }
          in
          if valid_row row then Ok (Some row) else Error "Invalid settlement quantities or fields."
        with Invalid_argument _ -> Error "Invalid settlement quantity.")
    | _ -> Error "Malformed or unsupported settlement row."

let of_string text =
  let rec parse rows = function
    | [] -> Ok { rows = List.rev rows }
    | line :: rest ->
        Result.bind (parse_line line) (function
          | None -> parse rows rest
          | Some row ->
              if List.exists (fun r -> r.id = row.id) rows then Error "Duplicate settlement ID."
              else parse (row :: rows) rest)
  in
  parse [] (String.split_on_char '\n' text)
