# Ruby 3.4対応修正ガイド

## 問題の原因

Ruby 3.4では、キーワード引数と位置引数の区別がより厳密になりました。
SQLite3 gemも同様に、引数の渡し方が変更されている可能性があります。

## 修正方法

### 方法1: SQLite3 gemを最新版にアップデート

```bash
bundle update sqlite3
```

または、Gemfileで明示的に最新版を指定：

```ruby
gem 'sqlite3', '~> 2.0'
```

### 方法2: executeメソッドの呼び出し方を修正

Ruby 3.4対応のため、以下のように修正します：

#### 修正前（492行目）:
```ruby
db.execute('INSERT INTO games (id) VALUES (?)', game_id)
```

#### 修正後:
```ruby
db.execute('INSERT INTO games (id) VALUES (?)', [game_id])
```

#### 修正前（496-497行目）:
```ruby
db.execute('INSERT INTO players (id, game_id, name, player_index) VALUES (?, ?, ?, ?)',
           player_id, game_id, name, index)
```

#### 修正後:
```ruby
db.execute('INSERT INTO players (id, game_id, name, player_index) VALUES (?, ?, ?, ?)',
           [player_id, game_id, name, index])
```

#### 修正前（500-501行目）:
```ruby
db.execute('INSERT INTO frames (player_id, frame_no) VALUES (?, ?)',
           player_id, frame_no)
```

#### 修正後:
```ruby
db.execute('INSERT INTO frames (player_id, frame_no) VALUES (?, ?)',
           [player_id, frame_no])
```

### 方法3: 全体的な修正スクリプト

以下のコマンドで一括置換できます：

```bash
# バックアップを作成
cp bowling_app.rb bowling_app.rb.backup_ruby34

# executeの呼び出しを修正（慎重に確認してください）
```

## 推奨される修正手順

1. **まず、Gemfileを確認**

```bash
cat Gemfile
```

2. **sqlite3のバージョンを確認**

```bash
bundle list | grep sqlite3
```

3. **sqlite3を最新版にアップデート**

```bash
bundle update sqlite3
bundle install
```

4. **それでも解決しない場合、executeの呼び出しを配列形式に変更**

## テスト方法

修正後、以下のコマンドで動作確認：

```bash
# 開発サーバーを起動
bundle exec ruby bowling_app.rb

# または
bundle exec rackup
```

ブラウザで `http://localhost:4567` にアクセスして、
ゲーム作成が正常に動作するか確認してください。
