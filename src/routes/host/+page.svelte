<script>
  import { getSupabase } from '$lib/supabase/client';
  import QRCode from 'qrcode';
  import {
    Play, Pause, SkipForward, Users, Eye, EyeOff, Lightbulb,
    Trophy, RefreshCcw, LogOut, Lock, Unlock, Trash2, ChevronRight,
    Monitor, Timer, Crown, AlertTriangle, CheckCircle, XCircle,
    Settings, BarChart3, FileText, Star, QrCode, X
  } from 'lucide-svelte';

  const supabase = getSupabase();

  let isLoggedIn = $state(false);
  let isLoggingIn = $state(false);
  let loginEmail = $state('');
  let loginPassword = $state('');
  let loginError = $state('');
  let authUser = $state(null);

  let games = $state([]);
  let selectedGameId = $state(null);
  let selectedGame = $derived(games.find(g => g.id === selectedGameId));
  let players = $state([]);
  let leaderboard = $state([]);
  let questions = $state({ 1: [], 2: [], 3: [], tiebreakers: [] });

  let timeRemaining = $state(0);
  let timerInterval = null;
  let countdownTimer = $state(null);
  let countdownInterval = null;

  let subscriptions = $state([]);
  let activeTab = $state('GAME 1');
  let showConfirmDialog = $state(false);
  let confirmAction = $state(null);
  let confirmMessage = $state('');
  let isProcessing = $state(false);

  let serverTimeOffset = $state(0);
  let qrDataUrl = $state('');
  let joinUrl = $state('');

  let playersLoadSeq = $state(0);

  let showQuestionBank = $state(false);
  let questionsLoaded = $state(false);

  let inLobby = $derived(selectedGame?.status === 'LOBBY_OPEN');
  let activePlayers = $derived(players.filter(p => p.game_id === selectedGameId && p.is_active));
  let activePlayerCount = $derived(activePlayers.length);

  function getStatusColor(status) {
    const colors = {
      'NOT_STARTED': 'bg-gray-100 text-gray-500',
      'LOBBY_OPEN': 'bg-green-50 text-green-700 border border-green-200',
      'LOBBY_CLOSED': 'bg-amber-50 text-amber-700 border border-amber-200',
      'COUNTDOWN': 'bg-orange-50 text-orange-700 border border-orange-200',
      'PLAYING': 'bg-purple-50 text-purple-700 border border-purple-200',
      'QUESTION_LOCKED': 'bg-cyan-50 text-cyan-700 border border-cyan-200',
      'PAUSED': 'bg-red-50 text-red-700 border border-red-200',
      'COMPLETED': 'bg-gray-50 text-gray-500 border border-gray-200'
    };
    return colors[status] || 'bg-gray-100 text-gray-500';
  }

  function getStatusLabel(status) {
    const labels = {
      'NOT_STARTED': 'NOT STARTED',
      'LOBBY_OPEN': 'LOBBY OPEN',
      'LOBBY_CLOSED': 'LOBBY CLOSED',
      'COUNTDOWN': 'COUNTDOWN',
      'PLAYING': 'PLAYING',
      'QUESTION_LOCKED': 'LOCKED',
      'PAUSED': 'PAUSED',
      'COMPLETED': 'COMPLETED'
    };
    return labels[status] || status;
  }

  function getDiffColor(diff) {
    if (diff === 'EASY') return 'text-green-700 bg-green-50';
    if (diff === 'MEDIUM') return 'text-amber-700 bg-amber-50';
    return 'text-red-700 bg-red-50';
  }

  function formatTime(seconds) {
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  }

  async function syncServerTime() {
    try {
      const start = Date.now();
      const { data } = await supabase.rpc('get_server_time');
      const end = Date.now();
      const rtt = end - start;
      if (data) {
        serverTimeOffset = Date.now() - data - rtt / 2;
      }
    } catch (e) {
      console.warn('Could not sync server time:', e);
    }
  }

  function getServerNow() {
    return Date.now() - serverTimeOffset;
  }

  async function handleLogin() {
    isLoggingIn = true;
    loginError = '';

    try {
      const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
        email: loginEmail,
        password: loginPassword
      });

      if (authError) {
        if (authError.message?.includes('Invalid login credentials')) {
          loginError = 'Invalid email or password.';
        } else if (authError.message?.includes('fetch') || authError.message?.includes('network')) {
          loginError = 'Unable to connect. Please try again.';
        } else {
          loginError = 'Invalid email or password.';
        }
        return;
      }

      const userId = authData.user?.id;
      if (!userId) {
        loginError = 'Invalid email or password.';
        await supabase.auth.signOut();
        return;
      }

      const { data: hostRecord, error: hostError } = await supabase
        .from('hosts')
        .select('id, email')
        .eq('id', userId)
        .maybeSingle();

      if (hostError || !hostRecord) {
        if (hostError?.code === 'PGRST205' || hostError?.message?.includes('Could not find the table')) {
          loginError = 'Host authorization not configured.';
        } else {
          loginError = 'This account is not authorized as a host.';
        }
        await supabase.auth.signOut();
        return;
      }

      authUser = authData.user;
      isLoggedIn = true;
      await loadAllGames();
      setupRealtimeSubscriptions();
    } catch (e) {
      console.error('[WORD RUSH] Login failed:', e?.message || e);
      if (e?.message?.includes('fetch') || e?.message?.includes('network') || e?.name === 'TypeError') {
        loginError = 'Unable to connect. Please try again.';
      } else {
        loginError = 'Invalid email or password.';
      }
    } finally {
      isLoggingIn = false;
    }
  }

  async function handleLogout() {
    cleanupSubscriptions();
    if (timerInterval) clearInterval(timerInterval);
    if (countdownInterval) clearInterval(countdownInterval);

    await supabase.auth.signOut();
    isLoggedIn = false;
    authUser = null;
    selectedGameId = null;
    games = [];
    players = [];
    leaderboard = [];
    questions = { 1: [], 2: [], 3: [], tiebreakers: [] };
    qrDataUrl = '';
    joinUrl = '';
    questionsLoaded = false;
  }

  async function loadAllGames() {
    const { data, error } = await supabase
      .from('games')
      .select('*')
      .order('game_number');

    if (!error && data) {
      games = data;
    }
  }

  async function loadPlayersForGame(gameId) {
    const seq = ++playersLoadSeq;
    const { data, error } = await supabase
      .from('players')
      .select('*')
      .eq('game_id', gameId)
      .order('joined_at', { ascending: true });

    if (!error && data && seq === playersLoadSeq) {
      players = data;
      console.log('[WORD RUSH Host] players loaded:', data.length);
    }
  }

  async function loadLeaderboard(gameId) {
    try {
      const { data, error } = await supabase.rpc('get_private_leaderboard', {
        p_game_id: gameId
      });

      if (!error && data?.success) {
        leaderboard = data.leaderboard || [];
      }
    } catch (e) {
      console.error('Failed to load leaderboard:', e);
    }
  }

  async function loadAllQuestions() {
    if (questionsLoaded) return;
    for (let gameNum = 1; gameNum <= 3; gameNum++) {
      const { data, error } = await supabase
        .from('questions')
        .select('*')
        .eq('game_number', gameNum)
        .eq('is_tiebreaker', false)
        .order('question_order');

      if (!error && data) {
        questions[gameNum] = data;
      }
    }

    const { data: tbData, error: tbError } = await supabase
      .from('questions')
      .select('*')
      .eq('is_tiebreaker', true)
      .order('game_number, question_order');

    if (!tbError && tbData) {
      questions.tiebreakers = tbData;
    }
    questionsLoaded = true;
  }

  async function openQuestionBank() {
    await loadAllQuestions();
    showQuestionBank = true;
  }

  function closeQuestionBank() {
    showQuestionBank = false;
  }

  function handleQuestionBankKeydown(e) {
    if (e.key === 'Escape' && showQuestionBank) closeQuestionBank();
  }

  function selectGame(gameId) {
    selectedGameId = gameId;
    const game = games.find(g => g.id === gameId);
    if (game) {
      loadPlayersForGame(gameId);
      loadLeaderboard(gameId);
      startTimerForGame(game);
      if (game.status === 'LOBBY_OPEN') {
        generateQR();
      } else {
        qrDataUrl = '';
        joinUrl = '';
      }
    }
  }

  function startTimerForGame(game) {
    if (timerInterval) clearInterval(timerInterval);

    if (game && game.question_deadline && game.status === 'PLAYING') {
      timerInterval = setInterval(() => {
        const now = getServerNow();
        const deadline = new Date(game.question_deadline).getTime();
        const remaining = Math.max(0, Math.floor((deadline - now) / 1000));
        timeRemaining = remaining;

        if (remaining <= 0 && game.status === 'PLAYING') {
          lockExpiredQuestion(game.id);
        }
      }, 100);
    }
  }

  async function lockExpiredQuestion(gameId) {
    try {
      const { data, error } = await supabase.rpc('lock_expired_question', {
        p_game_id: gameId
      });

      if (!error && data?.success) {
        await refreshSelectedGame();
      }
    } catch (e) {
      console.error('Lock expired question failed:', e);
    }
  }

  async function refreshSelectedGame() {
    if (!selectedGameId) return;

    const { data, error } = await supabase
      .from('games')
      .select('*')
      .eq('id', selectedGameId)
      .single();

    if (!error && data) {
      const idx = games.findIndex(g => g.id === selectedGameId);
      if (idx !== -1) {
        games[idx] = data;
      }
      if (data.question_deadline && data.status === 'PLAYING') {
        startTimerForGame(data);
      }
      if (data.status === 'LOBBY_OPEN') {
        generateQR();
      } else if (data.status !== 'LOBBY_OPEN' && qrDataUrl) {
        qrDataUrl = '';
        joinUrl = '';
      }
    }

    await loadPlayersForGame(selectedGameId);
    await loadLeaderboard(selectedGameId);
  }

  function showConfirm(message, action) {
    confirmMessage = message;
    confirmAction = action;
    showConfirmDialog = true;
  }

  function handleConfirm() {
    showConfirmDialog = false;
    if (confirmAction) confirmAction();
    confirmAction = null;
  }

  function cancelConfirm() {
    showConfirmDialog = false;
    confirmAction = null;
  }

  async function generateQR() {
    try {
      if (!selectedGame) return;
      joinUrl = `${window.location.origin}/game${selectedGame.game_number}`;
      qrDataUrl = await QRCode.toDataURL(joinUrl, {
        width: 400,
        margin: 2,
        color: { dark: '#1a1040', light: '#ffffff' }
      });
    } catch (e) {
      console.error('QR generation failed:', e);
    }
  }

  async function openLobby() {
    if (!selectedGame || isProcessing) return;
    isProcessing = true;
    try {
      const { data, error } = await supabase.rpc('open_lobby', {
        p_game_number: selectedGame.game_number
      });

      if (error) throw error;

      if (data?.error) {
        console.error('Open lobby error:', data.error);
      } else {
        await loadAllGames();
        await refreshSelectedGame();
      }
    } catch (e) {
      console.error('Open lobby failed:', e);
    } finally {
      isProcessing = false;
    }
  }

  async function closeLobby() {
    if (!selectedGameId || isProcessing) return;
    isProcessing = true;
    try {
      const { error } = await supabase
        .from('games')
        .update({ status: 'LOBBY_CLOSED' })
        .eq('id', selectedGameId);

      if (!error) await refreshSelectedGame();
    } catch (e) {
      console.error('Close lobby failed:', e);
    } finally {
      isProcessing = false;
    }
  }

  async function startGame() {
    if (!selectedGameId || isProcessing) return;

    const playerCountNow = players.filter(p => p.game_id === selectedGameId && p.is_active).length;
    if (playerCountNow === 0) {
      showConfirm('No players have joined yet. Start the game anyway?', doStartGame);
      return;
    }
    showConfirm('Start the game? This will close the lobby and begin a 5-second countdown.', doStartGame);
  }

  async function doStartGame() {
    isProcessing = true;
    try {
      await supabase
        .from('games')
        .update({ status: 'LOBBY_CLOSED' })
        .eq('id', selectedGameId);

      await supabase
        .from('games')
        .update({
          status: 'COUNTDOWN',
          projector_mode: 'COUNTDOWN',
          started_at: new Date().toISOString()
        })
        .eq('id', selectedGameId);

      await refreshSelectedGame();

      countdownTimer = 5;

      countdownInterval = setInterval(async () => {
        countdownTimer = countdownTimer - 1;

        if (countdownTimer <= 0) {
          clearInterval(countdownInterval);
          countdownInterval = null;
          countdownTimer = null;

          const firstQuestion = questions[selectedGame?.game_number]?.[0];

          await supabase
            .from('games')
            .update({
              status: 'PLAYING',
              current_question_number: 1,
              current_question_id: firstQuestion?.id || null,
              question_started_at: new Date().toISOString(),
              question_deadline: new Date(Date.now() + 30000).toISOString(),
              projector_mode: 'QUESTION'
            })
            .eq('id', selectedGameId);

          await refreshSelectedGame();
        }
      }, 1000);
    } catch (e) {
      console.error('Start game failed:', e);
      if (countdownInterval) clearInterval(countdownInterval);
      countdownTimer = null;
    } finally {
      isProcessing = false;
    }
  }

  async function pauseGame() {
    if (!selectedGameId || isProcessing) return;
    isProcessing = true;
    try {
      const now = getServerNow();
      const deadline = selectedGame?.question_deadline
        ? new Date(selectedGame.question_deadline).getTime()
        : 0;
      const remainingMs = Math.max(0, deadline - now);

      const { error } = await supabase
        .from('games')
        .update({
          status: 'PAUSED',
          paused_remaining_ms: Math.round(remainingMs)
        })
        .eq('id', selectedGameId);

      if (!error) {
        if (timerInterval) clearInterval(timerInterval);
        await refreshSelectedGame();
      }
    } catch (e) {
      console.error('Pause game failed:', e);
    } finally {
      isProcessing = false;
    }
  }

  async function resumeGame() {
    if (!selectedGameId || isProcessing) return;
    isProcessing = true;
    try {
      const remainingMs = selectedGame?.paused_remaining_ms || 30000;
      const newDeadline = new Date(Date.now() + remainingMs).toISOString();

      const { error } = await supabase
        .from('games')
        .update({
          status: 'PLAYING',
          question_deadline: newDeadline,
          paused_remaining_ms: null
        })
        .eq('id', selectedGameId);

      if (!error) {
        await refreshSelectedGame();
      }
    } catch (e) {
      console.error('Resume game failed:', e);
    } finally {
      isProcessing = false;
    }
  }

  async function skipQuestion() {
    if (!selectedGameId || !selectedGame?.current_question_id || isProcessing) return;

    isProcessing = true;
    try {
      const { error: insertError } = await supabase
        .from('question_results')
        .insert({
          game_id: selectedGameId,
          question_id: selectedGame.current_question_id,
          result_type: 'SKIPPED',
          answered_at: new Date().toISOString(),
          response_time_ms: 0,
          point_awarded: 0
        });

      if (insertError && !insertError.message?.includes('duplicate')) {
        console.warn('Skip insert warning:', insertError);
      }

      const { data, error } = await supabase.rpc('advance_question', {
        p_game_id: selectedGameId
      });

      if (error) throw error;

      if (data?.success) {
        await refreshSelectedGame();
      }
    } catch (e) {
      console.error('Skip question failed:', e);
    } finally {
      isProcessing = false;
    }
  }

  async function nextQuestion() {
    if (!selectedGameId || isProcessing) return;
    isProcessing = true;
    try {
      if (selectedGame?.current_question_id && selectedGame?.status === 'QUESTION_LOCKED') {
        const { data: existingResult } = await supabase
          .from('question_results')
          .select('id')
          .eq('game_id', selectedGameId)
          .eq('question_id', selectedGame.current_question_id)
          .maybeSingle();

        if (!existingResult) {
          await supabase
            .from('question_results')
            .insert({
              game_id: selectedGameId,
              question_id: selectedGame.current_question_id,
              result_type: 'TIMEOUT',
              answered_at: new Date().toISOString(),
              response_time_ms: 0,
              point_awarded: 0
            });
        }
      }

      const { data, error } = await supabase.rpc('advance_question', {
        p_game_id: selectedGameId
      });

      if (error) throw error;

      if (data?.success) {
        await refreshSelectedGame();
      }
    } catch (e) {
      console.error('Next question failed:', e);
    } finally {
      isProcessing = false;
    }
  }

  async function finalizeGame() {
    const { error } = await supabase
      .from('games')
      .update({
        status: 'COMPLETED',
        completed_at: new Date().toISOString(),
        projector_mode: 'FINAL_RESULT',
        leaderboard_public: true
      })
      .eq('id', selectedGameId);

    if (timerInterval) clearInterval(timerInterval);
    if (!error) await refreshSelectedGame();
  }

  function endGame() {
    showConfirm('End the current game? This cannot be undone.', async () => {
      isProcessing = true;
      try {
        await finalizeGame();
      } catch (e) {
        console.error('End game failed:', e);
      } finally {
        isProcessing = false;
      }
    });
  }

  function resetGame() {
    showConfirm('Reset this game? All players, scores, and progress will be deleted.', async () => {
      isProcessing = true;
      try {
        const { data, error } = await supabase.rpc('reset_game', {
          p_game_id: selectedGameId
        });

        if (!error) {
          if (timerInterval) clearInterval(timerInterval);
          countdownTimer = null;
          if (countdownInterval) clearInterval(countdownInterval);
          qrDataUrl = '';
          joinUrl = '';
          await refreshSelectedGame();
        }
      } catch (e) {
        console.error('Reset game failed:', e);
      } finally {
        isProcessing = false;
      }
    });
  }

  async function removePlayer(playerId) {
    showConfirm('Remove this player from the game?', async () => {
      try {
        const { data, error } = await supabase.rpc('remove_player', {
          p_player_id: playerId
        });

        if (error) throw error;

        if (data?.error) {
          console.error('Remove player error:', data.error);
        } else {
          await refreshSelectedGame();
        }
      } catch (e) {
        console.error('Remove player failed:', e);
      }
    });
  }

  async function showLeaderboardOnProjector() {
    if (!selectedGameId) return;
    try {
      await supabase
        .from('games')
        .update({
          leaderboard_public: true,
          projector_mode: 'LEADERBOARD'
        })
        .eq('id', selectedGameId);
      await refreshSelectedGame();
    } catch (e) {
      console.error('Show leaderboard failed:', e);
    }
  }

  async function hideLeaderboardFromProjector() {
    if (!selectedGameId) return;
    try {
      await supabase
        .from('games')
        .update({ leaderboard_public: false })
        .eq('id', selectedGameId);
      await refreshSelectedGame();
    } catch (e) {
      console.error('Hide leaderboard failed:', e);
    }
  }

  async function showFinalResult() {
    if (!selectedGameId) return;
    try {
      await supabase
        .from('games')
        .update({ projector_mode: 'FINAL_RESULT' })
        .eq('id', selectedGameId);
      await refreshSelectedGame();
    } catch (e) {
      console.error('Show final result failed:', e);
    }
  }

  async function showEventChampions() {
    if (!selectedGameId) return;
    try {
      await supabase
        .from('games')
        .update({ projector_mode: 'EVENT_CHAMPIONS' })
        .eq('id', selectedGameId);
      await refreshSelectedGame();
    } catch (e) {
      console.error('Show event champions failed:', e);
    }
  }

  function setupRealtimeSubscriptions() {
    cleanupSubscriptions();

    const gamesChannel = supabase
      .channel('host-games')
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'games'
      }, async (payload) => {
        if (payload.eventType === 'INSERT') {
          const existing = games.find(g => g.id === payload.new.id);
          if (!existing) {
            games = [...games, payload.new];
          }
        } else if (payload.eventType === 'UPDATE') {
          const idx = games.findIndex(g => g.id === payload.new.id);
          if (idx !== -1) {
            games[idx] = payload.new;
            games = [...games];

            if (payload.new.id === selectedGameId) {
              if (payload.new.question_deadline && payload.new.status === 'PLAYING') {
                startTimerForGame(payload.new);
              }
              if (payload.new.status !== 'PLAYING' && timerInterval) {
                clearInterval(timerInterval);
              }
              if (payload.new.status === 'LOBBY_OPEN') {
                generateQR();
              }
            }
          }
        } else if (payload.eventType === 'DELETE') {
          games = games.filter(g => g.id !== payload.old.id);
        }
      })
      .subscribe();

    subscriptions.push(gamesChannel);

    const playersChannel = supabase
      .channel('host-players')
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'players'
      }, async (payload) => {
        if (selectedGameId) {
          const gameId = payload.new?.game_id || payload.old?.game_id;
          if (gameId === selectedGameId) {
            await loadPlayersForGame(selectedGameId);
            await loadLeaderboard(selectedGameId);
          }
        }
      })
      .subscribe();

    subscriptions.push(playersChannel);

    const resultsChannel = supabase
      .channel('host-results')
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'question_results'
      }, async (payload) => {
        if (selectedGameId) {
          const gameId = payload.new?.game_id || payload.old?.game_id;
          if (gameId === selectedGameId) {
            await loadLeaderboard(selectedGameId);
          }
        }
      })
      .subscribe();

    subscriptions.push(resultsChannel);
  }

  function cleanupSubscriptions() {
    subscriptions.forEach(ch => {
      supabase.removeChannel(ch);
    });
    subscriptions = [];
  }

  function handleLoginKeydown(e) {
    if (e.key === 'Enter' && !isLoggingIn) {
      handleLogin();
    }
  }

  $effect(() => {
    syncServerTime();

    return () => {
      cleanupSubscriptions();
      if (timerInterval) clearInterval(timerInterval);
      if (countdownInterval) clearInterval(countdownInterval);
    };
  });
