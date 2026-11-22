# DEVLOG — Echo (Francisco's working copy)

## Repository layout

- `ECHO/` — Godot 4.6.2 project (`ECHO/project.godot`). The colleague's original code is preserved unmodified in the `Baseline` commit.
- `docs/` — design notes, audit, roadmap and the original prompt.
- `reference/` — course PDFs and assignments A2–A7 (local only, git-ignored, ~135 MB).
- The colleague's folder (`Downloads/echo`) is **never modified**; only its Godot executable is used to run the game and tests.
- Local git only, no remote.

**How to play:** desktop shortcut **ECHO - Jogar** (or `Jogar_Echo.bat`). **Editor:** **ECHO - Abrir Editor**.

---

## 2026-11-22 (2) — Full game loop: Clareira → 3 sense areas → C/M/Y → K → ending

Direction from Francisco after playing the first slice:
- No recruit/absorb. The interesting part of empathy is *how* you interact with each blob and figure out what it needs.
- Chords unlock by **helping 5 blobs of the same note** (e.g. 5× Dó → Dó maior). Never required.
- Groups that must be hit by one wave are **the same colour** (one ping, not three fast ones).
- No 8th note (C4). Seven notes: Dó…Si.
- A bigger world: the Clareira as a tutorial with K as guide → open world with 3 large themed areas (senses), any order, free to come and go → vassals C, M, Y restore colour (CMYK) → K's final challenge → K revealed as the elder, comments on your journey → end.
- Areas: not rectangles; maze-like elements, big alcoves, obstacles, curves, irregular shapes, but **not** a dead-end maze.
- Title screen with options (rebindable keys), a TEST skip button. Timers/counts visible for blobs like shy/stimulated; some puzzles left for the player to work out.

### What exists now
**Flow:** title screen → Clareira (K teaches ping, colours = notes, wrong-note answer, shy, same-wave pair, stimulated; the hidden one is NOT explained) → membrane opens → Encruzilhada (hub) → three areas, any order.

**World geometry** (`scripts/world/world_geometry.gd`, data in `world_layout.gd`): rooms are organic blobs, corridors are curved; everything is merged into one walkable shape and rocks/curved ridges are cut out of it. Loops between rooms (no single-path mazes), alcoves, bulges. One set of non-intersecting outlines drives collision, Ping blocking, the fog of war and the PCG checks. The layout is plain data, easy to edit.

**Areas (each gets easier the more blobs you help there):**
| Area | Sense | Theme mechanic | Eases with progress | Vassal |
|---|---|---|---|---|
| Grutas da Vista (west) | sight | nearly pitch dark; many hidden blobs; ping is your eyes | vision radius grows; every helped blob becomes a light | **Y**: hides when you get close; its light broke into 3 hidden sparks; with its light back it wants Mi (yellow) |
| Vale dos Ecos (north) | hearing | all blobs are **grey**: you must recognise their note by ear; melodies to answer | they sing more often; later they **vibrate when your selected note matches** | **C**: lost its voice, hums a broken 3-note song; 3 echo stones ring their note when pinged (listening references); answer the song note by note, no timer |
| Bosque do Toque (east) | touch | gentle (soft pings only), cautious (flee if you rush; Shift = walk slowly), warmth (stay close), push home with your body | more tolerant (speed, charge, warmth time) | **M**: curled in thorns; rushing/strong pings raise tension until it rolls away; approach slowly, stay close until warm, then a soft ping |

Freeing C, M, Y restores that ink to the environment (CMYK grading pass that only affects the environment; creatures keep their colours because they carry gameplay information). After all three, the sanctum in the hub opens: **K's finale** = (1) darkness: find K's 4 hidden fragments (shy, stimulated, 2-hit, gentle; Dó/Mi/Sol/Lá, so Dó maior helps), (2) answer K's song, (3) one wave for a violet trio around pillars, (4) 6 s of silence. K grows, all colour returns, K speaks as the elder with lines built from your stats (start area, wrong notes, patience, chords), ending card.

