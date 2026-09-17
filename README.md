# WORD RUSH

**Unscramble. Think Fast. Win.**

A real-time multiplayer word game for college Freshers Day events. Players compete to unscramble jumbled words faster than their peers across three independent game sessions.

---

## Game Rules

- A jumbled word is displayed to all players simultaneously
- Players type the correct unscrambled word
- The **first correct answer** wins 1 point
- The question immediately locks for all other players
- Each game has 20 questions (max score: 20/20)
- Each player gets **2 hints per game** (no point penalty)
- Player scores are **private** (not visible to other players)
- Leaderboard is **host-controlled** (hidden by default on projector)

## Event Structure

| Game | Players | Questions | Champion |
|------|---------|-----------|----------|
| Game 1 | 20 new | 20 unique | Game 1 Champion |
| Game 2 | 20 new | 20 unique | Game 2 Champion |
| Game 3 | 20 new | 20 unique | Game 3 Champion |

**Total: 60 participants, 60 unique questions, 3 separate champions**

---

## Technology Stack

- **Frontend:** SvelteKit 2 + Svelte 5 (Runes)
- **Styling:** Tailwind CSS v4
- **Database:** Supabase PostgreSQL
- **Realtime:** Supabase Realtime
- **Icons:** Lucide Svelte
- **QR Code:** qrcode.js

---

## Architecture

```
Player Device (/)          Host Laptop (/host)       Projector (/display)
     |                           |                          |
     +-------> Supabase <--------+--------------------------+
                 |
         PostgreSQL + Realtime
```

- **Player interface** (`/`): Mobile-first, registration, lobby, game, results
- **Host dashboard** (`/host`): Password-protected admin panel with full control
- **Projector display** (`/display`): Read-only auto-following display

---

## Routes

| Route | Description | Access |
|-------|-------------|--------|
| `/` | Player interface | Public |
| `/host` | Host control center | Auth required |
| `/display` | Projector display | Public read-only |

---

## Database Schema

### Tables

| Table | Purpose |
|-------|---------|
| `games` | Game state (3 games) |
| `players` | Player registration & scores |
| `questions` | 65 questions (60 main + 5 tiebreaker) |
| `question_results` | Per-question winners |
| `device_participation` | Device tracking (prevent rejoin) |
| `event_settings` | Event configuration |

### RPC Functions

| Function | Purpose |
|----------|---------|
| `join_active_game()` | Atomic player registration with 20-player lock |
| `submit_answer()` | Atomic first-correct-answer with question locking |
| `request_hint()` | Secure hint delivery with 2-hint enforcement |
| `lock_expired_question()` | Timeout handling |
| `get_private_leaderboard()` | Host-only ranked scores |
| `reset_game()` | Full game reset |

### Security (RLS)

- Players can only read their own data and basic game state
- Correct answers never sent to browser before question ends
- Leaderboard data restricted to host routes
- All critical operations use database-level atomic functions

---

## Installation

### Prerequisites

- Node.js 18+
- npm
- Supabase project (free tier works)

### 1. Clone and install

```bash
cd word-rush
npm install
```

### 2. Set up Supabase

