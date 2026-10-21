/// A job handed to a brain by a squad leader, an admin or a map behavior
/datum/npc_order
	/// Unique key, empty leaves the type abstract
	var/id
	var/name
	var/delivery = HAI_DELIVERY_COMMAND
	var/status = HAI_ORDER_ACTIVE
	var/issuer
	var/turf/target_turf
	var/datum/weakref/target_ref
	var/radius = 0
	var/list/turf/waypoints
	var/waypoint_index = 1
	/// A hard order keeps the legs under fire, a soft one gives way to a fight
	var/hard = FALSE
	/// 0 to 1, how risky obeying looks, feeds the compliance roll
	var/danger = 0
	var/duration = 0
	var/started_at = 0
	var/expires_at = 0
	/// Rules of engagement the order imposes while it runs
	var/roe
	var/sprint = FALSE
	/// Made by a squad plan and not listed as an order of the squad
	var/internal = FALSE
	/// Moves with the squad leader, the rest of the squad follows in formation
	var/leader_only = FALSE
	var/refuse_reason
	var/slot = 0
	var/facing = 0
	var/wait_until = 0
	var/turf/dest
	var/datum/human_ai_brain/brain

/datum/npc_order/Destroy()
	brain = null
	target_turf = null
	target_ref = null
	waypoints = null
	dest = null
	return ..()

/datum/npc_order/proc/get_target()
	return target_ref?.resolve()

/datum/npc_order/proc/set_target(atom/movable/new_target)
	target_ref = new_target ? WEAKREF(new_target) : null

/// Why the performer cannot carry this out, null when it can
/datum/npc_order/proc/can_perform(datum/human_ai_brain/performer)
	return null

/// How risky obeying looks to the performer, 0 to 1
/datum/npc_order/proc/estimate_danger(datum/human_ai_brain/performer)
	return danger

/// Called when the order ends however it ends, for orders that changed something about the performer that has to be put back
/datum/npc_order/proc/cleanup(datum/human_ai_brain/performer)
	return

/datum/npc_order/proc/begin(datum/human_ai_brain/performer)
	brain = performer
	started_at = world.time
	if(duration)
		expires_at = started_at + duration
	dest = slot ? performer.spread_turf(target_turf, slot) : target_turf

/// Called every think while the order runs, true when it used the legs
/datum/npc_order/proc/tick(datum/human_ai_brain/performer)
	return FALSE

/datum/npc_order/proc/wants_hands(datum/human_ai_brain/performer)
	return FALSE

/// The hands part of the order, true when it did something
/datum/npc_order/proc/tick_hands(datum/human_ai_brain/performer)
	return FALSE

/// The mob the performer must fight whatever else is around, null for most orders
/datum/npc_order/proc/forced_target()
	return null

/datum/npc_order/proc/finish(new_status)
	if(status != HAI_ORDER_ACTIVE)
		return
	status = new_status
	brain?.order_ended(src)

/datum/npc_order/proc/copy_for(datum/human_ai_brain/performer, member_slot = 0)
	var/datum/npc_order/copy = new type
	copy.delivery = delivery
	copy.issuer = issuer
	copy.target_turf = target_turf
	copy.target_ref = target_ref
	copy.radius = radius
	copy.waypoints = waypoints?.Copy()
	copy.hard = hard
	copy.danger = danger
	copy.duration = duration
	copy.roe = roe
	copy.sprint = sprint
	copy.internal = internal
	copy.facing = facing
	copy.slot = member_slot
	return copy

/datum/npc_order/move
	id = "move"
	name = "Move"
	hard = TRUE
	leader_only = TRUE

/datum/npc_order/move/estimate_danger(datum/human_ai_brain/performer)
	return max(danger, performer.danger_at(target_turf))

/datum/npc_order/move/tick(datum/human_ai_brain/performer)
	if(!dest)
		finish(HAI_ORDER_FAILED)
		return FALSE
	if(performer.move_to(dest, max(radius, HAI_ARRIVE_DISTANCE), sprint))
		return TRUE
	finish(performer.move_state == HAI_MOVE_ARRIVED ? HAI_ORDER_DONE : HAI_ORDER_FAILED)
	return FALSE

/datum/npc_order/hold
	id = "hold"
	name = "Hold position"
	hard = TRUE

/datum/npc_order/hold/begin(datum/human_ai_brain/performer)
	..()
	dest = target_turf ? dest : get_turf(performer.body)

