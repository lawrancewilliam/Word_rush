-- WORD RUSH - Migration 004: Fix Realtime Publication
-- Adds tables to supabase_realtime publication for Postgres Changes
-- This is the root cause of ALL realtime bugs:
--   - Students never receiving game status updates
--   - Host never receiving player INSERT events
--   - Students never receiving player count updates
-- Fully idempotent - safe to rerun

-- ============================================================
-- 1. Add tables to supabase_realtime publication
-- ============================================================
-- Tables created via SQL migrations are NOT automatically added
-- to the supabase_realtime publication. Without this, zero
-- postgres_changes events are delivered to any subscriber.

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE games;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE players;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE question_results;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================
-- END OF MIGRATION 004
-- ============================================================
