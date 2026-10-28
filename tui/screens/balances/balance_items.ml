module B = Bakhlo_household.Book
module D = Bakhlo_domain
module A = Daily_draft
open Book_display
open Locus_roles

let tr = Ui_text.tr

let is_balance_sheet_role = function
  | Asset | Liability | Equity -> true
  | Income | Expense -> false

let is_net_worth_role = function Asset | Liability -> true | Equity | Income | Expense -> false

type balance_item =
  | Header_row of string
  | Account_row of { locus : string; measure : string; role : role option; value : quantity_value }
  | Subtotal_row of { role : role; measure : string; subtotal : Z.t }
  | Balance_sheet_status of { measure : string; complete : bool }
  | Net_worth_row of { measure : string; known_subtotal : Z.t; complete : bool }
  | Blank_row

(* Accounting represents the coordinates of current Effects and support lines, never
   the admission list. Cached by the book.txt value, which every change replaces. *)
let represented_cache : (Bakhlo_book_txt.Book_txt.book * D.Effect_coordinate.t list) option ref =
  ref None

let compute_represented_coordinates book =
  let v = Bakhlo_book_txt.Book_txt.value (B.txt book) in
  let coordinate (l, m) : D.Effect_coordinate.t option =
    match (D.Identifier.Locus.of_string l, D.Identifier.Measure.of_string m) with
    | Ok locus, Ok measure -> Some { locus; measure }
    | _ -> None
  in
  List.concat_map
    (fun (tx : Bakhlo_book_txt.Book_txt.tx) ->
      List.map (fun (e : Bakhlo_book_txt.Book_txt.posting) -> (e.locus, e.measure)) tx.effects)
    v.txs
  @ v.zero_origins @ List.map fst v.openings
  @ List.concat_map (fun (a : Bakhlo_book_txt.Book_txt.anchor) -> List.map fst a.asserts) v.anchors
  |> List.sort_uniq compare |> List.filter_map coordinate
  |> List.sort_uniq D.Effect_coordinate.compare

let represented_coordinates book =
  let txt = B.txt book in
  match !represented_cache with
  | Some (cached, coordinates) when cached == txt -> coordinates
  | _ ->
      let coordinates = compute_represented_coordinates book in
      represented_cache := Some (txt, coordinates);
      coordinates

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

(* LOAM Role Balance presentation (Tui/RoleBalances.lean): per-Measure stock
   sections of exact rows, then the evidence details shared by every Measure.
   Each represented coordinate is exactly one of: exact with a role, exact with
   its role unresolved, or unsupported; nothing is coerced to 0. *)
