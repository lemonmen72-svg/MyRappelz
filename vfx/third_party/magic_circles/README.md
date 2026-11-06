# Magic Circles 3D

Spell areas on the ground for Godot 4.3+ (Forward+, Mobile, Compatibility): shaders, meshes and
particles made in code, no textures.

**The full pack:** **[Magic Circles 3D](https://heyheythere.itch.io/magic-circles-3d)** has all 80: portals, auras,
floating rings of runes, strike warnings, pillars of light, spiral vortices, dome-shaped wards and
swirling mist in the same eight elements on top of these.
Same node, same code: install it over this one.

## Use

```gdscript
MagicArea.add(self, "fire_circle")                       # element_kind, playing
var ward := MagicArea.add(self, "holy_dome", {position = Vector3(2, 0, 0), radius = 2.0})
MagicArea.add(self, "frost_pillar", {one_shot = true})   # forms, holds, fades, frees itself
ward.stop(1.0)                                           # fades out, then frees itself
```

Or add a MagicArea node in the editor, where it plays as you set it up. `MagicArea.presets()`
names every installed effect and `MagicArea.kinds()` the kinds.

## Kinds and elements

Kinds: `circle` (rings, runes and a star), `ripple` (rings spreading out), `pillar` (a column of
light), `mist` (a swirling pool), `vortex` (a spiral funnel), `dome` (a ward), `aura` (tongues
licking up round a body), `portal` (a gate standing on the ground, facing the node's +Z), `runes`
(two floating rings of runes) and `telegraph` (a strike warning that fills over `appear`, its
wind-up). Elements: `fire`, `frost`, `poison`, `holy`, `shadow`, `arcane`, `nature` and `blood`,
each with its colours, its star, how much it writhes, its particles (embers, snowflakes, bubbles,
sparkles, smoke, motes, leaves, drops) and its light (shadow's takes light away).

## Settings

- `radius` (a portal's height is its diameter), `height` (the top of a pillar, vortex, mist, aura
  or the runes), `speed`, `intensity`.
- `color` and `edge_color`: picking an element sets them; change them after for any colour.
- `particles` and `light` switch those parts off.
- `transparency`: `smooth`, `dither` (the PS1's ordered dither, drawn as solid pixels) or
  `cutout`. `MagicArea.default_transparency = 1` dithers every area whose own is `default`.
- `autoplay`, `one_shot`, `appear` (seconds to form), `duration` (seconds a one-shot holds);
  `play()` starts it again from nothing, `stop(fade)` ends it, and `finished` comes as it goes.

Any other option goes to the shaders as a uniform (`set_param`), for example `energy` (over 1
blooms under an Environment with glow), `turbulence`, `sides` (the circle's star) or
`dither_size`. They are listed in `shaders/area.gdshaderinc`.
