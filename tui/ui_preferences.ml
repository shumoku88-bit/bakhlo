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

type rgb = { r : int; g : int; b : int }

type palette = {
  foreground : rgb;
  background : rgb;
  accent : rgb;
  heading : rgb;
  status : rgb;
  panel_foreground : rgb;
  panel_background : rgb;
  selected_foreground : rgb;
  selected_background : rgb;
}

let rgb r g b = { r; g; b }

let palette = function
  | Terminal -> None
  | Bakhlo_light ->
      Some
        {
          foreground = rgb 45 48 50;
          background = rgb 247 244 235;
          accent = rgb 42 102 103;
          heading = rgb 132 78 49;
          status = rgb 57 111 74;
          panel_foreground = rgb 35 45 46;
          panel_background = rgb 228 234 222;
          selected_foreground = rgb 247 244 235;
          selected_background = rgb 42 102 103;
        }
  | Bakhlo_dark ->
      Some
        {
          foreground = rgb 222 229 234;
          background = rgb 21 26 32;
          accent = rgb 91 174 177;
          heading = rgb 214 153 101;
          status = rgb 127 196 139;
          panel_foreground = rgb 226 235 238;
          panel_background = rgb 34 43 52;
          selected_foreground = rgb 12 25 27;
          selected_background = rgb 91 174 177;
        }

let configured_home explicit =
  match explicit with
  | Some path when path <> "" -> Some path
  | Some _ -> None
  | None -> (
      match Sys.getenv_opt "BAKHLO_CONFIG_HOME" with
      | Some path when path <> "" -> Some path
      | Some _ -> None
      | None -> (
          match Sys.getenv_opt "XDG_CONFIG_HOME" with
          | Some path when path <> "" -> Some (Filename.concat path "bakhlo")
          | Some _ -> None
          | None -> (
              match Sys.getenv_opt "HOME" with
              | Some path when path <> "" -> Some (Filename.concat (Filename.concat path ".config") "bakhlo")
              | Some _ | None -> None)))

let path ?config_home () =
  Option.map (fun home -> Filename.concat home "ui-theme") (configured_home config_home)

let load_theme ?config_home () =
  match path ?config_home () with
  | None -> Terminal
  | Some filename -> (
      try
        let channel = open_in_bin filename in
        Fun.protect
          ~finally:(fun () -> close_in_noerr channel)
          (fun () ->
            match theme_of_id (String.trim (input_line channel)) with
            | Some theme -> theme
            | None -> Terminal)
      with Sys_error _ | End_of_file -> Terminal)

let rec ensure_directory path =
  if path = "" || path = "." || path = Filename.dirname path || Sys.file_exists path then ()
  else (
    ensure_directory (Filename.dirname path);
    try Unix.mkdir path 0o700 with Unix.Unix_error (Unix.EEXIST, _, _) -> ())

let save_theme ?config_home theme =
  match configured_home config_home with
  | None -> Error "ui-config-home-unavailable"
  | Some home ->
      let filename = Filename.concat home "ui-theme" in
      let temporary = filename ^ ".tmp-" ^ string_of_int (Unix.getpid ()) in
      (try
         ensure_directory home;
         let descriptor =
           Unix.openfile temporary [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_TRUNC ] 0o600
         in
         let channel = Unix.out_channel_of_descr descriptor in
         (try
            output_string channel (theme_id theme ^ "\n");
            flush channel;
            Unix.fsync descriptor;
            close_out channel
          with exn ->
            close_out_noerr channel;
            raise exn);
         Unix.rename temporary filename;
         Unix.chmod filename 0o600;
         Ok ()
       with
      | Unix.Unix_error _ | Sys_error _ ->
          (try Unix.unlink temporary with Unix.Unix_error _ -> ());
          Error "ui-theme-save-failed")
