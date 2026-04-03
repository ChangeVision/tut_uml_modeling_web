# frozen_string_literal: true

require 'logger'
require 'sinatra'
require 'sqlite3'
require 'json'
require 'securerandom'

# 静的ファイルの配信設定
set :public_folder, 'public'

# データベース初期化
def init_database
  db = SQLite3::Database.new('bowling.db')
  db.execute_batch <<-SQL
    CREATE TABLE IF NOT EXISTS teams (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS games (
      id TEXT PRIMARY KEY,
      team_id INTEGER,
      start_time DATETIME DEFAULT CURRENT_TIMESTAMP,
      status TEXT DEFAULT 'playing',
      turn_index INTEGER DEFAULT 0,
      FOREIGN KEY (team_id) REFERENCES teams(id)
    );

    CREATE TABLE IF NOT EXISTS players (
      id TEXT PRIMARY KEY,
      game_id TEXT,
      name TEXT NOT NULL,
      player_index INTEGER,
      current_frame INTEGER DEFAULT 1,
      state TEXT DEFAULT 'WAIT_FOR_1ST',
      FOREIGN KEY (game_id) REFERENCES games(id)
    );

    CREATE TABLE IF NOT EXISTS frames (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      player_id TEXT,
      frame_no INTEGER,
      first_roll INTEGER DEFAULT NULL,
      second_roll INTEGER DEFAULT NULL,
      third_roll INTEGER DEFAULT NULL,
      spare_bonus INTEGER DEFAULT 0,
      strike_bonus INTEGER DEFAULT 0,
      total INTEGER DEFAULT 0,
      state TEXT DEFAULT 'RESERVED',
      FOREIGN KEY (player_id) REFERENCES players(id)
    );
  SQL
  db.close
end

# ヘルパーメソッド：投球の表示
helpers do
  def display_roll(frame, roll_type, is_ten_frame: false)
    value = frame.send(roll_type)

    # 未投球チェック
    return '' if value.nil?

    # 10フレームの特殊処理
    if is_ten_frame
      if roll_type == :first
        return '<div class="strike"></div>' if value == 10
        return 'G' if value == 0
        return value.to_s
      elsif roll_type == :second
        return '' if frame.first.nil?

        if frame.first == 10
          # 1投目ストライク後の2投目：新しい組なので0ピンはG
          return '<div class="strike"></div>' if value == 10
          return 'G' if value == 0
          return value.to_s
        else
          # 1投目がストライクでない2投目：残りピンを倒せなかったのでミス
          return '<div class="spare"></div>' if frame.first + value == 10
          return '―' if value == 0
          return value.to_s
        end
      elsif roll_type == :third
        return '' if frame.first.nil? || frame.second.nil?

        # 3投目を投げる条件：ストライクまたはスペアの場合のみ
        prev_total = (frame.first == 10 ? 10 : frame.first) + frame.second

        # ストライクもスペアもない場合は3投目なし
        return '' if prev_total < 10

        # 3投目が未投球の場合（nilまたは初期値0）
        # フレームの状態がFIXEDでない場合は未投球と判断
        return '' if value.nil?
        return '' if value == 0 && frame.state != :FIXED

        # 3投目の表示
        if prev_total >= 10
          return '<div class="strike"></div>' if value == 10
          if frame.second == 10
            # 2投目ストライク：全ピンリセット後なので0はG
            return 'G' if value == 0
            return value.to_s
          elsif frame.first == 10
            # 1投目ストライク、2投目が非ストライク
            if frame.second + value == 10
              # スペア完成：全ピンリセット後なので表示はスペア
              return '<div class="spare"></div>'
            else
              # 残りピンあり → ミス or G
              return '―' if value == 0
              return value.to_s
            end
          else
            # 1・2投目ともに非ストライクでスペア完成（全ピンリセット）
            return 'G' if value == 0
            return value.to_s
          end
        end
        return ''
      end
    end

    # 通常フレーム（1-9フレーム）
    if roll_type == :first
      return '<div class="strike"></div>' if value == 10
      return 'G' if value == 0
      return value.to_s
    elsif roll_type == :second
      return '' if frame.first.nil?
      return '' if frame.first == 10
      return '<div class="spare"></div>' if frame.first + value == 10
      if value == 0
        return 'G' if frame.first == 0
        return '―'
      end
      return value.to_s
    end

    ''
  end
end

# 既存のクラス定義（Frame, Score, Game）
class Frame
  attr_reader :frame_no
  attr_accessor :first, :second, :third, :spare_bonus, :strike_bonus, :total, :state

  def initialize(frame_no, first: nil, second: nil, third: nil, spare_bonus: 0, strike_bonus: 0, total: 0, state: 'RESERVED')
    @frame_no = frame_no
    @first = first
    @second = second
    @third = third
    @spare_bonus = spare_bonus
    @strike_bonus = strike_bonus
    @total = total
    @state = state.to_sym
  end

  def frame_score
    if @frame_no == 10
      (@first || 0) + (@second || 0) + (@third || 0)
    else
      (@first || 0) + (@second || 0) + @spare_bonus + @strike_bonus
    end
  end

  def strike?
    @first == 10
  end

  def spare?
    @first && @second && @first < 10 && (@first + @second) == 10
  end

  def fixed?
    @state == :FIXED
  end
end

class Score
  attr_accessor :id, :player, :fno, :frames, :state

  def initialize(id, name, frames_data = [], fno: 1, state: 'WAIT_FOR_1ST')
    @id = id
    @player = name
    @fno = fno
    @state = state.to_sym
    @frames = []

    if frames_data.empty?
      (-1..13).each do |frame_no|
        @frames << Frame.new(frame_no)
      end
    else
      (-1..13).each do |frame_no|
        frame_data = frames_data.find { |f| f['frame_no'] == frame_no }
        if frame_data
          @frames << Frame.new(frame_no,
            first: frame_data['first_roll'],
            second: frame_data['second_roll'],
            third: frame_data['third_roll'] || 0,
            spare_bonus: frame_data['spare_bonus'],
            strike_bonus: frame_data['strike_bonus'],
            total: frame_data['total'],
            state: frame_data['state']
          )
        else
          @frames << Frame.new(frame_no)
        end
      end
    end
  end

  def fno2idx(fno)
    fno + 1
  end

  def frame(fno)
    @frames[fno2idx(fno)]
  end

  def current
    frame(@fno)
  end

  def prev
    frame(@fno - 1)
  end

  def pprev
    frame(@fno - 2)
  end

  def scoring(pins)
    if @fno == 10
      return scoring_frame_10(pins)
    end

    case @state
    when :WAIT_FOR_1ST
      wait_for_1st_proc(pins)
    when :WAIT_FOR_2ND
      wait_for_2nd_proc(pins)
    when :FINISHED
      return false
    end
    true
  end

  def finished?
    @fno > 10 || (@fno == 10 && frame(10).state == :FIXED)
  end

  private

  def scoring_frame_10(pins)
    frame10 = frame(10)

    case @state
    when :WAIT_FOR_1ST
      frame10.first = pins
      frame10.state = :BEFORE_2ND
      @state = :WAIT_FOR_2ND
      # 9フレームがスペアだったときのボーナス確定
      calc_spare_bonus_after_1st
      # 8・9フレームが連続ストライクのとき8フレームのボーナス確定
      calc_strike_bonus_after_1st
    when :WAIT_FOR_2ND
      frame10.second = pins
      if frame10.strike? || frame10.spare?
        frame10.state = :BEFORE_3RD
        @state = :WAIT_FOR_3RD
      else
        frame10.state = :FIXED
        @state = :FINISHED
      end
      # 9フレームがストライクのときのボーナス確定（10フレーム1投目＋2投目）
      calc_strike_bonus_after_2nd
    when :WAIT_FOR_3RD
      frame10.third = pins
      frame10.state = :FIXED
      @state = :FINISHED
    when :FINISHED
      return false
    end

    update_total
    true
  end

  def wait_for_1st_proc(pins)
    current.first = pins
    current.state = pins == 10 ? :PENDING : :BEFORE_2ND

    calc_spare_bonus_after_1st
    calc_strike_bonus_after_1st
    update_total

    if current.strike?
      @state = :WAIT_FOR_1ST
      @fno += 1
    else
      @state = :WAIT_FOR_2ND
    end
  end

  def wait_for_2nd_proc(pins)
    current.second = pins
    current.state = (current.first + pins == 10) ? :PENDING : :FIXED

    calc_strike_bonus_after_2nd
    update_total

    @state = :WAIT_FOR_1ST
    @fno += 1
  end

  def calc_spare_bonus_after_1st
    return unless prev.spare?
    prev.spare_bonus = current.first
    prev.state = :FIXED
  end

  def calc_strike_bonus_after_1st
    return unless prev.strike? && pprev.strike?
    pprev.strike_bonus = prev.first + current.first
    pprev.state = :FIXED
  end

  def calc_strike_bonus_after_2nd
    return unless prev.strike?
    prev.strike_bonus = current.first + current.second
    prev.state = :FIXED
  end

  def update_total
    @frames.each_cons(2) do |prev_frame, cur_frame|
      cur_frame.total = prev_frame.total + cur_frame.frame_score
    end
  end
end

class Game
  attr_reader :id, :turn, :scores

  def initialize(id, turn_index: 0)
    @id = id
    @turn = turn_index
    @scores = []
  end

  def add_player(score)
    @scores << score
  end

  def current_player
    return nil if @scores.empty?
    @scores[@turn]
  end

  def play(pins)
    player = current_player
    return false unless player

    old_fno = player.fno

    success = player.scoring(pins)
    return false unless success

    should_change_turn = false

    if old_fno <= 9
      if player.fno > old_fno
        should_change_turn = true
      end
    elsif old_fno == 10
      if player.finished?
        should_change_turn = true
      end
    end

    if should_change_turn
      @turn = (@turn + 1) % @scores.size
    end

    true
  end

  def finished?
    @scores.all?(&:finished?)
  end
end

# データベースアクセス関数
def save_game_state(game)
  db = SQLite3::Database.new('bowling.db')

  status = game.finished? ? 'completed' : 'playing'
  db.execute('UPDATE games SET status = ?, turn_index = ? WHERE id = ?',
             [status, game.turn, game.id])

  game.scores.each do |score|
    db.execute('UPDATE players SET current_frame = ?, state = ? WHERE id = ?',
               [score.fno, score.state.to_s, score.id])

    score.frames.each do |frame|
      next if frame.frame_no < 1 || frame.frame_no > 10

      db.execute(<<-SQL, [frame.first, frame.second, frame.third, frame.spare_bonus, frame.strike_bonus, frame.total, frame.state.to_s, score.id, frame.frame_no])
        UPDATE frames SET
          first_roll = ?, second_roll = ?, third_roll = ?, spare_bonus = ?,
          strike_bonus = ?, total = ?, state = ?
        WHERE player_id = ? AND frame_no = ?
      SQL
    end
  end

  db.close
end

def load_game(game_id)
  db = SQLite3::Database.new('bowling.db', results_as_hash: true)

  game_data = db.execute('SELECT * FROM games WHERE id = ?', [game_id]).first
  return nil unless game_data

  game = Game.new(game_id, turn_index: game_data['turn_index'])

  players = db.execute('SELECT * FROM players WHERE game_id = ? ORDER BY player_index', [game_id])

  players.each do |player_data|
    frames = db.execute('SELECT * FROM frames WHERE player_id = ?', [player_data['id']])

    score = Score.new(
      player_data['id'],
      player_data['name'],
      frames,
      fno: player_data['current_frame'],
      state: player_data['state']
    )

    game.add_player(score)
  end

  db.close
  game
end

def validate_pins(player, pins)
  current_frame = player.current

  case player.state
  when :WAIT_FOR_2ND
    if player.fno == 10
      unless current_frame.strike?
        if (current_frame.first || 0) + pins > 10
          return "2投目は#{10 - (current_frame.first || 0)}ピン以下にしてください"
        end
      end
    else
      if (current_frame.first || 0) + pins > 10
        return "2投目は#{10 - (current_frame.first || 0)}ピン以下にしてください"
      end
    end
  when :WAIT_FOR_3RD
    frame10 = player.frame(10)
    if frame10.first != 10 && frame10.second != 10 && (frame10.first || 0) + (frame10.second || 0) != 10
      if (frame10.second || 0) + pins > 10
        return "3投目は#{10 - (frame10.second || 0)}ピン以下にしてください"
      end
    end
  end

  nil
end

configure do
  enable :method_override
  init_database
end

get '/' do
  db = SQLite3::Database.new('bowling.db', results_as_hash: true)
  @games = db.execute(<<-SQL)
    SELECT g.*, GROUP_CONCAT(p.name, ', ') as players
    FROM games g
    LEFT JOIN players p ON g.id = p.game_id
    GROUP BY g.id
    ORDER BY g.start_time DESC
    LIMIT 20
  SQL
  db.close
  erb :index
end

post '/games' do
  player_names = params[:players].split(',').map(&:strip).reject(&:empty?)
  return redirect '/' if player_names.empty?

  game_id = SecureRandom.urlsafe_base64(8)

  db = SQLite3::Database.new('bowling.db')
  db.execute('INSERT INTO games (id) VALUES (?)', [game_id])

  player_names.each_with_index do |name, index|
    player_id = SecureRandom.urlsafe_base64(8)
    db.execute('INSERT INTO players (id, game_id, name, player_index) VALUES (?, ?, ?, ?)',
               [player_id, game_id, name, index])

    (1..10).each do |frame_no|
      db.execute('INSERT INTO frames (player_id, frame_no) VALUES (?, ?)',
                 [player_id, frame_no])
    end
  end

  db.close
  redirect "/games/#{game_id}"
end

get '/games/:id' do
  @game = load_game(params[:id])
  return 'Game not found' unless @game
  erb :game
end

post '/games/:id/play' do
  content_type :json

  pins = params[:pins].to_i
  return { error: 'Invalid pins' }.to_json if pins < 0 || pins > 10

  game = load_game(params[:id])
  return { error: 'Game not found' }.to_json unless game

  player = game.current_player
  return { error: 'No current player' }.to_json unless player

  validation_error = validate_pins(player, pins)
  return { error: validation_error }.to_json if validation_error

  if game.play(pins)
    save_game_state(game)
    {
      success: true,
      current_player: game.current_player&.player,
      finished: game.finished?
    }.to_json
  else
    { error: 'Invalid play' }.to_json
  end
end

post '/games/:id/delete' do
  db = SQLite3::Database.new('bowling.db')
  db.execute('DELETE FROM frames WHERE player_id IN (SELECT id FROM players WHERE game_id = ?)', [params[:id]])
  db.execute('DELETE FROM players WHERE game_id = ?', [params[:id]])
  db.execute('DELETE FROM games WHERE id = ?', [params[:id]])
  db.close
  redirect '/'
end
