# Pune Plus ("Pune con Punchis")

Local-multiplayer (1–4 players, same keyboard) snake/"Achtung, die Kurve"-style arena game made in **Godot 4.6** (GDScript, GL Compatibility renderer, 1920x1080, fullscreen borderless). Code comments and UI strings are mixed Spanish/English.

## Engine / running

The project needs Godot **4.6** (scenes use 4.6-only `unique_id`). On this machine the 4.6.1 editor is the GodotSteam build:

```
G=/t/GodotSteam/4.6/godotsteam.461.editor.win64.console.exe
$G --headless --path . --import                                   # reimport assets / catch parse errors
$G --headless --path . --quit-after 120                           # smoke-run the main menu
$G --headless --path . res://scenes/Playground.tscn --quit-after 300  # smoke-run gameplay scene
$G --path . -e                                                    # open the editor
$G --path .                                                       # play the game (windowed run)
```

Other Godot versions in `T:\GodotStables` (4.1–4.4) are too old for this project. Expected harmless warnings: "Screen-space AA is only available…" and "Detected another project.godot at res://nuevo-proyecto-de-juego".

No test suite; verify changes by headless runs (look for `ERROR`/`SCRIPT ERROR`) and by playing.

## Layout

- `scripts/` and `scenes/` – game code (scripts live in both folders, `.tscn` scenes in `scenes/`).
- `assets/` – art, fonts, sounds; `assets/jorge-resources/` is the artist's (Jorge) UI/power art.
- `fireball sprite/` – fireball sprite sheets/frames (work in progress on `ivo_bola_de_fuego`).
- `addons/AS2P/` – editor plugin (AnimatedSprite → AnimationPlayer converter).
- `particle_import/`, `nuevo-proyecto-de-juego/` – unrelated sample/scratch projects, ignored by the game.
- `bin/` – export output (gitignored, though some files are tracked).

## Architecture

- Autoloads: `Global` (`scripts/global.gd`: active players, scores, AI flags, colors, options) and `LessonList` (quotes shown between rounds).
- Flow: `scenes/menu.tscn` (`scripts/menu.gd`) → player setup (`scripts/player_setup.gd`, toggles players/AI, key remap via `redefine_keys`) → `scenes/Playground.tscn` (`scripts/Playground.gd`).
- `Playground.gd`: spawns `player.tscn` per active player, wires `dead`/`score` signals, round restart, win at `scoreToReach` (= (players-1)*10, min 10), "simulate round" debug from pause menu (`scenes/menu_pause.gd`).
- `Player.gd` (Area2D): snake head turning left/right, leaves `snake_body.tscn` segments every 0.05 s except during periodic gaps; collision with any non-own-recent segment = death. Each player id has a fixed elemental power on its "Up" key, with cooldown:
  1. Fire – `shoot()` fires `projectile.tscn` (`scripts/projectile.gd`) which deletes trail segments it hits.
  2. Earth – `hulk()`: temporary invincibility + spawns a chain of `fissure.tscn` segments (`scenes/fissure.gd`).
  3. Air – `teleport()` jumps to `DynamicTeleportNode` (point ahead, wrapped around the arena limits).
  4. Water – `twinHead()` spawns `twin_head.tscn` (mirrored second head; if the main head dies while the twin lives, it takes over).
- AI: `scripts/raycaster.gd` steers by raycast distances; `Player.ai_punchy()` decides when AI uses its power.
- `Events.gd` spawns score mushrooms (`shroom.tscn`); `HUD.gd` shows scores and cooldown bars.
- Multiplayer (`Multiplayer*.gd`, `multiplayer_*.tscn`) is an experimental network mode, mostly unused.

## Conventions

- Keep the existing style: tabs, GDScript without static typing for most code, commented-out experiments are common.
- Input actions: `Player{1..4}{Left,Right,Up}`, `Pause`, `ui_accept`, `ui_cancel` (defined in `project.godot`).
- Branches are per feature/person (e.g. `ivo_bola_de_fuego`, `gus_instrucciones`), merged into `main` via PR.
