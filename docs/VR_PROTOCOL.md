# VR Head-Tracking Protocol

How a VR player's head orientation reaches every client, VR or flatscreen.
Three parts take part:

1. **The client engine** packs head angles into its usercmds.
2. **The server engine** reads the wider usercmds from VR clients.
3. **The mod** decodes, transmits and renders the head, through the vendored
   `vr_*` files ([VR_INTEGRATION.md](VR_INTEGRATION.md) places the hooks).

A VR client on a vanilla server plays normally without head tracking. A
flatscreen client on a VR-aware server sees VR players' heads.

## 1. Negotiation

| Who | What |
|---|---|
| Server engine | Sets `vr_support 1` in serverinfo (`CVAR_SERVERINFO \| CVAR_ROM`). |
| Client engine | Sets the userinfo key `vr` (`CVAR_USERINFO \| CVAR_ROM`): `1` in VR, `0` in flatscreen. |
| Client engine | Sends 32-bit buttons when the server advertises `vr_support` and the userinfo it last sent said `vr 1`; otherwise 16-bit. |
| Server engine | Reads 32-bit buttons from a client whose latest userinfo says `vr 1`; otherwise 16-bit. |
| Mod (game) | `G_VR_ClientUserinfoChanged` records each client's `vr` value and adds `\vr\1` or `\vr\0` to its `CS_PLAYERS` configstring. |
| Mod (cgame) | `CG_VR_ClientIsVR( clientNum )` reads that flag, for scoreboard and HUD markers. |

## 2. Button encoding

VR clients pack the head into the upper bits of `usercmd_t.buttons`:

| Bits | Field | Range |
|---|---|---|
| 0-11 | standard buttons | |
| 12-18 | head pitch | -90 to +90 degrees, 7 bits |
| 19-25 | head yaw offset | -90 to +90 degrees, 7 bits |
| 26-31 | reserved | |

```c
// encode (client engine): clamp to +-80 degrees, then pack
pitch = (int)((Com_Clamp( -80, 80, hmd[PITCH] ) + 90) * 127 / 180);
yaw   = (int)((Com_Clamp( -80, 80, AngleSubtract( hmd[YAW], weapon[YAW] ) ) + 90) * 127 / 180);
cmd->buttons |= (pitch & 127) << 12 | (yaw & 127) << 19;

// decode (game, G_VR_ClientThink)
headPitch     = ((buttons >> 12) & 0x7F) * 180.0f / 127.0f - 90.0f;
headYawOffset = ((buttons >> 19) & 0x7F) * 180.0f / 127.0f - 90.0f;
```

- One step is about 1.42 degrees.
- Pitch is absolute. Yaw is the head's offset from the weapon's aim.
- The +-80 clamp is part of the encoding: it keeps each field between 7 and
  119, so a VR client never sends all-zero bits 12-25.
- The game decodes only for a client whose userinfo says `vr 1` and whose
  bits 12-25 (mask `0x03FFF000`) aren't zero. It then sets `EF_VR_PLAYER`,
  and clears it otherwise.

**Roll** travels in `cmd->angles[ROLL]`, clamped to +-60 degrees. It's always
sent in 32-bit commands; `vr_sendRollToServer 1` also sends it to 16-bit
servers.

## 3. Usercmd serialization

Both `MSG_WriteDeltaUsercmdKey` and `MSG_ReadDeltaUsercmdKey` take a
`buttonBits` argument, 16 or 32, and pass it to the buttons field's
`MSG_WriteDeltaKey` / `MSG_ReadDeltaKey` in place of the stock 16:

```c
void MSG_WriteDeltaUsercmdKey( msg_t *msg, int key, const usercmd_t *from, const usercmd_t *to, int buttonBits );
void MSG_ReadDeltaUsercmdKey( msg_t *msg, int key, const usercmd_t *from, usercmd_t *to, int buttonBits );
```

Client and server must choose the same width; section 1 says how.

## 4. Server side (game)

| Hook | Site | Does |
|---|---|---|
| `G_VR_ClientThink` | `ClientThink_real`, after the button latch | decodes the head, sets or clears `EF_VR_PLAYER` |
| `G_VR_ClientEndFrame` | `ClientEndFrame` | copies the head to the entity and the stats |
| `BG_VR_HeadToEntityState` | `BG_PlayerStateToEntityState` (and `...ExtraPolate`) | rebuilds the entity's head from the stats, for demos and follow |
| `G_VR_ClientUserinfoChanged` | `ClientUserinfoChanged` | records the `vr` flag (section 1) |

`G_VR_ClientEndFrame` writes:

