# Los Juegos de Jeffrey

Party multi-mode couch game for Windows. One shell, four modes, shared Copa Jeffrey standings.

## Modes

| Mode | Accent | Summary |
|------|--------|---------|
| **SMASH** | red / impact | Local platform fighter (Tereré / Jaguareté) |
| **TRACK** | cyan / speed | Procedural arcade racing |
| **ZOMBIES** | green / danger | Wave survival in Shopping del Sol |
| **COPA JEFFREY** | gold | Shared season standings across modes |

## Requirements

- **Godot 4.7.2** stable
- Windows (primary development / validation platform)
- GPU recommended for Forward+ (validated on NVIDIA GeForce RTX 2060 SUPER, D3D12)

## How to run

1. Install Godot 4.7.2.
2. Open `project.godot` from this folder (`super-smash-kapes/` if cloning the monorepo layout).
3. Press Play. Boot opens on the Jeffrey shell (`JeffreyBoot`).

## Basic controls

**Shell:** Enter confirm · Esc back · arrows / stick navigate

**Smash:** move · jump / double jump · attack · pause Esc

**Track:** W accelerate · A/D steer · Shift drift · Esc pause

**Zombies:** move · shoot · interact / buy · Esc pause

Exact glyphs adapt via `JeffreyInputHint` (keyboard vs generic gamepad labels).

## Project structure

```
project.godot
assets/          # runtime art / audio
scripts/         # gameplay + shell
scenes/          # Godot scenes
data/            # shared data resources
tests/           # pytest gates
tools/           # generators / labs
docs/            # architecture + sprint reports
```

## Development status

Polished indie vertical slice: shell + Copa + Smash + Track + Zombies are playable end-to-end. Art and audio are first-party / authored where possible; some presentation still uses interim StyleBox chrome.

Frozen authorities:

- Copa scoring lives in `JeffreyCore.copa` (5 / 3 / 2 / 1 / DNF=0, idempotent `match_id`)
- Track physics / procedural seed rules
- Smash combat timing and knockback fundamentals

## Testing

From the project directory:

```bash
pytest -q
```

Godot labs and capture scenes live under `scenes/debug/` and `scripts/debug/`.

## License / third party

See `THIRD_PARTY_NOTICES.md` for distributed third-party notes. Game content and original SFX are project-owned unless otherwise marked.
