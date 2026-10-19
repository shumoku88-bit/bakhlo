type route =
  | Home | Calendar | Selected_day of string | Actual | Scheduled | Balances | Daily_pace
  | Attention | Loci | Settlements | Income_expense | Transactions_flow | Stock_flow

type annual = {
  notice : string option Lazy.t;
  year : int option;
  unavailable : string option Lazy.t;
  history : ((string * string) option, string) result Lazy.t;
}

type env = {
  book : Bakhlo_sexp.Daily_book.t;
  bytes : string;
  new_id : unit -> string;
  measure : string;
  calendar : Daily_calendar.t;
  today : string;
  annual : annual;
  accounting_roles : (string * Daily_overlays.accounting_role) list Lazy.t;
  attention : (Attention_data.t, string) result;
  settlements : (Settlement_data.t, string) result;
  blocked : bool;
  config : string -> (string option, string) result;
}

type layout = Standard | Workspace

type geometry = {
  screen : int * int;
  body : int * int;
  content : int * int;
  width_of : string -> int;
}

type admission = Unconditional | Household_readable | Vocabulary_unchanged

type publication =
  | Add_locus of string
  | Set_locus_label of { locus : string; label : string; help : string }
  | Commit_transaction of { transaction : Daily_draft.transaction; base : string }
  | Observe_quantities of { rows : (string * string * Z.t) list; base : string }
  | Reverse_entry of { id : string; day : string; base : string }
  | Correct_entry of { transaction : Daily_draft.transaction; base : string }
  | Classify_merchant of {
      id : string; disposition : Bakhlo_application.Event_merchants.disposition; base : string;
      message : string;
    }
  | Cancel_plan of { id : string; day : string; base : string }
  | Plan_batch of { plans : Bakhlo_sexp.Daily_book.plan list; replace : bool; base : string }
  | Create_plan of { plan : Bakhlo_sexp.Daily_book.plan; base : string }

type publish_outcome = Published | Publish_refused of string | Publish_conflict | Publish_stopped

type record_target = Entry of Bakhlo_sexp.Daily_book.entry | Plan of Bakhlo_sexp.Daily_book.plan

type record_action =
  | Edit | Pay | Reverse | Correct_date | Classify_merchant | Cancel | Batch | Generate

type request =
  | Stay
  | Ignored
  | Message of string
  | Home
  | Commands
  | Reload
  | Cycle_measure of [ `Next | `Prev ]
  | Observe of { locus : string; measure : string; amount : Z.t option }
  | Save_attention of { expected : Attention_data.t; next : Attention_data.t }
  | Save_settlements of { expected : Settlement_data.t; next : Settlement_data.t }
  | Open_route of route
  | Back
  | Quit
  | Set_calendar of { calendar : Daily_calendar.t; clear_message : bool }
  | Open_observe
  | New_plan
  | Record_action of { action : record_action; target : record_target option }
  | New_record
  | Drill of { day : string; entry : string }
  | Publish of publication
  | Stop_writes of string option
  | Save_config of {
      file : string;
      expected : string option;
      content : string;
      admission : admission;
    }

type subtitle = Default | Text of string | Styled of Ui_render.style * string

type view = {
  title : string;
  subtitle : subtitle;
  rows : (Ui_render.style * string) list Lazy.t;
  footer : string list;
  overlay : Ui_overlay.frame option;
  cursor : (int * int) option;
}

let no_publication _env _geometry _outcome t = (t, Stay)
let no_reload _env t = (t, Stay)

let env_for_checks ?(accounting_roles = []) ?(config = fun name -> Error ("undeclared " ^ name))
    ~book ~measure ~today () =
  {
    book; bytes = ""; new_id = (let n = ref 0 in fun () -> incr n; Printf.sprintf "check-%d" !n);
    measure; today; calendar = Result.get_ok (Daily_calendar.create today);
    annual = { notice = lazy None; year = None; unavailable = lazy None; history = lazy (Ok None) };
    accounting_roles = lazy accounting_roles;
    attention = Ok Attention_data.empty;
    settlements = Ok Settlement_data.empty;
    blocked = false; config;
  }
