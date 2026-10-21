/// Every NPC command console, one per admin ckey
GLOBAL_LIST_EMPTY(npc_command_consoles)

/// Order key to its order type and what the click that sends it must supply: a point, a target or nothing
GLOBAL_LIST_INIT(npc_command_orders, list(
	"move" = list(/datum/npc_order/move, "point"),
	"attack" = list(/datum/npc_order/attack, "target"),
	"hold" = list(/datum/npc_order/hold, "none"),
	"follow" = list(/datum/npc_order/follow, "target"),
	"patrol" = list(/datum/npc_order/patrol, "point"),
	"guard" = list(/datum/npc_order/guard, "point"),
	"hold_area" = list(/datum/npc_order/hold_area, "point"),
	"regroup" = list(/datum/npc_order/regroup, "point"),
	"fall_back" = list(/datum/npc_order/fall_back, "point"),
	"take_cover" = list(/datum/npc_order/take_cover, "point"),
	"clear_room" = list(/datum/npc_order/clear_room, "point"),
	"suppress" = list(/datum/npc_order/suppress, "point"),
	"fortify" = list(/datum/npc_order/fortify, "point"),
	"demolish" = list(/datum/npc_order/demolish, "point"),
	"triage" = list(/datum/npc_order/triage, "none"),
	"escort" = list(/datum/npc_order/escort, "target"),
	"stand_down" = list(/datum/npc_order/stand_down, "none"),
))

/// An admin's console for the AI humans: selection, orders, squads, personalities, relations, spawning, difficulty and debugging
/datum/npc_command_console
	var/mob/owner
	var/ckey
	var/datum/npc_command_selection/selection
	var/tab = "roster"
	/// While set, shift-clicking an AI human in the world selects it
	var/selecting_mode = FALSE
	/// Orders from a right-click go out as requests the units may refuse
	var/request_mode = FALSE
	/// Order key waiting for a click, how long to hold it back once clicked and whether it goes out as a request
	var/armed_order
	var/armed_delay = 0
	var/armed_request = FALSE
	/// Sanitised spawn settings waiting for clicks on turfs
	var/list/pending_spawn
	/// Sanitised assign settings waiting for clicks on humans that have no brain yet
	var/list/pending_assign
	var/marquee_active = FALSE
	var/turf/marquee_start_turf
	var/list/turf/marquee_highlighted_turfs
	/// Order key to the world time it may be sent again
	var/list/order_cooldowns = list()
	/// Skips the rights check, only unit tests set it
	var/access_override = FALSE
	var/last_report
	var/filter_text = ""
	var/filter_faction = ""
	var/filter_role = ""
	var/sort_key = "name"
	var/sort_desc = FALSE
	var/page = 1
	var/list/roster_snapshot
	var/snapshot_time = -1000
	var/list/roster_view
	var/view_key
	var/datum/weakref/inspect_ref
	var/orders_sent = 0
	var/orders_refused = 0

/datum/npc_command_console/New(mob/user)
	owner = user
	ckey = user?.ckey
	selection = new
	if(ckey)
		GLOB.npc_command_consoles[ckey] = src

/datum/npc_command_console/Destroy()
	release_intercept()
	end_marquee()
	SStgui.close_uis(src)
	if(ckey && GLOB.npc_command_consoles[ckey] == src)
		GLOB.npc_command_consoles -= ckey
	QDEL_NULL(selection)
	owner = null
	roster_snapshot = null
	roster_view = null
	return ..()

/datum/npc_command_console/proc/is_admin(mob/user)
	if(access_override)
		return TRUE
	return user?.client && check_client_rights(user.client, R_SPAWN, FALSE)

/**
 * Admins command every AI human. Anyone else gets in only as the senior staff of a faction, and the selection is then held to that faction,
 * which is checked here on every use so a commander who dies or changes job loses the panel at once.
 */
/datum/npc_command_console/proc/has_access(mob/user)
	if(is_admin(user))
		selection.faction_scope = null
		return TRUE
	var/scope = human_ai_command_faction(user)
	selection.faction_scope = scope || HAI_COMMAND_NO_SCOPE
	return !!scope

/datum/npc_command_console/proc/owner_client()
	return ckey ? GLOB.directory[ckey] : null

