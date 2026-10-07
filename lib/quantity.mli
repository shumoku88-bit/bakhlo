(** 最小単位Quantaの符号付き任意精度整数。Zarithの [Z.t] を使い、
    浮動小数点の丸めや固定長整数の桁溢れを避ける。
    通貨単位・表示スケール・換算は、この算術型とは別に扱う。 *)

type t

val of_quanta : Z.t -> t
(** 任意精度整数 [Z.t] との相互変換（情報の欠落なし） *)

val quanta : t -> Z.t
val zero : t
val add : t -> t -> t
val neg : t -> t
val sub : t -> t -> t
val equal : t -> t -> bool

val compare : t -> t -> int
(** 厳密な整数順序に基づく比較（負なら負数、0なら等しい、正なら正数を返す） *)

val sum : t list -> t
(** 有限リストの総和。空リストの総和は [zero] です。
    （※ただし、家計の証拠が存在しないことと、残高が0であることは別です） *)
