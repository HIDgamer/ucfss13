/// The sheet metal the body carries for building
/datum/human_ai_brain/proc/find_building_stack()
	for(var/obj/item/stack/sheet/metal/sheets in body.get_contents())
		if(sheets.amount >= HAI_BARRICADE_COST)
			return sheets
	return null

/// A deployable defence (sentry, tesla and the like) in the pack
/datum/human_ai_brain/proc/find_handheld_defense()
	for(var/obj/item/defenses/handheld/kit in body.get_contents())
		if(kit.dropped && kit.TR)
			return kit
	return null

/datum/human_ai_brain/proc/find_mines()
	var/list/mines = list()
	for(var/obj/item/explosive/mine/mine in body.get_contents())
		if(!mine.active)
			mines += mine
	return mines

/// True when the body would still have a good deal of room to move after the tile is walled up
/datum/human_ai_brain/proc/room_left_after(turf/planned)
	var/turf/start = get_turf(body)
	var/list/seen = list()
	seen[start] = TRUE
	var/list/frontier = list(start)
	var/reached = 0
	while(length(frontier) && reached < HAI_ROOM_NEEDED)
		var/turf/here = frontier[1]
		frontier.Cut(1, 2)
		reached++
		for(var/direction in GLOB.alldirs)
			var/turf/next_turf = get_step(here, direction)
			if(!next_turf || seen[next_turf] || next_turf.density || next_turf == planned)
				continue
			var/blocked = FALSE
			for(var/obj/thing in next_turf)
				if(thing.density && (!(thing.flags_atom & ON_BORDER) || istype(thing, /obj/structure/barricade)))
					blocked = TRUE
					break
			if(blocked)
				continue
			seen[next_turf] = TRUE
			frontier += next_turf
	return reached >= HAI_ROOM_NEEDED

/// Finishes a barricade the engineer started, if it is still next to the spot
/datum/human_ai_brain/proc/build_barricade(turf/spot, direction, obj/item/stack/sheet/metal/sheets)
	if(stopped || QDELETED(body) || QDELETED(sheets) || get_dist(body, spot) > 1 || sheets.amount < HAI_BARRICADE_COST)
		return
	for(var/obj/thing in spot)
		if(thing.density)
			return
	sheets.use(HAI_BARRICADE_COST)
	var/obj/structure/barricade/metal/wall = new(spot)
	wall.setDir(direction)
	barricades_built++
	log_decision("built a barricade at [spot.x],[spot.y]")

/// Build a line of barricades across the point, facing the way the threat comes from, then a sentry and mines behind and in front of it
/datum/npc_order/fortify
	id = "fortify"
	name = "Fortify"
	danger = 0.15
	var/phase = HAI_FORTIFY_BUILD
	var/list/turf/queue = list()
	var/skipped = 0
	var/lane_step = 0
	var/obj/item/defenses/handheld/kit
	var/mines_left = 0

/datum/npc_order/fortify/can_perform(datum/human_ai_brain/performer)
	if(!performer.role?.supports_order(id))
		return "no engineer kit"
	if(!target_turf)
		return "no place to fortify"
	return performer.find_building_stack() ? null : "no building material"

/datum/npc_order/fortify/begin(datum/human_ai_brain/performer)
	..()
	facing ||= get_dir(performer.body, target_turf)
	var/lateral = turn(facing, 90)
	queue = list()
	for(var/offset in list(0, -1, 1))
		var/turf/spot = target_turf
		for(var/step_count in 1 to abs(offset))
			spot = get_step(spot, (offset < 0) ? turn(lateral, 180) : lateral)
		if(spot && !spot.density && !(locate(/obj/structure/barricade) in spot))
			queue += spot
	kit = performer.find_handheld_defense()
	mines_left = min(HAI_MAX_MINES, length(performer.find_mines()))

/datum/npc_order/fortify/tick(datum/human_ai_brain/performer)
	if(performer.is_acting())
		return FALSE
	switch(phase)
		if(HAI_FORTIFY_BUILD)
			if(!length(queue))
				phase = HAI_FORTIFY_SENTRY
				return FALSE
			var/turf/spot = queue[1]
			var/turf/stand = get_step(spot, turn(facing, 180))
			if(performer.body.loc != stand)
				if(performer.move_to(stand, 0, FALSE))
					return TRUE
				queue.Cut(1, 2)
				skipped++
				return FALSE
			if(!performer.room_left_after(spot))
				queue.Cut(1, 2)
				skipped++
				performer.log_decision("left [spot.x],[spot.y] open, it would seal the way back")
				return FALSE
			var/obj/item/stack/sheet/metal/sheets = performer.find_building_stack()
			if(!sheets)
				queue.Cut()
				return FALSE
			performer.body.face_atom(spot)
			performer.acting_until = world.time + HAI_BUILD_TIME
			addtimer(CALLBACK(performer, TYPE_PROC_REF(/datum/human_ai_brain, build_barricade), spot, facing, sheets), HAI_BUILD_TIME)
			queue.Cut(1, 2)
		if(HAI_FORTIFY_SENTRY)
			if(!kit || QDELETED(kit) || !kit.dropped)
				phase = HAI_FORTIFY_MINES
				return FALSE
			var/turf/stand = target_turf
			for(var/step_count in 1 to 2)
				stand = get_step(stand, turn(facing, 180))
			if(performer.body.loc != stand)
				if(performer.move_to(stand, 0, FALSE))
					return TRUE
				phase = HAI_FORTIFY_MINES
				return FALSE
			performer.body.setDir(facing)
			if(!performer.hand_item(kit))
				phase = HAI_FORTIFY_MINES
				return FALSE
			performer.acting_until = world.time + kit.deployment_time + 15
			INVOKE_ASYNC(kit, TYPE_PROC_REF(/obj/item/defenses/handheld, deploy_handheld), performer.body)
			performer.defenses_deployed++
			kit = null
			phase = HAI_FORTIFY_MINES
		if(HAI_FORTIFY_MINES)
			if(mines_left <= 0)
				finish(HAI_ORDER_DONE)
				return FALSE
			var/turf/lane = target_turf
			for(var/step_count in 1 to 3 + lane_step * 2)
				lane = get_step(lane, facing)
			if(!lane || lane.density)
				mines_left = 0
				return FALSE
			if(performer.body.loc != lane)
				if(performer.move_to(lane, 0, FALSE))
					return TRUE
				mines_left = 0
				return FALSE
			var/list/mines = performer.find_mines()
			if(!length(mines) || !performer.hand_item(mines[1]))
				mines_left = 0
				return FALSE
			var/obj/item/explosive/mine/mine = mines[1]
			mine.deploy_mine(performer.body)
			performer.mines_laid++
			mines_left--
			lane_step++
			performer.acting_until = world.time + 10
	return FALSE

