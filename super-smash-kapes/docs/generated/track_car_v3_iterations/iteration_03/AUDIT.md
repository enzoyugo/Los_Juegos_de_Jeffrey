# AUDIT V3

## PRIMARY VERDICT

PASS

## SEMANTIC ORIENTATION

True

## BODY

{
  "vertices": 11191,
  "faces": 7655,
  "aabb": {
    "min": [
      -0.2431640625,
      0.03320315480232239,
      -0.4990234375
    ],
    "max": [
      0.2431640625,
      0.322265625,
      0.4990234375
    ],
    "size": [
      0.486328125,
      0.2890624701976776,
      0.998046875
    ],
    "center": [
      0.0,
      0.1777343899011612,
      0.0
    ]
  },
  "centroid": [
    -0.00267,
    0.17223,
    0.07328
  ],
  "z_min": -0.49902,
  "z_max": 0.49902,
  "semantic": {
    "z_min": -0.49902,
    "z_max": 0.49902,
    "y_at_zmin": 0.10417,
    "y_at_zmax": 0.18026,
    "high_y_mean_z": 0.21582,
    "pass": true
  }
}

## WHEELS

### FL
verts=3374 faces=2636 max_r=0.09491 aabb=[0.05664, 0.16797, 0.18555] comps=463 stray=0 sweep=True pass=True

### FR
verts=3303 faces=2568 max_r=0.09527 aabb=[0.05664, 0.16602, 0.18555] comps=477 stray=0 sweep=True pass=True

### RL
verts=3371 faces=2674 max_r=0.09495 aabb=[0.05859, 0.16797, 0.16602] comps=450 stray=0 sweep=True pass=True

### RR
verts=3414 faces=2636 max_r=0.09517 aabb=[0.05664, 0.16797, 0.16797] comps=485 stray=0 sweep=True pass=True

## PIVOTS

STEER/SPIN center delta 0. WheelMesh rest origin (0,0,0). PASS

## RUNTIME

semantic_fwd = chassis_fwd = (0,0,-1). World radius ≈ 0.42 m. live=1. PASS

## AIRBORNE

AIRBORNE_ENTER/EXIT reason=RESET_SETTLE after spawn. Classified, not jump spam. PASS (human still confirms no post-settle spam)

## LANDING

Landing window + compression_m authority present. Validator OK. PASS (human still confirms peak_c > 0 on F6 drop)

## D3D12 / ATLAS

loaded=true 4096x4096 unique=1 fallback=false. PASS

## VALIDATOR

[JEFFREY_VALIDATE] OK

## DEFECTS TO FIX NEXT

- none (automated). Human F6 remains the visual certification gate.
