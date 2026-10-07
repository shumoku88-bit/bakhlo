(* Existing Bonsai_term state-machine/event loop; same daily actions and file owner. *)
module B = Bonsai_term
module Bonsai = B.Bonsai
module V = B.View
module C = Daily_interaction
module F = Daily_file

let fit width height view =
  let view = V.crop ~r:(max 0 (V.width view - width)) ~b:(max 0 (V.height view - height)) view in
  V.pad ~r:(max 0 (width - V.width view)) ~b:(max 0 (height - V.height view)) view

(* Default colors follow the terminal's light/dark palette; no RGB support needed. *)
let attributes = function
  | C.Plain -> []
  | C.Active -> [ B.Attr.invert; B.Attr.bold ]
  | C.Heading | C.Status -> [ B.Attr.bold ]

let render ((width, height) as dimensions) state =
  C.screen ~frontend:"Bonsai_term" dimensions state
  |> List.map (fun (style, text) -> V.text ~attrs:(attributes style) text)
  |> V.vcat |> fit width height

let input_of_event : B.Event.t -> C.input = function
  | B.Event.Paste marker -> `Paste marker
  | B.Event.Mouse _ -> `Mouse ()
  | B.Event.Key_press { key; mods } ->
      let key =
        match key with
        | Escape -> `Escape
        | Enter -> `Enter
        | Tab -> `Tab
        | Backspace -> `Backspace
        | Insert -> `Insert
        | Delete -> `Delete
        | Home -> `Home
        | End -> `End
        | Arrow direction -> `Arrow direction
        | Page direction -> `Page direction
        | Function n -> `Function n
        | ASCII c -> `ASCII c
        | Uchar c -> `Uchar c
      in
      let mods =
        List.map (function B.Event.Modifier.Meta -> `Meta | Ctrl -> `Ctrl | Shift -> `Shift) mods
      in
      `Key (key, mods)

let app initial ~exit ~dimensions graph =
  let state, inject =
    Bonsai.state_machine ~default_model:initial
      ~apply_action:(fun context state event ->
        match C.handle state (input_of_event event) with
        | Some state -> state
        | None ->
            Bonsai.Apply_action_context.schedule_event context (exit ());
            state)
      graph
  in
  let view =
    Bonsai.arr2 graph state dimensions ~f:(fun state (dimensions : B.Dimensions.t) ->
        render (dimensions.width, dimensions.height) state)
  in
  let handler = Bonsai.arr1 graph inject ~f:(fun inject event -> inject event) in
  (~view, ~handler)

let run path =
  let session = F.load path in
  F.require (Unix.isatty Unix.stdin && Unix.isatty Unix.stdout) "interactive-tty-required";
  match
    Async.Thread_safe.block_on_async_exn (fun () ->
        B.start_with_exit ~dispose:true ~mouse:B.Mouse_reporting.No_mouse_events ~bpaste:true
          (app (C.initial session)))
  with
  | Ok () -> ()
  | Error _ -> raise (F.Refused "Bonsai-terminal-unavailable")

let self_check () =
  let state = C.self_check () in
  List.iter
    (fun (style, expected) ->
      F.require
        (B.Attr.equal (B.Attr.many (attributes style)) expected)
        "Bonsai-terminal-default-style")
    [
      (C.Plain, B.Attr.empty);
      (C.Active, B.Attr.many [ B.Attr.invert; B.Attr.bold ]);
      (C.Heading, B.Attr.bold);
      (C.Status, B.Attr.bold);
    ];
  List.iter
    (fun dimensions ->
      let view = render dimensions state in
      F.require (V.width view = fst dimensions && V.height view = snd dimensions) "Bonsai-geometry")
    [ (100, 25); (64, 20); (40, 10) ];
  F.require (V.width (V.text "財布") = 4) "Bonsai-unicode-width";
  F.require
    (match
       C.handle state
         (input_of_event
            (B.Event.Key_press { key = B.Event.Key.ASCII 'Q'; mods = [ B.Event.Modifier.Ctrl ] }))
     with
    | None -> true
    | Some _ -> false)
    "Bonsai-event-adapter";
  let paste = input_of_event (B.Event.Paste `Start) in
  F.require (paste = `Paste `Start) "Bonsai-paste-adapter";
  print_endline "PASS: Bonsai terminal-default styles, daily rendering and event adapter."

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
    | _ ->
        prerr_endline
          "Usage: tools/tui bonsai --book FILE | --check FILE | --copy-from SOURCE --book \
           FRESH_FILE";
        exit 2
  with F.Refused _ | Unix.Unix_error _ | Sys_error _ ->
    prerr_endline
      "TUI refused: input/file/terminal unavailable; no empty fallback. Any attempted output \
       artifacts retained.";
    exit 1
