(* What moved through each place in a window.

   Every (Locus, Measure) that an entry touched gets one row: what came in, what
   went out, the difference and the total traffic, with the effects that moved
   it. A wallet topped up by 10000 and spent down by 2000 reads

     wallet  jpy  in 10000  out -2000  net 8000  gross 12000  2 effects

   Rows run from the busiest (largest gross) down, so the places where the most
   money passed come first; ties go by Locus, then Measure. Roles do not matter
   here: every Locus is shown, classified or not. Pinned in test/reports
   ([TRANSACTIONS-FLOW]). *)

type move = { day : string; id : string; amount : Z.t }

type row = {
  locus : string;
  measure : string;
  increase : Z.t;
  decrease : Z.t;
  net : Z.t;
  gross : Z.t;
  moves : move list;
}

let compute book ~start ~stop =
  let table = Hashtbl.create 16 in
  List.iter
    (fun (e : Book.entry) ->
      if start <= e.day && e.day < stop then
        List.iter
          (fun (p : Book.posting) ->
            let key = (p.locus, p.measure) in
            let moves = Option.value ~default:[] (Hashtbl.find_opt table key) in
            Hashtbl.replace table key ({ day = e.day; id = e.id; amount = p.amount } :: moves))
          e.effects)
    (Book.entries book);
  let row (locus, measure) moves =
    let moves = List.rev moves in
    let total keep =
      List.fold_left
        (fun t (m : move) -> if keep m.amount then Z.add t m.amount else t)
        Z.zero moves
    in
    let increase = total (fun n -> Z.sign n > 0) and decrease = total (fun n -> Z.sign n < 0) in
    {
      locus;
      measure;
      increase;
      decrease;
      net = Z.add increase decrease;
      gross = Z.sub increase decrease;
      moves;
    }
  in
  Hashtbl.fold (fun key moves rows -> row key moves :: rows) table []
  |> List.sort (fun a b ->
      match Z.compare b.gross a.gross with
      | 0 -> compare (a.locus, a.measure) (b.locus, b.measure)
      | c -> c)
