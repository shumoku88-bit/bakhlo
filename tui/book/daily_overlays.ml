(* Shared physical terminal geometry and read-only evidence formatting.
   Controllers and editors own navigation; these primitives never publish. *)
module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query
module A = Daily_draft
let tr = Ui_text.tr

include Ui_render


type quantity_value = Unsupported | Known_present | Exact of Z.t

let quantity_value ~book ~measure locus =
  match D.Identifier.Locus.of_string locus, D.Identifier.Measure.of_string measure with
  | Ok locus, Ok measure ->
      let coordinate : D.Effect_coordinate.t = { locus; measure } in
      (match Q.query (B.image book) coordinate with
      | Error (Q.Support_unknown _) -> Unsupported
      | Ok (Q.Known_present _) -> Known_present
      | Ok (Q.Exact e) -> Exact (D.Quantity.quanta (Q.quantity e)))
  | Error _, _ | _, Error _ -> Unsupported

let quantity ~book ~measure locus =
  match quantity_value ~book ~measure locus with
  | Unsupported -> tr "Unknown"
  | Known_present -> tr "Present; amount unknown"
  | Exact n -> B.format book measure n

type accounting_role =
  | Asset
  | Liability
  | Equity
  | Income
  | Expense

let role_to_string = function
  | Asset -> "Asset"
  | Liability -> "Liability"
  | Equity -> "Equity"
  | Income -> "Income"
  | Expense -> "Expense"

let role_of_string s =
  match String.uppercase_ascii (String.trim s) with
  | "ASSET" -> Some Asset
  | "LIABILITY" -> Some Liability
  | "EQUITY" -> Some Equity
  | "INCOME" -> Some Income
  | "EXPENSE" -> Some Expense
  | _ -> None

let is_balance_sheet_role = function
  | Asset | Liability | Equity -> true
  | Income | Expense -> false

let is_net_worth_role = function
  | Asset | Liability -> true
  | Equity | Income | Expense -> false

let parse_accounting_roles text =
  let lines = String.split_on_char '\n' text in
  List.filter_map
    (fun line ->
      let line = String.trim line in
      if line = "" || String.starts_with ~prefix:";" line || String.starts_with ~prefix:"#" line then None
      else if String.starts_with ~prefix:"LOAM-ACCOUNTING-ROLE-MAP" line then None
      else
        let parts = String.split_on_char '\t' line in
        match parts with
        | [ "ROLE"; locus; role_str ] ->
            (match role_of_string role_str with
            | Some r -> Some (String.trim locus, r)
            | None -> None)
        | [ locus; role_str ] ->
            (match role_of_string role_str with
            | Some r -> Some (String.trim locus, r)
            | None -> None)
        | _ -> None)
    lines

type balance_item =
  | Header_row of string
  | Account_row of {
      locus : string;
      measure : string;
      role : accounting_role option;
      value : quantity_value;
    }
  | Subtotal_row of {
      role : accounting_role;
      measure : string;
      subtotal : Z.t;
    }
  | Balance_sheet_status of {
      measure : string;
      complete : bool;
    }
  | Net_worth_row of {
      measure : string;
      known_subtotal : Z.t;
      complete : bool;
    }
  | Blank_row

