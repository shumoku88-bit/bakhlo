(* Manage Loci: admitted Locus tokens with their roles, labels and current
   quantities; admission and display names are ledger publications, accounting
   roles a checked configuration save of accounting-roles.tsv. *)
module B = Bakhlo_household.Book
module D = Bakhlo_domain
module A = Daily_draft
module O = Ui_render
module Roles = Locus_roles
module Form = Ui_form
module Panel = Ui_panel

let tr = Ui_text.tr
let roles_file = Roles.file_name

(* The unresolved holding Locus: not an account, and it never takes a role. *)
let suspense_locus = "suspense"

type pane = List_pane | Detail_pane

type editor =
  | Admit of Form.t
  | Role of Form.t
  | Label of Form.t
  | Label_review of {
      form : Form.t;
      editing : Form.t;
      locus : string;
      label : string;
      help : string;
    }

(* A role chosen while admitting is saved once the admission is read back. *)
type t = {
  selected : int;
  pane : pane;
  scroll : int;
  editor : editor option;
  pending_role : (string * Roles.role) option;
}

let config_files = [ roles_file ]
let create () = { selected = 0; pane = List_pane; scroll = 0; editor = None; pending_role = None }
let enter t = { t with pane = List_pane; scroll = 0; editor = None }
let modal t = Option.is_some t.editor
let selected t = t.selected
let detail_focused t = t.pane = Detail_pane

let form t =
  match t.editor with
  | None -> None
  | Some (Admit form | Role form | Label form | Label_review { form; _ }) -> Some form

let with_form form t =
  let editor =
    match t.editor with
    | None -> None
    | Some (Admit _) -> Some (Admit form)
    | Some (Role _) -> Some (Role form)
    | Some (Label _) -> Some (Label form)
    | Some (Label_review r) -> Some (Label_review { r with form })
  in
  { t with editor }

let admitted_loci book =
  match B.approved_loci book with
  | Some loci when loci <> [] -> loci
  | _ ->
      let from_entries =
        List.concat_map
          (fun (e : B.entry) -> List.map (fun p -> A.lstr (D.Effect.locus p)) e.effects)
          (B.entries book)
      in
      let from_plans =
        List.concat_map (fun (p : B.plan) -> List.map fst p.changes) (B.plans book)
      in
      List.sort_uniq String.compare (from_entries @ from_plans)

let selected_locus (env : Screen.env) t = List.nth_opt (admitted_loci env.book) t.selected

(* A role is an initial assignment and is never replaced. Unlike LOAM a used Locus
   without one may still receive it (user decision 2026-10-22): the role only
   classifies derived views, so assigning it rewrites no recorded fact. The
   unresolved holding Locus is not a case: it never takes a role. *)
type route = Role_assignment | Admission

let suspense_refusal = function
  | Role_assignment ->
      tr
        "suspense is the unresolved holding Locus: it takes no accounting role. Resolve it by \
         correcting the entries in Actual (/ search \"suspense\", then c)."
  | Admission ->
      tr
        "suspense is the unresolved holding Locus: it is admitted by Record's \"enable unresolved \
         recording\" (Ctrl-U), never with a role here."

let refusal_for ~route (env : Screen.env) locus =
  if locus = suspense_locus then Some (suspense_refusal route)
  else
    match Lazy.force env.accounting_roles with
    | Error why -> Some (tr "Accounting roles unavailable: " ^ why)
    | Ok roles when List.mem_assoc locus roles ->
        Some (tr "This Locus already has an accounting role; roles are never replaced.")
    | Ok _ -> None

let role_refusal (env : Screen.env) locus = refusal_for ~route:Role_assignment env locus
let admission_refusal (env : Screen.env) token = refusal_for ~route:Admission env token

let move (env : Screen.env) t delta =
  let count = List.length (admitted_loci env.book) in
  if count = 0 then t else { t with selected = max 0 (min (count - 1) (t.selected + delta)) }

let role_option_strings = [ "(Choose a role)"; "Asset"; "Liability"; "Equity"; "Income"; "Expense" ]

let role_of_index = function
  | 1 -> Some Roles.Asset
  | 2 -> Some Roles.Liability
  | 3 -> Some Roles.Equity
  | 4 -> Some Roles.Income
  | 5 -> Some Roles.Expense
  | _ -> None

