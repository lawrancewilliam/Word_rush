-- WORD RUSH - Initial Migration
-- Real-time multiplayer word game

-- ============================================================
-- TABLES
-- ============================================================

CREATE TABLE games (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_number integer UNIQUE NOT NULL,
  status text NOT NULL DEFAULT 'NOT_STARTED',
  max_players integer DEFAULT 20,
  total_questions integer DEFAULT 20,
  current_question_number integer DEFAULT 0,
  current_question_id uuid,
  question_started_at timestamptz,
  question_deadline timestamptz,
  projector_mode text DEFAULT 'WAITING',
  leaderboard_public boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  started_at timestamptz,
  completed_at timestamptz,
  CONSTRAINT valid_status CHECK (status IN ('NOT_STARTED', 'LOBBY_OPEN', 'LOBBY_CLOSED', 'COUNTDOWN', 'PLAYING', 'QUESTION_LOCKED', 'PAUSED', 'COMPLETED')),
  CONSTRAINT valid_projector_mode CHECK (projector_mode IN ('LOBBY', 'COUNTDOWN', 'QUESTION', 'QUESTION_RESULT', 'LEADERBOARD', 'FINAL_RESULT', 'EVENT_CHAMPIONS', 'WAITING')),
  CONSTRAINT valid_game_number CHECK (game_number BETWEEN 1 AND 3)
);

CREATE TABLE players (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id uuid REFERENCES games(id) ON DELETE CASCADE,
  name text NOT NULL,
  department text NOT NULL,
  device_session_id text NOT NULL,
  score integer DEFAULT 0,
  total_response_time_ms bigint DEFAULT 0,
  hints_used integer DEFAULT 0,
  joined_at timestamptz DEFAULT now(),
  is_active boolean DEFAULT true,
  removed_at timestamptz,
  UNIQUE(game_id, device_session_id)
);

CREATE TABLE questions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_number integer NOT NULL,
  question_order integer NOT NULL,
  correct_word text NOT NULL,
  jumbled_word text NOT NULL,
  hint text NOT NULL,
  difficulty text NOT NULL DEFAULT 'EASY',
  category text NOT NULL,
  is_tiebreaker boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  UNIQUE(game_number, question_order),
  CONSTRAINT valid_difficulty CHECK (difficulty IN ('EASY', 'MEDIUM', 'HARD'))
);

CREATE TABLE question_results (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id uuid REFERENCES games(id) ON DELETE CASCADE,
  question_id uuid REFERENCES questions(id) ON DELETE CASCADE,
  winner_player_id uuid REFERENCES players(id) ON DELETE SET NULL,
  answered_at timestamptz,
  response_time_ms bigint,
  point_awarded integer DEFAULT 0,
  result_type text DEFAULT 'NORMAL',
  UNIQUE(game_id, question_id),
  CONSTRAINT valid_result_type CHECK (result_type IN ('NORMAL', 'TIMEOUT', 'SKIPPED', 'TIEBREAKER'))
);

CREATE TABLE device_participation (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_session_id text NOT NULL UNIQUE,
  last_game_number integer,
  participated_at timestamptz DEFAULT now()
);

CREATE TABLE event_settings (
  key TEXT PRIMARY KEY,
  value TEXT,
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE hosts (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX idx_players_game_id ON players(game_id);
CREATE INDEX idx_players_device_session_id ON players(device_session_id);
CREATE INDEX idx_questions_game_number_order ON questions(game_number, question_order);
CREATE INDEX idx_question_results_game_id ON question_results(game_id);
CREATE INDEX idx_question_results_game_question ON question_results(game_id, question_id);
CREATE INDEX idx_question_results_game_winner ON question_results(game_id, winner_player_id);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE games ENABLE ROW LEVEL SECURITY;
ALTER TABLE players ENABLE ROW LEVEL SECURITY;
ALTER TABLE questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE question_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_participation ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE hosts ENABLE ROW LEVEL SECURITY;

-- GAMES: Anyone can read
CREATE POLICY "games_select_public" ON games
  FOR SELECT USING (true);

-- PLAYERS: Players can read their own row and basic info of others in same game
CREATE POLICY "players_select_own" ON players
  FOR SELECT USING (device_session_id = current_setting('request.jwt.claims', true)::json->>'device_session_id');

CREATE POLICY "players_select_game_info" ON players
  FOR SELECT USING (true);

-- QUESTIONS: Players can read jumbled info for active questions only
CREATE POLICY "questions_select_active" ON questions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM games g
      WHERE g.current_question_id = questions.id
      AND g.status IN ('PLAYING', 'QUESTION_LOCKED')
    )
  );

