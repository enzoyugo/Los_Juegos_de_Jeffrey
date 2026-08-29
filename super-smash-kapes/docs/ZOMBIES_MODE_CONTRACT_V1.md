# Zombies — Mode Contract V1

**Status:** documentation only. No FPS controller, guns, waves, map, split-screen, or economy in this sprint.

Registry: id `zombies`, display_name `Zombies`, enabled `false`, min 1, max 2.

Placeholder: `res://scenes/modes/zombies/ZombiesComingSoon.tscn`

---

## Basics

- 1–2 players
- local only
- split-screen when 2P
- first person
- up to **50** waves
- reaching round 50 must be extremely hard
- **no** endless mode in V1

---

## Player representation

FPS for the local view:

- arms / hands
- gun
- HUD portrait
- special power cues
- character-specific voice

The teammate sees:

- full character
- animations
- weapon
- downed state
- revive
- abilities

This is intentional comedy: you can forget which kape you picked and then see your friend as an absurd giant coming to revive you.

---

## Economy (future)

- points/currency from kills
- weapon buys
- locked doors / buy access
- limited ammo
- reload

Not implemented.

---

## Down / revive

2P:

1. Losing the life state → **DOWNED**
2. Teammate can revive
3. If revive fails → **DEAD FOR CURRENT WAVE**
4. Player returns on **NEXT WAVE**
5. Not eliminated from the whole match

1P: down/revive rules TBD when the mode is built; do not silently copy 2P.

---

## Friendly fire

**OFF** by default.

---

## Powerups

Will exist. Do **not** clone the COD Zombies set. Design original powerups later. Architecture should be data-driven.

---

## Characters

Unlike Racing, zombies characters may have:

- unique zombie traits
- unique special powers

Smash already has per-fighter presentation/visuals; combat stats today are shared `FighterStats` defaults (unchanged). Zombies may diverge later via `zombies_resource` on `CharacterRegistry`.

---

## First map

**SHOPPING DEL SOL** — fictional / caricature / zombified. Do not build it in this sprint.

---

## Session results (future screen)

wave reached, kills, downs, revives.

---

## Shared identity

Stats belong to `PlayerProfile`, not to the zombie character name.
