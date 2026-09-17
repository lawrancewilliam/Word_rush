import { createClient } from '@supabase/supabase-js';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY } from '$env/static/private';

export function createServerClient(useServiceRole = false) {
  const key = useServiceRole ? SUPABASE_SERVICE_ROLE_KEY : PUBLIC_SUPABASE_ANON_KEY;
  return createClient(PUBLIC_SUPABASE_URL, key, {
    auth: { persistSession: false, autoRefreshToken: false }
  });
}