let role_balance_items ~book ~roles =
  let measures = List.map fst (B.measures book) in
  let approved = Option.value ~default:[] (B.approved_loci book) in
  let items_for_measure measure =
    let loci_with_roles =
      List.map (fun locus -> (locus, List.assoc_opt locus roles)) approved
    in
    let rows_for_role target_role =
      List.filter_map
        (fun (locus, r) ->
          if r = Some target_role then
            Some (locus, quantity_value ~book ~measure locus)
          else None)
        loci_with_roles
    in
    let unresolved_loci =
      List.filter (fun (_, r) -> r = None) loci_with_roles
    in
    let stock_roles = [ Asset; Liability; Equity ] in
    let flow_roles = [ Income; Expense ] in

    let is_role_complete role =
      let rows = rows_for_role role in
      List.for_all (fun (_, v) -> match v with Exact _ -> true | _ -> false) rows
    in
    let stock_complete =
      List.for_all is_role_complete stock_roles && unresolved_loci = []
    in
    let net_worth_complete =
      is_role_complete Asset && is_role_complete Liability && unresolved_loci = []
    in

    let sum_role role =
      List.fold_left
        (fun acc (_, v) ->
          match v with
          | Exact n -> Z.add acc n
          | _ -> acc)
        Z.zero (rows_for_role role)
    in
    let known_net_worth = Z.add (sum_role Asset) (sum_role Liability) in

    let section_widgets role =
      let rows = rows_for_role role in
      let header = Header_row (role_to_string role) in
      let account_rows =
        if rows = [] then [ Header_row "  (no supported rows)" ]
        else
          List.map
            (fun (locus, value) ->
              Account_row { locus; measure; role = Some role; value })
            rows
      in
      let subtotal =
        Subtotal_row { role; measure; subtotal = sum_role role }
      in
      [ header ] @ account_rows @ [ subtotal; Blank_row ]
    in

    let stock_sections = List.concat_map section_widgets stock_roles in

    let unresolved_section =
      if unresolved_loci = [] then []
      else
        [ Header_row "Coordinates whose AccountingRole is unresolved:" ]
        @ List.map
            (fun (locus, _) ->
              Account_row
                {
                  locus;
                  measure;
                  role = None;
                  value = quantity_value ~book ~measure locus;
                })
            unresolved_loci
        @ [ Blank_row ]
    in

    let flow_sections =
      let has_flow =
        List.exists (fun r -> rows_for_role r <> []) flow_roles
      in
      if not has_flow then []
      else
        [ Header_row "Flow-role coordinates (Income / Expense):" ]
        @ List.concat_map section_widgets flow_roles
    in

    let bs_status = Balance_sheet_status { measure; complete = stock_complete } in
    let nw_row =
      Net_worth_row
        {
          measure;
          known_subtotal = known_net_worth;
          complete = net_worth_complete;
        }
    in

    [
      Header_row ("Measure: " ^ measure);
      Header_row "Balance Sheet-shaped supported rows";
      Blank_row;
    ]
    @ stock_sections
    @ unresolved_section
    @ [ bs_status; Blank_row; nw_row; Blank_row ]
    @ flow_sections
  in
  List.concat_map items_for_measure measures

let current_balance_items ~book ~coords =
  let coords =
    match coords with
    | Some coords -> coords
    | None ->
        let loci = Option.value ~default:[] (B.approved_loci book) in
        let measures = List.map fst (B.measures book) in
        List.concat_map (fun l -> List.map (fun m -> (l, m)) measures) loci
  in
    List.map
      (fun (locus, measure) ->
        let value = quantity_value ~book ~measure locus in
        Account_row { locus; measure; role = None; value })
      coords

let format_money book measure q =
  let raw = B.format book measure q in
  let negative = String.starts_with ~prefix:"-" raw in
  let start = if negative then 1 else 0 in
  let stop = Option.value ~default:(String.length raw) (String.index_opt raw '.') in
  let out = Buffer.create (String.length raw + (stop - start) / 3) in
  if negative then Buffer.add_char out '-';
  for i = start to stop - 1 do
    if i > start && (stop - i) mod 3 = 0 then Buffer.add_char out ',';
    Buffer.add_char out raw.[i]
  done;
  Buffer.add_substring out raw stop (String.length raw - stop);
  Buffer.contents out

