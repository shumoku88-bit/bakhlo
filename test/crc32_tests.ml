open Base

let%test_unit "crc32 standard vectors" =
  let check input expected_hex =
    let crc = Bakhlo_sexp.Crc32.of_string input in
    let hex = Bakhlo_sexp.Crc32.to_hex crc in
    if not (String.equal hex expected_hex) then
      failwith (Printf.sprintf "CRC32 mismatch for %S: got %s, expected %s" input hex expected_hex)
  in
  check "" "00000000";
  check "123456789" "cbf43926";
  check "Hello, world!" "ebe6c6e6";
  check "bakhlo-records" "f739d4d7"

let%test_unit "crc32 hex roundtrip" =
  let samples = [ ""; "a"; "abc"; "123456789"; "quick brown fox jumps over the lazy dog" ] in
  List.iter samples ~f:(fun s ->
    let crc = Bakhlo_sexp.Crc32.of_string s in
    let hex = Bakhlo_sexp.Crc32.to_hex crc in
    match Bakhlo_sexp.Crc32.of_hex hex with
    | None -> failwith ("Failed to parse hex: " ^ hex)
    | Some parsed ->
        if not (Int32.equal crc parsed) then
          failwith ("Roundtrip mismatch for: " ^ s))
