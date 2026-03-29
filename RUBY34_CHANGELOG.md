# Ruby 3.4対応 - 変更履歴と詳細

## 📋 変更サマリー

Ruby 3.4では、SQLite3 gemの`execute`メソッドが位置引数からキーワード引数（または配列）形式に変更されました。
すべての`db.execute`呼び出しで、パラメータを**配列**で渡す必要があります。

## 🔧 修正箇所一覧

### 1. INSERT文（ゲーム作成時）

#### 492行目
```ruby
# 修正前
db.execute('INSERT INTO games (id) VALUES (?)', game_id)

# 修正後
db.execute('INSERT INTO games (id) VALUES (?)', [game_id])
```

#### 496-497行目
```ruby
# 修正前
db.execute('INSERT INTO players (id, game_id, name, player_index) VALUES (?, ?, ?, ?)',
           player_id, game_id, name, index)

# 修正後
db.execute('INSERT INTO players (id, game_id, name, player_index) VALUES (?, ?, ?, ?)',
           [player_id, game_id, name, index])
```

#### 500-501行目
```ruby
# 修正前
db.execute('INSERT INTO frames (player_id, frame_no) VALUES (?, ?)',
           player_id, frame_no)

# 修正後
db.execute('INSERT INTO frames (player_id, frame_no) VALUES (?, ?)',
           [player_id, frame_no])
```

### 2. UPDATE文（ゲーム状態の保存）

#### 386-387行目
```ruby
# 修正前
db.execute('UPDATE games SET status = ?, turn_index = ? WHERE id = ?',
           status, game.turn, game.id)

# 修正後
db.execute('UPDATE games SET status = ?, turn_index = ? WHERE id = ?',
           [status, game.turn, game.id])
```

#### 390-391行目
```ruby
# 修正前
db.execute('UPDATE players SET current_frame = ?, state = ? WHERE id = ?',
           score.fno, score.state.to_s, score.id)

# 修正後
db.execute('UPDATE players SET current_frame = ?, state = ? WHERE id = ?',
           [score.fno, score.state.to_s, score.id])
```

#### 396行目（ヒアドキュメント形式）
```ruby
# 修正前
db.execute(<<-SQL, frame.first, frame.second, frame.third, frame.spare_bonus, frame.strike_bonus, frame.total, frame.state.to_s, score.id, frame.frame_no)
  UPDATE frames SET
    first_roll = ?, second_roll = ?, third_roll = ?, spare_bonus = ?,
    strike_bonus = ?, total = ?, state = ?
  WHERE player_id = ? AND frame_no = ?
SQL

# 修正後
db.execute(<<-SQL, [frame.first, frame.second, frame.third, frame.spare_bonus, frame.strike_bonus, frame.total, frame.state.to_s, score.id, frame.frame_no])
  UPDATE frames SET
    first_roll = ?, second_roll = ?, third_roll = ?, spare_bonus = ?,
    strike_bonus = ?, total = ?, state = ?
  WHERE player_id = ? AND frame_no = ?
SQL
```

### 3. SELECT文（データの読み込み）

#### 412行目
```ruby
# 修正前
game_data = db.execute('SELECT * FROM games WHERE id = ?', game_id).first

# 修正後
game_data = db.execute('SELECT * FROM games WHERE id = ?', [game_id]).first
```

#### 417行目
```ruby
# 修正前
players = db.execute('SELECT * FROM players WHERE game_id = ? ORDER BY player_index', game_id)

# 修正後
players = db.execute('SELECT * FROM players WHERE game_id = ? ORDER BY player_index', [game_id])
```

#### 420行目
```ruby
# 修正前
frames = db.execute('SELECT * FROM frames WHERE player_id = ?', player_data['id'])

# 修正後
frames = db.execute('SELECT * FROM frames WHERE player_id = ?', [player_data['id']])
```

### 4. DELETE文（ゲームの削除）

#### 544行目
```ruby
# 修正前
db.execute('DELETE FROM frames WHERE player_id IN (SELECT id FROM players WHERE game_id = ?)', params[:id])

# 修正後
db.execute('DELETE FROM frames WHERE player_id IN (SELECT id FROM players WHERE game_id = ?)', [params[:id]])
```

