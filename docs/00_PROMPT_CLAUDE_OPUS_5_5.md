# FIRST MESSAGE TO CLAUDE OPUS 5.5 / CLAUDE CODE

You are helping me develop **ECHO**, our university group game, in **Godot 4.6.2** with GDScript. I want a practical coding collaborator, not an autonomous agent that redesigns the whole game without asking.

**Please respond to me in European Portuguese (PT-PT).** You may use English for code, identifiers, comments, and technical file names. Explain what changed in plain language and tell me how I can run/test it in Godot. I care more about an enjoyable, coherent game and preserving the existing work than about producing a huge quantity of code.

## Project and source of truth
You have access to a prepared folder containing:
- `01_Godot_Project/ECHO/project.godot` and the original Godot project, including scripts and scenes.
- `02_Current_Design/ECHO_CANONICAL_DESIGN_2026-11-22.md`: the most recent design instructions and open decisions.
- `02_Current_Design/CODEBASE_AUDIT.md`: preliminary STATIC code inspection. Recheck it yourself and do not treat it as a runtime test.
- `02_Current_Design/IMPLEMENTATION_ROADMAP.md`: staged plan.
- `03_Student_Assignments`: submitted A2-A7 PDFs. Several are historical and contain outdated minigame mechanics.
- `04_Course_Slides`, `05_Historical_Group_Materials`, and `06_Theory_Papers`: theory and brainstorming.

Please prioritize **my current requirements and the actual code** over older documents. The brainstorming document contains conflicting ideas over time; its final sections after the midterm presentation are newer. Do not silently resurrect abandoned designs.

## Core concept
ECHO is a **2D top-down exploration game about empathy**, featuring a living blob in a mysterious, desaturated, organic world. Our strongest mechanic is **Ping as communication**, not external minigames. We decided to move away from memory/arcade minigames after feedback from our professors because they made the game feel like a minigame collection, disconnected from empathy.

The player explores the world, observes how other blobs behave, listens to their signals, and changes how they communicate to understand and help them. Sound, color and interaction should be deeply connected to gameplay. It is not just about identifying the correct color/note: each blob should also have a distinct response, context or need (timing, silence, simultaneous waves, distance, obstacles, etc.).

**Ping is unlocked from the beginning** and individual notes C, D, E, F, G, A, B are available from the start. Current code also includes upper C (8 selections, C3-C4). The exact final note-color mapping is not yet confirmed. Later, notes may receive **chord upgrades**; for example, C major contains C E G and could affect blobs tuned to any of those notes at once. Chords make the journey easier but **must never be mandatory to solve an encounter**. The world is intended to be broadly open and explorable in different orders.

There are six existing prototype interactions to preserve or iterate on: frightened blob (gentle pings), sound connection (one wave touches both), echolocation (reveal hidden blob), frequency matching, group resonance, and silence. The current project README explains these and the controls. Major blobs C/M/Y and K (elder/final figure) belong to the narrative, but their precise gameplay and ending are NOT fully finalized.

After genuinely helping a blob, we are considering a recruit versus absorb decision, with different benefits and nuanced moral implications. Recruiting might offer companions/technical assistance, absorbing might increase physical size, field of view or other physical abilities. We do not want the UI to announce that one choice is automatically good or evil. Karma and endings are discussion points, not finished specifications.

Procedural generation of encounter setups is an A7 proposal, not something that already exists in this Godot source and **not the first implementation priority**. First make hand-designed encounters work organically in a unified world.

## What already exists
`project.godot` launches `res://scenes/interaction_test_arena.tscn`: a six-zone mechanics lab with a debug HUD, note selection, pings, dash and reset/teleport controls. `scenes/main.tscn` is an older small test of Ping/field of view. We want to BUILD ON this project and preserve its working features, not replace it from scratch.

## Rules for working together
1. **Do not touch the original group copy or shared remote repositories.** You are working in an independent folder, and I will only merge back agreed changes.
2. At the start, read the actual Godot files and make a concise inventory of what is implemented, missing, fragile or outdated. Verify engine/version and editor startup.
3. Before coding, create a local backup or request that I initialize a local Git repository with an initial commit. Do not push any changes without explicit permission.
4. Show a short proposed first iteration: files to change, how the feature works, how to test success, and any assumptions requiring my input. Then **implement one small vertical slice** if the current tooling permits, rather than writing a gigantic master plan or immediately building the full game.
5. Prefer small, easily reviewed changes. Do not rewrite the Ping system, scene tree or procedural visuals unless needed. Preserve original scenes and interaction lab as regression tests.
6. Godot's own imported cache `.godot/` may be regenerated locally; do not add it to version control. Use Godot 4.6 APIs and type-aware GDScript.
7. When making changes, provide a diff/summary and explicit steps to test in Godot. Run headless/editor checks where available; if you cannot launch Godot, say so rather than claiming tests passed.
8. Check that any new interaction is accessible without requiring a chord upgrade, avoids softlocks, and includes meaningful visual/audio feedback. Consider players with color vision differences or who cannot rely on audio alone.
9. Clearly mark temporary prototypes versus confirmed group decisions. Ask before committing irreversible narrative/ethical mechanics, deleting colleague code, altering project-wide defaults or introducing external dependencies.
10. Keep a running `DEVLOG.md` documenting changes and tests. Prioritize readable maintainable code.

## Requested first technical task
Please start by inspecting the Godot project and reporting:
- the current scenes, scripts, input controls and how the six-zone test arena works;
- which pieces of our desired game already exist and which do not;
- any immediate problems preventing us from testing or extending the project.

Then propose and begin the **smallest integrated playable area**, preferably using existing Ping and blob classes, in which the player explores with limited visibility, discovers a blob, understands a behavioural need, and frees it using Ping (NOT a disconnected minigame). If straightforward, include a second complementary blob interaction and an *optional placeholder* for the recruit/absorb outcome. Do not expand into PCG or the entire world yet.

For the first implementation, aim for a clearly testable slice, with a scene that can be run separately and without breaking the existing `interaction_test_arena.tscn`. Before implementing uncertain decisions (note-color map, chords, moral effects, major boss outcomes), list them as open design questions and continue with reversible defaults.

If any of these requirements conflict with the code or documents, point out the discrepancy and propose a minimally disruptive resolution. Do not treat old course assignment text as a higher-priority specification than these instructions.