/datum/npc_command_console/tgui_interact(mob/user, datum/tgui/ui)
	if(!has_access(user))
		return
	owner = user
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "NpcCommandConsole", "NPC Command")
		ui.open()
	sync_click_intercept()

/datum/npc_command_console/ui_state(mob/user)
	return GLOB.always_state

/datum/npc_command_console/ui_close(mob/user)
	. = ..()
	armed_order = null
	pending_spawn = null
	pending_assign = null
	selecting_mode = FALSE
	release_intercept()
	end_marquee()

/datum/npc_command_console/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	return handle_action(ui.user, action, params)

/// Whether a click should reach the console: something is selected, an order or a spawn is armed or shift-click selecting is on
/datum/npc_command_console/proc/wants_intercept()
	return length(selection.selected) || armed_order || pending_spawn || pending_assign || selecting_mode

/datum/npc_command_console/proc/sync_click_intercept()
	var/client/target = owner_client()
	if(!target)
		return
	if(wants_intercept())
		target.click_intercept = src
	else if(target.click_intercept == src)
		target.click_intercept = null

/datum/npc_command_console/proc/release_intercept()
	var/client/target = owner_client()
	if(target?.click_intercept == src)
		target.click_intercept = null

/datum/npc_command_console/proc/refresh()
	roster_view = null
	SStgui.update_uis(src)

/// A living mob in the world, an AI human or not, that a click picked out
/datum/npc_command_console/proc/pick_human(atom/clicked)
	var/mob/living/carbon/human/human = clicked
	return istype(human) && selection.valid(human) ? human : null

/**
 * Click handling while the console is armed or has a selection. A left click is never taken unless an order is waiting
 * for it. A right click orders the selection: attack a living mob that is not on its side, follow one that is, otherwise move to the turf.
 */
/datum/npc_command_console/proc/InterceptClickOn(mob/user, params, atom/target)
	if(!has_access(user))
		release_intercept()
		return FALSE
	var/list/modifiers = params2list(params)
	var/right = LAZYACCESS(modifiers, RIGHT_CLICK)
	var/shift = LAZYACCESS(modifiers, SHIFT_CLICK)

	if(pending_spawn)
		if(right)
			pending_spawn = null
			sync_click_intercept()
			refresh()
			return TRUE
		do_spawn(user, get_turf(target), pending_spawn)
		return TRUE

	if(pending_assign)
		if(right)
			pending_assign = null
			sync_click_intercept()
			refresh()
			return TRUE
		do_assign(user, target, pending_assign)
		return TRUE

	if(armed_order)
		var/order_key = armed_order
		var/delay = armed_delay
		var/request = armed_request
		armed_order = null
		armed_delay = 0
		armed_request = FALSE
		sync_click_intercept()
		refresh()
		if(right)
			return TRUE
		send_order(user, order_key, target, get_turf(target), request, delay)
		return TRUE

	if(selecting_mode && shift && !right)
		var/mob/living/carbon/human/human = pick_human(target)
		if(!human)
			return FALSE
		selection.toggle(human)
		sync_click_intercept()
		refresh()
		return TRUE

	if(!right || !length(selection.get_selected()))
		return FALSE
	var/order_key = "move"
	var/mob/living/living_target = target
	if(istype(living_target) && living_target.stat != DEAD)
		var/mob/living/carbon/human/lead = selection.selected[1]
		order_key = (living_target.faction == lead.faction) ? "follow" : "attack"
	send_order(user, order_key, target, get_turf(target), request_mode, 0)
	return TRUE

/// Sends the order now or after the delay, and tells the admin how it went
/datum/npc_command_console/proc/send_order(mob/user, order_key, atom/target, turf/where, request = FALSE, delay = 0)
	var/list/entry = GLOB.npc_command_orders[order_key]
	if(!entry || world.time < order_cooldowns[order_key])
		return null
	var/list/humans = selection.get_selected()
	if(!length(humans))
		return null
	order_cooldowns[order_key] = world.time + HAI_COMMAND_ORDER_COOLDOWN
	if(delay > 0)
		delay = min(delay, HAI_COMMAND_MAX_DELAY)
		var/list/refs = list()
		for(var/mob/living/carbon/human/human as anything in humans)
			refs += WEAKREF(human)
		addtimer(CALLBACK(src, PROC_REF(send_delayed), user, refs, order_key, WEAKREF(target), where, request), delay SECONDS)
		to_chat(user, SPAN_NOTICE("Order staged, firing in [delay] second\s."))
		return list("accepted" = 0, "refused" = 0, "staged" = length(humans))
	return dispatch_order(user, humans, order_key, target, where, request)

