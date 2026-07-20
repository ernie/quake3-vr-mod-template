#!/usr/bin/env bash
# Syncs the vendored VR drop from a trinity checkout into this tree.
# The file list below IS the drop: a vr_* file added to trinity that is
# not listed here makes this script fail, on purpose - update the list
# (and the guide's Step 1) together.
#
# --check writes nothing: it compares every manifest file by content,
# prints a per-file drift report, and exits 1 on any drift.
set -euo pipefail

CHECK=0
if [ "${1:-}" = "--check" ]; then
  CHECK=1
  shift
fi

TRINITY="${1:?usage: ./sync-vr-drop.sh [--check] <path-to-trinity-checkout>}"

# The vendored drop (never edited here). vr_host_config.h is deliberately
# ABSENT: it is the one host-owned file in the drop - this tree keeps its
# own copy and a sync must never overwrite it.
DROP="
code/cgame/vr_cgame.c
code/cgame/vr_cgame.h
code/cgame/vr_host.h
code/game/vr_bg.c
code/game/vr_bg.h
code/game/vr_game.c
code/game/vr_game.h
code/game/vr_platform.c
code/game/vr_platform.h
code/game/vr_safe_types.h
code/game/vr_shared.h
code/game/vr_trap.h
code/q3_ui/vr_ui.c
code/q3_ui/vr_ui.h
code/ui/vr_ui.c
code/ui/vr_ui.h
code/ui/vr_uishared.c
code/ui/vr_uishared.h
"

# Step 1 companions: the VR settings screens and their assets.
COMPANIONS="
code/q3_ui/ui_vroptions.c
code/q3_ui/ui_vrcomfort.c
code/q3_ui/ui_vrcontrols.c
code/q3_ui/ui_vrhud_display.c
code/q3_ui/ui_vrmirror.c
assets-baseq3/gfx/weapon/scope.tga
assets-baseq3/scripts/vr.shader
assets-missionpack/ui/vroptions_pc.menu
assets-missionpack/ui/vroptions_standalone.menu
assets-missionpack/ui/ingame_vroptions_pc.menu
assets-missionpack/ui/ingame_vroptions_standalone.menu
assets-missionpack/ui/vrmenus_pc.txt
assets-missionpack/ui/vrmenus_standalone.txt
"

# Pre-flight: every manifest file must exist in trinity before anything
# is written - a partial sync is worse than a failed one.
missing=0
for f in $DROP $COMPANIONS; do
  if [ ! -f "$TRINITY/$f" ]; then
    echo "sync-vr-drop: missing in trinity: $f" >&2
    missing=1
  fi
done
[ "$missing" -eq 0 ] || exit 1

# Drift guard: every TRACKED code/**/vr_* file in trinity must be
# accounted for - either in DROP or as the host-owned config we
# intentionally skip. Tracked means git ls-files, not find: untracked
# scratch files must not trip the guard, a newly committed vr_* file
# must.
expected="$(printf '%s\n' $DROP code/cgame/vr_host_config.h | sort)"
actual="$(git -C "$TRINITY" ls-files -- 'code/' | grep '/vr_[^/]*$' | sort || true)"
if [ "$expected" != "$actual" ]; then
  echo "sync-vr-drop: trinity's vr_* file set diverged from the manifest:" >&2
  diff <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") >&2 || true
  exit 1
fi

# Companion guard: a VR settings screen or vroptions/vrmenus asset that
# trinity tracks but COMPANIONS does not list fails the sync, same as
# the drop manifest.
known="$(printf '%s\n' $COMPANIONS | sort)"
tracked="$(git -C "$TRINITY" ls-files -- 'code/q3_ui/ui_vr*' 'assets-*vroptions*' 'assets-*vrmenus*' | sort || true)"
unknown="$(comm -13 <(printf '%s\n' "$known") <(printf '%s\n' "$tracked"))"
if [ -n "$unknown" ]; then
  echo "sync-vr-drop: trinity tracks companion files the manifest does not know:" >&2
  printf '%s\n' "$unknown" >&2
  exit 1
fi

if [ "$CHECK" -eq 1 ]; then
  total=0
  drifted=0
  for f in $DROP $COMPANIONS; do
    total=$((total + 1))
    if ! cmp -s "$TRINITY/$f" "$f"; then
      echo "sync-vr-drop: drift: $f"
      drifted=$((drifted + 1))
    fi
  done
  if [ "$drifted" -gt 0 ]; then
    echo "sync-vr-drop: $drifted of $total files drifted from $TRINITY" >&2
    exit 1
  fi
  echo "sync-vr-drop: all $total files match $TRINITY"
  exit 0
fi

for f in $DROP $COMPANIONS; do
  mkdir -p "$(dirname "$f")"
  cp "$TRINITY/$f" "$f"
done

echo "sync-vr-drop: $(printf '%s\n' $DROP $COMPANIONS | grep -c .) files synced from $TRINITY"
