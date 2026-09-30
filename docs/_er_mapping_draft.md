# クラス図からER図への対応づけ（第7章の骨子・下書き）

前提：クラス図（score.rb）を正とし、ER図はクラス図から導く。DBはモデルのスナップショットであり、
DBに書くのはモデルのオブジェクトだけが行う。DBからオブジェクトは復元しない
（要件：ゲームの途中からは再開できない。再起動後は履歴の参照と新しいゲームの追加ができる）。
DBの行は、履歴の表示のために読み出す。そのとき、クラスと同じ属性名で扱う（下の対応表を逆向きに使う）。

## 対応づけルール

| # | クラス図の要素 | ER図の要素 | 本チュートリアルでの例 |
|---|---|---|---|
| R1 | 永続化するクラス | テーブル | ScoreSheet→score_sheets, Game→games, Score→scores, Frame→frames |
| R2 | 識別子の属性（id） | 主キー（クラスと同じ型） | Game.id→games.game_id（TEXT） |
| R3 | 値として持つ属性 | 列 | Score.player→scores.player_name |
| R4 | 状態変数（state）と状態の進み具合を表す属性 | 列（状態名を文字列で保存） | Frame.state, Score.state, Score.fno, Game.turn |
| R5 | 全体→部分の関連（多重度 1..*） | 部分側テーブルの外部キー | Game→Score：scores.game_id |
| R6 | 順序つきの関連（配列の添字に意味がある） | 順序を表す列 | Game.scores の並び→scores.entry_order（Game.turn が参照する） |
| R7 | 識別子を持たない部分クラス | 親の主キー＋限定子の複合主キー | Frame：(score_id, frame_no) |
| R8 | 計算の都合で置いたダミー要素 | 保存しない | Frame -1, 0, 13 は保存しない。1〜12（11・12はサービスフレーム）を保存する |

## 属性と列の対応表

| クラス.属性 | テーブル.列 | ルール | 旧ER図からの変更 |
|---|---|---|---|
| ScoreSheet.id | score_sheets.score_sheet_id | R2 | INTEGER→TEXT |
| ScoreSheet.play_date | score_sheets.play_date | R3 | |
| Game.id | games.game_id | R2 | INTEGER→TEXT |
| ScoreSheet.games | games.score_sheet_id | R5 | TEXT |
| Game.turn | games.turn | R4 | 追加 |
| Score.id | scores.score_id | R2 | INTEGER→TEXT |
| Game.scores | scores.game_id / entry_order | R5, R6 | entry_order 追加 |
| Score.player | scores.player_name | R3 | players テーブルを削除 |
| Score.fno | scores.fno | R4 | 追加 |
| Score.state | scores.state | R4 | 追加 |
| Score.frames / Frame.frame_no | frames.score_id / frame_no | R5, R7 | frame_id を廃止し複合主キーに |
| Frame.first / second | frames.first / second | R3 | NOT NULL DEFAULT 0 のまま（未投球は state で表す） |
| Frame.spare_bonus / strike_bonus | 同名 | R3 | |
| Frame.total | frames.frame_total | R3 | |
| Frame.state | frames.state | R4 | 追加 |

## 決定済み（旧・未決事項）
* ScoreSheet：CLI版と同じく、アプリ起動時に1枚作る
* 復元：行わない（要件で割り切る）。したがって復元用の生成手段は不要で、モデルは変更しない
* 保存のタイミング：投球ごとにスナップショットを保存する。中断は Score.state で判断する

* frames の行：Game#entry（Score の生成）のときに frame_no 1〜12 の12行を RESERVED で作る。
  行の有無に意味を持たせず、フレームの状況はすべて state で表す

## ER図からSQLへ（手順）
* ER図：docs/models/bowling_score_web.asta の「Web版ゲームスコアのER図」
  - state 列はドメイン frame_state / score_state（VARCHAR(16)、NOT NULL、初期値は状態機械図の開始状態）を使う
  - ドメインの定義欄に、とりうる値（状態機械図の状態の集合）と CHECK 制約を書く
  - 列の初期値はクラスの initialize の初期値から導く。モデルが与える値（frame_no、play_date など）には初期値を付けない
* SQLエクスポート：オプション「CREATE TABLE文のみを使用する」にチェックを入れて docs/models/bowling_score_web.sql に出力する
  - このオプションで主キー・外部キーが CREATE TABLE の中に出力され、そのままSQLiteで実行できる
  - 物理名は未設定のため、論理名を使うかを尋ねるダイアログで「はい」を選ぶ（論理名＝物理名の方針）
* SQLite用：エクスポートしたSQLに、ドメインの定義にある CHECK 制約を state 列へ加えて
  docs/models/bowling_score_web_sqlite.sql とする（手で加えるのはこれだけ）
* 外部キーを有効にするため、接続ごとに PRAGMA foreign_keys = ON; を実行する

## 扱い
* ER図はこの内容でいったん確定とする。コードを作る中で問題が見つかったら、ここに立ち戻って見直す
