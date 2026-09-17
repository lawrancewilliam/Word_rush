-- WORD RUSH - Migration 005: Gameplay Reliability
-- Fixes: blank jumbled word (RLS bypass), auto-advance, pause/resume timing
-- Idempotent - safe to rerun

-- ============================================================
-- 1. Add paused_remaining_ms column for pause/resume timing
-- ============================================================
DO $$
BEGIN
  ALTER TABLE games ADD COLUMN paused_remaining_ms integer;
EXCEPTION
  WHEN duplicate_column THEN NULL;
END $$;

-- ============================================================
-- 2. get_active_question RPC (bypasses RLS for question data)
-- ============================================================
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

  SELECT jumbled_word, hint, question_order, correct_word
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
-- 3. advance_question RPC (idempotent, advisory-lock-protected)
-- ============================================================
CREATE OR REPLACE FUNCTION advance_question(p_game_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game record;
  v_next_q record;
  v_lock_result boolean;
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

  -- Check if this is the last question
  IF v_game.current_question_number >= v_game.total_questions THEN
    -- Complete the game
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
    -- No next question found, complete the game
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
-- 4. Fix submit_answer to set QUESTION_LOCKED on winner
-- ============================================================
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

  -- If game is already QUESTION_LOCKED, reject further answers
  IF v_game_record.status = 'QUESTION_LOCKED' THEN
    RETURN json_build_object(
      'success', false,
      'error', 'QUESTION_LOCKED',
      'message', 'Question is already locked'
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

      -- Lock the question so no more answers can be submitted
      UPDATE games
      SET status = 'QUESTION_LOCKED'
      WHERE id = p_game_id;

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

-- ============================================================
-- 5. Grant permissions for new RPCs
-- ============================================================
GRANT EXECUTE ON FUNCTION get_active_question(uuid) TO anon;
GRANT EXECUTE ON FUNCTION advance_question(uuid) TO anon;

-- ============================================================
-- END OF MIGRATION 005
-- ============================================================