/datum/npc_order/hold/tick(datum/human_ai_brain/performer)
	if(get_dist(performer.body, dest) > radius)
		return performer.move_to(dest, radius, sprint)
	if(facing && performer.body.dir != facing && !performer.get_target())
		performer.body.setDir(facing)
	return FALSE

/datum/npc_order/attack
	id = "attack"
	name = "Attack"
	hard = TRUE
	danger = 0.7

/datum/npc_order/attack/can_perform(datum/human_ai_brain/performer)
	var/mob/living/victim = get_target()
	if(!victim || QDELETED(victim) || victim.stat == DEAD)
		return "no target"
	return null

/datum/npc_order/attack/forced_target()
	var/mob/living/victim = get_target()
	return (victim && !QDELETED(victim) && victim.stat != DEAD) ? victim : null

/datum/npc_order/attack/tick(datum/human_ai_brain/performer)
	var/mob/living/victim = forced_target()
	if(!victim)
		finish(HAI_ORDER_DONE)
		return FALSE
	var/datum/ai_contact/contact = performer.ensure_contact(victim, TRUE)
	if(!contact.visible)
		contact.notice = 1
		contact.confidence = 1
		contact.last_turf = get_turf(victim)
	if(performer.get_target() != victim)
		performer.set_target(victim)
	var/obj/item/weapon/gun/gun = performer.peek_gun()
	var/distance = get_dist(performer.body, victim)
	var/wanted = gun ? performer.preferred_range(gun) : 1
	if(contact.visible && distance <= wanted)
		return FALSE
	return performer.move_to(victim, max(1, wanted), distance > HAI_SPRINT_MIN_DISTANCE + 1)

/datum/npc_order/follow
	id = "follow"
	name = "Follow"
	hard = TRUE

/datum/npc_order/follow/can_perform(datum/human_ai_brain/performer)
	var/atom/movable/leader = get_target()
	return (leader && !QDELETED(leader)) ? null : "nobody to follow"

/datum/npc_order/follow/tick(datum/human_ai_brain/performer)
	var/atom/movable/leader = get_target()
	if(!leader || QDELETED(leader))
		finish(HAI_ORDER_FAILED)
		return FALSE
	return performer.follow_leader(leader, slot)

/datum/npc_order/patrol
	id = "patrol"
	name = "Patrol"
	leader_only = TRUE

/datum/npc_order/patrol/can_perform(datum/human_ai_brain/performer)
	return length(waypoints) ? null : "no route"

/datum/npc_order/patrol/tick(datum/human_ai_brain/performer)
	if(!length(waypoints))
		finish(HAI_ORDER_FAILED)
		return FALSE
	if(world.time < wait_until)
		if(prob(15))
			performer.body.setDir(turn(performer.body.dir, pick(90, -90)))
		return FALSE
	if(performer.move_to(waypoints[waypoint_index], HAI_ARRIVE_DISTANCE, sprint))
		return TRUE
	wait_until = world.time + HAI_PATROL_PAUSE
	waypoint_index = (waypoint_index % length(waypoints)) + 1
	return FALSE

/datum/npc_order/guard
	id = "guard"
	name = "Guard"
	radius = 2

/datum/npc_order/guard/begin(datum/human_ai_brain/performer)
	..()
	dest = target_turf ? dest : get_turf(performer.body)

/datum/npc_order/guard/tick(datum/human_ai_brain/performer)
	if(get_dist(performer.body, dest) > radius)
		return performer.move_to(dest, max(0, radius - 1), sprint)
	if(world.time >= wait_until)
		wait_until = world.time + rand(30, 60)
		performer.body.setDir(facing || pick(GLOB.cardinals))
	return FALSE

/datum/npc_order/regroup
	id = "regroup"
	name = "Regroup"
	hard = TRUE
	radius = 2

/datum/npc_order/regroup/tick(datum/human_ai_brain/performer)
	if(!dest)
		finish(HAI_ORDER_FAILED)
		return FALSE
	if(performer.move_to(dest, radius, sprint))
		return TRUE
	finish(performer.move_state == HAI_MOVE_ARRIVED ? HAI_ORDER_DONE : HAI_ORDER_FAILED)
	return FALSE

/datum/npc_order/fall_back
	id = "fall_back"
	name = "Fall back"
	hard = TRUE
	sprint = TRUE
	danger = 0.05

