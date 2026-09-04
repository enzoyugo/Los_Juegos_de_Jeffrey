# PHAROS S017 runtime driving lab

Run directly with Godot 4.7.2:

```powershell
& 'C:\Users\AORUS\Downloads\Godot_v4.7.2-stable_win64.exe' --path 'E:\SuperSmashKapes\super-smash-kapes' 'res://tests/integration/pharos_track_s017/PharosTrackS017DrivingLab.tscn'
```

This isolated scene imports the real Pharos GLB and instantiates the real `TrackCarWheelPhysics.tscn` / `TrackWheelCar` controller. The GLB copy is required by Godot's `res://` importer and has the same SHA-256 as the Pharos source. The scale is uniform and explicitly experimental: `8.20 / 4.00 = 2.05`.

Controls: W/S accelerate/brake, A/D steer, C reset, F4 toggles collision debug ON/OFF. The V2 adapter derives the spawn basis from the checkpoint source, applies only a visual CarVisualMount correction, and creates neutral laboratory lighting. This is not production Track and is not registered in menus.
