# Per-module source lists. Order matters twice: the module main file must be
# first (its vmMain must be the first proc q3asm emits), and the hand-written
# *_syscalls.asm is passed through to q3asm verbatim (never compiled).
# The lists are stock ioq3's QVM sets.

QA_SRC = g_main $(QADIR)/g_syscalls.asm \
  ai_chat ai_cmd ai_dmnet ai_dmq3 ai_main ai_team ai_vcmd \
  bg_misc bg_pmove bg_slidemove bg_lib \
  g_active g_arenas g_bot g_client g_cmds g_combat g_items g_mem g_misc \
  g_missile g_mover g_session g_spawn g_svcmds g_target g_team g_trigger \
  g_utils g_weapon vr_bg vr_game \
  q_math q_shared

ifeq ($(CONFIG),missionpack)

CG_SRC = cg_main $(CGDIR)/cg_syscalls.asm \
  bg_misc bg_pmove bg_slidemove bg_lib \
  cg_consolecmds cg_newdraw cg_draw cg_drawtools cg_effects cg_ents \
  cg_event cg_info cg_localents cg_marks cg_particles cg_players \
  cg_playerstate cg_predict cg_scoreboard cg_servercmds cg_snapshot \
  cg_view vr_cgame cg_weapons ui_shared vr_uishared \
  vr_bg vr_platform \
  q_math q_shared

UI_SRC = ui_main $(UIDIR)/ui_syscalls.asm \
  ui_atoms ui_gameinfo ui_players ui_shared vr_ui vr_uishared \
  bg_misc bg_lib vr_bg vr_platform \
  q_math q_shared

else

CG_SRC = cg_main $(CGDIR)/cg_syscalls.asm \
  bg_misc bg_pmove bg_slidemove bg_lib \
  cg_consolecmds cg_draw cg_drawtools cg_effects cg_ents cg_event \
  cg_info cg_localents cg_marks cg_particles cg_players cg_playerstate \
  cg_predict cg_scoreboard cg_servercmds cg_snapshot cg_view vr_cgame \
  cg_weapons vr_bg vr_platform \
  q_math q_shared

# Stock has no q3_ui syscalls file; the baseq3 UI links code/ui's.
UI_SRC = ui_main $(TAUIDIR)/ui_syscalls.asm \
  ui_addbots ui_atoms ui_cdkey ui_cinematics ui_confirm ui_connect \
  ui_controls2 ui_credits ui_demo2 ui_display ui_gameinfo ui_ingame \
  ui_loadconfig ui_menu ui_mfield ui_mods ui_network ui_options \
  ui_playermodel ui_players ui_playersettings ui_preferences ui_qmenu \
  ui_removebots ui_saveconfig ui_serverinfo ui_servers2 ui_setup \
  ui_sound ui_sparena ui_specifyserver ui_splevel ui_sppostgame \
  ui_spskill ui_startserver ui_team ui_teamorders ui_video \
  ui_vrcomfort ui_vrcontrols ui_vrhud_display ui_vrmirror ui_vroptions vr_ui \
  bg_misc bg_lib vr_bg vr_platform \
  q_math q_shared

endif