let admit_form ~count =
  Form.create ~id:"admit_locus" ~title:"Admit New Locus"
    ~summary:
      [
        Printf.sprintf "Currently admitted: %d loci" count;
        "Admission establishes an approved coordinate token in the book.";
        "Every new Locus needs an accounting role for reports and balance sheets.";
      ]
    ~fields:
      [
        Form.text_field ~id:"token" ~label:"Stable token" ~placeholder:"e.g. cash, wallet, grocery"
          ();
        Form.choice_field ~id:"role" ~label:"Accounting Role" ~options:role_option_strings
          ~selected:0 ();
        Form.action_buttons ~confirm:"Admit Locus" ~cancel:"Cancel" ();
      ]
    ()

let role_form ~locus =
  Form.create ~id:"set_locus_role" ~payload:locus
    ~title:("Assign Accounting Role / " ^ locus)
    ~summary:
      [
        "Target Locus: " ^ locus;
        "Initial assignment only: an assigned role is never replaced.";
        "Saved to accounting-roles.tsv for role-aware balance sheets and reports.";
      ]
    ~fields:
      [
        Form.choice_field ~id:"role" ~label:"Accounting Role" ~options:role_option_strings
          ~selected:0 ();
        Form.action_buttons ~confirm:"Save Role" ~cancel:"Cancel" ();
      ]
    ()

let label_form ~locus ~current_label ~current_help =
  Form.create ~id:"set_locus_label" ~payload:locus ~title:("Edit Display Name / " ^ locus)
    ~summary:
      [
        "Target Locus: " ^ locus;
        "Display name is shown across views instead of the raw coordinate token.";
        "Help text provides description in locus detail.";
      ]
    ~fields:
      [
        Form.text_field ~id:"label" ~label:"Display name" ~value:current_label ();
        Form.text_field ~id:"help" ~label:"Help / description (optional)" ~value:current_help ();
        Form.action_buttons ~confirm:"Review" ~cancel:"Cancel" ();
      ]
    ()

let label_review_form locus label help =
  Form.create ~id:"review_locus_label" ~payload:locus ~title:"Review Locus Display Name"
    ~summary:
      [ "Stable identity: " ^ locus; "Display name:    " ^ label; "Help:            " ^ help ]
    ~fields:[ Form.action_buttons ~confirm:"Save display name" ~cancel:"Edit" () ]
    ()

(* Replace one role in the captured accounting-roles.tsv; the Shell refuses if
   the file changed since it was captured for this event. *)
let save_role (env : Screen.env) locus role =
  Result.bind (env.config roles_file) (fun expected ->
      let current =
        match expected with None -> Ok Roles.empty | Some text -> Roles.of_string text
      in
      Result.map
        (fun roles ->
          Screen.Save_config
            {
              file = roles_file;
              expected;
              content = Roles.to_string (Roles.set_role roles locus role);
              admission = Unconditional;
            })
        (Result.map_error (fun why -> roles_file ^ " " ^ why) current))

let submit (env : Screen.env) (geometry : Screen.geometry) t submitted =
  let keep editor notice =
    ({ t with editor = Some (editor (Form.set_notice submitted notice)) }, Screen.Stay)
  in
  match t.editor with
  | None -> (t, Screen.Stay)
  | Some (Admit _) -> (
      let token = Option.value ~default:"" (Form.get_text submitted "token") |> String.trim in
      if token = "" then keep (fun f -> Admit f) (tr "Enter the new Locus token.")
      else
        (* The role is saved after the admission, so refuse up front whatever would
           leave the new Locus without one. *)
        match
          ( admission_refusal env token,
            role_of_index (Option.value ~default:0 (Form.get_choice submitted "role")) )
        with
        | Some why, _ -> keep (fun f -> Admit f) why
        | None, None -> keep (fun f -> Admit f) (tr "Choose an accounting role.")
        | None, Some role ->
            ( { t with editor = Some (Admit submitted); pending_role = Some (token, role) },
              Screen.Publish (Add_locus token) ))
  | Some (Role _) -> (
      let locus = Form.payload submitted in
      let role = role_of_index (Option.value ~default:0 (Form.get_choice submitted "role")) in
      match (role_refusal env locus, role) with
      | Some why, _ -> keep (fun f -> Role f) why
      | None, None -> keep (fun f -> Role f) (tr "Choose an accounting role.")
      | None, Some _ -> (
          match save_role env locus role with
          | Error why -> keep (fun f -> Role f) why
          | Ok request -> ({ t with editor = Some (Role submitted) }, request)))
  | Some (Label _) ->
      let locus = Form.payload submitted in
      let text id = Option.value ~default:"" (Form.get_text submitted id) |> String.trim in
      let label = text "label" and help = text "help" in
      let valid s =
        s <> ""
        && String.length s <= 80
        && String.for_all (fun c -> Char.code c >= 32 && Char.code c <> 127) s
      in
      if not (valid label) then
        keep
          (fun f -> Label f)
          (tr "Display name must be 1-80 characters without control characters.")
      else
        let existing_help = B.help env.book locus in
        let help =
          if help <> "" then help else if existing_help <> "" then existing_help else label
        in
        if not (valid help) then
          keep
            (fun f -> Label f)
            (tr "Help description must be 1-80 characters without control characters.")
        else
          ( {
              t with
              editor =
                Some
                  (Label_review
                     {
                       form = label_review_form locus label help;
                       editing = submitted;
                       locus;
                       label;
                       help;
                     });
            },
            Screen.Stay )
  | Some (Label_review r) ->
      if not (Ui_overlay.form_fits ~width_of:geometry.width_of ~body:geometry.body submitted) then
        keep
          (fun form -> Label_review { r with form })
          (tr "Enlarge the terminal to review locus label before saving.")
      else
        ( { t with editor = Some (Label_review { r with form = submitted }) },
          Screen.Publish (Set_locus_label { locus = r.locus; label = r.label; help = r.help }) )