-- QUESTION_RESULTS: Players can read results for their game
CREATE POLICY "question_results_select_game" ON question_results
  FOR SELECT USING (true);
-- DEVICE_PARTICIPATION: Service role only
-- EVENT_SETTINGS: Anyone can read
CREATE POLICY "event_settings_select" ON event_settings
  FOR SELECT USING (true);

-- HOSTS: Authenticated users can read their own row to verify authorization
CREATE POLICY "hosts_select_own" ON hosts
  FOR SELECT USING (auth.uid() = id);

-- ============================================================
-- SEED DATA: QUESTIONS (60 main + 5 tiebreaker)
-- ============================================================

-- GAME 1 (Questions 1-20)
INSERT INTO questions (game_number, question_order, correct_word, jumbled_word, hint, difficulty, category, is_tiebreaker)
VALUES
(1, 1, 'CANTEEN', 'E C A N T E N', 'A place where students buy food during breaks', 'EASY', 'Food', false),
(1, 2, 'LIBRARY', 'R L I B A R Y', 'A quiet place full of books', 'EASY', 'College', false),
(1, 3, 'HOSTEL', 'T L O H S E', 'Where students stay during college years', 'EASY', 'College', false),
(1, 4, 'KEYBOARD', 'D A Y K R B O E', 'You type on this device', 'EASY', 'Technology', false),
(1, 5, 'BROWSER', 'W B R O S R E', 'You use this to surf the internet', 'EASY', 'Technology', false),
(1, 6, 'SANDWICH', 'D S A N W C H I', 'Bread with filling, great for a quick snack', 'EASY', 'Food', false),
(1, 7, 'NOODLES', 'O O N D L E S', 'Long thin strands often served in soup', 'EASY', 'Food', false),
(1, 8, 'CRICKET', 'K R I C C E T', 'A bat and ball sport popular in India', 'EASY', 'Sports', false),
(1, 9, 'CINEMA', 'N I C E M A', 'Where you go to watch movies', 'EASY', 'Entertainment', false),
(1, 10, 'CHAMPION', 'N O I H C M A P', 'The one who wins the final prize', 'MEDIUM', 'General', false),
(1, 11, 'ADVENTURE', 'V E N T U D A R E', 'A thrilling journey into the unknown', 'MEDIUM', 'General', false),
(1, 12, 'MYSTERY', 'R E S Y M T Y', 'A story full of puzzles and secrets', 'MEDIUM', 'Entertainment', false),
(1, 13, 'FOOTBALL', 'O O F T B L L A', 'The world''s most popular sport with goals', 'MEDIUM', 'Sports', false),
(1, 14, 'INTERNET', 'E T N R I N E T', 'The global network connecting everyone', 'MEDIUM', 'Technology', false),
(1, 15, 'PROGRAM', 'R O P G R A M', 'A set of instructions for a computer', 'MEDIUM', 'Technology', false),
(1, 16, 'MOUNTAIN', 'N O U N T A I M', 'A very tall natural landform', 'MEDIUM', 'General', false),
(1, 17, 'DOLPHIN', 'P H I L O D N', 'An intelligent ocean creature', 'MEDIUM', 'General', false),
(1, 18, 'ROBOTICS', 'O R B T O C I S', 'The branch of technology dealing with robots', 'HARD', 'Technology', false),
(1, 19, 'CHEMISTRY', 'Y S T R I M C H E', 'The science of substances and reactions', 'HARD', 'College', false),
(1, 20, 'ALGORITHM', 'R O G H A L T I M', 'A step-by-step procedure for solving a problem', 'HARD', 'Technology', false);

