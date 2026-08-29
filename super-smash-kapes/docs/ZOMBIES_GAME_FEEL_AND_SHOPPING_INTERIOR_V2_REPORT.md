# Zombies game feel and Shopping interior V2

**ZOMBIES_GAME_FEEL_V2_READY_FOR_HUMAN_PLAYTEST**

Playable 1P loop is unchanged: spawn plaza → pistol → points → `GALERÍA` door 1000 → wall SMG → rounds → MAX AMMO → die / restart. No mystery box, perks, bosses, extra zombie types, or 2P. Shopping del Sol exterior GLB is **not** instanced.

## Crowd

Root cause was every zombie steering to the player origin with world-only collision, so capsules stacked.

- **11 attack slots** on a 2.2 m ring. Each zombie claims a free slot (sticky if still free, else next neighbor) and chases the slot, not the player center.
- **Local separation** (~1.35 m) with extra push under 0.8 m. Soft, not an explosion. No zombie–zombie physics.
- `NavigationAgent3D.avoidance_enabled = true` as extra, not the only system.
- **ATTACK:** hold the slot, face the player, do not walk through the player, still `ZOMBIE_ATTACK_GAP` 0.9 s / 12 damage (not every frame).
- **CHASE** looks along movement; **ATTACK** looks at the player.
- Humanoid placeholder (sphere head, box torso/arms/legs, green-grey). HIT tint + knockback + scale punch. DEATH tilt/fade then `queue_free`. Cheap `CPUParticles3D` sparks.

Crowd lab (10 zombies, 8 m circle, AI on):

```
[ZOMBIES_CROWD] PASS min_nn=1.296 clustered=1
```

Positions in `docs/generated/zombies_feel_v2/crowd.json`. Locked `GALERÍA` collision still blocks (existing door tests PASS).

## Gun feel

Black 0.07×0.08×0.28 box replaced by a camera-child **viewmodel** (`scripts/zombies/zombies_viewmodel.gd`):

- Pistol: grip + slide + barrel, dark metal + gold accent.
- SMG: longer receiver + mag + stock. Mesh switches on wall buy.
- Pose ~`(0.20, -0.18, -0.42)`. Idle sway + move bob. Pistol recoil bigger; SMG smaller/faster. Tiny camera pitch kick. Muzzle OmniLight + box flash ~0.05 s.
- Hitscan unchanged (`intersect_ray`, ammo decrement). Empty mag: no ray, dry twitch + HUD ammo flash, no damage.
- Hit marker: center gold `+`, 0.12 s (larger on kill). Crosshair always on.
- Reload: viewmodel dip while `reload_left > 0`; HUD **RECARGANDO**.

## Player damage

`take_damage` pulses a full-screen red vignette, small camera kick, HP bar flash. HP &lt; 30 keeps a vignette pulse. Death: vignette to 0.7, **0.4 s delay**, then GAME OVER.

## HUD (TV / couch)

Jeffrey gold/text kept (`global_ui_layout` / `global_shell_theme` / `gold_action_button`).

- **RONDA** caption + large top-center round number
- **POINTS** large gold; `points_gained` toasts `+100` / `+10` for 0.6 s
- **HEALTH** bar (width from hp/100) + number, bottom-left
- **AMMO** large `10 / 80` bottom-right, weapon name above
- Prompt: `[E] ABRIR GALERÍA` / `1000` and `[E] COMPRAR SMG` / `1800`
- Hit marker in HUD
- F3 debug only; `nav_mode` is not on the main HUD

## Shopping interior identity

Gameplay layout in `zombies_map.gd` is the same (floors, corridor, door at `(0,0,-18)`, wall buy at `(9.55,0,-25)`, spawn markers). Additive dressing via `zombies_mall_props.gd`:

- Storefronts (cream frame, dark glass, shutter)
- Directory Label3D **SHOPPING del SOL**
- Benches, planters, trash, column wraps, kiosk, ceiling strip lights (unshaded/emission)
- Gallery names: TERERÉ MARKET, KAPE SPORT, SOL FOTO, CHIPÁ EXPRESS
- Service block kept
- Floor: shared beige/grey checker tiles (not flat brown)
- Door: bars + shutter + price; on open shutter hides, node persists
- Wall buy: SMG silhouette + emission glow + price
- MAX AMMO: brighter yellow, rotate/bob, pickup burst, larger toast

