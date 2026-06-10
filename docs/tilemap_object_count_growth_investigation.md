# TileMap Object Count Growth - Investigation Report

## 1. Short Summary

The Object Count growth issue was reproduced and measured in Godot 4.5.2 with a controlled chunk streaming test.

The important result is that the active game data stayed bounded while Godot's Object Count continued to grow in the normal TileMap coordinate path. This means the project was not simply keeping old chunks, spawned objects, trees, plants, mobs, or containers alive forever.

A second diagnostic test then reused a fixed TileMap coordinate window near the origin while still allowing the logical world coordinates to move forward. In that mode, the TileMap `used_rect` stayed bounded and Object Count stayed around 1900-2000 instead of growing past 10000+.

This strongly confirms the current root direction: the project is using logical infinite world coordinates directly as visual TileMap coordinates, and Godot 4.5.2 does not handle that runtime set/erase pattern well for this project.

This is not a production-ready fix yet. The fixed-window test proves the direction, but a real implementation needs to adapt the other systems that read from or write to the TileMap.

## 2. Project Context

Godot version tested: 4.5.2.

Main project scene:

- `res://scenes/menus/game_controller.tscn`

World scene involved in the test:

- `res://scenes/game/game.tscn`

Main world generation script:

- `res://scripts/game/world_gen.gd`

Main TileMap node:

- `World/WorldTileMap` in `scenes/game/game.tscn`

The project currently uses the classic multi-layer `TileMap` node. In newer Godot versions, the older multi-layer TileMap workflow has been deprecated in favor of separate `TileMapLayer` nodes. This is relevant technical context, but it is not by itself proof that the deprecation caused the Object Count growth.

## 3. What Was Tested

A fake-center chunk streaming diagnostic was added. Instead of relying on player movement, the diagnostic moves the active chunk center automatically along the X axis. This keeps the test consistent and makes it easier to compare results.

Baseline diagnostic setup:

- `debug_tilemap_growth = true`
- `debug_use_fake_chunk_center = true`
- `debug_use_fixed_tilemap_window = false`
- `debug_force_tilemap_update_after_clear = false`
- `debug_fake_chunk_steps_per_second = 5.0`
- `chunk_size = 6`
- `view_distance = 3`

Observed baseline result:

- `generated_chunks` stayed bounded around 49/50.
- `total_used_cells` stayed bounded around 1764/1800.
- `object_container_children` stayed 0.
- `chunk_containers` stayed 0.
- TileMap `used_rect.position` kept moving into larger absolute X coordinates.
- Godot Object Count still grew over time, reaching the 10000+ range.

Two smaller A/B checks were also tested:

- Disabling the forced `tilemap.update_internals()` call after clearing chunks.
- Skipping unnecessary `set_cell()` and `erase_cell()` calls when the cell already had the requested state.

Neither check fully stopped the Object Count growth.

## 4. Fixed-Window Diagnostic Result

A fixed TileMap coordinate window diagnostic was then tested.

The key idea was:

- Keep logical world chunk coordinates moving normally.
- Keep noise and terrain decisions using real world tile coordinates.
- Write and erase visible TileMap cells inside a reusable bounded coordinate window near the origin.

Fixed-window diagnostic setup:

- `debug_tilemap_growth = true`
- `debug_use_fake_chunk_center = true`
- `debug_use_fixed_tilemap_window = true`
- `debug_force_tilemap_update_after_clear = false`
- `debug_fake_chunk_steps_per_second = 5.0`
- `chunk_size = 6`
- `view_distance = 3`

Observed fixed-window result:

- `generated_chunks` stayed bounded around 49/50.
- `total_used_cells` stayed bounded around 1764/1800.
- TileMap `used_rect.position` stayed near the origin instead of moving to huge X values.
- Godot Object Count stayed around 1900-2000 instead of growing past 10000+.

This is the strongest diagnostic result so far. It shows that keeping the visual TileMap coordinate area bounded greatly changes the Object Count behavior.

## 5. What Has Been Ruled Out So Far

The current tests make these causes unlikely:

- Gameplay objects accumulating without being deleted.
- Chunk containers accumulating.
- Object containers growing over time.
- The project failing to unload old chunks.
- The TileMap keeping an ever-growing number of active used cells.
- `tilemap.update_internals()` being the main cause.
- Duplicate or unnecessary `set_cell()` / `erase_cell()` calls being the main cause.

These checks matter because they separate a normal project-side leak from a TileMap runtime update problem.

## 6. Current Technical Conclusion

The project currently uses the same coordinate system for two different jobs:

- Logical world coordinates: the real infinite world position used for generation, saving, loading, and gameplay.
- Visual TileMap coordinates: the coordinates passed into `TileMap.set_cell()`, `erase_cell()`, and other TileMap read/write calls.

