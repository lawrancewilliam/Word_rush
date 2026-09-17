-- WORD RUSH - Migration 007: Tie Breaker Lobby, Kick Out, Improved Jumbles
-- Part A: Stronger jumbled words (65 UPDATEs)
-- Part B: Tie-breaker lobby schema + RPCs
-- Part C: Kick-out for all lobbies (fix remove_player host auth)
-- Idempotent - safe to rerun

-- ============================================================
-- PART A: IMPROVED JUMBLED WORDS
-- ============================================================

-- GAME 1 - Moderate (Q1-5), Moderate/Strong (Q6-10), Strong (Q11-15), Strongest (Q16-20)
UPDATE questions SET jumbled_word = 'N E T C E A N' WHERE game_number = 1 AND question_order = 1;
UPDATE questions SET jumbled_word = 'Y B R I A L R' WHERE game_number = 1 AND question_order = 2;
UPDATE questions SET jumbled_word = 'L S T O E H' WHERE game_number = 1 AND question_order = 3;
UPDATE questions SET jumbled_word = 'B R D K A Y O E' WHERE game_number = 1 AND question_order = 4;
UPDATE questions SET jumbled_word = 'S R B W E O R' WHERE game_number = 1 AND question_order = 5;
UPDATE questions SET jumbled_word = 'W A N C S H D I' WHERE game_number = 1 AND question_order = 6;
UPDATE questions SET jumbled_word = 'L D S O N E O' WHERE game_number = 1 AND question_order = 7;
UPDATE questions SET jumbled_word = 'K E C C I R T' WHERE game_number = 1 AND question_order = 8;
UPDATE questions SET jumbled_word = 'N I E C M A' WHERE game_number = 1 AND question_order = 9;
UPDATE questions SET jumbled_word = 'P M A H I C N O' WHERE game_number = 1 AND question_order = 10;
UPDATE questions SET jumbled_word = 'R U D E V A N T E' WHERE game_number = 1 AND question_order = 11;
UPDATE questions SET jumbled_word = 'S T Y M E R Y' WHERE game_number = 1 AND question_order = 12;
UPDATE questions SET jumbled_word = 'O L F T A B O L' WHERE game_number = 1 AND question_order = 13;
UPDATE questions SET jumbled_word = 'T N E R I T E N' WHERE game_number = 1 AND question_order = 14;
UPDATE questions SET jumbled_word = 'G O M R R A P' WHERE game_number = 1 AND question_order = 15;
UPDATE questions SET jumbled_word = 'T N U M O A N I' WHERE game_number = 1 AND question_order = 16;
UPDATE questions SET jumbled_word = 'P H D I L O N' WHERE game_number = 1 AND question_order = 17;
UPDATE questions SET jumbled_word = 'O C B T R O I S' WHERE game_number = 1 AND question_order = 18;
UPDATE questions SET jumbled_word = 'Y M C H I T S R E' WHERE game_number = 1 AND question_order = 19;
UPDATE questions SET jumbled_word = 'R I G O T L A M H' WHERE game_number = 1 AND question_order = 20;

