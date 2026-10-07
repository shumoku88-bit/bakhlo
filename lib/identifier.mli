(** 通貨・科目・事象などを取り違えないための独立した識別子。
    空文字列のみ拒絶し、トリム・大小文字変換・エイリアス解決は行わない。
    元のバイト列を保持する。識別子の型だけで実在性や記帳の承認は保証しない。 *)

type error = Empty

(** 通貨や単位（例: "jpy", "usd"）の識別子 *)
module Measure : sig
  type t

  val of_string : string -> (t, error) result
  val to_string : t -> string
  val equal : t -> t -> bool
end

(** 所在・口座・費目（例: "wallet", "bank", "food"）の識別子 *)
module Locus : sig
  type t

  val of_string : string -> (t, error) result
  val to_string : t -> string
  val equal : t -> t -> bool
end

(** 外部の関係者・取引先（店舗、支払先、債権者など）の識別子 *)
module External_party : sig
  type t

  val of_string : string -> (t, error) result
  val to_string : t -> string
  val equal : t -> t -> bool
end

(** 一つの事象（Event）内で個々の効果（Effect）を識別するためのキー *)
module Effect_key : sig
  type t

  val of_string : string -> (t, error) result
  val to_string : t -> string
  val equal : t -> t -> bool
  val compare : t -> t -> int

  include Base.Comparator.S with type t := t
end

(** 独立した関係単位の識別子 *)
module Relation : sig
  type t

  val of_string : string -> (t, error) result
  val to_string : t -> string
  val equal : t -> t -> bool
  val compare : t -> t -> int

  include Base.Comparator.S with type t := t
end

(** 日付改訂の主張を識別するための識別子 *)
module Validity_revision : sig
  type t

  val of_string : string -> (t, error) result
  val to_string : t -> string
  val equal : t -> t -> bool
  val compare : t -> t -> int

  include Base.Comparator.S with type t := t
end

(** 事象（取引・記録）そのものの識別子（例: "E1", "tx-2024-001"） *)
module Event : sig
  type t

  val of_string : string -> (t, error) result
  val to_string : t -> string
  val equal : t -> t -> bool

  val compare : t -> t -> int
  (** 不変メモリのインデックス付けのためのバイト順比較 *)

  include Base.Comparator.S with type t := t
end
