PK3 = zzz-vrtemplate.pk3

basedir = ../code

QADIR = $(basedir)/game
CGDIR = $(basedir)/cgame
CMDIR = $(basedir)/qcommon
UIDIR = $(basedir)/q3_ui
TAUIDIR = $(basedir)/ui

Q3ASM = ../tools/bin/q3asm -vq3 -r -m -v
# q3lcc's cpp resolves every -I dir relative to the MAIN source file's
# directory (appendDirToIncludeList prepends it), so these are written
# relative to code/<module>/. The one they exist for: code/game-resident
# sources include "q_shared.h", which lives in code/qcommon on the stock
# layout.
Q3LCC = ../../../tools/bin/q3lcc -DQ3_VM -S -Wf-g -I../qcommon -I../game
7Z = 7z u -tzip -mx=9 -mpass=8 -mfb=255 --

QA_CFLAGS = -DQAGAME
CG_CFLAGS = -DCGAME -I../cgame
UI_CFLAGS = -DQ3UI -I../q3_ui

include srcs.mk