/datum/npc_order/fall_back/begin(datum/human_ai_brain/performer)
	..()
	performer.express(HAI_EXPR_FALL_BACK)

/datum/npc_order/fall_back/tick(datum/human_ai_brain/performer)
	if(!dest)
		finish(HAI_ORDER_FAILED)
		return FALSE
	if(performer.move_to(dest, 1, sprint))
		return TRUE
	finish(performer.move_state == HAI_MOVE_ARRIVED ? HAI_ORDER_DONE : HAI_ORDER_FAILED)
	return FALSE

/datum/npc_order/take_cover
	id = "take_cover"
	name = "Take cover"
	hard = TRUE
	duration = HAI_TAKE_COVER_TIME
	danger = 0.2

/datum/npc_order/take_cover/tick(datum/human_ai_brain/performer)
	var/turf/threat = target_turf
	if(!threat)
		finish(HAI_ORDER_FAILED)
		return FALSE
	if(performer.in_good_cover(threat))
		performer.clear_cover_goal()
		return FALSE
	var/turf/goal = performer.cover_goal(threat, TRUE)
	if(!goal)
		if(world.time > started_at + 4 SECONDS)
			finish(HAI_ORDER_FAILED)
		return FALSE
	if(performer.body.loc == goal)
		performer.clear_cover_goal()
		return FALSE
	return performer.move_to(goal, 0, get_dist(performer.body, goal) > HAI_SPRINT_MIN_DISTANCE)

/datum/npc_order/clear_room
	id = "clear_room"
	name = "Clear room"
	leader_only = TRUE
	danger = 0.4

/datum/npc_order/clear_room/can_perform(datum/human_ai_brain/performer)
	return target_turf ? null : "no room"

/datum/npc_order/clear_room/begin(datum/human_ai_brain/performer)
	..()
	waypoints = performer.area_points(get_area(target_turf), 5)
	if(!length(waypoints))
		finish(HAI_ORDER_FAILED)

/datum/npc_order/clear_room/tick(datum/human_ai_brain/performer)
	if(waypoint_index > length(waypoints))
		finish(HAI_ORDER_DONE)
		return FALSE
	if(world.time < wait_until)
		if(prob(30))
			performer.body.setDir(turn(performer.body.dir, pick(90, -90)))
		return FALSE
	if(performer.move_to(waypoints[waypoint_index], HAI_ARRIVE_DISTANCE, FALSE))
		return TRUE
	wait_until = world.time + HAI_PATROL_PAUSE
	waypoint_index++
	return FALSE

/datum/npc_order/suppress
	id = "suppress"
	name = "Suppress"
	hard = TRUE
	duration = HAI_SUPPRESS_TIME
	danger = 0.1

/datum/npc_order/suppress/can_perform(datum/human_ai_brain/performer)
	if(!target_turf)
		return "no area"
	return performer.peek_gun() ? null : "no gun"

/datum/npc_order/suppress/wants_hands(datum/human_ai_brain/performer)
	return TRUE

/datum/npc_order/suppress/tick_hands(datum/human_ai_brain/performer)
	var/obj/item/weapon/gun/gun = performer.get_gun()
	if(!gun || performer.reload_phase != HAI_RELOAD_NONE || world.time < performer.volley_pause_until)
		return FALSE
	if(!performer.gun_can_shoot_now(gun) || !performer.safe_to_fire(gun, target_turf))
		return FALSE
	return performer.shoot(gun, target_turf)

/datum/npc_order/triage
	id = "triage"
	name = "Triage"

/datum/npc_order/triage/can_perform(datum/human_ai_brain/performer)
	return performer.role?.supports_order(id) ? null : "no medic kit"

/datum/npc_order/escort
	id = "escort"
	name = "Escort"
	hard = TRUE
	radius = 2

/datum/npc_order/escort/can_perform(datum/human_ai_brain/performer)
	var/atom/movable/vip = get_target()
	return (vip && !QDELETED(vip)) ? null : "nobody to escort"

/datum/npc_order/escort/tick(datum/human_ai_brain/performer)
	var/atom/movable/vip = get_target()
	if(!vip || QDELETED(vip))
		finish(HAI_ORDER_FAILED)
		return FALSE
	if(get_dist(performer.body, vip) <= radius)
		return FALSE
	return performer.follow_leader(vip, slot)

