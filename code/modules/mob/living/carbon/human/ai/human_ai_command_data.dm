/// One row of the roster for a human, everything the panel shows about it
/datum/npc_command_console/proc/roster_entry(mob/living/carbon/human/human)
	var/datum/human_ai_brain/brain = human.ai_brain
	var/ammo
	var/obj/item/weapon/gun/gun = brain.peek_gun()
	if(gun)
		var/capacity = brain.gun_capacity(gun)
		ammo = capacity > 0 ? clamp(round(brain.gun_rounds(gun) / capacity * 100), 0, 100) : null
	return list(
		"ref" = REF(human),
		"name" = human.real_name,
		"faction" = human.faction,
		"role" = brain.role?.id || "none",
		"squad" = brain.squad?.name || "",
		"personality" = brain.personality.id,
		"health" = clamp(round(human.health / max(human.maxHealth, 1) * 100), 0, 100),
		"ammo" = ammo,
		"stress" = round(brain.stress),
		"intent" = brain.intent_name(),
		"tier" = brain.tier,
		"order" = brain.current_order?.id || "",
		"refused" = (world.time < brain.last_refused_time + 100) ? brain.last_refused_order : "",
		"area" = get_area_name(human),
		"dead" = human.stat == DEAD,
	)

/// The roster rows for every AI human, rebuilt at most once per second
/datum/npc_command_console/proc/get_snapshot()
	if(roster_snapshot && world.time < snapshot_time + HAI_COMMAND_SNAPSHOT_TIME)
		return roster_snapshot
	roster_snapshot = list()
	for(var/mob/living/carbon/human/human as anything in GLOB.ai_human_list)
		if(!selection.valid(human))
			continue
		roster_snapshot += list(roster_entry(human))
	snapshot_time = world.time
	roster_view = null
	return roster_snapshot

/// The snapshot rows that pass the filters, sorted
/datum/npc_command_console/proc/get_view()
	var/list/snapshot = get_snapshot()
	var/key = "[filter_text]|[filter_faction]|[filter_role]|[sort_key]|[sort_desc]|[snapshot_time]"
	if(roster_view && view_key == key)
		return roster_view
	var/list/rows = list()
	for(var/list/row as anything in snapshot)
		if(filter_faction && row["faction"] != filter_faction)
			continue
		if(filter_role && row["role"] != filter_role)
			continue
		if(filter_text && !findtext(row["name"], filter_text) && !findtext(row["personality"], filter_text) && !findtext(row["squad"], filter_text))
			continue
		rows += list(row)
	rows = sort_rows(rows)
	roster_view = rows
	view_key = key
	return rows

GLOBAL_VAR_INIT(npc_roster_sort_key, "name")

/proc/cmp_npc_roster_asc(list/a, list/b)
	var/left = a[GLOB.npc_roster_sort_key]
	var/right = b[GLOB.npc_roster_sort_key]
	if(isnum(left) && isnum(right))
		return left - right
	return sorttext("[right]", "[left]")

/datum/npc_command_console/proc/sort_rows(list/rows)
	GLOB.npc_roster_sort_key = sort_key
	var/list/sorted = sortTim(rows.Copy(), GLOBAL_PROC_REF(cmp_npc_roster_asc))
	return sort_desc ? reverseRange(sorted) : sorted

/// The humans the roster currently lists, for the select all button
/datum/npc_command_console/proc/filtered_humans()
	var/list/humans = list()
	for(var/list/row as anything in get_view())
		var/mob/living/carbon/human/human = locate(row["ref"]) in GLOB.ai_human_list
		if(human)
			humans += human
	return humans

/datum/npc_command_console/ui_static_data(mob/user)
	var/list/data = list()
	var/list/orders = list()
	for(var/key in GLOB.npc_command_orders)
		var/list/entry = GLOB.npc_command_orders[key]
		var/datum/npc_order/sample = entry[1]
		orders += list(list("key" = key, "name" = initial(sample.name), "needs" = entry[2]))
	data["orders"] = orders
	data["personalities"] = list()
	for(var/id in GLOB.human_ai_personalities)
		var/datum/human_ai_personality/preset = GLOB.human_ai_personalities[id]
		data["personalities"] += list(list("id" = id, "name" = preset.name, "desc" = preset.desc, "traits" = preset.traits))
	data["trait_keys"] = GLOB.human_ai_trait_keys
	data["roles"] = list()
	for(var/id in GLOB.human_ai_roles)
		data["roles"] += id
	data["factions"] = human_ai_known_factions()
	data["jobs"] = list()
	for(var/job in GLOB.gear_name_presets_list)
		data["jobs"] += job
	return data

