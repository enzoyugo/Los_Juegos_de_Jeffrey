# Smash Stage Pipeline V1

## Current stages

| ID | Scene | Layout |
|----|-------|--------|
| defensores | `DefensoresDelChacoStage.tscn` | Main + 2 soft platforms (M0) |
| palacio | `PalacioDeLopezStage.tscn` | Reuses M0 layout + palace silhouette BG |
| costanera | `CostaneraDeAsuncionStage.tscn` | Wide single platform |

## Registry

`scripts/stages/stage_catalog.gd`

Carries: scene path, display name, spawns, blast AABB.

## Load path

`MatchSetup.stage_id` → `M0Playground._setup_stage()` → instantiate scene → apply spawns/blasts.

Combat rules stay in playground/fighters; stages only provide geometry + presentation (`show_ko` / `show_final_ko`).

## Selection

- Jeffrey character select: stage button row
- Kapes character select: Q/E cycle
- Env override: `SSK_STAGE_ID`

## How to add a stage

1. Gameplay collision scene (or reuse M0)
2. Wrapper script extending `jeffrey_smash_stage_base.gd` (or Defensores pattern)
3. Register in `StageCatalog`
4. Tests for scene path + blast/spawn validity
