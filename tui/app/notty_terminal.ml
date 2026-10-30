(* Notty terminal loop: the Shell driven by Notty_unix, painted by Notty_render.
   Same daily actions and file owner as the Bonsai adapter. *)
module Term = Notty_unix.Term
module C = Shell_state
module H = Shell_input
module R = Shell_view
module F = Book_file
module P = Ui_preferences
module N = Notty_render

(* What the terminal shows: its size, each row as the bytes that drew it, the cursor. *)
type shown = { size : int * int; rows : string array; cursor : (int * int) option }

(* Only the rows that differ from the screen are sent, as a full-screen editor does:
   Notty would redraw every row for each key (8-9 KB at 174x43), and the terminal
   then redraws every line. A frame is wrapped in synchronized output (DEC mode
   2026), which a terminal shows only once complete and one without the mode
   ignores. With Notty's dumb capability (TERM unset, empty or dumb) the frame goes
   through Notty whole, as before. *)
let ansi = match Sys.getenv_opt "TERM" with None | Some ("" | "dumb") -> false | Some _ -> true
let write text = ignore (Unix.write_substring Unix.stdout text 0 (String.length text))

let rows_of (width, height) image =
  Array.init height (fun y ->
      let row = Buffer.create 256 in
      Notty.Render.to_buffer row Notty.Cap.ansi (0, y) (width, 1) image;
      Buffer.contents row)

(* The bytes that bring the screen [before] to [rows] at [size]: each changed row,
   placed at its start. All rows after a resize or before the first frame. *)
let changed_rows ~before size rows =
  let frame = Buffer.create 16384 in
  Array.iteri
    (fun y row ->
      match before with
      | Some before when before.size = size && before.rows.(y) = row -> ()
      | _ -> Printf.bprintf frame "\027[%d;1H%s" (y + 1) row)
    rows;
  Buffer.contents frame

let show term ~before (size, image, cursor) =
  if not ansi then (
    Term.image term image;
    Term.cursor term cursor;
    None)
  else
    let rows = rows_of size image in
    let frame = changed_rows ~before size rows in
    let moved = match before with Some before -> before.cursor <> cursor | None -> true in
    if frame <> "" || moved then (
      write "\027[?2026h\027[?25l";
      Fun.protect
        ~finally:(fun () -> write "\027[?2026l")
        (fun () ->
          write frame;
          Term.cursor term cursor));
    Some { size; rows; cursor }

(* stty on the terminal, its output, or [None] when it cannot run or refuses. *)
let stty args =
  match Unix.pipe ~cloexec:true () with
  | exception Unix.Unix_error _ -> None
  | output, input -> (
      let quiet = Unix.openfile "/dev/null" [ Unix.O_WRONLY; Unix.O_CLOEXEC ] 0 in
      let started =
        Fun.protect
          ~finally:(fun () ->
            Unix.close input;
            Unix.close quiet)
          (fun () ->
            try
              Some
                (Unix.create_process "/bin/stty"
                   (Array.of_list ("stty" :: args))
                   Unix.stdin input quiet)
            with Unix.Unix_error _ -> None)
      in
      let text = In_channel.input_all (Unix.in_channel_of_descr output) in
      Unix.close output;
      match started with
      | None -> None
      | Some pid -> (
          match Unix.waitpid [] pid with _, Unix.WEXITED 0 -> Some (String.trim text) | _ -> None))

(* macOS gives Ctrl-O to the terminal driver (VDISCARD) while IEXTEN is on, which
   Notty leaves set, so the Record's Ctrl-O would never arrive. The session unsets
   it and afterwards restores the exact previous settings. Without a terminal or
   stty nothing changes. *)
let with_ctrl_o f =
  match if Unix.isatty Unix.stdin then stty [ "-g" ] else None with
  | None -> f ()
  | Some saved ->
      ignore (stty [ "discard"; "undef" ]);
      Fun.protect ~finally:(fun () -> ignore (stty [ saved ])) f

(* One terminal session: paint, wait for an event, let [step] decide. Every event
   reads the current terminal size, so a resize and a key never use stale geometry.
   A key that changes nothing sends nothing; a resize redraws every row. *)
let terminal_loop ~paint ~step initial =
  with_ctrl_o @@ fun () ->
  let term = Term.create ~dispose:true ~mouse:false ~bpaste:true () in
  let shown = ref None in
  let rec loop state =
    let dimensions = Term.size term in
    let image, cursor = paint dimensions state in
    shown := show term ~before:!shown (dimensions, image, cursor);
    match Term.event term with
    | `End -> state
    | `Resize _ ->
        shown := None;
        loop state
    | #Notty.Unescape.event as event -> (
        match step (Term.size term) state (N.input_of_event event) with
        | Some next -> loop next
        | None -> state)
  in
  Fun.protect ~finally:(fun () -> Term.release term) (fun () -> loop initial)

let run_shell session =
  ignore
    (terminal_loop
       ~paint:(fun dimensions state ->
         (N.render dimensions state, R.cursor_position ~width_of:N.width_of dimensions state))
       ~step:(fun dimensions state input -> H.handle ~dimensions ~width_of:N.width_of state input)
       (C.initial session))

type first_run_result =
  | First_run_created of F.t
  | First_run_cancelled
  | First_run_failed of string

let start_first_run path read_error =
  F.require (Unix.isatty Unix.stdin && Unix.isatty Unix.stdout) "interactive-tty-required";
  let outcome = ref None in
  let step (width, height) state input =
    match First_run.handle state input with
    | First_run.Continue next -> Some next
    | First_run.Cancel ->
        outcome := Some First_run_cancelled;
        None
    | First_run.Create _
      when not (First_run.ready_to_create ~dimensions:(width, height) ~width_of:N.width_of state) ->
        Some (First_run.refuse_confirmation state)
    | First_run.Create details ->
        (try
           outcome :=
             Some
               (First_run_created
                  (F.create_empty ~path:details.destination ~measure:details.measure
                     ~scale:details.scale))
         with
        | F.Refused why -> outcome := Some (First_run_failed why)
        | Unix.Unix_error (error, _, _) ->
            outcome := Some (First_run_failed (Unix.error_message error))
        | Sys_error why -> outcome := Some (First_run_failed why));
        None
  in
  ignore
    (terminal_loop
       ~paint:(fun (width, height) state ->
         let rows, cursor =
           First_run.screen ~dimensions:(width, height) ~width_of:N.width_of state
         in
         (N.lines P.Terminal rows |> N.fit width height, cursor))
       ~step
       (First_run.initial ~source_path:path ~read_error));
  match !outcome with
  | Some (First_run_created session) -> Some session
  | Some First_run_cancelled | None -> None
  | Some (First_run_failed why) ->
      prerr_endline
        ("First-run creation refused: " ^ why ^ ". Inspect the destination; no retry was attempted.");
      None

let run_loaded session = run_shell session

let run path =
  match
    try Ok (F.load path) with
    | F.Refused why -> Error why
    | Unix.Unix_error (error, _, _) -> Error (Unix.error_message error)
    | Sys_error why -> Error why
  with
  | Ok session ->
      F.require (Unix.isatty Unix.stdin && Unix.isatty Unix.stdout) "interactive-tty-required";
      run_loaded session
  | Error why -> (
      match start_first_run path why with None -> () | Some session -> run_loaded session)
