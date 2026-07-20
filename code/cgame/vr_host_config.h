// Vendored VR API - host configuration. This is the ONE file in the drop
// the host tree is meant to edit: it tells vr_cgame.c which optional host
// features exist. Everything else in the drop keeps the never-edit rule.
#ifndef __VR_HOST_CONFIG_H
#define __VR_HOST_CONFIG_H

// Stock tree: no TrinityVision TV playback.
#define VR_HOST_HAS_TV 0

// Stock tree: no warmup announcer events fired from the HUD pass.
#define VR_HOST_HAS_WARMUP_EVENTS 0

// Stock tree: the grapple is not handed out per server and has no mover hold.
#define VR_HOST_HAS_GRAPPLE 0

// Stock tree: no render-pose trace; view-path traces go through CG_Trace.
#define VR_HOST_HAS_TRACE_RENDER 0

// Stock trees map the drop's Q_sscanf onto bg_lib's sscanf (its
// terminating-character consumption handles the "%f,%f,..." formats).
#define Q_sscanf sscanf

// Optional: the weapon wheel's default set - what "*" and an empty
// cg_weaponSelectorWeapons expand to - in the cvar's token language.
// Tokens are whitespace-separated (commas are not separators); a token is
// a weapon_t number or an item classname with or without the weapon_
// prefix ("rocketlauncher", "weapon_railgun", "5"). "*" expands the
// default set ("*" here means the built-in set); "!name" hides a weapon
// from later mentions and expansions; first mention wins. A list of only
// exclusions means the default set minus those weapons.
// Unset: the built-in set (every weapon except the gauntlet and the
// grappling hook).
//#define VR_WHEEL_DEFAULT_WEAPONS "*"

#endif
