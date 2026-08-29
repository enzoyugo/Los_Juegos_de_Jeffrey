# Smash Kapes — Post-Migration Regression

**Date:** 2026-08-25  
**Compared to:** `docs/SMASH_PRE_MIGRATION_BEHAVIOR_BASELINE.md`

---

## Verdict

Smash gameplay authorities were **not rewritten**. Headless and static checks match the baseline. A human 2P keyboard pass of the baseline checklist is still recommended on the Windows machine.

---

## Automated

| Check | Result |
| --- | --- |
| `pytest tests/test_m0_combat.py tests/test_jeffrey_multimode_shell.py tests/test_jeffrey_shell_v2.py` | **78 passed** |
| Movement / jump / stocks / attack tres numbers | unchanged |
| Input map `p1_*` / `p2_*` / R / Esc | unchanged |
| `fighter.gd` / `m0_playground.gd` do not reference JeffreyCore | pass |
| Spawn constants `(-4, 1.7, 0)` / `(4, 1.7, 0)` | pass |
| Blast zone ±19 / y -10..18 | pass |
| Respawn delay 1.15, i-frames 1.5, stocks 3 | pass |
| Godot `ValidateJeffreyShell.tscn` | **OK** — 2 fighters, stocks 3, default terere/jaguarete, spawn_position baseline |
| `SSK_AUTO_START_BATTLE=1` from new main scene | fighters spawned, match active, first physics tick |

Godot command used:

```text
Godot 4.7.2 --headless --rendering-method gl_compatibility --audio-driver Dummy
SSK_DISABLE_STAGE_VISUALS=1  SSK_DISABLE_HUD=1
```

---

## Shell → Smash adapter

New boot `JeffreyBoot.tscn` hosts existing `Main.tscn` with `hosted_by_shell = true`.

`Main` still instantiates `M0Playground.tscn` the same way (`_enter_match`). Character select art/flow is preserved; hosted shell can pass profile display names so status shows Enzo/Jeffrey instead of P1/P2. MatchSetup profile ids remain stats-only.

---

## Human 2P keyboard smoke

**Status: `HUMAN_VALIDATION_REQUIRED`**

This environment cannot inject real P1/P2 keyboard gameplay against a visible window. Do **not** treat headless spawn/physics as a feel pass.

Run `docs/SMASH_PRE_MIGRATION_BEHAVIOR_BASELINE.md` on Windows fullscreen:

### P1
move · jump · double jump · attack · attack while moving · KO · respawn

### P2
same on arrows + N

### Match
damage % · hitstun · knockback · stocks · HUD · blast zones · R restart · i-frames · results / rematch / menú → game select

Host note: pause during battle previously no-op’d because `_toggle_pause` required `screen_root` (cleared in match). V2 host fix: pause if `active_match != null`. Overlay still lives on `Main.ui`. Gameplay numbers were not changed.

---

## Not regressions (intentional shell changes)

- Window title / project name: Los Juegos de Jeffrey
- Main scene is JeffreyBoot, not Main
- After a hosted match, MENÚ goes to game selection
- Profiles exist and may record smash_stats after a hosted match
