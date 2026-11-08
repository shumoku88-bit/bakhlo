(* Income and expense of a window.

   A household asks two things of a month: how much came in and went out, and
   how much of what went out was already promised. Only the accounting roles
   decide what counts. An INCOME Locus earns when its effect is negative (the
   money came from it), so its amount is turned around:

     salary  -300000  ->  income 300000
     food      +1200  ->  expense 1200
     food       -300  ->  expense -300   (a return lowers the expense)

   ASSET, LIABILITY and EQUITY are where money sits, not what it earned or cost,
   so they are left out. A Locus without a role is never guessed; its effect is
   kept as unresolved instead. An expense paid for a plan, or a refund of such a
   payment, is the plan's ([Book.settles_plan]); the rest is other spending. The
   answers are pinned in test/reports ([INCOME-EXPENSE]). *)

type line = { locus : string; amount : Z.t }

type summary = {
  measure : string;
  income : line list;
  expense : line list;
  total_income : Z.t;
  total_expense : Z.t;
  scheduled : Z.t;
  other : Z.t;
  net : Z.t;
}

type unresolved = { day : string; locus : string; measure : string; amount : Z.t }
type t = { summaries : summary list; unresolved : unresolved list }

let sum lines = List.fold_left (fun total (l : line) -> Z.add total l.amount) Z.zero lines

(* Per Locus, in Locus order. *)
let lines table =
  Hashtbl.fold (fun locus amount acc -> { locus; amount } :: acc) table []
  |> List.sort (fun (a : line) b -> String.compare a.locus b.locus)

let add table locus amount =
  Hashtbl.replace table locus
    (Z.add amount (Option.value ~default:Z.zero (Hashtbl.find_opt table locus)))

let compute book ~start ~stop =
  let roles = Book.roles book in
  let settles_plan = Book.settles_plan book in
  let entries =
    List.filter (fun (e : Book.entry) -> start <= e.day && e.day < stop) (Book.entries book)
  in
  let unresolved = ref [] in
  let summary measure =
    let income = Hashtbl.create 16 and expense = Hashtbl.create 16 in
    let scheduled = ref Z.zero and other = ref Z.zero in
    List.iter
      (fun (e : Book.entry) ->
        let for_plan = settles_plan e in
        List.iter
          (fun (p : Book.posting) ->
            if p.measure = measure then
              match List.assoc_opt p.locus roles with
              | Some Income -> add income p.locus (Z.neg p.amount)
              | Some Expense ->
                  add expense p.locus p.amount;
                  if for_plan then scheduled := Z.add !scheduled p.amount
                  else other := Z.add !other p.amount
              | Some (Asset | Liability | Equity) -> ()
              | None ->
                  unresolved :=
                    { day = e.day; locus = p.locus; measure; amount = p.amount } :: !unresolved)
          e.effects)
      entries;
    let income = lines income and expense = lines expense in
    let total_income = sum income and total_expense = sum expense in
    {
      measure;
      income;
      expense;
      total_income;
      total_expense;
      scheduled = !scheduled;
      other = !other;
      net = Z.sub total_income total_expense;
    }
  in
  let measures = List.sort_uniq String.compare (List.map fst (Book.measures book)) in
  let summaries = List.map summary measures in
  { summaries; unresolved = List.rev !unresolved }
