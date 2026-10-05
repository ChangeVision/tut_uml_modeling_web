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
require 'json'
require_relative 'score'
require_relative 'score_repository'

set :public_folder, File.join(__dir__, 'public')

DB_FILE = File.join(__dir__, 'bowling_web.db')
# ER図（astah）からエクスポートしたSQLに、CHECK制約を加えたもの
SCHEMA_FILE = File.expand_path('../docs/models/bowling_score_web_sqlite.sql', __dir__)

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
