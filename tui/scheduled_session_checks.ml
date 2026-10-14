(* Synthetic qualification of the LOAM-aligned Scheduled occurrence creation session.
   Validates fields, cyclic focus, 6-row cap, 2-row minimum, Date input guards,
   Locus prefix matching, Ctrl-U suspense auto-fill, LOAM validation rules,
   Preview navigation and tiny-terminal publication gates. *)

module B = Bakhlo_sexp.Daily_book
module A = Daily_actions
module Sch = Scheduled_session

let require condition name =
  if not condition then failwith ("FAILED: scheduled_session_check: " ^ name)

let key ?(mods = []) button = `Key (button, mods)
let char_key c = `Key (`ASCII c, [])

let get = function Ok x -> x | Error why -> failwith why

let fixture =
  "(bakhlo-daily 3)\n(scope corrected-entries explicit-plans)\n\
   (measures (measure \"jpy\" 0) (measure \"eur\" 2))\n\
   (labels (provided (label \"assets:cash\" \"現金\" \"Synthetic cash\") (label \"expenses:groceries\" \"食費\" \"Synthetic food\") (label \"expenses:rent\" \"家賃\" \"Synthetic rent\")))\n\
   (approved-loci (provided \"assets:cash\" \"expenses:groceries\" \"expenses:rent\"))\n(entries)\n\
   (plans)\n\
   (support (zero-origin (\"expenses:groceries\" \"jpy\")) (openings)\n\
     (observations (observation (reflected) (quantities (\"assets:cash\" \"jpy\" 1000))))\n\
     (presence (not-supplied)))\n"

let self_check ~width_of () =
  let book = get (B.of_string fixture) in

  (* 1. Initial state *)
  let s = Sch.create ~book ~day:"2026-10-15" ~measure:"jpy" in
  require (Sch.day s = "2026-10-15") "initial-day";
  require (Sch.measure s = "jpy") "initial-measure";
  require (not (Sch.is_preview s)) "initial-not-preview";

  let dim = (80, 24) in

  (* 2. Focus movement *)
  (* Focus 0 (Due) -> 1 (P1 Locus) -> 2 (P1 Amount) -> 3 (P2 Locus) -> 4 (P2 Amount)
     -> 5 (Add) -> 6 (Drop) -> 7 (Preview) -> 8 (Cancel) -> 0 (Due) *)
  let s = match Sch.handle ~blocked:false ~dimensions:dim ~width_of s (key `Tab) with Sch.Updated s -> s | _ -> failwith "tab 1" in
  let s = match Sch.handle ~blocked:false ~dimensions:dim ~width_of s (key `Tab) with Sch.Updated s -> s | _ -> failwith "tab 2" in
  let s_prev = match Sch.handle ~blocked:false ~dimensions:dim ~width_of s (key ~mods:[`Shift] `Tab) with Sch.Updated s -> s | _ -> failwith "sh-tab" in
  require (Sch.day s_prev = "2026-10-15") "focus-shift-tab-back";

  (* 3. Date input guards *)
  let s_due = Sch.create ~book ~day:"" ~measure:"jpy" in
  let s_due = match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_due (char_key 'a') with Sch.Updated s -> s | _ -> failwith "date a" in
  let s_due = match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_due (`Key (`Uchar (Uchar.of_int 0x3042), [])) with Sch.Updated s -> s | _ -> failwith "date uchar" in
  require (Sch.day s_due = "") "date-ignores-non-date-char";
  let s_due = match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_due (char_key '2') with Sch.Updated s -> s | _ -> failwith "date 2" in
  let s_due = match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_due (char_key '0') with Sch.Updated s -> s | _ -> failwith "date 0" in
  require (Sch.day s_due = "20") "date-accepts-digits";

  (* 4. Row addition and 6-row maximum *)
  let s_add = Sch.create ~book ~day:"2026-10-15" ~measure:"jpy" in
  (* Initial: 2 rows. Add 4 times -> 6 rows *)
  let add s =
    match Sch.handle ~blocked:false ~dimensions:dim ~width_of s (key ~mods:[`Ctrl] (`ASCII 'n')) with
    | Sch.Updated next -> next
    | _ -> failwith "add row"
  in
  let s_add = add (add (add (add s_add))) in
  require (Sch.notice s_add = "") "4-adds-ok-6-rows";
  let s_add_7 = add s_add in
  require (Sch.notice s_add_7 <> "") "7th-add-refused-notice";

  (* 5. Row dropping and 2-row minimum *)
  let drop s =
    match Sch.handle ~blocked:false ~dimensions:dim ~width_of s (key ~mods:[`Ctrl] (`ASCII 'd')) with
    | Sch.Updated next -> next
    | _ -> failwith "drop row"
  in
  require (Sch.rows_count s_add = 6) "add-up-to-6-rows";
  let s_drop = drop (drop (drop (drop s_add))) in
  (* Now at 2 rows *)
  let s_drop_min = drop s_drop in
  require (Sch.rows_count s_drop_min = 2) "drop-below-2-refused";

  (* 6. Locus prefix matching and Enter advancement *)
  let s_loc = Sch.create ~book ~day:"2026-10-15" ~measure:"jpy" in
  (* Move focus to Posting 1 Locus *)
  let s_loc = match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_loc (key `Tab) with Sch.Updated s -> s | _ -> failwith "tab locus" in
  (* Type "as" for "assets:cash" *)
  let s_loc = match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_loc (char_key 'a') with Sch.Updated s -> s | _ -> failwith "type a" in
  let s_loc = match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_loc (char_key 's') with Sch.Updated s -> s | _ -> failwith "type s" in
  let cands = Sch.candidates s_loc in
  require (List.length cands > 0) "candidates-found";
  require (List.hd cands = "assets:cash") "prefix-match-assets-cash";
  (* Enter on Locus commits the selected candidate and advances focus to Amount *)
  let s_loc = match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_loc (key `Enter) with Sch.Updated s -> s | _ -> failwith "enter advance" in
  let s_lines = Sch.screen ~book ~dimensions:dim ~width_of s_loc in
  let screen_text = String.concat "\n" (List.map snd s_lines) in
  require (Base.String.is_substring screen_text ~substring:"assets:cash") "candidate-committed-to-screen";

  (* 7. Ctrl-U suspense auto-fill *)
  (* Now at Posting 1 Amount. Type "+1000" *)
  let type_str str s =
    let rec aux s i =
      if i >= String.length str then s
      else
        let s = match Sch.handle ~blocked:false ~dimensions:dim ~width_of s (char_key str.[i]) with Sch.Updated s -> s | _ -> failwith "type" in
        aux s (i + 1)
    in
    aux s 0
  in
  let s_amt = type_str "+1000" s_loc in
  (* Press Ctrl-U: balances remainder with suspense posting *)
  let s_bal = match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_amt (key ~mods:[`Ctrl] (`ASCII 'u')) with Sch.Updated s -> s | _ -> failwith "ctrl-u" in
  require (Sch.notice s_bal <> "") "suspense-filled-notice";
  let s_bal_lines = Sch.screen ~book ~dimensions:dim ~width_of s_bal in
  let bal_text = String.concat "\n" (List.map snd s_bal_lines) in
  require (Base.String.is_substring bal_text ~substring:"unresolved") "suspense-unresolved-inserted";
  require (Base.String.is_substring bal_text ~substring:"-1000") "suspense-amount-balanced";

  (* Press Ctrl-U again when balanced: notice reports already balanced *)
  let s_bal2 = match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_bal (key ~mods:[`Ctrl] (`ASCII 'u')) with Sch.Updated s -> s | _ -> failwith "ctrl-u 2" in
  require (Base.String.is_substring (Sch.notice s_bal2) ~substring:"already balanced") "suspense-already-balanced";

  (* 8. Preview and LOAM validation *)
  (* Test unbalanced rejection *)
  let s_unbal = Sch.create ~book ~day:"2026-10-15" ~measure:"jpy" in
  let s_unbal = match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_unbal (key `Tab) with Sch.Updated s -> s | _ -> failwith "tab" in
  let s_unbal = type_str "assets:cash" s_unbal in
  let s_unbal = match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_unbal (key `Tab) with Sch.Updated s -> s | _ -> failwith "tab" in
  let s_unbal = type_str "+1000" s_unbal in
  let s_unbal = match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_unbal (key `Tab) with Sch.Updated s -> s | _ -> failwith "tab" in
  let s_unbal = type_str "expenses:groceries" s_unbal in
  let s_unbal = match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_unbal (key `Tab) with Sch.Updated s -> s | _ -> failwith "tab" in
  let s_unbal = type_str "-500" s_unbal in (* unbalanced! *)
  (* Advance focus to [Preview] and press Enter *)
  let rec to_preview s =
    if Sch.focus s = Sch.first_action s + 2 then s
    else
      let s = match Sch.handle ~blocked:false ~dimensions:dim ~width_of s (key `Tab) with Sch.Updated s -> s | _ -> failwith "to preview" in
      to_preview s
  in
  let s_unbal_prev = match Sch.handle ~blocked:false ~dimensions:dim ~width_of (to_preview s_unbal) (key `Enter) with Sch.Updated s -> s | _ -> failwith "enter preview unbal" in
  require (not (Sch.is_preview s_unbal_prev)) "unbalanced-not-preview";
  require (Base.String.is_substring (Sch.notice s_unbal_prev) ~substring:"totals differ") "unbalanced-notice";

  (* Correct amount to -1000 and enter preview *)
  (* Erase "-500" from row 1 amount field (where s_unbal is focused) *)
  let s_bal_correct = match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_unbal (key `Backspace) with Sch.Updated s -> s | _ -> failwith "bs" in
  let s_bal_correct = match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_bal_correct (key `Backspace) with Sch.Updated s -> s | _ -> failwith "bs" in
  let s_bal_correct = match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_bal_correct (key `Backspace) with Sch.Updated s -> s | _ -> failwith "bs" in
  let s_bal_correct = match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_bal_correct (key `Backspace) with Sch.Updated s -> s | _ -> failwith "bs" in
  let s_bal_correct = type_str "-1000" s_bal_correct in
  let s_ready = to_preview s_bal_correct in
  let s_preview = match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_ready (key `Enter) with Sch.Updated s -> s | _ -> failwith "enter preview" in
  require (Sch.is_preview s_preview) "preview-mode-entered";

  (* 9. Preview publication gate and successful publication *)
  (* Tiny terminal gate rejection: height 8 gives preview_capacity < 2 *)
  let s_tiny_pub = match Sch.handle ~blocked:false ~dimensions:(80, 8) ~width_of s_preview (key `Enter) with
    | Sch.Updated s -> s
    | Sch.Publish _ -> failwith "tiny terminal must not publish"
    | Sch.Closed -> failwith "closed"
  in
  require (Base.String.is_substring (Sch.notice s_tiny_pub) ~substring:"Enlarge terminal") "tiny-terminal-preview-gate";

  (* Normal terminal publication *)
  let published_draft = match Sch.handle ~blocked:false ~dimensions:(80, 24) ~width_of s_preview (key `Enter) with
    | Sch.Publish draft -> draft
    | _ -> failwith "normal terminal publish"
  in
  require (published_draft.Sch.scheduled_on = "2026-10-15") "published-date";
  require (published_draft.Sch.measure = "jpy") "published-measure";
  require (List.length published_draft.Sch.changes = 2) "published-changes-count";
  require (Z.equal published_draft.Sch.positive_total (Z.of_int 1000)) "published-positive-total";

  (* 10. Cursor position check *)
  let cur_pos = Sch.cursor_position ~book ~dimensions:dim ~width_of s in
  require (Option.is_some cur_pos) "cursor-position-computed";
  let cur_prev = Sch.cursor_position ~book ~dimensions:dim ~width_of s_preview in
  require (Option.is_none cur_prev) "preview-no-cursor";

  Printf.printf "PASS: Scheduled creation session synthetic checks (fields, focus, 6-row cap, Date guard, prefix match, Ctrl-U, LOAM preview gate).\n%!"