-- GAME 2
UPDATE questions SET jumbled_word = 'C R A F E T E I A' WHERE game_number = 2 AND question_order = 1;
UPDATE questions SET jumbled_word = 'Y C L B I C E' WHERE game_number = 2 AND question_order = 2;
UPDATE questions SET jumbled_word = 'Z P L Z E U' WHERE game_number = 2 AND question_order = 3;
UPDATE questions SET jumbled_word = 'N G E L U J' WHERE game_number = 2 AND question_order = 4;
UPDATE questions SET jumbled_word = 'N E C P L I' WHERE game_number = 2 AND question_order = 5;
UPDATE questions SET jumbled_word = 'R M O I R R' WHERE game_number = 2 AND question_order = 6;
UPDATE questions SET jumbled_word = 'A U G R T I' WHERE game_number = 2 AND question_order = 7;
UPDATE questions SET jumbled_word = 'S I L N A D' WHERE game_number = 2 AND question_order = 8;
UPDATE questions SET jumbled_word = 'V O N A L C O' WHERE game_number = 2 AND question_order = 9;
UPDATE questions SET jumbled_word = 'Y S U B A L L S' WHERE game_number = 2 AND question_order = 10;
UPDATE questions SET jumbled_word = 'H Y T R O P' WHERE game_number = 2 AND question_order = 11;
UPDATE questions SET jumbled_word = 'A B L N L O O' WHERE game_number = 2 AND question_order = 12;
UPDATE questions SET jumbled_word = 'C H E K T N I' WHERE game_number = 2 AND question_order = 13;
UPDATE questions SET jumbled_word = 'P A R T E I' WHERE game_number = 2 AND question_order = 14;
UPDATE questions SET jumbled_word = 'R L O S A' WHERE game_number = 2 AND question_order = 15;
UPDATE questions SET jumbled_word = 'B A E L R M' WHERE game_number = 2 AND question_order = 16;
UPDATE questions SET jumbled_word = 'X E Y G N O' WHERE game_number = 2 AND question_order = 17;
UPDATE questions SET jumbled_word = 'A C B I R T E A' WHERE game_number = 2 AND question_order = 18;
UPDATE questions SET jumbled_word = 'N A U Q T M U' WHERE game_number = 2 AND question_order = 19;
UPDATE questions SET jumbled_word = 'N O E R U N' WHERE game_number = 2 AND question_order = 20;

-- GAME 3
UPDATE questions SET jumbled_word = 'O R T A U D I M I U' WHERE game_number = 3 AND question_order = 1;
UPDATE questions SET jumbled_word = 'K E B T O X O T' WHERE game_number = 3 AND question_order = 2;
UPDATE questions SET jumbled_word = 'R C H A R E Y' WHERE game_number = 3 AND question_order = 3;
UPDATE questions SET jumbled_word = 'N U T B T O' WHERE game_number = 3 AND question_order = 4;
UPDATE questions SET jumbled_word = 'R E D A G N' WHERE game_number = 3 AND question_order = 5;
UPDATE questions SET jumbled_word = 'D A L E C N' WHERE game_number = 3 AND question_order = 6;
UPDATE questions SET jumbled_word = 'R A B B I T' WHERE game_number = 3 AND question_order = 7;
UPDATE questions SET jumbled_word = 'P R I S T I' WHERE game_number = 3 AND question_order = 8;
UPDATE questions SET jumbled_word = 'P L A N E T' WHERE game_number = 3 AND question_order = 9;
UPDATE questions SET jumbled_word = 'T U L E C R E' WHERE game_number = 3 AND question_order = 10;
UPDATE questions SET jumbled_word = 'N A M A R T O H' WHERE game_number = 3 AND question_order = 11;
UPDATE questions SET jumbled_word = 'C P A E S H I P S' WHERE game_number = 3 AND question_order = 12;
UPDATE questions SET jumbled_word = 'W E R F A L L A T' WHERE game_number = 3 AND question_order = 13;
UPDATE questions SET jumbled_word = 'S A L B B E T K L A' WHERE game_number = 3 AND question_order = 14;
UPDATE questions SET jumbled_word = 'I M C A G N E T' WHERE game_number = 3 AND question_order = 15;
UPDATE questions SET jumbled_word = 'B E L A T R O E A' WHERE game_number = 3 AND question_order = 16;
UPDATE questions SET jumbled_word = 'C R E F Q U E N Y' WHERE game_number = 3 AND question_order = 17;
UPDATE questions SET jumbled_word = 'R I C H A R T E C E T U' WHERE game_number = 3 AND question_order = 18;
UPDATE questions SET jumbled_word = 'T R E C P S U M' WHERE game_number = 3 AND question_order = 19;
UPDATE questions SET jumbled_word = 'O Y S M I U P M S' WHERE game_number = 3 AND question_order = 20;

