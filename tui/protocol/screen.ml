type annual = {
  year : int option;
  unavailable : string option Lazy.t;
  history : ((string * string) option, string) result Lazy.t;
}

type env = {
  book : Bakhlo_sexp.Daily_book.t;
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