```c
ent->s.angles2[PITCH] = head->pitch;
ent->s.angles2[ROLL]  = head->yawOffset;	// ROLL slot repurposed
client->ps.stats[STAT_VR_HEAD_PITCH]      = (short)(head->pitch * 182.04f);
client->ps.stats[STAT_VR_HEAD_YAW_OFFSET] = (short)(head->yawOffset * 182.04f);
```

182.04 is 32767 / 180. `BG_VR_HeadToEntityState` divides by it.

The mod's one stock addition is the two stats, appended at the end of
`statIndex_t` in `bg_public.h`. Only game and cgame read stat indices, so
their values may differ between baseq3 and missionpack. Append-only keeps old
demos reading zeros from new slots.

## 5. Entity state

| Field | Slot | Meaning |
|---|---|---|
| head pitch | `angles2[PITCH]` | absolute, degrees |
| head yaw offset | `angles2[ROLL]` | relative to weapon yaw (the slot is otherwise unused on players) |
| movement direction | `angles2[YAW]` | stock (legs animation) |
| VR player | `eFlags` | `EF_VR_PLAYER`, `0x00000400` |

`EF_VR_PLAYER` shares its bit with `EF_MOVER_STOP`, which only movers use.
Head roll comes through the normal view angles.

## 6. Client side (cgame)

These hooks test `EF_VR_PLAYER`, not a VR engine, so flatscreen clients render
VR heads too.

| Hook | Site | Does |
|---|---|---|
| `CG_VR_PlayerHeadLerp`, `CG_VR_PlayerTorsoYaw`, `CG_VR_PlayerTorsoPitch`, `CG_VR_PlayerSaveAbsoluteTorso`, `CG_VR_PlayerHeadAngles` | `CG_PlayerAngles` | interpolate the head between snapshots, keep the torso on weapon aim (the yaw offset is relative to it), convert the head to torso-local angles, limit pitch and yaw to +-80 and roll to +-60 |
| `CG_VR_FollowHeadView` | `CG_CalcViewValues` | first-person follow and demos look through the head, smoothed with a 30 ms moving average to hide the 7-bit steps |
| `CG_VR_InterpolateHeadStats` | `CG_InterpolatePlayerState` | interpolates the head stats like view angles |
| `CG_VR_PredictedPlayerHead` | `CG_AddPacketEntities` | in VR, puts your own head pose on your predicted entity (mirrors) |

`CG_VR_PlayerHeadReset` and `CG_VR_FollowHeadViewReset` clear the hooks' state
after a timeline jump.

## 7. Data flow

```
headset
  -> client engine: pitch and yaw offset in bits 12-25, roll in angles[ROLL], 32-bit buttons
  -> server engine: reads 32 bits for VR clients, 16 for the rest
  -> game: decodes, sets EF_VR_PLAYER, writes angles2 and the head stats
  -> snapshot to every client
  -> cgame: renders heads, smooths follow view, marks VR players
```

## 8. Compatibility

| Server engine | Client engine | Mod | Result |
|---|---|---|---|
| VR-aware | VR | VR-aware | full head tracking |
| VR-aware | flatscreen | VR-aware | normal play, sees VR heads |
| vanilla | VR | any | plays, no head tracking |
| vanilla | flatscreen | any | normal |
| VR-aware | VR | vanilla | head bits sent, mod ignores them |

## 9. Checklists

**Client engine:**

1. Register userinfo `vr` (`CVAR_USERINFO | CVAR_ROM`), `1` in VR.
2. Read `vr_support` from serverinfo.
3. When both allow it, pack pitch and yaw offset into bits 12-25 and write
   32-bit buttons.
4. Add `buttonBits` to the two `MSG_*DeltaUsercmdKey` functions.
5. Send roll in `cmd->angles[ROLL]` on 32-bit commands.

**Server engine:**

1. Set `vr_support 1` in serverinfo.
2. Track `vr` from each client's userinfo.
3. Read buttons with 32 bits for VR clients, 16 for the rest.

**Mod:** vendor the `vr_*` files and follow
[VR_INTEGRATION.md](VR_INTEGRATION.md) Steps 4 and 5.

## 10. Constants

| Constant | Value |
|---|---|
| `EF_VR_PLAYER` | `0x00000400` |
| head-bit mask | `0x03FFF000` (bits 12-25) |
| encode factor | 127 / 180 |
| decode factor | 180 / 127 |
| stat factor | 182.04 (32767 / 180) |
| pitch and yaw clamp | +-80 degrees (client and cgame) |
| roll clamp | +-60 degrees (client and cgame) |
| follow smoothing | 30 ms |
