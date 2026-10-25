(* The publication operations, applied all-or-nothing with the same Daily_book
   functions the application uses. Pure: no file access. *)
module B = Daily_book
module M = Bakhlo_application.Event_merchants

type op =
  | Put_entry of { replace : bool; entry : B.entry; plan : string option }
  | Correct_entry_date of { id : string; day : string }
  | Put_plan of { replace : bool; plan : B.plan }
  | Cancel_plan of { id : string; day : string }
  | Observe of (string * string * Z.t) list
  | Add_locus of string
  | Set_locus_label of { id : string; label : string; help : string option }
  | Classify_merchant of { id : string; disposition : M.disposition }

let apply book = function
  | Put_entry { replace; entry; plan } -> B.put_entry book ~replace entry ~plan
  | Correct_entry_date { id; day } -> B.correct_entry_date book ~id ~day
  | Put_plan { replace; plan } -> B.put_plan book ~replace plan
  | Cancel_plan { id; day } -> B.cancel_plan book ~id ~day
  | Observe rows -> B.observe_quantities book rows
  | Add_locus id -> B.add_locus book id
  | Set_locus_label { id; label; help } -> B.set_locus_label book ~id ~label ?help ()
  | Classify_merchant { id; disposition } -> B.classify_merchant book ~id ~disposition

let apply_all book ops =
  List.fold_left (fun result op -> Result.bind result (fun book -> apply book op)) (Ok book) ops
