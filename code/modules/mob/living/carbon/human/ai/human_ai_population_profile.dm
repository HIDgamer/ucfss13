/// Every map population profile by the name of the map it is for
GLOBAL_LIST_INIT(npc_population_profiles, init_npc_population_profiles())

/// Mobs the placement guards treat as players besides the real ones, only unit tests fill it
GLOBAL_LIST_EMPTY(npc_population_extra_watchers)

/proc/init_npc_population_profiles()
	var/list/found = list()
	for(var/profile_type in subtypesof(/datum/npc_population_profile))
		var/datum/npc_population_profile/profile = new profile_type
		if(!profile.map_name)
			qdel(profile)
			continue
		found[profile.map_name] = profile
	return found

/// The groups of ambient AI humans one map is populated with
/datum/npc_population_profile
	var/map_name
	var/list/group_types = list()
	var/list/datum/npc_population_group/groups = list()

/datum/npc_population_profile/New()
	for(var/group_type in group_types)
		groups += new group_type

/datum/npc_population_profile/Destroy()
	QDEL_LIST(groups)
	return ..()

/datum/npc_population_profile/proc/get_group(group_id)
	RETURN_TYPE(/datum/npc_population_group)
	for(var/datum/npc_population_group/group as anything in groups)
		if(group.id == group_id)
			return group
	return null

/// Problems found in the profile, an empty list when it is sound. Checks only what the data itself says, the map is checked by the director
/datum/npc_population_profile/proc/validate()
	var/list/problems = list()
	var/list/seen = list()
	for(var/datum/npc_population_group/group as anything in groups)
		if(!group.id || (group.id in seen))
			problems += "[map_name]: a group has a missing or repeated id ([group.id || "none"])"
		seen += group.id
		problems += group.validate()
	return problems

/// One kind of ambient NPC on a map: who they are, how many, where they stand and what they do
/datum/npc_population_group
	var/id
	var/name = "Group"
	/// Replaces the faction the equipment gives, empty keeps it
	var/faction
	/// How the group regards marines, friendly, wary or hostile
	var/marine_attitude = "wary"
	/// Equipment preset type to weight
	var/list/presets = list()
	/// Personality id to weight
	var/list/personalities = list("neutral" = 1)
	/// Role kit id to weight, left empty the equipment decides
	var/list/roles = list()
	var/size_min = 1
	/// A size of zero is meant, the group works out its own size
	var/allow_empty = FALSE
	var/size_max = 1
	/// Extra members for every marine awake, 0 keeps the size at its minimum
	var/size_per_player = 0
	/// Members to a squad, 0 for no squads
	var/squad_size = 0
	/// Area type to weight
	var/list/zones = list()
	/// The group finds its own ground, so it needs no zones
	var/dynamic_zone = FALSE
	/// Turfs to use instead of the zones
	var/list/turf/fixed_turfs
	var/behavior = HAI_POP_LOITER
	var/timing = HAI_POP_ROUNDSTART
	var/respawn = FALSE
	var/wound_min = 0
	var/wound_max = 0
	/// What the group does when something frightening turns up: fight, flee or cower
	var/reaction = "fight"
	/// Seconds after placement that the hive leaves them alone
	var/xeno_grace_seconds = 120
	/// Keeps off the turfs player survivors start on
	var/leave_landmarks = TRUE
	var/enabled = TRUE
	/// Most humans of the group alive at once, 0 for the size of the group
	var/max_alive = 0

	var/list/datum/weakref/members = list()
	var/spawned_total = 0
	var/placed = FALSE
	var/place_failures = 0
	var/next_spawn = 0
	/// Area type to its usable turfs, built on first use
	var/list/zone_turfs

/datum/npc_population_group/proc/validate()
	var/list/problems = list()
	if(!length(presets))
		problems += "[id]: no equipment presets"
	for(var/preset_type in presets)
		if(!ispath(preset_type, /datum/equipment_preset) || !GLOB.gear_path_presets_list[preset_type])
			problems += "[id]: unknown equipment preset [preset_type]"
		else if(!isnum(presets[preset_type]) || presets[preset_type] < 1)
			problems += "[id]: preset [preset_type] has no weight"
	for(var/personality_id in personalities)
		if(!(personality_id in GLOB.human_ai_personalities))
			problems += "[id]: unknown personality [personality_id]"
	for(var/role_id in roles)
		if(!(role_id in GLOB.human_ai_roles))
			problems += "[id]: unknown role [role_id]"
	if(!length(zones) && !length(fixed_turfs) && !dynamic_zone)
		problems += "[id]: no zones"
	for(var/area_type in zones)
		if(!ispath(area_type, /area))
			problems += "[id]: [area_type] is not an area"
	if((size_min < 1 && !allow_empty) || size_max < size_min)
		problems += "[id]: bad size [size_min] to [size_max]"
	if(faction && !(faction in human_ai_known_factions()))
		problems += "[id]: faction [faction] is not one the relations know"
	if(!(marine_attitude in list("friendly", "wary", "hostile")))
		problems += "[id]: bad attitude [marine_attitude]"
	if(!(behavior in list(HAI_POP_LOITER, HAI_POP_PATROL, HAI_POP_GUARD, HAI_POP_SHELTER, HAI_POP_WANDER)))
		problems += "[id]: bad behavior [behavior]"
	if(!(timing in list(HAI_POP_ROUNDSTART, HAI_POP_ON_LANDING, HAI_POP_TRICKLE, HAI_POP_ON_EVENT)))
		problems += "[id]: bad timing [timing]"
	return problems

