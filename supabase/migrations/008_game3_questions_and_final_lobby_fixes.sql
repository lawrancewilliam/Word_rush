-- WORD RUSH - Migration 008: Game 3 Question Polish, Tie Breaker Synced Countdown, Host Security
-- Part A: Game 1 & 2 jumble hardening (18 words) - regenerated with stricter shuffle gates
-- Part B: Game 3 full question replacement (20 words, Freshers-friendly, verified jumbles)
-- Part C: Fix remove_player dangling device_participation reference (table dropped in 002)
-- Part D: Tie-breaker synced COUNTDOWN state + start_tiebreaker_questions + reset_tiebreaker
-- Part E: Host-only authorization on host RPCs (anonymous students must not call host functions)
-- Idempotent - safe to rerun

-- ============================================================
-- PART A: HARDEN GAME 1 & 2 JUMBLES (18 words)
-- All verified: exact anagram, first + last letter moved, no
-- retained 2-letter prefix/suffix, same-position ratio <= 0.5.
-- Correct words, hints, categories unchanged.
-- ============================================================

UPDATE questions SET jumbled_word = 'E N C A T N E' WHERE game_number = 1 AND question_order = 1;
UPDATE questions SET jumbled_word = 'O S W R B R E' WHERE game_number = 1 AND question_order = 5;
UPDATE questions SET jumbled_word = 'K T C E I R C' WHERE game_number = 1 AND question_order = 8;
UPDATE questions SET jumbled_word = 'A M I C E N' WHERE game_number = 1 AND question_order = 9;
UPDATE questions SET jumbled_word = 'T E U D E R V A N' WHERE game_number = 1 AND question_order = 11;
UPDATE questions SET jumbled_word = 'T E Y R S Y M' WHERE game_number = 1 AND question_order = 12;
UPDATE questions SET jumbled_word = 'O L A F T L O B' WHERE game_number = 1 AND question_order = 13;
UPDATE questions SET jumbled_word = 'L D P I N H O' WHERE game_number = 1 AND question_order = 17;
UPDATE questions SET jumbled_word = 'O C S I B T R O' WHERE game_number = 1 AND question_order = 18;

UPDATE questions SET jumbled_word = 'F E I R C A T A E' WHERE game_number = 2 AND question_order = 1;
UPDATE questions SET jumbled_word = 'C L Y I E B C' WHERE game_number = 2 AND question_order = 2;
UPDATE questions SET jumbled_word = 'R R I O R M' WHERE game_number = 2 AND question_order = 6;
UPDATE questions SET jumbled_word = 'S D N I L A' WHERE game_number = 2 AND question_order = 8;
UPDATE questions SET jumbled_word = 'C L O N V O A' WHERE game_number = 2 AND question_order = 9;
UPDATE questions SET jumbled_word = 'B L Y A S L S U' WHERE game_number = 2 AND question_order = 10;
UPDATE questions SET jumbled_word = 'A T I E R P' WHERE game_number = 2 AND question_order = 14;
UPDATE questions SET jumbled_word = 'R C A I A T B E' WHERE game_number = 2 AND question_order = 18;
UPDATE questions SET jumbled_word = 'R N E N U O' WHERE game_number = 2 AND question_order = 20;

-- ============================================================
-- PART B: GAME 3 QUESTION REPLACEMENT (20 questions)
-- Freshers-friendly word bank, all >= 5 letters, verified jumbles.
-- Difficulty ramp: Q1-5 EASY, Q6-10 MEDIUM(stronger), Q11-15 MEDIUM(strong), Q16-20 HARD(strongest).
-- ============================================================

UPDATE questions SET
  correct_word = 'MANGO',
  jumbled_word = 'G M A O N',
  hint = 'A popular sweet fruit that is usually yellow when ripe',
  difficulty = 'EASY',
  category = 'General'
WHERE game_number = 3 AND question_order = 1 AND is_tiebreaker = false;

UPDATE questions SET
  correct_word = 'TIGER',
  jumbled_word = 'G R I T E',
  hint = 'A wild animal known for its black stripes',
  difficulty = 'EASY',
  category = 'Animals'
WHERE game_number = 3 AND question_order = 2 AND is_tiebreaker = false;