/datum/npc_command_console/proc/send_delayed(mob/user, list/refs, order_key, datum/weakref/target_ref, turf/where, request)
	if(QDELETED(src))
		return
	var/list/humans = list()
	for(var/datum/weakref/ref as anything in refs)
		var/mob/living/carbon/human/human = ref.resolve()
		if(selection.valid(human))
			humans += human
	if(!length(humans))
		return
	dispatch_order(user, humans, order_key, target_ref?.resolve(), where, request)

/// Builds the order for the key and the click that came with it
/datum/npc_command_console/proc/build_order(order_key, atom/target, turf/where, turf/origin)
	var/list/entry = GLOB.npc_command_orders[order_key]
	if(!entry)
		return null
	var/order_type = entry[1]
	var/datum/npc_order/order = new order_type
	order.issuer = ckey || "panel"
	switch(entry[2])
		if("point")
			if(!where)
				qdel(order)
				return null
			order.target_turf = where
		if("target")
			if(!target || QDELETED(target))
				qdel(order)
				return null
			order.set_target(target)
			order.target_turf = get_turf(target)
	if(order_key == "patrol")
		order.waypoints = list(origin || where, where)
	return order

/// Hands the order to the humans: whole squads through the squad so they keep their formation, the rest one by one
/datum/npc_command_console/proc/dispatch_order(mob/user, list/humans, order_key, atom/target, turf/where, request = FALSE)
	var/delivery = request ? HAI_DELIVERY_REQUEST : HAI_DELIVERY_COMMAND
	var/accepted = 0
	var/refused = 0
	var/turf/origin = get_turf(humans[1])
	var/list/handled = list()
	var/slot = 0
	for(var/mob/living/carbon/human/human as anything in humans)
		if(human in handled)
			continue
		var/datum/human_ai_brain/brain = human.ai_brain
		var/datum/human_ai_squad/squad = brain.squad
		if(squad && length(squad.members) > 1 && squad_selected(squad, humans))
			var/datum/npc_order/squad_order = build_order(order_key, target, where, origin)
			if(!squad_order)
				continue
			var/members = 0
			for(var/datum/human_ai_brain/member as anything in squad.members)
				if(squad.member_valid(member))
					members++
					handled += member.body
			var/took = squad.issue_order(squad_order, delivery)
			accepted += took
			refused += max(0, members - took)
			continue
		var/datum/npc_order/order = build_order(order_key, target, where, origin)
		if(!order)
			continue
		order.slot = slot
		slot++
		handled += human
		if(brain.give_order(order, delivery))
			accepted++
		else
			refused++
	orders_sent += accepted + refused
	orders_refused += refused
	last_report = "[order_key]: [accepted] obeyed, [refused] refused"
	HAI_LOG("panel [ckey] sent [order_key] as [request ? "request" : "command"]: [accepted] obeyed, [refused] refused")
	if(user)
		to_chat(user, SPAN_NOTICE("[last_report]."))
	refresh()
	return list("accepted" = accepted, "refused" = refused)

/// Whether every living member of the squad is in the list
/datum/npc_command_console/proc/squad_selected(datum/human_ai_squad/squad, list/humans)
	for(var/datum/human_ai_brain/member as anything in squad.members)
		if(squad.member_valid(member) && !(member.body in humans))
			return FALSE
	return TRUE

/datum/npc_command_console/proc/resolve_human(ref)
	var/mob/living/carbon/human/human = locate(ref) in GLOB.ai_human_list
	return selection.valid(human) ? human : null

/// Whether the squad is one this panel may see: all of them for an admin, otherwise those with a member of the faction the panel is held to
/datum/npc_command_console/proc/squad_in_scope(datum/human_ai_squad/squad)
	if(!selection.faction_scope)
		return TRUE
	for(var/datum/human_ai_brain/member as anything in squad.members)
		if(!QDELETED(member.body) && member.body.faction == selection.faction_scope)
			return TRUE
	return FALSE

