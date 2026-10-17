(* Synthetic research image and independent archive reader; no Irmin dependency. *)
module D = Bakhlo_domain
module A = Bakhlo_application
module B = Bakhlo_sexp.Daily_book
module R = Bakhlo_sexp.Records_book
module Q = A.Current_quantity_query
module X = Sexplib0.Sexp
let require b why = if not b then failwith why
let get = function Ok x -> x | Error _ -> failwith "core-admission-refused"
let ident = get
let atom s = X.Atom s
let sx x = X.to_string x
let parse s = match Parsexp.Single.parse_string s with Ok x -> x | Error _ -> failwith "archive-syntax"
let many s = match Parsexp.Many.parse_string s with Ok x -> x | Error _ -> failwith "book-syntax"
let sha s = Digestif.SHA256.(to_hex (digest_string s))
let read p = let ic=open_in_bin p in Fun.protect ~finally:(fun()->close_in ic) (fun()->really_input_string ic (in_channel_length ic))
let write_new p s = let fd=Unix.openfile p [Unix.O_CREAT;Unix.O_EXCL;Unix.O_WRONLY] 0o600 in
  let oc=Unix.out_channel_of_descr fd in Fun.protect ~finally:(fun()->close_out_noerr oc) (fun()->output_string oc s; flush oc)
let coordinate l m : D.Effect_coordinate.t = {locus=ident(D.Identifier.Locus.of_string l);measure=ident(D.Identifier.Measure.of_string m)}
let posting m l key z = D.Effect.create ~key:(Some(ident(D.Identifier.Effect_key.of_string key)))
  ~locus:(ident(D.Identifier.Locus.of_string l)) ~measure:(ident(D.Identifier.Measure.of_string m)) ~quantity:(D.Quantity.of_quanta z)
let currencies=["jpy";"eur";"usd"]
let measure i = List.nth currencies (i mod 3)
let amount i = if i=20 then Z.shift_left Z.one 180 else Z.of_int(100+i)
let name i=Printf.sprintf "e%02d" i
let entry i : B.entry = let id=name i and m=measure i and n=amount i in
  {id;day="2000-01-01";memo=Some "合成 \"quoted\"\\\n\000\127";
   effects=[posting m "wallet" (id^"-src") (Z.neg n);posting m "food" (id^"-dst") n];reversal_of=None;exchange=None;original_amount=None}
let initial () =
  let header : R.header={version=1;measures=["jpy",0;"eur",2;"usd",2];labels=Some[];
    approved_loci=Some["wallet";"food";"fees";"bank"];
    origins=List.concat_map(fun m->[coordinate "food" m;coordinate "fees" m]) currencies;
    openings=[];presence=None;opaque=[];
    observations=[{A.Current_quantity_groups.reflected_roots=List.init 10(fun i->ident(D.Identifier.Event.of_string(name(i+1))));
      assertions=List.map(fun m->{A.Current_quantity_projection.coordinate=coordinate "wallet" m;quantity=D.Quantity.of_quanta(Z.of_int 1000)})currencies}]} in
  let entries=List.init 20(fun j->let e=entry(j+1) in R.Entry {id=e.id;day=e.day;memo=e.memo;token=None;effects=e.effects;reversal_of=None;exchange=None;original_amount=None;opaque=[]}) in
  let plans=List.init 3(fun j->R.Plan {id=Printf.sprintf "p%d" (j+1);day="2000-01-03";measure="jpy";
    changes=["wallet",Z.of_int(-15);"food",Z.of_int 15];paid_by=None;cancelled_on=None;opaque=[]}) in
  get(B.of_records {header;frames=List.mapi(fun i p->R.encode_frame(i+1)p)(entries@plans)})
let replace_sections book replacement =
  let nodes=List.map(function X.List(X.Atom tag::_) as node -> (match List.assoc_opt tag replacement with Some n->n|None->node)|n->n)(many(B.to_string book)) in
  get(B.of_string(String.concat "\n" (List.map sx nodes)))
let support book =
  let roots=List.map(fun(e:B.entry)->atom e.id)(B.entries book) in
  let obs=X.List[atom "observation";X.List(atom "reflected"::roots);X.List(atom "quantities"::List.map(fun m->X.List[atom "wallet";atom m;atom "1100"])currencies)] in
  let old=List.find(function X.List(X.Atom "support"::_)->true|_->false)(many(B.to_string book)) in
  let revised=match old with X.List(tag::fields)->X.List(tag::List.map(function X.List(X.Atom "observations"::_)->X.List[atom "observations";obs]|n->n)fields)|_->failwith "support-shape" in
  replace_sections book ["support",revised]
