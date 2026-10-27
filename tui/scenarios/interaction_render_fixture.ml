(* Synthetic controller integration checks; see docs/RECONSTRUCTION_TEST_MAP.ja.md. *)
open Interaction_check_fixture

let render_cases state =
  let home =
    { state with C.overlay = C.No_overlay; record = None; record_visible = false; message = "" }
  in
  let record = C.open_record home in
  let record =
    match record.record with
    | None -> record
    | Some draft ->
        {
          record with
          record =
            Some
              (S.with_notice draft
                 "Record notice: long text remains separate from household feedback.");
        }
  in
  let review = prepare_record ~width_of:String.length home |> C.submit in
  let entry =
    get
      (Result.map_error
         (fun error -> error.Daily_actions.message)
         (Daily_actions.build_transaction ~book:home.session.book ~mode:Daily_actions.New
            (Daily_actions.Multiple
               {
                 day = home.workspace.focus_day;
                 memo = "Synthetic / 日本語";
                 draft =
                   {
                     Posting_draft.measure = "jpy";
                     rows =
                       [
                         {
                           Posting_draft.key = None;
                           locus = "wallet";
                           negative = true;
                           amount = String.make 70 '9';
                         };
                         {
                           Posting_draft.key = None;
                           locus = "food";
                           negative = false;
                           amount = String.make 70 '9';
                         };
                       ];
                   };
                 original_amount = None;
               })))
  in
  let book = get (B.put_entry home.session.book ~replace:false entry.entry ~plan:None) in
  let rich = { home with session = load_synthetic_book book } in
  let reversal = key (C.open_route rich W.Actual) (`ASCII 'x') in
  let reversal_preview = key reversal `Enter in
  let date = key (C.open_route rich W.Actual) (`ASCII 'd') in
  let date_preview = key date `Enter in
  let cancellation = key (C.open_route rich W.Scheduled) (`ASCII 'x') in
  let cancellation_preview = key cancellation `Enter in
  let source = List.hd (B.plans book) in
  let continuation_none =
    with_session rich
      (E.Scheduled_continuation (Cont.create ~book ~base_revision:rich.session.revision source))
  in
  let later = { source with id = "render-later"; day = get (Cal.shift_months source.day 1) } in
  let continuation_book = get (B.put_plan book ~replace:false later) in
  let continuation =
    with_session rich
      (E.Scheduled_continuation
         (Cont.create ~book:continuation_book ~base_revision:rich.session.revision source))
  in
  let continuation_review = key (key (key continuation `Tab) `Tab) `Enter in
  let bulk =
    with_session rich
      (E.Scheduled_bulk
         (get (Bulk.create ~book ~base_revision:rich.session.revision ~from_day:source.day source)))
  in
  let bulk_selection =
    String.fold_left (fun state c -> key state (`ASCII c)) bulk "321" |> fun state ->
    key state `Enter
  in
  let bulk_preview = key (key bulk_selection (`ASCII 'a')) `Enter in
  let generate =
    with_session rich
      (E.Scheduled_generate (get (Gen.create ~book ~base_revision:rich.session.revision ~source ())))
  in
  let generate_preview = key generate `Enter in
  let detail route =
    let view = C.open_route rich route in
    match route with
    | W.Selected_day _ | W.Actual | W.Scheduled | W.Income_expense | W.Transactions_flow
    | W.Stock_flow ->
        key view (`ASCII 'i') (* the owner's own detail key *)
    | _ -> key view `Tab
  in
  let let_search state = key state (`ASCII '/') |> fun s -> text ~width_of:String.length s "財布" in
  [
    home;
    C.open_route home W.Actual;
    C.open_route home W.Scheduled;
    key (C.open_route rich W.Scheduled) (`ASCII 'v');
    C.open_route home W.Balances;
    C.open_route home W.Daily_pace;
    C.open_plan_record home;
    {
      home with
      overlay =
        C.Modal_form
          (Ui_form.create ~id:"render" ~title:"Synthetic form"
             ~fields:
               [
                 Ui_form.text_field ~id:"memo" ~label:"Memo"
                   ~value:"Long input / 日本語 / abcdefghijklmnopqrstuvwxyz0123456789" ();
                 Ui_form.action_buttons ();
               ]
             ());
    };
    record;
    review;
    C.request_discard { review with record_visible = false };
    reversal;
    reversal_preview;
    date;
    date_preview;
    cancellation;
    cancellation_preview;
    continuation_none;
    continuation;
    continuation_review;
    bulk;
    bulk_selection;
    bulk_preview;
    generate;
    detail W.Income_expense;
    C.open_route home W.Income_expense;
    detail W.Transactions_flow;
    C.open_route home W.Transactions_flow;
    detail W.Stock_flow;
    C.open_route home W.Stock_flow;
    generate_preview;
    detail (W.Selected_day home.workspace.focus_day);
    detail W.Actual;
    detail W.Scheduled;
    detail W.Balances;
    { home with overlay = C.Commands M.initial };
    { home with overlay = C.Commands { M.page = M.Analysis; selected = 1 } };
    {
      home with
      overlay = C.Themes { selected = 0; original = home.theme; return_menu = M.initial };
    };
    let_search (C.open_route home W.Actual);
  ]
