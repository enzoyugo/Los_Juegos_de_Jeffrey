# Jeffrey Human-QA Fix Pass V2

Date: 2026-08-31  
Review root: `E:\JeffreyAIResearch\outputs\runtime-review\jeffrey_human_qa_fix_v2\`

## Primary verdict

`JEFFREY_HUMAN_QA_FIX_V2_PARTIAL`

The required production capture pipeline ran successfully on the current post-fix runtime. One safe P1 Hub correction was implemented and visually inspected. Several requested P0 states cannot be truthfully marked complete because the available capture scenes do not reach them, and the current production authority intentionally remains V3 for Shopping del Sol.

## Strict issue table

| ID | Severity | Issue | Fix | Runtime proof | Status |
|---|---|---|---|---|---|
| P0-01 | P0 | Track spawn/respawn grounding | No tuning change; existing reset contract retained | Shell validator reports 4/4 wheels at spawn; no dedicated respawn capture | PARTIAL |
| P0-02 | P0 | Smash platform placement/collision | Not changed without reachable jump/land proof | Existing stage collision is present; no fresh platform runtime proof | BLOCKED |
| P0-03 | P0 | Zombies door open/pass-through | No code change; existing `unlock()` disables mesh, collision and nav obstacle | Door API covered by existing tests; required three-state captures not reachable in sign-off scene | PARTIAL |
| P0-04 | P0 | New Zombies map authority | Preserved production V3 authority; V4.x candidates remain firewalled | Runtime sign-off shows Shopping del Sol V3 presentation; V4 candidate compatibility not proven | BLOCKED |
| P0-05 | P0 | Downloaded weapon models | Not integrated; production viewmodel remains procedural | Candidate paths exist, but no approved mapping/hand placement proof | BLOCKED |
| P0-06 | P0 | Downloaded zombie models | Not integrated; production enemy remains code-built humanoid | Candidate FBX/GLB paths exist, but no safe runtime adapter proof | BLOCKED |
| P0-07 | P0 | Jaguareté latest model/orientation | No change; catalog already points to `jaguarete_game_ready_v4.glb` | Fresh character-select capture visibly shows Jaguareté | PARTIAL |
| P1-01 | P1 | Players Today layout | No code change in this pass | Fresh roster capture generated | PARTIAL |
| P1-02 | P1 | Hub duplicated `JUGAR` labels | Mode badge is blanked only for playable `JUGAR` status; non-playable statuses remain supported | Fresh Hub capture inspected; duplicate labels are gone | PASS |
| P1-03 | P1 | Character Select | No code change | Fresh capture inspected; order panel remains sparse | PARTIAL |
| P1-04 | P1 | Smash pause | Not changed | Not reached by production sign-off scene | BLOCKED |
| P1-05 | P1 | Zombies pause/game over | No code change | Fresh game-over capture exists; distinct pause not reached | PARTIAL |
| P1-06 | P1 | Copa result | No code change | Fresh Copa capture exists; known layout issues remain | PARTIAL |
| P1-07 | P1 | Editar Jugadores | Not changed | Not included in sign-off capture | BLOCKED |
| P2-01 | P2 | Track active players bounds | No code change | No dedicated config capture | BLOCKED |
| P2-02 | P2 | Track duplicate placeholders | No code change | Fresh Track entry capture shows current configuration | PARTIAL |
| P2-03 | P2 | Track HUD scale/position | No code change | Fresh Track gameplay/HUD capture exists and was inspected | PARTIAL |
| P2-04 | P2 | Zombies HUD text placement | No code change | Fresh game-over/HUD state captured; live gameplay HUD not captured | PARTIAL |
| P2-05 | P2 | Hub environment placement | No code change | Fresh Hub environment capture exists; no new transform issue was introduced | PARTIAL |

## Files modified

- `scripts/ui/jeffrey/mode_select_card.gd`
- This report and the baseline/text/authority reports under the repository `docs/` folder.

No asset-generation work, gameplay balance, Shopping del Sol source art, or unrelated dirty files were modified.

## Runtime and tests

- Godot 4.7.2 parse/editor boot: PASS.
- Production GPU sign-off capture: PASS on NVIDIA RTX 2060 SUPER / D3D12 at 1920×1080.
- Targeted pytest set: `111 passed, 2 warnings`.
- Earlier full baseline remains `508 passed, 1 failed`; the failure is the pre-existing modified stationary-stability JSON fixture.

## Review evidence

Fresh capture source: `E:\JeffreyAIResearch\outputs\runtime-review\jeffrey_human_visual_signoff_v1\`  
Copied review package: `E:\JeffreyAIResearch\outputs\runtime-review\jeffrey_human_qa_fix_v2\`

The Hub after image was visually inspected and confirms the three playable mode cards no longer render the duplicated `JUGAR` side label. Track, character select, Zombies and Copa captures were also inspected; remaining weaknesses are recorded above rather than hidden.

## Final smoke limitation

The available deterministic sign-off scene covers boot, roster, Hub, Copa, character select, Track entry/gameplay/pause/results, Zombies menu/game-over and options. It does not automate the full interactive shell path through door purchase/pass-through, weapon fire with downloaded model, downloaded zombie wave, Smash platform landing, or Editar Jugadores save/cancel. Those sections require a dedicated reachable capture harness or human input.
