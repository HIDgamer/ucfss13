/**
 * The NPC command panel: one window for everything that is run by an AI. It has a side for the AI humans (the NPC command console) and a side for the hive's
 * AI xenos (the hive command console), switched at the top. What each side does is still done by its own console, the panel only hosts the window, hands
 * the data and the controls to the side that is showing, and keeps the click intercept with the side that is showing.
 *
 * Admins have both sides. Senior staff of a human faction have the human side held to their faction, a hive leader has the xeno side for their own hive.
 */

/// Every NPC command panel, one per ckey
GLOBAL_LIST_EMPTY(npc_command_panels)

/datum/npc_command_panel
	var/mob/owner
	var/ckey
	var/mode = NPC_PANEL_HUMANS
	var/datum/npc_command_console/humans
	var/datum/xeno_command_console/xenos
	/// Whether the panel made the hive console itself, and so has to clean it up, or borrowed a hive leader's own
	var/owns_xenos = FALSE

/datum/npc_command_panel/New(mob/user)
	set_owner(user)
	ckey = user?.ckey
	var/datum/npc_command_console/old = ckey ? GLOB.npc_command_consoles[ckey] : null
	if(old && !QDELETED(old))
		qdel(old)
	humans = new(user)
	humans.panel_ref = WEAKREF(src)
	if(ckey)
		GLOB.npc_command_panels[ckey] = src

/datum/npc_command_panel/Destroy()
	SStgui.close_uis(src)
	if(ckey && GLOB.npc_command_panels[ckey] == src)
		GLOB.npc_command_panels -= ckey
	QDEL_NULL(humans)
	drop_xenos()
	set_owner(null)
	return ..()

/// Whose panel it is, who is not kept from being freed by a panel that lives for the whole round
/datum/npc_command_panel/proc/set_owner(mob/new_owner)
	if(owner == new_owner)
		return
	if(owner)
		UnregisterSignal(owner, COMSIG_PARENT_QDELETING)
	owner = new_owner
	if(owner)
		RegisterSignal(owner, COMSIG_PARENT_QDELETING, PROC_REF(on_owner_deleted))

/datum/npc_command_panel/proc/on_owner_deleted(datum/source)
	SIGNAL_HANDLER
	owner = null

/// Lets go of the hive console, deleting it when the panel was the one to make it
/datum/npc_command_panel/proc/drop_xenos()
	if(!xenos)
		return
	UnregisterSignal(xenos, COMSIG_PARENT_QDELETING)
	xenos.release_intercept()
	xenos.panel_ref = null
	if(owns_xenos)
		qdel(xenos)
	xenos = null
	owns_xenos = FALSE

/datum/npc_command_panel/proc/on_xenos_deleted(datum/source)
	SIGNAL_HANDLER
	xenos = null
	owns_xenos = FALSE

/// Takes a hive console for the xeno side
/datum/npc_command_panel/proc/use_xenos(datum/xeno_command_console/console, made_here = FALSE)
	if(xenos == console)
		return
	drop_xenos()
	xenos = console
	owns_xenos = made_here
	xenos.panel_ref = WEAKREF(src)
	RegisterSignal(xenos, COMSIG_PARENT_QDELETING, PROC_REF(on_xenos_deleted))

/// Whether the user may use the human side
/datum/npc_command_panel/proc/can_humans(mob/user)
	return humans?.has_access(user)

/// Whether the user may use the xeno side: an admin, or a leader of a hive
/datum/npc_command_panel/proc/can_xenos(mob/user)
	if(humans?.is_admin(user))
		return TRUE
	var/mob/living/carbon/xenomorph/leader = user
	return istype(leader) && IS_XENO_LEADER(leader) && !!leader.hive

/// Makes the xeno side ready for a user who is a hive leader, with the console the leader keeps
/datum/npc_command_panel/proc/bind_leader_hive(mob/user)
	var/mob/living/carbon/xenomorph/leader = user
	if(!istype(leader) || !IS_XENO_LEADER(leader) || !leader.hive || humans.is_admin(user))
		return
	if(!leader.hive_command_console)
		leader.hive_command_console = new(leader, leader.hive, FALSE)
	use_xenos(leader.hive_command_console)

/// Shows the side, false when the user has no right to it
/datum/npc_command_panel/proc/switch_mode(mob/user, new_mode)
	if(new_mode == mode)
		return TRUE
	if(new_mode == NPC_PANEL_XENOS && !can_xenos(user))
		return FALSE
	if(new_mode == NPC_PANEL_HUMANS && !can_humans(user))
		return FALSE
	if(new_mode != NPC_PANEL_XENOS && new_mode != NPC_PANEL_HUMANS)
		return FALSE
	// The side that goes out of sight stops taking clicks
	if(mode == NPC_PANEL_HUMANS)
		humans.release_intercept()
	else
		xenos?.release_intercept()
	mode = new_mode
	if(mode == NPC_PANEL_XENOS)
		bind_leader_hive(user)
		xenos?.sync_click_intercept()
	else
		humans.sync_click_intercept()
	update_static_data_for_all_viewers()
	return TRUE

