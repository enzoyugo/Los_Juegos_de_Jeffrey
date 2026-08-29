class_name TrackLastDance
extends RefCounted

## Canonical Last Dance lives on TrackTurnManager.
## fuel <= 0 at turn start → one definitive run (LAST DANCE).
## Survival: new alive-rank < rank captured before the finish (passed at least one person).
## Exact time ties do not count as a pass.
## Restart from START = surrender / immediate elimination.
## Checkpoint reset stays on the same Last Dance attempt.
## Surviving does not gift fuel. Consecutive Last Dances are allowed.

const STATE_NONE := "none"
const STATE_ACTIVE := "active"
const STATE_SURVIVED := "survived"
const STATE_ELIMINATED := "eliminated"
