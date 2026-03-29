# Web版の作業メモ

## Web版1.0できていること

* SQLiteで永続化
* 複数名プレイ
* フレーム計算ロジック（だいたい元のと同じ）
* ゲームごとの記録

* 残る課題
  - GitHubに登録
  - UI改善（ストライク、スペア表示）
  - プレーヤー情報登録（いまはその場限りなので、プレーヤーごとの集積ができない）
  - WEB API化（現状はSinatraからDB直接叩いているので、他も直接SQLiteを叩かないとだめ）
  - データベーススキーマ作成、アクセス部分の分離
  - スタイルシートの分離
  - WEBアプリ版テキストの作成
  - WEBアプリとER、UMLの関係づけ

## 次にやったこと

* Look&Feelをコマンドライン版のチュートリアルテキストのものと似せる
* ゲーム一覧を表示する
* 既存のRubyプログラム（300行）をWebアプリ化
* Sinatra + SQLiteの軽量構成
* プロフェッショナルなボーリングスコアボードUI
* 正確なスコア計算とルール実装
* Git管理とGitHubへの公開
* v1.0-uiタグでのリリース

* リポジトリ: https://github.com/ChangeVision/tut_uml_modeling_web

## v1.0-uiでやったこと

* UI改善（ストライク・スペア表示の修正）
* ガーターとミスの区別
* 10フレーム3投目の正確な表示

## チュートリアル本文の作成開始

### チュートリアル文書の企画・設計

* Web版チュートリアルの全体構成確立（全10章）
* モデル駆動開発アプローチの一貫性確保
* 元のチュートリアルからの転用方針決定
* 共通ファイル群の作成
* メインファイルの作成
* タグ付け: v0.1-docs-foundation

### 現在のリポジトリ構成

``` console
tut_uml_modeling_web/
├── docs/                          # チュートリアル文書
│   ├── tut_uml_modeling_web.adoc # メインファイル
│   ├── attributes.adoc            # 共通属性
│   ├── image_size_matter.adoc    # 画像サイズ定義
│   ├── front_matter.adoc         # 表紙情報
│   ├── copyright.adoc            # 著作権
│   ├── preface.adoc              # まえがき
│   ├── bibliography.adoc         # 参考文献
│   ├── glossary.adoc             # 用語集
│   └── images/                   # 図版格納先（今後作成）
├── bowling_app.rb                # Webアプリ本体
├── config.ru
├── Gemfile
├── public/
│   └── scoresheet.css
└── README.md
```

### 次回のタスク候補

* 第1章ファイルの作成
* 第2-5章の転用作業
* 第6章の完成
* astahでUML図作成開始
