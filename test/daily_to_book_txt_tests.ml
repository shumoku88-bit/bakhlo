(* The one-time Daily_book -> book.txt conversion on synthetic households. *)
module C = Bakhlo_migrate.Daily_to_book_txt
module T = Bakhlo_book_txt.Book_txt

let entry ?(memo = "(none)") ?(reversal = "(none)") ?(original = "(none)") ?(merchant = "(none)") id day postings =
  Printf.sprintf
    "(entry %s (date %s) (memo %s) (postings %s) (reversal-of %s) (exchange (none)) (original-amount %s) \
     (merchant %s))"
    id day memo
    (String.concat " " (List.map (fun (l, m, q) -> Printf.sprintf "(posting %s %s %d (none))" l m q) postings))
    reversal original merchant

let book ?(presence = "(not-supplied)") entries =
  String.concat "\n"
    [
      "(bakhlo-daily 5)";
      "(scope corrected-entries explicit-plans)";
      "(measures (measure jpy 0) (measure usd 2))";
      "(labels (provided (label wallet 財布 現金) (label food 食費 毎日) (label old-phone 旧電話 解約)))";
      "(approved-loci (provided wallet food suspense bank))";
      "(entries " ^ String.concat "\n" entries ^ ")";
      "(plans (plan p1 (date 2027-01-06) (measure jpy) (changes (bank -100) (old-phone 100)) (paid-by (some e6)) \
       (cancelled-on (none)))";
      " (plan p2 (date 2027-02-06) (measure jpy) (changes (bank -100) (old-phone 100)) (paid-by (none)) \
       (cancelled-on (some 2027-01-20)))";
      " (plan p3 (date 2027-03-06) (measure jpy) (changes (bank -100) (old-phone 100)) (paid-by (none)) \
       (cancelled-on (none))))";
      "(support (zero-origin (food jpy)) (openings (bank jpy e1))";
      " (observations (observation (reflected e1 e2 e3 e5) (quantities (wallet jpy 1000)))";
      "  (observation (reflected) (quantities (cash-usd usd 700))))";
      " (presence " ^ presence ^ ")";
      " (bounded-history (wallet jpy 2027-01-01)))";
      "";
    ]

let entries =
  [
    entry "e1" "2027-01-01" ~memo:"(some 開始)" [ ("bank", "jpy", 5000); ("equity", "jpy", -5000) ];
    entry "e2" "2027-01-02" ~memo:"(some \"\")" ~original:"(amount usd 200)" ~merchant:"(party shop-1)"
      [ ("food", "jpy", 300); ("wallet", "jpy", -300) ];
    entry "e3" "2027-01-03" ~reversal:"(some e2)" ~merchant:"(nonmerchant)" [ ("food", "jpy", -300); ("wallet", "jpy", 300) ];
    entry "e4" "2027-01-02" ~memo:"(some 後で見つけた)" [ ("food", "jpy", 50); ("wallet", "jpy", -50) ];
    entry "e5" "2027-01-05" ~memo:"(some 仮置き)" [ ("suspense", "jpy", 20); ("wallet", "jpy", -20) ];
    entry "e6" "2027-01-06" [ ("old-phone", "jpy", 100); ("bank", "jpy", -100) ];
  ]

let roles = "LOAM-ACCOUNTING-ROLE-MAP\t1\nROLE\tbank\tASSET\nROLE\tfood\tEXPENSE\nROLE\tmagazine\tEXPENSE\n"
let attention = "LOAM-ATTENTION-MEMORY\t1\nITEM\tattention-1\tNO_DUE_DATE\t-\tcheck\\tthis\nCLOSE\tattention-1\t2027-01-05\tRESOLVED\n"
let input ?(settlements = None) ?(roles = roles) text : C.input = { book = text; accounting_roles = Some roles; attention = Some attention; settlements }