let balance_item_line ?(width_of = String.length) ?(width = max_int) ~book item =
  match item with
  | Blank_row -> ""
  | Header_row text -> text
  | Account_row { locus; measure; value; _ } ->
      let label = B.label book locus in
      let name =
        if label <> "" && label <> locus then
          Printf.sprintf "%s [%s]" label locus
        else locus
      in
      let full_val =
        match value with
        | Exact n ->
            (if Z.sign n > 0 then "+" else "") ^ format_money book measure n ^ " " ^ measure
        | Unsupported -> "? unsupported " ^ measure
        | Known_present -> "? amount unknown, known present " ^ measure
      in
      (* Narrow fallback names the preserved state; exact digits are never truncated. *)
      let short_val =
        match value with
        | Exact _ -> "see details " ^ measure
        | Unsupported -> "? unsupported " ^ measure
        | Known_present -> "? known present " ^ measure
      in
      let room = max 0 width in
      let val_w = width_of full_val in
      if room >= 2 + 22 + 2 + 18 && val_w <= 18 then
        "  " ^ pad ~width_of 22 name ^ "  " ^ pad_left ~width_of 18 full_val
      else
        let val_str = if 4 + val_w <= room then full_val else short_val in
        let name_room = min 22 (room - 4 - width_of val_str) in
        if name_room >= 1 then "  " ^ pad ~width_of name_room name ^ "  " ^ val_str
        else clip_text ~width_of room val_str
  | Subtotal_row { role = _; measure; subtotal } ->
      let sign_str = if Z.sign subtotal > 0 then "+" else "" in
      Printf.sprintf "  Known subtotal: %s%s %s" sign_str (B.format book measure subtotal) measure
  | Balance_sheet_status { complete; _ } ->
      if complete then "Balance Sheet support: COMPLETE"
      else "Balance Sheet support: INCOMPLETE"
  | Net_worth_row { measure; known_subtotal; complete } ->
      let sign_str = if Z.sign known_subtotal > 0 then "+" else "" in
      let subtotal_str =
        Printf.sprintf "Known Net Worth subtotal: %s%s %s" sign_str (B.format book measure known_subtotal) measure
      in
      let qualified_str =
        if complete then
          Printf.sprintf "Qualified Net Worth: %s%s %s" sign_str (B.format book measure known_subtotal) measure
        else "Qualified Net Worth: UNKNOWN"
      in
      subtotal_str ^ "  /  " ^ qualified_str

let balance_item_detail ~book item =
  match item with
  | Blank_row -> [ tr "Select an item to view its accounting support details." ]
  | Header_row text ->
      [
        text;
        "";
        tr "Accounting roles categorize accounts into balance sheet and flow components.";
        tr "Absence of an explicit role leaves the coordinate unresolved.";
      ]
  | Account_row { locus; measure; role; value } ->
      let label = B.label book locus in
      let role_name =
        match role with
        | Some r -> role_to_string r
        | None -> tr "Unresolved role (Neutral coordinate)"
      in
      let support_text =
        match value with
        | Exact n ->
            A.format_message "Exact current balance: %s %s" (format_money book measure n) measure
        | Unsupported ->
            tr "Unsupported: No current quantity support is justified for this coordinate. Do not infer zero."
        | Known_present ->
            tr "Known present: Presence is known; the exact current amount is unknown, not zero."
      in
      [
        (if label <> "" then Printf.sprintf "%s [%s]" label locus else locus);
        "";
        "Locus ID: " ^ locus;
        "Measure: " ^ measure;
        "Accounting Role: " ^ role_name;
        "Support: " ^ support_text;
        "";
        (match role with
        | None ->
            tr "Locus × Measure; not an Account taxonomy."
        | Some (Asset | Liability) ->
            tr "Stock role: Enters Balance Sheet and Net Worth qualification."
        | Some Equity ->
            tr "Stock role: Enters Balance Sheet qualification."
        | Some (Income | Expense) ->
            tr "Flow role: Flow coordinates do not block Balance Sheet or Net Worth.");
        "";
        "Actions:";
        "  o: Observe verified balance for this coordinate";
        "  v: Toggle Accounting / Current view";
      ]
  | Subtotal_row { role; measure; subtotal } ->
      let sign_str = if Z.sign subtotal > 0 then "+" else "" in
      [
        role_to_string role ^ " Subtotal";
        "";
        Printf.sprintf "Known exact sum: %s%s %s" sign_str (B.format book measure subtotal) measure;
        "";
        tr "Subtotals sum only exact quantities from supported rows.";
        tr "Unsupported or known-present rows are not substituted with zero.";
      ]
  | Balance_sheet_status { measure; complete } ->
      [
        "Balance Sheet Support (" ^ measure ^ ")";
        "";
        "Status: " ^ (if complete then "COMPLETE" else "INCOMPLETE");
        "";
        (if complete then
          tr "All stock-role coordinates (Asset, Liability, Equity) have exact quantity support and explicit roles."
        else
          tr "Incomplete: One or more stock-role coordinates are unsupported, amount-unknown, or have unresolved roles.");
      ]
  | Net_worth_row { measure; known_subtotal; complete } ->
      let sign_str = if Z.sign known_subtotal > 0 then "+" else "" in
      [
        "Net Worth (" ^ measure ^ ")";
        "";
        Printf.sprintf "Known Subtotal: %s%s %s" sign_str (B.format book measure known_subtotal) measure;
        "Qualified: " ^ (if complete then Printf.sprintf "%s%s %s" sign_str (B.format book measure known_subtotal) measure else "UNKNOWN");
        "";
        tr "Net Worth = Asset + Liability quantities (raw signed sum).";
        tr "Qualified Net Worth is proven only when all stock roles are complete.";
        tr "No cross-currency valuation or conversion is ever inferred.";
      ]

