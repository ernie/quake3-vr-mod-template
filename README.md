# quake3-vr-mod-template

A reference integration of the [Trinity VR API](https://github.com/ernie/trinity/blob/main/docs/VR_INTEGRATION.md)
into the stock ioquake3 mod source — baseq3 and missionpack (Team Arena)
both. Use it as a GitHub template to start a VR-aware Quake III mod, or
read it as the worked example beside the integration guide.

## Branches

- **`main`** is the base: the stock ioquake3 mod source plus the QVM
  toolchain and pak build — no VR anywhere. Diff your own tree against it,
  or start a flatscreen mod from it.
- **`v1.0`** (this branch) is the Trinity VR API 1.0 integration, built
  on `main` one guide step per commit — the branch to fork for a
  VR-aware mod.
- Future API versions land as sibling branches (`v1.1`, …), each frozen
  once published; `git diff v1.0..v1.1` is the migration between them.

## The walkthrough is the history

On a version branch, each step commit after the base mirrors one step of
`docs/VR_INTEGRATION.md` in the trinity repo: the vendored drop copy
(Step 1), the host contract (Appendix E), the build wiring (Step 2; the
guide's Step 3 is reading only), then the server (Step 4), client
(Step 5), and UI (Step 6) call-outs, and the settings screens (Step 7).
Step 6 also brings in the retail Team Arena menus the template ships
(see Running it), and Step 7 adds their VR entries. The commit after
Step 7 adds this README.

```
git log --reverse --oneline main..    # the steps, in guide order
git log --reverse -p main..           # the walkthrough, as diffs
git diff main..HEAD                   # the complete integration patch
```

## Building

```
git submodule update --init      # the q3lcc / q3asm toolchain
make                             # builds the tools, then both paks
```

Outputs: `dist/zzz-vrtemplate.pk3` and `dist/zzz-vrtemplate-mp.pk3`. The
chain runs anywhere gcc, GNU make and 7-Zip exist — CI proves it on stock
Ubuntu with nothing beyond `build-essential` and `p7zip-full`, and on
Windows it runs from Git Bash with `gcc`, GNU make and `7z` on PATH. Note
that `zzz-vrtemplate*.pk3` sorts after the Trinity mod's `pak8t.pk3` /
`pak3t.pk3`, so if both are installed the template QVMs override Trinity's.

## Running it

The pk3s go in `baseq3/` (and `missionpack/` for the `-mp` pak). A Trinity
engine in VR (trinity-engine with VR on, or a trinity-standalone release)
wakes the drop up: the QVMs register the VR API and come alive. Verify
with `vr_status`: it reports the VR state and lists any pak whose QVMs the
engine replaced with its bundled native modules, so the template's paks
must not appear there.
Running under stock ioquake3 (or any flatscreen engine) is the dormancy
test: every VR hook idles and the mod must behave exactly stock there.

The paks carry only the art the guide's Appendix C has a mod ship: the
zoom scope mask and the HUD sprite shader, in the baseq3 pak. The
Trinity pak in the base game (`pak8t.pk3`, `pak3t.pk3` for Team Arena)
supplies the rest: the VR keyboard's font and key art, the 64 px console
character sheet and the VR button glyph atlas. The Team Arena pak also
carries its own menus: retail's, with the VR entries, plus
`ui/menus.txt` and `ui/menudef.h`, because the Trinity pak replaces
retail's menus with ones that call Trinity's own UI scripts. In VR the
keyboard opens on text fields in both UIs.

## Updating the vendored drop

```
./sync-vr-drop.sh <path-to-trinity-checkout>
```

The script's file list IS the drop manifest. It never touches
`code/cgame/vr_host_config.h` (the one host-owned file in the drop), and
it fails loudly if trinity grows a `vr_*` file the manifest does not know.
Trinity's CI runs this same script as a canary: every trinity change is
rebuilt against this stock tree, so a Trinity-substrate dependency leaking
into a vendored file fails the PR that introduced it.

## Provenance

Stock sources imported from ioquake3 @ `67e4fa978530ae0a3f62fedb0a26ac4797443429`
(dead GameSpy-era files excluded; see the root commit message), with one
documented adjustment: `code/qcommon/q_math.c` defines the QVM vector math
out of line for this tree's q3asm — see the file's header comment. Licensed
GPLv2 — see `COPYING.txt`.
