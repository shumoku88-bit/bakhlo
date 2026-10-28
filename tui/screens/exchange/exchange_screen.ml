(* Exchange: one direct exchange between two Measures as a single entry with a
   negative source and a positive destination Effect. No rate is inferred.
   The reviewed entry is published against the bytes it was reviewed from. *)
module B = Bakhlo_household.Book
module D = Bakhlo_domain
module A = Draft
module Form = Ui_form

let tr = Ui_text.tr

type review = { form : Form.t; editing : Form.t; transaction : A.transaction; base : string }
type editor = Editing of Form.t | Review of review
type t = { editor : editor option }

let config_files = []
let create () = { editor = None }
let modal t = Option.is_some t.editor

let form t =
  match t.editor with None -> None | Some (Editing form) | Some (Review { form; _ }) -> Some form

let with_form form t =
  match t.editor with
  | None -> t
  | Some (Editing _) -> { editor = Some (Editing form) }
  | Some (Review r) -> { editor = Some (Review { r with form }) }

let exchange_form ~default_date =
  Form.create ~id:"exchange" ~title:"Exchange / Record"
    ~summary:
      [
        "Record one direct exchange between two Measures.";
        "Amounts are entered as positive magnitudes.";
        "Source Effect is negative; Destination Effect is positive.";
        "No FX rate or valuation is inferred.";
      ]
    ~fields:
      [
        Form.text_field ~id:"date" ~label:"Date" ~value:default_date ();
        Form.text_field ~id:"memo" ~label:"Description" ~placeholder:"Optional description" ();
        Form.text_field ~id:"source_locus" ~label:"Source Locus" ~placeholder:"e.g. wallet_jpy" ();
        Form.text_field ~id:"source_measure" ~label:"Source Measure" ~value:"jpy" ();
        Form.text_field ~id:"source_amount" ~label:"Source amount"
          ~placeholder:"Positive amount (deducted)" ();
        Form.text_field ~id:"destination_locus" ~label:"Destination Locus"
          ~placeholder:"e.g. wallet_usd" ();
        Form.text_field ~id:"destination_measure" ~label:"Destination Measure"
          ~placeholder:"e.g. usd" ();
        Form.text_field ~id:"destination_amount" ~label:"Destination amount"
          ~placeholder:"Positive amount (added)" ();
        Form.action_buttons ~confirm:"Preview Exchange" ~cancel:"Cancel" ();
      ]
    ()

let review_form ~canon_day ~memo ~src_locus ~src_measure ~src_quanta_str ~dst_locus ~dst_measure
    ~dst_quanta_str =
  let memo_line =
    match memo with Some m -> "Description:        " ^ m | None -> "Description:        (none)"
  in
  Form.create ~id:"review_exchange" ~title:"Exchange / Preview"
    ~summary:
      [
        "Date:               " ^ canon_day;
        memo_line;
        Printf.sprintf "Source Effect:      -%s %s at %s" src_quanta_str src_measure src_locus;
        Printf.sprintf "Destination Effect: +%s %s at %s" dst_quanta_str dst_measure dst_locus;
        "Exact observed quantities only; no FX rate is inferred.";
      ]
    ~fields:[ Form.action_buttons ~confirm:"Publish Exchange" ~cancel:"Edit" () ]
    ()

(* Commands entry: the editor opens over the current route on its day. *)
let open_editor ~default_date _t = { editor = Some (Editing (exchange_form ~default_date)) }

let amount_refusal side measure = function
  | "non-positive-amount" -> tr (side ^ " amount must be positive.")
  | "division-by-zero" -> tr (side ^ " amount divides by zero.")
  | "indivisible-amount" -> tr (side ^ " result cannot fit the Measure scale.")
  | "measure-scale-not-supplied" -> Printf.sprintf "Measure '%s' scale is not configured." measure
  | _ -> tr (side ^ " amount is invalid.")