let role_balance_items ~book ~roles =
  let rows =
    List.map
      (fun (c : D.Effect_coordinate.t) ->
        let locus = A.lstr c.locus and measure = A.mstr c.measure in
        (locus, measure, List.assoc_opt locus roles, quantity_value ~book ~measure locus))
      (represented_coordinates book)
  in
  let account (locus, measure, role, value) = Account_row { locus; measure; role; value } in
  let has_role pred (_, _, role, _) = match role with Some r -> pred r | None -> false in
  let exact (_, _, _, value) = match value with Exact _ -> true | _ -> false in
  let unsupported (_, _, _, value) = value = Unsupported in
  let unresolved (_, _, role, _) = role = None in
  let is_flow = function Income | Expense -> true | _ -> false in
  let in_measure m (_, measure, _, _) = measure = m in
  (* Role gaps in LOAM's order: exact, then unsupported. *)
  let gaps =
    List.filter (fun r -> unresolved r && exact r) rows
    @ List.filter (fun r -> unresolved r && unsupported r) rows
  in
  let sum =
    List.fold_left
      (fun acc (_, _, _, value) -> match value with Exact n -> Z.add acc n | _ -> acc)
      Z.zero
  in
  let amount measure n = (if Z.sign n > 0 then "+" else "") ^ format_money book measure n in
  let signed measure n = amount measure n ^ " " ^ measure in
  let token_pad = Ui_render.pad ~width_of:String.length 28 in
  let role_name (_, _, role, _) =
    match role with Some r -> role_label r | None -> "Unresolved role"
  in
  let measures =
    List.filter
      (fun m ->
        List.exists
          (fun r -> in_measure m r && (has_role is_balance_sheet_role r || unresolved r))
          rows)
      (List.map fst (B.measures book))
  in
  let measure_items m =
    let here = List.filter (in_measure m) rows in
    let stock_unsupported =
      List.filter (fun r -> unsupported r && has_role is_balance_sheet_role r) here
    in
    let worth_blocked = List.exists (fun r -> unsupported r && has_role is_net_worth_role r) here in
    let gaps_here = List.filter (in_measure m) gaps in
    let section role =
      let exact_rows = List.filter (fun r -> exact r && has_role (( = ) role) r) here in
      [ Header_row (role_label role) ]
      @ (if exact_rows = [] then [ Header_row "  (no supported rows)" ]
         else List.map account exact_rows)
      @ [ Subtotal_row { role; measure = m; subtotal = sum exact_rows } ]
    in
    let listed title items =
      if items = [] then [] else Header_row title :: List.map account items
    in
    let worth = sum (List.filter (fun r -> exact r && has_role is_net_worth_role r) here) in
    [ Header_row ("Measure: " ^ m); Header_row "Balance Sheet-shaped supported rows" ]
    @ section Asset @ [ Blank_row ] @ section Liability @ [ Blank_row ] @ section Equity
    @ [
        Blank_row;
        Balance_sheet_status { measure = m; complete = stock_unsupported = [] && gaps_here = [] };
      ]
    @ listed "Known stock-role coordinates without current balance support:" stock_unsupported
    @ listed "Coordinates whose AccountingRole is unresolved:" gaps_here
    @ [
        Blank_row;
        Net_worth_row
          { measure = m; known_subtotal = worth; complete = (not worth_blocked) && gaps_here = [] };
        Header_row
          (if (not worth_blocked) && gaps_here = [] then "Qualified Net Worth: " ^ signed m worth
           else "Qualified Net Worth: UNKNOWN");
        Header_row
          "Net Worth uses raw Asset + Liability quantity, exactly as the qualified projection \
           model.";
        Header_row "No cross-Measure valuation or conversion is inferred.";
        Blank_row;
      ]
  in
  let count p = List.length (List.filter p rows) and total = List.length rows in
  let supported = count exact and classified = count (fun r -> not (unresolved r)) in
  let bs_unsupported =
    List.filter (fun r -> unsupported r && has_role is_balance_sheet_role r) rows
  in
  let nw_unsupported = List.filter (fun r -> unsupported r && has_role is_net_worth_role r) rows in
  let flow_gaps = count (fun r -> unsupported r && has_role is_flow r) in
  let status ok = if ok then "ANSWERABLE" else "BLOCKED" in
  let blockers unsupported =
    Printf.sprintf "(%d unsupported, %d role blockers)" (List.length unsupported) (List.length gaps)
  in
  let coordinate (locus, measure, _, _) = locus ^ " / " ^ measure in
  let text lines = List.map (fun line -> Header_row line) lines in
  let gap_line (locus, measure, _, value) =
    "  ? " ^ token_pad locus
    ^ Ui_render.pad_left ~width_of:String.length 12
        (match value with Exact n -> amount measure n | _ -> "?")
    ^ " " ^ measure ^ "  role unresolved"
  in
  let unsupported_line ((locus, measure, _, _) as r) =
    "  ? " ^ token_pad locus ^ " balance unsupported  " ^ measure ^ "  " ^ role_name r
  in
  let supported_line ((locus, measure, _, value) as r) =
    "  " ^ token_pad locus
    ^ Ui_render.pad_left ~width_of:String.length 16
        (match value with Exact n -> signed measure n | _ -> "?")
    ^ "  " ^ role_name r
  in
  let by_measure =
    List.stable_sort (fun (l1, m1, _, _) (l2, m2, _, _) -> compare (m1, l1) (m2, l2))
  in
  let answerability =
    text
      ([
         "Answerability Map";
         "Which current accounting questions are justified by existing evidence?";
         Printf.sprintf "  Exact current quantity support  %d / %d coordinates" supported total;
         Printf.sprintf "  AccountingRole coverage  %d / %d coordinates" classified total;
         "  Balance Sheet            "
         ^ status (bs_unsupported = [] && gaps = [])
         ^ "  " ^ blockers bs_unsupported;
         "  Net Worth                "
         ^ status (nw_unsupported = [] && gaps = [])
         ^ "  " ^ blockers nw_unsupported;
         Printf.sprintf "  All current balances     %d / %d current quantities supported" supported
           total;
         Printf.sprintf
           "  Flow-role quantity gaps  %d  (Income / Expense; do not block Balance Sheet or Net \
            Worth)"
           flow_gaps;
         "";
         "Next evidence targets for Balance Sheet / Net Worth:";
       ]
      @ (if bs_unsupported = [] then [ "  No classified stock-role quantity blockers." ]
         else List.map (fun r -> "  [quantity] " ^ coordinate r ^ "  " ^ role_name r) bs_unsupported)
      @ (if gaps = [] then [ "  No unresolved AccountingRole blockers." ]
         else
           List.map
             (fun r ->
               "  [role] " ^ coordinate r ^ "  "
               ^ if exact r then "quantity known" else "quantity also unsupported")
             gaps)
      @ [
          "For an unsupported quantity blocker, explicit support can be zero-origin, opening, or \
           an exact current anchor.";
          "Add zero-origin only when retained history really begins at zero; never add it just to \
           erase '?'.";
          "Income / Expense role gaps remain visible here but do not block Balance Sheet or Net \
           Worth.";
        ])
  in
  let classified_rows = List.filter (fun r -> exact r && not (unresolved r)) rows |> by_measure in
  let classified_unsupported = List.filter (fun r -> unsupported r && not (unresolved r)) rows in
  let all_support =
    text
      ([
         "All current balance support";
         "Each current item is shown separately; role totals are not substituted for individual \
          rows.";
         ("Exact quantity support: " ^ if count unsupported = 0 then "COMPLETE" else "INCOMPLETE");
         ("Role classification: " ^ if gaps = [] then "COMPLETE" else "INCOMPLETE");
         "";
       ]
      @ (if classified_rows = [] then [ "No classified supported rows." ]
         else List.map supported_line classified_rows)
      @ (if gaps = [] then [] else "" :: "Unresolved role frontier:" :: List.map gap_line gaps)
      @
      if classified_unsupported = [] then []
      else
        "" :: "Classified coordinates without current balance support:"
        :: List.map unsupported_line classified_unsupported)
  in
  [ Header_row "Current Balances"; Header_row "What do I have and owe now?"; Blank_row ]
  @ (if measures = [] then
       [ Header_row "No Balance-Sheet-relevant or unresolved current coordinates are visible." ]
     else List.concat_map measure_items measures)
  @ [
      Header_row "Evidence details";
      Header_row "Why these balance answers are or are not justified.";
      Blank_row;
    ]
  @ answerability @ [ Blank_row ] @ all_support
  @ [
      Blank_row; Header_row "A known current amount does not prove that the full history is known.";
    ]

let balance_item_line ?(width_of = String.length) ?(width = max_int) ~book item =
  match item with
  | Blank_row -> ""
  | Header_row text -> text
  | Account_row { locus; measure; value; _ } ->
      let label = B.label book locus in
      let name =
        if label <> "" && label <> locus then Printf.sprintf "%s [%s]" label locus else locus
      in
      let full_val =
        match value with
        | Exact n ->
            (if Z.sign n > 0 then "+" else "") ^ format_money book measure n ^ " " ^ measure
        | Unsupported -> "? unsupported " ^ measure
      in
      (* Narrow fallback names the preserved state; exact digits are never truncated. *)
      let short_val =
        match value with
        | Exact _ -> "see details " ^ measure
        | Unsupported -> "? unsupported " ^ measure
      in
      let room = max 0 width in
      let val_w = width_of full_val in
      if room >= 2 + 22 + 2 + 18 && val_w <= 18 then
        "  " ^ Ui_render.pad ~width_of 22 name ^ "  " ^ Ui_render.pad_left ~width_of 18 full_val
      else
        let val_str = if 4 + val_w <= room then full_val else short_val in
        let name_room = min 22 (room - 4 - width_of val_str) in
        if name_room >= 1 then "  " ^ Ui_render.pad ~width_of name_room name ^ "  " ^ val_str
        else Ui_render.clip_text ~width_of room val_str
  | Subtotal_row { role = _; measure; subtotal } ->
      let sign_str = if Z.sign subtotal > 0 then "+" else "" in
      Printf.sprintf "  Known subtotal: %s%s %s" sign_str (B.format book measure subtotal) measure
  | Balance_sheet_status { complete; _ } ->
      if complete then "Balance Sheet support: COMPLETE" else "Balance Sheet support: INCOMPLETE"
  | Net_worth_row { measure; known_subtotal; complete = _ } ->
      let sign_str = if Z.sign known_subtotal > 0 then "+" else "" in
      let subtotal_str =
        Printf.sprintf "Known Net Worth subtotal: %s%s %s" sign_str
          (B.format book measure known_subtotal)
          measure
      in
      subtotal_str

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
        match role with Some r -> role_label r | None -> tr "Unresolved role (Neutral coordinate)"
      in
      let support_text =
        match value with
        | Exact n ->
            A.format_message "Exact current balance: %s %s" (format_money book measure n) measure
        | Unsupported ->
            tr
              "Unsupported: No current quantity support is justified for this coordinate. Do not \
               infer zero."
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
        | None -> tr "Locus × Measure; not an Account taxonomy."
        | Some (Asset | Liability) ->
            tr "Stock role: Enters Balance Sheet and Net Worth qualification."
        | Some Equity -> tr "Stock role: Enters Balance Sheet qualification."
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
        role_label role ^ " Subtotal";
        "";
        Printf.sprintf "Known exact sum: %s%s %s" sign_str (B.format book measure subtotal) measure;
        "";
        tr "Subtotals sum only exact quantities from supported rows.";
        tr "Unsupported rows are not substituted with zero.";
      ]
  | Balance_sheet_status { measure; complete } ->
      [
        "Balance Sheet Support (" ^ measure ^ ")";
        "";
        ("Status: " ^ if complete then "COMPLETE" else "INCOMPLETE");
        "";
        (if complete then
           tr
             "All stock-role coordinates (Asset, Liability, Equity) have exact quantity support \
              and explicit roles."
         else
           tr
             "Incomplete: One or more stock-role coordinates are unsupported or have unresolved \
              roles.");
      ]
  | Net_worth_row { measure; known_subtotal; complete } ->
      let sign_str = if Z.sign known_subtotal > 0 then "+" else "" in
      [
        "Net Worth (" ^ measure ^ ")";
        "";
        Printf.sprintf "Known Subtotal: %s%s %s" sign_str
          (B.format book measure known_subtotal)
          measure;
        ("Qualified: "
        ^
        if complete then
          Printf.sprintf "%s%s %s" sign_str (B.format book measure known_subtotal) measure
        else "UNKNOWN");
        "";
        tr "Net Worth = Asset + Liability quantities (raw signed sum).";
        tr "Qualified Net Worth is proven only when all stock roles are complete.";
        tr "No cross-currency valuation or conversion is ever inferred.";
      ]