UPDATE questions SET
  correct_word = 'TABLE',
  jumbled_word = 'E B T A L',
  hint = 'You keep books and other items on this',
  difficulty = 'EASY',
  category = 'Daily Use'
WHERE game_number = 3 AND question_order = 3 AND is_tiebreaker = false;

UPDATE questions SET
  correct_word = 'HORSE',
  jumbled_word = 'R E H O S',
  hint = 'An animal that people can ride',
  difficulty = 'EASY',
  category = 'Animals'
WHERE game_number = 3 AND question_order = 4 AND is_tiebreaker = false;

UPDATE questions SET
  correct_word = 'CLOCK',
  jumbled_word = 'O C L K C',
  hint = 'It tells you the time',
  difficulty = 'EASY',
  category = 'Daily Use'
WHERE game_number = 3 AND question_order = 5 AND is_tiebreaker = false;

UPDATE questions SET
  correct_word = 'BOTTLE',
  jumbled_word = 'L T B O E T',
  hint = 'Used to carry water or other drinks',
  difficulty = 'MEDIUM',
  category = 'Daily Use'
WHERE game_number = 3 AND question_order = 6 AND is_tiebreaker = false;

UPDATE questions SET
  correct_word = 'MONKEY',
  jumbled_word = 'N E O Y K M',
  hint = 'An animal known for climbing trees',
  difficulty = 'MEDIUM',
  category = 'Animals'
WHERE game_number = 3 AND question_order = 7 AND is_tiebreaker = false;

UPDATE questions SET
  correct_word = 'PENCIL',
  jumbled_word = 'N L E P C I',
  hint = 'Used for writing and can be erased',
  difficulty = 'MEDIUM',
  category = 'College'
WHERE game_number = 3 AND question_order = 8 AND is_tiebreaker = false;

UPDATE questions SET
  correct_word = 'RABBIT',
  jumbled_word = 'B T A R B I',
  hint = 'A small animal with long ears',
  difficulty = 'MEDIUM',
  category = 'Animals'
WHERE game_number = 3 AND question_order = 9 AND is_tiebreaker = false;

UPDATE questions SET
  correct_word = 'POCKET',
  jumbled_word = 'O T E C P K',
  hint = 'A small part of clothing used to carry things',
  difficulty = 'MEDIUM',
  category = 'Daily Use'
WHERE game_number = 3 AND question_order = 10 AND is_tiebreaker = false;

UPDATE questions SET
  correct_word = 'MARKER',
  jumbled_word = 'E R K R A M',
  hint = 'Often used to write on a classroom whiteboard',
  difficulty = 'MEDIUM',
  category = 'College'
WHERE game_number = 3 AND question_order = 11 AND is_tiebreaker = false;

UPDATE questions SET
  correct_word = 'GIRAFFE',
  jumbled_word = 'F R E F G A I',
  hint = 'The tallest living land animal',
  difficulty = 'MEDIUM',
  category = 'Animals'
WHERE game_number = 3 AND question_order = 12 AND is_tiebreaker = false;

UPDATE questions SET
  correct_word = 'WALLET',
  jumbled_word = 'L T E W L A',
  hint = 'Used to carry money and cards',
  difficulty = 'MEDIUM',
  category = 'Daily Use'
WHERE game_number = 3 AND question_order = 13 AND is_tiebreaker = false;

UPDATE questions SET
  correct_word = 'KEYBOARD',
  jumbled_word = 'B D E R Y O K A',
  hint = 'Used to type letters and commands into a computer',
  difficulty = 'MEDIUM',
  category = 'Technology'
WHERE game_number = 3 AND question_order = 14 AND is_tiebreaker = false;

UPDATE questions SET
  correct_word = 'NOTEBOOK',
  jumbled_word = 'O K B O N E T O',
  hint = 'Students use this to write notes',
  difficulty = 'MEDIUM',
  category = 'College'
WHERE game_number = 3 AND question_order = 15 AND is_tiebreaker = false;

UPDATE questions SET
  correct_word = 'ELEPHANT',
  jumbled_word = 'H E T L A N P E',
  hint = 'A very large animal with a trunk',
  difficulty = 'HARD',
  category = 'Animals'
WHERE game_number = 3 AND question_order = 16 AND is_tiebreaker = false;

