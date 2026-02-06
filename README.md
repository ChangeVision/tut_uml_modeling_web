# Bowling Score Manager

Rubyで作成されたボーリングスコア記録Webアプリケーション

## 必要環境

- Ruby 3.3.5
- rbenv
- Bundler

## セットアップ
```bash
# Rubyバージョンの設定
rbenv local 3.3.5

# 依存gemのインストール
bundle install

# アプリケーション起動
bundle exec rackup -p 4567
```

ブラウザで `http://localhost:4567` にアクセス

## サンプルデータで試す

リポジトリにはサンプルデータベースが含まれています：
```bash
# サンプルDBをコピーして使用
cp bowling_sample.db bowling.db

# アプリケーション起動
bundle exec rackup -p 4567
```

サンプルには完了済みのゲームとプレイ中のゲームが含まれており、すぐに動作を確認できます。

## 新規データベースで開始

サンプルを使わず、空のデータベースから始める場合：
```bash
# 既存のbowling.dbがあれば削除
rm -f bowling.db

# アプリケーション起動（自動的に新規DBが作成されます）
bundle exec rackup -p 4567
```


## 開発時（自動再起動）
```bash
bundle exec rerun -- rackup -p 4567
```

## 機能

- 複数プレイヤーでのゲーム作成・管理
- リアルタイムスコア計算（ストライク・スペア対応）
- 10フレーム3投目の正確な処理
- ゲーム履歴の保存・閲覧
- SQLiteによるデータ永続化

## ファイル構成
```
.
├── app.rb          # メインアプリケーション
├── config.ru       # Rack設定
├── Gemfile         # 依存gem定義
├── Gemfile.lock    # gem バージョンロック
├── .gitignore      # Git除外設定
└── README.md       # このファイル
```

## ライセンス

提供するチュートリアルの文書を含むやリポジトリ全体について、link:https://creativecommons.org/licenses/by-nc-nd/4.0[クリエイティブ・コモンズ CC-BY-NC-ND 4.0] に従います。
