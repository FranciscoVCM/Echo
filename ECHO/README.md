# ECHO

A 2D top-down blob prototype for Godot 4.6.2.

## Run

Open the project in Godot 4.6.2 and press F5 to run the six-zone small-blob interaction arena. The original single-room Ping test remains available as `scenes/main.tscn`.

## Controls

- **WASD** or **arrow keys**: move.
- **Hold and release E**: charge and emit a Ping. Range increases with hold time; walls block the wave.
- **Mouse wheel** or **1–8**: select a Ping tone from C3 to C4.
- **Hold Space**: charge a dash; release to launch.
- **F1–F6**: teleport to a test zone.
- **R**: reset the current zone. **Shift+R**: reset the whole arena.

## Small-blob interaction tests

1. Frightened blob: send three short pings nearby; a full/strong ping resets progress and makes it retreat.
2. Sound connection: move around the central obstacle until one charged Ping reaches both separated blobs; repeat three times.
3. Echolocation: ping to reveal the hidden blob, then get close and ping again to make it travel to the marked safe location.
4. Frequency matching: select **5** for G3, then hit the blob with three Pings at that tone. It repeats the note after completion.
5. Group resonance: use one charged Ping to activate all three blobs together before their timers expire.
6. Silence: ping the unstable blob once to start its recovery timer, then avoid pinging it until the timer completes.

Each blob shows a debug state label. The HUD lists zone status and offers zone/all reset buttons. Test geometry and blob behaviors are placeholders. Ping notes are synthesized in code; the frequency-match blob and completed resonance group provide repeating note cues without external audio files.

## Project structure

- `assets`: images, audio, fonts, materials, and shaders.
- `scenes`: Godot scenes.
- `scripts`: GDScript files.
- `resources`: reusable resources.

## Code overview

- `PlayerController` (`scripts/player_controller.gd`) reads input, controls the `CharacterBody2D`, and reports wall pressure.
- `TopDownMovement` (`scripts/top_down_movement.gd`) calculates acceleration and deceleration as a reusable resource.
- `BlobVisual` (`scripts/blob_visual.gd`) draws the organic contour and animates movement, collisions, dash charge, and cooldown feedback.
- `resources/default_top_down_movement.tres` stores the default movement profile.
- `scripts/ping_emitter.gd` and `scripts/ping_wave.gd` handle finite pings and collision blocking.
- PingDummy (scripts/ping_dummy.gd) provides a stationary test blob that answers pings.
- `scripts/small_blob_interaction.gd` implements one selectable prototype behavior per test blob.
- `scripts/blob_interaction_coordinator.gd` tracks shared-wave connections and simultaneous resonance.
- `scripts/interaction_test_arena.gd` builds the separated development zones, HUD, teleports and reset controls.

Select the Player node to toggle ability unlocks and adjust movement and dash settings. PingEmitter exposes minimum and maximum ping range, hold duration, cooldown, and color.