-- GAME 2 (Questions 1-20)
INSERT INTO questions (game_number, question_order, correct_word, jumbled_word, hint, difficulty, category, is_tiebreaker)
VALUES
(2, 1, 'CAFETERIA', 'F A T E C R A I A', 'Another name for a dining hall', 'EASY', 'College', false),
(2, 2, 'BICYCLE', 'I C Y B C L E', 'A two-wheeled vehicle you pedal', 'EASY', 'Sports', false),
(2, 3, 'PUZZLE', 'U P Z L E Z', 'A game that tests your problem-solving', 'EASY', 'Entertainment', false),
(2, 4, 'JUNGLE', 'U L G N E J', 'A dense tropical forest', 'EASY', 'General', false),
(2, 5, 'PENCIL', 'P E N L C I', 'You write and draw with this', 'EASY', 'College', false),
(2, 6, 'MIRROR', 'R O M I R R', 'Shows your reflection', 'EASY', 'General', false),
(2, 7, 'GUITAR', 'I T U G A R', 'A stringed musical instrument', 'EASY', 'Entertainment', false),
(2, 8, 'ISLAND', 'L A N D I S', 'Land completely surrounded by water', 'EASY', 'General', false),
(2, 9, 'VOLCANO', 'C O L V A N O', 'A mountain that can erupt with lava', 'EASY', 'General', false),
(2, 10, 'SYLLABUS', 'S U Y L L A B S', 'Outline of topics covered in a course', 'MEDIUM', 'College', false),
(2, 11, 'TROPHY', 'R O P T H Y', 'An award given to winners', 'MEDIUM', 'Sports', false),
(2, 12, 'BALLOON', 'L O O B L A N', 'Inflatable object filled with air or gas', 'MEDIUM', 'General', false),
(2, 13, 'KITCHEN', 'I T C H K E N', 'Room where food is cooked', 'MEDIUM', 'General', false),
(2, 14, 'PIRATE', 'I P R A T E', 'A seafaring robber of the high seas', 'MEDIUM', 'Entertainment', false),
(2, 15, 'SOLAR', 'L O S A R', 'Related to the sun', 'MEDIUM', 'Technology', false),
(2, 16, 'MARBLE', 'R M A L B E', 'A smooth stone or glass ball for games', 'MEDIUM', 'General', false),
(2, 17, 'OXYGEN', 'G O X Y E N', 'The gas we breathe to survive', 'HARD', 'College', false),
(2, 18, 'BACTERIA', 'I C T A A B E R', 'Microscopic single-celled organisms', 'HARD', 'College', false),
(2, 19, 'QUANTUM', 'T U M Q A N U', 'The smallest discrete unit in physics', 'HARD', 'Technology', false),
(2, 20, 'NEURON', 'O N E U R N', 'A nerve cell that carries information', 'HARD', 'College', false);

