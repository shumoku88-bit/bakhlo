module B = Bakhlo_sexp.Daily_book
module D = Bakhlo_domain
module X = Sexplib0.Sexp

let get = function Ok x -> x | Error why -> failwith why

(* Deliberately retain the former string-building printer as an independent
   formatting oracle. Production width/Buffer helpers must not be reused here. *)
let reference_render x =
  let tags =
    String.split_on_char ' '
      "bakhlo-daily scope measures measure labels label approved-loci entries entry date memo \
       postings posting reversal-of exchange keys plans plan changes paid-by cancelled-on support \
       budgets budget start end-exclusive allocations expense-loci actual-routes plan-routes \
       zero-origin openings observations observation reflected quantities presence coordinates \
       provided not-supplied none some"
  in
  let quote s =
    let b = Buffer.create (String.length s + 2) in
    Buffer.add_char b '"';
    String.iter
      (function
        | '"' -> Buffer.add_string b "\\\""
        | '\\' -> Buffer.add_string b "\\\\"
        | '\n' -> Buffer.add_string b "\\n"
        | '\r' -> Buffer.add_string b "\\r"
        | '\t' -> Buffer.add_string b "\\t"
        | c when Char.code c < 32 || Char.code c = 127 ->
            Buffer.add_string b (Printf.sprintf "\\%03d" (Char.code c))
        | c -> Buffer.add_char b c)
      s;
    Buffer.add_char b '"';
    Buffer.contents b
  in
  let numeric s =
    let len = String.length s in
    if len = 0 then false
    else
      let start = if s.[0] = '-' || s.[0] = '+' then 1 else 0 in
      start < len
      && String.for_all (fun c -> c >= '0' && c <= '9') (String.sub s start (len - start))
      &&
        try
          ignore (Z.of_string s);
          true
        with Invalid_argument _ -> false
  in
  let leaf s = if numeric s then s else quote s in
  let rec flat = function
    | X.Atom s -> leaf s
    | X.List (X.Atom tag :: xs) when List.mem tag tags ->
        "(" ^ tag ^ (if xs = [] then "" else " " ^ String.concat " " (List.map flat xs)) ^ ")"
    | X.List xs -> "(" ^ String.concat " " (List.map flat xs) ^ ")"
  in
  let rec pretty indent x =
    match x with
    | X.List (X.Atom tag :: xs) when List.mem tag tags && String.length (flat x) + indent > 110 ->
        "(" ^ tag
        ^ String.concat ""
            (List.map
               (fun value -> "\n" ^ String.make (indent + 2) ' ' ^ pretty (indent + 2) value)
               xs)
        ^ ")"
    | X.Atom _ | X.List _ -> flat x
  in
  pretty 0 x

