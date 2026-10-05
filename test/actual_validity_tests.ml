open Base
module D = Bakhlo_domain
module V = Bakhlo_application.Actual_validity
module F = Fixtures
let validity event date = F.base_validity (F.id event) date
let admit events facts = V.create ~events:(F.memory events) ~facts ~corrections:[]

let%expect_test "base Actual validity is independently unique, closed and complete" =
  let a = F.event "a" in
  let v = validity "a" "2026-10-03" in
  F.require (Result.is_ok (admit [] [])) "explicit empty source";
  F.require (Result.is_ok (admit [ a ] [ v ])) "explicit base validity";
  (match admit [ a ] [] with Error (Missing_validity { event }) -> F.require (D.Identifier.Event.equal event (F.id "a")) "missing witness" | _ -> failwith "missing validity");
  (match admit [ a ] [ v; v ] with
   | Error (Repeated_fact { reference = Base_ref event; first_position = 1; position = 2 }) -> F.require (D.Identifier.Event.equal event (F.id "a")) "duplicate witness"
   | _ -> failwith "duplicate validity");
  (match admit [ a ] [ validity "outside" "2026-10-03" ] with
   | Error (Unknown_validity_event { event; position = 1 }) -> F.require (D.Identifier.Event.equal event (F.id "outside")) "unknown witness"
   | _ -> failwith "orphan validity");
  (match admit [ a ] [ validity "a" "2026-02-30"; v ] with
   | Error (Invalid_date { position = 1; text = "2026-02-30" }) -> () | _ -> failwith "ordered date refusal");
  Stdlib.Printf.printf "dates do not supply Event membership, precedence or quantity support\n";
  [%expect {| dates do not supply Event membership, precedence or quantity support |}]
;;

let%expect_test "strict Gregorian base dates keep leap-century and lexical boundaries" =
  let admitted date = Result.is_ok (admit [ F.event "a" ] [ validity "a" date ]) in
  List.iter [ "0001-01-01"; "9999-12-31"; "2000-02-29"; "2024-02-29"; "1900-02-28"; "2026-04-30" ]
    ~f:(fun date -> F.require (admitted date) ("valid date " ^ date));
  List.iter [ "0000-01-01"; "1900-02-29"; "2100-02-29"; "2026-02-29"; "2026-04-31"; "2026-00-01";
      "2026-13-01"; "2026-01-00"; "2026-01-32"; "2026-1-01"; "+026-01-01"; " 2026-01-01"; "2026-01-01 " ]
    ~f:(fun date -> F.require (not (admitted date)) ("invalid date " ^ date));
  Stdlib.Printf.printf "six valid and thirteen invalid calendar/lexical specimens\n";
  [%expect {| six valid and thirteen invalid calendar/lexical specimens |}]
;;
