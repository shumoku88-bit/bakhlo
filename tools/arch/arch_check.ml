(* Architecture check for the TUI tree. Usage: arch_check ROOT

   The compiler and Dune enforce most boundaries once each layer is its own
   library with implicit_transitive_deps disabled. This check pins the parts
   Dune cannot see: which library may depend on which, that no source file
   escapes its Dune stanza, that pure layers perform no file I/O, that the
   Shell does not re-absorb a migrated screen's private vocabulary, and that
   every check module is actually run. See tui/README.md. *)

module Sexp = Sexplib0.Sexp

type layer =
  | Kit
  | Book
  | Protocol
  | Screen of string
  | Screen_test of string
  | Shell
  | Shell_test
  | Scenarios
  | App
  | App_test

let layer_name = function
  | Kit -> "kit"
  | Book -> "book"
  | Protocol -> "protocol"
  | Screen s -> "screen " ^ s
  | Screen_test s -> "screen test " ^ s
  | Shell -> "shell"
  | Shell_test -> "shell test"
  | Scenarios -> "scenarios"
  | App -> "terminal app"
  | App_test -> "terminal app test"

(* Directory names under tui/ decide the layer; an unknown directory is an
   error so that a new layer is an explicit architecture decision. *)
let layer_of_dir = function
  | [ "kit" ] -> Ok Kit
  | [ "book" ] -> Ok Book
  | [ "protocol" ] -> Ok Protocol
  | [ "screens"; s ] -> Ok (Screen s)
  | [ "screens"; s; "test" ] -> Ok (Screen_test s)
  | [ "shell" ] -> Ok Shell
  | [ "shell"; "test" ] -> Ok Shell_test
  | [ "scenarios" ] -> Ok Scenarios
  | [ "app" ] -> Ok App
  | [ "app"; "test" ] -> Ok App_test
  | parts -> Error ("unknown TUI layer directory tui/" ^ String.concat "/" parts)

let rank = function
  | Kit -> 0
  | Book -> 1
  | Protocol -> 2
  | Screen _ -> 3
  | Screen_test _ -> 4
  | Shell -> 5
  | Shell_test -> 6
  | Scenarios -> 7
  | App -> 8
  | App_test -> 9

(* The writer and operating-system access belong to the Shell and above; the
   terminal runtime belongs to the Bonsai adapter only. *)
let shell_only = [ "bakhlo.store"; "unix" ]
let terminal_only = [ "bonsai_term"; "async"; "core"; "notty-community" ]
let is_shell_or_above layer = rank layer >= rank Shell
let is_terminal = function App | App_test -> true | _ -> false

(* File access and writing in pure layers. Comments and literals are ignored. *)
let forbidden_tokens =
  [ "Durable_append"; "open_out"; "open_out_bin"; "open_out_gen"; "Out_channel";
    "open_in"; "open_in_bin"; "open_in_gen"; "In_channel"; "Sys.rename"; "Sys.remove";
    "Sys.mkdir"; "Sys.rmdir"; "Sys.file_exists"; "Sys.readdir"; "Filename.temp_file";
    "Daily_file"; "Daily_actions" ]

(* Literals still shared with legacy Shell workflows that have not moved to a
   screen owner yet. Migration debt: this list may only shrink. *)
let legacy_shared_literals = [ "boundary-presets.tsv"; "balance-view.tsv" ]

type stanza = { kind : string; names : string list; libraries : string list; dir : string list }

let errors = ref []
let fail fmt = Printf.ksprintf (fun s -> errors := s :: !errors) fmt

let read path = In_channel.with_open_bin path In_channel.input_all

let rec walk root rel =
  let path = Filename.concat root (String.concat "/" rel) in
  let entries = Sys.readdir path |> Array.to_list |> List.sort compare in
  let here = (rel, entries) in
  here
  :: List.concat_map
       (fun e ->
         if Sys.is_directory (Filename.concat path e) && e.[0] <> '.' && e.[0] <> '_' then
           walk root (rel @ [ e ])
         else [])
       entries

let atoms = List.filter_map (function Sexp.Atom a -> Some a | Sexp.List _ -> None)

let field name fields =
  List.find_map
    (function Sexp.List (Sexp.Atom n :: rest) when n = name -> Some rest | _ -> None)
    fields

let stanzas_of ~where ~dir text =
  match Parsexp.Many.parse_string text with
  | Error e -> fail "%s: %s" where (Parsexp.Parse_error.message e); []
  | Ok sexps ->
      List.filter_map
        (function
          | Sexp.List (Sexp.Atom kind :: fields)
            when List.mem kind [ "library"; "executable"; "executables"; "test"; "tests" ] ->
              let names =
                match field "name" fields, field "names" fields with
                | Some n, _ | None, Some n -> atoms n
                | None, None -> []
              in
              let libraries = Option.value ~default:[] (Option.map atoms (field "libraries" fields)) in
              Some { kind; names; libraries; dir }
          | _ -> None)
        sexps

