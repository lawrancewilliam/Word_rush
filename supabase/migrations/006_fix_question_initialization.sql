-- WORD RUSH - Migration 006: Fix Question Initialization & Security
-- Fixes: null current_question_id on game start, advance_question security
-- Idempotent - safe to rerun

-- ============================================================
-- 1. start_game RPC - atomic game initialization
-- ============================================================
-- Replaces client-side question lookup which fails when questions
-- array is empty. Atomically finds Question 1 and sets all fields.

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

-- ============================================================
-- 2. Fix advance_question - add reveal delay security check
-- ============================================================
-- Students can call this, but only AFTER the reveal period has
-- elapsed. Prevents premature question skipping via DevTools.

CREATE OR REPLACE FUNCTION advance_question(p_game_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game record;
  v_next_q record;
  v_lock_result boolean;
  v_result record;
  v_reveal_elapsed boolean := false;
BEGIN
  -- Advisory lock to prevent concurrent advances
  v_lock_result := pg_try_advisory_xact_lock(
    hashtext('advance_question:' || p_game_id::text)
  );

  IF NOT v_lock_result THEN
    RETURN json_build_object('success', false, 'error', 'CONCURRENT_ADVANCE');
  END IF;

  SELECT * INTO v_game
  FROM games
  WHERE id = p_game_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'GAME_NOT_FOUND');
  END IF;

  -- Only advance from QUESTION_LOCKED status
  IF v_game.status != 'QUESTION_LOCKED' THEN
    RETURN json_build_object('success', false, 'error', 'INVALID_STATUS', 'status', v_game.status);
  END IF;

  -- Security: verify reveal delay has elapsed (at least 2 seconds since answer/lock)
  -- Check the question_results entry for this question
  SELECT answered_at INTO v_result
  FROM question_results
  WHERE game_id = p_game_id
    AND question_id = v_game.current_question_id
  LIMIT 1;

  IF v_result.answered_at IS NOT NULL THEN
    v_reveal_elapsed := (now() - v_result.answered_at) >= interval '2 seconds';
  ELSE
    -- No result entry yet (shouldn't happen in QUESTION_LOCKED, but allow advance)
    v_reveal_elapsed := true;
  END IF;

  IF NOT v_reveal_elapsed THEN
    RETURN json_build_object('success', false, 'error', 'REVEAL_PENDING');
  END IF;

  -- Check if this is the last question
  IF v_game.current_question_number >= v_game.total_questions THEN
    UPDATE games
    SET status = 'COMPLETED',
        completed_at = now(),
        projector_mode = 'FINAL_RESULT',
        leaderboard_public = true
    WHERE id = p_game_id;

    RETURN json_build_object('success', true, 'action', 'GAME_COMPLETED');
  END IF;

  -- Find next question
  SELECT id, question_order INTO v_next_q
  FROM questions
  WHERE game_number = v_game.game_number
    AND question_order = v_game.current_question_number + 1
    AND is_tiebreaker = false
  LIMIT 1;

  IF NOT FOUND THEN
    UPDATE games
    SET status = 'COMPLETED',
        completed_at = now(),
        projector_mode = 'FINAL_RESULT',
        leaderboard_public = true
    WHERE id = p_game_id;

    RETURN json_build_object('success', true, 'action', 'GAME_COMPLETED');
  END IF;

  -- Advance to next question
  UPDATE games
  SET status = 'PLAYING',
      current_question_number = v_next_q.question_order,
      current_question_id = v_next_q.id,
      question_started_at = now(),
      question_deadline = now() + interval '30 seconds',
      projector_mode = 'QUESTION',
      paused_remaining_ms = NULL
  WHERE id = p_game_id;

  RETURN json_build_object(
    'success', true,
    'action', 'ADVANCED',
    'question_number', v_next_q.question_order
  );
END;
$$;

-- ============================================================
-- 3. Ensure get_active_question works without migration 005
-- ============================================================
-- Re-create to ensure it exists even if migration 005 was not run

CREATE OR REPLACE FUNCTION get_active_question(p_game_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game record;
  v_question record;
BEGIN
  SELECT id, game_number, status, current_question_number, current_question_id,
         question_started_at, question_deadline, total_questions, paused_remaining_ms
  INTO v_game
  FROM games
  WHERE id = p_game_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'GAME_NOT_FOUND');
  END IF;

  IF v_game.current_question_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'NO_ACTIVE_QUESTION');
  END IF;

  SELECT jumbled_word, hint, question_order
  INTO v_question
  FROM questions
  WHERE id = v_game.current_question_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'QUESTION_NOT_FOUND');
  END IF;

  RETURN json_build_object(
    'success', true,
    'jumbled_word', v_question.jumbled_word,
    'hint', v_question.hint,
    'question_number', v_game.current_question_number,
    'total_questions', v_game.total_questions,
    'question_deadline', v_game.question_deadline,
    'question_started_at', v_game.question_started_at,
    'status', v_game.status,
    'paused_remaining_ms', v_game.paused_remaining_ms
  );