/datum/npc_command_console/proc/resolve_squad(ref)
	RETURN_TYPE(/datum/human_ai_squad)
	var/datum/human_ai_squad/squad = locate(ref) in GLOB.human_ai_squads
	return (squad && squad_in_scope(squad)) ? squad : null

/// Every control on the panel comes through here, the rights are checked again on each one
/datum/npc_command_console/proc/handle_action(mob/user, action, list/params)
	if(!has_access(user))
		return FALSE
	var/admin = is_admin(user)
	if(!admin && (action in GLOB.npc_command_admin_actions))
		return FALSE
	if(!islist(params))
		params = list()
	switch(action)
		if("set_tab")
			if(params["tab"] in (admin ? list("roster", "squads", "orders", "personality", "relations", "population", "spawner", "difficulty", "debug") : GLOB.npc_command_commander_tabs))
				tab = params["tab"]
			return TRUE
		if("toggle_select")
			var/mob/living/carbon/human/human = resolve_human(params["ref"])
			if(human)
				selection.toggle(human)
			sync_click_intercept()
			refresh()
			return TRUE
		if("select_all")
			selection.select_list(filtered_humans())
			sync_click_intercept()
			refresh()
			return TRUE
		if("select_none")
			selection.clear()
			sync_click_intercept()
			refresh()
			return TRUE
		if("select_squad")
			var/datum/human_ai_squad/squad = resolve_squad(params["ref"])
			if(squad)
				for(var/datum/human_ai_brain/member as anything in squad.members)
					selection.select(member.body)
			sync_click_intercept()
			refresh()
			return TRUE
		if("toggle_selecting_mode")
			selecting_mode = !selecting_mode
			sync_click_intercept()
			refresh()
			return TRUE
		if("toggle_marquee_mode")
			toggle_marquee_mode(user)
			refresh()
			return TRUE
		if("toggle_request_mode")
			request_mode = !request_mode
			refresh()
			return TRUE
		if("set_filter")
			filter_text = copytext(sanitize("[params["text"]]"), 1, 40)
			filter_faction = "[params["faction"]]"
			filter_role = "[params["role"]]"
			page = 1
			refresh()
			return TRUE
		if("set_sort")
			var/key = params["key"]
			if(key in list("name", "faction", "role", "squad", "personality", "health", "ammo", "stress", "intent"))
				if(sort_key == key)
					sort_desc = !sort_desc
				else
					sort_key = key
					sort_desc = FALSE
				refresh()
			return TRUE
		if("set_page")
			page = max(1, round(text2num(params["page"])))
			refresh()
			return TRUE
		if("jump")
			var/mob/living/carbon/human/human = resolve_human(params["ref"])
			if(human && isobserver(user))
				user.forceMove(get_turf(human))
			return TRUE
		if("observe")
			var/mob/living/carbon/human/human = resolve_human(params["ref"])
			if(human && isobserver(user))
				var/mob/dead/observer/ghost = user
				ghost.ManualFollow(human)
			return TRUE
		if("claim")
			var/mob/living/carbon/human/human = resolve_human(params["ref"])
			if(human && user.client)
				user.client.cmd_assume_direct_control(human)
			return TRUE
		if("delete")
			var/mob/living/carbon/human/human = resolve_human(params["ref"])
			if(human)
				message_admins("[key_name_admin(user)] deleted the AI human [human] with the NPC command panel.")
				qdel(human)
			refresh()
			return TRUE
		if("order")
			var/order_key = params["order"]
			if(!(order_key in GLOB.npc_command_orders))
				return TRUE
			var/list/entry = GLOB.npc_command_orders[order_key]
			var/delay = clamp(text2num(params["delay"]), 0, HAI_COMMAND_MAX_DELAY)
			var/request = !!params["request"]
			if(entry[2] == "none")
				send_order(user, order_key, null, null, request, delay)
				return TRUE
			if(!length(selection.get_selected()))
				to_chat(user, SPAN_WARNING("Select someone first."))
				return TRUE
			armed_order = order_key
			armed_delay = delay
			armed_request = request
			pending_spawn = null
			pending_assign = null
			sync_click_intercept()
			to_chat(user, SPAN_NOTICE("Click [entry[2] == "target" ? "a target" : "a place"] for the [order_key] order, right-click to cancel."))
			refresh()
			return TRUE
		if("cancel_armed")
			armed_order = null
			pending_spawn = null
			pending_assign = null
			sync_click_intercept()
			refresh()
			return TRUE
		if("cancel_orders")
			for(var/mob/living/carbon/human/human as anything in selection.get_selected())
				human.ai_brain.cancel_order("panel")
			refresh()
			return TRUE
		if("cancel_order_of")
			var/mob/living/carbon/human/human = resolve_human(params["ref"])
			human?.ai_brain.cancel_order("panel")
			refresh()
			return TRUE
		if("set_roe")
			var/roe = round(text2num(params["roe"]))
			if(roe < HAI_ROE_WEAPONS_FREE || roe > HAI_ROE_NONLETHAL_ONLY)
				return TRUE
			for(var/mob/living/carbon/human/human as anything in selection.get_selected())
				human.ai_brain.roe = roe
			refresh()
			return TRUE
		if("set_move_cap")
			var/cap = round(text2num(params["cap"]))
			if(cap < HAI_MOVE_CAP_WALK || cap > HAI_MOVE_CAP_SPRINT)
				return TRUE
			for(var/mob/living/carbon/human/human as anything in selection.get_selected())
				human.ai_brain.move_cap = cap
			refresh()
			return TRUE
		if("set_posture")
			var/posture = round(text2num(params["posture"]))
			if(posture < HAI_POSTURE_CAUTIOUS || posture > HAI_POSTURE_AGGRESSIVE)
				return TRUE
			for(var/mob/living/carbon/human/human as anything in selection.get_selected())
				human.ai_brain.posture = posture
				human.ai_brain.apply_posture()
			refresh()
			return TRUE
		if("set_formation")
			var/form = round(text2num(params["formation"]))
			var/list/done = list()
			for(var/mob/living/carbon/human/human as anything in selection.get_selected())
				var/datum/human_ai_squad/squad = human.ai_brain.squad
				if(!squad || (squad in done))
					continue
				done += squad
				if(form >= HAI_FORM_WEDGE && form <= HAI_FORM_SCATTER)
					squad.formation = form
					squad.formation_locked = TRUE
				else
					squad.formation_locked = FALSE
			refresh()
			return TRUE
		if("create_squad")
			var/squad_name = copytext(sanitize("[params["name"]]"), 1, 30) || "Squad"
			var/list/bodies = selection.get_selected()
			if(length(bodies))
				create_human_ai_squad(bodies, null, squad_name)
			refresh()
			return TRUE
		if("disband_squad")
			resolve_squad(params["ref"])?.disband()
			refresh()
			return TRUE
		if("add_to_squad")
			var/datum/human_ai_squad/squad = resolve_squad(params["ref"])
			if(squad)
				for(var/mob/living/carbon/human/human as anything in selection.get_selected())
					squad.add_member(human.ai_brain)
			refresh()
			return TRUE
		if("leave_squad")
			for(var/mob/living/carbon/human/human as anything in selection.get_selected())
				human.ai_brain.squad?.remove_member(human.ai_brain, "left")
			refresh()
			return TRUE
		if("set_leader")
			var/list/chosen = selection.get_selected()
			if(length(chosen) == 1)
				var/mob/living/carbon/human/human = chosen[1]
				human.ai_brain.squad?.elect_leader(human.ai_brain)
			refresh()
			return TRUE
		if("apply_personality")
			apply_personality(user, params)
			return TRUE
		if("set_relation")
			set_relation(user, params)
			return TRUE
		if("set_faction_roe")
			set_faction_roe(user, params)
			return TRUE
		if("arm_spawn")
			arm_spawn(user, params)
			return TRUE
		if("arm_assign")
			arm_assign(user, params)
			return TRUE
		if("release_ai")
			release_selected(user)
			return TRUE
		if("set_difficulty")
			set_difficulty(user, params)
			return TRUE
		if("set_population_enabled")
			SShuman_ai_population.enabled = !!params["enabled"]
			message_admins("[key_name_admin(user)] [SShuman_ai_population.enabled ? "enabled" : "disabled"] the AI human population director.")
			refresh()
			return TRUE
		if("set_group_enabled")
			var/datum/npc_population_group/toggled = SShuman_ai_population.profile?.get_group(params["group"])
			if(toggled)
				toggled.enabled = !!params["enabled"]
				message_admins("[key_name_admin(user)] [toggled.enabled ? "enabled" : "disabled"] the population group [toggled.name].")
			refresh()
			return TRUE
		if("populate_group")
			var/datum/npc_population_group/asked = SShuman_ai_population.profile?.get_group(params["group"])
			if(asked)
				var/made = SShuman_ai_population.populate_now(asked)
				message_admins("[key_name_admin(user)] placed [made] humans of the population group [asked.name].")
			refresh()
			return TRUE
		if("set_hook_enabled")
			var/datum/npc_population_hook/hook = GLOB.npc_population_hooks["[params["hook"]]"]
			if(hook)
				hook.set_enabled(!!params["enabled"])
				message_admins("[key_name_admin(user)] [hook.enabled ? "enabled" : "disabled"] the AI human hook [hook.name].")
			refresh()
			return TRUE
		if("set_hook_forced")
			var/datum/npc_population_hook/forced_hook = GLOB.npc_population_hooks["[params["hook"]]"]
			if(forced_hook)
				forced_hook.forced = !!params["forced"]
				message_admins("[key_name_admin(user)] [forced_hook.forced ? "forced" : "stopped forcing"] the AI human hook [forced_hook.name] whatever the round.")
			refresh()
			return TRUE
		if("clear_population")
			var/removed = SShuman_ai_population.clear_all()
			message_admins("[key_name_admin(user)] cleared [removed] ambient AI humans.")
			refresh()
			return TRUE
		if("check_population")
			SShuman_ai_population.recheck()
			refresh()
			return TRUE
		if("toggle_debug")
			GLOB.ai_debug_pathing = !GLOB.ai_debug_pathing
			message_admins("[key_name_admin(user)] [GLOB.ai_debug_pathing ? "enabled" : "disabled"] human AI debugging.")
			refresh()
			return TRUE
		if("set_paused")
			SShuman_ai.paused = !!params["paused"]
			message_admins("[key_name_admin(user)] [SShuman_ai.paused ? "paused" : "resumed"] all human AI.")
			refresh()
			return TRUE
		if("inspect")
			var/mob/living/carbon/human/human = resolve_human(params["ref"])
			inspect_ref = human ? WEAKREF(human) : null
			refresh()
			return TRUE
	return FALSE