UPDATE questions SET
  correct_word = 'PROJECTOR',
  jumbled_word = 'J O P T R E O R C',
  hint = 'Used to display a computer screen on a large surface',
  difficulty = 'HARD',
  category = 'College'
WHERE game_number = 3 AND question_order = 17 AND is_tiebreaker = false;

UPDATE questions SET
  correct_word = 'UMBRELLA',
  jumbled_word = 'L R U E M B A L',
  hint = 'Commonly used to protect you from rain',
  difficulty = 'HARD',
  category = 'Daily Use'
WHERE game_number = 3 AND question_order = 18 AND is_tiebreaker = false;

UPDATE questions SET
  correct_word = 'CALCULATOR',
  jumbled_word = 'U O C R A T C L A L',
  hint = 'A device used to perform numerical calculations',
  difficulty = 'HARD',
  category = 'College'
WHERE game_number = 3 AND question_order = 19 AND is_tiebreaker = false;

UPDATE questions SET
  correct_word = 'HEADPHONES',
  jumbled_word = 'N D E P O E S H A H',
  hint = 'Worn over or in the ears to listen to audio privately',
  difficulty = 'HARD',
  category = 'Daily Use'
WHERE game_number = 3 AND question_order = 20 AND is_tiebreaker = false;

-- ============================================================
-- PART C: FIX remove_player (device_participation was dropped in 002)
-- Also add host-authorization guard (Part E security).
-- ============================================================

CREATE OR REPLACE FUNCTION remove_player(p_player_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_player record;
  v_game record;
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (SELECT 1 FROM hosts WHERE id = auth.uid()) THEN
    RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED',
      'message', 'Only the host can perform this action');
  END IF;

  SELECT * INTO v_player FROM players WHERE id = p_player_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'PLAYER_NOT_FOUND');
  END IF;

  SELECT * INTO v_game FROM games WHERE id = v_player.game_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'GAME_NOT_FOUND');
  END IF;

  IF v_game.status NOT IN ('LOBBY_OPEN') THEN
    RETURN json_build_object('success', false, 'error', 'WRONG_STATUS', 'message', 'Can only remove players from open lobby');
  END IF;

  UPDATE players SET is_active = false, removed_at = now() WHERE id = p_player_id;

  RETURN json_build_object('success', true, 'removed_player_id', p_player_id);
END;
$$;

-- ============================================================
-- PART D: TIE-BREAKER SYNCED COUNTDOWN + RESET
-- ============================================================

DO $$
BEGIN
  ALTER TABLE games ADD COLUMN tie_breaker_started_at timestamptz;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

-- Start tie-breaker: enter synced COUNTDOWN phase (host + students count 5..1 together)
CREATE OR REPLACE FUNCTION start_tiebreaker(p_game_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game record;
  v_first_tb_question record;
  v_eligible jsonb;
  v_participant jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (SELECT 1 FROM hosts WHERE id = auth.uid()) THEN
    RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED',
      'message', 'Only the host can perform this action');
  END IF;

  SELECT * INTO v_game FROM games WHERE id = p_game_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'GAME_NOT_FOUND');
  END IF;

  IF v_game.tie_breaker_status != 'LOBBY_OPEN' THEN
    RETURN json_build_object('success', false, 'error', 'NOT_LOBBY_OPEN');
  END IF;

  -- Count eligible (not kicked) participants
  v_eligible := '[]'::jsonb;
  FOR v_participant IN SELECT * FROM jsonb_array_elements(v_game.tie_breaker_participants)
  LOOP
    IF (v_participant->>'is_kicked')::boolean = false THEN
      v_eligible := v_eligible || v_participant;
    END IF;
  END LOOP;

  IF jsonb_array_length(v_eligible) < 2 THEN
    RETURN json_build_object('success', false, 'error', 'INSUFFICIENT_PLAYERS',
      'message', 'Need at least 2 eligible players to start tie-breaker');
  END IF;

  -- Find first tie-breaker question for this game
  SELECT id INTO v_first_tb_question
  FROM questions
  WHERE game_number = v_game.game_number
    AND is_tiebreaker = true
  ORDER BY question_order ASC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'NO_TIEBREAKER_QUESTIONS');
  END IF;

  -- Enter COUNTDOWN (tie_breaker_started_at drives the synced countdown)
  UPDATE games SET
    tie_breaker_status = 'COUNTDOWN',
    tie_breaker_question_number = 1,
    tie_breaker_question_id = v_first_tb_question.id,
    tie_breaker_deadline = NULL,
    tie_breaker_started_at = now(),
    started_at = NULL
  WHERE id = p_game_id;

  RETURN json_build_object(
    'success', true,
    'phase', 'COUNTDOWN',
    'question_number', 1,
    'question_id', v_first_tb_question.id
  );
