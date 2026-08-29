# Shell V1 — UI Audit

Short audit of the post-migration Jeffrey shell **before** V2 layout work. Smash battle UI (`m0_hud`, Defensores, `KapesMenuScreen` title) is out of scope except where the global shell still borrows it.

---

## Hierarchy

Boot: `JeffreyBoot.tscn` → `jeffrey_app.gd` swaps Control scripts under `ShellUI`.

V1 screens are vertical `VBoxContainer` stacks: title, subtitle, then a list of full-width buttons (`GameSelection`) or `CheckButton` rows (`Logon`, `ModePlayerSelect`).

Problem: modes, roster, and Options share the same visual weight. Options looks like a fourth mode. Roster is a leftover gold line (`Hoy: P1`).

---

## Responsiveness

Safe-area margins come from `KapesUILayout` (Smash constants). Layout is `position = safe.position` on a wrapping Control, not a `MarginContainer` tree. Works at 1080p; empty vertical space is large on 16:9 because content is center-clustered with no mode grid.

---

## Empty space

Mode player select is a title + one toggle + lots of unused canvas. Game select is a column of 5 similar buttons. No 3-up mode stage.

---

## Reusable components

Only `JeffreyShellChrome` (background + title + generic Button). No player card, mode card, badge, or roster widget. Style copied per screen.

---

## Hardcoded styling

Font sizes 18/22/26/46/52/56 inlined. Colors taken from `KapesVisual` (Smash Paraguay palette).

---

## Background coupling

`JeffreyShellChrome` loads `res://assets/ui/menu/main_menu_bg.png` (Asunción / Smash title art) plus a dark wash. Global shell is visually Smash.

---

## Button consistency

Same primary button recipe for Smash, Hotseat, Zombies, Edit Players, and Options.

---

## Roster / player-count scalability

Roster is a single concatenated string. Mode select is a vertical checkbox list — 10 Hotseat names would be a long scroll, not a grid. Smash helper still says “P1 teclado / P2 teclado”.

---

## Copy

Game select subtitle is roadmap: “Smash Kapes está listo; el resto llega después.”

Mode buttons concatenate status: `HOTSEAT — PRÓXIMAMENTE`.

Coming soon: `DEV PLACEHOLDER`.

---

## Navigation

Back exists on some screens but Coming Soon returns to Game Select (skips player select). Escape is not a consistent shell Back. Character select Esc is hosted-only.

---

## Localization

All Spanish hardcoded in scripts (acceptable for V1/V2).

---

## V2 targets (from this audit)

1. Neutral global background; Smash art stays Smash-owned.
2. Three mode cards as the main event; roster + Options secondary.
3. Shared player-card grid for logon and mode select (up to 10).
4. Status badges from registry, not concatenated names.
5. Profile names in shell; P1/P2 only as controller slots.
6. Continue disabled until min/max valid.
7. Back = one step.
