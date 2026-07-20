# quake3-vr-mod-template

The Trinity VR API integrated into the stock ioquake3 mod source (baseq3 and
missionpack). Start a VR-aware Quake III mod from it, or read it beside the
guide.

- [docs/VR_INTEGRATION.md](docs/VR_INTEGRATION.md): the integration guide,
  step by step.
- [docs/VR_PROTOCOL.md](docs/VR_PROTOCOL.md): how VR head tracking is
  networked.

## Branches

- **`main`**: the stock base, with the QVM toolchain and pak build and no VR.
- **`v1.0`** (this branch): the Trinity VR API 1.0 integration, one guide step
  per commit. Fork it for a VR-aware mod.
- Later API versions get sibling branches (`v1.1`, ...), frozen once
  published; `git diff v1.0..v1.1` is the migration.

## The steps are the history

Each commit after `main` is one guide step: the drop (Step 1), the host
contract (Appendix E), the build (Step 2), then the server (Step 4), client
(Step 5) and UI (Step 6) call-outs and the settings screens (Step 7). Step 3
is reading only. Step 6 also adds the retail Team Arena menus the template
ships, and Step 7 their VR entries. The last commit adds the docs.

```
git log --reverse --oneline main..    # the steps, in guide order
git log --reverse -p main..           # the steps, as diffs
git diff main..HEAD                   # the whole integration
```

## Building

```
git submodule update --init      # the q3lcc / q3asm toolchain
make                             # builds the tools, then both paks
```

Outputs: `dist/zzz-vrtemplate.pk3` and `dist/zzz-vrtemplate-mp.pk3`. Needs
gcc, GNU make and 7-Zip: `build-essential` and `p7zip-full` on Ubuntu, or Git
Bash with `gcc`, `make` and `7z` on PATH on Windows.

## Running it

Put the paks in `baseq3/` and `missionpack/`. They sort after Trinity's
`pak8t.pk3` and `pak3t.pk3`, so their QVMs replace Trinity's.

- **In VR** on a Trinity engine, the QVMs register the VR API. Check with
  `vr_status`: it lists paks whose QVMs the engine replaced with its native
  modules, and the template's paks must not appear.
- **On a flatscreen engine** (stock ioquake3 included) every VR hook idles,
  and the mod must behave exactly stock, apart from the two exceptions the
  guide names.

The paks carry only the art a mod ships (guide, Appendix C): the zoom scope
mask and the HUD sprite shader. The Trinity pak in the base game supplies the
VR keyboard art, the 64 px character sheet and the button glyphs. The Team
Arena pak also carries retail's menus with the VR entries, `ui/menus.txt` and
`ui/menudef.h`, because Trinity's pak replaces retail's menus with ones that
call Trinity's own UI scripts.

## Updating the drop

```
./sync-vr-drop.sh <path-to-trinity-checkout>
```

Its file list is the drop manifest. It never touches
`code/cgame/vr_host_config.h`, and it fails when Trinity has a `vr_*` file the
list doesn't know. Trinity's CI runs it against this branch on every change,
so a Trinity-only dependency in a drop file fails the change that added it.

## Provenance

Stock sources from ioquake3 @ `67e4fa978530ae0a3f62fedb0a26ac4797443429`,
without the GameSpy-era files (see the root commit). One change:
`code/qcommon/q_math.c` defines the QVM vector math out of line for this
tree's q3asm (see its header comment). Licensed GPLv2; see `COPYING.txt`.
