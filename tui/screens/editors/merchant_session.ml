module B = Bakhlo_household.Book
module D = Bakhlo_domain
module O = Ui_render
module Panel = Ui_panel

type choice = Merchant | Nonmerchant
type mode = Editing | Preview

type t = {
  target : string;
  description : string;
  choice : choice;
  party_input : string;
  mode : mode;
  notice : string;
  base_revision : string;
}

type outcome = Updated of t | Closed | Publish of string * B.disposition * string

let create ~base_revision (entry : B.entry) : t =
  {
    target = entry.id;
    description = Option.value ~default:"" entry.memo;
    choice = Merchant;
    party_input = "";
    mode = Editing;
    notice = "";
    base_revision;
  }

let base_revision t = t.base_revision
let target t = t.target
let choice t = t.choice
let party_input t = t.party_input
let is_preview t = t.mode = Preview
let edit t = { t with mode = Editing; notice = "" }
let with_publish_error t message = { t with mode = Editing; notice = message }

let valid_token s =
  s <> "" && not (String.contains s '\t' || String.contains s '\n' || String.contains s '\r')

let next_choice = function Merchant -> Nonmerchant | Nonmerchant -> Merchant
let choice_text = function Merchant -> "Merchant" | Nonmerchant -> "Nonmerchant"
let description_text t = if t.description = "" then "(no description)" else O.visible t.description

let proposal_text t =
  match t.choice with Merchant -> "Merchant " ^ t.party_input | Nonmerchant -> "Nonmerchant"

let draft_disposition t =
  match t.choice with
  | Merchant -> (
      if not (valid_token t.party_input) then
        Error "Merchant party id must be a non-empty single text field."
      else
        match D.Identifier.External_party.of_string t.party_input with
        | Ok p -> Ok (B.Merchant p)
        | Error _ -> Error "Merchant party id must be a non-empty single text field.")
  | Nonmerchant -> Ok B.Nonmerchant

let dimensions (width, height) =
  if width >= 76 && height >= 21 then (min 76 (width - 4), min 21 (height - 2))
  else (max 0 width, max 0 height)

let content_rows ~width ~width_of t =
  let wrap text = O.wrap_text ~width_of (max 1 (width - 6)) text in
  let labels =
    match t.mode with
    | Editing ->
        [
          "Event Merchant / Edit";
          "Target: " ^ O.visible t.target;
          "Description: " ^ description_text t;
          "Disposition: " ^ choice_text t.choice;
        ]
    | Preview ->
        [
          "Event Merchant / Preview";
          "Target remains: " ^ O.visible t.target;
          "Description: " ^ description_text t;
          "Proposed: " ^ proposal_text t;
        ]
  in
  let details = List.concat_map wrap labels in
  if t.mode = Editing then
    let party_row =
      match t.choice with
      | Merchant -> [ "Party id: " ^ t.party_input ]
      | Nonmerchant -> [ "Party id: (not applicable)" ]
    in
    party_row @ details
  else details

let footer_rows ~width ~width_of t =
  let wrap text = O.wrap_text ~width_of (max 1 (width - 6)) text in
  let help =
    match t.mode with
    | Editing -> "Tab Merchant/Nonmerchant  Type party id  Enter preview  Esc/q cancel"
    | Preview -> "Enter publish  Esc/e edit  q cancel"
  in
  let footer =
    wrap help
    @ (if t.mode = Preview then wrap "First classification only; replacement is not available here."
       else [])
    @ if t.notice = "" then [] else wrap t.notice
  in
  footer

let review_visible ~width ~height ~width_of t =
  let c_rows = content_rows ~width ~width_of t in
  let f_rows = footer_rows ~width ~width_of t in
  let capacity = Panel.capacity ~height:(max 0 (height - List.length f_rows)) ~heading:false in
  height >= 14 && width >= 46 && List.length c_rows <= capacity

