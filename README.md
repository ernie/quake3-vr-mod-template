# quake3-vr-mod-template

The stock ioquake3 mod source (baseq3 and missionpack) with a QVM toolchain
and pak build. This branch has no VR; it's the base the VR integrations build
on.

## Branches

- **`main`** (this branch): the stock base. Diff your tree against it, or
  start a flatscreen mod from it.
- **`v1.0`**: the Trinity VR API 1.0 integration, one guide step per commit.
  Fork it for a VR-aware mod. Its guide is
  [docs/VR_INTEGRATION.md](https://github.com/ernie/quake3-vr-mod-template/blob/v1.0/docs/VR_INTEGRATION.md).
- Later API versions get sibling branches (`v1.1`, ...), frozen once
  published; `git diff v1.0..v1.1` is the migration.

## Building

```
git submodule update --init      # the q3lcc / q3asm toolchain
make                             # builds the tools, then both paks
```

Outputs: `dist/zzz-vrtemplate.pk3` and `dist/zzz-vrtemplate-mp.pk3`. Needs
gcc, GNU make and 7-Zip: `build-essential` and `p7zip-full` on Ubuntu, or Git
Bash with `gcc`, `make` and `7z` on PATH on Windows.

## Provenance

Stock sources from ioquake3 @ `67e4fa978530ae0a3f62fedb0a26ac4797443429`,
without the GameSpy-era files (see the root commit). One change:
`code/qcommon/q_math.c` defines the QVM vector math out of line for this
tree's q3asm (see its header comment). Licensed GPLv2; see `COPYING.txt`.