-- GAME 3 (Questions 1-20)
INSERT INTO questions (game_number, question_order, correct_word, jumbled_word, hint, difficulty, category, is_tiebreaker)
VALUES
(3, 1, 'AUDITORIUM', 'U D I T O R I A U M', 'A large hall for assemblies and events', 'EASY', 'College', false),
(3, 2, 'TEXTBOOK', 'B O T K E X T T', 'A book used for studying a subject', 'EASY', 'College', false),
(3, 3, 'ARCHERY', 'H A R E Y C R', 'The sport of shooting arrows at a target', 'EASY', 'Sports', false),
(3, 4, 'BUTTON', 'O N T U B T', 'You press this on a screen or shirt', 'EASY', 'Technology', false),
(3, 5, 'GARDEN', 'D A N G E R', 'Where flowers and vegetables grow', 'EASY', 'General', false),
(3, 6, 'CANDLE', 'L E A N D C', 'A wax stick with a wick that gives light', 'EASY', 'General', false),
(3, 7, 'RABBIT', 'B I T R A B', 'A fluffy animal with long ears', 'EASY', 'General', false),
(3, 8, 'SPIRIT', 'I R S P I T', 'The non-physical part of a person', 'EASY', 'General', false),
(3, 9, 'PLANET', 'T A L E N P', 'A celestial body orbiting a star', 'EASY', 'General', false),
(3, 10, 'LECTURE', 'E U L T E C R', 'A talk given to students in a hall', 'MEDIUM', 'College', false),
(3, 11, 'MARATHON', 'A M O R T A H N', 'A very long running race', 'MEDIUM', 'Sports', false),
(3, 12, 'SPACESHIP', 'P H I S S A E C P', 'A vehicle that travels through space', 'MEDIUM', 'Technology', false),
(3, 13, 'WATERFALL', 'A F W L L T A E R', 'Water falling from a great height', 'MEDIUM', 'General', false),
(3, 14, 'BASKETBALL', 'L A B L E T S K B A', 'A sport with hoops and dribbling', 'MEDIUM', 'Sports', false),
(3, 15, 'MAGNETIC', 'C N A M G T I E', 'Something that attracts iron objects', 'MEDIUM', 'General', false),
(3, 16, 'ELABORATE', 'T R E B A L A O E', 'Very detailed and complicated in design', 'HARD', 'General', false),
(3, 17, 'FREQUENCY', 'N Y E F Q R U C E', 'How often something occurs per unit time', 'HARD', 'Technology', false),
(3, 18, 'ARCHITECTURE', 'T U R E A C I H C R T E', 'The art of designing buildings', 'HARD', 'General', false),
(3, 19, 'SPECTRUM', 'M U S P T E C R', 'A band of colors produced by splitting light', 'HARD', 'General', false),
(3, 20, 'SYMPOSIUM', 'U M O Y S I P M S', 'A conference for discussion of a topic', 'HARD', 'College', false);

-- TIEBREAKER QUESTIONS (5 total)
INSERT INTO questions (game_number, question_order, correct_word, jumbled_word, hint, difficulty, category, is_tiebreaker)
VALUES
(1, 21, 'WIZARD', 'I Z W A R D', 'A person who practices magic', 'EASY', 'Entertainment', true),
(2, 21, 'GALAXY', 'A L A X Y G', 'A massive system of stars', 'MEDIUM', 'General', true),
(3, 21, 'PHOENIX', 'O E P H N I X', 'A mythical bird that rises from ashes', 'MEDIUM', 'General', true),
(1, 22, 'LABYRINTH', 'H T N R I B A Y L', 'An elaborate maze', 'HARD', 'General', true),
(2, 22, 'RENAISSANCE', 'E S I N A R S E A N C', 'A period of cultural rebirth in Europe', 'HARD', 'General', true);

-- ============================================================
-- SEED DATA: INITIAL GAMES (3 games)
-- ============================================================

INSERT INTO games (game_number, status) VALUES
(1, 'NOT_STARTED'),
(2, 'NOT_STARTED'),
(3, 'NOT_STARTED');

-- ============================================================
-- POSTGRESQL FUNCTIONS (RPCs)
-- ============================================================