#### 545行目
```ruby
# 修正前
db.execute('DELETE FROM players WHERE game_id = ?', params[:id])

# 修正後
db.execute('DELETE FROM players WHERE game_id = ?', [params[:id]])
```

#### 546行目
```ruby
# 修正前
db.execute('DELETE FROM games WHERE id = ?', params[:id])

# 修正後
db.execute('DELETE FROM games WHERE id = ?', [params[:id]])
```

### 5. 修正不要な箇所

#### 473行目（引数なしのSELECT）
```ruby
# このままでOK
@games = db.execute(<<-SQL)
  SELECT g.*, GROUP_CONCAT(p.name, ', ') as players
  FROM games g
  LEFT JOIN players p ON g.id = p.game_id
  GROUP BY g.id
  ORDER BY g.start_time DESC
  LIMIT 20
SQL
```

## 🧪 テスト手順

### 1. 修正ファイルの適用

```bash
# バックアップを作成
cp bowling_app.rb bowling_app.rb.backup_before_ruby34

# 修正版をコピー
cp bowling_app_ruby34_fixed.rb bowling_app.rb
```

### 2. 依存関係の確認

```bash
# Gemfile.lockを確認
cat Gemfile.lock | grep sqlite3
```

最新のsqlite3 gemバージョンを確認してください（推奨: 2.0以上）

### 3. Bundlerで依存関係を更新

```bash
bundle update sqlite3
bundle install
```

### 4. データベースの初期化

```bash
# 既存のDBを削除（必要に応じて）
rm bowling.db

# アプリケーションを起動（初回起動時にDBが自動作成されます）
bundle exec ruby bowling_app.rb
```

### 5. 動作確認

ブラウザで `http://localhost:4567` にアクセスし、以下を確認：

1. ✅ トップページが表示される
2. ✅ プレイヤー名を入力してゲームを作成できる
3. ✅ ゲーム画面が表示される
4. ✅ ピン数を入力してスコアが更新される
5. ✅ ゲームを削除できる

## 🐛 トラブルシューティング

### エラー: `ArgumentError: wrong number of arguments`

**原因**: まだ修正していない`execute`呼び出しが残っている

**解決策**:
```bash
# executeの呼び出しを全て確認
grep -n "\.execute(" bowling_app.rb | grep -v "execute_batch"

# 各行を確認し、引数が配列形式になっているか確認
```

### エラー: `SQLite3::SQLException: no such table`

**原因**: データベースが初期化されていない

**解決策**:
```bash
# データベースを削除して再作成
rm bowling.db
bundle exec ruby bowling_app.rb
```

### エラー: `LoadError: cannot load such file -- sqlite3`

**原因**: sqlite3 gemがインストールされていない

**解決策**:
```bash
gem install sqlite3
# または
bundle install
```

## 📚 参考情報

### Ruby 3.x の変更点

Ruby 3.0以降、キーワード引数と位置引数の分離が強化されました：

- Ruby 2.x: 位置引数とキーワード引数が自動変換される
- Ruby 3.x: 明示的に区別する必要がある

### SQLite3 gem の変更点

sqlite3 gem 2.0以降では、`execute`メソッドの引数として：

- 単一の値: 配列で渡す `[value]`
- 複数の値: 配列で渡す `[value1, value2, ...]`
- 引数なし: そのまま呼び出す

### 推奨されるバージョン

```ruby
# Gemfile
ruby '3.4.4'
gem 'sinatra', '~> 4.0'
gem 'sqlite3', '~> 2.0'
```

## ✅ チェックリスト

修正が完了したら、以下を確認してください：

- [ ] すべての`execute`呼び出しで引数が配列形式になっている
- [ ] バックアップファイルを作成した
- [ ] `bundle install`を実行した
- [ ] アプリケーションが正常に起動する
- [ ] ゲームの作成ができる
- [ ] スコアの入力ができる
- [ ] ゲームの削除ができる
- [ ] エラーログに警告が出ていない

## 🎯 次のステップ

1. 本番環境への適用前に、十分にテストする
2. 他のRubyバージョンとの互換性を確認する
3. パフォーマンステストを実施する
4. ドキュメントを更新する

---

**作成日**: 2026-03-22  
**対応バージョン**: Ruby 3.4.4  
**修正者**: Claude (Anthropic)
