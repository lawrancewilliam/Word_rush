<script>
  import { onMount } from 'svelte';
  import { getSupabase } from '$lib/supabase/client';
  import QRCode from 'qrcode';

  const supabase = getSupabase();

  let displayState = $state('WAITING');
  let loading = $state(true);
  let currentGame = $state(null);
  let playerCount = $state(0);
  let players = $state([]);
  let jumbledWord = $state('');
  let questionNumber = $state(0);
  let totalQuestions = $state(20);
  let timeRemaining = $state(0);
  let questionDeadline = $state(null);
  let serverTimeOffset = $state(0);
  let timerInterval = null;
  let countdownText = $state('');
  let countdownKey = $state(0);
  let winnerName = $state('');
  let correctAnswer = $state('');
  let isTimedOut = $state(false);
  let leaderboard = $state([]);
  let champions = $state([]);
  let subscriptions = $state([]);
  let qrDataUrl = $state('');
  let joinUrl = $state('');

  const TOTAL_PLAYERS = 20;

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

  async function fetchActiveGame() {
    try {
      const { data: games, error } = await supabase
        .from('games')
        .select('*')
        .order('game_number', { ascending: true });

      if (error) throw error;

      const activeGame = games?.find(g =>
        ['LOBBY_OPEN', 'COUNTDOWN', 'PLAYING', 'QUESTION_LOCKED'].includes(g.status)
      );

      const completedGame = games?.find(g => g.status === 'COMPLETED');

      if (activeGame) {
        currentGame = activeGame;
        totalQuestions = activeGame.total_questions || 20;
        await loadPlayers(activeGame.id);

        if (activeGame.status === 'PLAYING' || activeGame.status === 'QUESTION_LOCKED') {
          await loadQuestionData(activeGame);
        }

        updateDisplayState(activeGame);
      } else if (completedGame) {
        currentGame = completedGame;
        totalQuestions = completedGame.total_questions || 20;
        await loadChampions();
        displayState = 'FINAL_RESULT';
      } else {
        displayState = 'WAITING';
      }
    } catch (e) {
      console.error('Failed to load active game:', e);
    } finally {
      loading = false;
    }
  }

  async function loadPlayers(gameId) {
    const { data, error } = await supabase
      .from('players')
      .select('id, name, score')
      .eq('game_id', gameId)
      .eq('is_active', true);

    if (!error) {
      players = data || [];
      playerCount = players.length;
    }
  }

  async function loadQuestionData(game) {
    if (!game.current_question_id) return;

    questionNumber = game.current_question_number || 0;
    questionDeadline = game.question_deadline;

    const { data: q } = await supabase
      .from('questions')
      .select('jumbled_word')
      .eq('id', game.current_question_id)
      .single();

    if (q) {
      jumbledWord = q.jumbled_word;
    }

    startTimer();
  }

  async function loadLeaderboard() {
    if (!currentGame?.id) return;

    const { data, error } = await supabase
      .from('players')
      .select('name, score')
      .eq('game_id', currentGame.id)
      .eq('is_active', true)
      .order('score', { ascending: false })
      .limit(20);

    if (!error) {
      leaderboard = data || [];
    }
  }

  async function loadChampions() {
    try {
      const { data: games, error } = await supabase
        .from('games')
        .select('id, game_number, status')
        .eq('status', 'COMPLETED')
        .order('game_number', { ascending: true });

      if (error) throw error;

      const champs = [];
      for (const game of (games || [])) {
        const { data: topPlayer } = await supabase
          .from('players')
          .select('name, score')
          .eq('game_id', game.id)
          .eq('is_active', true)
          .order('score', { ascending: false })
          .limit(1)
          .maybeSingle();

        champs.push({
          gameNumber: game.game_number,
          name: topPlayer?.name || '—',
          score: topPlayer?.score || 0
        });
      }

      champions = champs;
    } catch (e) {
      console.error('Failed to load champions:', e);
    }
  }

  function updateDisplayState(game) {
    switch (game.status) {
      case 'LOBBY_OPEN':
        displayState = 'LOBBY';
        generateQR();
        break;
      case 'COUNTDOWN':
        displayState = 'COUNTDOWN';
        runCountdown();
        break;
      case 'PLAYING':
        displayState = 'QUESTION';
        loadQuestionData(game);
        break;
      case 'QUESTION_LOCKED':
        if (game.leaderboard_public) {
          displayState = 'LEADERBOARD';
          loadLeaderboard();
        } else {
          displayState = 'QUESTION';
        }
        break;
      case 'COMPLETED':
        displayState = 'FINAL_RESULT';
        loadChampions();
        break;
    }
  }

  function setupSubscriptions() {
    cleanupSubscriptions();

    const gameChannel = supabase
      .channel('display-games')
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'games'
      }, async (payload) => {
        const game = payload.new;
        currentGame = { ...currentGame, ...game };

        if (payload.eventType === 'INSERT') {
          await fetchActiveGame();
          return;
        }

        await loadPlayers(game.id);
        updateDisplayState(game);
      })
      .subscribe();

    subscriptions.push(gameChannel);

    const playerChannel = supabase
      .channel('display-players')
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'players'
      }, async (payload) => {
        if (currentGame) {
          if (payload.eventType === 'INSERT' || payload.eventType === 'DELETE' || payload.eventType === 'UPDATE') {
            const gameId = payload.new?.game_id || payload.old?.game_id;
            if (gameId === currentGame.id) {
              await loadPlayers(currentGame.id);
            }
          }
        }
      })
      .subscribe();

    subscriptions.push(playerChannel);

    const resultChannel = supabase
      .channel('display-results')
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'question_results'
      }, async (payload) => {
        const result = payload.new;
        if (!currentGame || !result || result.game_id !== currentGame.id) return;

        if (result.result_type === 'NORMAL' && result.winner_player_id) {
          isTimedOut = false;

          const { data: player } = await supabase
            .from('players')
            .select('name')
            .eq('id', result.winner_player_id)
            .single();

          winnerName = player?.name || 'Someone';
          correctAnswer = '';

          if (displayState === 'QUESTION') {
            displayState = 'QUESTION_RESULT';
          }
        } else if (result.result_type === 'TIMEOUT') {
          isTimedOut = true;
          winnerName = '';

          if (displayState === 'QUESTION') {
            displayState = 'QUESTION_RESULT';
          }
        }
      })
      .subscribe();

    subscriptions.push(resultChannel);
  }

  function runCountdown() {
    clearInterval(timerInterval);
    const steps = [
      { text: 'GET READY', delay: 1000 },
      { text: '3', delay: 900 },
      { text: '2', delay: 900 },
      { text: '1', delay: 900 },
      { text: 'GO!', delay: 700 }
    ];

    let i = 0;
    function nextStep() {
      if (i < steps.length) {
        countdownText = steps[i].text;
        countdownKey++;
        i++;
        timerInterval = setTimeout(nextStep, steps[i - 1].delay);
      } else {
        countdownText = '';
        if (currentGame?.status === 'PLAYING') {
          displayState = 'QUESTION';
          loadQuestionData(currentGame);
        }
      }
    }
    nextStep();
  }

  function startTimer() {
    clearInterval(timerInterval);
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

  async function generateQR() {
    try {
      if (!currentGame) return;
      joinUrl = `${window.location.origin}/game${currentGame.game_number}`;
      qrDataUrl = await QRCode.toDataURL(joinUrl, {
        width: 500,
        margin: 2,
        color: { dark: '#1a1040', light: '#ffffff' }
      });
    } catch (e) {
      console.error('QR generation failed:', e);
    }
  }

  function cleanupSubscriptions() {
    subscriptions.forEach(ch => supabase.removeChannel(ch));
    subscriptions = [];
  }

  onMount(() => {
    syncServerTime();
    fetchActiveGame();
    setupSubscriptions();

    return () => {
      cleanupSubscriptions();
      clearInterval(timerInterval);
    };
  });
</script>

<div class="min-h-screen flex items-center justify-center p-6 md:p-12 bg-white">
  {#if loading}
    <div class="text-center animate-fade-in">
      <div class="inline-block w-16 h-16 border-4 border-purple-500 border-t-transparent rounded-full animate-spin mb-6"></div>
      <p class="text-gray-400 text-xl tracking-wide">LOADING...</p>
    </div>

  {:else if displayState === 'WAITING'}
    <div class="text-center space-y-8 animate-fade-in max-w-3xl">
      <div>
        <h1 class="text-6xl md:text-8xl font-black tracking-tight text-purple-700">
          WORD RUSH
        </h1>
        <p class="text-xl md:text-2xl text-gray-400 mt-4 tracking-[0.2em] uppercase">
          Unscramble. Think Fast. Win.
        </p>
      </div>
      <div class="flex items-center justify-center gap-3">
        <div class="w-2 h-2 rounded-full bg-purple-500 animate-pulse"></div>
        <p class="text-xl md:text-2xl text-gray-400 tracking-wider">
          Waiting for the next game...
        </p>
      </div>
    </div>

  {:else if displayState === 'LOBBY'}
    <div class="w-full max-w-4xl text-center space-y-8 animate-fade-in">
      <div>
        <h1 class="text-5xl md:text-7xl font-black tracking-tight text-purple-700">
          WORD RUSH
        </h1>
      </div>

      <div class="flex flex-col items-center gap-6">
        <p class="text-2xl md:text-3xl text-gray-500 tracking-[0.3em] uppercase font-semibold">
          SCAN TO JOIN
        </p>

        <div class="bg-white rounded-3xl flex items-center justify-center p-4 border-2 border-gray-200 shadow-xl" style="width: min(520px, 55vw); height: min(520px, 55vw);">
          {#if qrDataUrl}
            <img src={qrDataUrl} alt="Join QR Code" class="w-full h-full object-contain" />
          {:else}
            <div class="w-10 h-10 border-3 border-gray-200 border-t-purple-500 rounded-full animate-spin"></div>
          {/if}
        </div>

        {#if joinUrl}
          <p class="text-sm md:text-base text-gray-400 font-mono">{joinUrl}</p>
        {/if}

        <div class="space-y-2">
          <div class="text-4xl md:text-6xl font-black text-gray-900">
            <span class="text-purple-600">{playerCount}</span>
            <span class="text-gray-300 text-3xl md:text-5xl"> / {TOTAL_PLAYERS}</span>
          </div>
          <p class="text-xl md:text-2xl text-gray-400 tracking-[0.2em] uppercase">PLAYERS JOINED</p>
        </div>

        <p class="text-lg md:text-xl text-gray-400 tracking-wider animate-pulse mt-4">
          Waiting for players...
        </p>
      </div>
    </div>

  {:else if displayState === 'COUNTDOWN'}
    <div class="text-center animate-fade-in">
      {#key countdownKey}
        <div class="inline-block animate-countdown">
          {#if countdownText === 'GET READY'}
            <span class="text-5xl md:text-7xl font-black text-gray-600 tracking-[0.3em]">
              GET READY
            </span>
          {:else if countdownText === 'GO!'}
            <span class="text-[10rem] md:text-[14rem] font-black text-purple-600 tracking-wider leading-none">
              GO!
            </span>
          {:else}
            <span class="text-[12rem] md:text-[18rem] font-black text-gray-900 leading-none select-none">
              {countdownText}
            </span>
          {/if}
        </div>
      {/key}
    </div>

  {:else if displayState === 'QUESTION'}
    <div class="w-full max-w-5xl text-center space-y-8 animate-fade-in">
      <div class="space-y-2">
        <h1 class="text-4xl md:text-5xl font-black tracking-tight text-gray-900">
          WORD RUSH
        </h1>
      </div>

      <div class="text-lg md:text-xl text-gray-400 tracking-[0.3em] uppercase">
        QUESTION {questionNumber} / {totalQuestions}
      </div>

      <div class="py-8">
        <div class="inline-block px-12 py-6 rounded-3xl bg-gray-50 border border-gray-200 shadow-lg">
          <p class="text-xs md:text-sm text-gray-400 uppercase tracking-[0.4em] mb-4">Unscramble this word</p>
          <div class="text-5xl md:text-7xl font-bold tracking-[0.3em] text-gray-900 select-none leading-tight">
            {jumbledWord}
          </div>
        </div>
      </div>

      <div class="flex items-center justify-center gap-12">
        <div class="text-center">
          <div class="text-4xl md:text-6xl font-mono font-bold {timeRemaining <= 10 ? 'text-red-500' : 'text-gray-900'} {timeRemaining <= 5 ? 'animate-pulse' : ''}">
            {formatTime(timeRemaining)}
          </div>
          <p class="text-xs md:text-sm text-gray-400 mt-2 tracking-[0.2em] uppercase">TIME LEFT</p>
        </div>

        <div class="w-px h-16 bg-gray-200"></div>

        <div class="text-center">
          <div class="text-3xl md:text-5xl font-bold text-purple-600">
            {playerCount}
          </div>
          <p class="text-xs md:text-sm text-gray-400 mt-2 tracking-[0.2em] uppercase">PLAYERS COMPETING</p>
        </div>
      </div>
    </div>

  {:else if displayState === 'QUESTION_RESULT'}
    <div class="w-full max-w-4xl text-center space-y-10 animate-fade-in">
      <h1 class="text-4xl md:text-5xl font-black tracking-tight text-gray-900">
        WORD RUSH
      </h1>

      <div class="space-y-6">
        {#if isTimedOut}
          <div class="text-5xl md:text-7xl font-black text-red-500 tracking-wider animate-pulse">
            TIME'S UP!
          </div>
        {:else if winnerName}
          <div>
            <span class="text-4xl md:text-6xl font-black text-gray-900">{winnerName}</span>
            <span class="text-3xl md:text-5xl font-bold text-purple-600 ml-4">GOT IT FIRST!</span>
          </div>
        {:else}
          <div class="text-4xl md:text-6xl font-black text-gray-400 tracking-wider">
            NO ONE ANSWERED IN TIME
          </div>
        {/if}

        {#if correctAnswer}
          <div class="pt-6">
            <p class="text-lg md:text-xl text-gray-400 uppercase tracking-[0.3em] mb-3">Correct Answer</p>
            <div class="text-5xl md:text-7xl font-black tracking-[0.2em] text-emerald-600">
              {correctAnswer}
            </div>
          </div>
        {/if}
      </div>

      <p class="text-base md:text-lg text-gray-400 tracking-wider animate-pulse mt-8">
        Waiting for host...
      </p>
    </div>

  {:else if displayState === 'LEADERBOARD'}
    <div class="w-full max-w-4xl text-center space-y-8 animate-fade-in">
      <div>
        <h1 class="text-5xl md:text-7xl font-black tracking-tight text-purple-700">
          CURRENT STANDINGS
        </h1>
      </div>

      <div class="space-y-2 mt-6">
        {#each leaderboard as player, i}
          <div class="flex items-center justify-between px-6 md:px-10 py-3 md:py-4 rounded-xl {i === 0 ? 'bg-purple-50 border border-purple-200' : i < 3 ? 'bg-gray-50 border border-gray-100' : 'bg-white border border-gray-100'}">
            <div class="flex items-center gap-4 md:gap-6">
              <span class="text-2xl md:text-3xl font-black {i === 0 ? 'text-purple-600' : i < 3 ? 'text-gray-600' : 'text-gray-400'} w-10 md:w-14 text-right">
                {i + 1}.
              </span>
              <span class="text-xl md:text-2xl font-bold {i === 0 ? 'text-gray-900' : 'text-gray-700'} tracking-wide">
                {player.name}
              </span>
            </div>
            <span class="text-xl md:text-2xl font-bold {i === 0 ? 'text-purple-600' : 'text-gray-500'}">
              {player.score} / {totalQuestions}
            </span>
          </div>
        {/each}

        {#if leaderboard.length === 0}
          <p class="text-xl text-gray-400 py-8">No scores yet</p>
        {/if}
      </div>

      <p class="text-base text-gray-400 tracking-wider animate-pulse mt-6">
        Waiting for host...
      </p>
    </div>

  {:else if displayState === 'FINAL_RESULT'}
    <div class="w-full max-w-4xl text-center space-y-10 animate-fade-in">
      <div>
        <h1 class="text-5xl md:text-7xl font-black tracking-tight text-purple-700">
          WORD RUSH
        </h1>
        <div class="mt-4">
          <span class="text-2xl md:text-3xl font-bold text-purple-600 tracking-[0.2em]">
            CHAMPION
          </span>
        </div>
      </div>

      <div class="py-8">
        {#if champions.length > 0}
          <div class="space-y-3">
            <div class="inline-block px-12 py-8 rounded-3xl bg-purple-50 border-2 border-purple-200 shadow-xl">
              <p class="text-lg text-purple-500 uppercase tracking-[0.3em] mb-2">Champion</p>
              <div class="text-6xl md:text-8xl font-black text-gray-900 tracking-wide">
                {champions[0].name}
              </div>
              <div class="text-3xl md:text-4xl font-bold text-purple-600 mt-3">
                {champions[0].score} / {totalQuestions}
              </div>
            </div>
          </div>
        {:else}
          <p class="text-3xl text-gray-400">No champion determined</p>
        {/if}
      </div>

      {#if champions.length > 1}
        <div class="grid grid-cols-2 gap-6 mt-8">
          {#each champions.slice(1) as champ, i}
            <div class="px-8 py-6 rounded-2xl bg-gray-50 border border-gray-200">
              <p class="text-sm text-gray-400 uppercase tracking-[0.3em] mb-2">
                {i === 0 ? 'Runner-up' : '2nd Runner-up'}
              </p>
              <p class="text-3xl md:text-4xl font-bold text-gray-900">{champ.name}</p>
              <p class="text-xl text-gray-400 mt-1">{champ.score} / {totalQuestions}</p>
            </div>
          {/each}
        </div>
      {/if}

      <div class="mt-10 pt-6 border-t border-gray-100">
        <p class="text-3xl md:text-4xl font-black text-gray-300 tracking-[0.3em]">
          CONGRATULATIONS!
        </p>
      </div>
    </div>

  {:else if displayState === 'EVENT_CHAMPIONS'}
    <div class="w-full max-w-5xl text-center space-y-10 animate-fade-in">
      <div>
        <h1 class="text-5xl md:text-7xl font-black tracking-tight text-purple-700">
          WORD RUSH
        </h1>
        <div class="mt-4">
          <span class="text-2xl md:text-3xl font-bold text-purple-600 tracking-[0.2em]">
            FRESHERS DAY CHAMPIONS
          </span>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mt-8">
        {#each champions as champ, i}
          <div class="px-8 py-8 rounded-3xl {i === 0 ? 'bg-purple-50 border-2 border-purple-200 shadow-xl' : 'bg-gray-50 border border-gray-200'}">
            <p class="text-sm text-gray-400 uppercase tracking-[0.3em] mb-4">
              CHAMPION
            </p>
            <div class="text-4xl md:text-5xl font-black text-gray-900 tracking-wide leading-tight">
              {champ.name}
            </div>
            <div class="text-xl text-gray-500 mt-3">
              Score: {champ.score} / {totalQuestions}
            </div>
          </div>
        {/each}

        {#if champions.length === 0}
          <p class="text-xl text-gray-400 col-span-3 py-8">No champions yet</p>
        {/if}
      </div>

      <div class="mt-10 pt-6 border-t border-gray-100">
        <p class="text-3xl md:text-4xl font-black text-gray-300 tracking-[0.3em]">
          CONGRATULATIONS!
        </p>
      </div>
    </div>
  {/if}
</div>