-- Function: join_active_game
CREATE OR REPLACE FUNCTION join_active_game(
  p_name text,
  p_department text,
  p_device_session_id text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game_id uuid;
  v_player_id uuid;
  v_game_record record;
  v_lock_result boolean;
BEGIN
  -- Find the game with LOBBY_OPEN status
  SELECT id, game_number, status, max_players
  INTO v_game_record
  FROM games
  WHERE status = 'LOBBY_OPEN'
  ORDER BY game_number ASC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'NO_GAME_AVAILABLE',
      'message', 'No game lobby is currently open'
    );
  END IF;

  -- Check device hasn't already participated in ANY game
  IF EXISTS (
    SELECT 1 FROM device_participation
    WHERE device_session_id = p_device_session_id
  ) THEN
    RETURN json_build_object(
      'success', false,
      'error', 'ALREADY_PARTICIPATED',
      'message', 'This device has already participated in a game'
    );
  END IF;

  -- Use advisory lock to prevent race conditions on player count
  -- Lock based on game_id to serialize joins for this game
  v_lock_result := pg_try_advisory_xact_lock(
    hashtext('game_join:' || v_game_record.id::text)
  );

  IF NOT v_lock_result THEN
    RETURN json_build_object(
      'success', false,
      'error', 'CONCURRENT_JOIN',
      'message', 'Another join is in progress, please try again'
    );
  END IF;

  -- Re-check player count under lock
  IF (
    SELECT COUNT(*) FROM players
    WHERE game_id = v_game_record.id
  ) >= v_game_record.max_players THEN
    RETURN json_build_object(
      'success', false,
      'error', 'GAME_FULL',
      'message', 'This game has reached maximum capacity'
    );
  END IF;

  -- Check device hasn't joined THIS specific game
  IF EXISTS (
    SELECT 1 FROM players
    WHERE game_id = v_game_record.id
    AND device_session_id = p_device_session_id
  ) THEN
    RETURN json_build_object(
      'success', false,
      'error', 'ALREADY_IN_GAME',
      'message', 'You are already in this game'
    );
  END IF;

  -- Insert player
  INSERT INTO players (game_id, name, department, device_session_id)
  VALUES (v_game_record.id, p_name, p_department, p_device_session_id)
  RETURNING id INTO v_player_id;

  -- Record device participation
  INSERT INTO device_participation (device_session_id, last_game_number)
  VALUES (p_device_session_id, v_game_record.game_number);

  RETURN json_build_object(
    'success', true,
    'game_id', v_game_record.id,
    'player_id', v_player_id,
    'game_number', v_game_record.game_number
  );
END;
$$;

-- Function: submit_answer
CREATE OR REPLACE FUNCTION submit_answer(
  p_game_id uuid,
  p_player_id uuid,
  p_question_id uuid,
  p_answer text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_normalized_answer text;
  v_correct_word text;
  v_game_record record;
  v_question_record record;
  v_player_record record;
  v_result_id uuid;
  v_rows_affected integer;
  v_point_value integer;
BEGIN
  -- Verify player belongs to game and is active
  SELECT * INTO v_player_record
  FROM players
  WHERE id = p_player_id
  AND game_id = p_game_id
  AND is_active = true;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'INVALID_PLAYER',
      'message', 'Player not found or not active in this game'
    );
  END IF;

  -- Verify question belongs to game
  SELECT * INTO v_question_record
  FROM questions
  WHERE id = p_question_id
  AND game_number = (
    SELECT game_number FROM games WHERE id = p_game_id
  );

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'INVALID_QUESTION',
      'message', 'Question does not belong to this game'
    );
  END IF;

  -- Verify game status is PLAYING or QUESTION_LOCKED
  SELECT * INTO v_game_record
  FROM games
  WHERE id = p_game_id
  AND status IN ('PLAYING', 'QUESTION_LOCKED');

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'GAME_NOT_PLAYING',
      'message', 'Game is not currently in playing state'
    );
  END IF;

  -- Verify question_deadline has not passed
  IF v_game_record.question_deadline IS NOT NULL
     AND now() > v_game_record.question_deadline THEN
    RETURN json_build_object(
      'success', false,
      'error', 'QUESTION_EXPIRED',
      'message', 'Time is up for this question'
    );
  END IF;

  -- Normalize answer: trim whitespace, uppercase
  v_normalized_answer := UPPER(TRIM(p_answer));

  -- Get correct word
  v_correct_word := v_question_record.correct_word;

  -- Always award 1 point per correct answer (fixed scoring)
  v_point_value := 1;

  -- Atomic insert: only if no winner yet for this question
  IF v_normalized_answer = v_correct_word THEN
    INSERT INTO question_results (
      game_id, question_id, winner_player_id, answered_at,
      response_time_ms, point_awarded, result_type
    )
    SELECT
      p_game_id,
      p_question_id,
      p_player_id,
      now(),
      EXTRACT(EPOCH FROM (now() - v_game_record.question_started_at)) * 1000,
      v_point_value,
      'NORMAL'
    WHERE NOT EXISTS (
      SELECT 1 FROM question_results
      WHERE question_id = p_question_id
      AND result_type = 'NORMAL'
    )
    ON CONFLICT DO NOTHING;

    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

    IF v_rows_affected = 1 THEN
      -- This player won - update score
      UPDATE players
      SET score = score + v_point_value,
          total_response_time_ms = total_response_time_ms + (
            EXTRACT(EPOCH FROM (now() - v_game_record.question_started_at)) * 1000
          )::bigint
      WHERE id = p_player_id;

      RETURN json_build_object(
        'success', true,
        'correct', true,
        'won', true,
        'points_awarded', v_point_value,
        'response_time_ms', (
          EXTRACT(EPOCH FROM (now() - v_game_record.question_started_at)) * 1000
        )::bigint
      );
    ELSE
      -- Someone else won first
      RETURN json_build_object(
        'success', true,
        'correct', true,
        'won', false,
        'message', 'Another player answered first'
      );
    END IF;
  ELSE
    RETURN json_build_object(
      'success', true,
      'correct', false,
      'won', false,
      'message', 'Incorrect answer'
    );
  END IF;
