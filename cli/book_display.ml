(* How book values read: exact quantities, amounts grouped by three and Locus
   candidates. Read-only; nothing here saves. *)
module B = Bakhlo_household.Book

type quantity_value = Unsupported | Exact of Z.t

let quantity_value ~book ~measure locus =
  match B.quantity book ~locus ~measure with Some q -> Exact q.amount | None -> Unsupported

let format_money book measure q =
  let raw = B.format book measure q in
  let negative = String.starts_with ~prefix:"-" raw in
  let start = if negative then 1 else 0 in
  let stop = Option.value ~default:(String.length raw) (String.index_opt raw '.') in
  let out = Buffer.create (String.length raw + ((stop - start) / 3)) in
  if negative then Buffer.add_char out '-';
  for i = start to stop - 1 do
    if i > start && (stop - i) mod 3 = 0 then Buffer.add_char out ',';
    Buffer.add_char out raw.[i]
  done;
  Buffer.add_substring out raw stop (String.length raw - stop);
  Buffer.contents out

let recent_measure book ~except =
  let other m = not (List.mem m except) in
  let used (e : B.entry) =
    List.map (fun (p : B.posting) -> p.measure) e.effects
    @ Option.to_list (Option.map fst e.original_amount)
  in
  let latest =
    List.fold_left
      (fun last e -> match List.find_opt other (used e) with Some m -> Some m | None -> last)
      None (B.entries book)
  in
  match latest with
  | Some m -> m
  | None -> (
      match List.find_opt (fun (m, _) -> other m) (B.measures book) with
      | Some (m, _) -> m
      | None -> "")

let locus_candidates book query =
  let query = String.lowercase_ascii (String.trim query) in
  let choices = Option.value ~default:[] (B.approved_loci book) in
  if query = "" then choices
  else
    let is_prefix text = String.starts_with ~prefix:query (String.lowercase_ascii text) in
    let matches = List.filter (fun id -> is_prefix id || is_prefix (B.label book id)) choices in
    let exact, rest = List.partition (fun id -> String.lowercase_ascii id = query) matches in
    exact @ rest
