(* UI-only preferences. Never part of household data or accounting authority. *)

type theme = Terminal | Bakhlo_light | Bakhlo_dark

let all_themes = [ Terminal; Bakhlo_light; Bakhlo_dark ]

let theme_id = function
  | Terminal -> "terminal"
  | Bakhlo_light -> "bakhlo-light"
  | Bakhlo_dark -> "bakhlo-dark"

let theme_label = function
  | Terminal -> "Terminal"
  | Bakhlo_light -> "Bakhlo Light"
  | Bakhlo_dark -> "Bakhlo Dark"

let theme_of_id = function
  | "terminal" -> Some Terminal
  | "bakhlo-light" -> Some Bakhlo_light
  | "bakhlo-dark" -> Some Bakhlo_dark
  | _ -> None

(* Use fixed xterm entries 16..255, not user-customizable ANSI colors 0..15.
   macOS Terminal supports these but not the 24-bit SGR used by the first draft.
   Keep canonical RGB here as well, for readable swatches and contrast checks. *)
type color = { index : int; r : int; g : int; b : int }

type palette = {
  foreground : color;
  background : color;
  accent : color;
  heading : color;
  status : color;
  panel_foreground : color;
  panel_background : color;
  selected_foreground : color;
  selected_background : color;
}

let xterm_color index =
  if index < 16 || index > 255 then invalid_arg "fixed-xterm-color-required";
  if index >= 232 then
    let channel = 8 + (10 * (index - 232)) in
    { index; r = channel; g = channel; b = channel }
  else
    let levels = [| 0; 95; 135; 175; 215; 255 |] in
    let cube = index - 16 in
    { index; r = levels.(cube / 36); g = levels.(cube / 6 mod 6); b = levels.(cube mod 6) }

let palette = function
  | Terminal -> None
  | Bakhlo_light ->
      Some
        {
          foreground = xterm_color 237;
          (* #3a3a3a *)
          background = xterm_color 255;
          (* #eeeeee *)
          accent = xterm_color 25;
          (* #005faf *)
          heading = xterm_color 24;
          (* #005f87 *)
          status = xterm_color 58;
          (* #5f5f00 *)
          panel_foreground = xterm_color 237;
          (* #3a3a3a *)
          panel_background = xterm_color 253;
          (* #dadada *)
          selected_foreground = xterm_color 231;
          (* #ffffff *)
          selected_background = xterm_color 25;
          (* #005faf *)
        }
  | Bakhlo_dark ->
      Some
        {
          (* Earlier Bonsai trial: blue selection, cyan heading, yellow status. *)
          foreground = xterm_color 252;
          (* #d0d0d0 *)
          background = xterm_color 234;
          (* #1c1c1c *)
          accent = xterm_color 81;
          (* #5fd7ff *)
          heading = xterm_color 81;
          (* #5fd7ff *)
          status = xterm_color 221;
          (* #ffd75f *)
          panel_foreground = xterm_color 252;
          (* #d0d0d0 *)
          panel_background = xterm_color 236;
          (* #303030 *)
          selected_foreground = xterm_color 231;
          (* #ffffff *)
          selected_background = xterm_color 25;
          (* #005faf *)
        }

let home_from_environment ~bakhlo ~xdg ~home =
  match bakhlo with
  | Some path when path <> "" -> Some path
  | Some _ | None -> (
      match xdg with
      | Some path when path <> "" -> Some (Filename.concat path "bakhlo")
      | Some _ | None -> (
          match home with
          | Some path when path <> "" ->
              Some (Filename.concat (Filename.concat path ".config") "bakhlo")
          | Some _ | None -> None))

let configured_home explicit =
  match explicit with
  | Some path when path <> "" -> Some path
  | Some _ -> None
  | None ->
      home_from_environment
        ~bakhlo:(Sys.getenv_opt "BAKHLO_CONFIG_HOME")
        ~xdg:(Sys.getenv_opt "XDG_CONFIG_HOME")
        ~home:(Sys.getenv_opt "HOME")

let path ?config_home () =
  Option.map (fun home -> Filename.concat home "ui-theme") (configured_home config_home)

let load_theme ?config_home () =
  match path ?config_home () with
  | None -> Terminal
  | Some filename -> (
      try
        (* Bound malformed input and never block on a non-regular config file. *)
        let descriptor =
          Unix.openfile filename [ Unix.O_RDONLY; Unix.O_NONBLOCK; Unix.O_CLOEXEC ] 0
        in
        let channel = Unix.in_channel_of_descr descriptor in
        Fun.protect
          ~finally:(fun () -> close_in_noerr channel)
          (fun () ->
            let stat = Unix.fstat descriptor in
            if stat.st_kind <> Unix.S_REG || stat.st_size > 32 then Terminal
            else
              let text = really_input_string channel stat.st_size in
              let at_end =
                try
                  ignore (input_char channel);
                  false
                with End_of_file -> true
              in
              if not at_end then Terminal
              else
                match String.split_on_char '\n' text with
                | [ line ] | [ line; "" ] ->
                    Option.value ~default:Terminal (theme_of_id (String.trim line))
                | _ -> Terminal)
      with Unix.Unix_error _ | Sys_error _ | End_of_file -> Terminal)

let rec ensure_directory path =
  if path = "" || path = "." || path = Filename.dirname path || Sys.file_exists path then ()
  else (
    ensure_directory (Filename.dirname path);
    try Unix.mkdir path 0o700 with Unix.Unix_error (Unix.EEXIST, _, _) -> ())

let save_theme ?config_home theme =
  match configured_home config_home with
  | None -> Error "ui-config-home-unavailable"
  | Some home -> (
      let filename = Filename.concat home "ui-theme" in
      let temporary = ref None in
      try
        ensure_directory home;
        let temp_path, channel =
          Filename.open_temp_file ~mode:[ Open_binary ] ~perms:0o600 ~temp_dir:home "ui-theme-"
            ".tmp"
        in
        temporary := Some temp_path;
        let descriptor = Unix.descr_of_out_channel channel in
        (try
           output_string channel (theme_id theme ^ "\n");
           flush channel;
           Unix.fsync descriptor;
           close_out channel
         with exn ->
           close_out_noerr channel;
           raise exn);
        Unix.rename temp_path filename;
        Ok ()
      with Unix.Unix_error _ | Sys_error _ ->
        (match !temporary with
        | None -> ()
        | Some path -> ( try Unix.unlink path with Unix.Unix_error _ -> ()));
        Error "ui-theme-save-failed")
