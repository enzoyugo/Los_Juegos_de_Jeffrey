# Super Smash Kapes — UI Flow

## Title → battle

```text
BOOT
  ↓
TITLE (responsive KapesMenuScreen)
  ├─ background COVER
  ├─ logo CONTAIN (left column)
  └─ Local Battle panel CONTAIN (right column)
  ↓ Paraguay red → white → blue wipe (~340ms)
ELIGÍ TU KAPE (KapesCharacterSelectScreen)
  ├─ TERERÉ / JAGUARETÉ cards (raw design portraits)
  ├─ P1: A/D + F/Space → LISTO
  └─ P2: ←/→ + N → LISTO
  ↓ both ready → wipe
DEFENSORES DEL CHACO (battle)
```

The title screen has one dominant player-facing action baked into the Local Battle artwork. Keyboard `F` or `Space` on the title screen opens Character Select (not direct battle). A single subtle hint reads `F / SPACE — JUGAR`. No debug microcopy.

## Battle

The gameplay scene remains `M0Playground.tscn`. Fighters spawn from `MatchSetup` via `FighterCatalog` (default fallback: Tereré vs Jaguareté). The HUD uses two angular player cards with fighter portrait textures:

```text
P1 / fighter portrait / damage / stock pips       P2 / fighter portrait / damage / stock pips
```

Damage pulses when it changes. The center callout uses `¡DALE!` and the footer only carries useful pause/rematch affordances.

## Pause

```text
ESC
  ↓
PAUSA
  ├─ CONTINUAR
  ├─ REINICIAR
  └─ MENÚ PRINCIPAL
```

Gameplay is paused while the overlay remains active. The overlay is a darkened angular layer, not an operating-system dialog.

## Results

```text
final KO
  ↓ Paraguay flag wipe
GANADOR
  ├─ TERERÉ GANA / JAGUARETÉ GANA (fighter display name)
  ├─ per-player fighter identity + stats
  ├─ REVANCHA
  └─ MENÚ
```

`REVANCHA` is the first focused action and preserves the selected fighter matchup. `R` remains a fast rematch path while the match is active or on the result screen.

## Transition ownership

`KapesFlagWipe` is a CanvasLayer child owned by `main.gd`. It covers the screen at roughly 170 ms, runs the scene action, and exits by roughly 340 ms. Gameplay mechanics are not paused or retuned by the visual transition.

## Debug separation

The original `M0Playground.tscn` remains available for direct development runs. Normal player-facing screens do not display `M0`, `PLAYGROUND`, `DEBUG`, `KEYBOARD READY`, or prototype status copy.