END;
$$;

-- Host calls this when the 5-second countdown overlay finishes: activates questions
CREATE OR REPLACE FUNCTION start_tiebreaker_questions(p_game_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game record;
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (SELECT 1 FROM hosts WHERE id = auth.uid()) THEN
    RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED',
      'message', 'Only the host can perform this action');
  END IF;

  SELECT * INTO v_game FROM games WHERE id = p_game_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'GAME_NOT_FOUND');
  END IF;

  IF v_game.tie_breaker_status != 'COUNTDOWN' THEN
    RETURN json_build_object('success', false, 'error', 'NOT_COUNTDOWN');
  END IF;

  UPDATE games SET
    tie_breaker_status = 'ACTIVE',
    tie_breaker_deadline = now() + interval '30 seconds',
    started_at = now()
  WHERE id = p_game_id;

  RETURN json_build_object(
    'success', true,
    'phase', 'ACTIVE',
    'question_number', v_game.tie_breaker_question_number,
    'question_id', v_game.tie_breaker_question_id,
    'tie_breaker_deadline', (now() + interval '30 seconds')
  );
END;
$$;

-- Reset a tie breaker (clears participants, results, winner) so a fresh one can run
CREATE OR REPLACE FUNCTION reset_tiebreaker(p_game_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (SELECT 1 FROM hosts WHERE id = auth.uid()) THEN
    RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED',
      'message', 'Only the host can perform this action');
  END IF;

  DELETE FROM question_results
  WHERE game_id = p_game_id AND result_type = 'TIEBREAKER';

  UPDATE games SET
    tie_breaker_status = 'NONE',
    tie_breaker_question_number = 0,
    tie_breaker_question_id = NULL,
    tie_breaker_deadline = NULL,
    tie_breaker_started_at = NULL,
    tie_breaker_winner_id = NULL,
    tie_breaker_participants = '[]'::jsonb
  WHERE id = p_game_id;

  RETURN json_build_object('success', true);
END;
$$;

-- ============================================================
-- PART E: HOST-ONLY AUTHORIZATION FOR HOST RPCS
-- Anonymous students must NOT be able to call host functions.
-- revoke anon + public, grant authenticated (host login session).
-- ============================================================

-- Host auth guard helper (returns unauthorized json if not host)
CREATE OR REPLACE FUNCTION is_host()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT auth.uid() IS NOT NULL
     AND EXISTS (SELECT 1 FROM hosts WHERE id = auth.uid());
$$;

-- open_lobby - add host guard
CREATE OR REPLACE FUNCTION open_lobby(p_game_number integer)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game record;
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (SELECT 1 FROM hosts WHERE id = auth.uid()) THEN
    RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED',
      'message', 'Only the host can perform this action');
  END IF;

  IF p_game_number NOT IN (1, 2, 3) THEN
    RETURN json_build_object(
      'success', false,
      'error', 'INVALID_GAME',
      'message', 'Game number must be 1, 2, or 3'
    );
  END IF;

  SELECT * INTO v_game
  FROM games
  WHERE game_number = p_game_number;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'GAME_NOT_FOUND',
      'message', 'Game not found'
    );
  END IF;

  IF v_game.status NOT IN ('NOT_STARTED', 'COMPLETED') THEN
    RETURN json_build_object(
      'success', false,
      'error', 'INVALID_STATUS',
      'message', 'Game must be not started or completed to open lobby'
    );
  END IF;

  UPDATE games
  SET status = CASE
    WHEN status = 'LOBBY_OPEN' THEN 'LOBBY_CLOSED'
    ELSE status
  END
  WHERE game_number != p_game_number
  AND status = 'LOBBY_OPEN';

  UPDATE games
  SET status = 'LOBBY_OPEN',
      leaderboard_public = false,
      projector_mode = 'LOBBY'
  WHERE game_number = p_game_number;

  RETURN json_build_object(
    'success', true,
    'game_number', p_game_number,
    'message', 'Lobby opened for Game ' || p_game_number
  );
