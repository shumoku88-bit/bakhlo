val of_string : string -> int
(** Terminal cells of UTF-8 text: two for East Asian wide and fullwidth characters
    (kanji, kana, hangul, fullwidth forms, most emoji), none for combining marks. *)