let change book op = match op with
  | "record" -> get(B.put_entry book ~replace:false (entry 21) ~plan:None)
  | "correct" -> let e=Option.get(B.find_entry book "e02") in
      get(B.put_entry book ~replace:true {e with day="1999-12-31";effects=[posting "usd" "wallet" "e02-src" (Z.of_int(-60));posting "usd" "food" "e02-dst" (Z.of_int 40);posting "usd" "fees" "e02-fees" (Z.of_int 20)]} ~plan:None)
  | "pay" -> let e=entry 22 in get(B.put_entry book ~replace:false {e with effects=[posting "jpy" "wallet" "e22-src" (Z.of_int(-15));posting "jpy" "food" "e22-dst" (Z.of_int 15)]} ~plan:(Some "p1"))
  | "replace-plan" -> let p=List.find(fun(p:B.plan)->p.id="p2")(B.plans book) in get(B.put_plan book ~replace:true {p with day="2000-02-01"})
  | "cancel-plan" -> get(B.cancel_plan book ~id:"p3" ~day:"2000-01-04")
  | "support" -> support book
  | "unbalanced" -> let e=entry 23 in get(B.put_entry book ~replace:false {e with effects=[List.hd e.effects]} ~plan:None)
  | "duplicate" -> get(B.put_entry book ~replace:false (entry 1) ~plan:None)
  | _ -> failwith "unknown-operation"
let source_events book =
  let events=List.map(fun(e:B.entry)->get(D.Event.create ~id:(ident(D.Identifier.Event.of_string e.id)) ~effects:e.effects))(B.entries book) in
  get(D.Event_memory.of_events events)
let check_reference basis =
  let fact : A.Open_relations.fact={id=ident(D.Identifier.Relation.of_string "basis-relation");source_event=ident(D.Identifier.Event.of_string "e02");
    source_effect=ident(D.Identifier.Effect_key.of_string "e02-src");debtor=A.Open_relations.Household;
    creditor=A.Open_relations.External(ident(D.Identifier.External_party.of_string "synthetic-party"));quantity=D.Quantity.of_quanta(Z.of_int 80)} in
  ignore(get(A.Open_relations.create ~events:(source_events basis) ~facts:[fact]))
let check book op =
  require(Result.is_error(Q.query(B.image book)(coordinate "bank" "jpy"))) "unknown-became-zero";
  (match op with
   | "correct" -> let e=Option.get(B.find_entry book "e02") in require(e.day="1999-12-31" && List.length e.effects=3) "correction-not-whole"
   | "pay" -> let p=List.find(fun(p:B.plan)->p.id="p1")(B.plans book) in require(p.paid_by=Some "e22" && B.mem_entry book "e22") "partial-payment"
   | "support" -> List.iter(fun m->match Q.query(B.image book)(coordinate "wallet" m) with Ok(Q.Exact n)->require(Z.equal(D.Quantity.quanta(Q.quantity n))(Z.of_int 1100)) "partial-cut-or-quantity"|_->failwith "support-unknown")currencies
   | _ -> ());
  require(B.to_string(get(B.of_string(B.to_string book)))=B.to_string book) "canonical-unstable"
type t={book:string;basis:string;extras:(string*string option)list;parent:string;operation:string}
let fixture () = let b=initial() in check b "initial";check_reference b;
  {book=B.to_string b;basis=B.to_string b;parent="none";operation="initial";
   extras=["config/daily-pace.tsv",Some "wallet\tjpy\n";"config/boundary-presets.tsv",Some "cycle\t2000-01-01\t2000-02-01\n";
    "config/empty",Some "";"config/absent",None;"unknown/opaque",Some "FUTURE\000\255合成\n"]}
let opt = function None->X.List[atom "absent"]|Some s->X.List[atom "present";atom s]
let data x=X.List[atom "data";X.List[atom "book";atom x.book];X.List[atom "fixed-basis";atom x.basis];
  X.List[atom "fixed-reference";atom "e02";atom "e02-src";atom "80"];
  X.List(atom "external"::List.map(fun(n,v)->X.List[atom n;opt v])x.extras)]
