# Jeffrey UI — Third-Party License Audit V1

Audit date: 2026-08-28  
Upstream root: `E:\JeffreyAIResearch\upstream\godot-ui\sources`

No third-party runtime code was copied into `super-smash-kapes` during JEFFREY_UI_SYSTEM_V1. All integrations below are **policy decisions** for future work.

---

## Summary table

| Repository | License | Classification | Integration decision |
|------------|---------|----------------|----------------------|
| godot-ui-component-library | MIT (addon/LICENSE) | REFERENCE ONLY | Do not install; optional dropdown patterns only |
| EasyTransition | MIT claimed in README; **no LICENSE file in snapshot** | REFERENCE ONLY | Adapt fade/wipe ideas into first-party `JeffreyShellTransition` |
| simple-gui-transitions | **Unknown — no LICENSE/README** | REFERENCE ONLY | Adapt panel slide/fade into `JeffreyUiMotion` / shell transitions |
| godot-settings-menus | MIT (root + addon) | ADAPT | Borrow settings key patterns; bind to existing `JeffreyCore.settings` |
| Godot-Menus-Template (Maaack) | MIT + asset sub-licenses | REFERENCE ONLY | Study focus capture / scene loader; do not install alongside Jeffrey shell |

---

## 1. godot-ui-component-library

- **Path:** `...\godot-ui-component-library\godot-ui-component-library-main`
- **License:** MIT — `addons/GDUIComponentLibrary/LICENSE` — Copyright (c) 2023 Greyson Richey
- **Attribution:** Preserve copyright + MIT notice if any code copied
- **Commercial use:** Permitted under MIT
- **Proposed reuse:** None in V1 (REFERENCE ONLY)
- **Decision:** Two dropdown widgets insufficient for party-game shell; no runtime import

---

## 2. EasyTransition

- **Path:** `...\EasyTransition\EasyTransition-main`
- **License:** README states MIT © 2026 IUX Games — **no LICENSE file present in extracted archive**
- **Attribution:** Required if code copied; file missing → **do not copy**
- **Proposed reuse:** Scene fade/wipe timing references only
- **Decision:** REFERENCE ONLY. Implemented first-party shell crossfade in `jeffrey_shell_transition.gd`

---

## 3. simple-gui-transitions

- **Path:** `...\simple-gui-transitions\simple-gui-transitions-godot-4`
- **License:** **Not found** in archive
- **Proposed reuse:** In-panel stagger/slide concepts
- **Decision:** REFERENCE ONLY. Implemented `JeffreyUiMotion` + modal pop without importing addon

---

## 4. godot-settings-menus

- **Path:** `...\godot-settings-menus\godot-settings-menus-main`
- **License:** MIT — root `LICENSE` + `addons/settings_menus/LICENSE` — Copyright (c) 2026 Sean Elovirta
- **Attribution:** Required if addon or substantial code copied
- **Commercial use:** Permitted under MIT
- **Proposed reuse:** Settings tab structure, slider rows, persistence keys (ADAPT)
- **Decision:** ADAPT concepts only. V1 Options screen binds sliders to existing `JeffreyCore.settings` + `JeffreyPersistence`. Full addon **not installed** (would conflict with Jeffrey shell autoloads).

---

## 5. Godot-Menus-Template (Maaack)

- **Path:** `...\Godot-Menus-Template\Godot-Menus-Template-main`
- **License:** MIT — `LICENSE.txt` + addon copy; additional asset licenses (Kenney input icons, logos)
- **Attribution:** Required; input icon pack has separate License.txt
- **Proposed reuse:** `capture_focus.gd`, joypad input map patterns, scene loader architecture
- **Decision:** REFERENCE ONLY. Too heavy and overlaps Jeffrey shell + potential settings addon.

---

## Compliance notes

- Ambiguous or missing licenses → **no code copy** (EasyTransition, simple-gui-transitions).
- First-party Jeffrey UI System V1 files are original to Los Juegos de Jeffrey.
- Existing game art (`assets/ui/global/`, mode cards, boot art) remains first-party / project-owned.
