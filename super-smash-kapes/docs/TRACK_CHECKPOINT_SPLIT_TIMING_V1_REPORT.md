# Track checkpoint split timing V1

**Verdict: TRACK_CHECKPOINT_SPLITS_V1_RESOLVED**

## Bug

HUD TARGET showed the target player's **final** lap time. Delta compared **current elapsed** to that final time every frame (`00:51` vs `00:10` → `-40.779`). Wrong.

## Correct

Store `checkpoint_times[]` per completed run (`best_splits` / `run_splits`).

At CP N:

`delta = current_elapsed_at_CP_N - target_split_CP_N`

Negative = ahead. Positive = behind.

Qualification / missing target split: `TARGET --:--.---` and no fake delta.

## Validation

`splits_valid`: count == checkpoint count, monotonic, final split ≤ lap + 0.05 s.

Smoke: `scenes/debug/SmokeTrackCheckpointSplitsV1.tscn`

Hotseat last-place logic was not rewritten.