/datum/npc_command_console/ui_data(mob/user)
	var/list/data = list()
	if(!has_access(user))
		return data
	var/admin = is_admin(user)
	if(!admin && !(tab in GLOB.npc_command_commander_tabs))
		tab = "roster"
	data["restricted"] = !admin
	data["faction_scope"] = selection.faction_scope
	data["tab"] = tab
	data["selecting_mode"] = selecting_mode
	data["request_mode"] = request_mode
	data["marquee_active"] = marquee_active
	data["armed_order"] = armed_order
	data["armed_spawn"] = !!pending_spawn
	data["armed_assign"] = !!pending_assign
	data["selected_count"] = length(selection.selected)
	data["last_report"] = last_report
	data["paused"] = SShuman_ai.paused
	data["brains"] = admin ? length(SShuman_ai.brains) : length(get_snapshot())
	data["page_size"] = HAI_COMMAND_PAGE_SIZE
	switch(tab)
		if("roster")
			data += roster_data()
		if("squads")
			data["squads"] = squad_data()
		if("orders")
			data["active_orders"] = order_data()
		if("personality")
			data["stances"] = stance_data()
		if("relations")
			data["relations"] = relation_data()
		if("population")
			data["population"] = population_data()
		if("difficulty")
			data["difficulty"] = list(
				"aim_error" = SShuman_ai.aim_error_mult,
				"reaction" = SShuman_ai.reaction_mult,
				"aggression" = SShuman_ai.aggression_bias,
				"detection" = SShuman_ai.detection_mult,
				"markers" = SShuman_ai.stealth_cues,
				"max_full" = SShuman_ai.max_full,
				"max_total" = SShuman_ai.max_total,
				"full" = SShuman_ai.full_count,
				"auto_scale" = SShuman_ai.auto_scale,
				"table" = GLOB.human_ai_difficulty_table,
				"scale_players" = SShuman_ai.scale_players,
				"slowdown" = round(SShuman_ai.arbiter_multiplier, 0.01),
				"load" = round(SShuman_ai.arbiter_load, 0.01),
			)
		if("debug")
			data["debug"] = debug_data()
	return data

/datum/npc_command_console/proc/roster_data()
	var/list/list/rows = get_view()
	var/pages = max(1, -round(-length(rows) / HAI_COMMAND_PAGE_SIZE))
	page = clamp(page, 1, pages)
	var/list/shown = list()
	var/first = (page - 1) * HAI_COMMAND_PAGE_SIZE + 1
	for(var/index in first to min(length(rows), first + HAI_COMMAND_PAGE_SIZE - 1))
		var/list/row = rows[index].Copy()
		var/mob/living/carbon/human/human = locate(row["ref"]) in GLOB.ai_human_list
		row["selected"] = human && selection.is_selected(human)
		shown += list(row)
	return list(
		"roster" = shown,
		"roster_total" = length(rows),
		"all_total" = length(roster_snapshot),
		"page" = page,
		"pages" = pages,
		"filter_text" = filter_text,
		"filter_faction" = filter_faction,
		"filter_role" = filter_role,
		"sort_key" = sort_key,
		"sort_desc" = sort_desc,
	)

/datum/npc_command_console/proc/squad_data()
	var/list/squads = list()
	for(var/datum/human_ai_squad/squad as anything in GLOB.human_ai_squads)
		if(QDELETED(squad) || !squad_in_scope(squad))
			continue
		var/list/names = list()
		for(var/datum/human_ai_brain/member as anything in squad.members)
			names += member.body.real_name
		squads += list(list(
			"ref" = REF(squad),
			"name" = squad.name,
			"size" = length(squad.members),
			"leader" = squad.leader?.body.real_name,
			"formation" = squad.formation,
			"locked" = squad.formation_locked,
			"play" = squad.play,
			"members" = names,
		))
	return squads

/datum/npc_command_console/proc/order_data()
	var/list/active = list()
	for(var/mob/living/carbon/human/human as anything in GLOB.ai_human_list)
		if(!selection.valid(human))
			continue
		var/datum/human_ai_brain/brain = human.ai_brain
		var/datum/npc_order/order = brain?.current_order
		if(!order || order.status != HAI_ORDER_ACTIVE)
			continue
		active += list(list(
			"ref" = REF(human),
			"name" = human.real_name,
			"order" = order.id,
			"delivery" = order.delivery == HAI_DELIVERY_REQUEST ? "request" : "command",
			"issuer" = order.issuer || "",
			"remaining" = order.expires_at ? max(0, round((order.expires_at - world.time) / 10)) : null,
		))
	return active

