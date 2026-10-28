(* Quick capture checks, the cases of LOAM TuiRecord.checkQuickCapture on a
   synthetic book. Pure: nothing is written or published. *)
module B = Bakhlo_household.Book
module O = Ui_render
module Q = Quick_capture

let require condition cause = if not condition then failwith cause
let get = function Ok x -> x | Error why -> failwith why
let id = function Ok x -> x | Error _ -> failwith "synthetic-identifier"

let fixture =
  "BOOK\t1\n\
   MEASURE\tjpy\t0\n\
   MEASURE\tusd\t2\n\
   LOCUS\tfood\t食費\tSynthetic\n\
   LOCUS\tdrinks\t飲み物\tSynthetic\n\
   LOCUS\twallet\t財布\tSynthetic\n\
   LOCUS\tcard\tカード\tSynthetic\n\
   LOCUS\tsynthpay\tSynthPay\tSynthetic\n\
   LOCUS\tbooks\t本\tSynthetic\n\
   LOCUS\tsynthnet\tsynthnet\t\n\
   LOCUS\tsynthbank\tsynthbank\t\n\
   END\n"

let make_effect measure (locus, quanta) = { B.key = None; locus; measure; amount = Z.of_int quanta }

let entry ?(measure = "jpy") ?reversal_of id day memo postings : B.entry =
  {
    id;
    day;
    memo = Some memo;
    effects = List.map (make_effect measure) postings;
    reversal_of;
    exchange = None;
    original_amount = None;
    merchant = None;
  }

