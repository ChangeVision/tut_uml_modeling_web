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
 state VARCHAR(16) DEFAULT 'WAIT_FOR_1ST' NOT NULL,
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
 state VARCHAR(16) DEFAULT 'RESERVED' NOT NULL,

 PRIMARY KEY (frame_no,score_id),

 FOREIGN KEY (score_id) REFERENCES scores (score_id)
);


