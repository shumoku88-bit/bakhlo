(* Settlements: reimbursement and external-obligation commitments with exact
   remaining amounts, and the Add / Settle / Reduce / Retract editors. Saved
   only through the Shell against the commitments this editor started from. *)
module B = Bakhlo_sexp.Daily_book
module Stl = Settlement_data
module O = Daily_overlays
module Form = Ui_form
module Panel = Ui_panel

let tr = Ui_text.tr

type pane = List_pane | Detail_pane
type editor = { form : Form.t; success : string }

type t = { selected : int; scope : Stl.scope; pane : pane; scroll : int; editor : editor option }

let config_files = []
let create () = { selected = 0; scope = Stl.Open_only; pane = List_pane; scroll = 0; editor = None }
let enter t = { t with pane = List_pane; scroll = 0; editor = None }
let modal t = Option.is_some t.editor
let form t = Option.map (fun e -> e.form) t.editor
let with_form form t = { t with editor = Option.map (fun e -> { e with form }) t.editor }
let selected t = t.selected
let detail_focused t = t.pane = Detail_pane
let scope t = t.scope

let rows (env : Screen.env) t =
  match env.settlements with Ok s -> Stl.visible_rows s t.scope | Error _ -> []

let selected_row env t = List.nth_opt (rows env t) t.selected

let move env t delta =
  let count = List.length (rows env t) in
  if count = 0 then t else { t with selected = max 0 (min (count - 1) (t.selected + delta)) }

let cycle_scope env t =
  let scope = match t.scope with Stl.Open_only -> Stl.All | Stl.All -> Stl.Open_only in
  let count = List.length (rows env { t with scope }) in
  { t with scope; selected = (if count = 0 then 0 else min (count - 1) t.selected) }

let add_form (env : Screen.env) =
  let def_measure = match B.measures env.book with (m, _) :: _ -> m | [] -> "jpy" in
  Form.create
    ~id:"add_settlement"
    ~title:"Add Settlement Commitment"
    ~summary:[
      "Track one reimbursement or external obligation.";
      "Debtor owes Creditor; positive remaining balance indicates open obligation.";
    ]
    ~fields:[
      Form.text_field ~id:"label" ~label:"Description" ~placeholder:"e.g. Dinner reimbursement, 懇親会立替" ();
      Form.text_field ~id:"debtor" ~label:"Debtor (owes)" ~value:"external" ();
      Form.text_field ~id:"creditor" ~label:"Creditor (owed)" ~value:"household" ();
      Form.text_field ~id:"measure" ~label:"Measure" ~value:def_measure ();
      Form.text_field ~id:"amount" ~label:"Committed amount" ~placeholder:"e.g. 5000" ();
      Form.action_buttons ~confirm:"Add Commitment" ~cancel:"Cancel" ();
    ]
    ()

let action_form (r : Stl.row) =
  let rem = Stl.outstanding r in
  let desc = match r.label with Some l -> l | None -> r.id in
  Form.create
    ~id:"action_settlement"
    ~payload:r.id
    ~title:("Settlement Action / " ^ r.id)
    ~summary:[
      "Target: " ^ desc;
      Printf.sprintf "Direction: %s -> %s" r.debtor r.creditor;
      Printf.sprintf "Committed: %s %s  Remaining: %s %s" (Z.to_string r.committed) r.measure (Z.to_string rem) r.measure;
    ]
    ~fields:[
      Form.choice_field ~id:"action_kind" ~label:"Action"
        ~options:[ "Settle (Payment received/made)"; "Reduce without payment"; "Retract commitment" ]
        ~selected:0 ();
      Form.text_field ~id:"amount" ~label:"Amount" ~value:(Z.to_string rem) ();
      Form.action_buttons ~confirm:"Confirm Action" ~cancel:"Cancel" ();
    ]
    ()

let amount_refusal ~positive measure = function
  | "non-positive-amount" -> tr (if positive then "Committed amount must be positive." else "Amount must be positive.")
  | "division-by-zero" -> tr "Amount divides by zero."
  | "indivisible-amount" -> tr "Result cannot fit the Measure scale."
  | "measure-scale-not-supplied" -> Printf.sprintf "Measure '%s' scale is not configured." measure
  | _ -> tr "Invalid amount."

let commit (env : Screen.env) t submitted update success =
  let refused why =
    ({ t with editor = Some { form = Form.set_notice submitted
        ("Settlements not confirmed: " ^ why ^ " Reload to inspect before retrying."); success } },
     Screen.Stay)
  in
  if env.blocked then refused "Writes stopped. Reload to inspect."
  else
    match Result.bind env.settlements (fun expected ->
        Result.map (fun next -> (expected, next)) (update expected)) with
    | Error why -> refused why
    | Ok (expected, next) ->
        ({ t with editor = Some { form = submitted; success } }, Screen.Save_settlements { expected; next })

