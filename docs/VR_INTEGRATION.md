# Trinity VR Integration Guide

How to make a stock Quake III Arena 1.32 mod (baseq3, and missionpack if you
build it) work with Trinity VR clients. When you're done:

- the mod is VR-aware under a Trinity engine in VR,
- VR players' heads render correctly for everyone on the server,
- the mod behaves exactly stock on any flatscreen engine, with two
  exceptions: Team Arena menu models center on wide windows (a stock bugfix,
  Step 6), and on a Trinity engine that can switch to VR the display
  settings show a Display Mode row.

This repo's `v1.0` branch is the worked example: one commit per step below.
`git log --reverse -p main..v1.0` shows every change in order.

Terms: **the host** is your mod tree. **The engine** is the program that runs
your QVMs. **The drop** is the set of vendored `vr_*` files.

Related: [VR_PROTOCOL.md](VR_PROTOCOL.md) (the head-tracking wire format).

## Rules

- **Call-outs are unconditional.** Never wrap them in `#ifdef` or a VR test.
  On an engine without VR, predicates return `qfalse`, event hooks do nothing
  and value transforms return your value unchanged.
- **The head-tracking hooks gate on `EF_VR_PLAYER`, not on a VR engine**, so a
  flatscreen client still renders VR players' heads.
- **Four placements test `vrActive` directly**, because an unconditional call
  would double-draw in VR or change flatscreen rendering: the lightning-gun
  bolt origin and the flatscreen follow crosshair (Step 5), and the
  connect-screen background in both UIs (Step 6).
- **Never edit a `vr_*` file**, except `vr_host_config.h`. Customize through
  call-out placement, your own `CG_Draw2D` body and the public accessors, so
  the next drop updates cleanly.

---

## Step 1: Copy the drop

baseq3 is the base throughout; the `ui/` files and the missionpack halves of
each step apply only if you build missionpack. Paths are under `code/`.

| File | What it is |
|---|---|
| `game/vr_shared.h`, `game/vr_safe_types.h` | The engine-shared mirror struct (`vr_shared_t`) and its QVM-safe enums. Never edit: the engine checks only size and version, not layout. |
| `game/vr_trap.h` | `VR_RESOLVE`, which looks traps up by name (Step 3) |
| `cgame/vr_host.h` | The host contract: everything the drop needs from your tree beyond stock 1.32 (Appendix E) |
| `cgame/vr_host_config.h` | **The one file you edit.** Feature switches and small mappings, below. |
| `game/vr_platform.c/.h` | `VR_Platform`, the device query (Appendix A) |
| `game/vr_bg.c/.h` | Shared movement and entity-state hooks; defines `EF_VR_PLAYER` |
| `game/vr_game.c/.h` | Server side: bootstrap, head-bit decode, 6DOF aim and muzzle, config seed |
| `cgame/vr_cgame.c/.h` | Client side: bootstrap, view, view weapon, head rendering, follow view, events, HUD, body, cvar accessors |
| `q3_ui/vr_ui.c/.h` | baseq3 UI: bootstrap, cursor and input, menu scale, virtual keyboard |
| `ui/vr_ui.c/.h` | The same for Team Arena |
| `ui/vr_uishared.c/.h` | Team Arena's menu-focus haptic test and model-FOV compensation |
| `game/vr_ui_mode.c` | The flatscreen/VR display-mode choice, written to the latched `vr_enabled` through the console |
| `game/vr_bindmenu.c/.h` | The bindings menu model, shared by both UIs |
| `game/vr_supersample.c/.h` | Supersampling steps (1.0 to 2.0 in tenths) and the eye size each renders at |
| `game/vr_glyph.c/.h` | VR button glyphs: names to atlas cells, key markers, mixed text and glyph layout |

`vr_host_config.h` settings:

- `VR_HOST_HAS_TV`, `VR_HOST_HAS_WARMUP_EVENTS`, `VR_HOST_HAS_GRAPPLE`,
  `VR_HOST_HAS_TRACE_RENDER`: optional host features. A stock tree sets all
  four to 0.
- `#define Q_sscanf sscanf` for a stock tree.
- `VR_WHEEL_DEFAULT_WEAPONS` (optional), the weapon wheel's default set. Tokens
  are separated by whitespace, not commas. A token is a `weapon_t` number or an
  item classname, with or without `weapon_`. `*` expands the default set,
  `!name` hides a weapon from later mentions, and the first mention wins. A
  list of only exclusions means the default set minus those.

