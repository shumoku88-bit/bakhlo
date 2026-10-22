(* Every migrated screen owner, registered once: its private state lives in [t]
   and the Shell reaches it only through the contract functions in [all].
   Adding a screen means one field here and one entry in [all]. *)
module W = Ui_workspace

type t = {
  pace : Daily_pace_screen.t;
  balances : Balances_screen.t;
  income_expense : Income_expense_screen.t;
  transactions_flow : Transactions_flow_screen.t;
  stock_flow : Stock_flow_screen.t;
  liquidity : Liquidity_screen.t;
  trend_locus : Trend_locus_screen.t;
  multicurrency_spend : Multicurrency_spend_screen.t;
  attention : Attention_screen.t;
  settlements : Settlements_screen.t;
  loci : Loci_screen.t;
  observe : Observe_screen.t;
  exchange : Exchange_screen.t;
  editors : Record_editors.t;
  actual : Actual_screen.t;
  scheduled : Scheduled_screen.t;
  day : Selected_day_screen.t;
  home : Home_screen.t;
}

let create ~scheduled_months =
  {
    pace = Daily_pace_screen.create ();
    balances = Balances_screen.create ();
    income_expense = Income_expense_screen.create ();
    transactions_flow = Transactions_flow_screen.create ();
    stock_flow = Stock_flow_screen.create ();
    liquidity = Liquidity_screen.create ();
    trend_locus = Trend_locus_screen.create ();
    multicurrency_spend = Multicurrency_spend_screen.create ();
    attention = Attention_screen.create ();
    settlements = Settlements_screen.create ();
    loci = Loci_screen.create ();
    observe = Observe_screen.create ();
    exchange = Exchange_screen.create ();
    editors = Record_editors.create ();
    actual = Actual_screen.create ();
    scheduled = Scheduled_screen.create scheduled_months;
    day = Selected_day_screen.create ();
    home = Home_screen.create ();
  }

type 'a owner = {
  layout : Screen.layout;
  owns : W.route -> bool; (* false for an editor that opens over any route *)
  config_files : string list;
  get : t -> 'a;
  set : t -> 'a -> t;
  enter : W.route -> focus_day:string -> 'a -> 'a; (* the Shell's focus day *)
  modal : 'a -> bool;
  handle : Screen.env -> Screen.geometry -> 'a -> Ui_input.input -> 'a * Screen.request;
  view : Screen.env -> Screen.geometry -> 'a -> Screen.view;
  saved : Screen.env -> Screen.geometry -> (unit, string) result -> 'a -> 'a * Screen.request;
  published : Screen.env -> Screen.geometry -> Screen.publish_outcome -> 'a -> 'a * Screen.request;
  reloaded : Screen.env -> 'a -> 'a * Screen.request;
  book_changed :
    before:Bakhlo_sexp.Daily_book.t -> after:Bakhlo_sexp.Daily_book.t -> 'a -> 'a * string;
      (* after a publication or a drill return; the string is a notice *)
}

type owner_ref = Owner : 'a owner -> owner_ref

let no_save _env _geometry _result t = (t, Screen.Stay)
let no_change ~before:_ ~after:_ t = (t, "")

