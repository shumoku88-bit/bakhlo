(* This executable links Core/S-expression/digestif only, not Irmin or Lwt. *)
module T=Trial_image
let () =
  try match Array.to_list Sys.argv with
  | [_;"verify";archive] ->
      let head,x=T.of_archive(T.read archive) in T.verify_complete x;
      Printf.printf "PASS: standalone Core reconstruction; head=%s operation=%s entries=%d external/basis preserved\n%!"
        head x.operation (T.B.entry_count(T.get(T.B.of_string x.book)))
  | [_;"restore";archive;destination] ->
      let head,x=T.of_archive(T.read archive) in T.verify_complete x;
      Unix.mkdir destination 0o700;
      List.iter(fun d->Unix.mkdir(Filename.concat destination d)0o700)["config";"unknown"];
      T.write_new(Filename.concat destination "book.sexp")x.book;
      T.write_new(Filename.concat destination "basis.sexp")x.basis;
      T.write_new(Filename.concat destination "complete.archive.sexp")(T.archive ~head x);
      List.iter(fun(n,v)->let p=Filename.concat destination n in
        match v with None->T.require(not(Sys.file_exists p)) "absent-file-restored-as-empty"
        |Some bytes->T.write_new p bytes;T.require(T.read p=bytes) "external-readback")x.extras;
      Printf.printf "PASS: standalone new-directory restore; Core/book/basis/config/opaque/publication archive preserved; head=%s\n%!" head
  | [_;"compare";a;b] ->
      let ha,xa=T.of_archive(T.read a) and hb,xb=T.of_archive(T.read b) in
      T.require(ha=hb && xa=xb) "archive-diff";print_endline "PASS: complete archive equality"
  | [_;"head";a] -> let h,_=T.of_archive(T.read a) in print_endline h
  | [_;"self-check";dir] ->
      let x=T.fixture() in T.verify_complete x;
      let b=T.get(T.B.of_string x.book) in
      T.require(T.B.entry_count b=20) "not-20";
      List.iter(fun m->let want=ref(Z.of_int 1000) in
        for i=11 to 20 do if T.measure i=m then want:=Z.sub !want (T.amount i) done;
        match T.Q.query(T.B.image b)(T.coordinate "wallet" m)with
        | Ok(T.Q.Exact n)->T.require(Z.equal !want(T.D.Quantity.quanta(T.Q.quantity n))) "independent-initial-arithmetic"
        | _->failwith "initial-quantity-unknown")T.currencies;
      let changed=T.change b "correct" in T.check changed "correct";
      List.iter(fun m->match T.Q.query(T.B.image b)(T.coordinate "wallet" m),T.Q.query(T.B.image changed)(T.coordinate "wallet" m)with
        | Ok(T.Q.Exact a),Ok(T.Q.Exact c)->T.require(T.D.Quantity.equal(T.Q.quantity a)(T.Q.quantity c)) "reflected-correction-double-count"
        | _->failwith "quantity-unknown")T.currencies;
      let failed=try T.check_reference changed;false with _->true in T.require failed "retargeted-basis-admitted";
      let wire=T.archive ~head:"synthetic-provenance" x in ignore(T.of_archive wire);
      let altered={x with extras=List.filter(fun(n,_)->n<>"unknown/opaque")x.extras} in
      let refused=try T.verify_complete altered;false with _->true in T.require refused "unknown-loss-admitted";
      let missing_basis={x with basis=T.B.to_string changed} in
      let refused=try ignore(T.of_archive(T.archive ~head:"synthetic-provenance" missing_basis));false with _->true in T.require refused "fixed-basis-lost";
      let drift=String.map(fun c->if c='F' then 'G' else c)wire in
      let refused=try ignore(T.of_archive drift);false with _->true in T.require refused "archive-drift-admitted";
      let omitted_config={x with extras=List.filter(fun(n,_)->n<>"config/daily-pace.tsv")x.extras} in
      let refused=try T.verify_complete omitted_config;false with _->true in T.require refused "config-loss-admitted";
      T.write_new(Filename.concat dir "initial.sexp") x.book;
      T.write_new(Filename.concat dir "initial.archive.sexp") wire;
      print_endline "PASS: 20 entries, huge quantities/currencies, reflected correction, fixed-source bounds, omitted unknown/config/basis and tampering refusals."
  | _ -> failwith "usage: verify/restore/compare/head/self-check"
  with exn -> Printf.eprintf "restore-refused: %s\n%!" (Printexc.to_string exn);exit 2
