open Base
module B = Bakhlo_sexp.Book
module C = Current_sexp_command
module D = Bakhlo_domain

type single_transfer = {
  from_locus : string;
  to_locus : string;
  amount : Z.t;
}

type movement_kind =
  | Single of single_transfer
  | Multiple of (string * Z.t) list

type request = {
  book_path : string;
  output_path : string option;
  date : string option;
  id : string option;
  measure : string option;
  movement : movement_kind;
  description : string option;
}

type plan =
  | Help
  | Record of request
  | Refused of string

let help : Response.t =
  {
    exit_code = 0;
    stderr = "";
    stdout =
      "Usage: bakhlo record --book FILE [OPTIONS] [DESCRIPTION]\n\n\
       日常の支出・収入・資金移動をS式台帳に記録します。\n\n\
       基本オプション:\n\
         --book FILE            対象のS式台帳ファイル（必須）\n\
         --out FILE             出力先ファイル（省略時は --book をアトミック更新）\n\
         --date YYYY-MM-DD      取引日（省略時は今日の日付）\n\
         --id STRING            取引ID（省略時は自動生成）\n\
         --measure MEASURE      通貨単位（省略時は台帳の定義通貨）\n\
         --desc TEXT            メモ・摘要（最後の引数としても指定可能）\n\n\
       単一移動（1対1のショートカット）:\n\
         --from LOCUS           出金元（口座・科目）\n\
         --to LOCUS             入金先（口座・科目）\n\
         --amount QUANTA        金額（正の整数）\n\n\
       複数ポスティング（複合仕訳・まとめ買い）:\n\
         --effect LOCUS QUANTA  科目と金額（符号付き、合計が0になるよう複数回指定）\n\n\
       例:\n\
         bakhlo record --book ledger.sexp --from wallet --to food --amount 1000 \"昼食\"\n\
         bakhlo record --book ledger.sexp --effect wallet -4000 --effect food 3000 --effect daily 1000 \"スーパー買い物\"\n";
  }

let today () =
  let tm = Unix.localtime (Unix.time ()) in
  Printf.sprintf "%04d-%02d-%02d" (tm.Unix.tm_year + 1900) (tm.Unix.tm_mon + 1) tm.Unix.tm_mday

let generate_id () =
  let tm = Unix.localtime (Unix.time ()) in
  let time_sec = Int.of_float (Unix.time ()) % 100000 in
  Printf.sprintf "tx-%04d%02d%02d-%05d"
    (tm.Unix.tm_year + 1900) (tm.Unix.tm_mon + 1) tm.Unix.tm_mday time_sec

let parse_quantity text =
  match Quantity_literal.parse text with
  | Some q -> Ok (D.Quantity.quanta q)
  | None -> Error (Printf.sprintf "invalid integer amount %S" text)

let plan arguments =
  if List.mem arguments "--help" ~equal:String.equal || List.mem arguments "-h" ~equal:String.equal then
    Help
  else
    let rec parse ~book ~out ~date ~id ~measure ~from_locus ~to_locus ~amount ~effects ~desc = function
      | [] -> (
          match book with
          | None -> Refused "--book 台帳ファイルの指定が必要です"
          | Some book_path -> (
              match (from_locus, to_locus, amount, effects) with
              | Some from_l, Some to_l, Some amt, [] ->
                  if Z.compare amt Z.zero <= 0 then
                    Refused "--amount は正の整数で指定してください"
                  else
                    Record
                      {
                        book_path;
                        output_path = out;
                        date;
                        id;
                        measure;
                        movement = Single { from_locus = from_l; to_locus = to_l; amount = amt };
                        description = desc;
                      }
              | None, None, None, _ :: _ :: _ ->
                  Record
                    {
                      book_path;
                      output_path = out;
                      date;
                      id;
                      measure;
                      movement = Multiple (List.rev effects);
                      description = desc;
                    }
              | None, None, None, [ _ ] ->
                  Refused "複数ポスティングには少なくとも2つ以上の --effect が必要です"
              | Some _, _, _, _ :: _ | _, Some _, _, _ :: _ | _, _, Some _, _ :: _ ->
                  Refused "--from/--to/--amount と --effect は同時に指定できません"
              | _, _, _, [] ->
                  Refused "取引内容の指定が必要です（--from/--to/--amount または --effect）"))
      | "--book" :: path :: rest ->
          parse ~book:(Some path) ~out ~date ~id ~measure ~from_locus ~to_locus ~amount ~effects ~desc rest
      | "--out" :: path :: rest ->
          parse ~book ~out:(Some path) ~date ~id ~measure ~from_locus ~to_locus ~amount ~effects ~desc rest
      | "--date" :: d :: rest ->
          parse ~book ~out ~date:(Some d) ~id ~measure ~from_locus ~to_locus ~amount ~effects ~desc rest
      | "--id" :: i :: rest ->
          parse ~book ~out ~date ~id:(Some i) ~measure ~from_locus ~to_locus ~amount ~effects ~desc rest
      | "--measure" :: m :: rest ->
          parse ~book ~out ~date ~id ~measure:(Some m) ~from_locus ~to_locus ~amount ~effects ~desc rest
      | "--from" :: f :: rest ->
          parse ~book ~out ~date ~id ~measure ~from_locus:(Some f) ~to_locus ~amount ~effects ~desc rest
      | "--to" :: t :: rest ->
          parse ~book ~out ~date ~id ~measure ~from_locus ~to_locus:(Some t) ~amount ~effects ~desc rest
      | "--amount" :: amt_str :: rest -> (
          match parse_quantity amt_str with
          | Error err -> Refused err
          | Ok amt ->
              parse ~book ~out ~date ~id ~measure ~from_locus ~to_locus ~amount:(Some amt) ~effects ~desc rest)
      | "--effect" :: locus :: amt_str :: rest -> (
          match parse_quantity amt_str with
          | Error err -> Refused err
          | Ok amt ->
              parse ~book ~out ~date ~id ~measure ~from_locus ~to_locus ~amount
                ~effects:((locus, amt) :: effects) ~desc rest)
      | "--desc" :: d :: rest ->
          parse ~book ~out ~date ~id ~measure ~from_locus ~to_locus ~amount ~effects ~desc:(Some d) rest
      | [ trailing_desc ] when not (String.is_prefix trailing_desc ~prefix:"-") ->
          parse ~book ~out ~date ~id ~measure ~from_locus ~to_locus ~amount ~effects
            ~desc:(Some trailing_desc) []
      | unexpected :: _ ->
          Refused (Printf.sprintf "認識できないオプションまたは引数です: %S" unexpected)
    in
    parse ~book:None ~out:None ~date:None ~id:None ~measure:None ~from_locus:None ~to_locus:None
      ~amount:None ~effects:[] ~desc:None arguments