(* Legacy navigation is kept: Esc/q return Home, Enter/i open the detail and
   Page/Home/End move within the list. *)
let handle (env : Screen.env) (geometry : Screen.geometry) t input =
  let stay t = (t, Screen.Stay) in
  let detail = t.pane = Detail_pane in
  match t.editor with
  | Some editor -> (
      let current = Option.get (form t) in
      match Form.handle_input current input with
      | Form.Cancel -> (
          match editor with
          | Label_review r -> stay { t with editor = Some (Label r.editing) }
          | Admit _ | Role _ | Label _ -> stay { t with editor = None })
      | Form.Updated form -> stay (with_form form t)
      | Form.Submit submitted -> submit env geometry t submitted)
  | None -> (
      let key = Ui_input.key_ignoring_case input in
      let page = max 1 (snd geometry.screen - 8) in
      match key with
      | Some ((`Escape | `ASCII 'q'), []) -> (t, Screen.Home)
      | Some (`ASCII 'n', []) ->
          stay
            {
              t with
              editor = Some (Admit (admit_form ~count:(List.length (admitted_loci env.book))));
            }
      | Some (`ASCII 'r', []) -> (
          match selected_locus env t with
          | None -> (t, Screen.Message (tr "No locus selected."))
          | Some locus -> (
              match role_refusal env locus with
              | Some why -> (t, Screen.Message why)
              | None -> stay { t with editor = Some (Role (role_form ~locus)) }))
      | Some (`ASCII ('l' | 'e'), []) -> (
          match selected_locus env t with
          | None -> (t, Screen.Message (tr "No locus selected."))
          | Some locus ->
              let current_label = B.label env.book locus in
              let current_label = if current_label = locus then "" else current_label in
              stay
                {
                  t with
                  editor =
                    Some
                      (Label
                         (label_form ~locus ~current_label ~current_help:(B.help env.book locus)));
                })
      | Some ((`Tab | `ASCII 'w'), []) | Some (`Tab, [ `Shift ]) ->
          stay { t with pane = (if detail then List_pane else Detail_pane); scroll = 0 }
      | Some ((`Enter | `ASCII 'i'), []) -> stay { t with pane = Detail_pane; scroll = 0 }
      | Some (((`ASCII ('j' | 'k') | `Arrow (`Up | `Down)) as k), []) ->
          let delta = match k with `ASCII 'k' | `Arrow `Up -> -1 | _ -> 1 in
          if detail then stay { t with scroll = max 0 (t.scroll + delta) }
          else stay (move env t delta)
      | Some (`Page `Up, []) | Some (`ASCII 'u', [ `Ctrl ]) ->
          if detail then stay { t with scroll = max 0 (t.scroll - page) }
          else stay (move env t (-page))
      | Some (`Page `Down, []) | Some (`ASCII 'd', [ `Ctrl ]) ->
          if detail then stay { t with scroll = max 0 (t.scroll + page) }
          else stay (move env t page)
      | Some (`Home, []) ->
          if detail then stay { t with scroll = 0 } else stay { t with selected = 0 }
      | Some (`End, []) ->
          if detail then stay { t with scroll = max_int / 4 }
          else stay { t with selected = max 0 (List.length (admitted_loci env.book) - 1) }
      | _ -> (t, Screen.Ignored))