(* Split source into code (comments and literals blanked) and string literals. *)
let lex text =
  let code = Buffer.create (String.length text) and literal = Buffer.create 32 in
  let literals = ref [] in
  let n = String.length text in
  let rec code_at i depth =
    if i >= n then ()
    else if i + 1 < n && text.[i] = '(' && text.[i + 1] = '*' then code_at (i + 2) (depth + 1)
    else if depth > 0 && i + 1 < n && text.[i] = '*' && text.[i + 1] = ')' then code_at (i + 2) (depth - 1)
    else if depth > 0 && text.[i] = '"' then skip_string (i + 1) depth
    else if depth > 0 then code_at (i + 1) depth
    else if text.[i] = '"' then (Buffer.add_char code ' '; Buffer.clear literal; string_at (i + 1))
    else if text.[i] = '\'' && i + 2 < n && text.[i + 2] = '\'' then code_at (i + 3) depth
    else if text.[i] = '\'' && i + 3 < n && text.[i + 1] = '\\' && text.[i + 3] = '\'' then
      code_at (i + 4) depth
    else (Buffer.add_char code text.[i]; code_at (i + 1) depth)
  and string_at i =
    if i >= n then ()
    else if text.[i] = '\\' && i + 1 < n then (Buffer.add_char literal text.[i];
      Buffer.add_char literal text.[i + 1]; string_at (i + 2))
    else if text.[i] = '"' then (literals := Buffer.contents literal :: !literals; code_at (i + 1) 0)
    else (Buffer.add_char literal text.[i]; string_at (i + 1))
  and skip_string i depth =
    if i >= n then ()
    else if text.[i] = '\\' then skip_string (i + 2) depth
    else if text.[i] = '"' then code_at (i + 1) depth
    else skip_string (i + 1) depth
  in
  code_at 0 0;
  (Buffer.contents code, List.rev !literals)

let code_only text = fst (lex text)
let literals text = snd (lex text)

let contains_token code token =
  let re = Str.regexp ("\\(^\\|[^A-Za-z0-9_'.]\\)" ^ Str.quote token ^ "\\($\\|[^A-Za-z0-9_']\\)") in
  match Str.search_forward re code 0 with _ -> true | exception Not_found -> false

(* Configuration files and form identities a screen owns. *)
let owned_literals text =
  let files = List.filter (fun s -> Filename.check_suffix s ".tsv" && not (String.contains s ' ')) (literals text) in
  let ids =
    let re = Str.regexp {|~id:"\([a-z][a-z0-9_]*\)"|} in
    let rec loop pos acc =
      match Str.search_forward re text pos with
      | exception Not_found -> acc
      | _ -> loop (Str.match_end ()) (Str.matched_group 1 text :: acc)
    in
    List.filter (fun id -> String.contains id '_') (loop 0 [])
  in
  files @ ids

let capitalize = String.capitalize_ascii