END;
$$;

-- Function: request_hint
CREATE OR REPLACE FUNCTION request_hint(
  p_game_id uuid,
  p_player_id uuid,
  p_question_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_player_record record;
  v_question_record record;
  v_game_record record;
BEGIN
  -- Verify player belongs to game
  SELECT * INTO v_player_record
  FROM players
  WHERE id = p_player_id
  AND game_id = p_game_id
  AND is_active = true;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'INVALID_PLAYER',
      'message', 'Player not found or not active'
    );
  END IF;

  -- Verify hints_used < 2
  IF v_player_record.hints_used >= 2 THEN
    RETURN json_build_object(
      'success', false,
      'error', 'HINTS_EXHAUSTED',
      'message', 'You have already used all available hints'
    );
  END IF;

  -- Verify question belongs to game
  SELECT * INTO v_question_record
  FROM questions
  WHERE id = p_question_id
  AND game_number = (
    SELECT game_number FROM games WHERE id = p_game_id
  );

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'INVALID_QUESTION',
      'message', 'Question does not belong to this game'
    );
  END IF;

  -- Verify game is in correct state
  SELECT * INTO v_game_record
  FROM games
  WHERE id = p_game_id
  AND status IN ('PLAYING', 'QUESTION_LOCKED');

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'GAME_NOT_PLAYING',
      'message', 'Game is not currently in playing state'
    );
  END IF;

  -- Increment hints_used atomically
  UPDATE players
  SET hints_used = hints_used + 1
  WHERE id = p_player_id;

  RETURN json_build_object(
    'success', true,
    'hint', v_question_record.hint,
    'hints_remaining', 2 - (v_player_record.hints_used + 1)
  );
END;
$$;

-- Function: lock_expired_question
CREATE OR REPLACE FUNCTION lock_expired_question(
  p_game_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game_record record;
  v_question_record record;
  v_result_id uuid;
BEGIN
  -- Find current question for the game
  SELECT * INTO v_game_record
  FROM games
  WHERE id = p_game_id;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'GAME_NOT_FOUND'
    );
  END IF;

  IF v_game_record.current_question_id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'error', 'NO_CURRENT_QUESTION'
    );
  END IF;

  -- Check if deadline has passed and no winner yet
  IF v_game_record.question_deadline IS NOT NULL
     AND now() > v_game_record.question_deadline THEN

    -- Check if there's already a winner
    IF NOT EXISTS (
      SELECT 1 FROM question_results
      WHERE question_id = v_game_record.current_question_id
      AND result_type = 'NORMAL'
    ) THEN
      -- Create TIMEOUT result
      INSERT INTO question_results (
        game_id, question_id, winner_player_id, answered_at,
        response_time_ms, point_awarded, result_type
      )
      VALUES (
        p_game_id,
        v_game_record.current_question_id,
        NULL,
        now(),
        0,
        0,
        'TIMEOUT'
      )
      ON CONFLICT DO NOTHING;
    END IF;

    -- Update game status to QUESTION_LOCKED
    UPDATE games
    SET status = 'QUESTION_LOCKED'
    WHERE id = p_game_id;

    RETURN json_build_object(
      'success', true,
      'locked', true,
      'message', 'Question locked due to timeout'
    );
  ELSE
    RETURN json_build_object(
      'success', true,
      'locked', false,
      'message', 'Question deadline has not yet passed'
    );
  END IF;