END;
$$;

-- ============================================================
-- 4. Ensure submit_answer sets QUESTION_LOCKED
-- ============================================================
-- Re-create to ensure it exists with the lock behavior

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
  v_rows_affected integer;
  v_point_value integer;
  v_response_ms bigint;
BEGIN
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

  SELECT * INTO v_game_record
  FROM games
  WHERE id = p_game_id;

  IF NOT FOUND OR v_game_record.status NOT IN ('PLAYING', 'QUESTION_LOCKED') THEN
    RETURN json_build_object(
      'success', false,
      'error', 'GAME_NOT_PLAYING',
      'message', 'Game is not currently in playing state'
    );
  END IF;

  -- Reject if already locked
  IF v_game_record.status = 'QUESTION_LOCKED' THEN
    RETURN json_build_object(
      'success', false,
      'error', 'QUESTION_LOCKED',
      'message', 'Question is already locked'
    );
  END IF;

  -- Reject if deadline passed
  IF v_game_record.question_deadline IS NOT NULL
     AND now() > v_game_record.question_deadline THEN
    RETURN json_build_object(
      'success', false,
      'error', 'QUESTION_EXPIRED',
      'message', 'Time is up for this question'
    );
  END IF;

  v_normalized_answer := UPPER(TRIM(p_answer));
  v_correct_word := v_question_record.correct_word;
  v_point_value := 1;

  IF v_game_record.question_started_at IS NOT NULL THEN
    v_response_ms := (EXTRACT(EPOCH FROM (now() - v_game_record.question_started_at)) * 1000)::bigint;
  ELSE
    v_response_ms := 0;
  END IF;

  IF v_normalized_answer = v_correct_word THEN
    INSERT INTO question_results (
      game_id, question_id, winner_player_id, answered_at,
      response_time_ms, point_awarded, result_type
    )
    VALUES (
      p_game_id,
      p_question_id,
      p_player_id,
      now(),
      v_response_ms,
      v_point_value,
      'NORMAL'
    )
    ON CONFLICT DO NOTHING;

    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

    IF v_rows_affected = 1 THEN
      UPDATE players
      SET score = score + v_point_value,
          total_response_time_ms = total_response_time_ms + v_response_ms
      WHERE id = p_player_id;

      -- Lock the question
      UPDATE games
      SET status = 'QUESTION_LOCKED'
      WHERE id = p_game_id;

      RETURN json_build_object(
        'success', true,
        'correct', true,
        'won', true,
        'points_awarded', v_point_value,
        'response_time_ms', v_response_ms
      );
    ELSE
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

-- ============================================================
-- 5. Ensure lock_expired_question rejects premature calls
-- ============================================================

CREATE OR REPLACE FUNCTION lock_expired_question(
  p_game_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game_record record;
BEGIN
  SELECT * INTO v_game_record
  FROM games
  WHERE id = p_game_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'GAME_NOT_FOUND');
  END IF;

  IF v_game_record.current_question_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'NO_CURRENT_QUESTION');
  END IF;

  -- Only lock if deadline has actually passed and game is still PLAYING
  IF v_game_record.status != 'PLAYING' THEN
    RETURN json_build_object('success', false, 'error', 'NOT_PLAYING');
  END IF;

  IF v_game_record.question_deadline IS NOT NULL
     AND now() > v_game_record.question_deadline THEN

    -- Check if there's already a winner
    IF NOT EXISTS (
      SELECT 1 FROM question_results
      WHERE question_id = v_game_record.current_question_id
      AND result_type = 'NORMAL'
    ) THEN
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

-- ============================================================
-- 6. Update grants
-- ============================================================
GRANT EXECUTE ON FUNCTION start_game(uuid) TO anon;
GRANT EXECUTE ON FUNCTION get_active_question(uuid) TO anon;
GRANT EXECUTE ON FUNCTION advance_question(uuid) TO anon;
GRANT EXECUTE ON FUNCTION submit_answer(uuid, uuid, uuid, text) TO anon;
GRANT EXECUTE ON FUNCTION lock_expired_question(uuid) TO anon;

-- ============================================================
-- END OF MIGRATION 006
-- ============================================================
