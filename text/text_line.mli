type token = Word of string | Quoted of string
val decode : string -> (token list, string) result
