(* Scheduled plans and their payment, as language-neutral answers.

   Each sample in test/scheduled is a book before, the changes the Shell would
   publish, and the answer: the exact book.txt after, or the reason the whole
   change list is refused. A [.pace] file adds today's spending guide over the
   result. The files, not this runner, are the specification a rewrite must
   pass (test/scheduled/README.md); this runner only proves Bakhlo agrees.

   The change and pace files reuse book.txt's TX and PLAN blocks, so a reader of
   one already reads the other. *)
module B = Bakhlo_household.Book

let dir = "scheduled"
let read name = In_channel.with_open_bin (Filename.concat dir name) In_channel.input_all
let exists name = Sys.file_exists (Filename.concat dir name)
let lines text = List.filter (fun l -> l <> "") (String.split_on_char '\n' text)
let fields = String.split_on_char '\t'

exception Bad_sample of string

let bad why = raise (Bad_sample why)
let amount s = try Z.of_string s with Invalid_argument _ -> bad ("amount " ^ s)
let option = function "-" -> None | s -> Some s
let mode = function "NEW" -> false | "REPLACE" -> true | other -> bad ("mode " ^ other)

(* 1. A TX block, as book.txt writes it. Memos with escapes stay out of these
   samples; the conformance fixtures already pin escaping. *)
let entry_block = function
  | header :: rest ->
      let id, day, memo =
        match fields header with
        | [ "TX"; id; day ] -> (id, day, None)
        | [ "TX"; id; day; "DESC"; memo ] when not (String.contains memo '\\') ->
            (id, day, Some memo)
        | _ -> bad ("TX line " ^ header)
      in
      let rec body (e : B.entry) = function
        | "ENDTX" :: rest -> ({ e with effects = List.rev e.effects }, rest)
        | line :: rest ->
            let e =
              match fields line with
              | [ "EFFECT"; locus; measure; q ] ->
                  {
                    e with
                    effects = { locus; measure; amount = amount q; key = None } :: e.effects;
                  }
              | [ "EFFECT"; locus; measure; q; key ] ->
                  {
                    e with
                    effects = { locus; measure; amount = amount q; key = Some key } :: e.effects;
                  }
              | [ "REVERSAL-OF"; id ] -> { e with reversal_of = Some id }
              | [ "ORIGINAL"; measure; q ] -> { e with original_amount = Some (measure, amount q) }
              | [ "MERCHANT"; party ] -> { e with merchant = Some (B.Merchant party) }
              | [ "NONMERCHANT" ] -> { e with merchant = Some B.Nonmerchant }
              | _ -> bad ("TX body " ^ line)
            in
            body e rest
        | [] -> bad "TX without ENDTX"
      in
      body
        {
          id;
          day;
          memo;
          effects = [];
          reversal_of = None;
          exchange = None;
          original_amount = None;
          merchant = None;
        }
        rest
  | [] -> bad "missing TX block"

(* 2. A PLAN block. An ending is accepted here so a sample can show that a plan
   is never put already paid or cancelled. *)
let plan_block = function
  | header :: rest ->
      let id, day, measure =
        match fields header with
        | [ "PLAN"; id; day; measure ] -> (id, day, measure)
        | _ -> bad ("PLAN line " ^ header)
      in
      let rec body (p : B.plan) = function
        | "ENDPLAN" :: rest -> ({ p with changes = List.rev p.changes }, rest)
        | line :: rest ->
            let p =
              match fields line with
              | [ "CHANGE"; locus; q ] -> { p with changes = (locus, amount q) :: p.changes }
              | [ "PAID-BY"; tx ] -> { p with paid_by = Some tx }
              | [ "CANCELLED"; day ] -> { p with cancelled_on = Some day }
              | _ -> bad ("PLAN body " ^ line)
            in
            body p rest
        | [] -> bad "PLAN without ENDPLAN"
      in
      body { id; day; measure; changes = []; paid_by = None; cancelled_on = None } rest
  | [] -> bad "missing PLAN block"

