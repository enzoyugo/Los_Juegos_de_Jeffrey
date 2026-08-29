# Jeffrey UI — Asset Gaps V1

Updated through JEFFREY_ART_SMASH_RELEASE_V1.

| SCREEN | ASSET | PURPOSE | PRIORITY | TEMP SUBSTITUTE | STATUS |
|--------|-------|---------|----------|-----------------|--------|
| Track HUD | Painted timer frame PNG | Cyan racing chrome | P2 | `TrackHudChromeV1` StyleBox | **Interim closed** |
| Track roadside | Urban GLB MultiMesh bake | Replace primitives | P2 | Kit + runtime `.res` | **Systems closed** |
| Track results | Mode result banner | Finish hierarchy | P2 | Track cyan banner | **Interim closed** |
| Track world | Asphalt grain + ground breakup | Surface readability | P1 | 256px noise atlases | **Interim closed** — still planar ground |
| Track signs | Signage atlas | Jeffrey brands | P2 | `signage_atlas_v2.png` | **Interim closed** |
| Zombies results | Game-over banner | Death / Copa 0 | P2 | `ZombiesResultBannerV1` | **Interim closed** |
| Copa full | Podium header | Top-3 hierarchy | P2 | `CopaJeffreyPodiumV1` StyleBox | **Interim closed** — not illustrated PNG |
| All shell | UI SFX pack | Couch feedback | P0 | First-party WAVs + `GlobalUiAudio` | **CLOSED** |
| Controllers | Glyph set | Input prompts | P1 | `JeffreyInputHint` text glyphs | **CLOSED (interim)** — neutral labels, not painted SVG atlas |
| Smash combat | Hit / KO / match SFX | Fight feedback | P1 | `assets/audio/smash/` + `SmashAudioV1` | **CLOSED** |
| Smash KO | Illustrated burst art | Party KO moment | P1 | Large KO text + stage KO state | **OPEN** |
| Smash / Track / Copa | Painted illustrated podium / banners | Premium hierarchy | P2 | StyleBox banners | **OPEN** |
| Characters | Additional fighters / outlines | Roster depth | P2 | Tereré + Jaguareté | **OPEN** |
| Stages | Extra Smash stages | Variety | P2 | Defensores del Chaco | **OPEN** |

## Notes

- Do not re-open Track environment placer architecture.
- Prefer painting into existing chrome/banner slots over new UI frameworks.
- Glyph system uses neutral keyboard/gamepad notation (no trademarked console art).