let submit (env : Screen.env) t submitted =
  let stay notice = ({ t with editor = Some { form = Form.set_notice submitted notice; success = "" } }, Screen.Stay) in
  let text id = Option.value ~default:"" (Form.get_text submitted id) |> String.trim in
  match Form.id submitted with
  | "add_settlement" ->
      let debtor = text "debtor" and creditor = text "creditor" and measure = text "measure" in
      if debtor = "" then stay (tr "Enter debtor endpoint.")
      else if creditor = "" then stay (tr "Enter creditor endpoint.")
      else if measure = "" then stay (tr "Enter measure token.")
      else (
        match B.parse_amount env.book measure (text "amount") with
        | Error why -> stay (amount_refusal ~positive:true measure why)
        | Ok committed ->
            let label = match text "label" with "" -> None | l -> Some l in
            commit env t submitted
              (fun s -> Stl.add_row s ~id:(Stl.next_id s) ?label ~debtor ~creditor ~measure ~committed ())
              "Commitment added and read back.")
  | "action_settlement" -> (
      let id = Form.payload submitted in
      let kind_idx = Option.value ~default:0 (Form.get_choice submitted "action_kind") in
      match Result.bind env.settlements (fun s ->
          match Stl.find_row s id with Some r -> Ok r | None -> Error "Commitment not found.") with
      | Error why -> stay why
      | Ok r ->
          if kind_idx = 2 then
            commit env t submitted (fun s -> Stl.retract_row s ~id) (Printf.sprintf "Retracted commitment %s." id)
          else
            match B.parse_amount env.book r.measure (text "amount") with
            | Error why -> stay (amount_refusal ~positive:false r.measure why)
            | Ok amount ->
                let verb = if kind_idx = 0 then "Settled" else "Reduced" in
                commit env t submitted
                  (fun s -> if kind_idx = 0 then Stl.settle_row s ~id ~amount else Stl.reduce_row s ~id ~amount)
                  (Printf.sprintf "%s %s on %s." verb (Z.to_string amount) id))
  | _ -> (t, Screen.Stay)

(* Legacy navigation is kept: Esc/q always returns Home, Enter/i only open the
   detail, and Page/Home/End fall back to the first row of the list. *)
let handle (env : Screen.env) (geometry : Screen.geometry) t input =
  let stay t = (t, Screen.Stay) in
  let detail = t.pane = Detail_pane in
  match t.editor with
  | Some editor -> (
      match Form.handle_input editor.form input with
      | Form.Cancel -> stay { t with editor = None }
      | Form.Updated form -> stay { t with editor = Some { editor with form } }
      | Form.Submit submitted -> submit env t submitted)
  | None -> (
      let key = match input with
        | `Key (`ASCII c, mods) -> Some (`ASCII (Char.lowercase_ascii c), mods)
        | `Key (key, mods) -> Some (key, mods)
        | _ -> None
      in
      let page = max 1 (snd geometry.screen - 8) in
      match key with
      | Some ((`Escape | `ASCII 'q'), []) -> (t, Screen.Home)
      | Some (`ASCII 'n', []) -> stay { t with editor = Some { form = add_form env; success = "" } }
      | Some (`ASCII 'a', []) -> (
          match selected_row env t with
          | None -> (t, Screen.Message (tr "No commitment selected."))
          | Some r -> stay { t with editor = Some { form = action_form r; success = "" } })
      | Some (`ASCII 's', []) -> stay (cycle_scope env t)
      | Some ((`Tab | `ASCII 'w'), []) | Some (`Tab, [ `Shift ]) ->
          stay { t with pane = (if detail then List_pane else Detail_pane); scroll = 0 }
      | Some ((`Enter | `ASCII 'i'), []) -> stay { t with pane = Detail_pane; scroll = 0 }
      | Some (((`ASCII ('j' | 'k') | `Arrow (`Up | `Down)) as k), []) ->
          let delta = match k with `ASCII 'k' | `Arrow `Up -> -1 | _ -> 1 in
          if detail then stay { t with scroll = max 0 (t.scroll + delta) } else stay (move env t delta)
      | Some (`Page `Up, []) | Some (`ASCII 'u', [ `Ctrl ]) ->
          if detail then stay { t with scroll = max 0 (t.scroll - page) } else stay { t with selected = 0 }
      | Some (`Page `Down, []) | Some (`ASCII 'd', [ `Ctrl ]) ->
          if detail then stay { t with scroll = max 0 (t.scroll + page) } else stay { t with selected = 0 }
      | Some (`Home, []) -> stay { t with selected = 0; scroll = 0 }
      | Some (`End, []) -> stay { t with selected = 0; scroll = max_int / 4 }
      | _ -> (t, Screen.Ignored))

