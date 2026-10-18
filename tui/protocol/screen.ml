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
  blocked : bool;
  config : string -> (string option, string) result;
}

type geometry = {
  screen : int * int;
  body : int * int;
  content : int * int;
  width_of : string -> int;
}

type admission = Unconditional | Household_readable

type request =
  | Stay
  | Ignored
  | Message of string
  | Home
  | Commands
  | Reload
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
