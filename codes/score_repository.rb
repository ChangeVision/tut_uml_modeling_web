# frozen_string_literal: true

# データアクセス層：モデルのオブジェクト（score.rb）とデータベースの間で値を読み書きする
#
# 対応づけ（クラス図 -> ER図）
#   ScoreSheet -> score_sheets, Game -> games, Score -> scores, Frame -> frames
#   Game.scores の並び -> scores.entry_order, Frame は (score_id, frame_no) で識別する
#   保存するフレームは 1〜12（11・12 はサービスフレーム）。-1, 0, 13 は計算用のダミーなので保存しない

require 'sqlite3'
require_relative 'score'

# モデルのオブジェクトとデータベースの間で、値を読み書きするクラス
# （クラス図からER図への対応づけルールを、そのままコードにしたもの）
class ScoreRepository
  SAVED_FRAMES = (1..12) # 第1〜10フレームとサービスフレーム（第11・12フレーム）

  def initialize(db_file, schema_file)
    @db_file = db_file
    create_tables(schema_file)
  end

  # ScoreSheet -> score_sheets
  def insert_sheet(sheet)
    with_db do |db|
      db.execute('INSERT INTO score_sheets (score_sheet_id, play_date) VALUES (?, ?)',
                 [sheet.id, sheet.play_date.strftime('%Y-%m-%d %H:%M:%S')])
    end
  end

  # Game, Score, Frame -> games, scores, frames（ゲームを作ったときに行を作る）
  def insert_game(sheet, game)
    with_db do |db|
      db.transaction do
        db.execute('INSERT INTO games (game_id, score_sheet_id, turn) VALUES (?, ?, ?)',
                   [game.id, sheet.id, game.turn])
        game.scores.each_with_index do |score, entry_order|
          db.execute(<<~SQL, [score.id, game.id, entry_order, score.player, score.fno, score.state.to_s])
            INSERT INTO scores (score_id, game_id, entry_order, player_name, fno, state)
            VALUES (?, ?, ?, ?, ?, ?)
          SQL
          SAVED_FRAMES.each do |fno|
            f = score.frame(fno)
            db.execute(<<~SQL, [fno, score.id, f.first, f.second, f.spare_bonus, f.strike_bonus, f.total, f.state.to_s])
              INSERT INTO frames (frame_no, score_id, first, second, spare_bonus, strike_bonus, frame_total, state)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            SQL
          end
        end
      end
    end
  end

  # 投球のたびに、ゲームのスナップショットを保存する
  def update_game(game)
    with_db do |db|
      db.transaction do
        db.execute('UPDATE games SET turn = ? WHERE game_id = ?', [game.turn, game.id])
        game.scores.each do |score|
          db.execute('UPDATE scores SET fno = ?, state = ? WHERE score_id = ?',
                     [score.fno, score.state.to_s, score.id])
          SAVED_FRAMES.each do |fno|
            f = score.frame(fno)
            db.execute(<<~SQL, [f.first, f.second, f.spare_bonus, f.strike_bonus, f.total, f.state.to_s, score.id, fno])
              UPDATE frames SET first = ?, second = ?, spare_bonus = ?, strike_bonus = ?,
                                frame_total = ?, state = ?
              WHERE score_id = ? AND frame_no = ?
            SQL
          end
        end
      end
    end
  end

  # ゲーム履歴の一覧
  def game_summaries
    with_db do |db|
      db.results_as_hash = true
      db.execute(<<~SQL)
        SELECT g.game_id, ss.play_date,
               (SELECT GROUP_CONCAT(player_name, ', ')
                  FROM (SELECT player_name FROM scores
                         WHERE game_id = g.game_id ORDER BY entry_order)) AS players,
               NOT EXISTS (SELECT 1 FROM scores
                            WHERE game_id = g.game_id AND state <> 'FINISHED') AS finished
          FROM games g JOIN score_sheets ss ON g.score_sheet_id = ss.score_sheet_id
         ORDER BY ss.play_date DESC, g.rowid DESC
      SQL
    end
  end

  # 履歴表示用：DBの行から Score と Frame を組み立てる（表示するだけで、続きは投球できない）
  def find_game_record(game_id)
    with_db do |db|
      db.results_as_hash = true
      row = db.execute('SELECT * FROM games WHERE game_id = ?', [game_id]).first
      next nil unless row

      scores = db.execute('SELECT * FROM scores WHERE game_id = ? ORDER BY entry_order', [game_id]).map do |s|
        score = Score.new(s['player_name'])
        score.id = s['score_id']
        score.fno = s['fno']
        score.state = s['state'].to_sym
        db.execute('SELECT * FROM frames WHERE score_id = ?', [s['score_id']]).each do |fr|
          f = score.frame(fr['frame_no'])
          f.first = fr['first']
          f.second = fr['second']
          f.spare_bonus = fr['spare_bonus']
          f.strike_bonus = fr['strike_bonus']
          f.total = fr['frame_total']
          f.state = fr['state'].to_sym
        end
        score
      end
      GameRecord.new(row['game_id'], row['turn'], scores)
    end
  end

  def delete_game(game_id)
    with_db do |db|
      db.transaction do
        db.execute('DELETE FROM frames WHERE score_id IN (SELECT score_id FROM scores WHERE game_id = ?)', [game_id])
        db.execute('DELETE FROM scores WHERE game_id = ?', [game_id])
        db.execute('DELETE FROM games WHERE game_id = ?', [game_id])
      end
    end
  end

  private

  def with_db
    db = SQLite3::Database.new(@db_file)
    db.execute('PRAGMA foreign_keys = ON') # SQLiteでは接続ごとに外部キーを有効にする
    yield db
  ensure
    db&.close
  end

  def create_tables(schema_file)
    with_db do |db|
      exists = db.get_first_value("SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name = 'score_sheets'")
      db.execute_batch(File.read(schema_file, encoding: 'utf-8')) if exists.zero?
    end
  end
end

# 履歴表示用のゲーム（Game と同じ読み出し方ができるようにしたもの）
GameRecord = Struct.new(:id, :turn, :scores) do
  def finished?
    scores.all?(&:finished?)
  end
end
