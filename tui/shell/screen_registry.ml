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
  attention : Attention_screen.t;
  settlements : Settlements_screen.t;
  loci : Loci_screen.t;
  observe : Observe_screen.t;
  exchange : Exchange_screen.t;
  editors : Record_editors.t;
}

let create () =
  {
    pace = Daily_pace_screen.create ();
    balances = Balances_screen.create ();
    income_expense = Income_expense_screen.create ();
    transactions_flow = Transactions_flow_screen.create ();
    stock_flow = Stock_flow_screen.create ();
    attention = Attention_screen.create ();
    settlements = Settlements_screen.create ();
    loci = Loci_screen.create ();
    observe = Observe_screen.create ();
    exchange = Exchange_screen.create ();
    editors = Record_editors.create ();
  }

type 'a owner = {
  route : W.route option;  (* None: an editor that opens over any route *)
  config_files : string list;
  get : t -> 'a;
  set : t -> 'a -> t;
  enter : 'a -> 'a;
  modal : 'a -> bool;
  handle : Screen.env -> Screen.geometry -> 'a -> Ui_input.input -> 'a * Screen.request;
  view : Screen.env -> Screen.geometry -> 'a -> Screen.view;
  saved : Screen.env -> Screen.geometry -> (unit, string) result -> 'a -> 'a * Screen.request;
  published : Screen.env -> Screen.geometry -> Screen.publish_outcome -> 'a -> 'a * Screen.request;
  reloaded : Screen.env -> 'a -> 'a * Screen.request;
}

type owner_ref = Owner : 'a owner -> owner_ref

let no_save _env _geometry _result t = (t, Screen.Stay)

let all =
  [
    Owner
      {
        route = Some W.Daily_pace;
        config_files = Daily_pace_screen.config_files;
        get = (fun t -> t.pace);
        set = (fun t pace -> { t with pace });
        enter = Daily_pace_screen.enter;
        modal = Daily_pace_screen.modal;
        handle = Daily_pace_screen.handle;
        view = Daily_pace_screen.view;
        saved = Daily_pace_screen.saved;
        published = Screen.no_publication;
        reloaded = Screen.no_reload;
      };
    Owner
      {
        route = Some W.Balances;
        config_files = Balances_screen.config_files;
        get = (fun t -> t.balances);
        set = (fun t balances -> { t with balances });
        enter = Fun.id;
        modal = Balances_screen.modal;
        handle = Balances_screen.handle;
        view = Balances_screen.view;
        saved = Balances_screen.saved;
        published = Screen.no_publication;
        reloaded = Screen.no_reload;
      };
    Owner
      {
        route = Some W.Income_expense;
        config_files = Income_expense_screen.config_files;
        get = (fun t -> t.income_expense);
        set = (fun t income_expense -> { t with income_expense });
        enter = Income_expense_screen.enter;
        modal = Income_expense_screen.modal;
        handle = Income_expense_screen.handle;
        view = Income_expense_screen.view;
        saved = Income_expense_screen.saved;
        published = Screen.no_publication;
        reloaded = Screen.no_reload;
      };
    Owner
      {
        route = Some W.Transactions_flow;
        config_files = Transactions_flow_screen.config_files;
        get = (fun t -> t.transactions_flow);
        set = (fun t transactions_flow -> { t with transactions_flow });
        enter = Transactions_flow_screen.enter;
        modal = Transactions_flow_screen.modal;
        handle = Transactions_flow_screen.handle;
        view = Transactions_flow_screen.view;
        saved = Transactions_flow_screen.saved;
        published = Screen.no_publication;
        reloaded = Screen.no_reload;
      };
    Owner
      {
        route = Some W.Stock_flow;
        config_files = Stock_flow_screen.config_files;
        get = (fun t -> t.stock_flow);
        set = (fun t stock_flow -> { t with stock_flow });
        enter = Stock_flow_screen.enter;
        modal = Stock_flow_screen.modal;
        handle = Stock_flow_screen.handle;
        view = Stock_flow_screen.view;
        saved = Stock_flow_screen.saved;
        published = Screen.no_publication;
        reloaded = Screen.no_reload;
      };
    Owner
      {
        route = Some W.Attention;
        config_files = Attention_screen.config_files;
        get = (fun t -> t.attention);
        set = (fun t attention -> { t with attention });
        enter = Attention_screen.enter;
        modal = Attention_screen.modal;
        handle = Attention_screen.handle;
        view = Attention_screen.view;
        saved = Attention_screen.saved;
        published = Screen.no_publication;
        reloaded = Screen.no_reload;
      };
    Owner
      {
        route = Some W.Settlements;
        config_files = Settlements_screen.config_files;
        get = (fun t -> t.settlements);
        set = (fun t settlements -> { t with settlements });
        enter = Settlements_screen.enter;
        modal = Settlements_screen.modal;
        handle = Settlements_screen.handle;
        view = Settlements_screen.view;
        saved = Settlements_screen.saved;
        published = Screen.no_publication;
        reloaded = Screen.no_reload;
      };
    Owner
      {
        route = Some W.Loci;
        config_files = Loci_screen.config_files;
        get = (fun t -> t.loci);
        set = (fun t loci -> { t with loci });
        enter = Loci_screen.enter;
        modal = Loci_screen.modal;
        handle = Loci_screen.handle;
        view = Loci_screen.view;
        saved = Loci_screen.saved;
        published = Loci_screen.published;
        reloaded = Screen.no_reload;
      };
    Owner
      {
        route = None;
        config_files = Observe_screen.config_files;
        get = (fun t -> t.observe);
        set = (fun t observe -> { t with observe });
        enter = Fun.id;
        modal = Observe_screen.modal;
        handle = Observe_screen.handle;
        view = Observe_screen.view;
        saved = no_save;
        published = Observe_screen.published;
        reloaded = Observe_screen.reloaded;
      };
    Owner
      {
        route = None;
        config_files = Exchange_screen.config_files;
        get = (fun t -> t.exchange);
        set = (fun t exchange -> { t with exchange });
        enter = Fun.id;
        modal = Exchange_screen.modal;
        handle = Exchange_screen.handle;
        view = Exchange_screen.view;
        saved = no_save;
        published = Exchange_screen.published;
        reloaded = Screen.no_reload;
      };
    Owner
      {
        route = None;
        config_files = Record_editors.config_files;
        get = (fun t -> t.editors);
        set = (fun t editors -> { t with editors });
        enter = Fun.id;
        modal = Record_editors.modal;
        handle = Record_editors.handle;
        view = Record_editors.view;
        saved = Record_editors.saved;
        published = Record_editors.published;
        reloaded = Record_editors.reloaded;
      };
  ]

let for_route route = List.find_opt (fun (Owner o) -> o.route = Some route) all
let modal t = List.find_opt (fun (Owner o) -> o.modal (o.get t)) all

let enter route t =
  match for_route route with Some (Owner o) -> o.set t (o.enter (o.get t)) | None -> t

(* A finished publication closes every editor floating over the route. *)
let dismiss_floating t =
  { t with observe = Observe_screen.create (); exchange = Exchange_screen.create ();
           editors = Record_editors.create () }