/// Opens the window for the user, on the side asked for when the user may have it and on a side the user may have otherwise
/datum/npc_command_panel/proc/open(mob/user, wanted_mode)
	set_owner(user)
	var/humans_ok = can_humans(user)
	var/xenos_ok = can_xenos(user)
	if(!humans_ok && !xenos_ok)
		return FALSE
	var/target = wanted_mode || mode
	if((target == NPC_PANEL_XENOS && !xenos_ok) || (target == NPC_PANEL_HUMANS && !humans_ok))
		target = humans_ok ? NPC_PANEL_HUMANS : NPC_PANEL_XENOS
	if(target == NPC_PANEL_XENOS && !humans_ok)
		bind_leader_hive(user)
	if(target != mode)
		switch_mode(user, target)
	else if(mode == NPC_PANEL_XENOS)
		bind_leader_hive(user)
	tgui_interact(user)
	return TRUE

/datum/npc_command_panel/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "NpcCommandPanel", "NPC Command Panel")
		ui.open()
	if(mode == NPC_PANEL_HUMANS)
		humans.sync_click_intercept()
	else
		xenos?.sync_click_intercept()

/datum/npc_command_panel/ui_state(mob/user)
	return GLOB.always_state

/datum/npc_command_panel/ui_close(mob/user)
	. = ..()
	humans?.ui_close(user)
	xenos?.ui_close(user)

/// The side that is showing, or what to say when there is nothing to show yet
/datum/npc_command_panel/ui_data(mob/user)
	var/humans_ok = can_humans(user)
	var/xenos_ok = can_xenos(user)
	// A side the user lost the right to is not left showing
	if(mode == NPC_PANEL_XENOS && !xenos_ok && humans_ok)
		mode = NPC_PANEL_HUMANS
	else if(mode == NPC_PANEL_HUMANS && !humans_ok && xenos_ok)
		mode = NPC_PANEL_XENOS
	var/list/data
	if(mode == NPC_PANEL_XENOS)
		data = xenos ? xenos.ui_data(user) : list("needs_hive" = TRUE)
	else
		data = humans.ui_data(user)
	data["panel_mode"] = mode
	data["panel_humans"] = !!humans_ok
	data["panel_xenos"] = !!xenos_ok
	return data

/datum/npc_command_panel/ui_static_data(mob/user)
	var/list/data
	if(mode == NPC_PANEL_XENOS)
		data = xenos ? xenos.ui_static_data(user) : list()
		if(can_xenos(user) && humans.is_admin(user))
			data["available_hives"] = hive_choices()
	else
		data = humans.ui_static_data(user)
	return data

/// The hives an admin may pick from, as list(name, hivenumber)
/datum/npc_command_panel/proc/hive_choices()
	var/list/choices = list()
	for(var/hivenumber in GLOB.hive_datum)
		var/datum/hive_status/hive = GLOB.hive_datum[hivenumber]
		choices += list(list("name" = hive.name, "number" = "[hivenumber]"))
	return choices

/datum/npc_command_panel/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	return handle_action(ui.user, action, params)

/// Every control comes through here: the panel's own two and then whatever the side that is showing does
/datum/npc_command_panel/proc/handle_action(mob/user, action, list/params)
	if(!islist(params))
		params = list()
	switch(action)
		if("set_panel_mode")
			switch_mode(user, params["mode"])
			return TRUE
		if("pick_hive")
			if(!humans.is_admin(user))
				return FALSE
			var/datum/hive_status/hive = GLOB.hive_datum[params["hive"]] || GLOB.hive_datum[text2num(params["hive"])]
			if(!hive)
				return FALSE
			use_xenos(new /datum/xeno_command_console(user, hive, TRUE), TRUE)
			xenos.sync_click_intercept()
			update_static_data_for_all_viewers()
			return TRUE
	if(mode == NPC_PANEL_XENOS)
		return xenos ? xenos.handle_action(user, action, params) : FALSE
	return humans.handle_action(user, action, params)

/// Opens the panel of the user on a side, making the panel if the user has none yet. False when the user has no right to any side
/proc/open_npc_panel_for(mob/user, wanted_mode)
	if(!user?.ckey)
		return FALSE
	var/datum/npc_command_panel/panel = GLOB.npc_command_panels[user.ckey]
	if(!panel || QDELETED(panel))
		panel = new(user)
	return panel.open(user, wanted_mode)

/client/proc/npc_command_panel()
	set name = "NPC Command Panel"
	set category = "Admin.Events"
	if(!check_rights(R_SPAWN))
		return
	open_npc_panel_for(usr, NPC_PANEL_HUMANS)