**Blob temperaments** (`echo_blob.gd`): NOTE (n hits, pips), SHY (silence ring + seconds), STIMULATED (n hits within a window: pips + countdown), GENTLE, CAUTIOUS, WARMTH (fill ring), MELODY (pips), PUSH (nest drawn). Flags: hidden, grey, singer. Groups (`echo_blob_group.gd`): SAME_WAVE (same colour) and CLUSTER (different colours, any order, no time limit; a chord does it in one ping).

**PCG** (`encounter_generator.gd`), following our A7: designer patterns per area → the computer picks a pattern per site, varies notes/positions/rocks/timings, **evaluates** (reachable; solvable with single notes; stimulated windows always feasible with the ping cooldown; same-wave: a solution spot must exist *and* the rock must matter, i.e. ≤60% of nearby spots work; no repetition: max 3 per pattern, no back-to-back repeats; note balancing so every note has ≥5 creatures and every chord is reachable). Player influence: areas are generated on **first visit**, and chords the player owns make clusters of those notes more likely. Specs are saved, so a world stays the same on Continue.

**UI:** title screen (Continuar / Novo jogo / Opções / Sair, plus TEST: skip Clareira, original arena), options (volume, fullscreen, note names, **key rebinding** for every action), pause (Esc), non-blocking dialogue (Enter skips), HUD (note strip with per-note chord progress x/5, region, area progress, colours restored). Save/continue (`user://save.json`).

**Test-only keys** (only after the TEST button): F10 = help every creature in the current area, F11 = travel hub → caves → valley → forest.

### Changes to the colleague's code (small, backwards compatible)
- `player_controller.gd`: uses the rebindable input actions when they exist (falls back to the original hard-coded keys), slow walk (Shift), `controls_enabled`.
- `ping_emitter.gd`: input actions with fallback, `tone_count` (the world uses 7, the arena keeps 8 incl. key 8), `input_enabled`; chords from the previous iteration.
- `project.godot`: **main scene is now the title screen**, autoload `Game`. The arena is still reachable from the title screen (TEST) and runs unchanged.

### Tests (real, Godot 4.6.2)
- `tests/world_tests.tscn` (`--headless --fixed-fps 60 --path ECHO res://tests/world_tests.tscn`): **124 checks, 0 failures, ~58 s.** Geometry is one connected space, all markers/sites walkable; PCG on 5 seeds (12–17 blobs per area, every note ≥5); then a **full scripted playthrough with real pings and simulated input**: Clareira, every generated encounter of all 3 areas, Y/C/M, all 4 K stages, ending. A full playthrough unlocks all 7 chords.
- `tests/ui_smoke.tscn`: title → options → rebind → reset → TEST skip → pause/unpause.
- `tests/capture_world.tscn` (windowed): screenshots of every region + FPS: **98–155 fps**, 0.5–7 ms physics per frame on this laptop.
- The arena and `main.tscn` still start without errors.
- **Not yet tested by a human player**: readability of each temperament, difficulty, sound volumes/mix, fun.

### Open decisions / ideas for the group
1. Note→colour mapping (ROYGBIV from Dó) and which vassal belongs to which area (Y=sight, C=hearing, M=touch).
2. Diatonic chords (Ré menor, Si diminuto…) vs. always major.
3. K's backstory (currently: "when we stopped listening to each other I closed myself off and the colours left with me", ambiguous on purpose).
4. Colour-blind mode (planned; note names toggle exists, N).
5. Sounds are synthesised placeholders; a real sound pass (GD4) would help the hearing area a lot.
6. Tuning after playtests (GD10/GD11): fog darkness, timers, tolerances, number of blobs per area.

---

## 2026-11-22 (1) — First vertical slice "Clareira" (superseded)
First playable slice: note colours, shy / pair / trio / hidden blobs, Dó maior after 2 encounters, recruit/absorb placeholder. Replaced by the iteration above after Francisco's feedback (trio of different colours felt unsatisfying; recruit/absorb removed; chords per 5 blobs of a note).
