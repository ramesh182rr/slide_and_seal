# Poly Haven assets (CC0)

Every file in this folder comes from [Poly Haven](https://polyhaven.com) and is released under
**CC0 1.0 Universal (public domain)**: free for any use, commercial included, no attribution required
(https://polyhaven.com/license). Credit is given anyway, below.

Downloaded 2026-11-16 at 1k resolution. Textures: `_diff` (albedo), `_nor` (OpenGL normal map),
`_arm` (R = ambient occlusion, G = roughness, B = metalness).

| Folder | Source | Used for |
|---|---|---|
| mossy_rock | https://polyhaven.com/a/mossy_rock | World 1 floor stone |
| castle_wall_slates | https://polyhaven.com/a/castle_wall_slates | Walls (masonry); World 2 ice-chamber blocks (tinted) |
| cliff_side | https://polyhaven.com/a/cliff_side | Island cliffs and rock surfaces |
| dark_rock | https://polyhaven.com/a/dark_rock | World 7 obsidian |
| marble_01 | https://polyhaven.com/a/marble_01 | World 5 temple floor |
| snow_02 | https://polyhaven.com/a/snow_02 | World 2 snow and ice floor |
| metal_plate | https://polyhaven.com/a/metal_plate | World 3 deck; movable blocks |
| rusty_metal_02 | https://polyhaven.com/a/rusty_metal_02 | World 3 frame, pipes, tanks; gates |
| blue_metal_plate | https://polyhaven.com/a/blue_metal_plate | World 6 tech panels |
| boulder_01 | https://polyhaven.com/a/boulder_01 | Island undersides (model: `assets/models/boulder_01.glb`) |
| rock_07 | https://polyhaven.com/a/rock_07 | Floating rocks (model: `assets/models/rock_07.glb`) |
| rock_09 | https://polyhaven.com/a/rock_09 | Floating rocks (model: `assets/models/rock_09.glb`) |
| Barrel_01 | https://polyhaven.com/a/Barrel_01 | World 3 deck props (model: `assets/models/Barrel_01.glb`, "explosive" texture variant) |
| barrel_03 | https://polyhaven.com/a/barrel_03 | World 3 deck props (model: `assets/models/barrel_03.glb`) |
| concrete_moss | https://polyhaven.com/a/concrete_moss | World 1 colossal maze walls |
| overgrown_concrete_pavers | https://polyhaven.com/a/overgrown_concrete_pavers | World 1 arena ground |
| kloofendal_misty_morning_puresky | https://polyhaven.com/a/kloofendal_misty_morning_puresky | Soft sky HDRI for reflections only (never shown) |

The scanned models in `assets/models/` are decimated for phones by
`tools/blender/process_rocks.py` (Blender, headless). `column.glb` and `seal_dais.glb` are original
models authored from code by `tools/blender/build_props.py` (project-owned, not Poly Haven).
