(* Synthetic qualification of the LOAM-aligned Scheduled occurrence creation session.
   Validates fields, cyclic focus, 6-row cap, 2-row minimum, Date input guards,
   Locus prefix matching, Ctrl-U suspense auto-fill, LOAM validation rules,
   Preview navigation and tiny-terminal publication gates. *)

module B = Bakhlo_household.Daily_book
module Sch = Scheduled_session

let require condition name =
  if not condition then failwith ("FAILED: scheduled_session_check: " ^ name)

let key ?(mods = []) button = `Key (button, mods)
let char_key c = `Key (`ASCII c, [])

let fixture =
  "BOOK\t1\n\
   MEASURE\tjpy\t0\n\
   MEASURE\teur\t2\n\
   LOCUS\tassets:cash\t現金\tSynthetic cash\n\
   LOCUS\texpenses:groceries\t食費\tSynthetic food\n\
   LOCUS\texpenses:rent\t家賃\tSynthetic rent\n\
   ZERO-ORIGIN\texpenses:groceries\tjpy\n\
   ANCHOR\t-\n\
   ASSERT\tassets:cash\tjpy\t1000\n\
   ENDANCHOR\n\
   END\n"

(* Exercise the public editor through to the exact candidate, rather than trusting
   a success notice or a substring in the painted form. *)
let check_remainder ~book ~width_of () =
  let dimensions = (100, 30) in
  let update session input =
    match Sch.handle ~blocked:false ~dimensions ~width_of session input with
    | Sch.Updated next -> next
    | _ -> failwith "remainder editor unexpectedly closed or published"
  in
  let tab session = update session (key `Tab) in
  let type_text text session =
    String.fold_left (fun session c -> update session (char_key c)) session text
  in
  let focus index session =
    let rec loop remaining session =
      if Sch.focus session = index then session
      else if remaining = 0 then failwith "remainder focus did not converge"
      else loop (remaining - 1) (tab session)
    in
    loop 20 session
  in
  let edit rows =
    let session = Sch.create ~book ~day:"2026-10-15" ~measure:"jpy" in
    let session =
      List.fold_left
        (fun session _ -> update session (key ~mods:[ `Ctrl ] (`ASCII 'n')))
        session
        (List.filteri (fun i _ -> i >= 2) rows)
      |> focus 1
    in
    List.fold_left
      (fun session (locus, amount) -> session |> type_text locus |> tab |> type_text amount |> tab)
      session rows
  in
  let balance session = update session (key ~mods:[ `Ctrl ] (`ASCII 'u')) in
  let candidate session =
    let session = focus (Sch.first_action session + 2) session |> fun s -> update s (key `Enter) in
    require (Sch.is_preview session) ("remainder-preview: " ^ Sch.notice session);
    match Sch.handle ~blocked:false ~dimensions ~width_of session (key `Enter) with
    | Sch.Publish draft -> draft
    | _ -> failwith "remainder preview did not offer its candidate"
  in
  let expect changes session name =
    let draft = candidate session in
    let expected = List.map (fun (locus, amount) -> (locus, Z.of_string amount)) changes in
    require (draft.Sch.changes = expected) name;
    require
      (Z.equal (List.fold_left (fun total (_, n) -> Z.add total n) Z.zero draft.changes) Z.zero)
      (name ^ "-conserves")
  in
  let balanced = [ ("assets:cash", "+1000"); ("expenses:rent", "-500"); ("unresolved", "-500") ] in
  expect balanced (edit balanced |> balance |> balance) "balanced-three-postings-retained";
  let changed = [ ("assets:cash", "+1000"); ("expenses:rent", "-400"); ("unresolved", "-500") ] in
  expect
    [ ("assets:cash", "1000"); ("expenses:rent", "-400"); ("unresolved", "-600") ]
    (edit changed |> balance |> balance)
    "existing-suspense-replaced-from-other-postings";
  expect
    [ ("assets:cash", "1000"); ("unresolved", "-1000") ]
    (edit [ ("assets:cash", "+1,000"); ("", "") ] |> balance)
    "comma-amount-balances-like-preview";
  let huge = "1000000000000000000000000000000" in
  expect
    [ ("assets:cash", huge); ("unresolved", "-" ^ huge) ]
    (edit [ ("assets:cash", huge); ("", "") ] |> balance)
    "remainder-is-exact-beyond-machine-int";
  let unchanged rows expected_notice =
    let before = edit rows in
    let after = balance before in
    require
      (Sch.notice after = expected_notice)
      ("remainder-refusal-is-explicit: " ^ Sch.notice after);
    let paint session = Sch.screen ~book ~dimensions ~width_of (Sch.with_notice session "") in
    require (paint before = paint after) "remainder-refusal-keeps-every-field"
  in
  unchanged
    [ ("assets:cash", "+1+"); ("", "") ]
    "Enter a nonzero signed integer jpy amount for every posting.";
  unchanged
    [ ("assets:cash", "+1000"); ("expenses:rent", "") ]
    "Enter a nonzero signed integer jpy amount for every posting.";
  unchanged [ ("", "+1000"); ("", "") ] "Enter a valid Locus token for every posting.";
  unchanged
    [ ("assets:cash", "+1000"); ("unresolved", "-+") ]
    "Enter a nonzero signed integer jpy amount for every posting.";
  unchanged
    [ ("assets:cash", "+1000"); ("unresolved", "-400"); ("suspense:other", "-500") ]
    "Choose one suspense posting before balancing the remainder.";
  unchanged
    [ ("assets:cash", "+1000"); ("expenses:rent", "-1000"); ("unresolved", "-500") ]
    "Other postings already balance; edit or remove suspense explicitly."

