# Zombies vertical slice V1

**ZOMBIES_VERTICAL_SLICE_V1_READY_FOR_HUMAN_PLAYTEST**

Playable 1P greybox for **Los Juegos de Jeffrey**. Hub still hosts `res://scenes/zombies/ZombiesMain.tscn`. Mode stays development/disabled in the registry.

Shopping del Sol exterior GLB is **not** used (169 m exterior, no interior, D3D12 risk). Palette is terracotta `#c47a5a`, cream `#e8dcc8`, dark floor, plus a `SHOPPING del SOL` Label3D in the plaza.

## Map

Code-built in `scripts/zombies/zombies_map.gd`:

1. **Spawn plaza** — player spawn, starter pistol, kiosk + columns for cover, 3 spawn markers behind the kiosk/columns.
2. **Corridor** — cream portal/arch into the gallery.
3. **Buyable door** — `GALERÍA`, 1000 points. StaticBody blocks player and zombies until purchased. Stays open for the match.
4. **Galería** — wall-buy SMG, extra spawn markers, small service block.

Invisible/physical walls, floor, ceiling. Outer bounds are the room walls.

## Navigation

`NavigationRegion3D` bakes a `NavigationMesh` from floor static colliders in `_ready` (`bake_navigation_mesh(false)`). Headless load produced **14 polygons**, `nav_mode=navigation_mesh`. If polygon count is 0, zombies **fallback** to `CharacterBody3D.move_and_slide` toward the player. Locked door collision still blocks that fallback. On door open the mesh rebakes and gallery spawn points unlock.

F3 overlay shows `nav_mode`.

## Systems

| Piece | Behavior |
| --- | --- |
| Pistol | Semi, mag 10, reserve 80, 35 dmg, 4 rps |
| Wall SMG | Auto, mag 30, reserve 90, 22 dmg, 10 rps, 1800 / ammo 750 |
| Zombie | 80 HP r1, ×1.12 per round, speed 3.4, 12 dmg / 0.9 s |
| Rounds | `ZombiesWaves.next_count()` — r1 returns ≥1 and `wave == 1`. Interval 0.65 s, cap 10 alive, 3 s between rounds, HUD `RONDA N` |
| Points | 10 on hit, 100 on kill. Start 0 |
| MAX AMMO | ~10% drop, refills mag + reserve, toast 2.5 s |
| Game over | Freeze combat, mouse visible, R or REINICIAR. Esc/HUB emits `session_exited` |

## Controls

- **WASD** move, **Shift** sprint, **Space** jump, mouse look (captured)
- **LMB** fire
- **G** reload (`z_reload`; project R is `restart_match`)
- **E** interact (`z_interact`)
- **Esc** pause / hub on game over
- **R** restart only after GAME OVER
- **F3** debug overlay
- **F8** +5000 points
- **F9** spawn one zombie
- **F10** kill remaining / short-circuit round delay

## Tests

- `tests/test_zombies_greybox_v1.py` — scene path, capture, hitscan, `session_exited`, no infinite ammo string
- `tests/test_zombies_vertical_slice_v1.py` — door, wall buy, max ammo, round API, systems lab files
- `scenes/debug/ZombiesSystemsLab.tscn` — 8 API checks, prints `[ZOMBIES_SYSTEMS] PASS|FAIL` and `ALL_PASS`, quit 0/1. `SSK_ZOMBIES_SMOKE=1` is the same path.

Headless lab:

```
$env:SSK_ZOMBIES_SMOKE="1"; E:\Godot_v4.7.2-stable_win64_console.exe --path e:\SuperSmashKapes\super-smash-kapes --headless --display-driver headless --rendering-driver d3d12 --rendering-method forward_plus --audio-driver Dummy --quit-after 1200 res://scenes/debug/ZombiesSystemsLab.tscn
```

## Human playtest

1. F6 `ZombiesMain.tscn`.
2. Spawn plaza, pistol equipped, shoot approaching zombies, watch points.
3. Survive round 1; banner `RONDA 2`.
4. F8 if needed, **E** on `GALERÍA` (1000), enter room 2, buy SMG.
5. Kill until a **MAX AMMO** drop; walk over it.
6. Die, read GAME OVER, **R** restart.

## Known issues

- 1P only. No perks, mystery box, bosses, or weapon swap key (wall buy equips SMG).
- Nav bake may fall back to direct chase in headless; door physics still blocks.
- Reload is **G**, not R.
- No audio.

## Validator tokens

`ZombiesMain.tscn` `session_exited` `next_count` `MOUSE_MODE_CAPTURED` `intersect_ray` `[ZOMBIES_SYSTEMS] ALL_PASS` `RONDA` `GALERÍA` `MAX AMMO` `z_interact` `z_reload`