let archive ~head x = let payload=sx(data x) in sx(X.List[atom "irmin-trial-archive";atom "1";
  X.List[atom "publication";atom head;atom x.parent;atom x.operation;atom(sha payload)];data x])^"\n"
let of_archive text = match parse text with
  | X.List[X.Atom "irmin-trial-archive";X.Atom "1";X.List[X.Atom "publication";X.Atom head;X.Atom parent;X.Atom operation;X.Atom digest];
      (X.List[X.Atom "data";X.List[X.Atom "book";X.Atom book];X.List[X.Atom "fixed-basis";X.Atom basis];
        X.List[X.Atom "fixed-reference";X.Atom "e02";X.Atom "e02-src";X.Atom "80"];X.List(X.Atom "external"::raw)] as payload)] ->
      require(sha(sx payload)=digest) "archive-checksum";
      let extras=List.map(function X.List[X.Atom n;X.List[X.Atom "absent"]]->n,None|X.List[X.Atom n;X.List[X.Atom "present";X.Atom s]]->n,Some s|_->failwith "archive-external-shape")raw in
      let x={book;basis;extras;parent;operation} in
      require(List.length(List.sort_uniq String.compare(List.map fst extras))=List.length extras) "archive-duplicate-file";
      let b=get(B.of_string book) and old=get(B.of_string basis) in check b operation;check_reference old;
      require(B.to_string b=book && B.to_string old=basis) "noncanonical-archive";
      head,x
  | _ -> failwith "unsupported-or-incomplete-archive"
let verify_complete x =
  let baseline=fixture() in require(x.extras=baseline.extras && x.basis=baseline.basis) "external-or-basis-drift";
  check (get(B.of_string x.book)) x.operation;
  let after=change(get(B.of_string x.book)) "support" in check after "support";
  (if B.mem_entry(get(B.of_string x.book)) "e22" then
     require(Result.is_error(B.put_entry(get(B.of_string x.book)) ~replace:false (entry 23) ~plan:(Some "p1"))) "double-payment-admitted")
(* Deterministic split into per-entry/per-plan cells; only changed cells are written. *)
let encode_path p=sx(X.List(List.map atom p))
let cells x =
  let count=ref 0 in
  let domain=List.concat_map(fun node->incr count;
    let prefix=["domain";Printf.sprintf "%03d" !count] in
    match node with
    | X.List(X.Atom tag::items) when tag="entries" || tag="plans" ->
        (prefix@["kind"],sx(atom tag))::(prefix@["count"],string_of_int(List.length items))::List.mapi(fun i item->prefix@[Printf.sprintf "%08d" i],sx item)items
    | _ -> [prefix@["kind"],"section";prefix@["body"],sx node]) (many x.book) in
  domain @ [["sections"],string_of_int !count;["basis"],x.basis;["external"],sx(X.List(List.map(fun(n,v)->X.List[atom n;opt v])x.extras));
    ["publication"],sx(X.List[atom x.parent;atom x.operation])]
let from_cells find =
  let n=int_of_string(find["sections"]) in require(n=8) "unexpected-section-scope";
  let nodes=List.init n(fun i->let p=["domain";Printf.sprintf "%03d" (i+1)] in
    match find(p@["kind"]) with
    | "section" -> parse(find(p@["body"]))
    | kind -> let tag=match parse kind with X.Atom s when s="entries" || s="plans"->s|_->failwith "cell-kind" in
        let count=int_of_string(find(p@["count"])) in require(count>=0 && count<=100) "trial-count-bound";
        X.List(atom tag::List.init count(fun j->parse(find(p@[Printf.sprintf "%08d" j]))))) in
  let book=B.to_string(get(B.of_string(String.concat "\n"(List.map sx nodes)))) in
  let external_node=parse(find["external"]) in
  let extras=match external_node with X.List nodes->List.map(function X.List[X.Atom n;X.List[X.Atom "absent"]]->n,None|X.List[X.Atom n;X.List[X.Atom "present";X.Atom s]]->n,Some s|_->failwith "external-shape")nodes|_->failwith "external-shape" in
  let parent,operation=match parse(find["publication"])with X.List[X.Atom p;X.Atom op]->p,op|_->failwith "publication-shape" in
  let x={book;basis=find["basis"];extras;parent;operation} in verify_complete x;x
