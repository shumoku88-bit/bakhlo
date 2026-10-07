(* Notty drawing and event loop; daily-book actions are shared with Bonsai. *)
open Notty
module C = Daily_interaction
module F = Daily_file

let input_of_event = function
  | `Key event -> (`Key event : C.input)
  | `Paste marker -> `Paste marker
  | `End -> `End
  | `Resize _ -> `Resize ()
  | `Mouse _ -> `Mouse ()

(* Default colors follow the terminal's light/dark palette; no RGB support needed. *)
let attribute = function
  | C.Plain -> A.empty
  | C.Active -> A.(st reverse ++ st bold)
  | C.Heading | C.Status -> A.st A.bold

let render ((width, height) as dimensions) state =
  C.screen ~frontend:"Notty" dimensions state
  |> List.map (fun (style, text) -> I.string (attribute style) text)
  |> I.vcat |> I.hsnap ~align:`Left width |> I.vsnap ~align:`Top height

let run path =
  let session = F.load path in
  F.require (Unix.isatty Unix.stdin && Unix.isatty Unix.stdout) "interactive-tty-required";
  let terminal = Notty_unix.Term.create ~mouse:false ~bpaste:true () in
  Fun.protect
    ~finally:(fun () -> Notty_unix.Term.release terminal)
    (fun () ->
      let rec loop state =
        Notty_unix.Term.image terminal (render (Notty_unix.Term.size terminal) state);
        match C.handle state (input_of_event (Notty_unix.Term.event terminal)) with
        | None -> ()
        | Some state -> loop state
      in
      loop (C.initial session))

let self_check () =
  let state = C.self_check () in
  List.iter
    (fun (style, expected) ->
      F.require (A.equal (attribute style) expected) "Notty-terminal-default-style")
    [
      (C.Plain, A.empty);
      (C.Active, A.(st reverse ++ st bold));
      (C.Heading, A.st A.bold);
      (C.Status, A.st A.bold);
    ];
  List.iter
    (fun dimensions ->
      let view = render dimensions state in
      F.require (I.width view = fst dimensions && I.height view = snd dimensions) "Notty-geometry")
    [ (100, 25); (64, 20); (40, 10) ];
  F.require (I.width (I.string A.empty "財布") = 4) "Notty-unicode-width";
  F.require
    (match C.handle state (input_of_event (`Key (`ASCII 'Q', [ `Ctrl ]))) with
    | None -> true
    | Some _ -> false)
    "Notty-event-adapter";
  print_endline "PASS: Notty terminal-default styles, daily rendering and event adapter."

let () =
  try
    match Array.to_list Sys.argv with
    | [ _; "--self-check" ] -> self_check ()
    | [ _; "--book"; path ] -> run path
    | [ _; "--check"; path ] ->
        ignore (F.load path);
        print_endline "PASS: daily book admitted (no payload output)."
    | [ _; "--copy-from"; source; "--book"; target ] ->
        F.create_copy ~source ~target;
        print_endline "PASS: fresh trial copy created; original unchanged."
    | [ _; "--snapshot"; path ] ->
        Notty_unix.output_image ~cap:Cap.dumb (render (100, 25) (C.initial (F.load path)))
    | _ ->
        prerr_endline
          "Usage: tools/tui [notty] --book FILE | --check FILE | --copy-from SOURCE --book \
           FRESH_FILE";
        exit 2
  with F.Refused _ | Unix.Unix_error _ | Sys_error _ ->
    prerr_endline
      "TUI refused: input/file/terminal unavailable; no empty fallback. Any attempted output \
       artifacts retained.";
    exit 1
