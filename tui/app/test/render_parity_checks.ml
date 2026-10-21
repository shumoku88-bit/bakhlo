(* Notty trial: the Notty adapter must paint exactly what the Bonsai adapter paints.
   Every synthetic Shell state, theme and terminal size is rendered by both and the
   ANSI output compared byte for byte, together with the cell-width function and
   the cursor position the Shell derives from it. *)
module B = Bonsai_terminal
module N = Notty_render
module C = Shell_state
module F = Daily_file
module P = Ui_preferences

let ansi (width, height) image =
  let buffer = Buffer.create 4096 in
  Notty.Render.to_buffer buffer Notty.Cap.ansi (0, 0) (width, height) image;
  Buffer.contents buffer

let samples =
  [
    "";
    "Record";
    "財布 現金";
    "│ Date: x|y │";
    "╭ Record ─╮";
    "control \001 \t \127 and \194\128";
    "malformed \255 byte";
    "emoji 🐹 and ｶﾅ";
  ]

let run () =
  List.iter
    (fun text ->
      F.require (B.width_of text = N.width_of text) ("Notty-width-parity:" ^ String.escaped text))
    samples;
  let directory = "scratch/render-parity-" ^ F.new_id () in
  Unix.mkdir directory 0o700;
  let path = directory ^ "/book.sexp" in
  F.create_copy ~source:Interaction_check_fixture.example_book ~target:path;
  let state = C.initial ~config_home:directory (F.load path) in
  let compared = ref 0 and bonsai_time = ref 0.0 and notty_time = ref 0.0 in
  let timed total f =
    let start = Unix.gettimeofday () in
    let result = f () in
    total := !total +. (Unix.gettimeofday () -. start);
    result
  in
  List.iter
    (fun theme ->
      List.iter
        (fun dimensions ->
          List.iter
            (fun case ->
              let case = { case with C.theme } in
              let bonsai =
                timed bonsai_time (fun () ->
                    ansi dimensions (Bonsai_term.View.Private.notty_image (B.render dimensions case)))
              in
              let notty = timed notty_time (fun () -> ansi dimensions (N.render dimensions case)) in
              incr compared;
              F.require (bonsai = notty)
                (Printf.sprintf "Notty-render-parity:%dx%d:%s" (fst dimensions) (snd dimensions)
                   (match theme with P.Terminal -> "terminal" | P.Bakhlo_light -> "light" | P.Bakhlo_dark -> "dark")))
            (Interaction_render_fixture.render_cases state))
        [ (140, 40); (100, 25); (80, 24); (64, 20); (48, 14); (40, 10); (32, 9); (20, 5) ])
    P.all_themes;
  Printf.printf
    "PASS: Notty adapter paints byte-identical ANSI to Bonsai for %d theme/size/state cases and \
     the sample cell widths (paint+ANSI: Bonsai %.2f ms, Notty %.2f ms per frame).\n"
    !compared
    (1000. *. !bonsai_time /. float !compared)
    (1000. *. !notty_time /. float !compared)
