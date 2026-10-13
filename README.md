# TURBOGRASS

A grass sway shader that will tickle you in the ways you never knew you wanted. OpenMW. Works with any groundcover. The sway strength and behaviour changes with weather, supports both Wareya and Rafael PBR.

**Requires OpenMW 0.51.** This is a core shader mod: it replaces one of the engine's own shader files, and those change between OpenMW versions. This specific shader file probably does not change often, so might work in later versions as well.

<p><a href="https://ko-fi.com/maxyari"><img src="img/morrowind_kofi_banner_left_half_bright124.gif" width="25.72%" align="top" alt="Support me on Ko-fi"></a><a href="https://ko-fi.com/maxyari"><img src="img/banner_right.png" width="73.88%" align="top" alt="Support me on Ko-fi"></a><br><a href="https://ko-fi.com/maxyari"><img src="img/banner_glow.png" width="99.6%" align="top" alt=""></a></p>

## Requirements

- OpenMW 0.51 (release).
- A grass (groundcover) mod properly installed, works with any groundcover mod.

## Which archive to use

- **TURBOGRASS-1.0** if you use OpenMW's standard shaders (i.e. you did not install any PBR shaders).
- **TURBOGRASS-1.0-Wareya-PBR** if you use [Wareya's PBR shaders](https://github.com/wareya/OpenMW-PBR) for OpenMW 0.51.
- **TURBOGRASS-1.0-Rafael-PBR** if you use Rafael's Enhanced PBR Lighting 2.3 (the "OpenMW 0.51" folder), from [Rafael's Shader Pack](https://www.nexusmods.com/morrowind/mods/53667).

## Installation

If you use PBR shaders - Install the PBR shaders first, then the matching TURBOGRASS archive over them.

1. Find the `resources/shaders` folder of your OpenMW installation.
2. Make a backup of that `shaders` folder by COPYING it (NOT by renaming it). Trust me, actually do it and save it somewhere, core shaders are prone to breaking from modding.
3. Copy the `shaders` folder from this archive over it. Only `shaders/compatibility/groundcover.vert` is replaced.

Do not install this over another core shader mod that changes `groundcover.vert` (other than Wareya's or Rafael's PBR, which have their own archives). It will not work. Or it might, if you are lucky, I mean honestly install whatever onto whatever, we live only once, see the game burst in flames, go outside, touch grass, enjoy life!

Updating OpenMW replaces its shaders, which undoes TURBOGRASS. Reinstall it after updating (assuming TURBOGRASS supports that OpenMW version from the future, probably it does, but who knows).

## Uninstallation

Copy `shaders/compatibility/groundcover.vert` back from your backup.

## Credits and license

TURBOGRASS by me (Max Yari), the overall idea of how this should be implemented is mine, actual implementation is by Claude Code. Took me 3 hours to make this mod, half of which I spent making a video, Nexus art assets and this very page. Crazy, I know.

It is built on the groundcover shader from OpenMW 0.51.0. The PBR variants are built on [Wareya's PBR shaders](https://github.com/wareya/OpenMW-PBR) for OpenMW 0.51 and on Rafael's Enhanced PBR Lighting 2.3 from [Rafael's Shader Pack](https://www.nexusmods.com/morrowind/mods/53667).

Licensed under the GNU GPL v3, like OpenMW and both PBR shader packs. See LICENSE and AUTHORS.md for more information. AUTHORS.md contains a list of contributors to OpenMW, only some of whom have contributed to the shader code that TURBOGRASS is based on.