let locus_candidates book query =
  let query = String.lowercase_ascii (String.trim query) in
  let choices = Option.value ~default:[] (B.approved_loci book) in
  if query = "" then choices
  else
    let is_prefix text =
      Base.String.is_prefix (String.lowercase_ascii text) ~prefix:query
    in
    let matches = List.filter (fun id -> is_prefix id || is_prefix (B.label book id)) choices in
    let exact, rest = List.partition (fun id -> String.lowercase_ascii id = query) matches in
    exact @ rest

let signed book measure amount =
  (if Z.sign amount > 0 then "+" else "") ^ B.format book measure amount ^ " " ^ measure

let entry_lines book (entry : B.entry) =
  [tr "Effects (exact quantities):"]
  @ List.concat (List.mapi
      (fun n p ->
        let locus = A.lstr (D.Effect.locus p) and measure = A.mstr (D.Effect.measure p) in
        [ A.format_message "Posting %d: %s [%s]" (n + 1) (visible (B.label book locus)) (visible locus);
          "  " ^ signed book measure (A.quanta p) ^
          (match D.Effect.key p with None -> "" | Some key ->
            " / " ^ tr "Key:" ^ " " ^ visible (D.Identifier.Effect_key.to_string key)) ])
      entry.effects)
  @ [ ""; tr "Description:" ^ " " ^ (match entry.memo with None -> tr "(no description)" | Some text -> visible text);
      tr "Date:" ^ " " ^ entry.day; "ID: " ^ visible entry.id ]
  @ (match entry.original_amount with None -> [] | Some (m, q) ->
      [tr "Original amount:" ^ " " ^ B.format book m q ^ " " ^ visible m])
  @ (match entry.reversal_of with None -> [] | Some id -> [tr "Reversal of:" ^ " " ^ visible id])
  @ [tr "Merchant:" ^ " " ^
      (match entry.merchant with
       | None -> tr "Unresolved"
       | Some Nonmerchant -> tr "Nonmerchant"
       | Some (Merchant p) -> tr "Merchant " ^ visible (D.Identifier.External_party.to_string p))]
  @ (match entry.exchange with None -> [] | Some (a,b) -> [tr "Exchange keys:" ^ " " ^ visible a ^ " → " ^ visible b])
  @ (B.plans book |> List.filter_map (fun (p : B.plan) ->
      if p.paid_by = Some entry.id then Some (tr "Completed Scheduled:" ^ " " ^ visible p.id ^ " / " ^ p.day)
      else None))

let plan_lines book (plan : B.plan) =
  [tr "Expected Effects (exact quantities):"]
  @ List.mapi (fun n (locus, amount) ->
      A.format_message "Posting %d: %s [%s]  %s" (n+1)
        (visible (B.label book locus)) (visible locus) (signed book plan.measure amount)) plan.changes
  @ ["Due: " ^ plan.day; "ID: " ^ visible plan.id; "Measure: " ^ visible plan.measure]
  @ (match plan.cancelled_on, plan.paid_by with
      | Some day, _ -> [tr "Cancelled on:" ^ " " ^ day]
      | None, Some id -> [tr "Completed by Actual:" ^ " " ^ visible id]
      | None, None -> [tr "Open Scheduled occurrence"])