let saved _env _geometry result t =
  match t.editor, result with
  | Some editor, Ok () -> ({ t with editor = None }, Screen.Message editor.success)
  | Some editor, Error why ->
      ({ t with editor = Some { editor with form = Form.set_notice editor.form
           ("Settlements not confirmed: " ^ why ^ " Reload to inspect before retrying.") } },
       Screen.Stay)
  | None, _ -> (t, Screen.Stay)

let paint (env : Screen.env) (geometry : Screen.geometry) t =
  let width, height = geometry.content in
  let width_of = geometry.width_of in
  let visible = rows env t in
  let scope_label = match t.scope with Stl.Open_only -> "Open" | Stl.All -> "All current" in
  let left_title = match env.settlements with
    | Ok _ -> Printf.sprintf "Settlements [%s] (%d)" scope_label (List.length visible)
    | Error _ -> "Settlements / Unavailable" in
  let row_line (r : Stl.row) =
    let desc = match r.label with Some l -> l | None -> r.id in
    let rem = Stl.outstanding r in
    let status = if Z.equal rem Z.zero then "done" else "" in
    let trunc_desc = if String.length desc > 22 then String.sub desc 0 19 ^ "..." else desc in
    Printf.sprintf "%-22s  %10s %-4s %s" trunc_desc (Z.to_string rem) r.measure status
  in
  let left_rows = match env.settlements with
    | Error why -> O.wrap_text ~width_of (max 1 (width / 2 - 6))
        ("Settlements unavailable: " ^ why ^ ". Writes refused; Ctrl-R reloads.")
    | Ok _ -> if visible = [] then [ tr "  (no commitments in this scope)" ] else List.map row_line visible
  in
  let detail =
    match env.settlements, selected_row env t with
    | Error why, _ -> [ "Settlements unavailable (not empty)."; why; "Writes refused; Ctrl-R reloads." ]
    | Ok _, None -> [ tr "No selected commitment."; ""; tr "Press 'n' to add a new settlement commitment." ]
    | Ok _, Some r ->
        let rem = Stl.outstanding r in
        let desc = match r.label with Some l -> l | None -> "(no description)" in
        let effective = match r.effective_on with Some d -> d | None -> "(date unknown)" in
        [
          "Identity:    " ^ r.id;
          "Description: " ^ desc;
          "Direction:   " ^ r.debtor ^ " -> " ^ r.creditor;
          "Measure:     " ^ r.measure;
          "Committed:   " ^ Z.to_string r.committed ^ " " ^ r.measure;
          "Settled:     " ^ Z.to_string r.settled ^ " " ^ r.measure;
          "Adjusted:    " ^ Z.to_string r.extinguished ^ " " ^ r.measure;
          "Remaining:   " ^ Z.to_string rem ^ " " ^ r.measure;
          "Effective:   " ^ effective;
          "";
          "Allocations:";
          (if Z.gt r.settled Z.zero then Printf.sprintf "  Settled payment: %s %s" (Z.to_string r.settled) r.measure else "  Direct settlement: (none)");
          (if Z.gt r.extinguished Z.zero then Printf.sprintf "  Non-payment reduction: %s %s" (Z.to_string r.extinguished) r.measure else "  Reductions: (none)");
          "";
          "Actions:";
          "  a / Enter : Settlement action (Settle / Reduce / Retract)";
          "  s         : Cycle scope (Open only <-> All current)";
          "  n         : Add new settlement commitment";
        ]
  in
  let right_width = if width >= 80 then width - max 36 (min 58 (width * 52 / 100)) - 1 else width in
  let is_detail = t.pane = Detail_pane in
  Panel.split ~width_of ~width ~height
    ~left_focused:(not is_detail) ~left_title ~left_scroll:0
    ~left_selected:(if visible = [] then None else Some t.selected)
    ~left_rows
    ~right_focused:is_detail ~right_title:"Commitment Details"
    ~right_scroll:t.scroll ~right_selected:None
    ~right_rows:(List.concat_map (O.wrap_text ~width_of (max 1 (right_width - 6))) detail) ()

let view env (geometry : Screen.geometry) t =
  let overlay = Option.bind (form t)
      (Ui_overlay.form ~width_of:geometry.width_of ~screen:geometry.screen ~body:geometry.body) in
  {
    Screen.title = tr "Settlements";
    subtitle = Default;
    rows = lazy (paint env geometry t);
    footer =
      (if Option.is_some t.editor then
         [ "Enter submit  Tab next field  Esc cancel"; "Arrow keys / space to choose options" ]
       else [ "n add  a action  s scope  j/k select  Enter/Tab detail"; "q/Esc Home  Space Commands  Ctrl-r reload" ]);
    overlay;
    cursor = Option.bind overlay (fun frame -> frame.Ui_overlay.cursor);
  }