For a small or finite map, using the same coordinates is usually fine. For an infinite streaming world, it means the TileMap is constantly touched farther and farther from the origin as the player or fake center moves.

Even though old cells are erased and the active cell count remains bounded, Godot 4.5.2 still shows Object Count growth in this pattern. When the visual TileMap coordinates are kept bounded, the growth is greatly reduced or stabilized in the diagnostic test.

So the practical root direction is not "chunks are not unloading." The practical root direction is that the visual TileMap should not be used as an infinite-coordinate storage surface.

## 7. Why Godot 4.2 And Godot 4.5 May Behave Differently

The project reportedly behaves differently in Godot 4.2 compared with Godot 4.5/4.6.

One relevant context point is that the project uses the classic multi-layer `TileMap` node. In newer Godot versions, this older workflow has been deprecated in favor of separate `TileMapLayer` nodes.

This does not prove that the deprecation itself is the cause. It does mean the project is relying on an older TileMap workflow in newer engine versions, while also doing demanding runtime infinite-world streaming.

The fixed-window diagnostic points more specifically to coordinate growth in runtime TileMap mutation as the important trigger.

## 8. Diagnostic Code Included

The branch includes optional diagnostic code in `scripts/game/world_gen.gd`.

The diagnostic flags are disabled by default:

- `debug_tilemap_growth = false`
- `debug_use_fake_chunk_center = false`
- `debug_use_fixed_tilemap_window = false`
- `debug_force_tilemap_update_after_clear = false`

Normal gameplay still uses the player position as the chunk center. The fixed-window mode only activates when both of these are enabled:

- `debug_use_fake_chunk_center = true`
- `debug_use_fixed_tilemap_window = true`

The diagnostic print includes:

- current center chunk
- whether fake center is enabled
- whether fixed-window mode is enabled
- generated chunk count
- chunk size
- view distance
- used cells per TileMap layer
- total used cells
- TileMap used rect
- Godot Object Count
- available memory monitors
- object container child count
- chunk container count

This code is diagnostic-only. It is not a full gameplay implementation of the fixed-window approach.

## 9. Why The Diagnostic Is Not Production-Ready

The fixed-window test only remaps the main chunk generation and clearing path enough to prove the Object Count behavior.

A production solution would also need to review and adapt other systems that read from or write to the TileMap, including:

- player tile editing
- saved tile changes
- object placement checks
- minimap updates
- mob/object positioning checks
- `TileFollower`
- Better Terrain reads/writes
- any direct TileMap reads/writes outside the tested path

Without adapting those systems, the fixed-window mode should not be treated as a finished gameplay fix.

## 10. Recommended Solution Path

The recommended next phase is to implement a production coordinate separation layer.

Suggested helpers:

- `world_tile_to_display_tile()`
- `display_tile_to_world_tile()`
- `world_chunk_to_display_chunk()`

The goal is to keep logical world coordinates stable for gameplay, generation, saving, and loading, while keeping visual TileMap coordinates inside a bounded reusable area.

The production implementation should then decide clearly which systems use logical coordinates and which systems use display coordinates.

Likely affected files/scenes:

- `scripts/game/world_gen.gd`
- `scenes/game/game.tscn`
- `scenes/game/minimap.gd`
- `scripts/game/tile_follower.gd`
- `scripts/game/mobs/mob_manager.gd`
- any object placement or saved-change logic inside `scripts/game/world_gen.gd`

After implementation, the same fake-center Object Count diagnostic should be run again to confirm:

- active chunk count remains bounded
- active used cell count remains bounded
- TileMap `used_rect` stays bounded
- Object Count remains stable over time

## 11. TileMapLayer Migration

A full migration from classic multi-layer `TileMap` to multiple `TileMapLayer` nodes is a cleaner long-term modernization path for Godot 4.5+.

However, this should be treated as a larger separate phase, not as the smallest immediate fix.

The project currently relies heavily on multi-layer TileMap APIs and Better Terrain calls that pass a TileMap plus a layer index. Migrating to `TileMapLayer` would likely affect world generation, tile editing, minimap logic, object placement, saved changes, and addon integration.

Also, TileMapLayer migration alone would not automatically solve the infinite-coordinate pattern unless the production implementation also separates logical world coordinates from visual display coordinates.

## 12. Client-Facing Recommendation

The investigation has reproduced the issue, ruled out several simple causes, and confirmed the strongest technical direction with a bounded coordinate diagnostic.

The recommended next work is not a broad rewrite. The next practical scope should be a targeted production coordinate-mapping implementation, followed by validation using the same Object Count stress test.

Only after that should a full TileMapLayer migration be considered as a separate modernization step.
