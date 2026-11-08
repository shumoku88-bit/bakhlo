(* The sample files are the specification; this reader knows no household rules. *)
type context = (string * string option) list
type question = { header : string list; body : string list; line : int }
type counts = { mutable answers : int; mutable failures : int; kinds : (string, int) Hashtbl.t }

exception Bad_sample of string

let bad why = raise (Bad_sample why)
let fields = String.split_on_char '\t'
let row = String.concat "\t"
let read dir name = In_channel.with_open_bin (Filename.concat dir name) In_channel.input_all
let create () = { answers = 0; failures = 0; kinds = Hashtbl.create 16 }

let count counts kind =
  Hashtbl.replace counts.kinds kind
    (1 + Option.value ~default:0 (Hashtbl.find_opt counts.kinds kind))

let counted counts kind = Option.value ~default:0 (Hashtbl.find_opt counts.kinds kind)
let context use name = Option.join (List.assoc_opt name use)
let note line = line = "" || String.starts_with ~prefix:"#" line

let rec split_at stop = function
  | [] -> ([], [])
  | line :: rest when stop (fields line) -> ([], line :: rest)
  | line :: rest ->
      let before, after = split_at stop rest in
      (line :: before, after)

let values key lines =
  List.filter_map
    (fun line -> match fields line with [ k; v ] when k = key -> Some v | _ -> None)
    lines

let fail counts path line why =
  counts.failures <- counts.failures + 1;
  Printf.printf "FAIL %s:%d: %s\n" path line why

let equal counts ~path ~want ~got =
  if want <> got then
    let rec first line want got =
      match (want, got) with
      | w :: ws, g :: gs when w = g -> first (line + 1) ws gs
      | w :: _, g :: _ -> (line, w, g)
      | [], g :: _ -> (line, "<EOF>", g)
      | w :: _, [] -> (line, w, "<EOF>")
      | [], [] -> assert false
    in
    let line, want, got =
      first 1 (String.split_on_char '\n' want) (String.split_on_char '\n' got)
    in
    fail counts path line (Printf.sprintf "want %S, got %S" want got)

(* Notes keep their physical positions, but never reach an answer function. *)
let rec with_notes original printed =
  match (original, printed) with
  | [], rest -> rest
  | line :: rest, _ when note line -> line :: with_notes rest printed
  | _ :: rest, line :: printed -> line :: with_notes rest printed
  | _ :: rest, [] -> with_notes rest []

let render counts ~path ~line ~use ~blocks ~answer text =
  let rec loop use line = function
    | [] -> []
    | raw :: rest when note raw -> raw :: loop use (line + 1) rest
    | raw :: rest -> (
        let header = fields raw in
        let at () =
          match header with
          | [ "USE"; name; file ] ->
              let value = if file = "-" then None else Some file in
              raw :: loop ((name, value) :: List.remove_assoc name use) (line + 1) rest
          | "USE" :: _ -> bad "USE needs a name and a file or -"
          | kind :: _ ->
              let original, body, rest, next =
                if List.mem kind blocks then
                  let body, ending = split_at (fun fs -> fs = [ "END" ^ kind ]) rest in
                  match ending with
                  | [] -> bad ("missing END" ^ kind)
                  | stop :: rest ->
                      ( (raw :: body) @ [ stop ],
                        List.filter (fun s -> not (note s)) body,
                        rest,
                        line + List.length body + 2 )
                else ([ raw ], [], rest, line + 1)
              in
              counts.answers <- counts.answers + 1;
              count counts kind;
              let printed = answer use { header; body; line } in
              let printed = if List.mem kind blocks then printed @ [ "END" ^ kind ] else printed in
              with_notes original printed @ loop use next rest
          | [] -> assert false
        in
        try at () with Bad_sample why -> bad (Printf.sprintf "%s:%d: %s" path line why))
  in
  String.concat "\n" (loop use line (String.split_on_char '\n' text))

let check counts ~dir ~file ~blocks ~answer =
  let path = Filename.concat dir file in
  try
    let want = read dir file in
    equal counts ~path ~want ~got:(render counts ~path ~line:1 ~use:[] ~blocks ~answer want)
  with Bad_sample why | Sys_error why -> fail counts path 1 why

let run counts ~dir ~blocks ~answer =
  Sys.readdir dir |> Array.to_list
  |> List.filter (fun file -> Filename.check_suffix file ".answers")
  |> List.sort String.compare
  |> List.iter (fun file -> check counts ~dir ~file ~blocks ~answer)