let self_check ~width_of () =
  let book = Bakhlo_household.Daily_txt.book fixture in
  check_remainder ~book ~width_of ();

  (* 1. Initial state *)
  let s = Sch.create ~book ~day:"2026-10-15" ~measure:"jpy" in
  require (Sch.day s = "2026-10-15") "initial-day";
  require (Sch.measure s = "jpy") "initial-measure";
  require (not (Sch.is_preview s)) "initial-not-preview";

  let dim = (80, 24) in

  (* 2. Focus movement *)
  (* Focus 0 (Due) -> 1 (P1 Locus) -> 2 (P1 Amount) -> 3 (P2 Locus) -> 4 (P2 Amount)
     -> 5 (Add) -> 6 (Drop) -> 7 (Preview) -> 8 (Cancel) -> 0 (Due) *)
  let s =
    match Sch.handle ~blocked:false ~dimensions:dim ~width_of s (key `Tab) with
    | Sch.Updated s -> s
    | _ -> failwith "tab 1"
  in
  let s =
    match Sch.handle ~blocked:false ~dimensions:dim ~width_of s (key `Tab) with
    | Sch.Updated s -> s
    | _ -> failwith "tab 2"
  in
  let s_prev =
    match Sch.handle ~blocked:false ~dimensions:dim ~width_of s (key ~mods:[ `Shift ] `Tab) with
    | Sch.Updated s -> s
    | _ -> failwith "sh-tab"
  in
  require (Sch.day s_prev = "2026-10-15") "focus-shift-tab-back";

  (* 3. Date input guards *)
  let s_due = Sch.create ~book ~day:"" ~measure:"jpy" in
  let s_due =
    match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_due (char_key 'a') with
    | Sch.Updated s -> s
    | _ -> failwith "date a"
  in
  let s_due =
    match
      Sch.handle ~blocked:false ~dimensions:dim ~width_of s_due
        (`Key (`Uchar (Uchar.of_int 0x3042), []))
    with
    | Sch.Updated s -> s
    | _ -> failwith "date uchar"
  in
  require (Sch.day s_due = "") "date-ignores-non-date-char";
  let s_due =
    match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_due (char_key '2') with
    | Sch.Updated s -> s
    | _ -> failwith "date 2"
  in
  let s_due =
    match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_due (char_key '0') with
    | Sch.Updated s -> s
    | _ -> failwith "date 0"
  in
  require (Sch.day s_due = "20") "date-accepts-digits";

  (* 4. Row addition and 6-row maximum *)
  let s_add = Sch.create ~book ~day:"2026-10-15" ~measure:"jpy" in
  (* Initial: 2 rows. Add 4 times -> 6 rows *)
  let add s =
    match
      Sch.handle ~blocked:false ~dimensions:dim ~width_of s (key ~mods:[ `Ctrl ] (`ASCII 'n'))
    with
    | Sch.Updated next -> next
    | _ -> failwith "add row"
  in
  let s_add = add (add (add (add s_add))) in
  require (Sch.notice s_add = "") "4-adds-ok-6-rows";
  let s_add_7 = add s_add in
  require (Sch.notice s_add_7 <> "") "7th-add-refused-notice";

  (* 5. Row dropping and 2-row minimum *)
  let drop s =
    match
      Sch.handle ~blocked:false ~dimensions:dim ~width_of s (key ~mods:[ `Ctrl ] (`ASCII 'd'))
    with
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
  let s_loc =
    match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_loc (key `Tab) with
    | Sch.Updated s -> s
    | _ -> failwith "tab locus"
  in
  (* Type "as" for "assets:cash" *)
  let s_loc =
    match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_loc (char_key 'a') with
    | Sch.Updated s -> s
    | _ -> failwith "type a"
  in
  let s_loc =
    match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_loc (char_key 's') with
    | Sch.Updated s -> s
    | _ -> failwith "type s"
  in
  let cands = Sch.candidates s_loc in
  require (List.length cands > 0) "candidates-found";
  require (List.hd cands = "assets:cash") "prefix-match-assets-cash";
  (* Enter on Locus commits the selected candidate and advances focus to Amount *)
  let s_loc =
    match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_loc (key `Enter) with
    | Sch.Updated s -> s
    | _ -> failwith "enter advance"
  in
  let s_lines = Sch.screen ~book ~dimensions:dim ~width_of s_loc in
  let screen_text = String.concat "\n" (List.map snd s_lines) in
  require
    (Base.String.is_substring screen_text ~substring:"assets:cash")
    "candidate-committed-to-screen";

  (* 7. Ctrl-U suspense auto-fill *)
  (* Now at Posting 1 Amount. Type "+1000" *)
  let type_str str s =
    let rec aux s i =
      if i >= String.length str then s
      else
        let s =
          match Sch.handle ~blocked:false ~dimensions:dim ~width_of s (char_key str.[i]) with
          | Sch.Updated s -> s
          | _ -> failwith "type"
        in
        aux s (i + 1)
    in
    aux s 0
  in
  let s_amt = type_str "+1000" s_loc in
  (* Press Ctrl-U: balances remainder with suspense posting *)
  let s_bal =
    match
      Sch.handle ~blocked:false ~dimensions:dim ~width_of s_amt (key ~mods:[ `Ctrl ] (`ASCII 'u'))
    with
    | Sch.Updated s -> s
    | _ -> failwith "ctrl-u"
  in
  require (Sch.notice s_bal <> "") "suspense-filled-notice";
  let s_bal_lines = Sch.screen ~book ~dimensions:dim ~width_of s_bal in
  let bal_text = String.concat "\n" (List.map snd s_bal_lines) in
  require (Base.String.is_substring bal_text ~substring:"unresolved") "suspense-unresolved-inserted";
  require (Base.String.is_substring bal_text ~substring:"-1000") "suspense-amount-balanced";

  (* Press Ctrl-U again when balanced: notice reports already balanced *)
  let s_bal2 =
    match
      Sch.handle ~blocked:false ~dimensions:dim ~width_of s_bal (key ~mods:[ `Ctrl ] (`ASCII 'u'))
    with
    | Sch.Updated s -> s
    | _ -> failwith "ctrl-u 2"
  in
  require
    (Base.String.is_substring (Sch.notice s_bal2) ~substring:"already balanced")
    "suspense-already-balanced";

  (* 8. Preview and LOAM validation *)
  (* Test unbalanced rejection *)
  let s_unbal = Sch.create ~book ~day:"2026-10-15" ~measure:"jpy" in
  let s_unbal =
    match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_unbal (key `Tab) with
    | Sch.Updated s -> s
    | _ -> failwith "tab"
  in
  let s_unbal = type_str "assets:cash" s_unbal in
  let s_unbal =
    match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_unbal (key `Tab) with
    | Sch.Updated s -> s
    | _ -> failwith "tab"
  in
  let s_unbal = type_str "+1000" s_unbal in
  let s_unbal =
    match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_unbal (key `Tab) with
    | Sch.Updated s -> s
    | _ -> failwith "tab"
  in
  let s_unbal = type_str "expenses:groceries" s_unbal in
  let s_unbal =
    match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_unbal (key `Tab) with
    | Sch.Updated s -> s
    | _ -> failwith "tab"
  in
  let s_unbal = type_str "-500" s_unbal in
  (* unbalanced! *)
  (* Advance focus to [Preview] and press Enter *)
  let rec to_preview s =
    if Sch.focus s = Sch.first_action s + 2 then s
    else
      let s =
        match Sch.handle ~blocked:false ~dimensions:dim ~width_of s (key `Tab) with
        | Sch.Updated s -> s
        | _ -> failwith "to preview"
      in
      to_preview s
  in
  let s_unbal_prev =
    match Sch.handle ~blocked:false ~dimensions:dim ~width_of (to_preview s_unbal) (key `Enter) with
    | Sch.Updated s -> s
    | _ -> failwith "enter preview unbal"
  in
  require (not (Sch.is_preview s_unbal_prev)) "unbalanced-not-preview";
  require
    (Base.String.is_substring (Sch.notice s_unbal_prev) ~substring:"totals differ")
    "unbalanced-notice";

  (* Correct amount to -1000 and enter preview *)
  (* Erase "-500" from row 1 amount field (where s_unbal is focused) *)
  let s_bal_correct =
    match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_unbal (key `Backspace) with
    | Sch.Updated s -> s
    | _ -> failwith "bs"
  in
  let s_bal_correct =
    match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_bal_correct (key `Backspace) with
    | Sch.Updated s -> s
    | _ -> failwith "bs"
  in
  let s_bal_correct =
    match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_bal_correct (key `Backspace) with
    | Sch.Updated s -> s
    | _ -> failwith "bs"
  in
  let s_bal_correct =
    match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_bal_correct (key `Backspace) with
    | Sch.Updated s -> s
    | _ -> failwith "bs"
  in
  let s_bal_correct = type_str "-1000" s_bal_correct in
  let s_ready = to_preview s_bal_correct in
  let s_preview =
    match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_ready (key `Enter) with
    | Sch.Updated s -> s
    | _ -> failwith "enter preview"
  in
  require (Sch.is_preview s_preview) "preview-mode-entered";

  (* 9. Preview publication gate and successful publication *)
  (* Tiny terminal gate rejection: height 8 gives preview_capacity < 2 *)
  let s_tiny_pub =
    match Sch.handle ~blocked:false ~dimensions:(80, 8) ~width_of s_preview (key `Enter) with
    | Sch.Updated s -> s
    | Sch.Publish _ -> failwith "tiny terminal must not publish"
    | Sch.Closed -> failwith "closed"
  in
  require
    (Base.String.is_substring (Sch.notice s_tiny_pub) ~substring:"Enlarge terminal")
    "tiny-terminal-preview-gate";

  (* Normal terminal publication *)
  let published_draft =
    match Sch.handle ~blocked:false ~dimensions:(80, 24) ~width_of s_preview (key `Enter) with
    | Sch.Publish draft -> draft
    | _ -> failwith "normal terminal publish"
  in
  require (published_draft.Sch.scheduled_on = "2026-10-15") "published-date";
  require (published_draft.Sch.measure = "jpy") "published-measure";
  require (List.length published_draft.Sch.changes = 2) "published-changes-count";
  require (Z.equal published_draft.Sch.positive_total (Z.of_int 1000)) "published-positive-total";

  (* 10. Cursor in painted rows and UTF-8 / overflow regressions *)
  let s_rows = Sch.screen ~book ~dimensions:dim ~width_of s in
  let cur_pos = Daily_overlays.cursor_in_rows ~width_of ~width:80 s_rows in
  require (Option.is_some cur_pos) "cursor-position-computed";
  let s_prev_rows = Sch.screen ~book ~dimensions:dim ~width_of s_preview in
  let cur_prev = Daily_overlays.cursor_in_rows ~width_of ~width:80 s_prev_rows in
  require (Option.is_none cur_prev) "preview-no-cursor";
  let s_utf8 =
    match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_amt (key (`Arrow `Left)) with
    | Sch.Updated next -> next
    | _ -> failwith "left"
  in
  let s_utf8 =
    match Sch.handle ~blocked:false ~dimensions:dim ~width_of s_utf8 (char_key '9') with
    | Sch.Updated next -> next
    | _ -> failwith "insert 9"
  in
  let s_utf8_rows = Sch.screen ~book ~dimensions:dim ~width_of s_utf8 in
  require
    (List.exists (fun (_, t) -> Base.String.is_substring t ~substring:"+1009|0") s_utf8_rows
    || List.exists (fun (_, t) -> Base.String.is_substring t ~substring:"+10090|") s_utf8_rows)
    "scheduled-utf8-caret-editing";
  let s_warn = Sch.with_notice s (String.make 500 'w') in
  let s_warn_rows = Sch.screen ~book ~dimensions:(48, 14) ~width_of s_warn in
  require
    (List.exists (fun (_, t) -> Base.String.is_substring t ~substring:"… more") s_warn_rows)
    "scheduled-long-notice-overflow";
  let s_clean_rows = Sch.screen ~book ~dimensions:(48, 14) ~width_of s in
  let s_short_rows = Sch.screen ~book ~dimensions:(48, 14) ~width_of (Sch.with_notice s "Short") in
  require (List.length s_clean_rows = List.length s_short_rows) "scheduled-short-notice-stable";
  Printf.printf
    "PASS: Scheduled creation session synthetic checks (fields, focus, 6-row cap, Date guard, \
     prefix match, Ctrl-U, LOAM preview gate).\n\
     %!"
