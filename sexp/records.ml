(* The entry and plan records the book modules and their operations share. *)

type entry = {
  id : string;
  day : string;
  memo : string option;
  effects : Bakhlo_domain.Effect.t list;
  reversal_of : string option;
  exchange : (string * string) option;
  original_amount : (string * Z.t) option;
  merchant : Bakhlo_application.Event_merchants.disposition option;
}

type plan = {
  id : string;
  day : string;
  measure : string;
  changes : (string * Z.t) list;
  paid_by : string option;
  cancelled_on : string option;
}
