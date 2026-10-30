(* Notty terminal loop: the Shell driven by Notty_unix, painted by Notty_render.
   Same daily actions and file owner as the Bonsai adapter. *)
module Term = Notty_unix.Term
module C = Shell_state
module H = Shell_input
module R = Shell_view
module F = Book_file
module P = Ui_preferences
module N = Notty_render

let show term image cursor =
  Term.image term image;
  Term.cursor term cursor

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
   reads the current terminal size, so a resize and a key never use stale geometry. *)
let terminal_loop ~paint ~step initial =
  with_ctrl_o @@ fun () ->
  let term = Term.create ~dispose:true ~mouse:false ~bpaste:true () in
  let rec loop state =
    let dimensions = Term.size term in
    let image, cursor = paint dimensions state in
    show term image cursor;
    match Term.event term with
    | `End -> state
    | `Resize _ -> loop state
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