-- TIEBREAKER QUESTIONS
UPDATE questions SET jumbled_word = 'D A R W I Z' WHERE game_number = 1 AND question_order = 21 AND is_tiebreaker = true;
UPDATE questions SET jumbled_word = 'Y G A X A L' WHERE game_number = 2 AND question_order = 21 AND is_tiebreaker = true;
UPDATE questions SET jumbled_word = 'H N P I E X O' WHERE game_number = 3 AND question_order = 21 AND is_tiebreaker = true;
UPDATE questions SET jumbled_word = 'B I Y R A H N L T' WHERE game_number = 1 AND question_order = 22 AND is_tiebreaker = true;
UPDATE questions SET jumbled_word = 'A I E N R S A E N C S' WHERE game_number = 2 AND question_order = 22 AND is_tiebreaker = true;

-- ============================================================
-- PART B: TIE-BREAKER LOBBY SCHEMA
-- ============================================================

DO $$
BEGIN
  ALTER TABLE games ADD COLUMN tie_breaker_status text DEFAULT 'NONE';
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE games ADD COLUMN tie_breaker_question_number integer DEFAULT 0;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE games ADD COLUMN tie_breaker_question_id uuid;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE games ADD COLUMN tie_breaker_deadline timestamptz;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE games ADD COLUMN tie_breaker_winner_id uuid REFERENCES players(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE games ADD COLUMN tie_breaker_participants jsonb DEFAULT '[]'::jsonb;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

-- ============================================================
-- PART C: FIX remove_player HOST AUTH
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

  DELETE FROM device_participation WHERE device_session_id = v_player.device_session_id;

  RETURN json_build_object('success', true, 'removed_player_id', p_player_id);
END;
$$;

-- ============================================================
-- TIE-BREAKER RPCs
-- ============================================================

-- Open tie-breaker lobby
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
    tie_breaker_winner_id = NULL
  WHERE id = p_game_id;

  RETURN json_build_object(
    'success', true,
    'participants', v_tied_players,
    'top_score', v_top_score
  );
END;
$$;

-- Start tie-breaker
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

  UPDATE games SET
    tie_breaker_status = 'ACTIVE',
    tie_breaker_question_number = 1,
    tie_breaker_question_id = v_first_tb_question.id,
    tie_breaker_deadline = now() + interval '30 seconds',
    started_at = now()
  WHERE id = p_game_id;

  RETURN json_build_object(
    'success', true,
    'question_number', 1,
    'question_id', v_first_tb_question.id
  );
END;
$$;

-- Submit tie-breaker answer
CREATE OR REPLACE FUNCTION submit_tiebreaker_answer(
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
  v_game record;
  v_question record;
  v_player record;
  v_normalized text;
  v_rows_affected integer;
  v_response_ms bigint;
  v_participant jsonb;
  v_is_eligible boolean := false;
BEGIN
  SELECT * INTO v_game FROM games WHERE id = p_game_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'GAME_NOT_FOUND');
  END IF;

  IF v_game.tie_breaker_status != 'ACTIVE' THEN
    RETURN json_build_object('success', false, 'error', 'NOT_ACTIVE');
  END IF;

  IF v_game.tie_breaker_winner_id IS NOT NULL THEN
    RETURN json_build_object('success', false, 'error', 'WINNER_EXISTS');
  END IF;

  IF v_game.tie_breaker_deadline IS NOT NULL AND now() > v_game.tie_breaker_deadline THEN
    RETURN json_build_object('success', false, 'error', 'QUESTION_EXPIRED');
  END IF;

  IF v_game.tie_breaker_question_id IS NULL OR v_game.tie_breaker_question_id != p_question_id THEN
    RETURN json_build_object('success', false, 'error', 'WRONG_QUESTION');
  END IF;

  -- Verify player is eligible (in participants and not kicked)
  FOR v_participant IN SELECT * FROM jsonb_array_elements(v_game.tie_breaker_participants)
  LOOP
    IF (v_participant->>'player_id')::uuid = p_player_id
       AND (v_participant->>'is_kicked')::boolean = false THEN
      v_is_eligible := true;
      EXIT;
    END IF;
  END LOOP;

  IF NOT v_is_eligible THEN
    RETURN json_build_object('success', false, 'error', 'NOT_ELIGIBLE',
      'message', 'You are not eligible for this tie-breaker');
  END IF;

  -- Verify player is active
  SELECT * INTO v_player FROM players
  WHERE id = p_player_id AND game_id = p_game_id AND is_active = true;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'INVALID_PLAYER');
  END IF;

  -- Get question
  SELECT * INTO v_question FROM questions WHERE id = p_question_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'QUESTION_NOT_FOUND');
  END IF;

  v_normalized := UPPER(TRIM(p_answer));

  IF v_game.started_at IS NOT NULL THEN
    v_response_ms := (EXTRACT(EPOCH FROM (now() - v_game.started_at)) * 1000)::bigint;
  ELSE
    v_response_ms := 0;
  END IF;

  IF v_normalized = v_question.correct_word THEN
    INSERT INTO question_results (
      game_id, question_id, winner_player_id, answered_at,
      response_time_ms, point_awarded, result_type
    )
    VALUES (
      p_game_id, p_question_id, p_player_id, now(),
      v_response_ms, 0, 'TIEBREAKER'
    )
    ON CONFLICT DO NOTHING;

    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

    IF v_rows_affected = 1 THEN
      UPDATE games SET
        tie_breaker_status = 'COMPLETED',
        tie_breaker_winner_id = p_player_id
      WHERE id = p_game_id;

      RETURN json_build_object(
        'success', true, 'correct', true, 'won', true,
        'response_time_ms', v_response_ms
      );
    ELSE
      RETURN json_build_object(
        'success', true, 'correct', true, 'won', false,
        'message', 'Another player answered first'
      );
    END IF;
  ELSE
    RETURN json_build_object(
      'success', true, 'correct', false, 'won', false,
      'message', 'Incorrect answer'
    );
  END IF;