(* 3. The changes, in order; Book.apply takes all of them or none. *)
let rec changes = function
  | [] -> []
  | line :: rest -> (
      match fields line with
      | [ "PUT-ENTRY"; m; plan ] ->
          let entry, rest = entry_block rest in
          B.Put_entry { replace = mode m; entry; plan = option plan } :: changes rest
      | [ "PUT-PLAN"; m ] ->
          let plan, rest = plan_block rest in
          B.Put_plan { replace = mode m; plan } :: changes rest
      | [ "CANCEL-PLAN"; id; day ] -> B.Cancel_plan { id; day } :: changes rest
      | [ "CORRECT-ENTRY-DATE"; id; day ] -> B.Correct_entry_date { id; day } :: changes rest
      | _ -> bad ("change " ^ line))

(* 4. Today's guide over the book after the changes. A block names its question
   (Measure, observed day, exclusive end and pool Loci) and is followed by the
   answer; the runner prints the whole block again and compares the text. *)
let pace_blocks book text =
  let rec split acc = function
    | [] -> if acc = [] then [] else bad "PACE without ENDPACE"
    | "ENDPACE" :: rest -> List.rev ("ENDPACE" :: acc) :: split [] rest
    | line :: rest -> split (line :: acc) rest
  in
  List.map
    (fun block ->
      match block with
      | header :: body ->
          let measure, observed_at, end_exclusive =
            match fields header with
            | [ "PACE"; m; o; e ] -> (m, o, e)
            | _ -> bad ("PACE line " ^ header)
          in
          let pool =
            List.filter_map
              (fun l ->
                match fields l with [ "POOL"; locus ] -> Some { B.locus; measure } | _ -> None)
              body
          in
          let answer =
            match B.daily_pace book ~measure ~pool ~observed_at ~end_exclusive with
            | Error why -> [ "REFUSED\t" ^ why ]
            | Ok r ->
                List.map
                  (fun ((c : B.coordinate), n) ->
                    Printf.sprintf "BALANCE\t%s\t%s" c.locus (Z.to_string n))
                  r.pool_balances
                @ List.map
                    (fun (id, n) -> Printf.sprintf "DEDUCTION\t%s\t%s" id (Z.to_string n))
                    r.plan_deductions
                @ [
                    "AVAILABLE\t" ^ Z.to_string r.available_through_end;
                    "DAYS\t" ^ string_of_int r.remaining_days;
                    "DAILY\t" ^ Z.to_string r.daily_pace_quanta;
                  ]
          in
          let printed =
            (header :: List.map (fun (c : B.coordinate) -> "POOL\t" ^ c.locus) pool)
            @ answer @ [ "ENDPACE" ]
          in
          (block, printed)
      | [] -> bad "empty PACE block")
    (split [] (lines text))

let%expect_test "every Scheduled sample gives its listed answer" =
  let failures = ref 0 and accepted = ref 0 and refused = ref 0 and paces = ref 0 in
  let fail name why =
    incr failures;
    Printf.printf "FAIL %s: %s\n" name why
  in
  List.iter
    (fun row ->
      match fields row with
      | [ name; before; expect; _note ] -> (
          try
            let book =
              match B.read (read before) with Ok b -> b | Error why -> bad ("before " ^ why)
            in
            let after_file = name ^ ".after.txt" and pace_file = name ^ ".pace" in
            match (B.apply book (changes (lines (read (name ^ ".changes")))), expect) with
            | Ok after, "ok" ->
                incr accepted;
                if B.print after <> read after_file then fail name "book.txt after differs";
                if exists pace_file then
                  List.iter
                    (fun (want, got) ->
                      incr paces;
                      if want <> got then
                        fail name ("pace answer differs:\n" ^ String.concat "\n" got))
                    (pace_blocks after (read pace_file))
            | Ok _, code -> fail name ("admitted, expected " ^ code)
            | Error why, "ok" -> fail name ("refused " ^ why)
            | Error why, code ->
                incr refused;
                if why <> code then fail name (Printf.sprintf "want %s, got %s" code why);
                if exists after_file || exists pace_file then
                  fail name "a refused sample has no book after it"
          with Bad_sample why -> fail name ("bad sample: " ^ why))
      | _ -> fail row "bad cases row")
    (List.tl (lines (read "cases.tsv")));
  Printf.printf "%d applied, %d refused, %d pace answers, %d failures\n" !accepted !refused !paces
    !failures;
  [%expect {| 12 applied, 14 refused, 11 pace answers, 0 failures |}]
