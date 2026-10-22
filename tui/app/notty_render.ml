(* Notty painting of the Shell: styled rows to Notty images, with the colour and
   glyph rules of the Bonsai adapter. Pure; the terminal loop is Notty_terminal. *)
module A = Notty.A
module I = Notty.I
module C = Shell_state
module R = Shell_view
module P = Ui_preferences

(* Notty rejects control characters (Unicode Cc) and malformed UTF-8; show them
   escaped, as Bonsai_term's View.text does, instead of dropping user text. *)
let escape_control code =
  match code with
  | 8 -> "\\b"
  | 9 -> "\\t"
  | 10 -> "\\n"
  | 13 -> "\\r"
  | code when code < 8 -> Printf.sprintf "\\00%d" code
  | code -> Printf.sprintf "\\%s%d" (if code < 32 then "0" else "") code

let printable text =
  let buffer = Buffer.create (String.length text) in
  Uutf.String.fold_utf_8
    (fun () _ -> function
      | `Uchar c ->
          let code = Uchar.to_int c in
          if code < 32 || (code >= 127 && code < 160) then
            Buffer.add_string buffer (escape_control code)
          else Uutf.Buffer.add_utf_8 buffer c
      | `Malformed _ -> Uutf.Buffer.add_utf_8 buffer Uutf.u_rep)
    () text;
  Buffer.contents buffer

let text ?(attr = A.empty) s = I.string attr (printable s)
let width_of s = I.width (text s)

let fit width height image =
  let image =
    I.crop ~r:(max 0 (I.width image - width)) ~b:(max 0 (I.height image - height)) image
  in
  I.pad ~r:(max 0 (width - I.width image)) ~b:(max 0 (height - I.height image)) image

let xterm index =
  if index < 8 then
    [| A.black; A.red; A.green; A.yellow; A.blue; A.magenta; A.cyan; A.white |].(index)
  else if index < 16 then
    [|
      A.lightblack;
      A.lightred;
      A.lightgreen;
      A.lightyellow;
      A.lightblue;
      A.lightmagenta;
      A.lightcyan;
      A.lightwhite;
    |].(index - 8)
  else if index >= 232 then A.gray (index - 232)
  else
    let cube = index - 16 in
    A.rgb ~r:(cube / 36) ~g:(cube mod 36 / 6) ~b:(cube mod 6)

let color (c : P.color) = xterm c.index
let ( ++ ) = A.( ++ )
let fg c = A.fg (color c)
let bg c = A.bg (color c)
let bold = A.st A.bold
let active = A.(fg cyan ++ st reverse ++ st bold)

(* The chart series colours: the terminal's own ANSI slots in the Terminal
   theme, the theme's indexed palette otherwise. The Terminal slots must read
   on a light and on a dark background: yellow washes out on a light one (the
   user's terminal), blue is weak on a dark one, so the four slots are the ones
   that carry the difference without a red/green pair and without relying on
   one hue. The Bakhlo themes keep their tuned indexed colours. A further
   series stays in the plain foreground and keeps its marker glyph, so the
   chart still reads in monochrome. *)
let terminal_series = [ A.blue; A.magenta; A.cyan; A.red ]

let series_attributes theme index =
  match P.palette theme with
  | None -> (
      match List.nth_opt terminal_series index with
      | Some color -> A.fg color
      | None -> A.empty)
  | Some palette -> (
      match List.nth_opt (Array.to_list palette.P.series) index with
      | Some color -> fg color
      | None -> fg palette.foreground ++ bg palette.background)

let attributes theme style =
  match P.palette theme with
  | None -> (
      match style with
      | C.Plain | C.Calendar_dates | C.Bonsai | C.Entrance | C.Columns _ | C.Input _ -> A.empty
      | C.Active | C.Panel_active -> active
      | C.Focused_frame -> A.(fg cyan ++ st bold)
      | C.Heading | C.Status | C.Panel_heading -> bold
      | C.Panel | C.Chrome | C.Frame -> A.empty
      | C.Series index -> series_attributes theme index
      | C.Spans _ -> A.empty)
  | Some palette -> (
      match style with
      | C.Plain | C.Calendar_dates | C.Bonsai | C.Entrance | C.Columns _ | C.Input _ ->
          fg palette.foreground ++ bg palette.background
      | C.Active -> fg palette.selected_foreground ++ bg palette.selected_background ++ bold
      | C.Heading -> fg palette.foreground ++ bg palette.background ++ bold
      | C.Chrome | C.Frame -> fg palette.heading ++ bg palette.background
      | C.Focused_frame -> fg palette.accent ++ bg palette.panel_background
      | C.Status -> fg palette.status ++ bg palette.background ++ bold
      | C.Panel -> fg palette.panel_foreground ++ bg palette.panel_background
      | C.Panel_heading -> fg palette.panel_foreground ++ bg palette.panel_background ++ bold
      | C.Panel_active -> fg palette.selected_foreground ++ bg palette.selected_background ++ bold
      | C.Series index -> series_attributes theme index
      | C.Spans _ -> fg palette.foreground ++ bg palette.background)

let border_attributes theme intent =
  match theme with
  | P.Terminal -> (
      (* ANSI slots belong to the terminal's light/dark palette too. *)
      match intent with
      | `Create -> A.fg A.cyan
      | `Change -> A.fg A.yellow
      | `Cancel -> A.fg A.red)
  | P.Bakhlo_light | P.Bakhlo_dark ->
      let light = theme = P.Bakhlo_light in
      let index =
        match intent with
        | `Create -> if light then 31 else 67
        | `Change -> if light then 136 else 179
        | `Cancel -> if light then 131 else 174
      in
      A.fg (xterm index)

(* Compose styled glyph runs. [base] is the colour every run starts from (the theme's
   page or panel colours), so a run's own attributes only add to it. Borders are not
   part of the input highlight, including the interior edges of side-by-side panes. No
   presentation glyph participates in navigation, accounting or publication decisions. *)
let rec lines ?border ?(base = A.empty) theme rows =
  rows
  |> List.map (fun (style, row) ->
      let text ?(attr = A.empty) s = text ~attr:A.(base ++ attr) s in
      match style with
      | C.Columns (left_width, left_style, right_style) ->
          let split = ref 0 and cells = ref 0 in
          Uutf.String.fold_utf_8
            (fun () offset -> function
              | `Uchar c when !cells < left_width ->
                  let glyph = Daily_overlays.utf8 c in
                  cells := !cells + width_of glyph;
                  split := offset + String.length glyph
              | `Uchar _ | `Malformed _ -> ())
            () row;
          let left = String.sub row 0 !split in
          let right_start = min (String.length row) (!split + 1) in
          let right = String.sub row right_start (String.length row - right_start) in
          I.hcat
            [
              lines ?border ~base theme [ (left_style, left) ];
              text " ";
              lines ?border ~base theme [ (right_style, right) ];
            ]
      | _ -> (
          let glyphs =
            Uutf.String.fold_utf_8
              (fun xs _ -> function `Uchar c -> Daily_overlays.utf8 c :: xs | `Malformed _ -> xs)
              [] row
            |> List.rev
          in
          let body_style =
            match style with
            | C.Frame | C.Focused_frame -> C.Chrome
            | C.Input _ | C.Bonsai | C.Entrance -> C.Plain
            | style -> style
          in
          (* A row of spans keeps the style of the span each cell belongs to. *)
          let cell_style =
            match style with
            | C.Spans spans ->
                let rec at cell offset = function
                  | [] -> C.Plain
                  | (span_style, text) :: rest ->
                      let width = width_of text in
                      if cell < offset + width then span_style else at cell (offset + width) rest
                in
                (fun cell -> at cell 0 spans)
            | _ -> (fun _ -> body_style)
          in
          let edge_attrs =
            match border with
            | Some intent -> border_attributes theme intent
            | None ->
                attributes theme (if style = C.Focused_frame then C.Focused_frame else C.Frame)
          in
          let leaf_attrs = A.fg A.green in
          let entrance_key_attrs = A.(fg cyan ++ st bold) in
          let framed_row = String.starts_with ~prefix:"│" row && String.ends_with ~suffix:"│" row in
          let ruled_row =
            String.starts_with ~prefix:"╭" row || String.starts_with ~prefix:"╰" row
          in
          let total_cells = width_of row in
          let rec paint cell = function
            | "[" :: a :: b :: "]" :: rest
              when style = C.Calendar_dates
                   && String.length a = 1
                   && String.length b = 1
                   && a.[0] >= '0'
                   && a.[0] <= '9'
                   && b.[0] >= '0'
                   && b.[0] <= '9' ->
                (attributes theme C.Active, "[" ^ a ^ b ^ "]") :: paint (cell + 4) rest
            | glyph :: rest when style = C.Bonsai && (glyph = ":" || glyph = ";") ->
                (leaf_attrs, glyph) :: paint (cell + 1) rest
            | key :: " " :: rest
              when style = C.Entrance
                   && (key = "r" || key = "s" || key = "g" || key = "a" || key = "b" || key = "d")
                   && (cell = 0 || String.get row (max 0 (cell - 1)) = ' ') ->
                (entrance_key_attrs, key) :: paint (cell + 1) (" " :: rest)
            | glyph :: rest ->
                let attrs =
                  if
                    (framed_row && (cell = 0 || cell = total_cells - 1))
                    || (ruled_row && List.mem glyph [ "─"; "╭"; "╮"; "╰"; "╯" ])
                  then edge_attrs
                  else if match style with C.Input caret -> cell = caret | _ -> false then
                    attributes theme C.Active
                  else attributes theme (cell_style cell)
                in
                (attrs, glyph) :: paint (cell + width_of glyph) rest
            | [] -> []
          in
          let runs =
            List.fold_left
              (fun runs (attrs, glyph) ->
                match runs with
                | (previous, content) :: rest when A.equal previous attrs ->
                    (previous, content ^ glyph) :: rest
                | _ -> (attrs, glyph) :: runs)
              [] (paint 0 glyphs)
            |> List.rev
          in
          match runs with
          | [] -> text " " (* Empty content is still a physical terminal row. *)
          | _ -> I.hcat (List.map (fun (attr, s) -> text ~attr s) runs)))
  |> I.vcat

(* Theme colours under every run, with a solid backdrop of the same colours. *)
let page_colors theme = Option.map (fun p -> fg p.P.foreground ++ bg p.background) (P.palette theme)

let panel_colors theme =
  Option.map (fun p -> fg p.P.panel_foreground ++ bg p.panel_background) (P.palette theme)

let backdrop colors image =
  match colors with
  | None -> image
  | Some attr -> I.(image </> char attr ' ' (width image) (height image))

let overlay_screen dimensions state = R.overlay_screen ~dimensions ~width_of state

let editor_border state =
  if state.C.record_visible then Option.map Record_session.border_intent state.C.record else None

let base_view ((width, height) as dimensions) theme state =
  let border = if overlay_screen dimensions state = None then editor_border state else None in
  let colors = page_colors theme in
  R.screen ~width_of dimensions state
  |> lines ?border ?base:colors theme |> fit width height |> backdrop colors

let overlay_view dimensions theme state =
  match R.resolve_overlay ~dimensions ~width_of state with
  | None -> None
  | Some frame ->
      let colors = panel_colors theme in
      let pane = lines ?border:(editor_border state) ?base:colors theme frame.rows in
      Some (I.pad ~l:frame.origin_x ~t:frame.origin_y (backdrop colors pane))

let render ((width, height) as dimensions) state =
  let base = base_view dimensions state.C.theme state in
  match overlay_view dimensions state.C.theme state with
  | None -> base
  | Some overlay -> fit width height I.(overlay </> base)

(* Notty's events already have the Shell's shape; resize is a repaint, not input. *)
let input_of_event : Notty.Unescape.event -> C.input = function
  | `Key key -> `Key key
  | `Paste marker -> `Paste marker
  | `Mouse _ -> `Mouse ()
