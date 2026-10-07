module D = Bakhlo_domain
module A = Bakhlo_application

(** 現在の限定された [bakhlo 1/2/3 ordinary-quantity] 形式。
    明示された通貨スケール、通常の事象・日付・メモ、訂正関係、観測とゼロ起点を扱う。
    v2は新規記帳用の科目語彙、v3は選択された2通貨間の両替証拠も持つ。
    支払い予定や全LOAM家計を扱う形式ではない。
    未対応の情報は読み飛ばさず拒絶する。旧版を保持するこの形式の契約と、
    訂正済み明細を使う新しい家計簿候補の方針は別。 *)

type family = Measures | Events | Event_corrections | Observations | Zero_origin | Exchanges
type supply = Provided | Empty | Not_supplied
type measure = { id : D.Identifier.Measure.t; decimal_scale : Z.t }
type t

type error =
  | Syntax of Parsexp.Parse_error.t
  | Wire of { at : string; problem : string }
  | Event of { event : D.Identifier.Event.t; error : D.Event.error }
  | Movement of D.Movement.error list
  | Source of A.Actual_source.error
  | Support of A.Current_quantity_query.error

val of_string : string -> (t, error) result
(** 全体の構文・通貨・参照・数量根拠を検査する。欠落を空やゼロにしない。
    重複する観測座標は拒絶するが、独立した観測の反映集合は重なってよい。 *)

val original_bytes : t -> string
val version : t -> int

val to_string : t -> string
(** この形式の全事実と旧版を決定論的に印字する。
    メモは保持するが、元のコメント・空白そのものの再印字ではない。 *)

val measures : t -> measure list
val supply : t -> family -> supply

val locus_admission : t -> D.Identifier.Locus.t list option
(** [Some []] は承認語彙が空、[None] は未提供。履歴上の登場から承認を推測しない。 *)

val image : t -> A.Current_quantity_query.t
(** 提供された事実と根拠に基づく条件付き数量。家計全体の真実とは限らない。 *)

type candidate

val base : candidate -> t
val document : candidate -> t

val admit_locus : base:t -> locus:string -> (candidate, error) result
(** v2/v3の明示された語彙へ正確な識別子を追加する。残高ゼロや履歴は作らない。 *)

val append : base:t -> event:string -> (candidate, error) result
(** 明示された通常の単一通貨移動を追加し、印字・再読取・全体検査した候補を返す。 *)

val append_exchange :
  base:t ->
  event:string ->
  source:string ->
  destination:string ->
  (candidate, error) result
(** v3だけ。Event内のsource/destination Effect keyを明示して2 Measure間の両替として追加する。
    レート・評価額・手数料・自宅通貨は推測しない。Actualの既存Exchange admissionをそのまま使う。 *)

val correct : base:t -> target:D.Identifier.Event.t -> event:string -> (candidate, error) result
(** この形式では元事象を保持し、訂正関係を追加する。
    v2/v3の新しい効果は承認語彙を検査する。候補は記帳権限・実ファイル更新・保存成功ではない。 *)