/datum/npc_command_console/proc/apply_personality(mob/user, list/params)
	var/preset = params["preset"]
	if(!(preset in GLOB.human_ai_personalities))
		return
	var/jitter = clamp(round(text2num(params["jitter"])), 0, 30)
	var/list/overrides = list()
	var/list/sent = params["traits"]
	if(islist(sent))
		for(var/key in GLOB.human_ai_trait_keys)
			if(!isnull(sent[key]) && isnum(text2num(sent[key])))
				overrides[key] = clamp(round(text2num(sent[key])), 0, 100)
	for(var/mob/living/carbon/human/human as anything in selection.get_selected())
		human.ai_brain.set_personality(preset, jitter, overrides)
	refresh()

/// Every faction the relations editor knows
/proc/human_ai_known_factions()
	var/list/factions = list()
	for(var/side in GLOB.human_ai_sides)
		factions |= GLOB.human_ai_sides[side]
	factions |= list(FACTION_COLONIST, FACTION_SURVIVOR, FACTION_NEUTRAL)
	return factions

/datum/npc_command_console/proc/set_relation(mob/user, list/params)
	var/list/factions = human_ai_known_factions()
	var/faction = params["faction"]
	var/other = params["other"]
	var/relation = round(text2num(params["relation"]))
	if(!(faction in factions) || !(other in factions) || faction == other)
		return
	if(relation < HAI_REL_FRIENDLY || relation > HAI_REL_HOSTILE)
		return
	set_human_ai_relation(GLOB.human_ai_relations, faction, other, relation)
	if(params["mirror"])
		set_human_ai_relation(GLOB.human_ai_relations, other, faction, relation)
	message_admins("[key_name_admin(user)] set the relation of [faction] toward [other] to [relation].")
	refresh()