let all =
  [
    Owner
      {
        layout = Screen.Workspace;
        owns = ( = ) W.Daily_pace;
        config_files = Daily_pace_screen.config_files;
        get = (fun t -> t.pace);
        set = (fun t pace -> { t with pace });
        enter = (fun _ ~focus_day:_ t -> Daily_pace_screen.enter t);
        modal = Daily_pace_screen.modal;
        handle = Daily_pace_screen.handle;
        view = Daily_pace_screen.view;
        saved = Daily_pace_screen.saved;
        published = Screen.no_publication;
        reloaded = Screen.no_reload;
        book_changed = no_change;
      };
    Owner
      {
        layout = Screen.Standard;
        owns = ( = ) W.Balances;
        config_files = Balances_screen.config_files;
        get = (fun t -> t.balances);
        set = (fun t balances -> { t with balances });
        enter = (fun _ ~focus_day:_ t -> t);
        modal = Balances_screen.modal;
        handle = Balances_screen.handle;
        view = Balances_screen.view;
        saved = Balances_screen.saved;
        published = Screen.no_publication;
        reloaded = Screen.no_reload;
        book_changed = no_change;
      };
    Owner
      {
        layout = Screen.Standard;
        owns = ( = ) W.Income_expense;
        config_files = Income_expense_screen.config_files;
        get = (fun t -> t.income_expense);
        set = (fun t income_expense -> { t with income_expense });
        enter = (fun _ ~focus_day:_ t -> Income_expense_screen.enter t);
        modal = Income_expense_screen.modal;
        handle = Income_expense_screen.handle;
        view = Income_expense_screen.view;
        saved = Income_expense_screen.saved;
        published = Screen.no_publication;
        reloaded = Screen.no_reload;
        book_changed = no_change;
      };
    Owner
      {
        layout = Screen.Standard;
        owns = ( = ) W.Transactions_flow;
        config_files = Transactions_flow_screen.config_files;
        get = (fun t -> t.transactions_flow);
        set = (fun t transactions_flow -> { t with transactions_flow });
        enter = (fun _ ~focus_day:_ t -> Transactions_flow_screen.enter t);
        modal = Transactions_flow_screen.modal;
        handle = Transactions_flow_screen.handle;
        view = Transactions_flow_screen.view;
        saved = Transactions_flow_screen.saved;
        published = Screen.no_publication;
        reloaded = Screen.no_reload;
        book_changed = no_change;
      };
    Owner
      {
        layout = Screen.Standard;
        owns = ( = ) W.Stock_flow;
        config_files = Stock_flow_screen.config_files;
        get = (fun t -> t.stock_flow);
        set = (fun t stock_flow -> { t with stock_flow });
        enter = (fun _ ~focus_day:_ t -> Stock_flow_screen.enter t);
        modal = Stock_flow_screen.modal;
        handle = Stock_flow_screen.handle;
        view = Stock_flow_screen.view;
        saved = Stock_flow_screen.saved;
        published = Screen.no_publication;
        reloaded = Screen.no_reload;
        book_changed = no_change;
      };
    Owner
      {
        layout = Screen.Workspace;
        owns = ( = ) W.Trend_locus;
        config_files = Trend_locus_screen.config_files;
        get = (fun t -> t.trend_locus);
        set = (fun t trend_locus -> { t with trend_locus });
        enter = (fun _ ~focus_day t -> Trend_locus_screen.enter ~focus_day t);
        modal = Trend_locus_screen.modal;
        handle = Trend_locus_screen.handle;
        view = Trend_locus_screen.view;
        saved = Trend_locus_screen.saved;
        published = Screen.no_publication;
        reloaded = Screen.no_reload;
        book_changed = no_change;
      };
    Owner
      {
        layout = Screen.Standard;
        owns = ( = ) W.Liquidity;
        config_files = Liquidity_screen.config_files;
        get = (fun t -> t.liquidity);
        set = (fun t liquidity -> { t with liquidity });
        enter = (fun _ ~focus_day t -> Liquidity_screen.enter ~focus_day t);
        modal = Liquidity_screen.modal;
        handle = Liquidity_screen.handle;
        view = Liquidity_screen.view;
        saved = Liquidity_screen.saved;
        published = Screen.no_publication;
        reloaded = Liquidity_screen.reloaded;
        book_changed = Liquidity_screen.book_changed;
      };
    Owner
      {
        layout = Screen.Standard;
        owns = ( = ) W.Multicurrency_spend;
        config_files = Multicurrency_spend_screen.config_files;
        get = (fun t -> t.multicurrency_spend);
        set = (fun t multicurrency_spend -> { t with multicurrency_spend });
        enter = (fun _ ~focus_day t -> Multicurrency_spend_screen.resume ~focus_day t);
        modal = Multicurrency_spend_screen.modal;
        handle = Multicurrency_spend_screen.handle;
        view = Multicurrency_spend_screen.view;
        saved = Multicurrency_spend_screen.saved;
        published = Screen.no_publication;
        reloaded = Multicurrency_spend_screen.reloaded;
        book_changed = Multicurrency_spend_screen.book_changed;
      };
    Owner
      {
        layout = Screen.Standard;
        owns = ( = ) W.Attention;
        config_files = Attention_screen.config_files;
        get = (fun t -> t.attention);
        set = (fun t attention -> { t with attention });
        enter = (fun _ ~focus_day:_ t -> Attention_screen.enter t);
        modal = Attention_screen.modal;
        handle = Attention_screen.handle;
        view = Attention_screen.view;
        saved = Attention_screen.saved;
        published = Screen.no_publication;
        reloaded = Screen.no_reload;
        book_changed = no_change;
      };
    Owner
      {
        layout = Screen.Standard;
        owns = ( = ) W.Settlements;
        config_files = Settlements_screen.config_files;
        get = (fun t -> t.settlements);
        set = (fun t settlements -> { t with settlements });
        enter = (fun _ ~focus_day:_ t -> Settlements_screen.enter t);
        modal = Settlements_screen.modal;
        handle = Settlements_screen.handle;
        view = Settlements_screen.view;
        saved = Settlements_screen.saved;
        published = Screen.no_publication;
        reloaded = Screen.no_reload;
        book_changed = no_change;
      };
    Owner
      {
        layout = Screen.Standard;
        owns = ( = ) W.Loci;
        config_files = Loci_screen.config_files;
        get = (fun t -> t.loci);
        set = (fun t loci -> { t with loci });
        enter = (fun _ ~focus_day:_ t -> Loci_screen.enter t);
        modal = Loci_screen.modal;
        handle = Loci_screen.handle;
        view = Loci_screen.view;
        saved = Loci_screen.saved;
        published = Loci_screen.published;
        reloaded = Screen.no_reload;
        book_changed = no_change;
      };
    Owner
      {
        layout = Screen.Standard;
        owns = (fun _ -> false);
        config_files = Observe_screen.config_files;
        get = (fun t -> t.observe);
        set = (fun t observe -> { t with observe });
        enter = (fun _ ~focus_day:_ t -> t);
        modal = Observe_screen.modal;
        handle = Observe_screen.handle;
        view = Observe_screen.view;
        saved = no_save;
        published = Observe_screen.published;
        reloaded = Observe_screen.reloaded;
        book_changed = no_change;
      };
    Owner
      {
        layout = Screen.Standard;
        owns = (fun _ -> false);
        config_files = Exchange_screen.config_files;
        get = (fun t -> t.exchange);
        set = (fun t exchange -> { t with exchange });
        enter = (fun _ ~focus_day:_ t -> t);
        modal = Exchange_screen.modal;
        handle = Exchange_screen.handle;
        view = Exchange_screen.view;
        saved = no_save;
        published = Exchange_screen.published;
        reloaded = Screen.no_reload;
        book_changed = no_change;
      };
    Owner
      {
        layout = Screen.Standard;
        owns = (fun _ -> false);
        config_files = Record_editors.config_files;
        get = (fun t -> t.editors);
        set = (fun t editors -> { t with editors });
        enter = (fun _ ~focus_day:_ t -> t);
        modal = Record_editors.modal;
        handle = Record_editors.handle;
        view = Record_editors.view;
        saved = Record_editors.saved;
        published = Record_editors.published;
        reloaded = Record_editors.reloaded;
        book_changed = no_change;
      };
    Owner
      {
        layout = Screen.Workspace;
        owns = ( = ) W.Actual;
        config_files = Actual_screen.config_files;
        get = (fun t -> t.actual);
        set = (fun t actual -> { t with actual });
        enter = (fun _ ~focus_day t -> Actual_screen.enter ~focus_day t);
        modal = Actual_screen.modal;
        handle = Actual_screen.handle;
        view = Actual_screen.view;
        saved = Actual_screen.saved;
        published = Screen.no_publication;
        reloaded = Actual_screen.reloaded;
        book_changed = Actual_screen.book_changed;
      };
    Owner
      {
        layout = Screen.Standard;
        owns = ( = ) W.Scheduled;
        config_files = Scheduled_screen.config_files;
        get = (fun t -> t.scheduled);
        set = (fun t scheduled -> { t with scheduled });
        enter = (fun _ -> Scheduled_screen.enter);
        modal = Scheduled_screen.modal;
        handle = Scheduled_screen.handle;
        view = Scheduled_screen.view;
        saved = Scheduled_screen.saved;
        published = Screen.no_publication;
        reloaded = Scheduled_screen.reloaded;
        book_changed = Scheduled_screen.book_changed;
      };
    Owner
      {
        layout = Screen.Standard;
        owns = (function W.Selected_day _ -> true | _ -> false);
        config_files = Selected_day_screen.config_files;
        get = (fun t -> t.day);
        set = (fun t day -> { t with day });
        enter = Selected_day_screen.enter;
        modal = Selected_day_screen.modal;
        handle = Selected_day_screen.handle;
        view = Selected_day_screen.view;
        saved = Selected_day_screen.saved;
        published = Screen.no_publication;
        reloaded = Selected_day_screen.reloaded;
        book_changed = Selected_day_screen.book_changed;
      };
    Owner
      {
        layout = Screen.Standard;
        owns = ( = ) W.Home;
        config_files = [];
        get = (fun t -> t.home);
        set = (fun t home -> { t with home });
        enter = (fun _ ~focus_day:_ t -> t);
        modal = (fun _ -> false);
        handle = Home_screen.handle;
        view = Home_screen.view;
        saved = no_save;
        published = Screen.no_publication;
        reloaded = Screen.no_reload;
        book_changed = no_change;
      };
  ]

let for_route route = List.find_opt (fun (Owner o) -> o.owns route) all
let modal t = List.find_opt (fun (Owner o) -> o.modal (o.get t)) all

let enter route ~focus_day t =
  match for_route route with
  | Some (Owner o) -> o.set t (o.enter route ~focus_day (o.get t))
  | None -> t

(* Let the route's owner keep its place across a book change. *)
let book_changed route ~before ~after t =
  match for_route route with
  | Some (Owner o) ->
      let value, notice = o.book_changed ~before ~after (o.get t) in
      (o.set t value, notice)
  | None -> (t, "")

(* A finished publication closes every editor floating over the route. *)
let dismiss_floating t =
  {
    t with
    observe = Observe_screen.create ();
    exchange = Exchange_screen.create ();
    editors = Record_editors.create ();
  }