let saved _env _geometry result t =
  match (t.editor, result) with
  | Some (Role form), Ok () ->
      let locus = Form.payload form in
      let role = role_of_index (Option.value ~default:0 (Form.get_choice form "role")) in
      let role_str = match role with None -> "None" | Some r -> Roles.role_label r in
      ( { t with editor = None },
        Screen.Message (Printf.sprintf "Set accounting role for %s to %s." locus role_str) )
  | Some (Role form), Error why ->
      ({ t with editor = Some (Role (Form.set_notice form why)) }, Screen.Stay)
  | None, Error why ->
      (* Role chosen during admission: the locus is admitted, the role is not. *)
      (t, Screen.Message ("Locus admitted; accounting role not saved: " ^ why))
  | _, Ok () -> (t, Screen.Stay)
  | Some (Admit _ | Label _ | Label_review _), Error _ -> (t, Screen.Stay)

let published (env : Screen.env) _geometry outcome t =
  let notice why = (with_form (Form.set_notice (Option.get (form t)) why) t, Screen.Stay) in
  match (outcome, t.editor) with
  | _, None -> (t, Screen.Stay)
  | Screen.Publish_refused why, Some _ -> notice why
  | Screen.Publish_conflict, Some _ -> notice (tr "File changed on disk. Reload to inspect.")
  | Screen.Publish_stopped, Some _ -> ({ t with editor = None; pending_role = None }, Screen.Stay)
  | Screen.Published, Some (Admit _) -> (
      let pending = t.pending_role in
      let t = { t with editor = None; pending_role = None } in
      match pending with
      | None -> (t, Screen.Stay)
      | Some (locus, role) -> (
          match
            match admission_refusal env locus with
            | Some why -> Error why
            | None -> save_role env locus (Some role)
          with
          | Ok request -> (t, request)
          | Error why -> (t, Screen.Message ("Locus admitted; accounting role not saved: " ^ why))))
  | Screen.Published, Some _ -> ({ t with editor = None }, Screen.Stay)

(* Detail prose breaks between words, continuing at the line's indent; a word
   wider than the room falls back to the character wrap. *)
