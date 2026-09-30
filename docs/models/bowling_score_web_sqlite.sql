-- Web版スキーマ（SQLite用）
-- bowling_score_web.sql（astahのER図からのエクスポート。オプション「CREATE TABLE文のみを使用する」）に、
-- ドメイン frame_state / score_state の定義に書いた CHECK 制約を state 列へ加えたもの。
-- 外部キーを有効にするには、接続ごとに PRAGMA foreign_keys = ON; が必要。

CREATE TABLE score_sheets (
 score_sheet_id VARCHAR(16) NOT NULL PRIMARY KEY,
 play_date TIMESTAMP(10) NOT NULL
);


CREATE TABLE games (
 game_id VARCHAR(16) NOT NULL PRIMARY KEY,
 turn INT DEFAULT 0 NOT NULL,
 score_sheet_id VARCHAR(16) NOT NULL,

 FOREIGN KEY (score_sheet_id) REFERENCES score_sheets (score_sheet_id)
);


CREATE TABLE scores (
 score_id VARCHAR(16) NOT NULL PRIMARY KEY,
 entry_order INT NOT NULL,
 player_name VARCHAR(50) NOT NULL,
 fno INT DEFAULT 1 NOT NULL,
 state VARCHAR(16) DEFAULT 'WAIT_FOR_1ST' NOT NULL
   CHECK (state IN ('WAIT_FOR_1ST','WAIT_FOR_2ND','FINISHED')),
 game_id VARCHAR(16) NOT NULL,

 FOREIGN KEY (game_id) REFERENCES games (game_id)
);


CREATE TABLE frames (
 frame_no INT NOT NULL,
 score_id VARCHAR(16) NOT NULL,
 first INT DEFAULT 0 NOT NULL,
 second INT DEFAULT 0 NOT NULL,
 spare_bonus INT DEFAULT 0 NOT NULL,
 strike_bonus INT DEFAULT 0 NOT NULL,
 frame_total INT DEFAULT 0 NOT NULL,
 state VARCHAR(16) DEFAULT 'RESERVED' NOT NULL
   CHECK (state IN ('RESERVED','BEFORE_1ST','BEFORE_2ND','PENDING','FIXED')),

 PRIMARY KEY (frame_no,score_id),

 FOREIGN KEY (score_id) REFERENCES scores (score_id)
);


