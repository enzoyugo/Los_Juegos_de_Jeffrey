# Shopping interior threshold V1

**Verdict: PARTIAL — entry zone only**

Whole interior is out of scope. V2 adds ~20–40 m behind the main doors:

- Tiled plaza floor
- Side shopfront glass modules
- Mall columns
- Ceiling light fixtures + LIGHT_INTERIOR_* empties
- Kiosk module (visual; Godot kiosk collision stays proxy)
- Bench + planter

Greybox gallery / wall-buy / MAX AMMO remain behind this zone.

Player should not immediately see an empty grey void after `[E] ABRIR SHOPPING`, but the deep mall is still greybox until a later interior sprint.