let self_check ~width_of () =
  let bakery = [ ("food", 300); ("drinks", 120); ("wallet", -420) ] in
  let book =
    List.fold_left
      (fun book e -> get (B.put_entry book ~replace:false e ~plan:None))
      (get (B.read fixture))
      [
        entry "q1" "2026-10-01" "本屋" [ ("books", 1200); ("synthpay", -1200) ];
        entry "q2" "2026-10-02" "パン屋" bakery;
        entry "q3" "2026-10-03" "パン屋" bakery;
        entry "q4" "2026-10-06" "パン屋" [ ("drinks", 120); ("wallet", -120) ];
        entry "q5" "2026-10-04" "パン屋" bakery;
        entry ~measure:"usd" "q6" "2026-10-07" "外貨" [ ("books", 500); ("synthpay", -500) ];
        entry "q7" "2026-10-08" "消えた" [ ("books", 9); ("synthpay", -9) ];
        entry ~reversal_of:"q7" "q8" "2026-10-09" "消えた" [ ("books", -9); ("synthpay", 9) ];
      ]
  in
  let roles =
    [
      ("food", Locus_roles.Expense);
      ("drinks", Locus_roles.Expense);
      ("books", Locus_roles.Expense);
      ("wallet", Locus_roles.Asset);
      ("card", Locus_roles.Liability);
      ("synthpay", Locus_roles.Asset);
    ]
  in
  let start = Q.initial ~book ~day:"2026-10-19" ~measure:"jpy" ~roles in
  let typed text = Q.append start text in
  let press t input = Q.update ~book t input in
  let enter t = press t (`Key (`Enter, [])) in
  let screen ?(dimensions = (80, 24)) t =
    Q.view ~book ~width_of ~width:(fst dimensions) ~height:(snd dimensions) t
  in
  let painted t = String.concat "\n" (List.map snd (screen t)) in
  let preview t =
    match enter t with Q.Preview p -> p | _ -> failwith ("quick-not-previewed: " ^ Q.text t)
  in
  let edit t =
    match enter t with Q.Edit p -> p | _ -> failwith ("quick-not-edited: " ^ Q.text t)
  in
  (* Descriptions complete by prefix, then substring; other Measures and reversed
     records are not learned. *)
  let lines_with t needle =
    List.filter (fun (_, row) -> Base.String.is_substring row ~substring:needle) (screen t)
  in
  require
    (lines_with (typed "パ") "パン屋" <> [] && lines_with (typed "パ") "本屋" = [])
    "quick-prefix-suggestion";
  let both = painted (typed "屋") in
  require
    (Base.String.is_substring both ~substring:"パン屋"
    && Base.String.is_substring both ~substring:"本屋"
    && Base.String.substr_index both ~pattern:"パン屋" < Base.String.substr_index both ~pattern:"本屋")
    "quick-substring-suggestions-after-prefix";
  require
    (Base.String.is_substring (painted (typed "消")) ~substring:"New description"
    && Base.String.is_substring (painted (typed "外")) ~substring:"New description")
    "quick-ignores-reversed-and-other-measure-records";
  let completed =
    match enter (typed "パ") with Q.Stay t -> t | _ -> failwith "quick-description-enter"
  in
  require (Q.text completed = "パン屋 ") "quick-enter-completes-description";
  (* The template used most among the latest ten replays exactly. *)
  let usual = preview completed in
  require
    (usual.description = "パン屋" && usual.day = "2026-10-19"
    && usual.rows = [ ("drinks", "120"); ("food", "300"); ("wallet", "-420") ])
    "quick-replays-usual-split";
  require
    ((preview (typed "パン屋 450 食費 300")).rows
    = [ ("drinks", "150"); ("food", "300"); ("wallet", "-450") ])
    "quick-named-part-gives-rest-to-other-part";
  require
    ((preview (typed "パン屋 card")).rows = [ ("drinks", "120"); ("food", "300"); ("card", "-420") ])
    "quick-named-payer-replaces-template-payer";
  require
    ((preview (typed "パン屋 120")).rows = [ ("drinks", "120"); ("wallet", "-120") ])
    "quick-total-prefers-matching-template";
  let open_split = edit (typed "パン屋 700") in
  require
    (open_split.rows = [ ("drinks", ""); ("food", ""); ("wallet", "-700") ] && open_split.focus = 4)
    "quick-undetermined-split-opens-form-at-first-missing-amount";
  ignore (edit (typed "パン屋 420 nosuch"));
  require
    (Base.String.is_substring
       (painted (typed "パン屋 420 nosuch"))
       ~substring:"Not understood: nosuch")
    "quick-unknown-locus-word-is-not-ignored";
  require
    ((preview (typed "ラーメン 900 本 synthpay")).rows = [ ("books", "900"); ("synthpay", "-900") ])
    "quick-new-description-takes-loci-from-line";
  let unroled = Q.append (Q.with_roles [] start) "新規 10 synthnet synthbank" in
  require
    ((preview unroled).rows = [ ("synthnet", "10"); ("synthbank", "-10") ])
    "quick-roleless-loci-fill-receiving-then-paying";
  (* Dated today (here Record's day) unless a leading date word names another day. *)
  let day_of text =
    match press (typed text) (`Key (`Tab, [])) with Q.Edit p -> p.day | _ -> failwith "quick-tab"
  in
  require
    (day_of "パン屋" = "2026-10-19"
    && day_of "10-18 パン屋" = "2026-10-18"
    && day_of "2025-12-31 パン屋" = "2025-12-31"
    && day_of "12/31 パン屋" = "2025-12-31"
    && day_of "10-18" = "2026-10-19")
    "quick-leading-date-word";
  let earlier =
    match enter (typed "10-18 パ") with Q.Stay t -> t | _ -> failwith "quick-dated-description"
  in
  require
    (Q.text earlier = "10-18 パン屋 " && (preview earlier).day = "2026-10-18")
    "quick-dated-template";
  require ((edit (typed "10-32 本屋 900")).day = "10-32") "quick-unreal-date-left-for-record";
  require
    ((match press completed (`Key (`Tab, [])) with Q.Edit _ -> true | _ -> false)
    && match press completed (`Key (`Escape, [])) with Q.Cancel -> true | _ -> false)
    "quick-tab-opens-form-and-esc-cancels";
  List.iter
    (fun ((width, height) as dimensions) ->
      List.iter
        (fun t ->
          let rows = screen ~dimensions t in
          require
            (List.length rows <= height
            && List.for_all (fun (_, row) -> width_of row <= width) rows
            && List.length
                 (List.filter
                    (fun (style, _) -> match style with O.Input _ -> true | _ -> false)
                    rows)
               = 1)
            "quick-view-bounded-with-one-caret")
        [ start; typed "パ"; completed; typed "パン屋 700 nosuch"; typed "2025-12-31 パン屋 " ])
    [ (32, 9); (48, 14); (80, 24) ];
  (* LOAM quick capture geometry: a bounded framed modal, or the whole area. *)
  let surface = Q.surface in
  let framed = surface (80, 24) in
  require
    (framed.framed && framed.width = 75 && framed.height = 14 && framed.top = 4 && framed.left = 2)
    "quick-surface-is-a-bounded-framed-modal-at-80x24";
  let wide = surface (120, 36) in
  require
    (wide.framed && wide.width = 80 && wide.height = 14 && wide.top = 10 && wide.left = 19)
    "quick-surface-keeps-the-loam-width-bound-at-120x36";
  require
    ((not (surface (48, 14)).framed) && (surface (48, 14)).width = 48
   && (not (surface (32, 9)).framed) && (surface (32, 9)).width = 32)
    "quick-surface-is-unframed-on-a-small-terminal";
  print_endline
    "PASS: Quick capture suggests past descriptions, replays the usual template, takes totals, \
     parts, payer and date words, and hands Record a complete or open form (LOAM cases)."
