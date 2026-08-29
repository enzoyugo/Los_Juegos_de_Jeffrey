# Development notes

## Toolchain

- Godot **4.7.2** stable
- Python 3 + `pytest` for repo gates
- Primary validation: Windows + D3D12 Forward+

## Important authorities

| System | Authority | Do not casually change |
|--------|-----------|------------------------|
| Copa Jeffrey | `JeffreyCore.copa` | Points table, `match_id` idempotency |
| Track | `scripts/track/` generation + physics | Seeds, checkpoints, ranking |
| Smash combat | fighter attack timing / knockback | Balance without evidence + tests |
| Settings | `JeffreyCore.settings` | Master / music / SFX sliders |

## Useful commands

```bash
# Full automated gate suite
pytest -q

# Regenerate first-party UI + Smash SFX
python tools/generate_jeffrey_sfx_pack.py
```

## Audio

- UI pack: `assets/audio/ui/` via `GlobalUiAudio`
- Smash pack: `assets/audio/smash/` via `SmashAudioV1`
- Both respect `master_volume` × `sfx_volume`

## Input hints

Use `JeffreyInputHint.make(action, label, accent)` instead of hardcoding per-screen control strings.
