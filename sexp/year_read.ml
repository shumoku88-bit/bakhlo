module D = Bakhlo_domain
module Q = Bakhlo_application.Current_quantity_query

type fingerprint = string

let fingerprint contents = Stdlib.Digest.to_hex (Stdlib.Digest.string contents)

type selected = { year : int; revision : int; fingerprint : fingerprint }
type selection = { generation : int; years : selected list }
type original = { generation : int; year : int; revision : int; contents : string }

type error =
  | Selection_missing
  | Selection_unknown of string
  | Selection_corrupt of string
  | Year_missing of int
  | Original_missing of int
  | Original_unavailable of string
  | Mixed_generation of { expected : int; actual : int }
  | Mixed_session
  | Year_mismatch of { expected : int; actual : int }
  | Revision_mismatch of { year : int; expected : int; actual : int }
  | Fingerprint_mismatch of int
  | Unsupported_format of int
  | Admission_failed of { year : int; reason : string }
  | Entry_outside_year of { year : int; entry : string }
  | Not_previous_year of { prior : int; current : int }

module type VERIFIED_SELECTION_SOURCE = sig
  type snapshot

  val acquire : unit -> (snapshot, error) result
  val selection : snapshot -> selection
  val read : snapshot -> year:int -> (original, error) result
end

type balance = Exact of D.Quantity.t | Zero_origin | Known_present | Unknown

let ( let* ) = Result.bind

module Make (Source : VERIFIED_SELECTION_SOURCE) = struct
  type session = { snapshot : Source.snapshot; selection : selection; token : unit ref }
  type year_version = { selected : selected; book : Daily_book.t; token : unit ref }
  type carry_forward = year_version
  type annual_read = { current : year_version; prior : carry_forward }

  let begin_session () =
    let* snapshot = Source.acquire () in
    let selection = Source.selection snapshot in
    let rec check seen = function
      | [] -> Ok ()
      | (s : selected) :: rest ->
          if s.year < 1 || s.year > 9999 || s.revision < 1 then
            Error (Selection_corrupt "invalid year or revision")
          else if List.mem s.year seen then Error (Selection_corrupt "duplicate selected year")
          else check (s.year :: seen) rest
    in
    if selection.generation < 0 then Error (Selection_corrupt "invalid generation")
    else
      let* () = check [] selection.years in
      Ok { snapshot; selection; token = ref () }

  let selected session year =
    match List.find_opt (fun (s : selected) -> s.year = year) session.selection.years with
    | None -> Error (Year_missing year)
    | Some s -> Ok s

  let check_revision (expected : selected) actual =
    if expected.revision = actual then Ok ()
    else Error (Revision_mismatch { year = expected.year; expected = expected.revision; actual })

  let load_year (session : session) ~year =
    let* expected = selected session year in
    let* original = Source.read session.snapshot ~year in
    if original.generation <> session.selection.generation then
      Error
        (Mixed_generation { expected = session.selection.generation; actual = original.generation })
    else if original.year <> year then
      Error (Year_mismatch { expected = year; actual = original.year })
    else
      let* () = check_revision expected original.revision in
      if fingerprint original.contents <> expected.fingerprint then
        Error (Fingerprint_mismatch year)
      else
        match Daily_book.source_format_of_string original.contents with
        | `Records _ | `Unknown -> Error (Unsupported_format year)
        | `Monolithic _ -> (
            match Daily_book.of_string original.contents with
            | Error reason -> Error (Admission_failed { year; reason })
            | Ok book -> (
                let prefix = Printf.sprintf "%04d-" year in
                match
                  List.find_opt
                    (fun (e : Daily_book.entry) -> not (String.starts_with ~prefix e.day))
                    (Daily_book.entries book)
                with
                | Some e -> Error (Entry_outside_year { year; entry = e.id })
                | None -> Ok { selected = expected; book; token = session.token }))

  let verify_prior (session : session) (prior : carry_forward) =
    let* expected = selected session prior.selected.year in
    let* () = check_revision expected prior.selected.revision in
    if expected.fingerprint <> prior.selected.fingerprint then
      Error (Fingerprint_mismatch expected.year)
    else if session.token != prior.token then Error Mixed_session
    else Ok ()

  let derive_carry_forward session prior =
    let* () = verify_prior session prior in
    Ok prior

  let read_with_carry session ~year prior =
    if prior.selected.year <> year - 1 then
      Error (Not_previous_year { prior = prior.selected.year; current = year })
    else
      let* () = verify_prior session prior in
      let* current = load_year session ~year in
      Ok { current; prior }

  let current_book read = read.current.book

  let carry_balance read coordinate =
    match Q.query (Daily_book.image read.prior.book) coordinate with
    | Error (Q.Support_unknown _) -> Unknown
    | Ok (Q.Known_present _) -> Known_present
    | Ok (Q.Exact answer) -> (
        let quantity = Q.quantity answer in
        match Q.premise answer with
        | Q.Zero_origin when Z.equal (D.Quantity.quanta quantity) Z.zero -> Zero_origin
        | Q.Zero_origin | Q.Opening _ | Q.Current_assertion _ -> Exact quantity)
end
