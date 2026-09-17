<script>
  import { getSupabase } from '$lib/supabase/client';

  let { gameNumber } = $props();

  const supabase = getSupabase();

  let screen = $state('LOADING');
  let loading = $state(true);
  let error = $state('');
  let isOnline = $state(true);

  let deviceSessionId = $state('');
  let playerName = $state('');
  let playerId = $state(null);

  let currentGame = $state(null);
  let players = $state([]);
  let playerCount = $state(0);

  let questionNumber = $state(0);
  let totalQuestions = $state(20);
  let jumbledWord = $state('');
  let answerInput = $state('');
  let submittingAnswer = $state(false);
  let hint = $state('');
  let hintsUsed = $state(0);
  let maxHints = 2;
  let wrongAnswer = $state(false);
  let showWrongMessage = $state(false);
  let timeRemaining = $state(0);
  let serverTimeOffset = $state(0);
  let questionDeadline = $state(null);
  let timerInterval = null;
  let countdownNumber = $state(null);
  let questionWinner = $state(null);
  let winnerName = $state('');
  let correctAnswer = $state('');
  let isTimedOut = $state(false);

  let subscriptions = $state([]);

  function getOrCreateSession() {
    let stored = localStorage.getItem('wr_session');
    if (!stored) {
      stored = crypto.randomUUID();
      localStorage.setItem('wr_session', stored);
    }
    deviceSessionId = stored;
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

  async function checkSession() {
    loading = true;
    error = '';
    try {
      const { data: gameInfo, error: gameError } = await supabase
        .from('games')
        .select('*')
        .eq('game_number', gameNumber)
        .single();

      if (gameError || !gameInfo) {
        error = 'Game not found.';
        loading = false;
        screen = 'ERROR';
        return;
      }

      currentGame = gameInfo;

      const { data: existing, error: fetchError } = await supabase
        .from('players')
        .select('*')
        .eq('device_session_id', deviceSessionId)
        .eq('game_id', gameInfo.id)
        .eq('is_active', true)
        .maybeSingle();

      if (fetchError) {
        throw fetchError;
      }

      if (existing) {
        playerId = existing.id;
        playerName = existing.name;

        if (gameInfo.status === 'LOBBY_OPEN') {
          screen = 'LOBBY';
          await subscribeToGame(gameInfo.id);
          await loadPlayers(gameInfo.id);
        } else if (gameInfo.status === 'COUNTDOWN') {
          screen = 'COUNTDOWN';
          await subscribeToGame(gameInfo.id);
        } else if (gameInfo.status === 'PLAYING' || gameInfo.status === 'QUESTION_LOCKED') {
          screen = 'PLAYING';
          await subscribeToGame(gameInfo.id);
          await loadCurrentQuestion();
        } else if (gameInfo.status === 'COMPLETED') {
          screen = 'GAME_COMPLETED';
        } else {
          screen = 'WAITING';
        }
      } else {
        if (gameInfo.status === 'LOBBY_OPEN') {
          const { count } = await supabase
            .from('players')
            .select('id', { count: 'exact', head: true })
            .eq('game_id', gameInfo.id)
            .eq('is_active', true);

          if (count >= 20) {
            screen = 'GAME_FULL';
          } else {
            screen = 'REGISTRATION';
          }
        } else if (gameInfo.status === 'COMPLETED') {
          screen = 'GAME_COMPLETED';
        } else if (['PLAYING', 'QUESTION_LOCKED', 'COUNTDOWN'].includes(gameInfo.status)) {
          screen = 'GAME_PLAYING';
        } else {
          screen = 'WAITING';
        }
      }
    } catch (e) {
      console.error('[WORD RUSH] Session check failed:', e?.message || e);
      error = 'Failed to load game. Please refresh.';
      screen = 'ERROR';
    } finally {
      loading = false;
    }
  }

  async function loadPlayers(gameId) {
    const { data, error: fetchError } = await supabase
      .from('players')
      .select('id, name')
      .eq('game_id', gameId)
      .eq('is_active', true);

    if (!fetchError) {
      players = data || [];
      playerCount = players.length;
    }
  }

  async function loadCurrentQuestion() {
    if (!currentGame?.id) return;
    const { data: game, error: fetchError } = await supabase
      .from('games')
      .select('current_question_number, current_question_id, question_deadline, question_started_at, total_questions, status')
      .eq('id', currentGame.id)
      .single();

    if (fetchError || !game) return;

    questionNumber = game.current_question_number;
    totalQuestions = game.total_questions;
    questionDeadline = game.question_deadline;

    if (game.current_question_id) {
      const { data: q } = await supabase
        .from('questions')
        .select('jumbled_word, hint')
        .eq('id', game.current_question_id)
        .single();

      if (q) {
        jumbledWord = q.jumbled_word;
        hint = '';
        wrongAnswer = false;
        showWrongMessage = false;
      }
    }

    const { data: playerData } = await supabase
      .from('players')
      .select('hints_used')
      .eq('id', playerId)
      .single();

    if (playerData) {
      hintsUsed = playerData.hints_used || 0;
    }

    startTimer();
  }

  function startTimer() {
    if (timerInterval) clearInterval(timerInterval);
    if (!questionDeadline) return;

    timerInterval = setInterval(() => {
      const now = Date.now() - serverTimeOffset;
      const deadline = new Date(questionDeadline).getTime();
      const remaining = Math.max(0, Math.floor((deadline - now) / 1000));
      timeRemaining = remaining;

      if (remaining <= 0) {
        clearInterval(timerInterval);
        timeRemaining = 0;
      }
    }, 100);
  }

  function formatTime(seconds) {
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  }

  async function joinGame() {
    if (!playerName.trim()) {
      error = 'Please enter your name.';
      return;
    }

    loading = true;
    error = '';

    try {
      const { data, error: rpcError } = await supabase.rpc('join_game', {
        p_game_number: gameNumber,
        p_name: playerName.trim(),
        p_device_session_id: deviceSessionId
      });

      if (rpcError) throw rpcError;

      if (data?.error) {
        if (data.error === 'GAME_FULL') {
          screen = 'GAME_FULL';
        } else {
          error = data.message || data.error;
        }
        loading = false;
        return;
      }

      playerId = data.player_id;
      currentGame = { id: data.game_id, game_number: data.game_number, status: 'LOBBY_OPEN' };
      screen = 'LOBBY';
      await subscribeToGame(data.game_id);
      await loadPlayers(data.game_id);
    } catch (e) {
      console.error('Join failed:', e);
      error = e.message || 'Failed to join. Please try again.';
    } finally {
      loading = false;
    }
  }

  async function submitAnswer() {
    if (!answerInput.trim() || submittingAnswer || timeRemaining <= 0) return;

    submittingAnswer = true;
    showWrongMessage = false;
    wrongAnswer = false;

    try {
      const { data, error: rpcError } = await supabase.rpc('submit_answer', {
        p_player_id: playerId,
        p_game_id: currentGame.id,
        p_question_id: currentGame.current_question_id,
        p_answer: answerInput.trim()
      });

      if (rpcError) throw rpcError;

      if (data?.error) {
        if (data.message === 'Incorrect answer') {
          wrongAnswer = true;
          showWrongMessage = true;
          setTimeout(() => { showWrongMessage = false; }, 2000);
        }
      } else {
        answerInput = '';
      }
    } catch (e) {
      console.error('Submit answer failed:', e);
    } finally {
      submittingAnswer = false;
    }
  }

  async function requestHint() {
    if (hintsUsed >= maxHints) return;

    try {
      const { data, error: rpcError } = await supabase.rpc('request_hint', {
        p_player_id: playerId,
        p_game_id: currentGame.id,
        p_question_id: currentGame.current_question_id
      });

      if (rpcError) throw rpcError;

      if (data?.hint) {
        hint = data.hint;
        hintsUsed = (hintsUsed || 0) + 1;
      }
    } catch (e) {
      console.error('Hint request failed:', e);
    }
  }

  function subscribeToGame(gameId) {
    cleanupSubscriptions();

    const gameChannel = supabase
      .channel(`game-${gameId}`)
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'games',
        filter: `id=eq.${gameId}`
      }, async (payload) => {
        const g = payload.new;
        currentGame = { ...currentGame, ...g };

        if (g.status === 'LOBBY_OPEN') {
          screen = 'LOBBY';
          await loadPlayers(gameId);
        } else if (g.status === 'COUNTDOWN') {
          screen = 'COUNTDOWN';
          startCountdown();
        } else if (g.status === 'PLAYING') {
          if (screen === 'COUNTDOWN') {
            screen = 'PLAYING';
          }
          await loadCurrentQuestion();
        } else if (g.status === 'QUESTION_LOCKED') {
        } else if (g.status === 'COMPLETED') {
          screen = 'GAME_COMPLETED';
          clearInterval(timerInterval);
        }
      })
      .subscribe();

    subscriptions.push(gameChannel);

    const playerChannel = supabase
      .channel(`players-${gameId}`)
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'players',
        filter: `game_id=eq.${gameId}`
      }, async () => {
        await loadPlayers(gameId);
      })
      .subscribe();

    subscriptions.push(playerChannel);

    const resultChannel = supabase
      .channel(`results-${gameId}`)
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'question_results',
        filter: `game_id=eq.${gameId}`
      }, async (payload) => {
        const r = payload.new;
        if (r.result_type === 'NORMAL' && r.winner_player_id) {
          questionWinner = r.winner_player_id;
          isTimedOut = false;
          correctAnswer = '';
          const { data: winnerPlayer } = await supabase
            .from('players')
            .select('name')
            .eq('id', r.winner_player_id)
            .single();
          if (winnerPlayer) {
            winnerName = winnerPlayer.name;
          }
          if (screen === 'PLAYING') {
            screen = 'QUESTION_RESULT';
          }
        } else if (r.result_type === 'TIMEOUT') {
          isTimedOut = true;
          correctAnswer = '';
          winnerName = '';
          questionWinner = null;
          if (screen === 'PLAYING') {
            screen = 'QUESTION_RESULT';
          }
        }
      })
      .subscribe();

    subscriptions.push(resultChannel);
  }

  function startCountdown() {
    screen = 'COUNTDOWN';
    countdownNumber = 'GET READY';
    const steps = [
      { text: 'GET READY', delay: 800 },
      { text: '3', delay: 800 },
      { text: '2', delay: 800 },
      { text: '1', delay: 800 },
      { text: 'GO!', delay: 500 }
    ];

    let i = 0;
    function nextStep() {
      if (i < steps.length) {
        countdownNumber = steps[i].text;
        i++;
        setTimeout(nextStep, steps[i - 1].delay);
      } else {
        screen = 'PLAYING';
        countdownNumber = null;
        loadCurrentQuestion();
      }
    }
    nextStep();
  }

  function cleanupSubscriptions() {
    subscriptions.forEach(ch => {
      supabase.removeChannel(ch);
    });
    subscriptions = [];
  }

  function handleOnline() {
    isOnline = true;
    checkSession();
  }

  function handleOffline() {
    isOnline = false;
  }

  $effect(() => {
    getOrCreateSession();
    syncServerTime();
    checkSession();

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
      cleanupSubscriptions();
      if (timerInterval) clearInterval(timerInterval);
    };
  });

  function handleJoinKeydown(e) {
    if (e.key === 'Enter' && !loading) {
      joinGame();
    }
  }

  function handleAnswerKeydown(e) {
    if (e.key === 'Enter' && !submittingAnswer && timeRemaining > 0) {
      submitAnswer();
    }
  }
