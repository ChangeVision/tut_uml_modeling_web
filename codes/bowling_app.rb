# frozen_string_literal: true

# ボウリングスコアのWebアプリケーション
#
# score.rb のクラス（ScoreSheet, Game, Score, Frame）を変更せずに使う。
# score.rb のメイン処理（テストコード）を、Sinatra のルーティングに置き換えたもの。
#
#   score.rb のメイン処理            Webアプリケーション
#   ScoreSheet.new(Time.now)    ->  起動時（configure）
#   sheet.add_game / game.entry ->  POST /games
#   game.playing(turn, pins)    ->  POST /games/:id/play
#   puts game                   ->  GET  /games/:id
#
# 要件：ゲームの途中からは再開できない。再起動したときには、
#       前のゲームの履歴の参照と、新しいゲームの追加ができる。
# DBはモデルのスナップショット。DBに書き込むのはモデルのオブジェクトだけ。

require 'logger'
require 'sinatra'
require 'sqlite3'
require 'json'
require_relative 'score'

set :public_folder, File.join(__dir__, 'public')

DB_FILE = File.join(__dir__, 'bowling_web.db')
# ER図（astah）からエクスポートしたSQLに、CHECK制約を加えたもの
SCHEMA_FILE = File.expand_path('../docs/models/bowling_score_web_sqlite.sql', __dir__)

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

configure do
  set :repository, ScoreRepository.new(DB_FILE, SCHEMA_FILE)
  sheet = ScoreSheet.new(Time.now) # score.rb のメイン処理と同じく、起動時にスコアシートを作る
  settings.repository.insert_sheet(sheet)
  set :sheet, sheet
end

helpers do
  def repository
    settings.repository
  end

  # 今回の起動中に作ったゲーム（投球できるゲーム）
  def live_game(game_id)
    settings.sheet.games.find { |g| g.id == game_id }
  end

  # 現在のフレームで倒せるピン数の上限（Frameの状態から決まる）
  def max_pins(score)
    frame = score.current
    case frame.state
    when :BEFORE_1ST then 10
    when :BEFORE_2ND then 10 - frame.first
    else 0
    end
  end
end

# スコアボードの表示（見た目のための処理。投球の有無は Frame の状態で判断する）
helpers do
  STRIKE_MARK = '<div class="strike"></div>'
  SPARE_MARK = '<div class="spare"></div>'

  def first_thrown?(frame)
    !%i[RESERVED BEFORE_1ST].include?(frame.state)
  end

  def second_thrown?(frame)
    first_thrown?(frame) && frame.state != :BEFORE_2ND && !frame.strike?
  end

  def first_mark(frame)
    return '' unless first_thrown?(frame)
    return STRIKE_MARK if frame.strike?

    frame.first.zero? ? 'G' : frame.first.to_s
  end

  def second_mark(frame)
    return '' unless second_thrown?(frame)
    return SPARE_MARK if frame.spare?
    return (frame.first.zero? ? 'G' : '―') if frame.second.zero?

    frame.second.to_s
  end

  # 第10フレームの枠には、第10フレームとサービスフレーム（第11・12フレーム）の投球を並べる
  def tenth_marks(score)
    f10, f11, f12 = score.frame(10), score.frame(11), score.frame(12)
    if f10.strike?
      [first_mark(f10), first_mark(f11), f11.strike? ? first_mark(f12) : second_mark(f11)]
    elsif f10.spare?
      [first_mark(f10), second_mark(f10), first_mark(f11)]
    else
      [first_mark(f10), second_mark(f10), '']
    end
  end

  # 得点が確定した（FIXED）フレームだけ累計を表示する
  def frame_total(frame)
    frame.fixed? ? frame.total : ''
  end

  def game_total(score)
    last_fixed = (1..10).map { |fno| score.frame(fno) }.select(&:fixed?).last
    last_fixed ? last_fixed.total : ''
  end
end

get '/' do
  @games = repository.game_summaries.map do |g|
    status = if g['finished'] == 1 then '終了'
             elsif live_game(g['game_id']) then 'プレー中'
             else '中断'
             end
    g.merge('status' => status)
  end
  erb :index
end

# sheet.add_game と game.entry に対応する
post '/games' do
  names = params[:players].to_s.split(/[,、]/).map(&:strip).reject(&:empty?)
  redirect '/' if names.empty?

  sheet = settings.sheet
  sheet.add_game
  game = sheet.games.last
  names.each { |name| game.entry(name) }
  repository.insert_game(sheet, game)
  redirect "/games/#{game.id}"
end

# puts game に対応する（プレー中のゲームも履歴のゲームも同じテンプレートで表示する）
get '/games/:id' do
  @game = live_game(params[:id])
  @live = !@game.nil?
  @game ||= repository.find_game_record(params[:id])
  halt 404, 'ゲームが見つかりません' unless @game
  erb :game
end

# game.playing(turn, pins) に対応する
post '/games/:id/play' do
  content_type :json
  game = live_game(params[:id])
  return { error: 'このゲームには投球できません（中断または終了したゲーム）' }.to_json unless game
  return { error: 'ゲームは終了しています' }.to_json if game.finished?

  score = game.scores[game.turn]
  pins = Integer(params[:pins], exception: false)
  unless pins&.between?(0, max_pins(score))
    return { error: "ピン数は0〜#{max_pins(score)}で指定してください" }.to_json
  end

  game.playing(game.turn, pins)
  repository.update_game(game)
  { success: true, finished: game.finished? }.to_json
end

post '/games/:id/delete' do
  settings.sheet.games.delete_if { |g| g.id == params[:id] }
  repository.delete_game(params[:id])
  redirect '/'
end
