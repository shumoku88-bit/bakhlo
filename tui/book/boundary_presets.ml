type preset = string * string list

let token text = text <> "" && String.for_all (fun c -> Char.code c > 32 && Char.code c <> 127) text

let canonical day =
  match Daily_draft.normalize_date day with Ok normalized -> normalized = day | Error _ -> false

let rec increasing = function
  | a :: (b :: _ as rest) -> a < b && increasing rest
  | [] | [ _ ] -> true

let parse text =
  let lines =
    String.split_on_char '\n' text |> List.map String.trim
    |> List.filter (fun line -> line <> "" && not (String.starts_with ~prefix:"#" line))
  in
  let rec loop names acc = function
    | [] -> Ok (List.rev acc)
    | line :: rest -> (
        match String.split_on_char '\t' line with
        | name :: dates
          when token name
               && (not (List.mem name names))
               && List.length dates >= 2
               && List.for_all canonical dates && increasing dates ->
            loop (name :: names) ((name, dates) :: acc) rest
        | _ -> Error ())
  in
  loop [] [] lines

let windows presets =
  let rec pairs name = function
    | a :: (b :: _ as rest) -> (name, a, b) :: pairs name rest
    | _ -> []
  in
  List.concat_map (fun (name, dates) -> pairs name dates) presets

let containing day presets = List.filter (fun (_, a, b) -> a <= day && day < b) (windows presets)
