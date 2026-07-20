# quake3-vr-mod-template

The stock ioquake3 mod source — baseq3 and missionpack (Team Arena)
both — plus a self-contained QVM toolchain and pak build. No VR on this
branch: `main` is the base the integrations build on.

## Branches

- **`main`** (this branch): the stock base. Diff your own tree against
  it, or start a flatscreen mod from it.
- **`v1.0`**: the [Trinity VR API](https://github.com/ernie/trinity/blob/main/docs/VR_INTEGRATION.md)
  1.0 integration, built on `main` one guide step per commit — the
  branch to fork for a VR-aware mod: `git checkout v1.0`.
- Future API versions land as sibling branches (`v1.1`, …), each frozen
  once published; `git diff v1.0..v1.1` is the migration between them.

## Building

```
git submodule update --init      # the q3lcc / q3asm toolchain
make                             # builds the tools, then both paks
```

Outputs: `dist/zzz-vrtemplate.pk3` and `dist/zzz-vrtemplate-mp.pk3`. The
chain runs anywhere gcc, GNU make and 7-Zip exist — CI proves it on stock
Ubuntu with nothing beyond `build-essential` and `p7zip-full`, and on
Windows it runs from Git Bash with `gcc`, GNU make and `7z` on PATH.

## Provenance

Stock sources imported from ioquake3 @ `67e4fa978530ae0a3f62fedb0a26ac4797443429`
(dead GameSpy-era files excluded; see the root commit message), with one
documented adjustment: `code/qcommon/q_math.c` defines the QVM vector math
out of line for this tree's q3asm — see the file's header comment. Licensed
GPLv2 — see `COPYING.txt`.