Also copy the VR settings screens for each UI you build (Step 7 explains why
they're required):

- baseq3: `ui_vroptions.c` (the hub), `ui_vrbindings.c`, `ui_vrcomfort.c`,
  `ui_vrcontrols.c`, `ui_vrhud_display.c`, `ui_vrmirror.c`.
- Team Arena: `vroptions.menu`, `ingame_vroptions.menu`, `vrbindings.menu`
  and their manifest `vrmenus.txt`.
- Both: `game/ui_displaymodes.c/.h`, the Desktop Mirror sizes.

`sync-vr-drop.sh <trinity checkout>` copies all of these; its file list is the
drop manifest.

---

## Step 2: Wire the build

| Source | Compiles into |
|---|---|
| `vr_bg.c` | every module: game, cgame, both UIs |
| `vr_game.c` | game |
| `vr_cgame.c` | cgame |
| `vr_platform.c`, `vr_glyph.c` | cgame and both UIs |
| `q3_ui/vr_ui.c`, the baseq3 VR screens | baseq3 UI |
| `ui/vr_ui.c` | missionpack UI |
| `ui/vr_uishared.c` | missionpack cgame **and** missionpack UI (it links wherever `ui_shared.c` does) |
| `vr_ui_mode.c`, `vr_bindmenu.c`, `vr_supersample.c`, `ui_displaymodes.c` | both UIs |

Put the headers on every module's include path. The template includes the
host pair at the end of `cg_local.h`, just before `vr_cgame.h`.

The Team Arena `.menu` files and `vrmenus.txt` are runtime assets: ship them
in your own pak. A mod under its own `fs_game` stacks on baseq3 and never
loads the missionpack asset pak.

> **Build and check.** Before placing any call-out, add the two stat enum
> entries (Step 4) and satisfy `vr_host.h` (Appendix E), then build. A drop
> that builds with no call-outs is dormant code; any remaining failure is a
> file list or include path problem.

---

## Building the QVMs

Trinity engines run QVMs but don't compile them; your tree builds its own.

The template uses lcc 4.2 (`tools/q3lcc`) and a q3asm fork with dead-code
elimination and `.jts` jump tables (`tools/q3asm`), both submodules
(`git submodule update --init`). `make` builds the tools, then both paks. It
needs only `build-essential` and `p7zip-full` on Ubuntu. Stock ioquake3's
`code/tools` works too.

If you adopt that q3asm, also take the template's `q_math.c`: the q3asm scopes
`static` per file, so the `Q3_VM` vector math must be defined out of line, not
as stock's `__Q3_VM_MATH` header inlines. Otherwise the vector-math externs
fail to link.

QVM pitfalls:

- q3lcc is C90 with its own preprocessor, which can differ silently from your
  native compiler's. Test both the QVM and the native build.
- Missing symbols (a libc function `bg_lib` lacks, a file left off a list)
  fail at q3asm link time, after every file compiled clean.
- q3lcc resolves `-I` relative to the source file's directory, not the make
  directory. Write include flags relative to `code/<module>/`.
- Engines JIT QVMs, so undefined behavior an interpreter tolerated can crash.

---

## Step 3: How a module wakes up

This code is in the drop; you don't write it.

1. The module reads the cvar `//trap_GetValue`. Empty means a stock engine:
   the module stays dormant.
2. It resolves its trap keys by name through that entry point (Appendix B).
   There are no fixed VR syscall numbers.
3. Last, it resolves `trap_VR_RegisterState` and registers its mirror with the
   version pair it was built against:

```c
vr_state.structSize = sizeof( vr_state );
vr_state.apiVersion = VR_API_MAJOR;
trap_VR_RegisterState( &vr_state, sizeof( vr_state ), VR_API_MAJOR, VR_API_MINOR );
```

A flatscreen Trinity engine answers `//trap_GetValue` but not
`trap_VR_RegisterState`, so modules stay dormant there. Registration is the
dormancy signal: `G_VR_Active()` in game, `vrActive` in cgame and the UIs.

The engine accepts a module whose major version matches and whose minor it
meets, and refuses anything else with `VR API incompatible`. Each QVM also
embeds the string `TRINITY_VR_API/1.0` (`vr_api_sentinel[]`), which the
engine scans for. A hand-written bootstrap must keep that array and its
self-reference, or the engine treats the QVM as flatscreen-only. Native
modules aren't scanned; registration is their only version check.

Two consequences:

- The engine checks each module on its own. A QVM without the sentinel is
  skipped with one console line and replaced by the engine's bundled native
  module, so all three modules must carry the drop.
- Each sync writes back only the mirror blocks your module owns (see the block
  comments in `vr_shared.h`). A write to an engine-owned field compiles but is
  reverted at the next sync. Change engine state through cvars or traps.

---

## Step 4: Wire the server side

**Bootstrap.** `G_VR_Init()` in `G_InitGame`, after the init prints:

```diff
 	G_Printf ("gamedate: %s\n", __DATE__);
+
+	G_VR_Init();
```

**Head decode.** `G_VR_ClientThink` in `ClientThink_real`, after the button
latch. It unpacks the head bits and sets or clears `EF_VR_PLAYER`, for
clients whose userinfo reports `vr 1`:

```diff
 	client->latched_buttons |= client->buttons & ~client->oldbuttons;
+
+	G_VR_ClientThink( client, ucmd );
```

**One-line call-outs:**

| Site | Call-out |
|---|---|
| `ClientEndFrame` (g_active.c) | `G_VR_ClientEndFrame( client, ent )`: copies head angles to the entity and packs the head stats |
| `ClientUserinfoChanged` (g_client.c) | `G_VR_ClientUserinfoChanged( client, userinfo )`, once per change for every client, bots included. Its return fills `\vr\%s` in the player configstring. |
| `CalcMuzzlePointOrigin` (g_weapon.c) | `if ( !G_VR_MuzzlePoint( ent, ... ) )` around the stock math; `qtrue` means it wrote a 6DOF muzzle |
| `FireWeapon`, `CheckGauntletAttack` (g_weapon.c) | `G_VR_AimAngles( ent, angles )`: applies the 6DOF aim when it returns `qtrue` |

A missing `vr` key reads as not-VR, so bots and vanilla servers need nothing.
In cgame, `CG_VR_ClientIsVR( clientNum )` reports the flag; showing it on the
scoreboard or HUD is recommended, since VR players aim and move differently.

**Stat enum.** Append the two head stats at the end of `statIndex_t` in
`bg_public.h`:

```c
	STAT_VR_HEAD_PITCH,				// VR head pitch angle (packed as short for demo playback)
	STAT_VR_HEAD_YAW_OFFSET,		// VR head yaw offset from weapon direction (packed as short)
```

Their values differ between baseq3 and missionpack; that's fine, since only
game and cgame read them. Keep the enum append-only so old demos read zeros
from new slots. `MAX_STATS` is 16: count before you append.

**Movement (`bg_pmove.c`).** In `PM_UpdateViewAngles`:

```diff
 	if ( ps->pm_type != PM_SPECTATOR && ps->stats[STAT_HEALTH] <= 0 ) {
 		return;		// no view changes at all
 	}
 
+	if ( BG_VR_UpdateViewAngles( ps, cmd ) ) {
+		return;		// 6DOF client: YAW-only delta compensation applied
+	}
+
 	// circularly clamp the angles with deltas
```

Pass your movement constants through `BG_VR_PmoveFriction( pm->ps, friction )`
(stock: `pm_friction` in `PM_Friction`) and
`BG_VR_PmoveAccelerate( pm->ps, accelerate )` (stock: the ground
`pm_accelerate` in `PM_WalkMove`).

In `PM_Footsteps`, after stock's not-trying-to-move branch:

```c
	// VR players: analog sticks and roomscale drift produce tiny velocities
	// that must not advance the walk cycle
	if ( BG_VR_DriftIdle( pm->ps ) && xyspeed < 10 ) {
		pm->ps->bobCycle = 0;	// start at beginning of cycle again
		if ( pm->ps->pm_flags & PMF_DUCKED ) {
			PM_ContinueLegsAnim( LEGS_IDLECR );
		} else {
			PM_ContinueLegsAnim( LEGS_IDLE );
		}
		return;
	}
```

In `BG_PlayerStateToEntityState` and `BG_PlayerStateToEntityStateExtraPolate`,
call `BG_VR_HeadToEntityState( ps, s )` after the `s->angles2[YAW]`
assignment.

> **Build and check.** Nothing changes on a flatscreen engine. A VR client on
> this server is now flagged `EF_VR_PLAYER` and sends head data.

---

## Step 5: Wire the client side

**Lifecycle.**

| Site | Call-out |
|---|---|
| top of `CG_Init` | `CG_VR_Init()` |
| `CG_RegisterGraphics` | `CG_VR_RegisterMedia()` |
| `CG_DrawActiveFrame`, after `CG_UpdateCvars()` and before the loading-screen return and `CG_ProcessSnapshots()` | `CG_VR_Frame()` |
| `CG_DrawActiveFrame`, after `CG_ProcessSnapshots`, right before `CG_AddViewWeapon` | `CG_WeaponAdjustFrame()` (it needs a fresh snapshot, so keep it out of `CG_VR_Frame`) |
| `CG_Shutdown` | `CG_VR_Shutdown()` |

**Console commands.** Add to the `cg_consolecmds.c` table:

```c
	{ "weapon_select", CG_WeaponSelectorSelect_f },
	{ "weapon_adjust", CG_WeaponAdjust_f },
	{ "+adjust_reset", CG_WeaponAdjustResetDown_f },
	{ "-adjust_reset", CG_WeaponAdjustResetUp_f },
```

`weapon_adjust` toggles adjust mode; from the console or a menu it sends
`returntogame` first. In adjust mode, tapping `+adjust_reset` resets the
selected parameter and a 2 second hold resets all. The drop draws the adjust
overlay itself.

**What the engine provides.**

- `thumbstick_location[VR_STICK_MOVE]` and `[VR_STICK_TURN]`: the sticks by
  role, with deadzone, handedness and `vr_switchThumbsticks` applied.
- `pointerMode`: `VR_POINTER_CURSOR` (0) the ray moves the hover and the module
  draws the cursor; `VR_POINTER_STICK` (1) a stick moves the selection, with no
  cursor; `VR_POINTER_DRAWN` (2) the engine draws the ray, so the module hides
  its cursor. The UI hooks handle this. A cursor your cgame draws (a clickable
  scoreboard) adds `&& !CG_VR_HideCursor()`.
- `cg_followMode` sets the VR follow camera each frame: 0 first person, 1 third
  person, 2 free-fly (TV playback only). In third person, smooth turning orbits
  and snap turning (`vr_snapturn`) keeps the teleporting camera.

**The whole-frame fork.** In `CG_DrawActive`, after `CG_TileClear()`. `qtrue`
means the drop drew the VR frame:

```diff
 	CG_TileClear();
+
+	if ( CG_VR_DrawFrame( stereoView ) ) {
+		return;
+	}
 
 	if(stereoView != STEREO_CENTER)
 		CG_DrawCrosshair3D();
```

Code above the fork runs in VR too. Put 2D work in `CG_Draw2D`, which the VR
path calls with the right setup.

**2D scaling.** In VR, `CG_AdjustFrom640` letterboxes 640x480 into the
frame's centered 4:3 box with one scale for both axes. In `CG_Init`, right
after stock sets `cgs.screenXScale` and `cgs.screenYScale`:

```diff
+	if ( CG_VR_HostScale( &cgs.screenXScale, &cgs.screenXBias, &cgs.screenYBias ) ) {
+		cgs.screenYScale = cgs.screenXScale;
+	}
```

It returns `qfalse` on flatscreen and leaves the values alone. `cgs_t` gains
`float screenYBias` after `screenXBias`. `CG_AdjustFrom640` adds both biases:

```diff
-	*x *= cgs.screenXScale;
-	*y *= cgs.screenYScale;
+	*x = *x * cgs.screenXScale + cgs.screenXBias;
+	*y = *y * cgs.screenYScale + cgs.screenYBias;
```

`UI_DrawBannerString2` and `UI_DrawProportionalString2` add `screenYBias` to
`ay` too. A mod that already letterboxes with one scale passes its own scale
and bias fields.

**Head-tracking hooks** (the cgame side of [VR_PROTOCOL.md](VR_PROTOCOL.md)).
Five go in `CG_PlayerAngles` (cg_players.c). Add a local:

```diff
 	clientInfo_t	*ci;
+	vec3_t		absoluteTorsoAngles;
```

Cache the interpolated head:

```diff
 	VectorClear( torsoAngles );
 
+	// VR player - interpolate head pitch and yaw offset (applied after AnglesSubtract below)
+	CG_VR_PlayerHeadLerp( cent );
+
 	// --------- yaw -------------
```

Wrap the torso swings. Each hook returns `qtrue` when it handled a VR player,
whose torso follows weapon aim exactly:

```diff
 	legsAngles[YAW] = headAngles[YAW] + movementOffsets[ dir ];
-	torsoAngles[YAW] = headAngles[YAW] + 0.25 * movementOffsets[ dir ];
-
-	// torso
-	CG_SwingAngles( torsoAngles[YAW], 25, 90, cg_swingSpeed.value, &cent->pe.torso.yawAngle, &cent->pe.torso.yawing );
+	// VR: torso follows weapon aim 1:1 (no movement offset);
+	// flatscreen: torso turns 25% toward movement direction
+	if ( !CG_VR_PlayerTorsoYaw( cent, headAngles, torsoAngles ) ) {
+		torsoAngles[YAW] = headAngles[YAW] + 0.25 * movementOffsets[ dir ];
+		CG_SwingAngles( torsoAngles[YAW], 25, 90, cg_swingSpeed.value, &cent->pe.torso.yawAngle, &cent->pe.torso.yawing );
+	}
 	CG_SwingAngles( legsAngles[YAW], 40, 90, cg_swingSpeed.value, &cent->pe.legs.yawAngle, &cent->pe.legs.yawing );
```

```diff
-	CG_SwingAngles( dest, 15, 30, 0.1f, &cent->pe.torso.pitchAngle, &cent->pe.torso.pitching );
+	// VR: torso follows weapon pitch directly; flatscreen uses swing tolerance
+	if ( !CG_VR_PlayerTorsoPitch( cent, dest ) ) {
+		CG_SwingAngles( dest, 15, 30, 0.1f, &cent->pe.torso.pitchAngle, &cent->pe.torso.pitching );
+	}
 	torsoAngles[PITCH] = cent->pe.torso.pitchAngle;
```

Save the absolute torso, then turn the world-space head into torso-local
angles:

```diff
 	CG_AddPainTwitch( cent, torsoAngles );
 
+	// Save absolute torso angles for VR head calculation
+	CG_VR_PlayerSaveAbsoluteTorso( cent, torsoAngles, absoluteTorsoAngles );
+
 	// pull the angles back out of the hierarchial chain
 	AnglesSubtract( headAngles, torsoAngles, headAngles );
 	AnglesSubtract( torsoAngles, legsAngles, torsoAngles );
+
+	// VR: compute head orientation relative to torso using matrix math
+	CG_VR_PlayerHeadAngles( cent, absoluteTorsoAngles, headAngles );
+
 	AnglesToAxis( legsAngles, legs );
```

The other three:

| Site | Call-out |
|---|---|
| `CG_CalcViewValues` (cg_view.c), after the view angles are copied | `CG_VR_FollowHeadView( ps );` looks through a followed VR player's head |
| end of `CG_InterpolatePlayerState` (cg_predict.c) | `CG_VR_InterpolateHeadStats( out, &prev->ps, &next->ps, f );` |
| `CG_AddPacketEntities` (cg_ents.c), after the predicted player's `BG_PlayerStateToEntityState` | `CG_VR_PredictedPlayerHead();` gives your own entity your head pose |

If your mod jumps its timeline (demo seek), call `CG_VR_FollowHeadViewReset()`
and `CG_VR_PlayerHeadReset()` at the jump.

`CG_VR_IsVRFollow()` is `qtrue` while following a VR player. Its one
`vrActive` placement is the flatscreen follow crosshair, in
`CG_DrawActiveFrame` after `CG_AddViewWeapon`:

```c
	if ( !vrActive && !cg.renderingThirdPerson && CG_VR_IsVRFollow() )
		CG_DrawCrosshair3D();
```

**Everything else** is one line at its stock site. The full list is the
template's Step 5 commit; the shapes are:

- **Gate swaps.** Stock code calls through the hook, so your own changes
  stay. View: `CG_VR_Fov`, `CG_VR_OffsetView`, `CG_VR_ViewAxis`, the
  intermission and menu-freeze regions, the weapon angles. View weapon:
  `CG_VR_WeaponWheel`, `CG_VR_WeaponHandPose`, `CG_VR_HideViewWeapon` and
  others. Body: `CG_VR_FirstPersonBody`, `CG_VR_OffHandItemPose` and others.
  Aim: `CG_VR_CrosshairScanRay` (in `CG_ScanForCrosshairEntity`),
  `CG_VR_WeaponMuzzleOrigin` (`EV_RAILTRAIL`), `CG_VR_FollowedPlayerSprite`
  (`CG_PlayerSprites`), `CG_VR_ForceThirdPerson` (`cg.renderingThirdPerson`
  in `CG_DrawActiveFrame`). Values: `CG_VR_DamageRollScale`
  (`CG_OffsetFirstPersonView`), `CG_VR_ChatOffsetX/Y` (missionpack chat in
  cg_newdraw.c).
- **Suppression predicates.** AND `!CG_VR_Owns...()` into a draw condition:
  `CG_VR_OwnsHudVisibility`, `CG_VR_Owns2DCrosshair`, `CG_VR_OwnsWeaponSelect`,
  `CG_VR_OwnsViewBob`, `CG_VR_SuppressDeadScoreboard` and others.
  `CG_VR_IsDeathCam` is an OR-in early return in `CG_DrawCrosshair3D`. The
  missionpack HUD also uses `CG_VR_HudVisible()` (`qtrue` when dormant):
  `CG_OwnerDraw` and `CG_Draw2DMinimal` return early when it's `qfalse`, and
  `CG_Draw2D` paints menus when
  `CG_VR_HudVisible() && ( CG_VR_OwnsHudVisibility() || cg_drawStatus.integer )`.
- **Event hooks.** `CG_VR_EntityEvent( cent, event, clientNum )` at the top of
  `CG_EntityEvent`, before the `switch` and after `clientNum` is clamped; it
  handles game-event haptics. If you drop duplicate events (a predicted
  pickup), do that first. `CG_VR_OnHitByMissile`, `CG_VR_OnDamageTaken`,
  `CG_VR_OnWeaponFired` and `CG_VR_OnWeaponFiring` go at their own sites.
- **Server-interaction accessors.** Voting: `CG_VR_SetVoteActive(active)` and
  `CG_VR_VoteHolding()` for hold-to-confirm. The hold timer is host code: take
  the template's `CG_ProcessVoteHold` (cg_draw.c) and call it in `CG_Draw2D`
  after `CG_DrawVote` and `CG_DrawTeamVote`. A clickable scoreboard uses
  `CG_VR_SetScoreboardCursor(active)` and `CG_VR_ScoreboardCursor(&x, &y)`.
  Demo scrubbing uses `CG_VR_MenuYaw()`, `CG_VR_LockMenuYaw(yaw)`,
  `CG_VR_UnlockMenuYaw(yaw)` and `CG_VR_MenuPointerYaw()`. A stock mod has no
  call site for the last two families.
- **State resets and reads.** `CG_VR_DeathCamReset()` where the player
  respawns or a gamestate begins (the template: `CG_Init` and `CG_Respawn`).
  `CG_VR_PortraitReset()` where your timeline jumps without a snapshot
  teleport (demo seek). `CG_VR_ReticleShader()` returns the scope mask.

Two sites are larger; copy them from the template:

- **Lightning gun** (`CG_LightningBolt`, cg_weapons.c). After stock computes
  `directView`, branch on `vrActive && directView`: the bolt starts at the
  hand-held weapon (`CG_CalculateVRWeaponPosition`) and
  `CG_VR_OnWeaponFiring( weapon )` drives the haptic each frame. The stock
  math stays in the other branch.
- **HUD portrait** (`CG_DrawStatusBarHead` in cg_draw.c; missionpack
  `CG_DrawPlayerHead` in cg_newdraw.c). After `VectorClear( angles )`, add
  `vr = CG_VR_PortraitHeadAngles( angles );`. When it's `qtrue` the damage kick
  adds on top (`angles[YAW] += cg.damageX * 45`) and the stock idle bob runs
  only under `!vr`. It tests `EF_VR_PLAYER`, so flatscreen clients show a
  followed VR player's head too.

---

## Step 6: Wire the UI

Do each UI you build.

**baseq3 (`q3_ui`).**

| Site | Call-out |
|---|---|
| top of `UI_Init` | `UI_VR_Init();` |
| end of `UI_Init`'s scaling setup | `if ( UI_VR_HostScale( &uis.xscale, &uis.bias, &uis.biasY ) ) uis.yscale = uis.xscale;` |
| vmMain `UI_SHUTDOWN`, beside `UI_Shutdown` | `UI_VR_Shutdown();` |
| first in `UI_KeyEvent` | `UI_VR_KeyEvent( key, down )` (also opens the VR keyboard on a text-field click) |
| `UI_MouseEvent` | the `UI_VR_StickNavActive()` early return; `UI_VR_CursorOverride( &uis.cursorx, &uis.cursory )` after the stock clamps; the `UI_VKeyboardIsActive()` guard before the region test; `UI_VR_OnMenuMove()` on focus change |
| `UI_Refresh`, once per frame | the cursor override |
| the cursor draw | gate with `!UI_VR_HideCursor()` |
| every menu-model refdef (ui_menu.c models, `UI_DrawPlayer`) | `UI_VR_CompensateModelFov` |

The connect-screen background is a `vrActive` placement:

```c
	if ( vrActive ) {
		UI_VR_FillScreen( uis.menuBackShader );
	} else {
		UI_DrawHandlePic( 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, uis.menuBackShader );
	}
```

`UI_VR_HostScale` writes the VR letterbox like `CG_VR_HostScale` (Step 5).
`UI_AdjustFrom640` gets no VR branch: it applies the `uis` fields the helper
writes, with `biasY` (Appendix E).

**Team Arena (`ui`).** `displayContextDef_t` gains `float biasY` after
`bias`. Both 640-space transforms add it: `UI_AdjustFrom640` (ui_atoms.c)
takes `*y = *y * uiInfo.uiDC.yscale + uiInfo.uiDC.biasY;`. `AdjustFrom640`
(ui_shared.c) takes `*x = *x * DC->xscale + DC->bias;` and
`*y = *y * DC->yscale + DC->biasY;`, so menu models center on wide frames.
Stock comments the x bias out, which leaves menu models left of their panels
on wide flatscreen windows. Adding it is a stock bugfix, so menu models
center on flatscreen too.

The rest are in `ui_main.c`:

| Site | Call-out |
|---|---|
| top of `_UI_Init` | `UI_VR_Init();` |
| end of `_UI_Init`'s scaling setup | `if ( UI_VR_HostScale( &uiInfo.uiDC.xscale, &uiInfo.uiDC.bias, &uiInfo.uiDC.biasY ) ) uiInfo.uiDC.yscale = uiInfo.uiDC.xscale;` |
| vmMain `UI_SHUTDOWN`, beside `_UI_Shutdown` | `UI_VR_Shutdown();` |
| `_UI_Refresh`, once per frame | `UI_VR_CursorOverride( &uiInfo.uiDC.cursorx, &uiInfo.uiDC.cursory )` (also the hover haptic, and under stick navigation rests the cursor on the focused item); gate the cursor draw with `!UI_VR_HideCursor()` |
| `_UI_MouseEvent` | the `UI_VR_StickNavActive()` early return and the cursor override |
| first in `_UI_KeyEvent` | `UI_VR_KeyEvent( key, down )` (a waiting bindings row takes every key; under stick navigation left and right step the focused slider) |
| end of `_UI_KeyEvent`, key-down only | `UI_VR_KeyHandled( key )`, with `Menu_EditingItem()` and `Menu_SetEditingItem()` added to ui_shared.c |
| after every `UI_LoadMenus` (`_UI_Init` and `UI_Load`) | `UI_VR_LoadMenus();` |
| top of `UI_DrawCinematic` | the `UI_VR_DrawCinematic( handle, x, y, w, h )` early return (on the virtual screen the engine takes the extents in 640 units) |
| connect screen, before the stock `Menu_Paint` | `if ( vrActive && menu->window.background ) UI_VR_FillScreen( menu->window.background );` |
| `UI_RunMenuScript`'s command chain | `UI_VR_RunMenuScript(name)` |
| `Item_Model_Paint` (both links), `UI_DrawPlayer` | `UI_VR_CompensateModelFov` |

The three owner-draw switches hand their `default:` case to the drop:

```diff
     default:
-      break;
+      UI_VR_OwnerDraw(x, y, w, h, text_x, text_y, ownerDraw, ownerDrawFlags, align, special, scale, color, shader, textStyle);
+      break;
```

`UI_OwnerDrawHandleKey`'s becomes
`return UI_VR_OwnerDrawHandleKey(ownerDraw, flags, special, key);` and
`UI_OwnerDrawWidth`'s `return UI_VR_OwnerDrawWidth(ownerDraw, scale);`.

---

## Step 7: The VR settings screens

They're **required**: a mod's `ui.qvm` replaces the engine's, so without them
VR players can't reach VR settings in the headset. Copying the shipped
screens covers everything below. Your own screens must cover every cvar in
Appendix A and these couplings:

- **`vr_hudDrawStatus`**: value 2 also sets `cg_draw3dIcons 0`; every other
  value sets `cg_draw3dIcons 1`. Team Arena's HUD Mode rows run
  `uiScript vrHudDrawStatusChanged`.
- **Display mode**: `vr_enabled` is latched, so the choice goes through the
  console (`UI_VR_ChooseMode`) and applies at the next video restart. Team
  Arena's row binds the shadow cvar `ui_vrEnabled`; the menu's `onOpen` runs
  `uiScript vrModeSetup` and the row's `action` runs `uiScript vrModeChanged`.
  baseq3 calls `UI_VR_ModeChoice` and `UI_VR_ChooseMode` directly.
- **Desktop mirror**: `vr_mirrorEnabled`, `vr_mirrorFullscreen`,
  `vr_mirrorWidth` and `vr_mirrorHeight` are staged and applied with a
  `vid_restart` on confirm.
- **Fullscreen menus**: the laser pointer can click anywhere, and a
  non-fullscreen menu closes on an outside click. Every standalone VR screen
  sets `fullscreen 1` (q3_ui: `menu.fullscreen = qtrue`). The exception is
  the in-game `ingame_vroptions.menu` panel: `fullscreen 0` with
  `outOfBoundsClick`, so an outside click returns to the game.

**Bindings.** Controller inputs are keys the engine binds per context:
`vrbind <context>[+alt] <key> <command>`. The contexts are `global`, `menu`,
`adjust`, `scrub`, `scoreboard`, `vote`, `wheel`, `follow` and `gameplay`,
each with a `+alt` layer used while Alt is held. Keys name roles (weapon hand,
off hand, move stick, turn stick), so handedness and the stick swap change
the glyph a key shows, never its bindings. Each UI needs a bindings screen;
both shipped forms use `vr_bindmenu`. Rows show Button and Alt + Button
columns, X clears both, and the stick moves between cells.

The drop's `vr_ui.c` talks to the engine through `trap_GetValue` keys and one
trap:

| Key | Answer |
|---|---|
| `vr_keyfirst` | The first VR key code; VR key *n* is that plus *n* (0 to 35). Read at UI init. |
| `vr_binding <context> <keycode>` | The bound command, empty when unbound |
| `vr_keyglyph <keycode>` | The key's glyph name (`trigger_l`, `stick_up_r`, `a`, `menu`, `dpad_left`, ...), after handedness and the stick swap |
| `vr_bindkeys <context> <command>` | The keys that would run that command in that context: an Alt combo first as `<altcode>+<code>`, else one plain key; keys the controller lacks don't count |
| `vr_keydefault <context> <index> <command>` | The controller's default key for that command, `<index>` 0 or 1; no answer when there's none |
| `vr_eyesize` | `recW recH maxW maxH`: the recommended and maximum per-eye size |
| `trap_VR_BindCapture` | A trap, armed only while the UI has key focus: the next VR button gesture arrives as its key code once released, instead of running a binding |

Writes use the console commands `vrbind` and `vrunbind`. Each frame the UI
calls `VRBM_Tick( realtime )` and `VRG_Tick` and paints with its glyph glue
(`UI_VR_GlyphPaint` in Team Arena, `UI_VR_GlyphString` in baseq3).
`UI_VR_BindingsAvailable()` is `qtrue` when the engine answered both
`trap_VR_BindCapture` and `vr_keyfirst`; otherwise the screens hide the
bindings entry. Team Arena tests it as `cvarTest "ui_vrBindingsAvailable"`.
The bindings menu's `onClose` runs `uiScript vrBindCancel`.

**Team Arena owner-draws.** Reached through the Step 6 `default:` cases. Your
`ui/menudef.h` defines these IDs, and your missionpack pak ships it:

| ID | Value | Row |
|---|---|---|
| `UI_REFRESHRATE` | 265 | cycles `vr_refreshrate` through `vr_refreshrates` |
| `UI_FOVEATION` | 266 | `vr_foveation`, capped by `vr_foveationCaps` |
| `UI_FOVEATION_STRENGTH` | 267 | `vr_foveationStrength` |
| `UI_VRBIND` | 269 | one bindings row; the row index is the item's `special` |
| `UI_VRBIND_STATUS` | 270 | the bindings status line |
| `UI_VRSUPERSAMPLING` | 271 | `vr_superSampling`, 1.0 to 2.0 in tenths, with the eye size each step renders at |

baseq3's screens draw the same rows in C.

**Making them reachable.**

- baseq3: in `ui_setup.c`, SETUP shows VR OPTIONS in place of CONTROLS when
  `UI_VR_Platform() != VRP_NONE`. The hub opens the bindings screen. In
  `ui_display.c`, the Display page gets a Display Mode row above Brightness
  when `UI_VR_CanSwitchMode()`, and an Apply button that shows while
  `UI_VR_ModePending()` and runs `vid_restart`.
- Team Arena: `UI_VR_LoadMenus` loads the menus listed in `vrmenus.txt`. Add
  the entries to your own menus on `cvarTest "ui_vrActive"` (set by
  `UI_VR_Init`, `0` on a flatscreen engine): a VR Options item in
  `setup.menu`'s Controls slot (`open vroptions_menu`) with Controls hidden
  under VR, a VR tab in `ingame.menu` in the Controls tab's place
  (`open ingame_vroptions`), and the Display Mode row on the System pages.
  The template's Step 7 commit makes these edits to retail's menus.

---

# Appendices

## Appendix A: The cvar contract

The drop reads and writes these engine-owned cvars by name.
`CG_VR_CvarValue(name)` and `CG_VR_CvarSet(name, value)` wrap the cgame side
(the cgame QVM has no float cvar trap); the UIs use `trap_Cvar_VariableValue`.

| Cvar | Kind | Role |
|---|---|---|
| `vr_worldscale` | archived | World scale; read each frame by cgame and by the game |
| `vr_worldscaleScaler` | archived | Spectator and zoom scale factor, written each frame by the drop and read by the renderers |
| `vr_hudDrawStatus`, `vr_hudDepth`, `vr_hudScale`, `vr_hudYOffset` | archived | HUD visibility and placement |
| `vr_currentHudDrawStatus`, `vr_currentHudDepth` | transient | Written by `CG_VR_Frame` for the renderer |
| `cl_platform` | read-only | The device: `windows`, `macos`, `linux`, `frame`, `pico`, `quest`. Read only through `UI_VR_Platform()`. |
| `vr_6dof` | archived | Seeds `use_6dof` (single player only) |
| `vr_physicalCrouch` | archived, default 1 | Physical crouch on or off; the engine applies it |
| `vr_mirrorEnabled`, `vr_mirrorFullscreen` | archived | Desktop mirror mode |
| `vr_mirrorWidth`, `vr_mirrorHeight` | archived, PC only | Desktop mirror size; writes are inert elsewhere |
| `vr_lasersight`, `vr_twoHandedWeapons`, `vr_showItemInHand`, `vr_rollWhenHit`, `vr_weaponSelectorMode`, `vr_weaponSelectorWithHud` | archived | Gameplay and comfort toggles |
| `vr_switchThumbsticks` | archived | Swaps the stick roles; the engine applies it |
| `vr_snapturn` | archived | Snap-turn angle, 0 for smooth; also picks the third-person follow camera |
| `vr_controllerModels` | archived, default 1 | The pointer ray, its light and the controller models |
| `vr_screenCurvature` | archived, default 0.5 | Virtual screen curvature, 0 flat to 1 tightest |
| `vr_refreshrate`, `vr_foveation`, `vr_foveationStrength`, `vr_weaponPitch`, `vr_superSampling` | archived | Headset settings |
| `vr_refreshrates`, `vr_foveationCaps` | read-only | What the headset offers: its refresh rates, and `none`, `fixed` or `eyetracked` |

Weapon stabilization is a mirror flag, not a cvar.

**Never read `cl_platform` directly in menus.** It names the device in
flatscreen too. `UI_VR_Platform()` returns `VRP_NONE` unless VR is live:

```c
vrPlatform_t VR_Platform( qboolean vrActive ) {
	char buf[16];

	if ( !vrActive ) {
		return VRP_NONE;
	}
	trap_Cvar_VariableStringBuffer( "cl_platform", buf, sizeof( buf ) );
	if ( !Q_stricmp( buf, "windows" ) || !Q_stricmp( buf, "macos" ) || !Q_stricmp( buf, "linux" ) ) {
		return VRP_PC;
	}
	if ( !Q_stricmp( buf, "frame" ) || !Q_stricmp( buf, "pico" ) || !Q_stricmp( buf, "quest" ) ) {
		return VRP_STANDALONE;
	}
	return VRP_NONE;
}

vrPlatform_t UI_VR_Platform( void ) {
	return VR_Platform( vrActive );
}
```

`UI_VR_LoadMenus()` checks both the same way.

## Appendix B: Bootstrap trap keys

`trap_GetValue(value, valueSize, key)` returns non-zero and writes the trap
number when the engine knows `key`. All keys are required: a bootstrap
missing any one stays dormant. `trap_VR_RegisterState` is resolved last and
its success sets `vrActive` / `g_vrActive`. New traps come with a
`VR_API_MINOR` bump; there are no per-feature flags.

| Key | Modules |
|---|---|
| `trap_VR_RegisterState` | all (resolved last) |
| `trap_R_SceneComplete` | cgame |
| `trap_R_HUDBufferStart`, `trap_R_HUDBufferEnd` | cgame |
| `trap_HapticEvent` | cgame, both UIs |
| `trap_VKeyboard_Show`, `_Hide`, `_IsActive`, `_HandleKey` | both UIs |

After registration the UIs also ask for `trap_VR_BindCapture` and
`vr_keyfirst`. If either is missing the module stays active and only the
bindings screen is unavailable.

## Appendix C: Assets

A missing asset drops its feature; it never crashes.

Your mod ships:

| Asset | Used for | Without it |
|---|---|---|
| `gfx/weapon/scope` | zoom scope mask | zoom works, no reticle |
| `sprites/vr/hud` | in-world HUD panel (HUD mode 1) | mode 1 draws no panel |
| VR menu files and manifests | the settings screens | settings only from the console |

`CG_VR_RegisterMedia` registers these and the weapon-wheel hover sphere
(`models/powerups/health/small_sphere.md3`). The laser beam draws through your
`CG_LaserSight` (`vr_host.h`). Comfort vignettes, the damage border and the
zoom reticle are yours to draw in `CG_DrawScreen2D` (Appendix E).

The Trinity pak in the base game (`pak8t.pk3` in baseq3, `pak3t.pk3` in
missionpack) supplies the rest; don't copy these:

| Asset | Used for | Without it |
|---|---|---|
| `fonts/fontImage_24.dat`, `fonts/fontImage_0_24.tga`, `gfx/vkb/cap`, `panel`, `glow`, `icons`, `scripts/vkb.shader` | the VR keyboard | flat text keys |
| `gfx/2d/bigchars_64.tga`, the `gfx/2d/bigchars` entry in `scripts/trinity.shader` | console, notify lines and q3_ui small text | retail's 16 px sheet, pixelated in VR |
| `gfx/vr/glyphs.tga`, `scripts/vrglyphs.shader` | VR button glyphs | missing-shader images in place of buttons |

Ship your own `ui/menudef.h` in your missionpack pak, with the owner-draw IDs
from Step 7.

In missionpack the Trinity pak replaces 22 retail menus and `ui/menus.txt`
with menus that call Trinity's own UI scripts. A Team Arena mod ships its own
copy of every menu it uses, plus its own `ui/menus.txt`; the template ships
retail's with the Step 7 entries. Retail's menus use about 0.9 MB of the UI's
`MEM_POOL_SIZE` and the VR menus about 110 KB, so raise it from stock's 1 MB
(the template uses 1.5 MB). Out of pool, the main menu hangs.

## Appendix D: Differences between the two UIs

- **Virtual keyboard.** The engine gives an open keyboard its keys first and
  closes it on DONE, Escape or an outside click; each UI only follows focus.
  `UI_VR_KeyHandled` opens it when focus lands on a text field, passing the
  field's bottom edge so the keyboard sits below the text, and closes it when
  focus leaves. baseq3 types at the end of a field because the template adds
  one line to stock `ui_qmenu.c`'s `Menu_CursorMoved`. `ui_vrmirror.c` wraps
  its size list when `ui_local.h` defines `QMF_WRAP`. Team Arena's
  `Menu_EditingItem` and `Menu_SetEditingItem` let stick navigation start and
  end edits.
- **Local-player tests.** `CG_VR_EntityEvent` and `CG_VR_OnHitByMissile` test
  the local player themselves (Step 5).

## Appendix E: The host contract (`vr_host.h`)

The drop keeps its own state, cvars and media; it needs no cvar table or
media struct entries, and no `cg_t`/`cgs_t` fields beyond Step 5's
`screenYBias`. It does need:

**Five host functions:** `CG_DrawScreen2D`, `CG_Draw2DMinimal`,
`CG_PushHUDAnchors` / `CG_PopHUDAnchors`, `CG_LaserSight`. Minimal versions:
draw nothing in `CG_DrawScreen2D` and leave the anchor pair empty. Four more
exist only behind their `vr_host_config.h` switches: `CG_WarmupEvents`,
`CG_GrappleLatchAnchor`, `CG_GrappleOwnerRGBA`, `CG_TraceRender`.

`CG_DrawScreen2D` draws in frame pixels, 0 to `vidWidth` by 0 to
`vidHeight`, with `trap_R_DrawStretchPic`, not through `CG_AdjustFrom640`.
Off the virtual screen, the engine puts the frame's center on the line of
sight and its edges on each eye's edges. While the weapon is zoomed, the
frame maps one to one onto each eye. `CG_Draw2DMinimal` draws in 640x480
units, inside the scope HUD.

**Six stock functions made non-static:** `CG_Draw2D`, `CG_DrawCrosshair3D`,
`CG_WeaponSelectable`, `CG_CalculateWeaponPosition`,
`CG_OffsetFirstPersonView`, `CG_TrailItem` (which also gains offset and scale
parameters). Take the template's bodies for two:

- `CG_Draw2D`, split from `CG_DrawScreen2D` and `CG_Draw2DMinimal` so the VR
  frame can bracket your 2D.
- `CG_DrawCrosshair3D`, which traces from `CG_CalculateVRWeaponPosition` and
  sets the sprite color explicitly (map it to your crosshair color, or white).

**Renderer types** (`code/renderercommon/tr_types.h`): `RF_OVERBRIGHT`,
`RF_WORLD_ORIENTED`, `RF_VIEW_ORIENTED`, `RT_LASERSIGHT` and
`refdef_t.isHUD`. `isHUD` must stay the last field; inserting it mid-struct
compiles and corrupts rendering. Set `refdef.isHUD = qtrue` on every 2D
mini-scene (stock: `CG_Draw3DModel`, which covers scoreboard heads, the
status-bar face and 3D icons). UI menu models don't take it.

Sprites: VR engines face billboards at the eye with up pinned to the horizon.
`RF_VIEW_ORIENTED` uses the full view axes instead (visor-style UI: the HUD
sprite, the damage blob, weapon-selector icons). `RF_WORLD_ORIENTED` uses
`refEntity_t.axis`. Flatscreen engines ignore both. Remove any cgame code that
counter-rotates sprites against head roll.

`trap_R_AddSpritePolyToScene` is an optional per-renderer trap outside the VR
contract: poly-batched billboards the engine orients per view, so puffs don't
roll with the head. Gate every call on its resolved flag and keep the stock
poly path.

**Syscalls.** Trampolines for every Appendix B trap go in all four
`*_syscalls.c`, with declarations at the end of each `*_local.h`; the
trap-number variables and QVM function pointers go in `cg_main.c` and
`g_main.c`. The UIs also trampoline `trap_VR_BindCapture`, and q3_ui's
`ui_local.h` declares the screens' entry points. Copy the blocks from the
template. Float arguments must go through `PASSFLOAT` or native builds get
garbage.

**Small pieces:**

- `Q_sscanf` (stock: `#define Q_sscanf sscanf` in `vr_host_config.h`).
- The two stat enum entries (Step 4).
- `PLAYER_HEIGHT`, `SPECTATOR_WORLDSCALE_MULTIPLIER`,
  `SPECTATOR2_WORLDSCALE_MULTIPLIER`: defaults in `vr_host.h`; define your own
  first to override.
- `cgs.cursorX` / `cgs.cursorY` become `float` if you use the scoreboard
  cursor.
- Register `cgs.media.friendShader` (`sprites/foe`) in every gametype; the
  weapon wheel draws its marker with it.
- `bot_matchvariable_t.offset` in `be_ai_chat.h` is a `short` (stock: `char`),
  matching the engines' botlib. The struct stays 8 bytes with `length` at
  byte 4. `BotCheckConsoleMessages` (ai_dmq3.c) zeroes `match` before
  `trap_BotFindMatch`, because stock botlibs write only the low byte.

**UI pieces.** baseq3: `uiStatic_t` gains `float biasY`, added in
`UI_AdjustFrom640` (`*y = *y * uis.yscale + uis.biasY;`) and in
`UI_DrawBannerString2`, `UI_DrawProportionalString2` and `UI_DrawString2`
(`ay = y * uis.yscale + uis.biasY;`); `uis.cursorx` / `uis.cursory` become
`float`. Team Arena: `ui_shared.c` gains `Menu_EditingItem` and
`Menu_SetEditingItem`. `displayContextDef_t` gains `float biasY`;
`UI_AdjustFrom640` and `AdjustFrom640` add it, and `AdjustFrom640` adds
`bias` too (Step 6). `displayContextDef_t`'s `cursorx` and `cursory` become
`float`.
`ui/menudef.h` defines the Step 7 owner-draw IDs.

A symbol still unresolved after `vr_host.h` is satisfied is a contract bug;
please report it.

## Appendix F: API 1.0 at a glance

What a module built against `VR_API_MAJOR` 1, `VR_API_MINOR` 0 can rely on:

- **Mirror:** `vr_shared_t` is 312 bytes; the cgame, shared-UI and config
  blocks start at 204, 280 and 296. `pointerMode` is the last field.
- **Registration:** `trap_VR_RegisterState` with the mirror size and 1.0, the
  `TRINITY_VR_API/1.0` sentinel in every QVM, the Appendix B keys.
- **Bindings:** `vrbind` contexts; the `vr_keyfirst`, `vr_binding`,
  `vr_keyglyph`, `vr_bindkeys` and `vr_keydefault` keys; `trap_VR_BindCapture`.
- **Commands:** `weapon_select`, `weapon_adjust`, `+adjust_reset` /
  `-adjust_reset`.
- **Follow camera:** `cg_followMode`, with `vr_snapturn` choosing orbit or
  teleport in third person.
- **Settings:** the Appendix A cvars, with `vr_eyesize` and `vr_supersample`
  behind supersampling.
- **Assets:** the VR keyboard art, 64 px character sheet and glyph atlas from
  the Trinity pak.
- **Botlib:** `bot_matchvariable_t.offset` is a `short`.
