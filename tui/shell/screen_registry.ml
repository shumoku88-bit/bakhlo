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
  }

type 'a owner = {
  route : W.route;
  config_files : string list;
  get : t -> 'a;
  set : t -> 'a -> t;
  enter : 'a -> 'a;
  modal : 'a -> bool;
  handle : Screen.env -> Screen.geometry -> 'a -> Ui_input.input -> 'a * Screen.request;
  view : Screen.env -> Screen.geometry -> 'a -> Screen.view;
  saved : Screen.env -> Screen.geometry -> (unit, string) result -> 'a -> 'a * Screen.request;
}

type owner_ref = Owner : 'a owner -> owner_ref

let all =
  [
    Owner
      {
        route = W.Daily_pace;
        config_files = Daily_pace_screen.config_files;
        get = (fun t -> t.pace);
        set = (fun t pace -> { t with pace });
        enter = Daily_pace_screen.enter;
        modal = Daily_pace_screen.modal;
        handle = Daily_pace_screen.handle;
        view = Daily_pace_screen.view;
        saved = Daily_pace_screen.saved;
      };
    Owner
      {
        route = W.Balances;
        config_files = Balances_screen.config_files;
        get = (fun t -> t.balances);
        set = (fun t balances -> { t with balances });
        enter = Fun.id;
        modal = Balances_screen.modal;
        handle = Balances_screen.handle;
        view = Balances_screen.view;
        saved = Balances_screen.saved;
      };
    Owner
      {
        route = W.Income_expense;
        config_files = Income_expense_screen.config_files;
        get = (fun t -> t.income_expense);
        set = (fun t income_expense -> { t with income_expense });
        enter = Income_expense_screen.enter;
        modal = Income_expense_screen.modal;
        handle = Income_expense_screen.handle;
        view = Income_expense_screen.view;
        saved = Income_expense_screen.saved;
      };
    Owner
      {
        route = W.Transactions_flow;
        config_files = Transactions_flow_screen.config_files;
        get = (fun t -> t.transactions_flow);
        set = (fun t transactions_flow -> { t with transactions_flow });
        enter = Transactions_flow_screen.enter;
        modal = Transactions_flow_screen.modal;
        handle = Transactions_flow_screen.handle;
        view = Transactions_flow_screen.view;
        saved = Transactions_flow_screen.saved;
      };
    Owner
      {
        route = W.Stock_flow;
        config_files = Stock_flow_screen.config_files;
        get = (fun t -> t.stock_flow);
        set = (fun t stock_flow -> { t with stock_flow });
        enter = Stock_flow_screen.enter;
        modal = Stock_flow_screen.modal;
        handle = Stock_flow_screen.handle;
        view = Stock_flow_screen.view;
        saved = Stock_flow_screen.saved;
      };
    Owner
      {
        route = W.Attention;
        config_files = Attention_screen.config_files;
        get = (fun t -> t.attention);
        set = (fun t attention -> { t with attention });
        enter = Attention_screen.enter;
        modal = Attention_screen.modal;
        handle = Attention_screen.handle;
        view = Attention_screen.view;
        saved = Attention_screen.saved;
      };
    Owner
      {
        route = W.Settlements;
        config_files = Settlements_screen.config_files;
        get = (fun t -> t.settlements);
        set = (fun t settlements -> { t with settlements });
        enter = Settlements_screen.enter;
        modal = Settlements_screen.modal;
        handle = Settlements_screen.handle;
        view = Settlements_screen.view;
        saved = Settlements_screen.saved;
      };
  ]

let for_route route = List.find_opt (fun (Owner o) -> o.route = route) all
let modal t = List.find_opt (fun (Owner o) -> o.modal (o.get t)) all

let enter route t =
  match for_route route with Some (Owner o) -> o.set t (o.enter (o.get t)) | None -> t