END;
$$;

-- start_game - add host guard
CREATE OR REPLACE FUNCTION start_game(p_game_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game record;
  v_first_question record;
  v_lock_result boolean;
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (SELECT 1 FROM hosts WHERE id = auth.uid()) THEN
    RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED',
      'message', 'Only the host can perform this action');
  END IF;

  -- Advisory lock to prevent concurrent starts
  v_lock_result := pg_try_advisory_xact_lock(
    hashtext('start_game:' || p_game_id::text)
  );

  IF NOT v_lock_result THEN
    RETURN json_build_object('success', false, 'error', 'CONCURRENT_START');
  END IF;

  SELECT * INTO v_game
  FROM games
  WHERE id = p_game_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'GAME_NOT_FOUND');
  END IF;

  -- Only start from COUNTDOWN or LOBBY_CLOSED status
  IF v_game.status NOT IN ('COUNTDOWN', 'LOBBY_CLOSED') THEN
    RETURN json_build_object('success', false, 'error', 'INVALID_STATUS', 'status', v_game.status);
  END IF;

  -- Find first non-tiebreaker question for this game
  SELECT id, question_order INTO v_first_question
  FROM questions
  WHERE game_number = v_game.game_number
    AND is_tiebreaker = false
    AND question_order = 1
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'NO_QUESTIONS_FOUND');
  END IF;

  -- Atomically set all game state for Question 1
  UPDATE games
  SET status = 'PLAYING',
      current_question_number = 1,
      current_question_id = v_first_question.id,
      question_started_at = now(),
      question_deadline = now() + interval '30 seconds',
      projector_mode = 'QUESTION',
      paused_remaining_ms = NULL
  WHERE id = p_game_id;

  RETURN json_build_object(
    'success', true,
    'question_number', 1,
    'question_id', v_first_question.id,
    'question_deadline', (now() + interval '30 seconds')
  );
END;
$$;

-- reset_game - add host guard + clear tie-breaker state
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
  IF auth.uid() IS NULL OR NOT EXISTS (SELECT 1 FROM hosts WHERE id = auth.uid()) THEN
    RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED',
      'message', 'Only the host can perform this action');
  END IF;

  SELECT * INTO v_game_record
  FROM games
  WHERE id = p_game_id;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'GAME_NOT_FOUND'
    );
  END IF;

  DELETE FROM question_results WHERE game_id = p_game_id;
  DELETE FROM players WHERE game_id = p_game_id;

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
    completed_at = NULL,
    tie_breaker_status = 'NONE',
    tie_breaker_question_number = 0,
    tie_breaker_question_id = NULL,
    tie_breaker_deadline = NULL,
    tie_breaker_started_at = NULL,
    tie_breaker_winner_id = NULL,
    tie_breaker_participants = '[]'::jsonb
  WHERE id = p_game_id;

  RETURN json_build_object(
    'success', true,
    'message', 'Game has been reset'
  );
END;
$$;