/// How many humans the group should have now
/datum/npc_population_group/proc/target_size()
	var/size = size_min
	if(size_per_player)
		size += round(get_active_player_count(TRUE, TRUE, TRUE, FACTION_MARINE) * size_per_player)
	return clamp(size, size_min, size_max)

/datum/npc_population_group/proc/prune_members()
	for(var/datum/weakref/ref as anything in members.Copy())
		var/mob/living/carbon/human/human = ref.resolve()
		if(!human || QDELETED(human))
			members -= ref

/datum/npc_population_group/proc/alive_members()
	var/list/alive = list()
	for(var/datum/weakref/ref as anything in members)
		var/mob/living/carbon/human/human = ref.resolve()
		if(human && !QDELETED(human) && human.stat != DEAD)
			alive += human
	return alive

/datum/npc_population_group/proc/alive_count()
	return length(alive_members())

/// The turfs of every zone that a human could stand on, built once
/datum/npc_population_group/proc/get_zone_turfs()
	if(zone_turfs)
		return zone_turfs
	zone_turfs = list()
	if(length(fixed_turfs))
		zone_turfs["fixed"] = fixed_turfs.Copy()
		return zone_turfs
	for(var/area_type in zones)
		var/area/room = GLOB.areas_by_type[area_type]
		if(!room)
			continue
		var/list/usable = list()
		for(var/turf/open/candidate in room)
			if(is_valid_admin_spawn_turf(candidate) && !istype(candidate, /turf/open/space))
				usable += candidate
		if(length(usable))
			zone_turfs[area_type] = usable
	return zone_turfs

/// Whether a human may be put on the turf right now: free, away from players, not on a landmark players start on
/datum/npc_population_group/proc/turf_allowed(turf/where, list/watchers)
	if(!where || !is_valid_admin_spawn_turf(where))
		return FALSE
	if(locate(/mob/living) in where)
		return FALSE
	if(leave_landmarks && locate(/obj/effect/landmark/survivor_spawner) in where)
		return FALSE
	for(var/mob/watcher as anything in watchers)
		var/turf/seen_from = get_turf(watcher)
		if(seen_from && seen_from.z == where.z && get_dist(seen_from, where) < HAI_POP_MIN_PLAYER_DISTANCE)
			return FALSE
	return TRUE

/// A free turf in a zone picked by weight, null when none could be found
/datum/npc_population_group/proc/pick_turf(list/watchers)
	var/list/pools = get_zone_turfs()
	if(!length(pools))
		return null
	for(var/attempt in 1 to HAI_POP_PLACE_TRIES)
		var/list/weighted = list()
		for(var/area_type in pools)
			weighted[area_type] = max(1, zones[area_type] || 1)
		var/zone = pick_weight(weighted)
		var/turf/candidate = pick(pools[zone])
		if(turf_allowed(candidate, watchers))
			return candidate
	return null

/// Puts one human of the group on the turf and sets it up, null when the population cap is reached
/datum/npc_population_group/proc/spawn_member(turf/where)
	var/preset_type = pick_weight(presets)
	if(!preset_type || !where)
		return null
	var/mob/living/carbon/human/human = new(where)
	human.create_hud()
	arm_equipment(human, preset_type, TRUE, FALSE)
	if(faction)
		human.faction = faction
	var/personality = pick_weight(personalities)
	if(!attach_human_ai(human, personality || "neutral"))
		qdel(human)
		return null
	var/datum/human_ai_brain/brain = human.ai_brain
	var/role = length(roles) ? pick_weight(roles) : null
	if(!role && reaction == "cower")
		role = "civilian"
	if(role)
		brain.set_role(role)
	brain.role?.equip_kit(brain)
	brain.home_turf = where
	human.ai_grace_until = world.time + xeno_grace_seconds SECONDS
	if(marine_attitude == "hostile")
		brain.enemy_factions = list(FACTION_MARINE)
	if(wound_max > 0)
		human.take_overall_damage(rand(wound_min, wound_max))
	members += WEAKREF(human)
	spawned_total++
	return human

/// Gives a freshly placed batch its squads and its standing orders
/datum/npc_population_group/proc/organise(list/batch)
	if(!length(batch))
		return
	var/list/squads = list()
	if(squad_size > 1 && length(batch) > 1)
		var/list/chunk = list()
		for(var/mob/living/carbon/human/human as anything in batch)
			chunk += human
			if(length(chunk) >= squad_size)
				squads += create_human_ai_squad(chunk, null, "[name] squad")
				chunk = list()
		if(length(chunk) > 1)
			squads += create_human_ai_squad(chunk, null, "[name] squad")
	for(var/mob/living/carbon/human/human as anything in batch)
		var/datum/human_ai_brain/brain = human.ai_brain
		if(brain.squad && brain.squad.leader != brain)
			continue
		var/datum/npc_order/order = standing_order(human)
		if(!order)
			continue
		if(brain.squad)
			brain.squad.issue_order(order)
		else
			brain.give_order(order)

/// The order that goes with the group's behavior, null for the ones that only stand about
/datum/npc_population_group/proc/standing_order(mob/living/carbon/human/human)
	var/datum/npc_order/order
	switch(behavior)
		if(HAI_POP_PATROL)
			var/datum/npc_order/patrol/route = new
			route.waypoints = human.ai_brain.area_points(get_area(human), 5, get_turf(human), HAI_PATROL_RANGE)
			if(length(route.waypoints) < 2)
				qdel(route)
				return null
			order = route
		if(HAI_POP_GUARD)
			var/datum/npc_order/guard/post = new
			post.target_turf = get_turf(human)
			order = post
	if(order)
		order.internal = TRUE
		order.issuer = "population"
	return order
