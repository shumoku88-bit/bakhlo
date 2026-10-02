type t =
  { id : Identifier.Event.t
  ; effects : Effect.t list
  }

let create ~id ~effects = { id; effects }
let id event = event.id
let effects event = event.effects
