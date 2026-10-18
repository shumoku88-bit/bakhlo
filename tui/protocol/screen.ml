type annual = {
  year : int option;
  unavailable : string option Lazy.t;
  history : ((string * string) option, string) result Lazy.t;
}

type env = {
  book : Bakhlo_sexp.Daily_book.t;
  bytes : string;
  new_id : unit -> string;
  measure : string;
  today : string;
  annual : annual;
  accounting_roles : (string * Daily_overlays.accounting_role) list Lazy.t;
  attention : (Attention_data.t, string) result;
  settlements : (Settlement_data.t, string) result;
  blocked : bool;
  config : string -> (string option, string) result;
}

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

type publish_outcome = Published | Publish_refused of string | Publish_conflict | Publish_stopped

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
  | Publish of publication
  | Stop_writes of string option
  | Save_config of {
      file : string;
      expected : string option;
      content : string;
      admission : admission;
    }

type view = {
  title : string;
  subtitle : string option;
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
    measure; today;
    annual = { year = None; unavailable = lazy None; history = lazy (Ok None) };
    accounting_roles = lazy accounting_roles;
    attention = Ok Attention_data.empty;
    settlements = Ok Settlement_data.empty;
    blocked = false; config;
  }