/datum/npc_command_console/proc/set_faction_roe(mob/user, list/params)
	var/faction = params["faction"]
	var/roe = round(text2num(params["roe"]))
	if(!(faction in human_ai_known_factions()) || roe < HAI_ROE_WEAPONS_FREE || roe > HAI_ROE_NONLETHAL_ONLY)
		return
	GLOB.human_ai_faction_roe[faction] = roe
	if(params["existing"])
		for(var/mob/living/carbon/human/human as anything in GLOB.ai_human_list)
			if(human.ai_brain && human.faction == faction)
				human.ai_brain.roe = roe
	message_admins("[key_name_admin(user)] set the default rules of engagement of [faction] to [roe].")
	refresh()

/datum/npc_command_console/proc/arm_spawn(mob/user, list/params)
	var/job = params["job"]
	if(!job || !(job in GLOB.gear_name_presets_list))
		to_chat(user, SPAN_WARNING("Pick an equipment preset first."))
		return
	var/personality = params["personality"]
	if(!(personality in GLOB.human_ai_personalities))
		personality = "neutral"
	var/role = params["role"]
	if(role && !(role in GLOB.human_ai_roles))
		role = null
	var/faction = params["faction"]
	if(faction && !(faction in human_ai_known_factions()))
		faction = null
	pending_assign = null
	pending_spawn = list(
		"job" = job,
		"personality" = personality,
		"role" = role,
		"faction" = faction,
		"count" = clamp(round(text2num(params["count"])), 1, HAI_COMMAND_MAX_SPAWN),
		"range" = clamp(round(text2num(params["range"])), 0, 6),
		"squad" = !!params["squad"],
	)
	armed_order = null
	sync_click_intercept()
	to_chat(user, SPAN_NOTICE("Click a turf to spawn [pending_spawn["count"]] as [job], right-click to stop."))
	refresh()