/datum/npc_order/stand_down
	id = "stand_down"
	name = "Stand down"

/datum/npc_order/stand_down/begin(datum/human_ai_brain/performer)
	..()
	performer.begin_stand_down()
	finish(HAI_ORDER_DONE)

/// A squad plan sends one member along a route of turfs, nothing a panel can issue
/datum/npc_order/maneuver
	id = "maneuver"
	name = "Maneuver"
	hard = TRUE
	internal = TRUE
	sprint = TRUE

/datum/npc_order/maneuver/begin(datum/human_ai_brain/performer)
	..()
	performer.express(HAI_EXPR_MOVING)

/datum/npc_order/maneuver/can_perform(datum/human_ai_brain/performer)
	return length(waypoints) ? null : "no route"

/datum/npc_order/maneuver/tick(datum/human_ai_brain/performer)
	if(waypoint_index > length(waypoints))
		finish(HAI_ORDER_DONE)
		return FALSE
	if(performer.move_to(waypoints[waypoint_index], HAI_ARRIVE_DISTANCE, sprint))
		return TRUE
	if(performer.move_state != HAI_MOVE_ARRIVED)
		finish(HAI_ORDER_FAILED)
		return FALSE
	waypoint_index++
	return FALSE

/datum/human_ai_action/order_drive
	id = "order_drive"
	conflicts = HAI_LIMB_LEGS

/datum/human_ai_action/order_drive/get_weight(datum/human_ai_brain/brain)
	var/datum/npc_order/active = brain.current_order
	if(!active || active.status != HAI_ORDER_ACTIVE)
		return 0
	return active.hard ? 105 : 28

/datum/human_ai_action/order_drive/trigger(datum/human_ai_brain/brain)
	return brain.current_order?.tick(brain)

/datum/human_ai_action/order_hands
	id = "order_hands"
	conflicts = HAI_LIMB_HANDS

/datum/human_ai_action/order_hands/get_weight(datum/human_ai_brain/brain)
	var/datum/npc_order/active = brain.current_order
	return (active && active.status == HAI_ORDER_ACTIVE && active.wants_hands(brain)) ? 66 : 0

/datum/human_ai_action/order_hands/trigger(datum/human_ai_brain/brain)
	return brain.current_order?.tick_hands(brain)

/// Takes an order, false when it is refused. A command is always obeyed if the kit allows it, a request goes through the compliance roll
/datum/human_ai_brain/proc/give_order(datum/npc_order/new_order, delivery = HAI_DELIVERY_COMMAND)
	new_order.delivery = delivery
	orders_received++
	var/reason = new_order.can_perform(src)
	if(reason)
		return refuse_order(new_order, reason)
	if(delivery == HAI_DELIVERY_REQUEST && !prob(comply_chance(new_order) * 100))
		return refuse_order(new_order, "balked")
	if(current_order)
		current_order.finish(HAI_ORDER_CANCELLED)
	current_order = new_order
	if(new_order.roe)
		roe_before_order = roe
		roe = new_order.roe
	new_order.begin(src)
	if(!new_order.internal && current_order == new_order)
		express(HAI_EXPR_ACK)
	log_decision("order [new_order.id][new_order.issuer ? " from [new_order.issuer]" : ""]")
	return TRUE

/datum/human_ai_brain/proc/refuse_order(datum/npc_order/refused, reason)
	refused.status = HAI_ORDER_REFUSED
	express(HAI_EXPR_REFUSE)
	refused.refuse_reason = reason
	orders_refused++
	last_refused_order = refused.id
	last_refused_time = world.time
	log_decision("refused order [refused.id] ([reason])")
	return FALSE

/datum/human_ai_brain/proc/cancel_order(reason = "cancelled")
	if(!current_order)
		return
	log_decision("order [current_order.id] cancelled ([reason])")
	current_order.finish(HAI_ORDER_CANCELLED)

/datum/human_ai_brain/proc/order_ended(datum/npc_order/ended)
	if(ended.brain == src)
		ended.brain = null
	if(current_order != ended)
		return
	ended.cleanup(src)
	current_order = null
	if(ended.roe && !roe_restore_time)
		roe = roe_before_order
	if(ended.status == HAI_ORDER_DONE)
		orders_completed++
	log_decision("order [ended.id] ended ([ended.status])")