END;
$$;

-- Function: get_private_leaderboard
CREATE OR REPLACE FUNCTION get_private_leaderboard(
  p_game_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_agg(row_to_json(t))
  INTO v_result
  FROM (
    SELECT
      ROW_NUMBER() OVER (ORDER BY p.score DESC, p.total_response_time_ms ASC, p.joined_at ASC) as rank,
      p.id as player_id,
      p.name,
      p.department,
      p.score,
      p.total_response_time_ms,
      p.hints_used
    FROM players p
    WHERE p.game_id = p_game_id
    AND p.is_active = true
    ORDER BY p.score DESC, p.total_response_time_ms ASC, p.joined_at ASC
  ) t;

  IF v_result IS NULL THEN
    v_result := '[]'::json;
  END IF;

  RETURN json_build_object(
    'success', true,
    'leaderboard', v_result
  );
END;
$$;

-- Function: reset_game
CREATE OR REPLACE FUNCTION reset_game(
  p_game_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game_record record;
BEGIN
  -- Get game info
  SELECT * INTO v_game_record
  FROM games
  WHERE id = p_game_id;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'GAME_NOT_FOUND'
    );
  END IF;

  -- Delete question results for this game
  DELETE FROM question_results
  WHERE game_id = p_game_id;

  -- Delete players from this game
  DELETE FROM players
  WHERE game_id = p_game_id;

  -- Clear device participation for players who were in this game
  DELETE FROM device_participation
  WHERE last_game_number = v_game_record.game_number;

  -- Reset game status
  UPDATE games
  SET
    status = 'NOT_STARTED',
    current_question_number = 0,
    current_question_id = NULL,
    question_started_at = NULL,
    question_deadline = NULL,
    projector_mode = 'WAITING',
    leaderboard_public = false,
    started_at = NULL,
    completed_at = NULL
  WHERE id = p_game_id;

  RETURN json_build_object(
    'success', true,
    'message', 'Game has been reset'
  );
END;
$$;

-- ============================================================
-- GRANT PERMISSIONS
-- ============================================================

-- Grant execute permissions for the functions
GRANT EXECUTE ON FUNCTION join_active_game(text, text, text) TO anon;
GRANT EXECUTE ON FUNCTION submit_answer(uuid, uuid, uuid, text) TO anon;
GRANT EXECUTE ON FUNCTION request_hint(uuid, uuid, uuid) TO anon;
GRANT EXECUTE ON FUNCTION lock_expired_question(uuid) TO anon;
GRANT EXECUTE ON FUNCTION get_private_leaderboard(uuid) TO anon;
GRANT EXECUTE ON FUNCTION reset_game(uuid) TO anon;

-- Grant table access for RLS
GRANT SELECT ON games TO anon;
GRANT SELECT ON players TO anon;
GRANT SELECT ON questions TO anon;
GRANT SELECT ON question_results TO anon;
GRANT SELECT ON event_settings TO anon;
GRANT SELECT ON hosts TO authenticated;

-- Service role permissions (for admin operations)
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- ============================================================
-- TRIGGER: Auto-update updated_at for event_settings
-- ============================================================

CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER update_event_settings_modtime
  BEFORE UPDATE ON event_settings
  FOR EACH ROW
  EXECUTE FUNCTION update_modified_column();

-- ============================================================
-- FUNCTION: get_server_time (used for client time sync)
-- ============================================================

CREATE OR REPLACE FUNCTION get_server_time()
RETURNS bigint
LANGUAGE sql
STABLE
AS $$
  SELECT EXTRACT(EPOCH FROM now()) * 1000::bigint;
$$;

GRANT EXECUTE ON FUNCTION get_server_time() TO anon;

-- ============================================================
-- END OF MIGRATION
-- ============================================================
