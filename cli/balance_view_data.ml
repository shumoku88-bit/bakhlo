(* Which balances the household looks at: balance-view.tsv.

   One account and one Measure per line, separated by a tab, in the order the
   balances are shown:

     cash\tjpy
     smbc\tjpy

   Bakhlo writes this file itself (Balances, [c]) and never writes a comment or
   a blank line, so a line of any other shape means the file was changed by hand
   or damaged. Then the whole file is refused: showing some of the balances
   would let a missing account pass for one that is not chosen. `bk bal`, the
   Balances screen, Stock–Flow and Liquidity all read it here, so they accept
   and refuse the same files. *)

type coordinate = { locus : string; measure : string }
type t = coordinate list

let valid_token s = s <> "" && String.for_all (fun c -> Char.code c > 32 && Char.code c <> 127) s

let of_string text =
  let lines = String.split_on_char '\n' text in
  let lines = match List.rev lines with "" :: rest -> List.rev rest | _ -> lines in
  let rec parse acc = function
    | [] -> Ok (List.rev acc)
    | line :: rest -> (
        match String.split_on_char '\t' line with
        | [ locus; measure ] when valid_token locus && valid_token measure ->
            parse ({ locus; measure } :: acc) rest
        | _ -> Error "Malformed balance-view.tsv; no coordinates were inferred.")
  in
  parse [] lines

let to_string t =
  let lines = List.map (fun c -> Printf.sprintf "%s\t%s" c.locus c.measure) t in
  String.concat "\n" lines ^ if lines = [] then "" else "\n"