1. Create a project at [supabase.com](https://supabase.com)
2. Go to SQL Editor
3. Run the migration file:

```sql
-- Copy and paste contents of:
-- supabase/migrations/001_initial.sql
```

This creates all tables, RLS policies, functions, and seeds 65 questions.

### 3. Configure environment

Create `.env`:

```env
PUBLIC_SUPABASE_URL=https://your-project.supabase.co
PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
PUBLIC_APP_URL=https://your-deployed-url.com
```

Find keys in: Supabase Dashboard → Settings → API

### 4. Create Host Account

Host accounts require TWO steps:

**Step A:** Create the Auth user in Supabase Dashboard → Authentication → Users:
1. Click "Add user"
2. Enter a real email address you control and a secure password
3. Confirm the email (or disable email confirmation in Auth settings)

**Step B:** After creating the Auth user, copy its UUID. Then run this SQL in the SQL Editor:

```sql
insert into public.hosts (id, email)
values (
  '<AUTH_USER_UUID>',
  '<HOST_EMAIL>'
);
```

Replace `<AUTH_USER_UUID>` with the UUID from Step A and `<HOST_EMAIL>` with the email used in Step A.

### 5. Start development

```bash
npm run dev
```

Open:
- Player: `http://localhost:5173`
- Host: `http://localhost:5173/host`
- Display: `http://localhost:5173/display`

---

## How the Permanent QR Works

**ONE QR code** is used for the entire event. It always points to:

```
PUBLIC_APP_URL/
```

The system automatically routes players:
- If Game 1 lobby is open → joins Game 1
- If Game 2 lobby is open → joins Game 2
- If Game 3 lobby is open → joins Game 3
- If game in progress → "Please wait for next game"
- If game full → "Game Full"
- If all done → "Event Completed"

---

## Host Workflow

### Game 1

1. Login at `/host`
2. Click **Game 1** card
3. Click **OPEN LOBBY**
4. Display `/display` on projector - shows QR code
5. Students scan QR → register → enter lobby
6. Player count updates in real-time (X/20)
7. Click **CLOSE LOBBY** (or auto-close at 20)
8. Click **START GAME**
9. Countdown: 3... 2... 1... GO!
10. Question 1 appears on all devices
11. Monitor private leaderboard
12. Use **SHOW LEADERBOARD** / **HIDE LEADERBOARD** to control projector
13. After Q20, click **SHOW FINAL RESULT**
14. Game 1 Champion displayed

### Game 2

15. Click **OPEN GAME 2 LOBBY**
16. Same QR code works - new students join
17. Repeat steps 6-14

### Game 3

18. Click **OPEN GAME 3 LOBBY**
19. Repeat for final 20 students
20. Click **SHOW EVENT CHAMPIONS** for final celebration

---

## Projector Display

Open `/display` once. It auto-follows event state:

- **Lobby:** QR code + player count
- **Countdown:** Large animated 3-2-1
- **Question:** Jumbled word + timer
- **Result:** Winner name + correct answer
- **Leaderboard:** Only when host enables it
- **Final:** Champion reveal
- **Event Champions:** All 3 champions

No manual refresh needed.

---

## Host Controls

| Control | When Available | Action |
|---------|---------------|--------|
| OPEN LOBBY | NOT_STARTED | Opens player registration |
| CLOSE LOBBY | LOBBY_OPEN | Stops new joins |
| START GAME | LOBBY_CLOSED | Countdown + Q1 |
| PAUSE GAME | PLAYING | Freezes timer |
| RESUME GAME | PAUSED | Resumes |
| SKIP QUESTION | PLAYING | No winner, advance |
| NEXT QUESTION | QUESTION_LOCKED | Load next question |
| SHOW LEADERBOARD | Anytime | Projector shows scores |
| HIDE LEADERBOARD | Anytime | Projector returns to game |
| SHOW FINAL RESULT | Game complete | Champion display |
| RESET GAME | Anytime | Full reset (with confirm) |
| REMOVE PLAYER | LOBBY_OPEN | Free up slot |

---

## Deployment

### Vercel (Recommended)

```bash
npm i -g vercel
vercel --prod
```

Set environment variables in Vercel dashboard.

### Netlify

```bash
npm run build
# Deploy build/ directory
```

### Other Platforms

The app uses `@sveltejs/adapter-auto`. Install the appropriate adapter:

```bash
npm install @sveltejs/adapter-node  # For Node.js servers
# or
npm install @sveltejs/adapter-static  # For static hosting
```

---

## Testing Multiple Phones

1. Start dev server: `npm run dev`
2. Find your local IP: `ipconfig` (Windows) / `ifconfig` (Mac/Linux)
3. Open `http://YOUR-IP:5173` on multiple phones
4. Test registration, lobby, gameplay
5. Verify 20-player limit enforcement
6. Test simultaneous answer submission

---

## Event-Day Checklist

### Setup (1 hour before)

- [ ] Verify production URL is accessible
- [ ] Verify Supabase connection (run a test query)
- [ ] Login to host panel
- [ ] Verify all 3 games show NOT_STARTED
- [ ] Test permanent QR with 2-3 phones
- [ ] Verify projector displays correctly
- [ ] Check internet connectivity
- [ ] Connect host laptop to charger
- [ ] Keep backup hotspot ready

### Pre-Game 1

- [ ] Open Game 1 Lobby
- [ ] Show QR on projector
- [ ] Verify player count updates
- [ ] Test with 2-3 students first
- [ ] Close lobby when ready

### During Game 1

- [ ] Verify countdown works
- [ ] Verify questions appear on all devices
- [ ] Test hint system
- [ ] Verify first-answer locking
- [ ] Check private leaderboard
- [ ] Test SHOW/HIDE leaderboard on projector

### Between Games

- [ ] Show Game 1 Champion
- [ ] Open Game 2 Lobby
- [ ] Verify new students can join (same QR)
- [ ] Verify Game 1 players can't rejoin

### After All Games

- [ ] Show Event Champions
- [ ] Verify all 3 champions calculated
- [ ] Optional: Export results from Supabase

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Players can't join | Check if lobby is open (host panel) |
| Duplicate players | Clear localStorage, refresh |
| Timer desync | Check Supabase connection |
| Projector not updating | Refresh `/display` page |
| Host can't login | Verify Supabase Auth user exists |
| 21st player joins | Check `submit_answer` RPC is deployed |
| Hints not working | Verify `request_hint` RPC is deployed |
| Build fails | Run `npm install`, check env vars |

---

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `PUBLIC_SUPABASE_URL` | Yes | Supabase project URL |
| `PUBLIC_SUPABASE_ANON_KEY` | Yes | Supabase anonymous key |
| `SUPABASE_SERVICE_ROLE_KEY` | Yes | Server-side only (never exposed to browser) |
| `PUBLIC_APP_URL` | Yes | Public URL for QR code generation |

---

## Question Bank

- **60 main questions** (20 per game)
- **5 tiebreaker questions**
- Categories: College, Technology, Food, Entertainment, Sports, General
- Difficulty: Easy (Q1-5), Easy/Medium (Q6-10), Medium (Q11-15), Hard (Q16-20)
- All questions validated: jumbled letters match correct word exactly

---

## Security Features

- Correct answers never sent to browser during active questions
- Player scores hidden from player interface
- Leaderboard hidden from projector by default
- Database-level atomic operations prevent race conditions
- Advisory locks prevent concurrent player limit violations
- Device session tracking prevents accidental multi-game joining
- Host authentication via Supabase Auth

---

## License

Built for college Freshers Day events. Free to use and modify.