/// Arms the click tool that hands humans already in the round a brain, the settings are checked here and not trusted from the panel
/datum/npc_command_console/proc/arm_assign(mob/user, list/params)
	var/personality = params["personality"]
	if(!(personality in GLOB.human_ai_personalities))
		personality = "neutral"
	var/role = params["role"]
	if(role && !(role in GLOB.human_ai_roles))
		role = null
	var/faction = params["faction"]
	if(faction && !(faction in human_ai_known_factions()))
		faction = null
	pending_assign = list(
		"personality" = personality,
		"role" = role,
		"faction" = faction,
		"range" = clamp(round(text2num(params["range"])), 0, 10),
		"squad" = !!params["squad"],
	)
	armed_order = null
	pending_spawn = null
	sync_click_intercept()
	to_chat(user, SPAN_NOTICE("Click a human to give it an AI, right-click to stop."))
	refresh()

/**
 * Gives a brain to the human that was clicked, or to everyone without one within the range of the click when the tool has a range, and
 * selects whoever took it so that they can be ordered at once. The tool stays armed for the next click.
 */
/datum/npc_command_console/proc/do_assign(mob/user, atom/clicked, list/settings)
	var/list/targets = list()
	var/turf/center = get_turf(clicked)
	if(!center)
		return null
	if(settings["range"])
		for(var/mob/living/carbon/human/near in range(settings["range"], center))
			if(!human_ai_attach_refusal(near))
				targets += near
	else
		var/mob/living/carbon/human/direct = clicked
		if(!istype(direct))
			for(var/mob/living/carbon/human/on_turf in center)
				direct = on_turf
				break
		if(!istype(direct))
			to_chat(user, SPAN_WARNING("Click a human."))
			return null
		var/refusal = human_ai_attach_refusal(direct)
		if(refusal)
			to_chat(user, SPAN_WARNING("No AI for that one, [refusal]."))
			return null
		targets += direct
	if(!length(targets))
		to_chat(user, SPAN_WARNING("Nobody there could be given an AI."))
		return null
	var/list/assigned = list()
	var/list/failures = list()
	for(var/mob/living/carbon/human/human as anything in targets)
		var/refusal = assign_human_ai(human, settings["personality"], settings["role"], settings["faction"])
		if(refusal)
			failures += refusal
		else
			assigned += human
	if(length(assigned) > 1 && settings["squad"])
		create_human_ai_squad(assigned, null, "Assigned squad")
	if(length(failures))
		to_chat(user, SPAN_WARNING("[length(failures)] could not be given an AI: [failures[1]]."))
	if(length(assigned))
		message_admins("[key_name_admin(user)] gave an AI to [length(assigned)] existing humans at [get_area(center)] with the NPC command panel.")
		last_report = "assign: [length(assigned)] given an AI"
		selection.select_list(assigned)
	sync_click_intercept()
	refresh()
	return assigned