let handle ~blocked ~dimensions:(width, height) ~width_of t (input : Ui_input.input) : outcome =
  match t.mode with
  | Editing -> (
      match input with
      | `Key (`ASCII ('q' | 'Q'), []) | `Key (`Escape, []) -> Closed
      | `Key (`Tab, _) -> Updated { t with choice = next_choice t.choice; notice = "" }
      | `Key (`Backspace, _) -> (
          match t.choice with
          | Merchant ->
              let len = String.length t.party_input in
              if len > 0 then
                Updated { t with party_input = String.sub t.party_input 0 (len - 1); notice = "" }
              else Updated { t with notice = "" }
          | Nonmerchant -> Updated t)
      | `Key (`ASCII c, _) when c >= ' ' && c <= '~' -> (
          match t.choice with
          | Merchant ->
              if String.length t.party_input < 80 then
                Updated { t with party_input = t.party_input ^ String.make 1 c; notice = "" }
              else Updated t
          | Nonmerchant -> Updated t)
      | `Key (`Uchar u, _) -> (
          match t.choice with
          | Merchant ->
              if String.length t.party_input < 80 then (
                let b = Buffer.create 4 in
                Uutf.Buffer.add_utf_8 b u;
                Updated { t with party_input = t.party_input ^ Buffer.contents b; notice = "" })
              else Updated t
          | Nonmerchant -> Updated t)
      | `Key (`Enter, []) -> (
          match draft_disposition t with
          | Ok _ -> Updated { t with mode = Preview; notice = "" }
          | Error message -> Updated { t with notice = message })
      | _ -> Updated t)
  | Preview -> (
      match input with
      | `Key (`ASCII ('q' | 'Q'), []) -> Closed
      | `Key (`Escape, []) | `Key (`ASCII ('e' | 'E'), []) ->
          Updated { t with mode = Editing; notice = "" }
      | `Key (`Enter, []) -> (
          if not (review_visible ~width ~height ~width_of t) then
            Updated
              {
                t with
                notice =
                  "Enlarge terminal to review the Merchant target and proposal before Publish.";
              }
          else if blocked then Updated { t with notice = "Writes stopped; draft retained." }
          else
            match draft_disposition t with
            | Ok disposition -> Publish (t.target, disposition, t.base_revision)
            | Error message -> Updated { t with mode = Editing; notice = message })
      | _ -> Updated t)

let footer t =
  match t.mode with
  | Editing ->
      [ "Tab Merchant/Nonmerchant  Type party id  Enter preview  Esc/q cancel" ]
      @ if t.notice <> "" then [ t.notice ] else []
  | Preview ->
      [
        "Enter publish  Esc/e edit  q cancel";
        "First classification only; replacement is not available here.";
      ]
      @ if t.notice <> "" then [ t.notice ] else []

let screen ~dimensions:(width, height) ~width_of t =
  let styled_rows =
    match t.mode with
    | Editing ->
        let party_row =
          match t.choice with
          | Merchant ->
              let prompt = "Party id: " ^ t.party_input in
              (O.Input (width_of prompt), prompt)
          | Nonmerchant -> (O.Plain, "Party id: (not applicable)")
        in
        [
          party_row;
          (O.Heading, "Event Merchant / Edit");
          (O.Plain, "Target: " ^ O.visible t.target);
          (O.Plain, "Description: " ^ description_text t);
          (O.Plain, "Disposition: " ^ choice_text t.choice);
        ]
        @ if t.notice <> "" then [ (O.Status, t.notice) ] else []
    | Preview ->
        (if t.notice <> "" then [ (O.Status, t.notice) ] else [])
        @ [
            (O.Heading, "Event Merchant / Preview");
            (O.Plain, "Target remains: " ^ O.visible t.target);
            (O.Plain, "Description: " ^ description_text t);
            (O.Plain, "Proposed: " ^ proposal_text t);
            (O.Chrome, "First classification only; replacement is not available here.");
            (O.Active, " [Publish classification]");
          ]
  in
  Panel.frame_rows ~width_of ~width ~height ~focused:true ~title:"Event Merchant" styled_rows
