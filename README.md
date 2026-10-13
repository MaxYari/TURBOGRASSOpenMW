# TURBOGRASS

Grass that moves like it's actually in the wind, for OpenMW 0.51.

TURBOGRASS replaces OpenMW's grass (groundcover) sway. Instead of wobbling in place, grass leans downwind and bends with real curvature. Gust fronts roll across whole fields, and blades flutter. It all follows the weather: a gentle sway with the odd gust on a clear day, constant motion in rain, wild grass in a thunderstorm and chaos in a blight storm.

**Requires OpenMW 0.51.** This is a core shader mod: it replaces one of the engine's own shader files, and those change between OpenMW versions.

<p><a href="https://ko-fi.com/maxyari">Support me on Ko-fi</a></p>

## What it does

- **Real bending.** Blades curve over and keep their length, with the tips dropping as they bend, instead of skewing sideways.
- **Gusts.** Wide gust fronts sweep across the land in the wind direction. Grass leans into a gust quickly, holds while it lasts, and eases back up slowly.
- **Flutter.** A fine, quick shiver of the blades. Its speed drifts slowly across the land, and gusts make it faster.
- **Weather.** Everything scales with each weather's wind:
  - Clear weather has a light lean, a gentle sway and occasional gusts.
  - Rain keeps the grass moving.
  - In a thunderstorm the grass stays leaning and gusts come constantly.
  - Ash and blight storms whip it around without letting it stand up.
- **Light.** Grass shading follows the bend, so gust fronts show up as moving light and shade across the fields.
- **Stomping.** OpenMW's grass stomping settings still work, and grass now bends away from you.

The wind blows the same way the water's waves move.

## Requirements

- OpenMW 0.51 (release).
- A grass mod, for example Remiros' Groundcover or Aesthesia Groundcover, with groundcover enabled in OpenMW.

## Which archive to use

- **TURBOGRASS-1.0** if you use OpenMW's own shaders.
- **TURBOGRASS-1.0-Wareya-PBR** if you use [Wareya's PBR shaders](https://github.com/wareya/OpenMW-PBR) for OpenMW 0.51. Those change the grass shaders too, so the regular archive would break grass with them. Install Wareya's shaders first, then this archive over them.

## Installation

Don't install this unless you know what you're doing.

1. Find the `resources/shaders` folder of your OpenMW installation.
2. Make a backup of that `shaders` folder by COPYING it (NOT by renaming it).
3. Copy the `shaders` folder from this archive over it. Only `shaders/compatibility/groundcover.vert` is replaced.

Do not install this over another core shader mod that changes `groundcover.vert` (other than Wareya's PBR, which has its own archive). It will not work.

Updating OpenMW replaces its shaders, which undoes TURBOGRASS. Reinstall it after updating, but only if this version of TURBOGRASS supports the new OpenMW version.

## Uninstallation

Copy `shaders/compatibility/groundcover.vert` back from your backup.

## Tuning

All the settings are `WIND_*` defines near the top of `shaders/compatibility/groundcover.vert`, each with a comment. The ones you're most likely to want:

| Define | What it does |
| --- | --- |
| `WIND_DIRECTION` | Where the wind blows to |
| `WIND_LEAN_CALM`, `WIND_LEAN_FULL` | Steady lean, from windless weather to a blight storm |
| `WIND_GUST_CALM`, `WIND_GUST_FULL` | Extra lean while a gust passes |
| `WIND_GUST_START_CALM`, `WIND_GUST_START_FULL` | How often gusts come; lower means more gusts |
| `WIND_GUST_LENGTH`, `WIND_GUST_SPEED` | Size and speed of the gust fronts |
| `WIND_FLUTTER_CALM`, `WIND_FLUTTER_FULL` | Flutter strength |
| `WIND_STORM_*` | Extra wildness from rain up to a thunderstorm |
| `WIND_FURY_*` | Extra wildness from a thunderstorm up to a blight storm |

To see your changes while the game runs, open the console, type `luap`, then enter:

```
require('openmw.debug').setShaderHotReloadEnabled(true)
```

Every time you save the file after that, the shader reloads.

## Credits and license

TURBOGRASS by Max Yari.

It is built on the groundcover shader from OpenMW 0.51.0. The PBR variant is built on [Wareya's PBR shaders](https://github.com/wareya/OpenMW-PBR) for OpenMW 0.51.

Licensed under the GNU GPL v3, like OpenMW and Wareya's shaders. See LICENSE and AUTHORS.md for more information. AUTHORS.md contains a list of contributors to OpenMW, only some of whom have contributed to the shader code that TURBOGRASS is based on.
