-- WORD RUSH - Migration 003: Game-Specific Join Routes
-- Adds join_game(p_game_number, p_name, p_device_session_id) RPC
-- Drops old join_active_game which joined any open lobby
-- Fully idempotent - safe to rerun

-- ============================================================
-- 1. Drop old join_active_game RPC (any signature)
-- ============================================================
DROP FUNCTION IF EXISTS public.join_active_game(text, text);
DROP FUNCTION IF EXISTS public.join_active_game(text, text, text);

-- ============================================================
-- 2. Create game-specific join_game RPC
-- ============================================================
CREATE OR REPLACE FUNCTION join_game(
  p_game_number integer,
  p_name text,
  p_device_session_id text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game_record record;
  v_player_id uuid;
  v_lock_result boolean;
BEGIN
  -- Validate game number
  IF p_game_number NOT IN (1, 2, 3) THEN
    RETURN json_build_object(
      'success', false,
      'error', 'INVALID_GAME',
      'message', 'Game number must be 1, 2, or 3'
    );
  END IF;

  -- Find the specific game by game_number
  SELECT id, game_number, status, max_players
  INTO v_game_record
  FROM games
  WHERE game_number = p_game_number;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'GAME_NOT_FOUND',
      'message', 'Game not found'
    );
  END IF;

  -- Verify game lobby is open
  IF v_game_record.status != 'LOBBY_OPEN' THEN
    RETURN json_build_object(
      'success', false,
      'error', 'LOBBY_NOT_OPEN',
      'message', 'Game ' || p_game_number || ' lobby is not open'
    );
  END IF;

  -- Advisory lock per game to serialize concurrent joins
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

  -- Check device not already active in THIS specific game
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

  -- Re-check player count under lock (atomic 20-player limit)
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

  -- Insert player into the specific game
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
-- 3. Update grants
-- ============================================================
GRANT EXECUTE ON FUNCTION join_game(integer, text, text) TO anon;

-- Revoke old function grants if they still exist
DO $$
BEGIN
  REVOKE EXECUTE ON FUNCTION join_active_game(text, text) FROM anon;
EXCEPTION
  WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
  REVOKE EXECUTE ON FUNCTION join_active_game(text, text, text) FROM anon;
EXCEPTION
  WHEN undefined_function THEN NULL;
END $$;

-- ============================================================
-- END OF MIGRATION 003
-- ============================================================
