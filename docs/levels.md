# Making levels

A level is a scene in `res://levels/` that adds walls inside the arena. Players pick it
with **Arena** in player setup's *Match settings* (or the online lobby); every `.tscn` in
that folder shows up there by its file name (files starting with `_` are skipped).

## Quick start

1. **Scene > New Scene**, root node: **Other Node > Level** (`scripts/levels/level.gd`).
   The editor draws the play area (purple frame), the scoreboard strip that isn't
   playable, and the four usual starting spots.
2. Add a **LevelWall** child (it's a `Polygon2D`). With it selected, use the point tools in
   the 2D toolbar to draw its outline. Set its **Color** for the fill; the outline color and
   width are in the inspector.
3. Optional movement, in the inspector:
   - **Move Offset** / **Move Time**: slides that far and back, easing at both ends, once
     every *Move Time* seconds. **Phase** (0..1) puts walls out of step.
   - **Rotation Speed**: degrees per second around the wall's own origin (the node's
     position), negative for counter-clockwise. Put the origin where the pivot should be.
   The editor shows a faint copy where the slide ends and an arc for the spin.
4. Optional starting spots: **Marker2D** children named `Spawn1`..`Spawn4` (Fire, Earth,
   Air, Water). Their rotation is the heading (0 = facing up). Without them the usual
   corners are used, and a snake whose corner lands on a wall gets a random spot.
   With *Spawns: Random* the markers are ignored and snakes start away from the walls.
   Except at markers, a snake's heading is turned until the way ahead is clear of walls
   (moving walls included, as they'll be during the countdown), and snakes start at least
   `SPAWN_MIN_DISTANCE` apart. These rules are constants at the top of the spawn section
   of `scripts/Playground.gd` (`SPAWN_*`).
5. Save it in `res://levels/` and press **F6** (Run Current Scene) to playtest: you play
   Fire with its usual keys against three AIs on your level.

## How walls behave

Walls are deadly like the outer border: snakes crash on them, fireballs stop on them and
Earth's armor doesn't get through (except with the Burrower upgrade). The AI sees them with its raycasts, and Air's AI won't
teleport onto them. Moving walls follow a clock shared by every machine online, so they
are in the same place for everyone.

Examples: `levels/pillars.tscn` (static), `levels/windmill.tscn` (spinning cross, two
sliders and spawn markers).
