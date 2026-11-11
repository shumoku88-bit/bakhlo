module B = Bakhlo_household.Book
module O = Ui_render
module Form = Ui_form
module F = Book_file

type details = { destination : string; measure : string; scale : int }
type phase = Editing of Form.t | Reviewing of Form.t * Form.t * details
type state = { phase : phase }
type action = Continue of state | Cancel | Create of details

let editing_form ~destination ~read_error =
  Form.create ~id:"first_run" ~title:"Start a new household"
    ~summary:
      [
        "The selected book could not be opened.";
        "Choose a new file and configure the first Measure.";
        "The source file will not be changed.";
        "";
        "Read failure: " ^ read_error;
      ]
    ~fields:
      [
        Form.text_field ~id:"destination" ~label:"New book file" ~value:destination ();
        Form.text_field ~id:"measure" ~label:"First Measure" ();
        Form.text_field ~id:"scale" ~label:"Decimal scale (0–9)" ();
        Form.action_buttons ~confirm:"Review" ~cancel:"Cancel" ();
      ]
    ()

let initial ~source_path ~read_error =
  let destination =
    try
      ignore (Unix.lstat source_path);
      ""
    with
    | Unix.Unix_error (Unix.ENOENT, _, _) -> source_path
    | Unix.Unix_error _ -> ""
  in
  { phase = Editing (editing_form ~destination ~read_error) }

let validate form =
  let error message = Error message in
  let destination = Option.value ~default:"" (Form.get_text form "destination") in
  let measure = String.trim (Option.value ~default:"" (Form.get_text form "measure")) in
  let scale_text = String.trim (Option.value ~default:"" (Form.get_text form "scale")) in
  if String.trim destination = "" then error "Enter a new book file path."
  else if
    String.length destination > 240
    || String.exists (fun c -> Char.code c < 32 || Char.code c = 127) destination
  then error "Book file path must be one printable line of at most 240 bytes."
  else if
    Uutf.String.fold_utf_8
      (fun hidden _ -> function
        | `Uchar c ->
            let n = Uchar.to_int c in
            hidden || n = 0x61c || n = 0x200e || n = 0x200f
            || (n >= 0x202a && n <= 0x202e)
            || (n >= 0x2066 && n <= 0x2069)
        | `Malformed _ -> true)
      false destination
  then error "Book file path contains invalid UTF-8 or bidirectional controls."
  else if measure = "" then error "Enter a valid Measure token."
  else if scale_text = "" || not (String.for_all (fun c -> c >= '0' && c <= '9') scale_text) then
    error "Enter a decimal scale from 0 to 9."
  else
    match int_of_string_opt scale_text with
    | Some scale when scale <= 9 -> (
        let parent = Filename.dirname destination in
        try
          if (Unix.stat parent).Unix.st_kind <> Unix.S_DIR then
            error "The destination parent must be an existing directory."
          else
            try
              ignore (Unix.lstat destination);
              error "That file already exists; choose an unused destination."
            with Unix.Unix_error (Unix.ENOENT, _, _) -> Ok { destination; measure; scale }
        with Unix.Unix_error _ -> error "The destination parent is unavailable.")
    | _ -> error "Enter a decimal scale from 0 to 9."

let review_form details =
  Form.create ~id:"first_run_review" ~title:"Review new household"
    ~summary:
      [
        "New book file: " ^ details.destination;
        Printf.sprintf "First Measure: %s (scale %d)" details.measure details.scale;
        "No Loci, Actuals, Scheduled plans, balances or observations will be created.";
        "No history or opening evidence will be invented.";
      ]
    ~fields:[ Form.action_buttons ~confirm:"Create empty book" ~cancel:"Edit" () ]
    ()

let handle state input =
  match state.phase with
  | Editing form -> (
      match Form.handle_input form input with
      | Form.Cancel -> Cancel
      | Form.Updated form -> Continue { phase = Editing form }
      | Form.Submit form -> (
          match Form.get_selected_button form with
          | Some button when button.Form.is_cancel -> Cancel
          | _ -> (
              match validate form with
              | Error why -> Continue { phase = Editing (Form.set_notice form why) }
              | Ok details -> Continue { phase = Reviewing (review_form details, form, details) })))
  | Reviewing (form, editing, details) -> (
      match Form.handle_input form input with
      | Form.Cancel -> Continue { phase = Editing editing }
      | Form.Updated form -> Continue { phase = Reviewing (form, editing, details) }
      | Form.Submit form -> (
          match Form.get_selected_button form with
          | Some button when button.Form.is_cancel -> Continue { phase = Editing editing }
          | _ -> Create details))

