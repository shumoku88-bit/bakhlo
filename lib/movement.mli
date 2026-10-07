(** 検査済みの通常の資金移動。効果は非空・非ゼロ・単一通貨で、総和がゼロ。
    この型は構造の検査結果であり、実際の家計の事実や保存成功を保証しない。 *)

type t

type error =
  | Empty
  | Zero_quantity of { position : int }
  | Measure_mismatch of {
      position : int;
      expected : Identifier.Measure.t;
      actual : Identifier.Measure.t;
    }
  | Unbalanced of { measure : Identifier.Measure.t; residual : Quantity.t }

val validate : Effect.t list -> (t, error list) result
(** 効果リストを検証し、均衡の取れた [Movement.t] を構築します。
    エラーは発生順（1-basedのインデックス付き）で網羅的に収集されます。 *)

val measure : t -> Identifier.Measure.t
val effects : t -> Effect.t list

val positive_total : t -> Quantity.t
(** 正の効果の総和。算出値であり、独立した正データではない。 *)
