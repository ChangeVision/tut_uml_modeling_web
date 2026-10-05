# frozen_string_literal: true

# サンプルデータベース（bowling_sample.db）を作るスクリプト
#
# score.rb のモデルでゲームを進め、ScoreRepository で保存する。
# アプリケーションと同じく、DBに書き込むのはモデルのオブジェクトだけ。
#
#   使い方: ruby make_sample_db.rb

require_relative 'score'
require_relative 'score_repository'

SAMPLE_DB = File.join(__dir__, 'bowling_sample.db')
SCHEMA_FILE = File.expand_path('../docs/models/bowling_score_web_sqlite.sql', __dir__)

# ゲームを作り、ピン数の記録を順に投げる。stop_after を指定すると、その投球数で止める（中断したゲーム）
def play_game(repository, sheet, names, records, stop_after: nil)
  sheet.add_game
  game = sheet.games.last
  names.each { |name| game.entry(name) }
  repository.insert_game(sheet, game)

  records = records.map(&:dup)
  throws = 0
  until game.finished? || (stop_after && throws >= stop_after)
    score_index = game.turn
    game.playing(score_index, records[score_index].shift)
    repository.update_game(game)
    throws += 1
  end
  game
end

File.delete(SAMPLE_DB) if File.exist?(SAMPLE_DB)
repository = ScoreRepository.new(SAMPLE_DB, SCHEMA_FILE)
sheet = ScoreSheet.new(Time.now)
repository.insert_sheet(sheet)

games = [
  # score.rb のテストデータ（1人目が第10フレームでストライクもスペアもとれずに終わる）
  play_game(repository, sheet, %w[くぼあき うえはら],
            [[6, 3, 9, 0, 0, 3, 8, 2, 7, 3, 10, 9, 1, 8, 0, 10, 6, 3],
             [7, 0, 5, 5, 10, 10, 5, 4, 10, 7, 3, 5, 4, 7, 3, 7, 3, 4]]),
  # 第10フレームのサービスフレームを使うゲーム（パーフェクトを含む）
  play_game(repository, sheet, %w[くぼあき うえはら],
            [[6, 3, 9, 0, 0, 3, 8, 2, 7, 3, 10, 9, 1, 8, 0, 10, 10, 6, 4],
             [10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10]]),
  # 途中で止めたゲーム（アプリケーションでは「中断」として表示される）
  play_game(repository, sheet, %w[たなか すずき],
            [[10, 7, 3, 9, 0, 10],
             [5, 4, 8, 2, 10, 6, 3]],
            stop_after: 7)
]

games.each do |game|
  scores = game.scores.map { |s| "#{s.player}: #{s.finished? ? s.frame(10).total : '途中'}" }
  puts "Game(id:#{game.id}) #{scores.join(', ')}"
end
puts "#{SAMPLE_DB} を作成しました。"
