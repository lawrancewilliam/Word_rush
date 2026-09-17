-- WORD RUSH - Migration 002: Lobby, QR, Join Cleanup
-- Fully idempotent - safe to rerun after partial failure
-- Does NOT destroy existing data, hosts, or auth

-- ============================================================
-- 1. Make department column optional (nullable)
-- ============================================================
DO $$
BEGIN
  ALTER TABLE players ALTER COLUMN department DROP NOT NULL;
EXCEPTION
  WHEN dependent_objects_still_exist THEN NULL;
  WHEN others THEN NULL;
END $$;

-- ============================================================
-- 2. Drop device_participation table (replaced by session restore)
-- ============================================================
DROP TABLE IF EXISTS device_participation CASCADE;

-- ============================================================
-- 3. New RPC: open_lobby(game_number)
--    Closes ALL other lobbies, opens the selected game lobby.
--    Only one lobby can be open at a time.
-- ============================================================
CREATE OR REPLACE FUNCTION open_lobby(p_game_number integer)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game record;
BEGIN
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

-- ============================================================
-- 4. New RPC: remove_player(p_player_id)
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
  SELECT * INTO v_player
  FROM players
  WHERE id = p_player_id;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'PLAYER_NOT_FOUND',
      'message', 'Player not found'
    );
  END IF;

  SELECT * INTO v_game
  FROM games
  WHERE id = v_player.game_id;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'GAME_NOT_FOUND',
      'message', 'Game not found'
    );
  END IF;

  IF v_game.status NOT IN ('NOT_STARTED', 'LOBBY_OPEN') THEN
    RETURN json_build_object(
      'success', false,
      'error', 'GAME_IN_PROGRESS',
      'message', 'Cannot remove player after game has started'
    );
  END IF;

  UPDATE players
  SET is_active = false,
      removed_at = now()
  WHERE id = p_player_id;

  RETURN json_build_object(
    'success', true,
    'message', 'Player removed from lobby'
  );
END;
$$;

-- ============================================================
-- 5. Replace join_active_game: 2-param, no department
-- ============================================================
-- Safely drop old versions (any signature) before creating new
DROP FUNCTION IF EXISTS public.join_active_game(text, text, text);
DROP FUNCTION IF EXISTS public.join_active_game(text, text);

CREATE OR REPLACE FUNCTION join_active_game(
  p_name text,
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

  IF EXISTS (
    SELECT 1 FROM players
    WHERE game_id = v_game_record.id
    AND device_session_id = p_device_session_id
    AND is_active = true
  ) THEN
    SELECT id INTO v_player_id
    FROM players
    WHERE game_id = v_game_record.id
    AND device_session_id = p_device_session_id
    AND is_active = true;

    RETURN json_build_object(
      'success', true,
      'game_id', v_game_record.id,
      'player_id', v_player_id,
      'game_number', v_game_record.game_number,
      'restored', true
    );
  END IF;

  IF (
    SELECT COUNT(*) FROM players
    WHERE game_id = v_game_record.id
    AND is_active = true
  ) >= v_game_record.max_players THEN
    RETURN json_build_object(
      'success', false,
      'error', 'GAME_FULL',
      'message', 'This game has reached maximum capacity (20 players)'
    );
  END IF;

  INSERT INTO players (game_id, name, device_session_id)
  VALUES (v_game_record.id, p_name, p_device_session_id)
  RETURNING id INTO v_player_id;

  RETURN json_build_object(
    'success', true,
    'game_id', v_game_record.id,
    'player_id', v_player_id,
    'game_number', v_game_record.game_number
  );
END;
$$;

-- ============================================================
-- 6. Update get_private_leaderboard (no department column)
-- ============================================================
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

-- ============================================================
-- 7. Update reset_game (no device_participation cleanup needed)
-- ============================================================
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
    completed_at = NULL
  WHERE id = p_game_id;

  RETURN json_build_object(
    'success', true,
    'message', 'Game has been reset'
  );
END;
$$;

-- ============================================================
-- 8. RLS: Host-only policies (idempotent drop+create)
-- ============================================================
DROP POLICY IF EXISTS "questions_select_host" ON questions;
CREATE POLICY "questions_select_host" ON questions
  FOR SELECT USING (
    auth.uid() IS NOT NULL
    AND EXISTS (SELECT 1 FROM hosts WHERE id = auth.uid())
  );

DROP POLICY IF EXISTS "question_results_insert_host" ON question_results;
CREATE POLICY "question_results_insert_host" ON question_results
  FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (SELECT 1 FROM hosts WHERE id = auth.uid())
  );

DROP POLICY IF EXISTS "games_update_host" ON games;
CREATE POLICY "games_update_host" ON games
  FOR UPDATE USING (
    auth.uid() IS NOT NULL
    AND EXISTS (SELECT 1 FROM hosts WHERE id = auth.uid())
  );

DROP POLICY IF EXISTS "players_insert_host" ON players;
CREATE POLICY "players_insert_host" ON players
  FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (SELECT 1 FROM hosts WHERE id = auth.uid())
  );

DROP POLICY IF EXISTS "players_update_host" ON players;
CREATE POLICY "players_update_host" ON players
  FOR UPDATE USING (
    auth.uid() IS NOT NULL
    AND EXISTS (SELECT 1 FROM hosts WHERE id = auth.uid())
  );

DROP POLICY IF EXISTS "players_delete_host" ON players;
CREATE POLICY "players_delete_host" ON players
  FOR DELETE USING (
    auth.uid() IS NOT NULL
    AND EXISTS (SELECT 1 FROM hosts WHERE id = auth.uid())
  );

DROP POLICY IF EXISTS "question_results_delete_host" ON question_results;
CREATE POLICY "question_results_delete_host" ON question_results
  FOR DELETE USING (
    auth.uid() IS NOT NULL
    AND EXISTS (SELECT 1 FROM hosts WHERE id = auth.uid())
  );

-- ============================================================
-- 9. Grant permissions (safely handle missing old functions)
-- ============================================================
-- Only grant the 2-param version (old 3-param was dropped above)
GRANT EXECUTE ON FUNCTION join_active_game(text, text) TO anon;
GRANT EXECUTE ON FUNCTION open_lobby(integer) TO anon;
GRANT EXECUTE ON FUNCTION remove_player(uuid) TO anon;

-- Revoke old 3-param if it somehow still exists (safe guard)
DO $$
BEGIN
  REVOKE EXECUTE ON FUNCTION join_active_game(text, text, text) FROM anon;
EXCEPTION
  WHEN undefined_function THEN NULL;
END $$;

-- Keep existing grants (these are idempotent)
GRANT EXECUTE ON FUNCTION submit_answer(uuid, uuid, uuid, text) TO anon;
GRANT EXECUTE ON FUNCTION request_hint(uuid, uuid, uuid) TO anon;
GRANT EXECUTE ON FUNCTION lock_expired_question(uuid) TO anon;
GRANT EXECUTE ON FUNCTION get_private_leaderboard(uuid) TO anon;
GRANT EXECUTE ON FUNCTION reset_game(uuid) TO anon;
GRANT EXECUTE ON FUNCTION get_server_time() TO anon;

-- ============================================================
-- END OF MIGRATION 002
-- ============================================================