/// Drops an order that ran out of time
/datum/human_ai_brain/proc/check_order()
	if(roe_restore_time && world.time >= roe_restore_time)
		end_stand_down()
	var/datum/npc_order/active = current_order
	if(active && active.expires_at && world.time >= active.expires_at)
		active.finish(HAI_ORDER_EXPIRED)

/// 0 to 1, how likely the brain is to go along with an order that is not forced
/datum/human_ai_brain/proc/comply_chance(datum/npc_order/asked)
	var/risk = asked.estimate_danger(src)
	if(risk <= 0 || asked.delivery == HAI_DELIVERY_COMMAND)
		return 1
	var/willing = personality.trait("discipline") * 0.0025 + personality.trait("loyalty") * 0.0035 + personality.trait("courage") * 0.004
	if(personality.trait("courage") >= 95)
		willing = min(1, willing + 0.2)
	return clamp(1 - risk * (1 - willing) * (1 + stress * 0.01), 0.02, 1)

/// 0 to 1, how many known enemies stand near the turf
/datum/human_ai_brain/proc/danger_at(turf/where)
	if(!where)
		return 0
	var/total = 0
	for(var/key in contacts)
		var/datum/ai_contact/contact = contacts[key]
		if(!contact.identified() || !contact.last_turf || (!contact.visible && contact.confidence < 0.3))
			continue
		if(get_dist(contact.last_turf, where) <= 8)
			total += 0.3
	return min(total, 1)

/// A turf near the center for the member with this slot, so a group sent to one place does not stack
/datum/human_ai_brain/proc/spread_turf(turf/center, slot)
	if(!center || !slot)
		return center
	var/direction = GLOB.alldirs[((slot - 1) % 8) + 1]
	var/turf/found = center
	for(var/step_count in 1 to 1 + round((slot - 1) / 8))
		var/turf/next_turf = get_step(found, direction)
		if(!next_turf || next_turf.density)
			break
		found = next_turf
	return found

/// Open floor spots in the area, spaced out, for walking through it, and when told where from only the ones that can be walked to from there
/datum/human_ai_brain/proc/area_points(area/room, count, turf/reachable_from)
	var/list/points = list()
	if(!room)
		return points
	var/list/open = list()
	for(var/turf/open/candidate in room)
		if(!candidate.density)
			open += candidate
	var/tries = 0
	while(length(open) && length(points) < count)
		var/turf/pick = pick_n_take(open)
		// An area can be bigger than the room and be in pieces, a spot nobody can get to is no use to the man sent to it
		if(reachable_from)
			if(pick.z != reachable_from.z || get_dist(reachable_from, pick) > HAI_BREACH_SECTOR_RANGE)
				continue
			if(++tries > HAI_BREACH_SECTOR_TRIES)
				break
			if(SSxeno_pathfinding?.available && !human_ai_route_exists(reachable_from, pick))
				continue
		var/spaced = TRUE
		for(var/turf/other as anything in points)
			if(get_dist(other, pick) < 4)
				spaced = FALSE
				break
		if(spaced)
			points += pick
	return points

/// A turf the given distance from the threat on the far side of the body, null when none is open
/datum/human_ai_brain/proc/retreat_turf(turf/threat, distance = HAI_FALL_BACK_DISTANCE)
	var/turf/here = get_turf(body)
	var/angle = Get_Angle(threat, here)
	for(var/reach in list(distance, distance - 3, distance - 6, 3))
		if(reach < 2)
			continue
		var/turf/candidate = locate(clamp(round(here.x + sin(angle) * reach), 1, world.maxx), clamp(round(here.y + cos(angle) * reach), 1, world.maxy), here.z)
		var/turf/found = candidate ? open_turf_near(candidate) : null
		if(found && get_dist(found, threat) > get_dist(here, threat))
			return found
	return null

/// Holds fire for a while unless someone shoots at the body
/datum/human_ai_brain/proc/begin_stand_down()
	if(!roe_restore_time)
		roe_before_order = roe
	roe = HAI_ROE_WEAPONS_HOLD
	roe_restore_time = world.time + HAI_STAND_DOWN_TIME
	clear_cover_goal()
	log_decision("standing down")

/datum/human_ai_brain/proc/end_stand_down()
	if(!roe_restore_time)
		return
	roe_restore_time = 0
	roe = roe_before_order
	log_decision("stand down over")
