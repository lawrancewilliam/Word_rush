<script>
  import { getSupabase, isSupabaseConfigured } from '$lib/supabase/client';

  const supabase = getSupabase();
  const supabaseReady = isSupabaseConfigured();

  let games = $state([]);
  let loading = $state(true);

  const statusLabels = {
    'NOT_STARTED': 'WAITING',
    'LOBBY_OPEN': 'LOBBY OPEN',
    'LOBBY_CLOSED': 'STARTING SOON',
    'COUNTDOWN': 'COUNTDOWN',
    'PLAYING': 'IN PROGRESS',
    'QUESTION_LOCKED': 'IN PROGRESS',
    'PAUSED': 'PAUSED',
    'COMPLETED': 'COMPLETED'
  };

  const statusColors = {
    'NOT_STARTED': 'bg-gray-100 text-gray-500',
    'LOBBY_OPEN': 'bg-green-100 text-green-700 border border-green-200',
    'LOBBY_CLOSED': 'bg-amber-100 text-amber-700 border border-amber-200',
    'COUNTDOWN': 'bg-orange-100 text-orange-700 border border-orange-200',
    'PLAYING': 'bg-purple-100 text-purple-700 border border-purple-200',
    'QUESTION_LOCKED': 'bg-purple-100 text-purple-700 border border-purple-200',
    'PAUSED': 'bg-red-100 text-red-700 border border-red-200',
    'COMPLETED': 'bg-gray-100 text-gray-500 border border-gray-200'
  };

  async function loadGames() {
    if (!supabaseReady) {
      loading = false;
      return;
    }
    try {
      const { data } = await supabase
        .from('games')
        .select('game_number, status')
        .order('game_number');

      if (data) {
        games = data;
      }
    } catch (e) {
      console.warn('Could not load game statuses:', e);
    } finally {
      loading = false;
    }
  }

  $effect(() => {
    loadGames();
  });
</script>

<div class="min-h-screen flex items-center justify-center p-4">
  <div class="w-full max-w-md animate-fade-in text-center space-y-8">
    <div>
      <h1 class="text-5xl font-black tracking-tight text-purple-700">
        WORD RUSH
      </h1>
      <p class="text-gray-500 mt-3 text-sm tracking-[0.2em] uppercase">
        Freshers Day Word Game
      </p>
    </div>

    <div class="glass-strong rounded-2xl p-6 space-y-4">
      <p class="text-xs text-gray-400 uppercase tracking-wider font-semibold mb-4">
        Scan the QR code provided by your host to join
      </p>

      {#if loading}
        <div class="py-4">
          <div class="inline-block w-8 h-8 border-3 border-gray-200 border-t-purple-500 rounded-full animate-spin"></div>
        </div>
      {:else}
        <div class="space-y-3">
          {#each games as game}
            <a
              href="/game{game.game_number}"
              class="flex items-center justify-between p-4 rounded-xl bg-white border border-gray-100 hover:border-purple-200 hover:shadow-md transition-all group"
            >
              <div class="flex items-center gap-3">
                <span class="text-lg font-bold text-gray-900 group-hover:text-purple-700 transition-colors">
                  Game {game.game_number}
                </span>
                <span class="px-2 py-0.5 rounded-full text-xs font-semibold {statusColors[game.status] || 'bg-gray-100 text-gray-500'}">
                  {statusLabels[game.status] || game.status}
                </span>
              </div>
              <svg class="w-5 h-5 text-gray-300 group-hover:text-purple-500 transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
              </svg>
            </a>
          {/each}
        </div>
      {/if}

      <p class="text-gray-400 text-xs mt-4">
        Use the QR code from the projector or host screen to join the correct game.
      </p>
    </div>
  </div>
</div>
