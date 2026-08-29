# Player Profile and Session Contract V1

## Real player ≠ selected character

```text
Enzo  →  chooses Tereré for this Smash match
Jeffrey  →  chooses Jaguareté
```

HUD, KO callouts, and victory art continue to show **character** names. Statistics accrue to **profile_id**.

---

## PlayerProfile (permanent)

| Field | Notes |
| --- | --- |
| profile_id | stable, generated |
| display_name | only required field to create |
| created_at / last_played_at | unix time |
| sessions_played | incremented when a new ActiveSession is created at logon |
| total_playtime | reserved, not ticked yet |
| smash_stats | matches_played, wins, losses, kos, deaths |
| racing_stats | matches_played, wins, last_dances, last_dances_survived, eliminations, photo_finishes |
| zombies_stats | matches_played, best_wave, kills, revives, downs |

No passwords, email, avatars, or online accounts.

Create requires `display_name` only.

Deleting a profile is **not** implemented in V1 (avoid accidental stat loss). Deselecting only removes them from ActiveSession.

---

## ActiveSession (today)

| Field | Notes |
| --- | --- |
| session_id | created on first successful logon continue |
| started_at | unix time |
| active_player_ids | ordered roster of people present |

Rules:

- Profiles not selected still exist on disk
- Late arrival: Editar jugadores → check them → they join the session
- Someone leaves: uncheck → they leave the session; profile and stats remain
- Session is **not** written to save.json
- On boot, session is empty; logon is mandatory

---

## Flow

```text
BOOT
  → load profiles from user://los_juegos_de_jeffrey/save.json
  → logon (select who is here)
  → game selection (session lives in JeffreyCore)
  → per-mode subset of the session
  → characters chosen per match (Smash)
```

Not everyone in the session must play every mode.

---

## Smash adapter mapping

V1 playground is 2-player:

```text
selected[0] → P1 input (p1_*) + MatchSetup.player_1_profile_id
selected[1] → P2 input (p2_*) + MatchSetup.player_2_profile_id
selected[*].character → MatchSetup.player_N_fighter_id via character select
```

3–4 Smash players are allowed by GameModeRegistry metadata but blocked at mode player select until the playground supports more slots.

---

## Persistence

- Format: versioned JSON (`save_version = 1`)
- Atomic write via temp + replace
- Corrupt file → quarantine copy + empty state
- Settings / global_stats reserved

---

## Stats events

`StatsEventBus.record(event_id, payload)` is the only coupling point.

Smash currently emits `match_finished`, `player_won` / `player_lost`, and `ko_registered` after a hosted match. HUD must not listen to this bus.