</script>

<svelte:window onkeydown={handleQuestionBankKeydown} />

{#if !isLoggedIn}
  <div class="min-h-screen flex items-center justify-center p-4 bg-gray-50">
    <div class="w-full max-w-md animate-fade-in">
      <div class="text-center mb-8">
        <h1 class="text-4xl font-bold tracking-tight text-purple-700">
          WORD RUSH
        </h1>
        <p class="text-gray-500 mt-2 text-sm tracking-wide">HOST CONTROL CENTER</p>
      </div>

      <div class="glass-strong rounded-2xl p-8 space-y-6">
        {#if loginError}
          <div class="bg-red-50 border border-red-200 rounded-xl px-4 py-3 text-sm text-red-600 flex items-center gap-2">
            <XCircle size={16} />
            {loginError}
          </div>
        {/if}

        <div>
          <label for="host-email" class="block text-xs font-medium text-gray-500 mb-1.5 uppercase tracking-wider">Email</label>
          <input
            id="host-email"
            type="email"
            bind:value={loginEmail}
            placeholder="Enter host email"
            disabled={isLoggingIn}
            autocomplete="email"
            class="w-full px-4 py-3 rounded-xl bg-white border border-gray-200 text-gray-900 placeholder-gray-400 focus:border-purple-500 focus:ring-2 focus:ring-purple-500/20 transition-colors outline-none"
          />
        </div>

        <div>
          <label for="host-password" class="block text-xs font-medium text-gray-500 mb-1.5 uppercase tracking-wider">Password</label>
          <input
            id="host-password"
            type="password"
            bind:value={loginPassword}
            placeholder="Enter password"
            disabled={isLoggingIn}
            onkeydown={handleLoginKeydown}
            class="w-full px-4 py-3 rounded-xl bg-white border border-gray-200 text-gray-900 placeholder-gray-400 focus:border-purple-500 focus:ring-2 focus:ring-purple-500/20 transition-colors outline-none"
          />
        </div>

        <button
          onclick={handleLogin}
          disabled={isLoggingIn || !loginEmail || !loginPassword}
          class="w-full py-3.5 rounded-xl bg-purple-600 hover:bg-purple-700 disabled:bg-gray-200 disabled:text-gray-400 text-white font-semibold text-lg transition-all active:scale-[0.98] shadow-lg shadow-purple-600/25"
        >
          {#if isLoggingIn}
            <span class="inline-block w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin"></span>
          {:else}
            LOGIN
          {/if}
        </button>
      </div>
    </div>
  </div>
{:else}
  <div class="min-h-screen p-6 bg-gray-50">
    <div class="max-w-[1600px] mx-auto space-y-6">

      <!-- Header -->
      <div class="flex items-center justify-between animate-fade-in">
        <div>
          <h1 class="text-2xl font-bold tracking-tight text-purple-700">
            WORD RUSH - HOST CONTROL CENTER
          </h1>
          <p class="text-gray-400 text-sm mt-1">Admin Dashboard</p>
        </div>
        <div class="flex items-center gap-3">
          {#if selectedGame && !inLobby}
            <button
              onclick={openQuestionBank}
              class="flex items-center gap-2 px-4 py-2 rounded-xl bg-white border border-gray-200 text-gray-600 hover:text-gray-900 hover:bg-gray-50 transition-all text-sm"
            >
              <FileText size={16} />
              VIEW QUESTION BANK
            </button>
          {/if}
          <button
            onclick={handleLogout}
            class="flex items-center gap-2 px-4 py-2 rounded-xl bg-white border border-gray-200 text-gray-600 hover:text-gray-900 hover:bg-gray-50 transition-all text-sm"
          >
            <LogOut size={16} />
            Logout
          </button>
        </div>
      </div>

      <!-- Countdown overlay -->
      {#if countdownTimer !== null}
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm">
          <div class="text-center animate-scale-in">
            <div class="text-9xl font-black text-purple-600 animate-countdown select-none">
              {countdownTimer}
            </div>
            <p class="text-gray-300 text-xl mt-4">Game Starting...</p>
          </div>
        </div>
      {/if}

      <!-- ========== DEDICATED LOBBY VIEW ========== -->
      {#if inLobby && selectedGame}
        <div class="animate-fade-in">
          <!-- Lobby Header -->
          <div class="text-center mb-6">
            <div class="inline-block px-6 py-2 rounded-full bg-green-50 border border-green-200 mb-3">
              <span class="text-lg font-bold text-green-700 tracking-[0.3em]">
                GAME {selectedGame.game_number} LOBBY OPEN
              </span>
            </div>
          </div>

          <div class="grid grid-cols-12 gap-6">
            <!-- Left: QR + Join URL + Count -->
            <div class="col-span-5 flex flex-col items-center gap-6">
              <div class="bg-white rounded-3xl flex items-center justify-center p-4 border border-gray-200 shadow-lg" style="width: min(380px, 70vw); height: min(380px, 70vw);">
                {#if qrDataUrl}
                  <img src={qrDataUrl} alt="Join QR Code" class="w-full h-full object-contain" />
                {:else}
                  <div class="w-12 h-12 border-4 border-gray-200 border-t-purple-500 rounded-full animate-spin"></div>
                {/if}
              </div>

              <div class="text-center space-y-1">
                <p class="text-sm text-gray-500 uppercase tracking-wider font-semibold">Scan to Join</p>
                {#if joinUrl}
                  <p class="text-sm text-purple-600 font-mono">{joinUrl}</p>
                {/if}
              </div>

              <div class="text-center">
                <div class="text-5xl font-black text-gray-900">
                  <span class="text-purple-600">{activePlayerCount}</span>
                  <span class="text-gray-300 text-3xl"> / {selectedGame.max_players}</span>
                </div>
                <p class="text-sm text-gray-400 mt-1 uppercase tracking-wider">Players Joined</p>
              </div>

              {#if activePlayerCount >= selectedGame.max_players}
                <div class="px-6 py-2 rounded-xl bg-green-50 border border-green-200">
                  <p class="text-sm font-bold text-green-700">LOBBY FULL</p>
                </div>
              {/if}
            </div>

            <!-- Right: Player List -->
            <div class="col-span-7">
              <div class="glass-strong rounded-2xl p-5 h-full">
                <h3 class="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-4 flex items-center gap-2">
                  <Users size={16} />
                  Joined Players — {activePlayerCount} / {selectedGame.max_players}
                </h3>

                <div class="grid grid-cols-2 gap-x-6 gap-y-1 max-h-[calc(100vh-350px)] overflow-y-auto pr-2">
                  {#each activePlayers as player, i (player.id)}
                    <div class="flex items-center gap-3 py-2 px-3 rounded-lg hover:bg-gray-50 transition-colors group">
                      <span class="text-xs text-gray-400 font-mono w-6 text-right">{String(i + 1).padStart(2, '0')}</span>
                      <span class="text-gray-900 font-medium flex-1 truncate">{player.name}</span>
                      {#if selectedGame.status === 'LOBBY_OPEN'}
                        <button
                          onclick={() => removePlayer(player.id)}
                          class="p-1 rounded-lg opacity-0 group-hover:opacity-100 hover:bg-red-50 text-gray-300 hover:text-red-500 transition-all"
                          title="Remove player"
                        >
                          <Trash2 size={12} />
                        </button>
                      {/if}
                    </div>
                  {:else}
                    <div class="col-span-2 py-12 text-center text-gray-400">
                      <Users size={32} class="mx-auto mb-3 opacity-30" />
                      <p>Waiting for players to join...</p>
                    </div>
                  {/each}
                </div>
              </div>
            </div>
          </div>

          <!-- Lobby Action Buttons -->
          <div class="flex gap-4 mt-6 justify-center">
            <button
              onclick={closeLobby}
              disabled={isProcessing}
              class="flex items-center justify-center gap-2 px-8 py-3.5 rounded-xl border-2 border-orange-300 bg-white hover:bg-orange-50 hover:border-orange-400 disabled:bg-gray-100 disabled:border-gray-200 disabled:text-gray-400 text-orange-600 font-semibold transition-all active:scale-[0.98]"
            >
              <Lock size={18} />
              CLOSE LOBBY
            </button>

            <button
              onclick={startGame}
              disabled={isProcessing || activePlayerCount === 0}
              class="flex items-center justify-center gap-2 px-12 py-3.5 rounded-xl bg-purple-600 hover:bg-purple-700 disabled:bg-gray-200 disabled:text-gray-400 text-white font-bold text-lg transition-all active:scale-[0.98] shadow-lg shadow-purple-600/25"
            >
              <Play size={20} />
              START GAME
            </button>
          </div>
        </div>

      <!-- ========== NORMAL DASHBOARD VIEW ========== -->
      {:else}

        <!-- Game Selector -->
        <div class="grid grid-cols-3 gap-4 animate-slide-up">
          {#each games as game (game.id)}
            <button
              onclick={() => selectGame(game.id)}
              class="glass-strong rounded-2xl p-5 text-left transition-all hover:shadow-md {selectedGameId === game.id ? 'ring-2 ring-purple-500 border-purple-300 shadow-lg' : ''}"
            >
              <div class="flex items-center justify-between mb-3">
                <span class="text-lg font-bold text-gray-900">Game {game.game_number}</span>
                <span class="px-2.5 py-1 rounded-full text-xs font-semibold {getStatusColor(game.status)}">
                  {getStatusLabel(game.status)}
                </span>
              </div>

              <div class="space-y-2">
                <div class="flex items-center gap-2 text-sm text-gray-500">
                  <Users size={14} />
                  <span>{players.filter(p => p.game_id === game.id && p.is_active).length} / {game.max_players} Players</span>
                </div>
                <div class="flex items-center gap-2 text-sm text-gray-500">
                  <FileText size={14} />
                  <span>Question {game.current_question_number} / {game.total_questions}</span>
                </div>
                {#if game.leaderboard_public}
                  <div class="flex items-center gap-2 text-sm text-green-600">
                    <Eye size={14} />
                    <span>Leaderboard Visible</span>
                  </div>
                {/if}
              </div>
            </button>
          {/each}
        </div>

        {#if selectedGame}
          <div class="grid grid-cols-12 gap-6">

            <!-- Left Column: Controls -->
            <div class="col-span-4 space-y-6 animate-slide-up">

              <!-- Game Controls -->
              <div class="glass-strong rounded-2xl p-5">
                <h3 class="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-4 flex items-center gap-2">
                  <Settings size={16} />
                  Game Controls
                </h3>

                <div class="space-y-3">
                  <button
                    onclick={openLobby}
                    disabled={isProcessing || (selectedGame.status !== 'NOT_STARTED' && selectedGame.status !== 'COMPLETED')}
                    class="w-full flex items-center justify-center gap-2 py-3 rounded-xl bg-green-600 hover:bg-green-500 disabled:bg-gray-100 disabled:text-gray-400 text-white font-semibold transition-all active:scale-[0.98]"
                  >
                    <Unlock size={18} />
                    OPEN LOBBY
                  </button>

                  <button
                    onclick={pauseGame}
                    disabled={isProcessing || selectedGame.status !== 'PLAYING'}
                    class="w-full flex items-center justify-center gap-2 py-3 rounded-xl bg-orange-500 hover:bg-orange-400 disabled:bg-gray-100 disabled:text-gray-400 text-white font-semibold transition-all active:scale-[0.98]"
                  >
                    <Pause size={18} />
                    PAUSE GAME
                  </button>

                  <button
                    onclick={resumeGame}
                    disabled={isProcessing || selectedGame.status !== 'PAUSED'}
                    class="w-full flex items-center justify-center gap-2 py-3 rounded-xl bg-green-600 hover:bg-green-500 disabled:bg-gray-100 disabled:text-gray-400 text-white font-semibold transition-all active:scale-[0.98]"
                  >
                    <Play size={18} />
                    RESUME GAME
                  </button>

                  <button
                    onclick={skipQuestion}
                    disabled={isProcessing || selectedGame.status !== 'PLAYING' || !selectedGame.current_question_id}
                    class="w-full flex items-center justify-center gap-2 py-3 rounded-xl bg-gray-100 hover:bg-gray-200 disabled:bg-gray-50 disabled:text-gray-300 text-gray-700 font-semibold transition-all active:scale-[0.98]"
                  >
                    <SkipForward size={18} />
                    SKIP QUESTION
                  </button>

                  <button
                    onclick={nextQuestion}
                    disabled={isProcessing || selectedGame.status !== 'QUESTION_LOCKED'}
                    class="w-full flex items-center justify-center gap-2 py-3 rounded-xl bg-cyan-500 hover:bg-cyan-400 disabled:bg-gray-100 disabled:text-gray-400 text-white font-semibold transition-all active:scale-[0.98]"
                  >
                    <ChevronRight size={18} />
                    NEXT QUESTION
                  </button>

                  <button
                    onclick={endGame}
                    disabled={isProcessing || (selectedGame.status !== 'PLAYING' && selectedGame.status !== 'PAUSED' && selectedGame.status !== 'QUESTION_LOCKED')}
                    class="w-full flex items-center justify-center gap-2 py-3 rounded-xl bg-red-600 hover:bg-red-500 disabled:bg-gray-100 disabled:text-gray-400 text-white font-semibold transition-all active:scale-[0.98]"
                  >
                    <AlertTriangle size={18} />
                    END GAME
                  </button>

                  <button
                    onclick={resetGame}
                    disabled={isProcessing}
                    class="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl bg-white border border-gray-200 hover:bg-red-50 hover:border-red-200 disabled:text-gray-300 text-gray-500 hover:text-red-500 text-sm font-medium transition-all"
                  >
                    <RefreshCcw size={16} />
                    RESET GAME
                  </button>
                </div>
              </div>

              <!-- Projector Controls -->
              <div class="glass-strong rounded-2xl p-5">
                <h3 class="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-4 flex items-center gap-2">
                  <Monitor size={16} />
                  Projector Controls
                </h3>

                <div class="space-y-3">
                  <button
                    onclick={showLeaderboardOnProjector}
                    disabled={isProcessing}
                    class="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl bg-purple-50 border border-purple-200 hover:bg-purple-100 text-purple-700 font-medium transition-all text-sm"
                  >
                    <Eye size={16} />
                    SHOW LEADERBOARD ON PROJECTOR
                  </button>

                  <button
                    onclick={hideLeaderboardFromProjector}
                    disabled={isProcessing}
                    class="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl bg-white border border-gray-200 hover:bg-gray-50 text-gray-600 font-medium transition-all text-sm"
                  >
                    <EyeOff size={16} />
                    HIDE LEADERBOARD FROM PROJECTOR
                  </button>

                  <button
                    onclick={showFinalResult}
                    disabled={isProcessing}
                    class="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl bg-amber-50 border border-amber-200 hover:bg-amber-100 text-amber-700 font-medium transition-all text-sm"
                  >
                    <Trophy size={16} />
                    SHOW FINAL RESULT
                  </button>

                  <button
                    onclick={showEventChampions}
                    disabled={isProcessing}
                    class="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl bg-cyan-50 border border-cyan-200 hover:bg-cyan-100 text-cyan-700 font-medium transition-all text-sm"
                  >
                    <Star size={16} />
                    SHOW EVENT CHAMPIONS
                  </button>
                </div>
              </div>

              <!-- Current Question Display -->
              {#if selectedGame.status === 'PLAYING' || selectedGame.status === 'QUESTION_LOCKED' || selectedGame.status === 'PAUSED'}
                <div class="glass-strong rounded-2xl p-5">
                  <h3 class="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-4 flex items-center gap-2">
                    <FileText size={16} />
                    Current Question
                  </h3>

                  {#if selectedGame.current_question_id}
                    {@const currentQ = (questions[selectedGame.game_number] || []).find(q => q.id === selectedGame.current_question_id)}
                    {#if currentQ}
                      <div class="space-y-3">
                        <div class="flex items-center justify-between">
                          <span class="text-gray-500 text-sm">Question #{selectedGame.current_question_number}</span>
                          <span class="px-2 py-0.5 rounded text-xs font-semibold {getDiffColor(currentQ.difficulty)}">
                            {currentQ.difficulty}
                          </span>
                        </div>

                        <div class="bg-gray-50 rounded-xl p-4 text-center border border-gray-100">
                          <p class="text-2xl font-black tracking-widest text-gray-900 select-none">
                            {currentQ.jumbled_word}
                          </p>
                        </div>

                        <div class="space-y-2">
                          <div class="flex items-center gap-2">
                            <CheckCircle size={14} class="text-green-600" />
                            <span class="text-sm text-gray-600">Answer:</span>
                            <span class="text-sm font-bold text-green-600">{currentQ.correct_word}</span>
                          </div>
                          <div class="flex items-center gap-2">
                            <Lightbulb size={14} class="text-amber-500" />
                            <span class="text-sm text-gray-600">Hint:</span>
                            <span class="text-sm text-gray-700">{currentQ.hint}</span>
                          </div>
                          <div class="flex items-center gap-2">
                            <BarChart3 size={14} class="text-purple-500" />
                            <span class="text-sm text-gray-600">Category:</span>
                            <span class="text-sm text-gray-700">{currentQ.category}</span>
                          </div>
                        </div>

                        <div class="flex items-center justify-between pt-2 border-t border-gray-100">
                          <div class="flex items-center gap-2">
                            <Timer size={14} class={timeRemaining <= 10 ? 'text-red-500' : 'text-gray-400'} />
                            <span class="text-sm font-mono font-bold {timeRemaining <= 10 ? 'text-red-500' : 'text-gray-900'}">
                              {formatTime(timeRemaining)}
                            </span>
                          </div>
                          <div class="flex items-center gap-2">
                            <Users size={14} class="text-gray-400" />
                            <span class="text-sm text-gray-500">
                              {players.filter(p => p.game_id === selectedGame.id && p.is_active).length} active
                            </span>
                          </div>
                        </div>
                      </div>
                    {:else}
                      <p class="text-gray-400 text-sm">Question data not loaded</p>
                    {/if}
                  {:else}
                    <p class="text-gray-400 text-sm">No active question</p>
                  {/if}
                </div>
              {/if}
            </div>

            <!-- Right Column: Players & Leaderboard -->
            <div class="col-span-8 space-y-6 animate-slide-up">

              <!-- Player List (table for gameplay) -->
              <div class="glass-strong rounded-2xl p-5">
                <h3 class="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-4 flex items-center gap-2">
                  <Users size={16} />
                  Players ({activePlayerCount})
                </h3>

                <div class="overflow-x-auto">
                  <table class="w-full text-sm">
                    <thead>
                      <tr class="border-b border-gray-100">
                        <th class="text-left py-2 px-3 text-gray-400 font-medium">Name</th>
                        <th class="text-center py-2 px-3 text-gray-400 font-medium">Score</th>
                        <th class="text-center py-2 px-3 text-gray-400 font-medium">Hints</th>
                        <th class="text-center py-2 px-3 text-gray-400 font-medium">Status</th>
                      </tr>
                    </thead>
                    <tbody>
                      {#each players.filter(p => p.game_id === selectedGameId) as player (player.id)}
                        <tr class="border-b border-gray-50 hover:bg-gray-50 transition-colors">
                          <td class="py-2.5 px-3 text-gray-900 font-medium">{player.name}</td>
                          <td class="py-2.5 px-3 text-center">
                            <span class="text-purple-600 font-bold">{player.score}</span>
                            <span class="text-gray-400"> / 20</span>
                          </td>
                          <td class="py-2.5 px-3 text-center text-gray-500">{player.hints_used || 0}</td>
                          <td class="py-2.5 px-3 text-center">
                            {#if player.is_active}
                              <span class="px-2 py-0.5 rounded-full text-xs bg-green-50 text-green-700 border border-green-200">Active</span>
                            {:else}
                              <span class="px-2 py-0.5 rounded-full text-xs bg-red-50 text-red-600 border border-red-200">Removed</span>
                            {/if}
                          </td>
                        </tr>
                      {:else}
                        <tr>
                          <td colspan="4" class="py-8 text-center text-gray-400">
                            No players yet
                          </td>
                        </tr>
                      {/each}
                    </tbody>
                  </table>
                </div>
              </div>

              <!-- Private Leaderboard -->
              <div class="glass-strong rounded-2xl p-5 border border-purple-200">
                <h3 class="text-sm font-semibold text-purple-700 uppercase tracking-wider mb-4 flex items-center gap-2">
                  <Crown size={16} />
                  HOST ONLY - PRIVATE LEADERBOARD
                </h3>

                <div class="space-y-2">
                  {#each leaderboard as entry (entry.player_id)}
                    <div class="flex items-center gap-4 px-4 py-3 rounded-xl bg-gray-50 {entry.rank <= 3 ? 'border border-gray-200' : ''}">
                      <div class="w-8 text-center">
                        {#if entry.rank === 1}
                          <span class="text-amber-600 font-bold">#1</span>
                        {:else if entry.rank === 2}
                          <span class="text-gray-500 font-bold">#2</span>
                        {:else if entry.rank === 3}
                          <span class="text-orange-500 font-bold">#3</span>
                        {:else}
                          <span class="text-gray-400">#{entry.rank}</span>
                        {/if}
                      </div>
                      <div class="flex-1">
                        <p class="text-gray-900 font-medium">{entry.name}</p>
                      </div>
                      <div class="text-right">
                        <span class="text-purple-600 font-bold text-lg">{entry.score}</span>
                        <span class="text-gray-400 text-sm"> / 20</span>
                      </div>
                    </div>
                  {:else}
                    <div class="py-6 text-center text-gray-400 text-sm">
                      No leaderboard data yet
                    </div>
                  {/each}
                </div>
              </div>

            </div>
          </div>
        {:else}
          <div class="glass-strong rounded-2xl p-12 text-center animate-fade-in">
            <div class="text-gray-300 mb-4">
              <Settings size={48} class="mx-auto" />
            </div>
            <p class="text-gray-500 text-lg">Select a game to manage</p>
            <p class="text-gray-400 text-sm mt-2">Click on one of the game cards above</p>
          </div>
        {/if}
      {/if}
    </div>
  </div>
{/if}

<!-- ========== QUESTION BANK MODAL ========== -->
{#if showQuestionBank}
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm"
    role="dialog"
    tabindex="-1"
    onclick={closeQuestionBank}
    onkeydown={(e) => { if (e.key === 'Escape') closeQuestionBank(); }}
  >
    <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
    <div
      class="bg-white rounded-2xl w-full max-w-5xl mx-4 max-h-[85vh] flex flex-col animate-scale-in border border-gray-200 shadow-2xl"
      onclick={(e) => e.stopPropagation()}
      onkeydown={(e) => e.stopPropagation()}
      role="document"
    >
      <div class="flex items-center justify-between px-6 py-4 border-b border-gray-100">
        <h3 class="text-lg font-semibold text-gray-900 flex items-center gap-2">
          <FileText size={20} />
          Question Bank
        </h3>
        <button
          onclick={closeQuestionBank}
          class="p-2 rounded-xl hover:bg-gray-100 text-gray-400 hover:text-gray-600 transition-all"
          title="Close"
        >
          <X size={20} />
        </button>
      </div>

      <div class="flex gap-2 px-6 pt-4 border-b border-gray-100">
        {#each ['GAME 1', 'GAME 2', 'GAME 3', 'TIE BREAKERS'] as tab}
          <button
            onclick={() => activeTab = tab}
            class="px-4 py-2 rounded-lg text-sm font-medium transition-all {activeTab === tab ? 'bg-purple-50 text-purple-700 border border-purple-200' : 'text-gray-500 hover:text-gray-700 hover:bg-gray-50'}"
          >
            {tab}
          </button>
        {/each}
      </div>

      <div class="overflow-auto flex-1 p-6">
        <table class="w-full text-sm">
          <thead class="sticky top-0 bg-gray-50/80 backdrop-blur-sm">
            <tr class="border-b border-gray-100">
              <th class="text-left py-2 px-3 text-gray-400 font-medium">#</th>
              <th class="text-left py-2 px-3 text-gray-400 font-medium">Jumbled</th>
              <th class="text-left py-2 px-3 text-gray-400 font-medium">Correct</th>
              <th class="text-left py-2 px-3 text-gray-400 font-medium">Hint</th>
              <th class="text-center py-2 px-3 text-gray-400 font-medium">Diff</th>
              <th class="text-left py-2 px-3 text-gray-400 font-medium">Category</th>
            </tr>
          </thead>
          <tbody>
            {#each (activeTab === 'TIE BREAKERS' ? questions.tiebreakers : questions[parseInt(activeTab.split(' ')[1])] || []) as q (q.id)}
              <tr class="border-b border-gray-50 hover:bg-gray-50 transition-colors">
                <td class="py-2 px-3 text-gray-400">{q.question_order}</td>
                <td class="py-2 px-3 font-mono text-gray-700 tracking-wider">{q.jumbled_word}</td>
                <td class="py-2 px-3 font-mono font-bold text-green-600 tracking-wider">{q.correct_word}</td>
                <td class="py-2 px-3 text-gray-500 max-w-[200px] truncate" title={q.hint}>{q.hint}</td>
                <td class="py-2 px-3 text-center">
                  <span class="px-2 py-0.5 rounded text-xs font-semibold {getDiffColor(q.difficulty)}">
                    {q.difficulty}
                  </span>
                </td>
                <td class="py-2 px-3 text-gray-500">{q.category}</td>
              </tr>
            {:else}
              <tr>
                <td colspan="6" class="py-8 text-center text-gray-400">
                  No questions available
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    </div>
  </div>
{/if}

<!-- ========== CONFIRMATION DIALOG ========== -->
{#if showConfirmDialog}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm">
    <div class="bg-white rounded-2xl p-6 max-w-md w-full mx-4 animate-scale-in border border-gray-200 shadow-2xl">
      <div class="flex items-center gap-3 mb-4">
        <div class="p-2 rounded-xl bg-amber-50 border border-amber-200">
          <AlertTriangle size={24} class="text-amber-500" />
        </div>
        <h3 class="text-lg font-semibold text-gray-900">Confirm Action</h3>
      </div>
      <p class="text-gray-600 mb-6">{confirmMessage}</p>
      <div class="flex gap-3">
        <button
          onclick={cancelConfirm}
          class="flex-1 py-2.5 rounded-xl bg-gray-100 border border-gray-200 text-gray-600 hover:bg-gray-200 font-medium transition-all"
        >
          Cancel
        </button>
        <button
          onclick={handleConfirm}
          class="flex-1 py-2.5 rounded-xl bg-red-600 hover:bg-red-500 text-white font-semibold transition-all"
        >
          Confirm
        </button>
      </div>
    </div>
  </div>
{/if}
