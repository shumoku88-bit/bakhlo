open Base
module B = Bakhlo_sexp.Book
module C = Current_sexp_command
module D = Bakhlo_domain

type side = { locus : string; measure : string; amount : Z.t }

type request = {
  book_path : string;
  output_path : string;
  date : string;
  id : string;
  source : side;
  destination : side;
  description : string option;
}

type plan = Help | Exchange of request | Refused of string

let help : Response.t =
  {
    exit_code = 0;
    stderr = "";
    stdout =
      "Usage: bakhlo exchange --book FILE --out NEW --date YYYY-MM-DD --id ID \\\n       --from LOCUS MEASURE QUANTA --to LOCUS MEASURE QUANTA [--desc TEXT]\n\n\
       2通貨間の両替を、両側の正確な数量を明示して新しいS式候補へ記録します。\n\
       v3 Book専用。レート・評価額・手数料・自宅通貨は推測しません。\n\
       QUANTAは各Measureの最小単位の正の整数です。\n";
  }

let quantity text =
  match Quantity_literal.parse text with
  | Some value when Z.compare (D.Quantity.quanta value) Z.zero > 0 ->
      Ok (D.Quantity.quanta value)
  | Some _ -> Error "両替数量は正の整数で指定してください"
  | None -> Error (Printf.sprintf "invalid integer amount %S" text)

let plan arguments =
  if List.mem arguments "--help" ~equal:String.equal || List.mem arguments "-h" ~equal:String.equal
  then Help
  else
    let rec loop book out date id source destination description = function
      | [] -> (
          match (book, out, date, id, source, destination) with
          | Some book_path, Some output_path, Some date, Some id, Some source, Some destination ->
              if String.equal source.measure destination.measure then
                Refused "両替元と両替先のMeasureは異なる必要があります"
              else Exchange { book_path; output_path; date; id; source; destination; description }
          | _ ->
              Refused
                "--book/--out/--date/--id/--from/--to をすべて明示してください")
      | "--book" :: value :: rest -> loop (Some value) out date id source destination description rest
      | "--out" :: value :: rest -> loop book (Some value) date id source destination description rest
      | "--date" :: value :: rest -> loop book out (Some value) id source destination description rest
      | "--id" :: value :: rest -> loop book out date (Some value) source destination description rest
      | "--desc" :: value :: rest -> loop book out date id source destination (Some value) rest
      | "--from" :: locus :: measure :: amount :: rest -> (
          match quantity amount with
          | Error message -> Refused message
          | Ok amount ->
              loop book out date id (Some { locus; measure; amount }) destination description rest)
      | "--to" :: locus :: measure :: amount :: rest -> (
          match quantity amount with
          | Error message -> Refused message
          | Ok amount ->
              loop book out date id source (Some { locus; measure; amount }) description rest)
      | unexpected :: _ -> Refused (Printf.sprintf "認識できない引数です: %S" unexpected)
    in
    loop None None None None None None None arguments

let event_text request =
  let description =
    match request.description with
    | None | Some "" -> "(description (not-supplied))"
    | Some text -> Printf.sprintf "(description (text %S))" text
  in
  Printf.sprintf
    "(event %S\n  (day (date %S))\n  %s\n  (effect (key (named \"exchange-source\")) (locus %S) (measure %S) (quanta -%s))\n  (effect (key (named \"exchange-destination\")) (locus %S) (measure %S) (quanta %s)))\n"
    request.id request.date description request.source.locus request.source.measure
    (Z.to_string request.source.amount)
    request.destination.locus request.destination.measure (Z.to_string request.destination.amount)

let evaluate request contents =
  match C.read ~path:request.book_path contents with
  | Error response -> Error response
  | Ok base -> (
      match
        B.append_exchange ~base ~event:(event_text request) ~source:"exchange-source"
          ~destination:"exchange-destination"
      with
      | Error error -> Error (C.codec_refusal error)
      | Ok candidate -> Ok (B.document candidate))
