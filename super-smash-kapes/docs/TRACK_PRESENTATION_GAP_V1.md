# Track Presentation Gap — V1

Diagnostic sprint: **JEFFREY PERFORMANCE + TRACK PRESENTATION DIAGNOSTIC V1**

Human video (~123s) confirms a sharp quality drop when entering Track versus Hub / Character Select.

---

## Summary matrix

| Area | CURRENT | TARGET | GAP | Implementation | Asset required | Priority |
|------|---------|--------|-----|----------------|----------------|----------|
| Sky / background | Flat `#87a0b4` BG_COLOR | Stylized dusk/speed sky with depth | No horizon interest, reads as debug viewport | Code: ProceduralSky + fog (V1 quick win) | Optional HDRI later | P0 |
| Horizon | None — course floats in void | Distant ground silhouette or city strip | Zero world anchor | Code: large ground plane (V1 quick win) | Urban skyline kit (V2 lab exists) | P0 |
| Terrain / backdrop geometry | Box solids only | Embankments, props, distant blocks | No environmental context | Deferred — kit/scenery pipeline in labs | GLB kit pieces | P1 |
| Lighting | Single DirectionalLight, no shadows | Warm key + readable fill + shadows | Flat, low contrast | Code: shadowed sun + sky ambient (V1) | — | P0 |
| Fog / atmosphere | None (pre-V1) | Light aerial perspective | Weak depth | Code: fog (V1 quick win) | — | P0 |
| Road material | Flat StandardMaterial3D greys | Readable asphalt with edge contrast | Road/barrier/off-course similar | Code: darker road + roughness (V1 partial) | Textured road atlas | P1 |
| Barriers / rails | Grey boxes `#9aa0aa` | High-contrast guardrails | Low readability at speed | Code: color tweak | Barrier mesh kit | P2 |
| Road markings | None | Center lines, start/finish emphasis | Hard to read racing line | Procedural decals or mesh strips | Marking atlas | P1 |
| Environment props | None in production TrackMain | Palm/building/signage per V2 lab | Empty world | Promote lab scenery selectively | Authored GLB props | P1 |
| Shadows | Off (pre-V1) | Car + track contact shadows | Floating appearance | Code: directional shadows (V1) | — | P0 |
| Car presentation | 4096 source atlas car | Same art, better lighting context | Car OK; world makes it look placeholder | Lighting/env fix | Articulated wheel GLB (lab) | P2 |
| Camera | Chase FOV 70–86 | Stronger speed read | Adequate logic; weak context | Tune FOV/punch (future) | — | P2 |
| Sense of speed | FOV ramp only | Motion parallax + environment | No reference objects | Scenery + fog (partial) | Speed FX overlay | P2 |
| HUD | Small gold labels, greybox copy | Jeffrey Track cyan hierarchy | Disconnected from shell | Code: cyan timer panel (V1) | Track HUD frame PNG | P1 |
| Countdown / start | Large center status text | Mode-branded countdown | Functional but generic | Style pass | Countdown art | P2 |
| Timer | 28px gold | Dominant cyan TIME block | Low hierarchy | Code: 36px cyan panel (V1) | — | P1 |
| Checkpoint feedback | Text only | Visual gate + SFX | Weak moment | Existing gates; polish pass | Gate VFX | P2 |
| Finish feedback | Board text | Podium-style overlay | Functional greybox | Copa overlay exists | Finish banner | P2 |
| Pause screen | Gold "PAUSA" | Track-branded pause | Minor mismatch | Code: cyan title (V1) | — | P2 |

---

## Root cause of “prototype” feel

Track production path (`TrackMain` → `track_race.gd` → V1 greybox generator) intentionally prioritizes **physics parity** over presentation. Shell/Character Select use authored PNG frames and Jeffrey gold identity; Track uses:

- Procedural `BoxMesh` solids (~370 bodies for media length)
- Runtime flat color materials
- No sky, fog, shadows, or backdrop (pre-V1 quick wins)
- HUD built from generic shell tokens, not Jeffrey Track mode accent

This is a **pipeline mismatch**, not merely missing UI polish.

---

## What V1 quick wins address (code-only)

1. Procedural sky + filmic tonemap + fog
2. Shadowed directional light
3. Horizon ground plane
4. Darker road albedo + material roughness
5. Track HUD cyan timer hierarchy + branded setup/pause titles

---

## What remains asset-driven

- Kit-based track pieces (V2 lab)
- Scenery generator props
- Road marking textures
- Track HUD chrome PNG
- Speed-line / FX overlays

See also: [`JEFFREY_UI_ASSET_GAPS_V1.md`](JEFFREY_UI_ASSET_GAPS_V1.md)