END;
$$;

-- Advance tie-breaker question (on timeout)
CREATE OR REPLACE FUNCTION advance_tiebreaker(p_game_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game record;
  v_next_q record;
  v_lock boolean;
BEGIN
  v_lock := pg_try_advisory_xact_lock(hashtext('advance_tb:' || p_game_id::text));
  IF NOT v_lock THEN
    RETURN json_build_object('success', false, 'error', 'CONCURRENT_ADVANCE');
  END IF;

  SELECT * INTO v_game FROM games WHERE id = p_game_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'GAME_NOT_FOUND');
  END IF;

  IF v_game.tie_breaker_status != 'ACTIVE' THEN
    RETURN json_build_object('success', false, 'error', 'NOT_ACTIVE');
  END IF;

  IF v_game.tie_breaker_winner_id IS NOT NULL THEN
    RETURN json_build_object('success', false, 'error', 'WINNER_EXISTS');
  END IF;

  -- Check reveal delay (2 seconds since answer/lock)
  IF EXISTS (
    SELECT 1 FROM question_results
    WHERE game_id = p_game_id AND question_id = v_game.tie_breaker_question_id
  ) THEN
    IF (now() - (SELECT answered_at FROM question_results
        WHERE game_id = p_game_id AND question_id = v_game.tie_breaker_question_id
        LIMIT 1)) < interval '2 seconds' THEN
      RETURN json_build_object('success', false, 'error', 'REVEAL_PENDING');
    END IF;
  END IF;

  -- Check if there are more tie-breaker questions
  SELECT id INTO v_next_q
  FROM questions
  WHERE game_number = v_game.game_number
    AND is_tiebreaker = true
    AND question_order > (
      SELECT COALESCE(MAX(question_order), 20)
      FROM questions
      WHERE id = v_game.tie_breaker_question_id
    )
  ORDER BY question_order ASC
  LIMIT 1;

  IF NOT FOUND THEN
    -- All tie-breakers exhausted
    UPDATE games SET tie_breaker_status = 'UNRESOLVED'
    WHERE id = p_game_id;
    RETURN json_build_object('success', true, 'action', 'EXHAUSTED');
  END IF;

  UPDATE games SET
    tie_breaker_question_number = v_game.tie_breaker_question_number + 1,
    tie_breaker_question_id = v_next_q.id,
    tie_breaker_deadline = now() + interval '30 seconds'
  WHERE id = p_game_id;

  RETURN json_build_object(
    'success', true,
    'action', 'ADVANCED',
    'question_number', v_game.tie_breaker_question_number + 1
  );