/// The stance of the selection, shown on the personality tab
/datum/npc_command_console/proc/stance_data()
	var/list/chosen = selection.get_selected()
	if(!length(chosen))
		return null
	var/mob/living/carbon/human/first = chosen[1]
	var/datum/human_ai_brain/brain = first.ai_brain
	return list(
		"name" = first.real_name,
		"personality" = brain.personality.id,
		"traits" = brain.personality.traits,
		"posture" = brain.posture,
		"move_cap" = brain.move_cap,
		"roe" = brain.roe,
	)

/datum/npc_command_console/proc/relation_data()
	var/list/factions = human_ai_known_factions()
	var/list/matrix = list()
	for(var/faction in factions)
		var/list/row = list()
		for(var/other in factions)
			row[other] = human_ai_faction_relation(faction, other)
		matrix[faction] = row
	var/list/roes = list()
	for(var/faction in factions)
		roes[faction] = human_ai_default_roe(faction)
	return list("matrix" = matrix, "roe" = roes)

/datum/npc_command_console/proc/debug_data()
	var/list/data = list(
		"debug_text" = GLOB.ai_debug_pathing,
		"avg_cost_ms" = round(SShuman_ai.avg_cost_ms, 0.01),
		"full_count" = SShuman_ai.full_count,
		"squads" = length(SShuman_ai.squads),
		"orders_sent" = orders_sent,
		"orders_refused" = orders_refused,
		"disabled" = SShuman_ai.disabled_count,
	)
	var/mob/living/carbon/human/human = inspect_ref?.resolve()
	if(!human || QDELETED(human) || !human.ai_brain)
		return data
	var/datum/human_ai_brain/brain = human.ai_brain
	var/list/contacts = list()
	for(var/key in brain.contacts)
		var/datum/ai_contact/contact = brain.contacts[key]
		var/atom/subject = contact.subject_ref?.resolve()
		contacts += list(list(
			"name" = subject ? "[subject]" : "gone",
			"visible" = contact.visible,
			"known" = contact.identified(),
			"confidence" = round(contact.confidence * 100),
			"threat" = round(contact.threat),
			"where" = contact.last_turf ? "[contact.last_turf.x],[contact.last_turf.y]" : "",
		))
	var/list/log = list()
	for(var/index in length(brain.decision_log) to max(1, length(brain.decision_log) - 14) step -1)
		log += brain.decision_log[index]
	data["inspect"] = list(
		"ref" = REF(human),
		"name" = human.real_name,
		"intent" = brain.intent_name(),
		"tier" = brain.tier,
		"personality" = brain.personality.id,
		"stress" = round(brain.stress),
		"roe" = brain.roe,
		"target" = "[brain.get_target() || "none"]",
		"order" = brain.current_order?.id || "none",
		"thinks" = brain.think_count,
		"errors" = brain.error_total,
		"contacts" = contacts,
		"log" = log,
	)
	return data

/datum/npc_command_console/proc/population_data()
	var/datum/controller/subsystem/human_ai_population/director = SShuman_ai_population
	var/datum/npc_population_profile/profile = director.profile || director.find_profile()
	var/list/groups = list()
	for(var/datum/npc_population_group/group as anything in profile?.groups)
		groups += list(list(
			"id" = group.id,
			"name" = group.name,
			"faction" = group.faction || "from equipment",
			"enabled" = group.enabled,
			"alive" = group.alive_count(),
			"target" = group.target_size(),
			"spawned" = group.spawned_total,
			"placed" = group.placed,
			"timing" = group.timing,
			"behavior" = group.behavior,
			"attitude" = group.marine_attitude,
		))
	var/list/hooks = list()
	for(var/hook_id in GLOB.npc_population_hooks)
		var/datum/npc_population_hook/hook = GLOB.npc_population_hooks[hook_id]
		var/list/hook_groups = list()
		for(var/datum/npc_population_group/group as anything in hook.groups)
			hook_groups += list(list("id" = group.id, "name" = group.name, "alive" = group.alive_count(), "target" = group.target_size()))
		hooks += list(list(
			"id" = hook.id,
			"name" = hook.name,
			"desc" = hook.desc,
			"enabled" = hook.enabled,
			"forced" = hook.forced,
			"suits" = hook.suits_round(),
			"groups" = hook_groups,
		))
	return list(
		"hooks" = hooks,
		"enabled" = director.enabled,
		"profile" = profile?.map_name,
		"groups" = groups,
		"report" = director.health_report || list(),
		"checked" = !!director.health_report,
		"placed_total" = director.placed_total,
		"cleared_total" = director.cleared_total,
		"landed" = director.landed,
		"cost_ms" = round(director.last_run_ms, 0.01),
	)