let%expect_test "a synthetic household converts, reprints and keeps every answer" =
  match C.convert (input (book entries)) with
  | Error why -> print_endline ("refused: " ^ why)
  | Ok (t, r) ->
      Printf.printf "entries=%d plans=%d coordinates=%d known=%d unknown=%d empty_memos=%d\nadded=%s\nhidden=%s\n"
        r.entries r.plans r.coordinates r.known r.unknown r.empty_memos (String.concat "," r.added_loci)
        (String.concat "," r.hidden_loci);
      List.iter
        (fun (l, m) ->
          Printf.printf "%s %s %s\n" l m
            (match T.balance t ~locus:l ~measure:m with T.Known q -> Z.to_string q | T.Unknown -> "UNKNOWN"))
        [ ("wallet", "jpy"); ("food", "jpy"); ("bank", "jpy"); ("cash-usd", "usd"); ("suspense", "jpy") ];
      print_string (T.to_string t);
      [%expect {|
        entries=6 plans=3 coordinates=7 known=4 unknown=3 empty_memos=1
        added=suspense,bank,equity,cash-usd,magazine
        hidden=old-phone,equity,cash-usd,magazine
        wallet jpy 950
        food jpy 50
        bank jpy 4900
        cash-usd usd 700
        suspense jpy UNKNOWN
        BOOK	1
        MEASURE	jpy	0
        MEASURE	usd	2
        LOCUS	wallet	財布	現金
        LOCUS	food	食費	毎日
        LOCUS	old-phone	旧電話	解約	HIDDEN
        LOCUS	suspense	suspense
        LOCUS	bank	bank
        LOCUS	equity	equity		HIDDEN
        LOCUS	cash-usd	cash-usd		HIDDEN
        LOCUS	magazine	magazine		HIDDEN
        ROLE	bank	ASSET
        ROLE	food	EXPENSE
        ROLE	magazine	EXPENSE
        TX	e1	2027-01-01	DESC	開始
        EFFECT	bank	jpy	5000
        EFFECT	equity	jpy	-5000
        ENDTX
        TX	e2	2027-01-02
        EFFECT	food	jpy	300
        EFFECT	wallet	jpy	-300
        ORIGINAL	usd	200
        MERCHANT	shop-1
        ENDTX
        TX	e3	2027-01-03
        EFFECT	food	jpy	-300
        EFFECT	wallet	jpy	300
        REVERSAL-OF	e2
        NONMERCHANT
        ENDTX
        TX	e4	2027-01-02	DESC	後で見つけた
        EFFECT	food	jpy	50
        EFFECT	wallet	jpy	-50
        ENDTX
        TX	e5	2027-01-05	DESC	仮置き
        EFFECT	suspense	jpy	20
        EFFECT	wallet	jpy	-20
        ENDTX
        TX	e6	2027-01-06
        EFFECT	old-phone	jpy	100
        EFFECT	bank	jpy	-100
        ENDTX
        PLAN	p1	2027-01-06	jpy
        CHANGE	bank	-100
        CHANGE	old-phone	100
        PAID-BY	e6
        ENDPLAN
        PLAN	p2	2027-02-06	jpy
        CHANGE	bank	-100
        CHANGE	old-phone	100
        CANCELLED	2027-01-20
        ENDPLAN
        PLAN	p3	2027-03-06	jpy
        CHANGE	bank	-100
        CHANGE	old-phone	100
        ENDPLAN
        ZERO-ORIGIN	food	jpy
        OPENING	bank	jpy	e1
        HISTORY-FROM	wallet	jpy	2027-01-01
        ANCHOR	e3
        ALSO	e5
        ASSERT	wallet	jpy	1000
        ENDANCHOR
        ANCHOR	-
        ASSERT	cash-usd	usd	700
        ENDANCHOR
        ITEM	attention-1	NO_DUE_DATE	-	check\tthis
        CLOSE	attention-1	2027-01-05	RESOLVED
        END
        |}]

let%expect_test "what the format cannot represent refuses instead of disappearing" =
  let show label i = Printf.printf "%s: %s\n" label (match C.convert i with Ok _ -> "converted" | Error why -> why) in
  show "settlements" (input ~settlements:(Some "x") (book entries));
  show "presence" (input (book ~presence:"(provided (reflected e1) (coordinates (old-phone jpy)))" entries));
  show "roles header" (input ~roles:"ROLE\tbank\tASSET\n" (book entries));
  show "suspense role" (input ~roles:(roles ^ "ROLE\tsuspense\tASSET\n") (book entries));
  let keyed =
    List.mapi
      (fun i e -> if i = 5 then {|(entry e6 (date 2027-01-06) (memo (none)) (postings (posting old-phone jpy 100 (some k1)) (posting bank jpy -100 (none))) (reversal-of (none)) (exchange (none)) (original-amount (none)) (merchant (none)))|} else e)
      entries
  in
  show "effect key" (input (book keyed));
  [%expect {|
    settlements: settlements
    presence: presence
    roles header: accounting-roles-bad-header
    suspense role: book-txt-suspense-role-line-15
    effect key: effect-key
    |}]