END;
$$;

-- Lock expired tie-breaker question
CREATE OR REPLACE FUNCTION lock_expired_tiebreaker(p_game_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game record;
BEGIN
  SELECT * INTO v_game FROM games WHERE id = p_game_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'GAME_NOT_FOUND');
  END IF;

  IF v_game.tie_breaker_status != 'ACTIVE' THEN
    RETURN json_build_object('success', false, 'error', 'NOT_ACTIVE');
  END IF;

  IF v_game.tie_breaker_winner_id IS NOT NULL THEN
    RETURN json_build_object('success', false, 'error', 'WINNER_EXISTS');
  END IF;

  IF v_game.tie_breaker_deadline IS NOT NULL AND now() > v_game.tie_breaker_deadline THEN
    IF NOT EXISTS (
      SELECT 1 FROM question_results
      WHERE game_id = p_game_id
        AND question_id = v_game.tie_breaker_question_id
        AND result_type = 'TIEBREAKER'
    ) THEN
      INSERT INTO question_results (
        game_id, question_id, winner_player_id, answered_at,
        response_time_ms, point_awarded, result_type
      )
      VALUES (
        p_game_id, v_game.tie_breaker_question_id, NULL, now(), 0, 0, 'TIMEOUT'
      )
      ON CONFLICT DO NOTHING;
    END IF;

    RETURN json_build_object('success', true, 'locked', true);
  ELSE
    RETURN json_build_object('success', true, 'locked', false);
  END IF;
END;
$$;

-- Cancel tie-breaker
CREATE OR REPLACE FUNCTION cancel_tiebreaker(p_game_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE games SET
    tie_breaker_status = 'NONE',
    tie_breaker_question_number = 0,
    tie_breaker_question_id = NULL,
    tie_breaker_deadline = NULL,
    tie_breaker_winner_id = NULL,
    tie_breaker_participants = '[]'::jsonb
  WHERE id = p_game_id;

  RETURN json_build_object('success', true);
END;
$$;

-- Kick player from tie-breaker lobby
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
-- GRANTS
-- ============================================================
GRANT EXECUTE ON FUNCTION remove_player(uuid) TO anon;
GRANT EXECUTE ON FUNCTION open_tiebreaker_lobby(uuid) TO anon;
GRANT EXECUTE ON FUNCTION start_tiebreaker(uuid) TO anon;
GRANT EXECUTE ON FUNCTION submit_tiebreaker_answer(uuid, uuid, uuid, text) TO anon;
GRANT EXECUTE ON FUNCTION advance_tiebreaker(uuid) TO anon;
GRANT EXECUTE ON FUNCTION lock_expired_tiebreaker(uuid) TO anon;
GRANT EXECUTE ON FUNCTION cancel_tiebreaker(uuid) TO anon;
GRANT EXECUTE ON FUNCTION kick_tiebreaker_player(uuid, uuid) TO anon;

-- ============================================================
-- END OF MIGRATION 007
-- ============================================================