let preview_lines book (transaction : A.transaction) =
  (match transaction.plan with
  | Some id ->
      [tr "Complete Scheduled:" ^ " " ^ visible id; tr "Actual and completion link publish together."]
      @ (match List.find_opt (fun (p:B.plan) -> p.id=id) (B.plans book) with
        | None -> [] | Some p -> [tr "Original due date (kept):" ^ " " ^ p.day])
  | None -> [if transaction.replace then tr "Correct Actual (same ID)" else tr "Record new Movement"])
  @ entry_lines book transaction.entry
  @ (match transaction.entry.effects with
      | [] -> []
      | first :: _ ->
          let measure=A.mstr (D.Effect.measure first) in
          let total=List.fold_left (fun n posting ->
            let value=A.quanta posting in if Z.sign value>0 then Z.add n value else n)
            Z.zero transaction.entry.effects in
          [tr "Balanced total:" ^ " " ^ B.format book measure total ^ " " ^ measure])

let plan_preview_lines book ~replace (plan : B.plan) =
  [if replace then tr "Edit Scheduled (same ID)" else tr "Create new Scheduled"]
  @ plan_lines book plan
  @ (let total =
       List.fold_left
         (fun n (_, value) -> if Z.sign value > 0 then Z.add n value else n)
         Z.zero plan.changes
     in
     [tr "Balanced total:" ^ " " ^ B.format book plan.measure total ^ " " ^ plan.measure])

let bonsai_silhouette =
  [
    "               .:;;;:.";
    "          .:;;;;;::;;;;:.";
    "       .:;;;:. '\\|/ '::;'";
    "   .:;;;;;;:..  |";
    "    '::;;::'\\   /";
    "            \\_/";
    "            / \\";
    "      .----/---\\----.";
    "       \\___________/";
  ]

let center_line ~width ~width_of text =
  let w = width_of text in
  let pad = max 0 ((width - w) / 2) in
  clip_text ~width_of (max 0 width) (String.make pad ' ' ^ text)

let bonsai_home_lines ~width ~height ~width_of ~today =
  let tree_width = 32 in
  let capacity = max 0 height in
  let show_art = width >= tree_width && capacity >= 20 in
  let roomy = capacity >= 13 in
  let tree_rows =
    if not show_art then [ (Heading, center_line ~width ~width_of "bakhlo") ]
    else
      let rows =
        List.mapi (fun i line ->
          let style = if i >= 7 then Chrome else Bonsai in
          (style, center_line ~width ~width_of line)) bonsai_silhouette
      in
      rows @ [ (Plain, ""); (Heading, center_line ~width ~width_of "bakhlo") ]
  in
  let date_rows =
    if roomy then
      [ (Plain, ""); (Status, center_line ~width ~width_of today); (Plain, "") ]
    else
      [ (Status, center_line ~width ~width_of today) ]
  in
  let entrances =
    [
      ("r", tr "Record");
      ("s", tr "Scheduled");
      ("g", tr "Calendar");
      ("a", tr "Actual");
      ("b", tr "Balances");
      ("d", tr "Daily Pace");
    ]
  in
  let menu_rows =
    if capacity >= 8 then
      List.map (fun (key, label) ->
        let text = Printf.sprintf "  %s   %-14s" key label in
        (Entrance, center_line ~width ~width_of text)) entrances
    else
      let compact =
        [
          "r Record     s Scheduled";
          "g Calendar   a Actual";
          "b Balances   d Daily Pace";
        ]
      in
      List.map (fun line -> (Entrance, center_line ~width ~width_of line)) compact
  in
  let body = tree_rows @ date_rows @ menu_rows in
  let top_pad = max 0 ((capacity - List.length body) / 3) in
  let padded = List.init top_pad (fun _ -> (Plain, "")) @ body in
  let visible_body = List.filteri (fun i _ -> i < capacity) padded in
  let bottom_pad = max 0 (capacity - List.length visible_body) in
  let full_body = visible_body @ List.init bottom_pad (fun _ -> (Plain, "")) in
  List.map (fun (style, text) -> (style, clip_text ~width_of (max 0 width) text)) full_body

let progress_bar ~width ~ratio =
  let clamped = max 0.0 (min 1.0 ratio) in
  let inner_width = max 1 (width - 2) in
  let filled = int_of_float (float_of_int inner_width *. clamped) in
  let empty = max 0 (inner_width - filled) in
  "[" ^ String.make filled '#' ^ String.make empty '-' ^ "]"