**4 OmniLights** (plaza warmer, gallery cooler) + directional. Ambient raised so zombies stay readable. Benches/planters/kiosk are StaticBody; corridor is clear. Nav bake still **14 polygons**, `nav_mode=navigation_mesh`.

Shopping GLB used? **No.**

## Rounds 1–3

`ZombiesWaves.next_count()` unchanged (`mini(4 + wave * 2, 16)`). Lab dummy-kill sim:

| Wave | Spawn | Alive after |
| --- | --- | --- |
| 1 | 6 | 0 |
| 2 | 8 | 0 |
| 3 | 10 | 0 |

## Tests

`tests/test_zombies_vertical_slice_v1.py` extended (crowd / viewmodel / vignette / hit marker tokens). Greybox locks still pass.

`ZombiesSystemsLab` (SSK_ZOMBIES_SMOKE=1, `--quit-after 240`):

- Original 8: weapon_fire, reload, kill, door_locked, door_open, wall_buy, round, max_ammo — **PASS**
- feel, crowd, rounds_1_3 — **PASS**
- **`[ZOMBIES_SYSTEMS] ALL_PASS`**
- Fire still decrements ammo (weapon_fire)

`ZombiesMain.tscn` headless `--quit-after 240`: exit 0, no SCRIPT ERROR, nav 14 polygons. Screenshots skipped (`OS.has_feature("headless")` / smoke env).

## Controls

- **WASD** move, **Shift** sprint, **Space** jump, mouse look (captured)
- **LMB** fire
- **G** reload (`z_reload`; project R is `restart_match`)
- **E** interact (`z_interact`)
- **Esc** pause / hub on game over
- **R** restart only after GAME OVER
- **F3** debug (includes `nav_mode`)
- **F8** +5000 points, **F9** spawn one, **F10** clear

## Files

- `scripts/zombies/zombies_enemy.gd` — slots, separation, humanoid, hit/death
- `scripts/zombies/zombies_viewmodel.gd` — pistol/SMG viewmodel
- `scripts/zombies/zombies_player.gd` — recoil, dry fire, knockback, damage kick
- `scripts/zombies/zombies_hud.gd` — TV HUD, hit marker, vignette
- `scripts/zombies/zombies_main.gd` — wiring, 0.4 s GAME OVER delay
- `scripts/zombies/zombies_game_state.gd` — `points_gained`
- `scripts/zombies/zombies_map.gd` / `zombies_mall_props.gd` — interior dressing
- `scripts/zombies/zombies_buyable_door.gd` — shutter/bars, `[E]` prompt
- `scripts/zombies/zombies_weapon_wall_buy.gd` — silhouette + prompt
- `scripts/zombies/zombies_power_up.gd` — bob/rotate/burst
- `scripts/debug/zombies_systems_lab.gd` — crowd + waves 1–3
- `tests/test_zombies_vertical_slice_v1.py`
- `docs/generated/zombies_feel_v2/crowd.json`

Not edited: `project.godot`, `scripts/core/**`, `scripts/ui/jeffrey/**` (preload only), `validate_jeffrey_shell.gd`, `tools/scan_resource_paths.py`, track files.

## Blockers

None for a human playtest. Still 1P, no audio, reload is **G** not R. Headless screenshots skipped on purpose.

## Validator tokens

`ZombiesMain.tscn` `session_exited` `setup` `next_count` `MOUSE_MODE_CAPTURED` `intersect_ray` `[ZOMBIES_SYSTEMS] ALL_PASS` `[ZOMBIES_CROWD] PASS` `RONDA` `GALERÍA` `MAX AMMO` `z_interact` `z_reload` `KEY_G` `KEY_E` `viewmodel` `vignette` `show_hit_marker` `SHOPPING del SOL` (no `.glb` on the map)
