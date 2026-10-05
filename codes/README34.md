# Bowling Score Manager（Web版）

Rubyで作成したボウリングスコア記録Webアプリケーションです。
チュートリアル『モデルを使ってWebアプリケーションを開発しよう』のサンプルコードです。

スコア計算には、CLI版と同じ `score.rb` のクラス（ScoreSheet, Game, Score, Frame）を変更せずに使っています。
Webアプリケーションは、`score.rb` のメイン処理（テストコード）を Sinatra のルーティングに置き換えたものです。

## 必要環境

- Ruby 3.4.4
- rbenv
- Bundler

## セットアップ

```bash
# Rubyバージョンの設定
rbenv local 3.4.4

# 依存gemのインストール
bundle install

# アプリケーション起動
bundle exec rackup -p 4567
```

ブラウザで `http://localhost:4567` にアクセスします。

起動すると、データベース `bowling_web.db` がなければ作成します。
テーブルは、ER図からエクスポートしたSQL（`../docs/models/bowling_score_web_sqlite.sql`）から作ります。

## サンプルデータで試す

リポジトリにはサンプルデータベース（`bowling_sample.db`）が含まれています。

```bash
# サンプルDBをコピーして使用
cp bowling_sample.db bowling_web.db

# アプリケーション起動
bundle exec rackup -p 4567
```

サンプルには、終了したゲームが2つと、途中で止めた（中断した）ゲームが1つ含まれています。

サンプルDBは、次のスクリプトで作り直せます。

```bash
ruby make_sample_db.rb
```

## 新規データベースで開始

```bash
# 既存のデータベースがあれば削除
rm -f bowling_web.db

# アプリケーション起動（自動的に新規DBが作成されます）
bundle exec rackup -p 4567
```

## 開発時（自動再起動）

```bash
bundle exec rerun -- rackup -p 4567
```

## 機能

- 複数プレーヤーでのゲーム作成と投球
- スコア計算（ストライク・スペア・第10フレームのサービスフレーム）
- 投球のたびにSQLiteへ保存
- ゲーム履歴の表示

ゲームの途中からは再開できません。
アプリケーションを再起動したときには、前のゲームの履歴の参照と、新しいゲームの追加ができます。
再起動前に途中だったゲームは、履歴に「中断」として表示されます。

## ファイル構成

```
codes/
├── bowling_app.rb       # Webアプリケーション（Sinatraのルーティングと表示用ヘルパー）
├── score.rb             # モデル（ScoreSheet, Game, Score, Frame）。CLI版と同じ
├── score_repository.rb  # データアクセス層（モデルとデータベースの間の読み書き）
├── make_sample_db.rb    # サンプルデータベースを作るスクリプト
├── bowling_sample.db    # サンプルデータベース
├── config.ru            # Rack設定
├── Gemfile              # 依存gem定義
├── Gemfile.lock         # gemバージョンロック
├── public/
│   └── scoresheet.css   # スタイルシート
└── views/
    ├── layout.erb       # 共通レイアウト
    ├── index.erb        # ゲームの作成と履歴の一覧
    └── game.erb         # スコアボード（プレー中のゲームと履歴で共通）

docs/models/
├── bowling_score_web.asta        # モデル（クラス図、ステートマシン図、ER図）
├── bowling_score_web.sql         # ER図からエクスポートしたSQL
└── bowling_score_web_sqlite.sql  # SQLite用（CHECK制約を加えたもの）
```

## ライセンス

提供するチュートリアルの文書を含むリポジトリ全体について、[クリエイティブ・コモンズ CC-BY-NC-ND 4.0](https://creativecommons.org/licenses/by-nc-nd/4.0) に従います。
