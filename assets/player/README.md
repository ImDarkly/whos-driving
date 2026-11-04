# Crash-test dummy

Original mesh implementation based on Oleksandr's supplied v1.1 visual reference, 2026-11-04. No downloaded character geometry or textures. The reference image's authorship/license was not independently established; no new license for that reference is asserted here.

- Editable source: `art/player/crash_dummy.blend` (Blender 5.2.1 LTS). Source/studio assets are excluded from Godot scanning with `art/.gdignore`.
- Runtime asset: `crash_dummy.glb`, self-contained, 1,360 triangles, 34 mesh objects (including eyes, badges, joints and soles), one 14-bone armature. All pieces have rigid bone weights. No UVs/textures required.
- Godot forward is -Z, up +Y. Blender forward is +Y, up +Z. Standing height is 0.942 m; shell head width 0.335 m. Body root is at the floor origin. Scale is an asset fit decision, not a gameplay camera change.
- Cabin-study placement uses uniform scale 1.2 (effective standing height 1.13 m, head width 0.402 m), the existing seat X/Z coordinates, and vertical offsets -0.24 m front / -0.227 m rear. Cushion surface rays measured +0.112 m front / +0.125 m rear in car-local up. The seated thigh undersides sit about 6 mm above those surfaces. Head centers are lower than the existing camera anchors; camera/body alignment needs a separate integration decision.
- Static inspection pose clips: `Stand`, `Sit`, `Steer`, `LookSide`. Select the corresponding Action or unmute only its NLA track in Blender; in Godot use AnimationPlayer. The two keyed frames hold a pose; they are not motion animations. Bones have no mechanical limit constraints or IK.
- `Body_Repaint` is the only repaintable shell material. `body_yellow.tres`, `body_red.tres`, `body_blue.tres`, `body_green.tres` are reusable Godot materials; corresponding palettes are saved in Blender. Override only surfaces using Body_Repaint, sharing the chosen material within one character and using a distinct material instance between players. Keep charcoal joints, ivory eyes and safety-yellow badges fixed.
- The Blender file contains a studio camera, lights and ground; the GLB exports only the character and rig. It does not contain the third-party car. The temporary four-passenger cabin study is `build/dummy-cabin-study.blend`; the car's own attribution remains in `assets/retro_car/ATTRIBUTION.md`.

Rebuild from the repository with installed Blender:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python tools/build_dummy.py
```

Original character previews are tracked in `docs/player-previews/`. Car-containing `cabin-*.png` images are local-only Blender fit studies with the intact car, not Godot gameplay captures. The local study passenger is hidden for each seat camera. The rebuild script also needs the restored local car GLB for its cabin-study step; see restoration instructions in `docs/KNOWLEDGE.md`. Normal F5 gameplay still uses the previous colored heads. Demo launchers and their separate validation/adoption status are documented there; production character integration and networked gaze remain outside this asset delivery.

Godot import verification:

```powershell
& 'C:/Godot/Godot_v4.6.2-stable_win64_console.exe' --headless --path . --editor --import --quit
& 'C:/Godot/Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script tests/check_dummy.gd
```