let%expect_test "Daily Buffer printer preserves former bytes and layout boundaries" =
  let base =
    get
      (B.of_string
         "(bakhlo-daily 3) (scope corrected-entries explicit-plans)\n\
          (measures (measure jpy 0) (measure eur 2))\n\
          (labels (provided (label wallet -00042 財布) (label food 同じ表示 食費)))\n\
          (approved-loci (provided wallet food some)) (entries) (plans)\n\
          (support (zero-origin (wallet jpy) (food jpy) (some jpy))\n\
          (openings) (observations) (presence (not-supplied)))")
  in
  let amount = Z.of_string "12345678901234567890123456789012345678901234567890" in
  let posting ?(measure = "jpy") ?key locus quantity =
    D.Effect.create
      ~key:
        (Option.map
           (fun key ->
             match D.Identifier.Effect_key.of_string key with
             | Ok x -> x
             | Error _ -> failwith "key")
           key)
      ~locus:
        (match D.Identifier.Locus.of_string locus with Ok x -> x | Error _ -> failwith "locus")
      ~measure:
        (match D.Identifier.Measure.of_string measure with
        | Ok x -> x
        | Error _ -> failwith "measure")
      ~quantity:(D.Quantity.of_quanta quantity)
  in
  let entry memo : B.entry =
    {
      id = "some";
      day = "2026-10-03";
      memo;
      effects = [ posting "wallet" (Z.neg amount); posting "food" amount ];
      reversal_of = None;
      exchange = None;
    }
  in
  let checked = ref 0 in
  let check book =
    let actual = B.to_string book in
    let expected =
      "; Corrected entries and explicit plans. No correction-version chains.\n"
      ^ String.concat "\n\n" (List.map reference_render (Parsexp.Many.parse_string_exn actual))
      ^ "\n"
    in
    if actual <> expected then failwith "printer-bytes-or-110-byte-layout-changed";
    if B.to_string (get (B.of_string actual)) <> actual then failwith "printer-not-stable";
    incr checked
  in
  check base;
  List.iter
    (fun memo -> check (get (B.put_entry base ~replace:false (entry memo) ~plan:None)))
    (None
    :: List.map
         (fun s -> Some s)
         ([
            "";
            "none";
            "scope";
            "001";
            "+0003";
            "-0";
            "+";
            "-";
            "1_0";
            "0x10";
            "- 2";
            "1.0";
            "²";
            String.make 8192 '9';
            "引用\"\\\t\n\r";
            "あい€\194\133";
            String.init 128 Char.chr;
          ]
         @ List.init 126 (fun n -> String.make n 'a')
         @ List.init 35 (fun n -> String.make n '\000')
         @ List.init 45 (fun n -> String.concat "" (List.init n (fun _ -> "あ")))));
  let plan : B.plan =
    {
      id = "plan";
      day = "2026-10-08";
      measure = "jpy";
      changes = [ ("wallet", Z.neg amount); ("food", amount) ];
      paid_by = None;
      cancelled_on = None;
    }
  in
  let planned = get (B.put_plan base ~replace:false plan) in
  check planned;
  check (get (B.put_entry planned ~replace:false (entry None) ~plan:(Some plan.id)));
  check (get (B.cancel_plan planned ~id:plan.id ~day:"2026-10-04"));
  let actual = get (B.put_entry base ~replace:false (entry None) ~plan:None) in
  let refund =
    {
      (entry (Some "返金")) with
      id = "refund";
      reversal_of = Some "some";
      effects = [ posting "wallet" amount; posting "food" (Z.neg amount) ];
    }
  in
  check (get (B.put_entry actual ~replace:false refund ~plan:None));
  let exchange =
    {
      (entry None) with
      effects =
        [
          posting ~key:"from" "wallet" (Z.neg amount);
          posting ~measure:"eur" ~key:"to" "food" amount;
        ];
      exchange = Some ("from", "to");
    }
  in
  check (get (B.put_entry base ~replace:false exchange ~plan:None));
  let budget : B.budget =
    {
      id = "some";
      start_day = "2026-10-01";
      end_exclusive = "2026-11-01";
      measure = "jpy";
      allocations = [ ("用途", amount) ];
      expense_loci = [ "food" ];
      actual_routes = [ ("food", Some "用途") ];
      plan_routes = [];
    }
  in
  check (get (B.put_budget base ~replace:false budget));
  check
    (get
       (B.put_budget planned ~replace:false
          { budget with plan_routes = [ (plan.id, "food", None) ] }));
  Printf.printf "byte-identical reference and stable roundtrip: %d cases\n" !checked;
  [%expect {| byte-identical reference and stable roundtrip: 232 cases |}]

let%expect_test "shared integer syntax keeps strict signed decimal admission" =
  let read text =
    let atom = X.to_string_mach (X.Atom text) in
    B.of_string
      ("(bakhlo-daily 3) (scope corrected-entries explicit-plans)\n\
        (measures (measure jpy 0)) (labels (not-supplied))\n\
        (approved-loci (not-supplied)) (entries) (plans)\n\
        (support (zero-origin) (openings)\n\
        (observations (observation (reflected) (quantities (wallet jpy " ^ atom
     ^ ")))) (presence (not-supplied)))")
  in
  let accepted =
    List.for_all
      (fun text -> match read text with Ok _ -> true | Error _ -> false)
      [ "0"; "00"; "-0"; "+0"; "+123"; "-123"; String.make 8192 '9' ]
  in
  let refused =
    List.for_all
      (fun text -> read text = Error "invalid-integer")
      [ ""; "+"; "-"; "1_0"; "0x10"; "1.0"; " 1"; "- 2"; "²"; "1\n" ]
  in
  Printf.printf "signed decimal / strict refusal: %b %b\n" accepted refused;
  [%expect {| signed decimal / strict refusal: true true |}]
