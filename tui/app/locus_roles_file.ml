(* File access for accounting-roles.tsv. Legacy direct writer used only by the
   Loci workflow; it is replaced by the Shell's checked configuration save. *)
module Roles = Locus_roles

let file_path ?config_home ledger_path =
  match config_home with
  | Some home -> Filename.concat home "accounting-roles.tsv"
  | None ->
      let dir = Filename.dirname ledger_path in
      Filename.concat dir "accounting-roles.tsv"

let load_file path : Roles.t =
  if not (Sys.file_exists path) then Roles.empty
  else
    try
      let ic = open_in_bin path in
      let len = in_channel_length ic in
      let content = really_input_string ic len in
      close_in ic;
      Roles.of_string content
    with Sys_error _ | Unix.Unix_error _ -> Roles.empty

let save_file path t =
  try
    let content = Roles.to_string t in
    let tmp = path ^ ".tmp" in
    let oc = open_out_bin tmp in
    output_string oc content;
    flush oc;
    close_out oc;
    Sys.rename tmp path;
    Ok ()
  with Sys_error why -> Error why
