(* A conditional outlook for the money the household has chosen to watch.

   Today's exact balances of the chosen (Locus, Measure) cells are added up, then
   every open plan that moves them is applied on its day, up to a day the household
   names: "assume nothing else is scheduled through 03-31". The path is only as good
   as that assumption, so it is never called a forecast. A plan already overdue is
   refused rather than moved, and a cell without a known balance is never read as
   zero. Unlike Daily Pace, incoming plans raise the path. Pinned in test/reports
   ([LIQUIDITY]). *)

type point = { date : string; scheduled_change : Z.t; balance : Z.t }

type snapshot = {
  as_of : string;
  assumed_complete_through : string;
  measure : string;
  current_selected : Z.t;
  points : point list;
}

let compute book ~today ~coords ~assumed_complete_through =
  let horizon = assumed_complete_through in
  if not (Day.is_valid today) then Error "Liquidity requires a real canonical today date."
  else if not (Day.is_valid horizon) then
    Error "The assumed complete-through date must be a real YYYY-MM-DD calendar date."
  else if String.compare horizon today < 0 then
    Error "The assumed complete-through date is inclusive and cannot precede today."
  else if coords = [] then Error "Liquidity requires a nonempty balance-view.tsv selection."
  else if List.length (List.sort_uniq compare coords) <> List.length coords then
    Error "Liquidity selection contains duplicate coordinates; no partial sum is used."
  else
    let measure = snd (List.hd coords) in
    if List.exists (fun (_, m) -> m <> measure) coords then
      Error "Liquidity selection spans multiple Measures; exactly one is required."
    else
      let selected = Hashtbl.create (List.length coords) in
      List.iter (fun (locus, _) -> Hashtbl.add selected locus ()) coords;
      let rec quantities total = function
        | [] -> Ok total
        | (locus, _) :: rest -> (
            match Book.quantity book ~locus ~measure with
            | Some q -> quantities (Z.add total q.amount) rest
            | None ->
                Error
                  (Printf.sprintf
                     "Selected coordinate %s (%s) has no supported current quantity; Liquidity \
                      never infers zero."
                     locus measure))
      in
      Result.bind (quantities Z.zero coords) (fun current_selected ->
          let rec changes acc = function
            | [] -> Ok acc
            | (plan : Book.plan) :: rest ->
                let net =
                  if plan.measure <> measure then Z.zero
                  else
                    List.fold_left
                      (fun sum (locus, amount) ->
                        if Hashtbl.mem selected locus then Z.add sum amount else sum)
                      Z.zero plan.changes
                in
                if Z.equal net Z.zero then changes acc rest
                else if not (Day.is_valid plan.day) then
                  Error
                    (Printf.sprintf
                       "Selected Scheduled plan %s has an invalid due date; Liquidity refuses."
                       plan.id)
                else if String.compare plan.day today < 0 then
                  Error
                    (Printf.sprintf
                       "Selected Scheduled plan %s is overdue (%s before today %s); Liquidity \
                        refuses to move or settle it."
                       plan.id plan.day today)
                else if String.compare plan.day horizon > 0 then changes acc rest
                else changes ((plan.day, net) :: acc) rest
          in
          Result.map
            (fun dated ->
              let buckets = Hashtbl.create (List.length dated) in
              List.iter
                (fun (day, net) ->
                  let previous = Option.value ~default:Z.zero (Hashtbl.find_opt buckets day) in
                  Hashtbl.replace buckets day (Z.add previous net))
                dated;
              let changes =
                Hashtbl.fold (fun day net rows -> (day, net) :: rows) buckets []
                |> List.sort (fun (left, _) (right, _) -> String.compare left right)
              in
              let rec build running acc = function
                | [] -> List.rev acc
                | (date, scheduled_change) :: rest ->
                    let balance = Z.add running scheduled_change in
                    build balance ({ date; scheduled_change; balance } :: acc) rest
              in
              {
                as_of = today;
                assumed_complete_through = horizon;
                measure;
                current_selected;
                points = build current_selected [] changes;
              })
            (changes [] (Book.open_plans book)))

let final_at_horizon snapshot =
  List.fold_left (fun _ (point : point) -> point.balance) snapshot.current_selected snapshot.points

let low_water snapshot =
  List.fold_left
    (fun low (point : point) -> if Z.compare point.balance low < 0 then point.balance else low)
    snapshot.current_selected snapshot.points
