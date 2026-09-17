import { createClient } from '@supabase/supabase-js';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';

let supabaseInstance = null;

export function getSupabase() {
  if (!supabaseInstance) {
    const url = PUBLIC_SUPABASE_URL || '';
    const key = PUBLIC_SUPABASE_ANON_KEY || '';

    if (!url || !key) {
      console.warn(
        '[WORD RUSH] Supabase credentials are not configured. ' +
        'Set PUBLIC_SUPABASE_URL and PUBLIC_SUPABASE_ANON_KEY in your .env file.'
      );
    }

    supabaseInstance = createClient(url || 'https://placeholder.supabase.co', key || 'placeholder-key', {
      auth: { persistSession: false, autoRefreshToken: false }
    });
  }
  return supabaseInstance;
}

export function isSupabaseConfigured() {
  return !!(PUBLIC_SUPABASE_URL && PUBLIC_SUPABASE_ANON_KEY);
}
