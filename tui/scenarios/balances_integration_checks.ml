(* Synthetic controller integration checks; see docs/RECONSTRUCTION_TEST_MAP.ja.md. *)
open Interaction_check_fixture

let balance_display_checks ~width_of ~directory () =
  let directory = directory ^ "/balance-display" in
  Unix.mkdir directory 0o700;
  let path = directory ^ "/book.sexp" in
  F.write_new path
    "(bakhlo-daily 1) (scope corrected-entries explicit-plans)\n\
     (measures (measure jpy 0) (measure eur 2)) (labels (not-supplied))\n\
     (approved-loci (provided wallet zero bank)) (entries) (plans)\n\
     (support (zero-origin (zero jpy)) (openings)\n\
     (observations (observation (reflected) (quantities (wallet jpy 74500))))\n\
     (presence (not-supplied)))";
  let home = C.initial ~config_home:directory (F.load path) in
  let book = home.session.book in
  let item value = O.Account_row { locus = "wallet"; measure = "jpy"; role = None; value } in
  let exact = item (O.Exact (Z.of_int 74500)) in
  let line ~width row = O.balance_item_line ~width_of ~width ~book row in
  let has text needle = Base.String.is_substring text ~substring:needle in
  require (has (line ~width:26 exact) "+74,500 jpy") "balance-narrow-exact-amount";
  let huge = Z.of_string (String.make 100 '7') in
  let huge_item = item (O.Exact huge) in
  require
    (has (line ~width:26 huge_item) "details"
     && not (has (line ~width:26 huge_item) "777"))
    "balance-unfit-quantity-is-not-partial-digits";
  List.iter (fun measure ->
    let row = O.Account_row { locus = "wallet"; measure; role = None; value = O.Unsupported } in
    require (has (O.balance_item_line ~width_of ~width:26 ~book row) measure)
      "balance-unknown-row-keeps-measure";
    let row = O.Account_row { locus = "wallet"; measure; role = None; value = O.Exact huge } in
    require (has (O.balance_item_line ~width_of ~width:26 ~book row) measure)
      "balance-huge-cue-keeps-measure")
    ["jpy"; "eur"];
  require
    (has (O.balance_item_line ~width_of ~book huge_item) (O.format_money book "jpy" huge))
    "balance-unbounded-print-retains-huge-quantity";
  require (O.format_money book "eur" (Z.of_int (-123456)) = "-1,234.56")
    "balance-grouping-preserves-sign-scale";
  List.iter
    (fun value ->
      List.iter
        (fun width -> require (width_of (line ~width (item value)) <= width)
            "balance-row-fits-real-width")
        [ 0; 1; 8; 26; 42; 80 ])
    [ O.Exact huge; O.Exact (Z.of_int (-74500)); O.Unsupported; O.Known_present ];
  require
    (has (line ~width:26 (item O.Unsupported)) "unsupported"
     && has (line ~width:26 (item O.Known_present)) "present"
     && has (line ~width:26 (item (O.Exact Z.zero))) "0 jpy")
    "balance-unknown-presence-zero-distinct";
  let view = C.open_route home W.Balances in
  let coordinate state =
    match List.nth_opt (balance_items state) (Balances.selected state.C.screens.balances) with
    | Some (O.Account_row { locus; measure; _ }) -> Some (locus, measure)
    | _ -> None in
  let wallet_index = Option.get (List.find_index (function
    | O.Account_row { locus = "wallet"; measure = "jpy"; _ } -> true | _ -> false)
    (balance_items view)) in
  let wallet = { view with screens = { view.screens with balances = Balances.set_selected wallet_index view.screens.balances } } in
  let accounting = key ~width_of wallet (`ASCII 'v') in
  let current = key ~width_of accounting (`ASCII 'v') in
  require (coordinate accounting = Some ("wallet", "jpy") && coordinate current = Some ("wallet", "jpy"))
    "balance-mode-switch-keeps-exact-coordinate-not-header";
  (* As LOAM: Accounting represents evidence coordinates, not admission x Measure. *)
  let represented = List.filter_map (function
    | O.Account_row { locus; measure; _ } -> Some (locus, measure) | _ -> None) (balance_items accounting) in
  require (List.mem ("zero", "jpy") represented && not (List.mem ("wallet", "eur") represented)
           && not (List.exists (fun (locus, _) -> locus = "bank") represented))
    "accounting-represents-evidence-coordinates-not-admissions";
  List.iter (fun state ->
    let heading = Balances.mode state.C.screens.balances = `Current in
    List.iter (fun dimensions ->
      let head = key ~dimensions ~width_of state `Home in
      (* Current paints one heading row inside the list frame; padding rows never
         enlarge the scrollable capacity. *)
      let rec painted_capacity inside count = function
        | [] -> count
        | (_, row) :: rest ->
            if inside && String.starts_with ~prefix:"╰" row then
              max 0 (count - (if heading then 1 else 0))
            else if inside then painted_capacity true (count + 1) rest
            else painted_capacity (String.starts_with ~prefix:"╭" row) count rest in
      let capacity = painted_capacity false 0 (R.screen ~width_of dimensions head) in
      let next = key ~dimensions ~width_of head (`Page `Down) in
      require (Balances.selected next.C.screens.balances = min capacity (List.length (balance_items head) - 1))
        "balance-page-matches-actual-painted-list-capacity")
      [(120,36); (80,24); (48,14); (32,9)])
    [accounting; current];
  let medium_rows = R.screen ~width_of (80, 24) view in
  let medium = String.concat "\n" (List.map snd medium_rows) in
  require (not (List.exists (function C.Columns _, _ -> true | _ -> false) medium_rows)
    && has medium "74,500 jpy" && not (has medium "+74,500"))
    "balances-medium-stacks-with-scaled-amount-and-measure";
  let painted = R.screen ~width_of (32, 9) view |> List.map snd |> String.concat "\n" in
  require (has painted "74,500" && has painted "jpy" && not (has painted "+74,500"))
    "balance-tiny-first-coordinate-shows-scaled-amount-and-measure";
  let huge_book = get (B.observe_quantities book [("wallet", "jpy", Z.neg huge)]) in
  let large = C.open_route { home with session = { home.session with book = huge_book } } W.Balances in
  List.iter (fun dimensions ->
    let detail = key ~dimensions ~width_of large (`ASCII 'i') in
    let at_end = key ~dimensions ~width_of detail `End in
    let up = key ~dimensions ~width_of at_end (`Arrow `Up) in
    let _, viewport = Balances.detail_viewport (X.balances_env detail) (X.screen_geometry ~dimensions ~width_of detail) detail.screens.balances in
    let page = key ~dimensions ~width_of detail (`Page `Down) in
    let stepped = List.fold_left (fun state _ -> key ~dimensions ~width_of state (`ASCII 'j'))
        detail (List.init viewport.capacity Fun.id) in
    require (R.screen ~width_of dimensions page = R.screen ~width_of dimensions stepped)
      "balance-detail-page-matches-visible-capacity";
    if viewport.last > 0 then require
      (R.screen ~width_of dimensions up <> R.screen ~width_of dimensions at_end)
      "balance-end-up-moves-visible-detail";
    let printed = key ~dimensions ~width_of at_end (`ASCII 'p') in
    let printed_end = key ~dimensions ~width_of printed `End in
    let printed_up = key ~dimensions ~width_of printed_end (`Arrow `Up) in
    require (calendar_scroll printed_end = calendar_scroll at_end
      && (Balances.selected printed_end.C.screens.balances) = (Balances.selected large.C.screens.balances))
      "balance-print-keeps-parent-context";
    require (Balances.modal printed.screens.balances) "balance-print-overlay-open";
    (match Balances.print_preview_summary printed.screens.balances with
     | Some summary ->
         let pane_w = min 64 (max 8 (fst dimensions - 4)) in
         let rows = List.concat_map (O.wrap_text ~width_of (max 1 (pane_w - 6))) summary in
         require (has (String.concat "" rows) (O.format_money huge_book "jpy" (Z.neg huge)))
           "balance-print-wrap-retains-full-negative-quantity";
         let pane_h = min (snd dimensions) (max 3 (List.length rows + 2)) in
         let print_view = Ui_panel.window ~capacity:(Ui_panel.capacity ~height:pane_h ~heading:false) ~count:(List.length rows) ~scroll:0 ~selected:None in
         if print_view.last > 0 then begin
           let s_end = R.overlay_screen ~dimensions ~width_of printed_end in
           let s_up = R.overlay_screen ~dimensions ~width_of printed_up in
           if s_end = s_up then
             Printf.eprintf "DIM %dx%d: print_view.last=%d, s_end is equal to s_up!\n%!"
               (fst dimensions) (snd dimensions) print_view.last;
           require (s_end <> s_up) "balance-print-end-up-moves-visible-report"
         end
     | None -> raise (F.Refused "balance-print-not-open"));
    require (not (Balances.modal (key ~dimensions ~width_of printed_end `Enter).C.screens.balances))
      "balance-print-enter-closes-without-save";
    let closed = key ~dimensions ~width_of printed_end `Escape in
    require (calendar_scroll closed = calendar_scroll at_end && not (Balances.modal closed.screens.balances)
      && F.read_revision path = home.session.revision) "balance-print-close-preserves-parent-without-save")
    [(120,36); (80,24); (48,14); (32,9)];
  require (Balances.print_fits [String.make 32767 'x']
    && not (Balances.print_fits [String.make 32768 'x'])
    && Balances.print_fits (List.init 200 (fun _ -> ""))
    && not (Balances.print_fits (List.init 201 (fun _ -> ""))))
    "balance-print-exact-byte-and-line-limits-including-newlines";
  let oversized = get (B.observe_quantities book
    [("wallet", "jpy", Z.of_string (String.make 25000 '7'))]) in
  let refused = Balances.print_preview_form { (X.balances_env view) with book = oversized } view.screens.balances in
  require (Ui_form.id refused = "balance_print_refused" && F.read_revision path = home.session.revision)
    "balance-print-refuses-real-oversized-quantity-without-save";
  let oversized_view = { view with session = { view.session with book = oversized } } in
  let refusal = key ~width_of oversized_view (`ASCII 'p') in
  require (Option.map Ui_form.id (Balances.form refusal.screens.balances) = Some "balance_print_refused"
           && not (Balances.modal (key ~width_of refusal `Enter).C.screens.balances))
    "balance-print-refusal-enter-closes";
  require (O.current_balance_items ~book ~coords:(Some []) = [])
    "balance-empty-has-no-selectable-placeholder";
  F.write_new (directory ^ "/balance-view.tsv") "";
  let empty = R.screen ~width_of (32, 9) view |> List.map snd |> String.concat "\n" in
  require
    (has empty "No balances are selected" && has empty "0/0" && not (has empty "0 jpy"))
    "balance-empty-shows-state-evidence-and-zero-counter-not-zero";
  print_endline "PASS: Balances first coordinate, exact-or-detail quantities and empty evidence states."

(* UI-24-B2: visible-account picker and multi-coordinate observation. Drives
   only keys/screen/file-bytes/cold quantities so it survives controller
   restyling; asserts LOAM-parity behavior, not widget ids. *)

let b2_overlay_open (state : C.state) =
  (match state.C.overlay with C.No_overlay -> Option.is_some (Screen_registry.modal state.screens) | _ -> true)

let b2_screen ~width_of dimensions state =
  R.screen ~width_of dimensions state

let b2_overlay_text ~width_of dimensions state =
  match R.overlay_screen ~dimensions ~width_of state with
  | None -> ""
  | Some rows -> String.concat "\n" (List.map snd rows)

let b2_check_qty book locus measure =
  let module Q = Bakhlo_application.Current_quantity_query in
  let locus = C.get_id (D.Identifier.Locus.of_string locus) in
  let measure = C.get_id (D.Identifier.Measure.of_string measure) in
  match Q.query (B.image book) { D.Effect_coordinate.locus; measure } with
  | Ok (Q.Exact x) -> Z.to_string (D.Quantity.quanta (Q.quantity x))
  | _ -> "unexpected"

let b2_book_fixture =
  "(bakhlo-daily 1) (scope corrected-entries explicit-plans)\n\
   (measures (measure jpy 0) (measure eur 2)) (labels (not-supplied))\n\
   (approved-loci (provided wallet bank food zero)) (entries) (plans)\n\
   (support (zero-origin (zero jpy)) (openings)\n\
   (observations (observation (reflected) (quantities (food jpy 5500))))\n\
   (presence (not-supplied)))"

let balance_picker_checks ~width_of ~directory () =
  let directory = directory ^ "/balance-picker" in
  Unix.mkdir directory 0o700;
  let path = directory ^ "/book.sexp" in
  F.write_new path b2_book_fixture;
  let bv = directory ^ "/balance-view.tsv" in
  let replace file bytes = (if Sys.file_exists file then Unix.unlink file); F.write_new file bytes in
  F.write_new bv "wallet\tjpy\nbank\tjpy\nbank\teur\n";
  let fresh () = C.open_route (C.initial ~config_home:directory (F.load path)) W.Balances in
  let view = fresh () in
  let before = F.read bv and book_before = F.read path in
  (* Open picker: must open without writing. *)
  let opened = key ~width_of view (`ASCII 'c') in
  require (b2_overlay_open opened && F.read bv = before && F.read path = book_before)
    "picker-open-no-write";
  let shown = b2_overlay_text ~width_of (100, 30) opened in
  require (Base.String.is_substring shown ~substring:"wallet" && Base.String.is_substring shown ~substring:"bank")
    "picker-lists-candidates";
  (* j/k/up/down clamp without crashing or writing. *)
  let moved = key ~width_of ~dimensions:(100, 30) opened (`ASCII 'j') in
  let moved = key ~width_of ~dimensions:(100, 30) moved (`ASCII 'j') in
  let moved = key ~width_of ~dimensions:(100, 30) moved (`ASCII 'k') in
  let moved = key ~width_of ~dimensions:(100, 30) moved (`Arrow `Up) in
  let moved = key ~width_of ~dimensions:(100, 30) moved (`Arrow `Down) in
  require (b2_overlay_open moved && F.read bv = before) "picker-motion-no-write";
  (* Toggle then review: still no write at 100x30. *)
  let toggled = key ~width_of ~dimensions:(100, 30) moved (`ASCII ' ') in
  require (b2_overlay_open toggled && F.read bv = before) "picker-toggle-no-write";
  let review = key ~width_of ~dimensions:(100, 30) toggled `Enter in
  require (b2_overlay_open review && F.read bv = before) "picker-review-no-write";
  (* j j k Up Down from cursor 0 over [wallet; bank; food; zero]: lands bank;
     Space deselects bank, so review lists wallet without bank. *)
  let rtext = b2_overlay_text ~width_of (100, 30) review in
  require (Base.String.is_substring rtext ~substring:"wallet" && not (Base.String.is_substring rtext ~substring:"bank"))
    "picker-review-lists-chosen";
  (* Review Esc/e retains chosen without writing; cancel from choose writes nothing. *)
  let back = key ~width_of ~dimensions:(100, 30) review `Escape in
  require (b2_overlay_open back && F.read bv = before) "picker-review-esc-retains-no-write";
  let back_e = key ~width_of ~dimensions:(100, 30) review (`ASCII 'e') in
  require (b2_overlay_open back_e && F.read bv = before) "picker-review-e-retains-no-write";
  let cancelled = key ~width_of ~dimensions:(100, 30) back (`ASCII 'q') in
  require (not (b2_overlay_open cancelled) && F.read bv = before) "picker-cancel-no-write";
  let cancelled_esc = key ~width_of ~dimensions:(100, 30) back `Escape in
  require (F.read bv = before) "picker-escape-no-write";
  ignore cancelled_esc;
  (* 80x24 normal review must remain usable: full open/toggle/review/save path. *)
  let o80 = key ~dimensions:(80, 24) ~width_of view (`ASCII 'c') in
  require (b2_overlay_open o80) "picker-80x24-opens";
  let r80 = key ~dimensions:(80, 24) ~width_of (key ~dimensions:(80, 24) ~width_of o80 (`ASCII ' ')) `Enter in
  require (b2_overlay_open r80 && F.read bv = before) "picker-80x24-review-no-write";
  let saved80 = key ~dimensions:(80, 24) ~width_of r80 `Enter in
  require (not (b2_overlay_open saved80)) "picker-80x24-save-closes";
  (* Space on cursor 0 deselects wallet: remaining jpy row is bank; eur row kept. *)
  let after80 = F.read bv in
  require (after80 = "bank\teur\nbank\tjpy\n") "picker-80x24-save-exact-bytes";
  let cold = fresh () in
  let painted = b2_screen ~width_of (120, 30) cold |> List.map snd |> String.concat "\n" in
  require (Base.String.is_substring painted ~substring:"bank"
    && not (Base.String.is_substring painted ~substring:"wallet"))
    "picker-cold-keeps-bank-only";
  require (Base.String.is_substring painted ~substring:"?") "picker-cold-unknown-stays-question";
  (* Historical previously-selected locus stays offered, never silently erased. *)
  replace bv "oldshop\tjpy\nbank\tjpy\n";
  let hist = key ~width_of (fresh ()) (`ASCII 'c') in
  require (b2_overlay_open hist && Base.String.is_substring (b2_overlay_text ~width_of (100, 30) hist) ~substring:"oldshop")
    "picker-historical-candidate-visible";
  require (F.read path = book_before) "picker-historical-no-book-write";
  (* Explicit empty clears this Measure, keeps others. Deselect both known
     candidates, then save via review at 100x30. *)
  replace bv "bank\tjpy\nwallet\tjpy\nbank\teur\n";
  let empty_open = key ~width_of (fresh ()) (`ASCII 'c') in
  let empty_open = key ~width_of ~dimensions:(100, 30) empty_open (`ASCII ' ') in
  let empty_open = key ~width_of ~dimensions:(100, 30) empty_open (`Arrow `Down) in
  let empty_open = key ~width_of ~dimensions:(100, 30) empty_open (`ASCII ' ') in
  let empty_review = key ~width_of ~dimensions:(100, 30) empty_open `Enter in
  require (F.read bv = "bank\tjpy\nwallet\tjpy\nbank\teur\n") "picker-review-empty-no-write";
  let empty_saved = key ~width_of ~dimensions:(100, 30) empty_review `Enter in
  let empty_bytes = F.read bv in
  require (Base.String.is_substring empty_bytes ~substring:"bank\teur\n") "picker-explicit-empty-keeps-other-measure";
  require (not (Base.String.is_substring empty_bytes ~substring:"\tjpy\n")) "picker-explicit-empty-clears-measure";
  ignore empty_saved;
  (* Malformed config never becomes empty selection: 'c' refuses without write. *)
  replace bv "malformed row\n";
  let malformed_bytes = F.read bv in
  let malformed = key ~width_of (fresh ()) (`ASCII 'c') in
  require (not (b2_overlay_open malformed) && F.read bv = malformed_bytes) "picker-malformed-refuses-no-write";
  (* Missing config opens (explicit create on save); unreadable path refuses. *)
  Unix.unlink bv;
  let missing = key ~width_of (fresh ()) (`ASCII 'c') in
  require (b2_overlay_open missing) "picker-missing-opens-for-explicit-create";
  let _ = key ~width_of ~dimensions:(100, 30) missing (`ASCII 'q') in
  Unix.mkdir bv 0o700;
  let unreadable = key ~width_of (fresh ()) (`ASCII 'c') in
  require (not (b2_overlay_open unreadable)) "picker-unreadable-refuses";
  Unix.rmdir bv;
  (* Stale concurrent change refuses; concurrent bytes preserved. *)
  replace bv "bank\tjpy\nwallet\tjpy\n";
  let stale_open = key ~width_of (fresh ()) (`ASCII 'c') in
  let stale_toggled = key ~width_of ~dimensions:(100, 30) stale_open (`ASCII ' ') in
  let stale_review = key ~width_of ~dimensions:(100, 30) stale_toggled `Enter in
  replace bv "bank\tjpy\nwallet\tjpy\nfood\tjpy\n";
  let concurrent = F.read bv in
  let stale_try = key ~width_of ~dimensions:(100, 30) stale_review `Enter in
  require (F.read bv = concurrent && b2_overlay_open stale_try)
    "picker-stale-preserves-concurrent";
  (* Small terminal refuses save without writing. *)
  replace bv "bank\tjpy\nwallet\tjpy\n";
  let small_base = F.read bv in
  let small_open = key ~dimensions:(48, 14) ~width_of (fresh ()) (`ASCII 'c') in
  let small_try =
    if b2_overlay_open small_open then
      let s1 = key ~dimensions:(48, 14) ~width_of small_open (`ASCII ' ') in
      let s2 = key ~dimensions:(48, 14) ~width_of s1 `Enter in
      key ~dimensions:(48, 14) ~width_of s2 `Enter
    else small_open in
  require (F.read bv = small_base) "picker-small-no-write";
  ignore small_try;
  require (F.read path = book_before) "picker-only-config-changes";
  print_endline "PASS: Balances picker order/toggle/review/cancel/save/cold, other-Measure/historical, empty/malformed/missing/stale/small (synthetic)."

let observe_multi_checks ~width_of ~directory () =
  let directory = directory ^ "/observe-multi" in
  Unix.mkdir directory 0o700;
  let path = directory ^ "/book.sexp" in
  F.write_new path b2_book_fixture;
  let fresh_home () = C.initial ~config_home:directory (F.load path) in
  let modal state =
    match visible_form state with Some f -> f | None -> raise (F.Refused "observe-open") in
  let notice state = Ui_form.notice (modal state) in
  let fill state locus measure amount =
    let form = modal state in
    let form = Ui_form.set_text form "locus" locus in
    let form = Ui_form.set_text form "measure" measure in
    let form = Ui_form.set_text form "amount" amount in
    with_visible_form state (Ui_form.set_focused form 2) in
  let press state =
    match H.handle ~width_of ~dimensions:(100, 30) state (`Key (`Enter, [])) with
    | Some s -> s | None -> raise (F.Refused "observe-exit") in
  let set_action state idx =
    let form = modal state in
    let form = Ui_form.update_field form "action" (function
      | Ui_form.Buttons b -> Ui_form.Buttons { b with selected = idx }
      | other -> other) in
    with_visible_form state (Ui_form.set_focused form (Ui_form.find_field_index form "action")) in
  let to_preview state = press (set_action state 1) in
  let publish state = press (set_action state 0) in
  let is_preview state =
    visible_form_id state = Some "observe_preview" in
  let is_editing state =
    visible_form_id state = Some "observe_quantity" in
  let home = fresh_home () in
  let book_before = F.read path in
  let opened = key ~width_of home (`ASCII 'o') in
  require (Ui_form.id (modal opened) = "observe_quantity"
    && Ui_form.get_button (modal opened) "action" = Some 0 && F.read path = book_before)
    "observe-open-add-default-no-write";
  (* Enter on amount Adds the row without writing; measure kept, locus cleared. *)
  let added = press (fill opened "wallet" "jpy" "1234") in
  require (is_editing added && F.read path = book_before) "observe-add-no-write";
  let kept = modal added in
  require (Ui_form.get_text kept "measure" = Some "jpy" && Ui_form.get_text kept "locus" = Some "")
    "observe-add-keeps-measure-clears-locus";
  require (Base.String.is_substring (b2_overlay_text ~width_of (100, 30) added) ~substring:"wallet")
    "observe-add-row-visible";
  (* Second row accumulates; Preview lists both, still no write. *)
  let added2 = press (fill added "bank" "JPY" "0") in
  require (is_editing added2 && F.read path = book_before) "observe-add2-no-write";
  let preview = to_preview added2 in
  require (is_preview preview && F.read path = book_before) "observe-preview-no-write";
  let pt = b2_overlay_text ~width_of (100, 30) preview in
  require (Base.String.is_substring pt ~substring:"wallet" && Base.String.is_substring pt ~substring:"bank"
    && Base.String.is_substring pt ~substring:"1234") "observe-preview-lists-rows";
  (* Edit retains rows and pending input. *)
  let edited = key ~width_of ~dimensions:(100, 30) preview (`ASCII 'e') in
  require (is_editing edited && F.read path = book_before) "observe-edit-no-write";
  require (Base.String.is_substring (b2_overlay_text ~width_of (100, 30) edited) ~substring:"wallet")
    "observe-edit-retains-rows";
  (* Publish once: wallet 1234, bank 0, unmentioned food 5500 preserved. *)
  let published = publish (to_preview edited) in
  require (no_modal published) "observe-publish-closes";
  let cold = (F.load path).book in
  require (b2_check_qty cold "wallet" "jpy" = "1234" && b2_check_qty cold "bank" "jpy" = "0"
    && b2_check_qty cold "food" "jpy" = "5500") "observe-publish-wallet-bank-preserves-food";
  (* Exact signed via UI Add→Preview→Publish→cold. *)
  let s0 = fill (key ~width_of published (`ASCII 'o')) "wallet" "jpy" "-123" in
  let spub = publish (to_preview (press s0)) in
  require (b2_check_qty (F.load path).book "wallet" "jpy" = "-123") "observe-signed-ui-cold";
  ignore spub;
  (* Multi-Measure via UI: eur scale 2, "12.34" is exactly 1234 quanta. *)
  let m0 = fill (key ~width_of (fresh_home ()) (`ASCII 'o')) "wallet" "eur" "12.34" in
  let mpub = publish (to_preview (press m0)) in
  require (b2_check_qty (F.load path).book "wallet" "eur" = "1234") "observe-multi-measure-ui-cold";
  ignore mpub;
  (* Refusals retain Preview + notice with identical bytes. *)
  let bytes_before = F.read path in
  let refuse locus measure amount label =
    let st = press (fill (key ~width_of (fresh_home ()) (`ASCII 'o')) locus measure amount) in
    let st = if is_preview st then st else to_preview st in
    let st = publish st in
    require (is_preview st && notice st <> "" && F.read path = bytes_before)
      ("observe-" ^ label ^ "-retains-preview-refusal") in
  refuse "nope" "jpy" "5" "unapproved";
  refuse "zero" "jpy" "5" "zero-origin";
  List.iter (fun (measure, amount) ->
      let st = press (fill (key ~width_of (fresh_home ()) (`ASCII 'o')) "wallet" measure amount) in
      require (is_editing st && notice st <> "" && F.read path = bytes_before)
        "observe-invalid-amount-or-measure-refuses-add")
    ["xxm", "5"; "jpy", "abc"];
  (* Duplicate coordinate in one group is refused atomically at publish. *)
  (let st = key ~width_of (fresh_home ()) (`ASCII 'o') in
   let st = press (fill st "bank" "jpy" "1") in
   let st = press (fill st "bank" "jpy" "2") in
   let st = publish (to_preview st) in
   require (is_preview st && notice st <> "" && F.read path = bytes_before)
     "observe-duplicate-retains-preview-refusal";
   let closed = key ~width_of ~dimensions:(100, 30) st `Escape in
   require (no_modal closed && F.read path = bytes_before) "observe-duplicate-cancel-no-write");
  (* Blocked publish retains Preview; small terminal refuses publish; both no-write. *)
  (let st = key ~width_of (fresh_home ()) (`ASCII 'o') in
   let st = press (fill st "wallet" "jpy" "7") in
   let st = to_preview st in
   require (is_preview st) "observe-preview-ready";
   let blocked = publish { st with C.blocked = true } in
   require (is_preview blocked && F.read path = bytes_before) "observe-blocked-retains-preview";
   let small = key ~dimensions:(48, 14) ~width_of st `Enter in
   require (F.read path = bytes_before) "observe-small-no-write";
   ignore small);
  (* Save conflict: concurrent writer wins, draft retained with refusal. *)
  (let st = key ~width_of (fresh_home ()) (`ASCII 'o') in
   let st = press (fill st "wallet" "jpy" "11") in
   let st = to_preview st in
   (match F.append (fresh_home ()).session [ L.Observe [ ("bank", "jpy", Z.of_int 3) ] ] with
    | F.Written _ -> () | _ -> raise (F.Refused "observe-conflict-setup"));
   let concurrent = F.read path in
   let conflict = publish st in
   require (is_preview conflict && notice conflict <> "" && F.read path = concurrent)
     "observe-conflict-preserves-concurrent-retains-preview";
   let reloaded =
     match H.handle ~width_of conflict (`Key (`ASCII 'r', [ `Ctrl ])) with
     | Some s -> s | None -> raise (F.Refused "observe-reload-exited") in
   require (F.read path = concurrent) "observe-reload-writes-nothing";
   let retried = publish reloaded in
   require (retried.C.blocked && is_preview retried && F.read path = concurrent)
     "observe-reload-cannot-bless-old-image");
  (let st = press (fill (key ~width_of (fresh_home ()) (`ASCII 'o')) "wallet" "jpy" "13")
       |> to_preview in
   Unix.rename path (path ^ ".held");
   let failed = publish st in
   require (is_preview failed && notice failed <> "" && not (Sys.file_exists path))
     "observe-save-failure-retains-preview";
   Unix.rename (path ^ ".held") path);
  print_endline "PASS: Observe Add/Preview/Publish/Edit, exact zero/signed/multi-Measure UI cold reads, atomic refusals, blocked/small/conflict/reload (synthetic)."

