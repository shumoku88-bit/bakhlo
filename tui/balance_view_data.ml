(** balance_view_data.ml - Balance view configuration (balance-view.tsv) *)

type coordinate = {
  locus : string;
  measure : string;
}

type t = coordinate list

let empty = []

let valid_token s =
  s <> "" && not (String.contains s ' ') && not (String.contains s '\t')
  && not (String.contains s '\n') && not (String.contains s '\r')

let of_string text =
  let lines = String.split_on_char '\n' text in
  List.filter_map
    (fun line ->
      let line = String.trim line in
      if line = "" || String.starts_with ~prefix:";" line || String.starts_with ~prefix:"#" line then None
      else
        match String.split_on_char '\t' line with
        | [ locus; measure ] ->
            let locus = String.trim locus in
            let measure = String.trim (String.lowercase_ascii measure) in
            if valid_token locus && valid_token measure then
              Some { locus; measure }
            else None
        | _ -> None)
    lines

let to_string t =
  let lines =
    List.map (fun c -> Printf.sprintf "%s\t%s" c.locus c.measure) t
  in
  String.concat "\n" lines ^ (if lines = [] then "" else "\n")

let file_path ?config_home ledger_path =
  match config_home with
  | Some home ->
      let config_dir = Filename.concat home "config" in
      if Sys.file_exists (Filename.concat config_dir "balance-view.tsv") then
        Filename.concat config_dir "balance-view.tsv"
      else if Sys.file_exists (Filename.concat home "balance-view.tsv") then
        Filename.concat home "balance-view.tsv"
      else
        Filename.concat home "balance-view.tsv"
  | None ->
      let dir = Filename.dirname ledger_path in
      let config_dir = Filename.concat dir "config" in
      if Sys.file_exists (Filename.concat config_dir "balance-view.tsv") then
        Filename.concat config_dir "balance-view.tsv"
      else
        Filename.concat dir "balance-view.tsv"

let load_file path =
  if not (Sys.file_exists path) then empty
  else
    try
      let ic = open_in_bin path in
      let len = in_channel_length ic in
      let content = really_input_string ic len in
      close_in ic;
      of_string content
    with Sys_error _ | Unix.Unix_error _ -> empty

let save_file path t =
  try
    let content = to_string t in
    let tmp = path ^ ".tmp" in
    let oc = open_out_bin tmp in
    output_string oc content;
    flush oc;
    close_out oc;
    Sys.rename tmp path;
    Ok ()
  with Sys_error why -> Error why
