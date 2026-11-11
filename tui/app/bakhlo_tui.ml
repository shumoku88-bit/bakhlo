(* Terminal entry point: plain bk opens the screens; a bk command runs as in cli/. *)
let () = Command_line.main ~screens:Notty_terminal.run ()
