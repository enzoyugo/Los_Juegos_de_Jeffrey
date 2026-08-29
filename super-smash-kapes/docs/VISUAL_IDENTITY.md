# Super Smash Kapes — Visual Identity

## North star

Super Smash Kapes is a South-American couch fighting game with fighting-game rhythm, sports-broadcast energy, arcade impact, and a distinctly Paraguayan night atmosphere. It should feel loud, warm, urban, celebratory, and immediately playable.

The identity is not a copied platform-fighter interface with a flag attached. It is an original system built from:

```text
Asunción at night
Palacio-inspired silhouette
Paraguay flag motion
street/stadium geometry
oversized arcade typography
angular physical panels
red/white/blue player identity
warm sodium-gold light
```

## Palette

| Token | Use | Value |
|---|---|---|
| Night | deep background | `#070A13` |
| Midnight | panels/depth | `#10182A` |
| Ink | secondary geometry | `#151D31` |
| Paraguay red | aggression, P1, transitions | `#D93B35` |
| Red bright | title/emphasis | `#F05A3C` |
| Paraguay blue | P2, depth, transition | `#2875B9` |
| Blue bright | P2 HUD emphasis | `#55A8FF` |
| Warm white | readable type | `#F5F0DF` |
| Gold | selection, winner, light | `#F5C66B` |
| Amber | street/stadium light | `#E0A84B` |

The dark foundation carries most of the screen. Flag colors are structural accents and motion bands, not a full-screen rainbow.

## Responsive layout (Presentation V1)

- Design resolution: 1920×1080 with 5.5% horizontal / 5% vertical safe margins.
- Menu background uses COVER; logo and battle panel use CONTAIN within safe area columns.
- HUD cards scale to ~22% × 12% of viewport inside safe margins.
- Layout utilities live in `scripts/ui/kapes_ui_layout.gd`.

## Typography

Headlines are oversized, uppercase, layered with outline/shadow, and placed asymmetrically. Body copy is sparse and secondary. The interface should communicate through a large action, a player identity, or a result—not paragraphs of product explanation.

## Shape language

Avoid soft SaaS cards. Use:

- Trapezoids and cropped panels
- Diagonal edges
- Flag-color slash bands
- Thin broadcast-style rules
- Hard selection borders
- Large readable blocks

`KapesPanel` and `KapesPlayerHUD` are reusable implementations of this language.

## Paraguayan motifs

The title backdrop uses original procedural abstractions rather than downloaded imagery:

- A simplified Palacio-inspired central tower and symmetrical wings
- Asunción night skyline blocks
- Warm city windows and street-lamp halos
- Moving Paraguay red/white/blue slash bands
- Stadium/urban depth geometry

The central star and official seal are intentionally not reproduced. Identity comes from atmosphere, palette, skyline rhythm, and flag motion.

## Screen hierarchy

### Title

Hero motif: Asunción at night, Palacio silhouette, and flag motion. The logo and `BATALLA LOCAL / JUGAR` action dominate.

### Battle HUD

Hero motif: sports/fighting geometry and player-color identity. Damage is the largest number; stocks are graphical pips.

### Pause

Hero motif: darkened gameplay with one angular flag-accented pause panel.

### Results

Hero motif: `GANADOR`, player color, statistics, and fast `REVANCHA`. It celebrates the winner without a long ceremony.

## Motion timing

```text
micro feedback: 80–150 ms
normal UI movement: 150–300 ms
flag transition: 340 ms
```

The title background breathes continuously. Buttons scale subtly on focus. Damage pulses on change. Flag wipes are short and skippable by their duration.

## Player identity

```text
P1 = red / ROJO
P2 = blue / AZUL
```

Identity is repeated through fighter color, HUD backplate, title player callout, result statistics, and impact context. Color is paired with explicit P1/P2 labels for readability.

## Future direction

Future fighter select should use the same identity system: large silhouettes, dramatic angled cards, player-color edges, sparse labels, and Paraguayan atmosphere. It should not become a grid of generic portrait rectangles.
