# Zombies Weapons and Live Gameplay QA V1

## Candidate decision

The supplied weapon candidates were audited in Blender 5.2.1. The TT pistol is the selected sidearm candidate and the Colt M4A1 is the selected rifle candidate based on readable silhouette, compact first-person proportions, and lower complexity than the other rifle candidates. The source GLBs remain immutable development candidates; their provenance/license is not confirmed and they are not redistributed by this report.

The supplied zombie character FBX meshes use FBX version 6100. Blender 5.2.1 and the installed legacy Blender 2.83.1 both reject that mesh version, so those meshes are not promoted into runtime. The animation-only FBXs import as 65-bone Mixamo clips, but without a compatible character mesh there is no safe retargeted runtime package. Runtime remains the verified procedural zombie authority with state-driven spawn/chase/windup/attack/hit/death transforms.

## Runtime weapon authority

The authoritative weapons remain `pistol` and `smg` resources in `data/zombies/`, with centralized damage, rate, magazine, reserve, reload, spread, range, and automatic-fire values. The player can now cycle owned weapons with `Q`; wall-buying the SMG equips it immediately, and cycling returns to the pistol without resetting either weapon's ammunition. `G` remains reload and left mouse remains fire.

## Candidate audit summary

| Candidate | Triangles | Materials | Decision |
| --- | ---: | ---: | --- |
| TT pistol | 2,886 | 3 | Selected pistol candidate; compact but orientation/hand marker still needs an authored runtime wrapper |
| Colt M4A1 | 23,533 | 7 | Selected rifle candidate; strongest safe rifle candidate for a later authored wrapper |
| G95 A1 | 28,752 | 16 | Hold; higher material/object complexity |
| Diemaco C7 | 19,200 | 21 | Hold; material count and imported bounds need cleanup |
| BCM MK12 | 25,421 | 28 | Hold; too many materials for current first-person pass |
| DD MK18 | 27,996 | 36 | Hold; highest material overhead |

## Live-QA limitation

The local computer-use helper could enumerate the Godot window but its Windows.Graphics.Capture binding failed on the current Godot window (`SetIsBorderRequired: E_NOINTERFACE`). Existing deterministic Godot capture remains available, but this turn could not truthfully claim a completed manual five-wave keyboard playthrough through that helper.