-- open_tiebreaker_lobby - add host guard
CREATE OR REPLACE FUNCTION open_tiebreaker_lobby(p_game_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game record;
  v_top_score integer;
  v_tied_players jsonb;
  v_player record;
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (SELECT 1 FROM hosts WHERE id = auth.uid()) THEN
    RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED',
      'message', 'Only the host can perform this action');
  END IF;

  SELECT * INTO v_game FROM games WHERE id = p_game_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'GAME_NOT_FOUND');
  END IF;

  IF v_game.status != 'COMPLETED' THEN
    RETURN json_build_object('success', false, 'error', 'NOT_COMPLETED');
  END IF;

  SELECT COALESCE(MAX(score), 0) INTO v_top_score
  FROM players WHERE game_id = p_game_id AND is_active = true;

  IF v_top_score = 0 THEN
    RETURN json_build_object('success', false, 'error', 'NO_SCORES');
  END IF;

  v_tied_players := '[]'::jsonb;
  FOR v_player IN
    SELECT id, name, score FROM players
    WHERE game_id = p_game_id AND is_active = true AND score = v_top_score
    ORDER BY joined_at ASC
  LOOP
    v_tied_players := v_tied_players || jsonb_build_object(
      'player_id', v_player.id,
      'name', v_player.name,
      'score', v_player.score,
      'is_kicked', false
    );
  END LOOP;

  IF jsonb_array_length(v_tied_players) < 2 THEN
    RETURN json_build_object('success', false, 'error', 'NO_TIE', 'message', 'No tie detected at top score');
  END IF;

  UPDATE games SET
    tie_breaker_status = 'LOBBY_OPEN',
    tie_breaker_participants = v_tied_players,
    tie_breaker_question_number = 0,
    tie_breaker_question_id = NULL,
    tie_breaker_deadline = NULL,
    tie_breaker_started_at = NULL,
    tie_breaker_winner_id = NULL
  WHERE id = p_game_id;

  RETURN json_build_object(
    'success', true,
    'participants', v_tied_players,
    'top_score', v_top_score
  );
END;
$$;

-- cancel_tiebreaker - add host guard
CREATE OR REPLACE FUNCTION cancel_tiebreaker(p_game_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (SELECT 1 FROM hosts WHERE id = auth.uid()) THEN
    RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED',
      'message', 'Only the host can perform this action');
  END IF;

  UPDATE games SET
    tie_breaker_status = 'NONE',
    tie_breaker_question_number = 0,
    tie_breaker_question_id = NULL,
    tie_breaker_deadline = NULL,
    tie_breaker_started_at = NULL,
    tie_breaker_winner_id = NULL,
    tie_breaker_participants = '[]'::jsonb
  WHERE id = p_game_id;

  RETURN json_build_object('success', true);
END;
$$;

-- kick_tiebreaker_player - add host guard
CREATE OR REPLACE FUNCTION kick_tiebreaker_player(p_game_id uuid, p_player_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game record;
  v_updated jsonb;
  v_participant jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (SELECT 1 FROM hosts WHERE id = auth.uid()) THEN
    RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED',
      'message', 'Only the host can perform this action');
  END IF;

  SELECT * INTO v_game FROM games WHERE id = p_game_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'GAME_NOT_FOUND');
  END IF;

  IF v_game.tie_breaker_status != 'LOBBY_OPEN' THEN
    RETURN json_build_object('success', false, 'error', 'NOT_LOBBY_OPEN');
  END IF;

  v_updated := '[]'::jsonb;
  FOR v_participant IN SELECT * FROM jsonb_array_elements(v_game.tie_breaker_participants)
  LOOP
    IF (v_participant->>'player_id')::uuid = p_player_id THEN
      v_participant := v_participant || '{"is_kicked": true}'::jsonb;
    END IF;
    v_updated := v_updated || v_participant;
  END LOOP;

  UPDATE games SET tie_breaker_participants = v_updated WHERE id = p_game_id;

  RETURN json_build_object('success', true, 'participants', v_updated);
END;
$$;

-- ============================================================
-- GRANTS: HOST RPCs = authenticated only (never anon)
-- Student RPCs (join_game, submit_answer, request_hint,
-- advance_question, lock_expired_question, get_active_question,
-- submit_tiebreaker_answer, advance_tiebreaker,
-- lock_expired_tiebreaker, get_server_time) remain anon.
-- ============================================================

REVOKE EXECUTE ON FUNCTION open_lobby(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION open_lobby(integer) TO authenticated;

REVOKE EXECUTE ON FUNCTION start_game(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION start_game(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION reset_game(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION reset_game(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION remove_player(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION remove_player(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION open_tiebreaker_lobby(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION open_tiebreaker_lobby(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION start_tiebreaker(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION start_tiebreaker(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION start_tiebreaker_questions(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION start_tiebreaker_questions(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION reset_tiebreaker(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION reset_tiebreaker(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION cancel_tiebreaker(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION cancel_tiebreaker(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION kick_tiebreaker_player(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION kick_tiebreaker_player(uuid, uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION get_private_leaderboard(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_private_leaderboard(uuid) TO authenticated;

-- ============================================================
-- END OF MIGRATION 008
-- ============================================================