/// Takes the brain off the selected humans and leaves them standing there as plain mobs
/datum/npc_command_console/proc/release_selected(mob/user)
	var/released = 0
	for(var/mob/living/carbon/human/human as anything in selection.get_selected())
		if(detach_human_ai(human))
			released++
	if(released)
		message_admins("[key_name_admin(user)] took the AI off [released] humans with the NPC command panel.")
	last_report = "release: [released] humans let go"
	sync_click_intercept()
	refresh()
	return released

/// Spawns the armed group around the turf and returns the humans that came out
/datum/npc_command_console/proc/do_spawn(mob/user, turf/center, list/settings)
	if(!center || !(settings["job"] in GLOB.gear_name_presets_list))
		return null
	var/list/turfs = list()
	if(settings["range"])
		for(var/turf/candidate in range(settings["range"], center))
			if(is_valid_admin_spawn_turf(candidate))
				turfs += candidate
	else if(is_valid_admin_spawn_turf(center))
		turfs += center
	if(!length(turfs))
		return null
	var/list/spawned = list()
	var/failures = 0
	for(var/index in 1 to settings["count"])
		var/mob/living/carbon/human/human = new(pick(turfs))
		if(!human.hud_used)
			human.create_hud()
		arm_equipment(human, settings["job"], TRUE, FALSE)
		if(settings["faction"])
			human.faction = settings["faction"]
		if(!attach_human_ai(human, settings["personality"]))
			failures++
			continue
		if(settings["role"])
			human.ai_brain.set_role(settings["role"])
			human.ai_brain.role.equip_kit(human.ai_brain)
		spawned += human
	if(length(spawned) > 1 && settings["squad"])
		create_human_ai_squad(spawned, null, "[settings["job"]] squad")
	if(failures)
		to_chat(user, SPAN_WARNING("[failures] humans spawned without AI, the population cap [SShuman_ai.max_total] was reached."))
	message_admins("[key_name_admin(user)] spawned [length(spawned)] AI humans ([settings["job"]]) at [get_area(center)] with the NPC command panel.")
	selection.select_list(spawned)
	sync_click_intercept()
	refresh()
	return spawned

/datum/npc_command_console/proc/set_difficulty(mob/user, list/params)
	if(!isnull(params["auto_scale"]))
		SShuman_ai.auto_scale = !!params["auto_scale"]
		SShuman_ai.next_scale_time = 0
		SShuman_ai.scale_players = -1
	else if(!isnull(params["aim_error"]) || !isnull(params["reaction"]) || !isnull(params["aggression"]))
		SShuman_ai.auto_scale = FALSE
	if(!isnull(params["aim_error"]))
		SShuman_ai.aim_error_mult = clamp(text2num(params["aim_error"]), 0.25, 4)
	if(!isnull(params["reaction"]))
		SShuman_ai.reaction_mult = clamp(text2num(params["reaction"]), 0.25, 4)
	if(!isnull(params["aggression"]))
		SShuman_ai.aggression_bias = clamp(text2num(params["aggression"]), -1, 1)
		for(var/datum/human_ai_brain/brain as anything in SShuman_ai.brains)
			brain.apply_posture()
	if(!isnull(params["max_full"]))
		SShuman_ai.max_full = clamp(round(text2num(params["max_full"])), 1, 300)
	if(!isnull(params["max_total"]))
		SShuman_ai.max_total = clamp(round(text2num(params["max_total"])), 1, 500)
	message_admins("[key_name_admin(user)] changed the human AI difficulty: aim error [SShuman_ai.aim_error_mult], reaction [SShuman_ai.reaction_mult], aggression [SShuman_ai.aggression_bias], caps [SShuman_ai.max_full]/[SShuman_ai.max_total].")
	refresh()

/// Opens the console of the admin, making one if they have none yet
/proc/open_npc_command_console(mob/user)
	var/datum/npc_command_console/console = GLOB.npc_command_consoles[user.ckey]
	if(!console || QDELETED(console))
		console = new(user)
	console.tgui_interact(user)

/client/proc/npc_command_console()
	set name = "NPC Command Console"
	set category = "Admin.Events"
	if(!check_rights(R_SPAWN))
		return
	open_npc_command_console(usr)