let wrap_words ~width_of room text =
  let body = String.trim text in
  let rec leading i = if i < String.length text && text.[i] = ' ' then leading (i + 1) else i in
  let indent = String.make (leading 0) ' ' in
  let room' = room - String.length indent in
  if body = "" || width_of text <= room || room' < 8 then O.wrap_text ~width_of room text
  else
    let words = List.filter (( <> ) "") (String.split_on_char ' ' body) in
    let lines, current =
      List.fold_left
        (fun (lines, current) word ->
          let next = if current = "" then word else current ^ " " ^ word in
          if width_of next <= room' then (lines, next)
          else if current = "" then (lines, word)
          else (current :: lines, word))
        ([], "") words
    in
    List.concat_map
      (fun line -> List.map (fun piece -> indent ^ piece) (O.wrap_text ~width_of room' line))
      (List.rev (current :: lines))

let paint (env : Screen.env) (geometry : Screen.geometry) t =
  let width, height = geometry.content in
  let width_of = geometry.width_of in
  let book = env.book in
  let loci = admitted_loci book in
  let roles = Lazy.force env.accounting_roles in
  let role_of locus = match roles with Ok roles -> List.assoc_opt locus roles | Error _ -> None in
  (* An unreadable file is "?", never "unassigned". *)
  let role_tag locus =
    match (roles, role_of locus) with
    | Error _, _ -> "[?]"
    | Ok _, Some r -> "[" ^ Roles.role_label r ^ "]"
    | Ok _, None -> "[--]"
  in
  (* Columns fit the list pane; when the label would be squeezed out the role
     column yields first, since the detail pane names the role. *)
  let left_width = if width >= 80 then max 36 (min 58 (width * 52 / 100)) else width in
  let room = left_width - 6 in
  let widest f = List.fold_left (fun w locus -> max w (width_of (f locus))) 0 loci in
  let token_w = min 18 (widest Fun.id) and role_w = widest role_tag in
  let with_role = room >= token_w + 2 + role_w + 2 + 8 in
  let locus_line locus =
    let label = B.label book locus in
    let label = if label <> "" && label <> locus then label else "" in
    let cells =
      O.pad ~width_of token_w locus
      :: (if with_role then [ O.pad ~width_of role_w (role_tag locus) ] else [])
    in
    String.concat "  " (cells @ [ label ])
  in
  let left_rows =
    if loci = [] then [ tr "No admitted loci in this book." ] else List.map locus_line loci
  in
  let balances_of locus =
    List.map
      (fun (m, _) ->
        Printf.sprintf "  %s: %s" (String.uppercase_ascii m)
          (Book_display.quantity ~book ~measure:m locus))
      (B.measures book)
  in
  let suspense_detail =
    [
      "Locus Token:      " ^ suspense_locus;
      "Kind:             unresolved recording holding";
      "";
      "Current Balances:";
    ]
    @ (match balances_of suspense_locus with [] -> [ "  (no measures)" ] | balances -> balances)
    @ [
        "";
        "This Locus holds Effects whose real account is not yet known. It is not an";
        "account: it takes no accounting role. The Balances accounting view lists it";
        "as an unresolved role gap, so Net Worth reads unknown while it holds";
        "something. Correcting those entries in Actual clears it:";
        "  /  search \"suspense\"    c  Correct the entry to its real Locus";
        "";
        "Frontiers:";
        "  n : Admit new Locus token";
        "  q / Esc : Return to Home";
      ]
  in
  let detail =
    match selected_locus env t with
    | None -> [ tr "No selected locus."; ""; tr "Press 'n' to admit a new coordinate token." ]
    | Some locus when locus = suspense_locus -> suspense_detail
    | Some locus ->
        let label = B.label book locus in
        let role_opt = role_of locus in
        let role_str =
          match (roles, role_opt) with
          | Error _, _ -> "Unavailable (" ^ roles_file ^ " unreadable)"
          | Ok _, None -> "None / Unassigned"
          | Ok _, Some r -> Roles.role_label r
        in
        let balances = balances_of locus in
        [
          "Locus Token:      " ^ locus;
          ("Display Label:    " ^ if label <> "" then label else "(same as token)");
          "Accounting Role:  " ^ role_str;
          "";
          "Current Balances:";
        ]
        @ (if balances = [] then [ "  (no measures)" ] else balances)
        @ [
            "";
            "Role Impact:";
            (match (roles, role_opt) with
            | Error why, _ -> "  " ^ why
            | Ok _, Some Roles.Asset -> "  Asset: Positive balance represents owned resources."
            | Ok _, Some Roles.Liability -> "  Liability: Positive balance represents debt owed."
            | Ok _, Some Roles.Equity -> "  Equity: Capital / opening balance baseline."
            | Ok _, Some Roles.Income -> "  Income: Inflow tracking for reporting."
            | Ok _, Some Roles.Expense -> "  Expense: Outflow tracking for reporting."
            | Ok _, None -> "  Unassigned: excluded from role summaries; press r to assign one.");
            "";
            "Actions:";
            "  n : Admit new Locus token";
            "  r : Assign role (Locus without one)";
          ]
  in
  let right_width = if width >= 80 then width - max 36 (min 58 (width * 52 / 100)) - 1 else width in
  let is_detail = t.pane = Detail_pane in
  Panel.split ~width_of ~width ~height ~left_focused:(not is_detail)
    ~left_title:
      (match
         match roles with
         | Ok roles ->
             List.length
               (List.filter (fun l -> l <> suspense_locus && not (List.mem_assoc l roles)) loci)
         | Error _ -> 0
       with
      | 0 -> Printf.sprintf "Manage Loci (%d admitted)" (List.length loci)
      | n -> Printf.sprintf "Manage Loci (%d, %d without role)" (List.length loci) n)
    ~left_scroll:0
    ~left_selected:(if loci = [] then None else Some t.selected)
    ~left_rows ~right_focused:is_detail ~right_title:"Locus Detail" ~right_scroll:t.scroll
    ~right_selected:None
    ~right_rows:(List.concat_map (wrap_words ~width_of (max 1 (right_width - 6))) detail)
    ()

let view env (geometry : Screen.geometry) t =
  let overlay =
    Option.bind (form t)
      (Ui_overlay.form ~width_of:geometry.width_of ~screen:geometry.screen ~body:geometry.body)
  in
  {
    Screen.title = tr "Manage Loci";
    subtitle = Default;
    rows = lazy (paint env geometry t);
    footer =
      (if Option.is_some t.editor then
         [ "Enter submit  Tab next field  Esc cancel"; "Arrow keys / space to choose options" ]
       else
         [
           "n admit locus  r assign role  j/k select  Enter/Tab detail";
           "q/Esc Home  Space Commands  Ctrl-r reload";
         ]);
    overlay;
    cursor = Option.bind overlay (fun frame -> frame.Ui_overlay.cursor);
  }