</script>

{#if !isOnline}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm">
    <div class="glass-strong rounded-2xl p-8 text-center animate-fade-in">
      <div class="text-3xl mb-3">&#x1F4E1;</div>
      <p class="text-lg font-semibold text-gray-900">Connection Lost</p>
      <p class="text-sm text-gray-500 mt-1">Reconnecting...</p>
    </div>
  </div>
{/if}

{#if loading && screen === 'LOADING'}
  <div class="min-h-screen flex items-center justify-center">
    <div class="text-center animate-fade-in">
      <div class="inline-block w-12 h-12 border-4 border-purple-500 border-t-transparent rounded-full animate-spin mb-4"></div>
      <p class="text-gray-500">Loading...</p>
    </div>
  </div>

{:else if screen === 'ERROR'}
  <div class="min-h-screen flex items-center justify-center p-4">
    <div class="w-full max-w-md animate-fade-in text-center space-y-6">
      <div>
        <h1 class="text-4xl font-bold tracking-tight text-purple-700">WORD RUSH</h1>
        <p class="text-gray-500 mt-2 text-sm tracking-wide">Unscramble. Think Fast. Win.</p>
      </div>
      <div class="glass-strong rounded-2xl p-6 space-y-4">
        <div class="bg-red-50 border border-red-200 rounded-xl px-4 py-3 text-sm text-red-600">
          {error || 'Something went wrong. Please refresh.'}
        </div>
      </div>
    </div>
  </div>

{:else if screen === 'REGISTRATION'}
  <div class="min-h-screen flex items-center justify-center p-4">
    <div class="w-full max-w-md animate-fade-in">
        <div class="text-center mb-8">
        <h1 class="text-4xl font-bold tracking-tight text-purple-700">WORD RUSH</h1>
        <p class="text-gray-500 mt-2 text-sm tracking-wide">Unscramble. Think Fast. Win.</p>
      </div>

      <div class="glass-strong rounded-2xl p-6 space-y-5">
        {#if error}
          <div class="bg-red-50 border border-red-200 rounded-xl px-4 py-3 text-sm text-red-600">
            {error}
          </div>
        {/if}

        <div>
          <label for="player-name" class="block text-xs font-medium text-gray-500 mb-1.5 uppercase tracking-wider">Enter Your Name</label>
          <input
            id="player-name"
            type="text"
            bind:value={playerName}
            placeholder="Your name"
            disabled={loading}
            autocomplete="off"
            class="w-full px-4 py-3 rounded-xl bg-white border border-gray-200 text-gray-900 placeholder-gray-400 focus:border-purple-500 focus:ring-2 focus:ring-purple-500/20 transition-colors outline-none"
          />
        </div>

        <button
          onclick={joinGame}
          disabled={loading || !playerName.trim()}
          class="w-full py-3.5 rounded-xl bg-purple-600 hover:bg-purple-700 disabled:bg-gray-200 disabled:text-gray-400 text-white font-semibold text-lg transition-all active:scale-[0.98] shadow-lg shadow-purple-600/25"
        >
          {#if loading}
            <span class="inline-block w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin"></span>
          {:else}
            JOIN GAME
          {/if}
        </button>
      </div>
    </div>
  </div>

{:else if screen === 'LOBBY'}
  <div class="min-h-screen flex items-center justify-center p-4">
    <div class="w-full max-w-md animate-scale-in">
      <div class="text-center mb-6">
        <h1 class="text-3xl font-bold text-gray-900">YOU'RE IN!</h1>
      </div>

      <div class="glass-strong rounded-2xl p-6 space-y-4">
        <div class="text-center space-y-1">
          <p class="text-xl font-semibold text-gray-900">{playerName}</p>
        </div>

        <div class="flex items-center justify-center gap-3 py-4">
          <div class="text-center">
            <p class="text-4xl font-bold text-purple-600">{playerCount}</p>
            <p class="text-xs text-gray-400 mt-1">/ 20 Players</p>
          </div>
        </div>

        <p class="text-center text-gray-400 text-sm animate-pulse">
          Waiting for the host to start...
        </p>
      </div>
    </div>
  </div>

{:else if screen === 'COUNTDOWN'}
  <div class="min-h-screen flex items-center justify-center p-4">
    <div class="text-center animate-fade-in">
      <div class="text-9xl font-black text-purple-600 animate-countdown select-none">
        {countdownNumber}
      </div>
    </div>
  </div>

{:else if screen === 'PLAYING'}
  <div class="min-h-screen flex flex-col p-4 max-w-lg mx-auto">
    <div class="flex items-center justify-end mb-4">
      <span class="text-xs text-gray-400">
        QUESTION {questionNumber} / {totalQuestions}
      </span>
    </div>

    <div class="flex-1 flex flex-col items-center justify-center gap-6">
      <div class="glass-strong rounded-2xl p-6 w-full text-center">
        <p class="text-xs text-gray-400 uppercase tracking-widest mb-4">Unscramble this word</p>
        <div class="text-3xl sm:text-4xl font-black tracking-widest text-gray-900 select-none py-4">
          {jumbledWord}
        </div>
      </div>

      {#if hint}
        <div class="w-full glass rounded-xl px-4 py-3 border border-amber-200 bg-amber-50">
          <p class="text-xs text-amber-600 uppercase tracking-wider mb-1">Hint</p>
          <p class="text-sm text-amber-700">{hint}</p>
        </div>
      {/if}

      <div class="w-full glass rounded-2xl p-5 space-y-4">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2">
            <div class="text-2xl font-mono font-bold {timeRemaining <= 10 ? 'text-red-500 animate-pulse' : 'text-gray-900'}">
              {formatTime(timeRemaining)}
            </div>
          </div>
          <div class="text-xs text-gray-400">
            Hints Left: {maxHints - hintsUsed}
          </div>
        </div>

        <div class="relative">
          <input
            type="text"
            bind:value={answerInput}
            onkeydown={handleAnswerKeydown}
            placeholder="Type your answer..."
            disabled={submittingAnswer || timeRemaining <= 0}
            autocomplete="off"
            autocapitalize="off"
            autocorrect="off"
            spellcheck="false"
            class="w-full px-5 py-4 rounded-xl bg-white border-2 {wrongAnswer ? 'border-red-400' : 'border-gray-200 focus:border-purple-500'} text-gray-900 text-xl text-center tracking-wide placeholder-gray-300 transition-all outline-none"
          />
        </div>

        {#if showWrongMessage}
          <p class="text-center text-red-500 text-sm font-medium animate-fade-in">
            Wrong Answer - Try Again!
          </p>
        {/if}

        <div class="flex gap-3">
          <button
            onclick={requestHint}
            disabled={hintsUsed >= maxHints || timeRemaining <= 0}
            class="flex-shrink-0 px-4 py-3 rounded-xl bg-gray-100 border border-gray-200 text-gray-600 disabled:text-gray-300 disabled:border-gray-100 text-sm font-medium transition-all active:scale-[0.98]"
          >
            Get Hint
          </button>
          <button
            onclick={submitAnswer}
            disabled={submittingAnswer || !answerInput.trim() || timeRemaining <= 0}
            class="flex-1 py-3 rounded-xl bg-purple-600 hover:bg-purple-700 disabled:bg-gray-200 disabled:text-gray-400 text-white font-semibold text-lg transition-all active:scale-[0.98] shadow-lg shadow-purple-600/25"
          >
            {#if submittingAnswer}
              <span class="inline-block w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin"></span>
            {:else}
              SUBMIT
            {/if}
          </button>
        </div>

        {#if timeRemaining <= 0}
          <p class="text-center text-red-500 font-bold text-lg animate-fade-in">TIME'S UP!</p>
        {/if}
      </div>
    </div>
  </div>

{:else if screen === 'QUESTION_RESULT'}
  <div class="min-h-screen flex items-center justify-center p-4">
    <div class="w-full max-w-md animate-scale-in text-center space-y-6">
      <div class="glass-strong rounded-2xl p-8 space-y-4">
        {#if isTimedOut}
          <div class="text-3xl font-bold text-red-500">Time's Up!</div>
        {:else if questionWinner}
          <div class="space-y-2">
            <div class="text-2xl font-bold text-gray-900">{winnerName}</div>
            <p class="text-purple-600 font-semibold">got it first!</p>
          </div>
        {:else}
          <div class="text-2xl font-bold text-gray-400">No one answered in time</div>
        {/if}

        {#if correctAnswer}
          <div class="pt-2">
            <p class="text-xs text-gray-400 uppercase tracking-wider mb-1">Correct Answer</p>
            <p class="text-3xl font-black tracking-widest text-emerald-600">{correctAnswer}</p>
          </div>
        {/if}
      </div>

      <p class="text-gray-400 text-sm animate-pulse">Waiting for next question...</p>
    </div>
  </div>

{:else if screen === 'GAME_COMPLETED'}
  <div class="min-h-screen flex items-center justify-center p-4">
    <div class="w-full max-w-md animate-scale-in text-center space-y-6">
      <div>
        <h1 class="text-4xl font-bold text-purple-700">WORD RUSH</h1>
      </div>

      <div class="glass-strong rounded-2xl p-8 space-y-4">
        <div class="text-5xl mb-4">&#x1F389;</div>
        <h2 class="text-2xl font-bold text-gray-900">
          Game Completed!
        </h2>
        <p class="text-gray-500">Thank you for playing!</p>
      </div>
    </div>
  </div>

{:else if screen === 'GAME_FULL'}
  <div class="min-h-screen flex items-center justify-center p-4">
    <div class="w-full max-w-md animate-scale-in text-center space-y-6">
      <div>
        <h1 class="text-4xl font-bold text-purple-700">WORD RUSH</h1>
      </div>

      <div class="glass-strong rounded-2xl p-8 space-y-4">
        <div class="text-5xl mb-4">&#x1F512;</div>
        <h2 class="text-2xl font-bold text-gray-900">
          Game Full
        </h2>
        <p class="text-gray-500">The maximum number of players has joined. Please wait for the next round.</p>
      </div>
    </div>
  </div>

{:else if screen === 'GAME_PLAYING'}
  <div class="min-h-screen flex items-center justify-center p-4">
    <div class="w-full max-w-md animate-scale-in text-center space-y-6">
      <div>
        <h1 class="text-4xl font-bold text-purple-700">WORD RUSH</h1>
      </div>

      <div class="glass-strong rounded-2xl p-8 space-y-4">
        <div class="text-5xl mb-4">&#x1F3AE;</div>
        <h2 class="text-2xl font-bold text-gray-900">
          Game In Progress
        </h2>
        <p class="text-gray-500">Please wait for the next round.</p>
      </div>
    </div>
  </div>

{:else if screen === 'WAITING'}
  <div class="min-h-screen flex items-center justify-center p-4">
    <div class="w-full max-w-md animate-scale-in text-center space-y-6">
      <div>
        <h1 class="text-4xl font-bold text-purple-700">WORD RUSH</h1>
      </div>

      <div class="glass-strong rounded-2xl p-8 space-y-4">
        <div class="flex items-center justify-center gap-3">
          <div class="w-3 h-3 rounded-full bg-purple-500 animate-pulse"></div>
        </div>
        <h2 class="text-2xl font-bold text-gray-900">
          Lobby Not Open Yet
        </h2>
        <p class="text-gray-500">Please wait for the host to open the lobby.</p>
      </div>
    </div>
  </div>

{:else}
  <div class="min-h-screen flex items-center justify-center">
    <div class="text-center animate-fade-in">
      <div class="inline-block w-12 h-12 border-4 border-purple-500 border-t-transparent rounded-full animate-spin mb-4"></div>
      <p class="text-gray-500">Loading...</p>
    </div>
  </div>
{/if}
