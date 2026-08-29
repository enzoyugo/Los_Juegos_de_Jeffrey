# Hotseat Racing — Mode Contract V1

**Status:** product contract. **Runtime overlay (overnight greybox):** `HOTSEAT_RACING_GREYBOX_V1` exists at `res://scenes/track/TrackMain.tscn`. See `docs/JEFFREY_OVERNIGHT_UI_TRACK_ZOMBIES_REPORT.md`.

**Conflict recorded:** this file originally said “documentation only / no car physics.” That is stale. The shell now hosts a playable greybox. This contract remains the product source of truth for fuel/Last Dance/hotseat rules. Greybox implementation is incomplete vs the full contract (no authored art, no 10-player playtest, no cockpit cosmetics).

Registry: id `racing`, display_name `Hotseat`, enabled `false`, availability `development`, min 2, max 10.

Greybox scene: `res://scenes/track/TrackMain.tscn`  
Fallback placeholder (kept on disk): `res://scenes/modes/racing/HotseatComingSoon.tscn`

---

## Core concept

Local hotseat. One person drives at a time. Up to **10** players.

Everyone uses:

- the same car
- the same physics
- the same stats
- the same track
- the same seed

The selected character is **cosmetic only** (head / head+torso visible in the cockpit). Characters never change performance.

---

## Track lengths

Length is independent of difficulty.

| Category | Target lap | Acceptable | Target full match |
| --- | --- | --- | --- |
| Corta | ~10s | 8–12s | 10–20 min |
| Media | ~20s | 17–23s | 15–25 min |
| Larga | ~35s | 30–40s | 20–30 min |

---

## Difficulty

Enum (not implemented):

```text
TRANQUI
PICANTE
DEMENTE
```

Difficulty affects piece weighting / eligibility, not a second length axis.

Future piece metadata:

```text
piece_type
estimated_time
difficulty
entry_speed_min
exit_speed_expected
entry_transform
exit_transform
height_delta
hazard_score
tags
```

---

## Procedural track

Generator output:

```text
seed
length_category
difficulty
piece_sequence
estimated_time
validation_result
```

Pipeline:

```text
GENERATE → VALIDATE → ESTIMATE TIME → PASS → VISIBLE BUILD ANIMATION
```

Never show an invalid track. The player-facing clack-clack build happens **after** internal validation.

Visible build:

```text
START  CLACK  PIECE  CLACK  PIECE  …  FINISH
CAMERA FLYOVER
[ JUGAR ]  [ OTRA ]
```

`OTRA` rolls a new seed.

---

## V1 pieces (objectives, not assets)

START, STRAIGHTS, CURVES, CHICANES, JUMPS, RAMPS, DROPS, BOOST, TUNNELS, WALLRIDES, NARROW PLATFORMS, LIMITED MOVING OBSTACLES, FINISH.

No loops in V1.

---

## Fuel

Fuel is **remaining hotseat play budget**, not gasoline.

- Shown as fuel
- Consumes only while that player is on their turn
- Does not refill
- Initial amount from `expected_track_time`, `player_count`, `target_match_duration`, tuning multipliers
- Numbers are for playtest calibration — do not hardcode finals in architecture

---

## LAST DANCE (canonical)

When `fuel <= 0` and the player must run, show **LAST DANCE**.

That player gets **one** definitive run.

During Last Dance:

- can drive normally
- can reset to last checkpoint
- time continues
- gains **no** fuel

If they use **RESTART FROM START**: that is **RENDICIÓN** — eliminated.

If they finish the attempt but do not beat any player they need to beat: **ELIMINADO**.

If they overtake a needed player: **SOBREVIVE**, still at fuel `0`.

If they later become last again: they get **another LAST DANCE**. Consecutive clutches are allowed.

**Never** gift fuel for surviving Last Dance.

---

## Restart contract

Normal racing:

### Restart checkpoint

- position resets
- timer continues
- fuel continues

### Restart track (from start)

- position to START
- run timer to 0
- fuel does **not** reset (reserve)

During Last Dance, restart-from-start is surrender (above).

---

## Ghosts

Show ghosts for **all living** players, not only a record/target ghost.

Ghosts: no collision, visually identified, racing lines readable. Removed from the active ghost set on elimination.

---

## Close finish hooks

Detect margins between finishing positions. Future events:

| Event | Reference threshold |
| --- | --- |
| CLOSE_FINISH | ≤ 0.100s |
| INSANE_FINISH | ≤ 0.050s |
| PHOTO_FINISH | ≤ 0.010s |

No visual polish in this sprint.

---

## Camera

V1: third-person chase, Trackmania Turbo reading: speed, track, car visible, horizon readable. No camera selector yet.

---

## Car

One car design. Same acceleration, speed, grip, mass, handling for every character.

Visual damage (loose bumper, missing part, bent hood) is allowed later.

**No** physics penalty, **no** speed penalty beyond the collision itself, **no** handling penalty from visual damage. Stats never change from damage.

---

## Session results (future screen)

winner, ranking, best times, eliminations, last dances, margins.

---

## Next sprint (not this one)

HOTSEAT RACING GREYBOX V1 — greybox track + one car + hotseat loop. Do not start until this foundation is accepted.