let submit_editing (env : Screen.env) submitted =
  let refuse notice =
    ({ editor = Some (Editing (Form.set_notice submitted notice)) }, Screen.Stay)
  in
  let text id = Option.value ~default:"" (Form.get_text submitted id) |> String.trim in
  let src_locus = text "source_locus" and src_measure = text "source_measure" in
  let dst_locus = text "destination_locus" and dst_measure = text "destination_measure" in
  let valid_token s =
    s <> ""
    && (not (String.contains s ' '))
    && (not (String.contains s '\t'))
    && (not (String.contains s '\n'))
    && not (String.contains s '\r')
  in
  match Day.normalize (text "date") with
  | Error _ -> refuse (tr "Invalid date (YYYY-MM-DD).")
  | Ok canon_day -> (
      if not (Day.is_valid canon_day) then
        refuse (tr "Enter a real calendar date in YYYY-MM-DD form.")
      else if not (valid_token src_locus) then
        refuse (tr "Source Locus must be a nonempty single-line token.")
      else if not (valid_token dst_locus) then
        refuse (tr "Destination Locus must be a nonempty single-line token.")
      else if not (valid_token src_measure) then
        refuse (tr "Source Measure must be a nonempty single-line token.")
      else if not (valid_token dst_measure) then
        refuse (tr "Destination Measure must be a nonempty single-line token.")
      else if String.equal src_measure dst_measure then
        refuse (tr "Source and destination Measures must differ.")
      else
        match B.parse_amount env.book src_measure (text "source_amount") with
        | Error why -> refuse (amount_refusal "Source" src_measure why)
        | Ok src_quanta -> (
            match B.parse_amount env.book dst_measure (text "destination_amount") with
            | Error why -> refuse (amount_refusal "Destination" dst_measure why)
            | Ok dst_quanta ->
                let unapproved =
                  match B.approved_loci env.book with
                  | None -> []
                  | Some ids ->
                      List.filter (fun loc -> not (List.mem loc ids)) [ src_locus; dst_locus ]
                in
                if unapproved <> [] then
                  refuse
                    (Printf.sprintf "Locus '%s' is not admitted." (String.concat ", " unapproved))
                else
                  let leg key locus measure quanta =
                    D.Effect.create
                      ~key:(Some (Result.get_ok (D.Identifier.Effect_key.of_string key)))
                      ~locus:(Result.get_ok (D.Identifier.Locus.of_string locus))
                      ~measure:(Result.get_ok (D.Identifier.Measure.of_string measure))
                      ~quantity:(D.Quantity.of_quanta quanta)
                  in
                  let memo = match text "memo" with "" -> None | m -> Some m in
                  let entry =
                    {
                      B.id = env.new_id ();
                      day = canon_day;
                      memo;
                      effects =
                        [
                          leg "exchange-source" src_locus src_measure (Z.neg src_quanta);
                          leg "exchange-destination" dst_locus dst_measure dst_quanta;
                        ];
                      reversal_of = None;
                      exchange = Some ("exchange-source", "exchange-destination");
                      original_amount = None;
                      merchant = None;
                    }
                  in
                  let form =
                    review_form ~canon_day ~memo ~src_locus ~src_measure
                      ~src_quanta_str:(B.format env.book src_measure src_quanta)
                      ~dst_locus ~dst_measure
                      ~dst_quanta_str:(B.format env.book dst_measure dst_quanta)
                  in
                  ( {
                      editor =
                        Some
                          (Review
                             {
                               form;
                               editing = submitted;
                               base = env.revision;
                               transaction = { A.entry; replace = false; plan = None };
                             });
                    },
                    Screen.Stay )))

let handle (env : Screen.env) (geometry : Screen.geometry) t input =
  match t.editor with
  | None -> (t, Screen.Ignored)
  | Some (Editing form) -> (
      match Form.handle_input form input with
      | Form.Cancel -> ({ editor = None }, Screen.Stay)
      | Form.Updated form -> ({ editor = Some (Editing form) }, Screen.Stay)
      | Form.Submit submitted -> submit_editing env submitted)
  | Some (Review r) -> (
      match Form.handle_input r.form input with
      | Form.Cancel -> ({ editor = Some (Editing r.editing) }, Screen.Stay)
      | Form.Updated form -> ({ editor = Some (Review { r with form }) }, Screen.Stay)
      | Form.Submit submitted ->
          if not (Ui_overlay.form_fits ~width_of:geometry.width_of ~body:geometry.body submitted)
          then
            ( {
                editor =
                  Some
                    (Review
                       {
                         r with
                         form =
                           Form.set_notice submitted
                             (tr
                                "Enlarge the terminal to review the full exchange before \
                                 publishing.");
                       });
              },
              Screen.Stay )
          else
            ( { editor = Some (Review { r with form = submitted }) },
              Screen.Publish (Commit_transaction { transaction = r.transaction; base = r.base }) ))

let published _env _geometry outcome t =
  let notice why = (with_form (Form.set_notice (Option.get (form t)) why) t, Screen.Stay) in
  match (outcome, t.editor) with
  | _, None -> (t, Screen.Stay)
  | Screen.Publish_refused why, Some _ -> notice why
  | Screen.Publish_conflict, Some _ -> notice (tr "File changed on disk. Reload to inspect.")
  | (Screen.Published | Screen.Publish_stopped), Some _ -> ({ editor = None }, Screen.Stay)

let view _env (geometry : Screen.geometry) t =
  let overlay =
    Option.bind (form t)
      (Ui_overlay.form ~width_of:geometry.width_of ~screen:geometry.screen ~body:geometry.body)
  in
  {
    Screen.title = tr "Exchange";
    subtitle = Default;
    rows = lazy [];
    footer = [ "Enter submit  Tab next field  Esc cancel"; "Arrow keys / space to choose options" ];
    overlay;
    cursor = Option.bind overlay (fun frame -> frame.Ui_overlay.cursor);
  }