let ready_to_create ~dimensions:(width, height) ~width_of state =
  match state.phase with
  | Editing _ -> false
  | Reviewing (form, _, _) ->
      if width < 48 || height < 12 then false
      else
        let body = Form.render_rows ~width:(width - 4) ~height:1000 ~width_of form in
        List.length body + 4 <= height

let refuse_confirmation state =
  match state.phase with
  | Editing _ -> state
  | Reviewing (form, editing, details) ->
      {
        phase =
          Reviewing
            ( Form.set_notice form
                "Enlarge the terminal to review the complete destination and confirm.",
              editing,
              details );
      }

let roundtrip_empty scale =
  match B.empty ~measure:"jpy" ~scale with
  | Error why -> failwith ("first-run-check: " ^ why)
  | Ok book -> (
      match B.read (B.print book) with
      | Ok book -> book
      | Error why -> failwith ("first-run-check: empty-book-roundtrip: " ^ why))

let check ~width_of () =
  let require ok why = if not ok then failwith ("first-run-check: " ^ why) in
  let get = function
    | Continue state -> state
    | Cancel -> failwith "first-run-check: unexpected cancel"
    | Create _ -> failwith "first-run-check: unexpected create"
  in
  let root = Filename.temp_file "bakhlo-first-run-check-" "" in
  Unix.unlink root;
  Unix.mkdir root 0o700;
  Fun.protect
    ~finally:(fun () ->
      List.iter
        (fun name -> try Unix.unlink (Filename.concat root name) with _ -> ())
        [ "source"; "existing"; "new.txt" ];
      try Unix.rmdir root with _ -> ())
    (fun () ->
      let source = Filename.concat root "source" in
      let absent = initial ~source_path:source ~read_error:"missing" in
      (match absent.phase with
      | Editing form ->
          require (Form.get_text form "destination" = Some source) "missing-path-prefilled"
      | _ -> assert false);
      let source_bytes = "unreadable source bytes" in
      let oc = open_out_bin source in
      output_string oc source_bytes;
      close_out oc;
      let unreadable = initial ~source_path:source ~read_error:"invalid book" in
      (match unreadable.phase with
      | Editing form -> require (Form.get_text form "destination" = Some "") "unreadable-path-blank"
      | _ -> assert false);
      let book = roundtrip_empty 0 in
      require
        (B.measures book = [ ("jpy", 0) ]
        && B.entry_count book = 0
        && B.plans book = []
        && B.approved_loci book = Some [])
        "empty-book-shape";
      (match B.add_locus book "wallet" with
      | Ok added ->
          require (B.approved_loci added = Some [ "wallet" ]) "empty-book-can-admit-first-locus"
      | Error _ -> failwith "first-run-check: empty-book-cannot-admit-locus");
      require (Result.is_ok (B.empty ~measure:"jpy" ~scale:9)) "maximum-scale-admitted";
      require (Result.is_error (B.empty ~measure:"" ~scale:0)) "invalid-measure-refused";
      require (Result.is_error (B.empty ~measure:"jpy" ~scale:10)) "invalid-scale-refused";
      let form = match absent.phase with Editing form -> form | _ -> assert false in
      let form =
        Form.set_text form "destination" (Filename.concat root "new.txt") |> fun form ->
        Form.set_text form "measure" "jpy" |> fun form ->
        Form.set_text form "scale" "0" |> fun form ->
        Form.set_focused form (Form.find_field_index form "action")
      in
      let reviewed = get (handle { phase = Editing form } (`Key (`Enter, []))) in
      (match reviewed.phase with
      | Reviewing _ -> ()
      | _ -> failwith "first-run-check: not-reviewing");
      let review_form =
        match reviewed.phase with Reviewing (form, _, _) -> form | _ -> assert false
      in
      require
        (List.length (Form.render_rows ~width:76 ~height:20 ~width_of review_form) + 4 <= 24)
        "review-fits-standard-terminal";
      require
        (Sys.file_exists source
        && In_channel.with_open_bin source In_channel.input_all = source_bytes)
        "source-preserved";
      require (not (Sys.file_exists (Filename.concat root "new.txt"))) "review-did-not-write";
      require (not (ready_to_create ~dimensions:(32, 9) ~width_of reviewed)) "small-review-refused";
      require
        (ready_to_create ~dimensions:(80, 24) ~width_of reviewed)
        "standard-review-confirmable";
      let long_destination = Filename.concat root (String.make 100 'x') in
      let long_form = Form.set_text form "destination" long_destination in
      let long_reviewed = get (handle { phase = Editing long_form } (`Key (`Enter, []))) in
      require
        ((not (ready_to_create ~dimensions:(48, 14) ~width_of long_reviewed))
        && ready_to_create ~dimensions:(80, 24) ~width_of long_reviewed)
        "long-destination-must-fit-inside-frame";
      List.iter
        (fun name ->
          let misleading = Form.set_text form "destination" (Filename.concat root name) in
          match handle { phase = Editing misleading } (`Key (`Enter, [])) with
          | Continue { phase = Editing _ } -> ()
          | _ -> failwith "first-run-check: invisible-or-reordered-path-accepted")
        [ "abc\226\128\174txt"; "abc\255txt" ];
      let japanese = Form.set_text form "destination" (Filename.concat root "家計.txt") in
      (match handle { phase = Editing japanese } (`Key (`Enter, [])) with
      | Continue { phase = Reviewing _ } -> ()
      | _ -> failwith "first-run-check: valid-unicode-path-refused");
      (match handle (refuse_confirmation reviewed) (`Key (`Escape, [])) with
      | Continue { phase = Editing form } ->
          require
            (Form.get_text form "destination" = Some (Filename.concat root "new.txt")
            && Form.get_text form "measure" = Some "jpy"
            && Form.get_text form "scale" = Some "0")
            "review-escape-retains-input";
          require (not (Sys.file_exists (Filename.concat root "new.txt"))) "review-escape-no-write";
          require
            (match handle { phase = Editing form } (`Key (`Escape, [])) with
            | Cancel -> true
            | _ -> false)
            "editing-escape-cancels"
      | _ -> failwith "first-run-check: review-escape-did-not-edit");
      let selected_edit = get (handle reviewed (`Key (`Arrow `Right, []))) in
      (match handle selected_edit (`Key (`Enter, [])) with
      | Continue { phase = Editing _ } -> ()
      | _ -> failwith "first-run-check: edit-button-did-not-edit");
      require
        (match handle reviewed (`Key (`Enter, [])) with
        | Create { destination; measure = "jpy"; scale = 0 } ->
            destination = Filename.concat root "new.txt"
        | _ -> false)
        "second-enter-requests-create";
      let existing = Filename.concat root "existing" in
      let oc = open_out_bin existing in
      output_string oc "keep";
      close_out oc;
      let existing_form =
        Form.set_text form "destination" existing |> fun form ->
        Form.set_text form "measure" "jpy" |> fun form ->
        Form.set_text form "scale" "0" |> fun form ->
        Form.set_focused form (Form.find_field_index form "action")
      in
      (match handle { phase = Editing existing_form } (`Key (`Enter, [])) with
      | Continue { phase = Editing form; _ } ->
          require (String.length (Form.notice form) > 0) "existing-target-refused"
      | _ -> failwith "first-run-check: existing-target-transition");
      let created = F.create_empty ~path:(Filename.concat root "new.txt") ~measure:"jpy" ~scale:0 in
      require
        (F.read_revision created.F.path = created.F.revision
        && B.measures created.F.book = [ ("jpy", 0) ]
        && B.entry_count created.F.book = 0
        && B.approved_loci created.F.book = Some [])
        "exclusive-empty-book-cold-reopen";
      require
        (try
           ignore (F.create_empty ~path:existing ~measure:"jpy" ~scale:0);
           false
         with Unix.Unix_error (Unix.EEXIST, _, _) -> true)
        "exclusive-create-refuses-existing-file";
      require
        (In_channel.with_open_bin existing In_channel.input_all = "keep")
        "existing-target-preserved")

let screen ~dimensions:(width, height) ~width_of state =
  if width < 48 || height < 12 then
    ( [
        O.panel_border ~width:(max 0 width) ~width_of "First run";
        O.panel_line ~width:(max 0 width) ~width_of O.Status "Resize or Esc.";
        O.panel_bottom ~width:(max 0 width) ~width_of ();
      ]
      |> List.filteri (fun i _ -> i < height),
      None )
  else
    let form = match state.phase with Editing form | Reviewing (form, _, _) -> form in
    let inner_width = width - 4 and inner_height = height - 4 in
    let body = Form.render_rows ~width:inner_width ~height:inner_height ~width_of form in
    let rows =
      [ O.panel_border ~width ~width_of "First run" ]
      @ List.map
          (fun (style, text) ->
            let style =
              match style with O.Input column -> O.Input (column + 2) | other -> other
            in
            O.panel_line ~width ~width_of style text)
          body
      @ [ O.panel_bottom ~width ~width_of () ]
    in
    let cursor =
      match O.cursor_in_rows ~width_of ~width rows with
      | Some (x, y) when x < width && y < height -> Some (x, y)
      | _ -> None
    in
    (List.filteri (fun i _ -> i < height) rows, cursor)
