(* Trend / Locus display evidence. Calculation rules live in test/reports;
   a zero flow still supplies no balance evidence, and amounts use their scale. *)
module B = Bakhlo_household.Book
module T = Bakhlo_household.Trend

let get = function Ok x -> x | Error why -> failwith why
let require condition why = if not condition then failwith why
let z = Z.of_int
let coord locus measure : T.coordinate = { locus; measure }
let posting locus measure n = Printf.sprintf "EFFECT\t%s\t%s\t%s\n" locus measure (Z.to_string n)

(* One balanced jpy pair: the signed effect lands on a, its counter-effect on b. *)
let ab n = posting "a" "jpy" n ^ posting "b" "jpy" (Z.neg n)
let row id day postings = Printf.sprintf "TX\t%s\t%s\n%sENDTX\n" id day postings

(* Loci in [approved] are offered for new entries; those in [hidden] are only recorded. *)
let fixture ?(approved = [ "a"; "b"; "c"; "gamma" ]) ?(hidden = []) entries =
  let locus suffix l = Printf.sprintf "LOCUS\t%s\t%s\t%s\n" l l suffix in
  get
  @@ B.read
       ("BOOK\t1\nMEASURE\tjpy\t0\nMEASURE\teur\t2\n"
       ^ String.concat "" (List.map (locus "") approved)
       ^ String.concat "" (List.map (locus "\tHIDDEN") hidden)
       ^ entries ^ "ZERO-ORIGIN\ta\tjpy\nZERO-ORIGIN\tb\tjpy\nEND\n")

let preset name dates = name ^ "\t" ^ String.concat "\t" dates ^ "\n"
let config = preset "household" [ "2026-10-01"; "2026-10-03"; "2026-11-01" ]
let observation = "2026-10-03"

let primary =
  fixture
    (row "sep" "2026-09-30" (ab (z 900))
    ^ row "oct1" "2026-10-01" (ab (z 5))
    ^ row "oct2" "2026-10-02"
        (ab (z (-2)) ^ posting "a" "eur" (z 12345) ^ posting "b" "eur" (z (-12345)))
    ^ row "oct3" "2026-10-03" (ab (z (-4)))
    ^ row "oct4" "2026-10-04" (ab (z 100)))

let project ?(config = Some config) ?(grain = T.Cycle) ?(scope = T.All_history) book observed
    coordinates =
  T.project book ~observed_at:observed ~boundary_presets_text:config ~grain ~scope ~coordinates
  |> Result.map_error T.message

let series_of snapshot ~locus =
  match Array.find_opt (fun (s : T.series) -> s.coordinate.locus = locus) snapshot.T.series with
  | Some s -> s
  | None -> failwith ("missing series " ^ locus)

let effects_book_checks () =
  require
    (Book_display.quantity_value ~book:primary ~measure:"jpy" "gamma" = Book_display.Unsupported)
    "an empty recorded flow invents no balance support";
  let eur = get (project ~grain:T.Day primary observation [ coord "a" "eur" ]) in
  let e = series_of eur ~locus:"a" in
  require
    (B.format primary "eur" e.points.(1).total = "123.45")
    "other-measure postings project only under their own measure at their own scale"

let () =
  effects_book_checks ();
  print_endline "PASS: Trend/Locus balance evidence and Measure-scale formatting."