let write_file_atomic target_path content =
  let tmp_path = Printf.sprintf "%s.tmp.%d" target_path (Unix.getpid ()) in
  try
    let oc = Stdlib.open_out_bin tmp_path in
    Stdlib.output_string oc content;
    Stdlib.close_out oc;
    Unix.rename tmp_path target_path;
    Ok ()
  with exn ->
    (try Unix.unlink tmp_path with _ -> ());
    Error (Stdlib.Printexc.to_string exn)

let evaluate request contents =
  match C.read ~path:request.book_path contents with
  | Error response -> response
  | Ok base -> (
      let measures = B.measures base in
      let measure_result =
        match request.measure with
        | Some m -> Ok m
        | None -> (
            match measures with
            | [ single ] -> Ok (D.Identifier.Measure.to_string single.id)
            | [] -> Error "台帳に通貨が定義されていません（(measure ...) が必要です）"
            | _ ->
                Error
                  "台帳に複数の通貨が定義されています。--measure で通貨を指定してください")
      in
      match measure_result with
      | Error msg -> C.syntax_refusal msg
      | Ok measure -> (
          let date = Option.value request.date ~default:(today ()) in
          let id = Option.value request.id ~default:(generate_id ()) in
          let effects =
            match request.movement with
            | Single { from_locus; to_locus; amount } ->
                [ (from_locus, Z.neg amount); (to_locus, amount) ]
            | Multiple list -> list
          in
          let desc_sexp =
            match request.description with
            | None | Some "" -> "(description (absent))"
            | Some text -> Printf.sprintf "(description (text %S))" text
          in
          let effects_sexp =
            effects
            |> List.map ~f:(fun (locus, quanta) ->
                   Printf.sprintf "  (effect (key (unkeyed)) (locus %S) (measure %S) (quanta %s))"
                     locus measure (Z.to_string quanta))
            |> String.concat ~sep:"\n"
          in
          let event_str =
            Printf.sprintf "(event %S\n  (day (date %S))\n  %s\n%s)\n" id date desc_sexp
              effects_sexp
          in
          match B.append ~base ~event:event_str with
          | Error error -> C.codec_refusal error
          | Ok candidate -> (
              let doc = B.document candidate in
              let output_bytes = B.to_string doc in
              let target_path = Option.value request.output_path ~default:request.book_path in
              match write_file_atomic target_path output_bytes with
              | Error err ->
                  {
                    Response.exit_code = 1;
                    stdout = "";
                    stderr = Printf.sprintf "ファイルの書き込みに失敗しました %S: %s\n" target_path err;
                  }
              | Ok () ->
                  let summary =
                    match request.movement with
                    | Single { from_locus; to_locus; amount } ->
                        Printf.sprintf "%s -> %s %s %s" from_locus to_locus (Z.to_string amount)
                          measure
                    | Multiple effs ->
                        effs
                        |> List.map ~f:(fun (l, q) -> Printf.sprintf "%s:%s" l (Z.to_string q))
                        |> String.concat ~sep:", "
                  in
                  let desc_info =
                    match request.description with
                    | Some d when not (String.is_empty d) -> Printf.sprintf " (%s)" d
                    | _ -> ""
                  in
                  {
                    Response.exit_code = 0;
                    stderr = "";
                    stdout =
                      Printf.sprintf "取引を記録しました: %s [%s] %s%s\n" id date summary desc_info;
                  })))