let () =
  let root = if Array.length Sys.argv > 1 then Sys.argv.(1) else "." in
  let tui = Filename.concat root "tui" in
  if not (Sys.file_exists tui && Sys.is_directory tui) then (prerr_endline "arch_check: no tui directory"; exit 2);
  (* 0. Core never depends on the TUI. *)
  let is_tui_library name =
    String.starts_with ~prefix:"bakhlo_tui" name || String.starts_with ~prefix:"bakhlo_screen" name
  in
  List.iter
    (fun top ->
      let path = Filename.concat root top in
      if Sys.is_directory path && top.[0] <> '.' && top.[0] <> '_'
         && not (List.mem top [ "tui"; "scratch"; "experiments" ]) then
        List.iter
          (fun (rel, entries) ->
            if List.mem "dune" entries then
              let dir = top :: rel in
              let file = String.concat "/" (dir @ [ "dune" ]) in
              List.iter
                (fun s ->
                  List.iter
                    (fun dep -> if is_tui_library dep then fail "%s: Core may not depend on %s" file dep)
                    s.libraries)
                (stanzas_of ~where:file ~dir (read (Filename.concat root file))))
          (walk path []))
    (Sys.readdir root |> Array.to_list |> List.sort compare);
  let dirs = walk tui [] in
  let sources (rel, entries) =
    List.filter (fun e -> Filename.check_suffix e ".ml" || Filename.check_suffix e ".mli") entries
    |> List.map (fun e -> (rel, e, read (Filename.concat tui (String.concat "/" (rel @ [ e ])))))
  in
  (* 1. Every source file belongs to a known layer and a Dune stanza. *)
  let layered =
    List.filter_map
      (fun ((rel, entries) as d) ->
        let srcs = sources d in
        if rel = [] then (
          if srcs <> [] then fail "tui/: source files must live in a layer directory";
          None)
        else if srcs = [] && not (List.mem "dune" entries) then None
        else
          match layer_of_dir rel with
          | Error why -> fail "%s" why; None
          | Ok layer ->
              if not (List.mem "dune" entries) then
                fail "tui/%s: sources without a dune file are never built" (String.concat "/" rel);
              let stanzas =
                if List.mem "dune" entries then
                  stanzas_of ~where:("tui/" ^ String.concat "/" (rel @ [ "dune" ])) ~dir:rel (read (Filename.concat tui (String.concat "/" (rel @ [ "dune" ]))))
                else []
              in
              Some (layer, rel, srcs, stanzas))
      dirs
  in
  let library_layer =
    List.concat_map
      (fun (layer, _, _, stanzas) ->
        List.concat_map (fun s -> if s.kind = "library" then List.map (fun n -> (n, (layer, s.dir))) s.names else []) stanzas)
      layered
  in
  (* 2. Library dependencies follow the layer order. *)
  List.iter
    (fun (layer, rel, _, stanzas) ->
      let where = "tui/" ^ String.concat "/" rel in
      List.iter
        (fun s ->
          List.iter
            (fun dep ->
              (match List.assoc_opt dep library_layer with
               | None -> ()
               | Some (_, dep_dir) when dep_dir = rel -> ()
               | Some (target, _) ->
                   let allowed =
                     match layer, target with
                     | Screen _, Screen _ -> false
                     | Screen_test a, Screen b -> a = b
                     | Screen_test _, Screen_test _ -> false
                     | (Shell | Shell_test | Scenarios | App | App_test), _ -> rank target < rank layer
                     | _ -> rank target < rank layer && (match target with Screen _ -> false | _ -> true)
                   in
                   if not allowed then
                     fail "%s: %s may not depend on %s (%s)" where (layer_name layer) dep (layer_name target));
              if List.mem dep shell_only && not (is_shell_or_above layer) then
                fail "%s: %s may not depend on %s (Shell and above only)" where (layer_name layer) dep;
              if List.mem dep terminal_only && not (is_terminal layer) then
                fail "%s: %s may not depend on %s (terminal adapter only)" where (layer_name layer) dep)
            s.libraries)
        stanzas)
    layered;
  (* 3. Pure layers perform no file access or writing. *)
  List.iter
    (fun (layer, rel, srcs, _) ->
      match layer with
      | Kit | Book | Protocol | Screen _ ->
          List.iter
            (fun (_, file, text) ->
              let code = code_only text in
              List.iter
                (fun token ->
                  if contains_token code token then
                    fail "tui/%s/%s: %s layer may not use %s" (String.concat "/" rel) file
                      (layer_name layer) token)
                forbidden_tokens)
            srcs
      | Screen_test _ | Shell | Shell_test | Scenarios | App | App_test -> ())
    layered;
  (* 4. The Shell does not take back a migrated screen's files or forms. *)
  let owned =
    List.concat_map
      (fun (layer, _, srcs, _) ->
        match layer with
        | Screen s -> List.concat_map (fun (_, _, text) -> List.map (fun l -> (l, s)) (owned_literals text)) srcs
        | _ -> [])
      layered
  in
  List.iter
    (fun (layer, rel, srcs, _) ->
      if layer = Shell then
        List.iter
          (fun (_, file, text) ->
            List.iter
              (fun literal ->
                match List.assoc_opt literal owned with
                | Some screen when not (List.mem literal legacy_shared_literals) ->
                    fail "tui/%s/%s: \"%s\" belongs to screen %s" (String.concat "/" rel) file literal screen
                | _ -> ())
              (literals text))
          srcs)
    layered;
  (* 5. Every check module is run by its test executable. *)
  List.iter
    (fun (_, rel, srcs, stanzas) ->
      let mains = List.concat_map (fun s -> if s.kind <> "library" then s.names else []) stanzas in
      if mains <> [] then
        List.iter
          (fun (_, file, _) ->
            let m = Filename.remove_extension file in
            if Filename.check_suffix file ".ml" && Filename.check_suffix m "_checks" && not (List.mem m mains) then
              let referenced =
                List.exists
                  (fun main ->
                    match List.find_opt (fun (_, f, _) -> f = main ^ ".ml") srcs with
                    | Some (_, _, text) -> contains_token (code_only text) (capitalize m)
                    | None -> false)
                  mains
              in
              if not referenced then
                fail "tui/%s/%s: check module is not run by %s" (String.concat "/" rel) file
                  (String.concat ", " mains))
          srcs)
    layered;
  match List.rev !errors with
  | [] -> print_endline "arch_check: ok"
  | errors -> List.iter prerr_endline errors; exit 1
