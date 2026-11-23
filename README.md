# ECHO — cada voz é uma cor

A 2D top-down game about **empathy**, made in **Godot 4.6**. You are a small blob in a world that lost its colour. Every note is a colour: by listening to each creature and answering with the right note — and the right *way* (silence for the shy ones, patience for the cold ones, calm for the nervous ones…) — you help them, and the world slowly gets its colour back.

University group project (Game Design). Prototype.

## Play (Windows)

1. Go to **[Releases](../../releases/latest)** and download **`Echo-windows.zip`**.
2. Extract it and run **`Echo.exe`**.
   (Windows may warn about an unknown publisher: *More info → Run anyway*.)

**Controls** (rebindable in *Opções*): WASD/arrows move · **Shift** walk slowly · **Space** dash (hold/release) · **E** ping (hold longer = further) · **1–7** / mouse wheel choose a note · **Q** chord (once unlocked) · **Enter** dialogue · **Esc** pause.

The *TESTE* buttons on the title screen and the **F8** debug panel are testing tools of the prototype.

## What's in the game

- **Clareira** — a guided tutorial with a mysterious voice.
- **Nascente** — the hub, and three areas you can visit in any order, each built around a sense:
  - **Vale dos Ecos** (west, hearing) — colourless blobs you recognise by ear.
  - **Bosque do Toque** (north, touch) — delicate, nervous, cold blobs; slowness and closeness.
  - **Grutas da Vista** (east, sight) — near darkness; your ping is your eyes.
- Each area has a **vassal** (C, M, Y) with a hand-made themed challenge; it wakes after you help a few of the area's blobs, and freeing it returns that ink to the world (CMYK). Help every blob of an area and its colour gets even stronger.
- Then K's last challenge and the ending: the more blobs you helped along the way, the bigger the colour explosion. You can keep exploring afterwards.
- Blob encounters in the three areas are **procedurally generated** on first visit from designed patterns, and validated (always solvable with single notes, feasible timings, no repetition). Advanced challenges and vassals are hand-designed.

## Develop

- Install **Godot 4.6.2** and open `ECHO/project.godot` (F5 runs the title screen).
- Code: `ECHO/scripts/` — `core/` (settings, input, save), `world/` (geometry, layout data, PCG, fog, colour, K's guidance), `echo/` (blobs, groups, vassals), `ui/`.
- Tests (full scripted playthrough with real pings, ~1 min):
  `Godot_v4.6.2-stable_win64_console.exe --headless --fixed-fps 60 --path ECHO res://tests/world_tests.tscn`
- Design notes and history: [`DEVLOG.md`](DEVLOG.md), [`docs/`](docs/).

The original movement / ping / blob-visual prototype by the group is preserved in the first commits and still runs as `ECHO/scenes/interaction_test_arena.tscn`.