/// Plants a plastic charge on a wall or door, backs away and waits for it to go off
/datum/npc_order/demolish
	id = "demolish"
	name = "Demolish"
	hard = TRUE
	danger = 0.2
	var/phase = HAI_DEMOLISH_PLANT
	var/obj/item/explosive/plastic/charge

/datum/npc_order/demolish/can_perform(datum/human_ai_brain/performer)
	if(!target_turf)
		return "nothing to demolish"
	return performer.find_demolition_tool(target_turf) ? null : "no charge or hammer"

/datum/npc_order/demolish/tick(datum/human_ai_brain/performer)
	if(performer.is_acting())
		return FALSE
	switch(phase)
		if(HAI_DEMOLISH_PLANT)
			var/turf/stand
			var/best = INFINITY
			for(var/direction in GLOB.cardinals)
				var/turf/candidate = get_step(target_turf, direction)
				if(candidate && !candidate.density && get_dist(performer.body, candidate) < best)
					best = get_dist(performer.body, candidate)
					stand = candidate
			if(!stand)
				finish(HAI_ORDER_FAILED)
				return FALSE
			if(performer.body.loc != stand)
				if(performer.move_to(stand, 0, FALSE))
					return TRUE
				finish(HAI_ORDER_FAILED)
				return FALSE
			// A breaching hammer takes a wall down with no blast at all, and a charge does the rest
			var/obj/item/weapon/twohanded/breacher/hammer = performer.find_breaching_hammer()
			if(hammer && istype(target_turf, /turf/closed/wall))
				if(!performer.hand_item(hammer))
					finish(HAI_ORDER_FAILED)
					return FALSE
				performer.body.face_atom(target_turf)
				performer.acting_until = world.time + 7 SECONDS
				INVOKE_ASYNC(target_turf, TYPE_PROC_REF(/atom, attackby), hammer, performer.body)
				performer.walls_hammered++
				phase = HAI_DEMOLISH_WAIT
				wait_until = world.time + 10 SECONDS
				return FALSE
			charge = performer.find_charge()
			if(!charge || !performer.hand_item(charge))
				finish(HAI_ORDER_FAILED)
				return FALSE
			performer.body.face_atom(target_turf)
			performer.ensure_charge_skill(charge)
			performer.acting_until = world.time + 60
			INVOKE_ASYNC(charge, TYPE_PROC_REF(/obj/item/explosive/plastic, afterattack), target_turf, performer.body, TRUE)
			performer.charges_planted++
			phase = HAI_DEMOLISH_RETREAT
		if(HAI_DEMOLISH_RETREAT)
			var/turf/away = performer.retreat_turf(target_turf, 7)
			if(away && get_dist(performer.body, target_turf) < 6)
				if(performer.move_to(away, 0, TRUE))
					return TRUE
			phase = HAI_DEMOLISH_WAIT
			wait_until = world.time + 100
		if(HAI_DEMOLISH_WAIT)
			if(!charge || QDELETED(charge) || world.time > wait_until)
				finish(HAI_ORDER_DONE)
	return FALSE

/// A breaching hammer the body can swing, the heavy kind needs a strength it does not have
/datum/human_ai_brain/proc/find_breaching_hammer()
	RETURN_TYPE(/obj/item/weapon/twohanded/breacher)
	for(var/obj/item/weapon/twohanded/breacher/hammer in body.get_contents())
		if(!hammer.really_heavy || HAS_TRAIT(body, TRAIT_SUPER_STRONG))
			return hammer
	return null

/// What the body would bring a wall or a door down with: a hammer for a wall, a charge for anything
/datum/human_ai_brain/proc/find_demolition_tool(turf/target)
	if(istype(target, /turf/closed/wall) && find_breaching_hammer())
		return find_breaching_hammer()
	return find_charge()

/datum/human_ai_brain/proc/find_charge()
	for(var/obj/item/explosive/plastic/charge in body.get_contents())
		if(!charge.active)
			return charge
	return null
