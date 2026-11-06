# Storm & Wind 3D

Lightning and wind for Godot 4.3+ (Forward+, Mobile, Compatibility): shaders and meshes made in
code, no textures. What the wind carries moves on the GPU.

**The full pack:** **[Storm & Wind 3D](https://heyheythere.itch.io/storm-wind-3d)** has all 54: arcs that chain from
target to target, ball lightning, novas, storm clouds, dust devils, tornadoes and bursts in the
same twelve styles on top of these. Same node, same code: install it over this one.

## Use

```gdscript
StormFX.add(self, "storm_strike")                        # style_kind, playing
StormFX.add(self, "leaves_gust", {rotation = Vector3(0, PI / 2, 0)})   # blows along its -Z
var arc := StormFX.add(hand, "arcane_arc")
arc.aim([enemy.global_position, next_enemy.global_position])          # jumps one to the next
StormFX.add(self, "sand_burst", {one_shot = true})       # one burst, then frees itself
```

Or add a StormFX node in the editor, where it plays as you set it up. `StormFX.presets()` names
every installed effect and `StormFX.kinds()` the kinds.

## Kinds and styles

Lightning: `strike` (a bolt from the sky, branching, with a flash, sparks and a scorch on the
ground), `arc` (between the node and its `targets`), `orb` (ball lightning), `nova` (a ring of
lightning along the ground) and `cloud` (a storm cloud lit from inside, striking and raining). In
`storm`, `arcane`, `fire`, `toxic`, `holy` and `void` (its light takes light away).

Wind: `gust` (streaks and what they carry blowing past), `swirl` (a dust devil), `tornado` and
`burst` (thrown out from a point, a landing or a shockwave). Of `air`, `leaves`, `snow`, `sand`,
`petals` or `ash` (with embers).

## Settings

- `radius`, `height`, `speed`, `intensity`.
- `color` and `edge_color`: picking a style sets them; change them after for any colour.
- `interval`: seconds between strikes, novas, cloud strikes and bursts; 0 for only on `strike()`.
  `struck(at)` comes as each one lands.
- `particles` and `light` switch those parts off.
- `transparency`: `smooth`, `dither` (the PS1's ordered dither, drawn as solid pixels) or
  `cutout`. `StormFX.default_transparency = 1` dithers every effect whose own is `default`.
- `autoplay`, `one_shot` (one strike or burst, or a gust that holds for `duration`), `appear`
  (seconds wind takes to rise); `play()` starts it again, `stop(fade)` ends it, and `finished`
  comes as it goes.

Any other option goes to the shaders as a uniform (`set_param`), for example `energy` (over 1
blooms under an Environment with glow), `thickness`, `trail` or `dither_size`. They are listed in
`shaders/storm.gdshaderinc` and at the top of each shader.
