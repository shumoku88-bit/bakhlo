(* Plans in series. A series is not stored: it is the open plans of one Measure
   whose signed Loci are the same (which Loci are paid from and which receive),
   whatever their amounts. Rent paid every month from the bank is one series;
   the same rent paid once from the wallet is another.

   Three household operations follow from that:
   - a batch amount change, for a price change: every chosen two-row plan gets
     the new amount, a split plan is refused (no allocation is guessed) and a
     plan already at that amount is left out;
   - replenishment, for filling the coming months: the k-th occurrence after an
     anchor keeps the anchor's day of the month, and a month without that day
     is left for the person to date (never clamped to another day);
   - cancellation is Book's (one Cancel_plan per plan, applied together). *)
module B = Book

type shape = { negative : string list; positive : string list }

let shape (p : B.plan) =
  let side keep =
    List.sort_uniq String.compare
      (List.filter_map (fun (locus, q) -> if keep (Z.sign q) then Some locus else None) p.changes)
  in
  { negative = side (fun s -> s < 0); positive = side (fun s -> s > 0) }

let by_day (a : B.plan) (b : B.plan) =
  match String.compare a.day b.day with 0 -> String.compare a.id b.id | c -> c

let same (a : B.plan) (b : B.plan) = a.measure = b.measure && shape a = shape b

let series_of book (source : B.plan) =
  let open_plans = B.open_plans book in
  if not (List.exists (( = ) source) open_plans) then Error "source-not-open"
  else Ok (List.stable_sort by_day (List.filter (same source) open_plans))

let series book =
  let rec group = function
    | [] -> []
    | (p : B.plan) :: rest ->
        let mine, others = List.partition (same p) rest in
        (p :: mine) :: group others
  in
  group (List.stable_sort by_day (B.open_plans book))

let simple_amount (p : B.plan) =
  match p.changes with
  | [ (a, x); (b, y) ] when a <> b && Z.sign x * Z.sign y < 0 ->
      Some (if Z.sign x > 0 then x else y)
  | _ -> None

let change_amount plans ~amount =
  match List.find_opt (fun p -> simple_amount p = None) plans with
  | Some (p : B.plan) -> Error ("split-plan:" ^ p.id)
  | None -> (
      let changed =
        List.filter_map
          (fun (p : B.plan) ->
            if simple_amount p = Some amount then None
            else
              Some
                {
                  p with
                  changes =
                    List.map
                      (fun (locus, q) -> (locus, if Z.sign q < 0 then Z.neg amount else amount))
                      p.changes;
                })
          plans
      in
      match changed with [] -> Error "unchanged" | _ -> Ok changed)

type slot = Dated of string | Missing of { year : int; month : int; day : int }

let slot ~anchor ~every_months k =
  match Day.parts anchor with
  | Error _ -> None
  | Ok (year, month, day) ->
      let index = (year * 12) + (month - 1) + (k * every_months) in
      let year = index / 12 and month = (index mod 12) + 1 in
      if year < 1 || year > 9999 then None
      else if day > Day.days_in_month ~year ~month then Some (Missing { year; month; day })
      else Some (Dated (Printf.sprintf "%04d-%02d-%02d" year month day))
