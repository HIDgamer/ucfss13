/// Every squad that is planning
GLOBAL_LIST_EMPTY(human_ai_squads)

/// Gathers the AI humans into a squad, the preferred body leads if it can
/proc/create_human_ai_squad(list/bodies, mob/living/carbon/human/preferred, squad_name)
	var/datum/human_ai_squad/squad = new
	if(squad_name)
		squad.name = squad_name
	for(var/mob/living/carbon/human/body as anything in bodies)
		if(body?.ai_brain)
			squad.add_member(body.ai_brain)
	if(!length(squad.members))
		qdel(squad)
		return null
	squad.elect_leader(preferred?.ai_brain)
	return squad

/// A message from one member that the rest of the squad hears a moment later
/datum/human_ai_callout
	var/ready_at = 0
	var/key
	var/datum/weakref/subject_ref
	var/turf/where
	var/datum/human_ai_brain/reporter

/datum/human_ai_callout/Destroy()
	subject_ref = null
	where = null
	reporter = null
	return ..()

/// A group of brains that fight as a unit: a leader, shared contacts, formations and plays
/datum/human_ai_squad
	var/name = "Squad"
	var/list/datum/human_ai_brain/members = list()
	var/datum/human_ai_brain/leader
	var/formation = HAI_FORM_WEDGE
	var/play = HAI_PLAY_NONE
	var/play_until = 0
	var/next_plan = 0
	var/next_flank_time = 0
	var/next_fallback_time = 0
	var/list/datum/human_ai_callout/callouts = list()
	/// The men of the squad that died, the squad still knows where they lie
	var/list/datum/weakref/fallen = list()
	/// Mover brain to the order that sends it along the play
	var/list/mover_orders = list()
	/// Mover brain to its health fraction when the play began
	var/list/mover_health = list()
	var/fallback_stage = 0
	var/turf/play_turf
	var/turf/rally_turf
	var/turf/pin_turf
	var/pin_since = 0
	var/plan_errors = 0
	var/casualties = 0
	var/play_changes = 0
	var/flanks_started = 0
	var/flanks_done = 0
	var/flanks_aborted = 0
	var/fallbacks_started = 0
	var/fallbacks_done = 0
	var/callouts_sent = 0
	var/callouts_received = 0
	var/leader_changes = 0
	var/next_radio_time = 0
	var/rallies = 0
	var/breach_state = HAI_BREACH_IDLE
	var/obj/structure/machinery/door/breach_door
	var/turf/breach_room_spot
	var/list/breach_log = list()
	var/list/datum/human_ai_brain/breach_members = list()
	var/list/breach_spots = list()
	var/datum/human_ai_brain/breach_opener
	var/datum/human_ai_brain/breach_thrower
	var/breach_started = 0
	var/breach_wait_until = 0
	var/breach_flash_wait = 0
	var/flashes_thrown = 0
	var/breaches_done = 0
	var/formation_changes = 0
	var/formation_locked = FALSE
	var/radio_calls = 0

/datum/human_ai_squad/New()
	. = ..()
	next_plan = world.time + rand(0, HAI_SQUAD_PLAN_INTERVAL - 1)
	GLOB.human_ai_squads += src
	SShuman_ai.squads += src

/datum/human_ai_squad/Destroy()
	GLOB.human_ai_squads -= src
	SShuman_ai.squads -= src
	for(var/datum/human_ai_brain/member as anything in members)
		if(member.squad == src)
			member.squad = null
			member.squad_role = HAI_SQUAD_ROLE_NONE
	members = null
	leader = null
	mover_orders = null
	mover_health = null
	QDEL_LIST(callouts)
	play_turf = null
	rally_turf = null
	pin_turf = null
	return ..()

/datum/human_ai_squad/proc/member_valid(datum/human_ai_brain/brain)
	return brain && !QDELETED(brain) && !brain.stopped && !QDELETED(brain.body) && brain.body.stat != DEAD

/datum/human_ai_squad/proc/add_member(datum/human_ai_brain/brain)
	if(!brain || brain.squad == src || length(members) >= HAI_SQUAD_MAX_MEMBERS)
		return FALSE
	brain.squad?.remove_member(brain, "joined another squad")
	members += brain
	brain.squad = src
	brain.squad_role = HAI_SQUAD_ROLE_NONE
	return TRUE

/datum/human_ai_squad/proc/remove_member(datum/human_ai_brain/brain, reason)
	if(!(brain in members))
		return
	members -= brain
	release_mover(brain)
	if(brain.squad == src)
		brain.squad = null
	brain.squad_role = HAI_SQUAD_ROLE_NONE
	if(reason == HAI_STOP_DEAD)
		casualties++
		if(brain.body)
			if(length(fallen) >= 20)
				fallen.Cut(1, 2)
			fallen += WEAKREF(brain.body)
	if(!length(members))
		qdel(src)
		return
	if(leader == brain)
		leader = null
		elect_leader()

/// Chooses the best member to lead, the preferred one wins if it is able
/datum/human_ai_squad/proc/elect_leader(datum/human_ai_brain/preferred)
	var/datum/human_ai_brain/best
	var/best_score = -INFINITY
	for(var/datum/human_ai_brain/brain as anything in members)
		if(!member_valid(brain))
			continue
		var/score = brain.personality.trait("discipline") + brain.personality.trait("loyalty") + clamp(brain.body.health / max(brain.body.maxHealth, 1), 0, 1) * 50 + brain.role.leader_bonus
		if(brain == preferred)
			score += 1000
		if(score > best_score)
			best_score = score
			best = brain
	if(best == leader)
		return
	leader = best
	leader_changes++
	leader?.log_decision("leads [name]")

/// Place of the member among the leader's followers, from 0
/// How many other members stand within the range of the member
/datum/human_ai_squad/proc/friends_near(datum/human_ai_brain/member, range)
	var/count = 0
	for(var/datum/human_ai_brain/other as anything in members)
		if(other != member && member_valid(other) && get_dist(other.body, member.body) <= range)
			count++
	return count

/datum/human_ai_squad/proc/slot_of(datum/human_ai_brain/brain)
	var/slot = 0
	for(var/datum/human_ai_brain/other as anything in members)
		if(other == brain)
			return slot
		if(other != leader && member_valid(other))
			slot++
	return slot

/// Hands an order to the squad: the leader carries a movement order and the rest follow, anything else goes to everyone
/datum/human_ai_squad/proc/issue_order(datum/npc_order/order, delivery = HAI_DELIVERY_COMMAND)
	var/accepted = 0
	if(order.id == "breach")
		return start_breach(order.target_turf) ? length(breach_members) : 0
	if(!leader)
		elect_leader()
	if(order.leader_only && leader)
		if(leader.give_order(order, delivery))
			accepted++
		for(var/datum/human_ai_brain/brain as anything in members)
			if(brain == leader || !member_valid(brain))
				continue
			var/datum/npc_order/trail = new /datum/npc_order/follow
			trail.internal = TRUE
			trail.set_target(leader.body)
			trail.slot = slot_of(brain)
			if(brain.give_order(trail, delivery))
				accepted++
		return accepted
	var/slot = 0
	for(var/datum/human_ai_brain/brain as anything in members)
		if(!member_valid(brain))
			continue
		var/datum/npc_order/copy = slot ? order.copy_for(brain, slot) : order
		if(brain.give_order(copy, delivery))
			accepted++
		slot++
	return accepted

/datum/human_ai_squad/proc/disband()
	for(var/datum/human_ai_brain/brain as anything in members)
		release_mover(brain)
	qdel(src)

/// A member saw an enemy clearly, the rest hear about it a moment later
/datum/human_ai_squad/proc/report_contact(datum/human_ai_brain/reporter, mob/living/subject, datum/ai_contact/contact)
	if(length(members) < 2)
		return
	var/key = REF(subject)
	for(var/datum/human_ai_callout/pending as anything in callouts)
		if(pending.key == key)
			pending.where = contact.last_turf
			return
	var/datum/human_ai_callout/callout = new
	callout.key = key
	callout.subject_ref = WEAKREF(subject)
	callout.where = contact.last_turf
	callout.reporter = reporter
	callout.ready_at = world.time + HAI_CALLOUT_DELAY_MAX - round((HAI_CALLOUT_DELAY_MAX - HAI_CALLOUT_DELAY_MIN) * reporter.personality.trait("discipline") * 0.01)
	callouts += callout
	callouts_sent++

/datum/human_ai_squad/proc/deliver_callouts()
	for(var/datum/human_ai_callout/callout as anything in callouts.Copy())
		if(callout.ready_at > world.time)
			continue
		callouts -= callout
		var/mob/living/subject = callout.subject_ref?.resolve()
		if(subject && !QDELETED(subject) && subject.stat != DEAD)
			for(var/datum/human_ai_brain/brain as anything in members)
				if(brain != callout.reporter && member_valid(brain) && brain.receive_callout(subject, callout.where))
					callouts_received++
		qdel(callout)

/// How many different enemies the squad knows of right now
/datum/human_ai_squad/proc/known_enemy_count()
	var/list/seen = list()
	for(var/datum/human_ai_brain/brain as anything in members)
		for(var/key in brain.contacts)
			var/datum/ai_contact/contact = brain.contacts[key]
			if(contact.identified() && (contact.visible || contact.confidence >= 0.4))
				seen[key] = TRUE
	return length(seen)

/datum/human_ai_squad/proc/set_play(new_play)
	if(play == new_play)
		return
	play = new_play
	play_changes++
	leader?.log_decision("[name] plays [new_play]")

/// Takes a member off the play, cancelling the order that carried it
/datum/human_ai_squad/proc/release_mover(datum/human_ai_brain/brain)
	var/datum/npc_order/carried = mover_orders?[brain]
	mover_orders?.Remove(brain)
	mover_health?.Remove(brain)
	if(carried && carried.status == HAI_ORDER_ACTIVE)
		carried.finish(HAI_ORDER_CANCELLED)
	if(brain.squad_role == HAI_SQUAD_ROLE_MANEUVER)
		brain.squad_role = HAI_SQUAD_ROLE_NONE

/datum/human_ai_squad/proc/end_play(reason)
	for(var/datum/human_ai_brain/brain as anything in mover_orders.Copy())
		release_mover(brain)
	fallback_stage = 0
	if(play == HAI_PLAY_FLANK)
		next_flank_time = max(next_flank_time, world.time + HAI_FLANK_COOLDOWN)
	else if(play == HAI_PLAY_FALLBACK)
		next_fallback_time = max(next_fallback_time, world.time + HAI_FALLBACK_COOLDOWN)
	set_play(HAI_PLAY_NONE)

/// Runs from the subsystem, a squad that throws too often is dissolved
/datum/human_ai_squad/proc/run_plan()
	next_plan = world.time + HAI_SQUAD_PLAN_INTERVAL
	try
		plan()
	catch(var/exception/error)
		plan_errors++
		stack_trace("human_ai_squad error for [name]: [istype(error, /exception) ? "[error:name] at [error:file]:[error:line]" : error]")
		if(plan_errors >= HAI_MAX_ERRORS)
			disband()

/datum/human_ai_squad/proc/plan()
	for(var/datum/human_ai_brain/brain as anything in members.Copy())
		if(!member_valid(brain))
			remove_member(brain, brain.stopped ? brain.stop_reason : HAI_STOP_DELETED)
	if(QDELETED(src))
		return
	if(!member_valid(leader))
		elect_leader()
	deliver_callouts()
	breach_step()

	var/list/engaged = list()
	for(var/datum/human_ai_brain/brain as anything in members)
		if(brain.intent == HAI_INTENT_ENGAGE && brain.get_target())
			engaged += brain
	rally_members()
	choose_formation(engaged)
	if(!length(engaged))
		if(play == HAI_PLAY_FALLBACK)
			continue_fallback(play_turf)
		else if(play != HAI_PLAY_NONE)
			end_play("contact lost")
		pin_turf = null
		return

	var/mob/living/focus = pick_focus(engaged)
	var/turf/focus_turf = get_turf(focus)
	if(!pin_turf || get_dist(pin_turf, focus_turf) > 2)
		pin_turf = focus_turf
		pin_since = world.time

	switch(play)
		if(HAI_PLAY_FLANK)
			continue_flank(focus_turf)
		if(HAI_PLAY_FALLBACK)
			continue_fallback(focus_turf)
	if(play == HAI_PLAY_NONE || play == HAI_PLAY_HOLD_LINE)
		if(should_fall_back())
			start_fallback(focus_turf)
		else if(!start_flank(engaged, focus, focus_turf))
			set_play(HAI_PLAY_HOLD_LINE)
	assign_roles(engaged)

/// The enemy most of the engaged members are fighting, the leader's choice wins a tie
/datum/human_ai_squad/proc/pick_focus(list/engaged)
	var/list/votes = list()
	var/mob/living/best
	var/best_votes = 0
	for(var/datum/human_ai_brain/brain as anything in engaged)
		var/mob/living/target = brain.get_target()
		if(!target)
			continue
		votes[target] += (brain == leader) ? 1.5 : 1
		if(votes[target] > best_votes)
			best_votes = votes[target]
			best = target
	return best

/datum/human_ai_squad/proc/assign_roles(list/engaged)
	for(var/datum/human_ai_brain/brain as anything in members)
		if(brain in mover_orders)
			brain.squad_role = HAI_SQUAD_ROLE_MANEUVER
		else if(brain == leader && play != HAI_PLAY_NONE)
			brain.squad_role = HAI_SQUAD_ROLE_ANCHOR
		else if(brain in engaged)
			brain.squad_role = HAI_SQUAD_ROLE_FIRE
		else
			brain.squad_role = HAI_SQUAD_ROLE_NONE

/datum/human_ai_squad/proc/average_stress()
	var/total = 0
	var/counted = 0
	for(var/datum/human_ai_brain/brain as anything in members)
		total += brain.stress
		counted++
	return counted ? total / counted : 0

/datum/human_ai_squad/proc/should_fall_back()
	if(world.time < next_fallback_time || !leader)
		return FALSE
	var/stress_limit = 40 + leader.personality.trait("courage") * 0.4
	if(average_stress() >= stress_limit)
		return TRUE
	if(casualties >= 2 && casualties >= length(members))
		return TRUE
	return known_enemy_count() >= max(3, length(members) * 3)

/datum/human_ai_squad/proc/start_fallback(turf/threat)
	var/turf/retreat = leader.retreat_turf(threat)
	if(!retreat)
		next_fallback_time = world.time + 10 SECONDS
		return FALSE
	rally_turf = retreat
	var/list/by_distance = list()
	for(var/datum/human_ai_brain/brain as anything in members)
		if(member_valid(brain) && !brain.current_order)
			by_distance += brain
	if(length(by_distance) < 2)
		next_fallback_time = world.time + 10 SECONDS
		return FALSE
	for(var/index in 1 to length(by_distance))
		for(var/inner in index + 1 to length(by_distance))
			if(get_dist(by_distance[inner], threat) > get_dist(by_distance[index], threat))
				by_distance.Swap(index, inner)
	send_back(by_distance.Copy(1, 1 + round(length(by_distance) / 2)))
	fallback_stage = 1
	leader.express(HAI_EXPR_FALL_BACK)
	play_until = world.time + HAI_FALLBACK_COMMIT
	play_turf = threat
	fallbacks_started++
	set_play(HAI_PLAY_FALLBACK)
	return TRUE

/// Sends the given members back to the rally point
/datum/human_ai_squad/proc/send_back(list/movers)
	var/slot = 0
	for(var/datum/human_ai_brain/brain as anything in movers)
		var/datum/npc_order/retreat = new /datum/npc_order/fall_back
		retreat.internal = TRUE
		retreat.target_turf = rally_turf
		retreat.slot = slot++
		if(brain.give_order(retreat))
			mover_orders[brain] = retreat
			mover_health[brain] = clamp(brain.body.health / max(brain.body.maxHealth, 1), 0, 1)

/// Keeps the member where it stands for a while so the retreat is not undone by a search for the enemy
/datum/human_ai_squad/proc/hold_here(datum/human_ai_brain/brain)
	var/datum/npc_order/hold/stay = new
	stay.internal = TRUE
	stay.duration = HAI_RALLY_HOLD
	brain.give_order(stay)

/datum/human_ai_squad/proc/continue_fallback(turf/threat)
	var/running = 0
	for(var/datum/human_ai_brain/brain as anything in mover_orders.Copy())
		var/datum/npc_order/retreat = mover_orders[brain]
		if(!member_valid(brain) || retreat.status != HAI_ORDER_ACTIVE)
			if(member_valid(brain) && retreat.status == HAI_ORDER_DONE)
				hold_here(brain)
			mover_orders.Remove(brain)
			mover_health.Remove(brain)
			if(brain.squad_role == HAI_SQUAD_ROLE_MANEUVER)
				brain.squad_role = HAI_SQUAD_ROLE_NONE
			continue
		running++
	if(world.time > play_until)
		end_play("fall back timed out")
		return
	if(running)
		return
	if(fallback_stage == 1)
		var/list/rest = list()
		for(var/datum/human_ai_brain/brain as anything in members)
			if(member_valid(brain) && !brain.current_order && get_dist(brain.body, rally_turf) > 3)
				rest += brain
		fallback_stage = 2
		if(length(rest))
			send_back(rest)
			return
	fallbacks_done++
	end_play("fell back")

/// Whether a flank is worth trying, and if so sends the movers, false when nobody went
/datum/human_ai_squad/proc/start_flank(list/engaged, mob/living/focus, turf/focus_turf)
	if(world.time < next_flank_time || length(members) < 3 || world.time < pin_since + HAI_PINNED_TIME)
		return FALSE
	var/list/shooters = list()
	for(var/datum/human_ai_brain/brain as anything in engaged)
		var/datum/ai_contact/contact = brain.get_contact(focus)
		if(contact?.visible && brain.peek_gun() && !brain.gun_unusable(brain.peek_gun()))
			shooters += brain
	var/enemies = known_enemy_count()
	if(length(shooters) < 2 || length(shooters) < enemies)
		return FALSE
	var/superior = length(shooters) >= enemies * 2
	var/total_x = 0
	var/total_y = 0
	for(var/datum/human_ai_brain/shooter as anything in shooters)
		total_x += shooter.body.x
		total_y += shooter.body.y
	var/turf/base = locate(round(total_x / length(shooters)), round(total_y / length(shooters)), focus_turf.z)
	if(!base)
		return FALSE
	var/wanted = (length(members) >= 5) ? 2 : 1
	var/list/chosen = list()
	for(var/datum/human_ai_brain/candidate as anything in flankers_first(engaged))
		if(length(chosen) >= wanted)
			break
		if(candidate == leader || candidate.current_order || !candidate.peek_gun() || candidate.stress >= 50 || candidate.body.health < candidate.body.maxHealth * 0.6)
			continue
		if(candidate.flank_willingness() < 0.4 - (superior ? 0.15 : 0))
			continue
		var/list/route = flank_route(candidate, focus_turf, base)
		if(!route)
			continue
		var/datum/npc_order/maneuver/go = new
		go.waypoints = route
		if(candidate.give_order(go))
			mover_orders[candidate] = go
			mover_health[candidate] = clamp(candidate.body.health / max(candidate.body.maxHealth, 1), 0, 1)
			chosen += candidate
	if(!length(chosen))
		next_flank_time = world.time + 10 SECONDS
		return FALSE
	flanks_started++
	play_until = world.time + HAI_FLANK_COMMIT
	play_turf = focus_turf
	set_play(HAI_PLAY_FLANK)
	return TRUE

/// Cover-to-cover route to a spot well off the line of fire with a view of the target, null when there is none
/datum/human_ai_squad/proc/flank_route(datum/human_ai_brain/mover, turf/target, turf/base)
	var/turf/start = get_turf(mover.body)
	var/base_angle = Get_Angle(target, base)
	var/line_angle = Get_Angle(base, target)
	var/distance = clamp(get_dist(base, target), 4, 9)
	var/turf/best
	var/best_score = -INFINITY
	for(var/side in list(1, -1))
		for(var/offset in list(75, 95, 115))
			var/angle = base_angle + side * offset
			var/turf/raw = locate(clamp(round(target.x + sin(angle) * distance), 1, world.maxx), clamp(round(target.y + cos(angle) * distance), 1, world.maxy), target.z)
			var/turf/spot = raw ? mover.open_turf_near(raw) : null
			if(!spot || !mover.cover_turf_usable(spot) || get_dist(spot, target) < 3 || !mover.cover_has_line(spot, target))
				continue
			var/arc = abs(Get_Angle(spot, target) - line_angle)
			if(arc > 180)
				arc = 360 - arc
			if(arc < HAI_FLANK_MIN_ARC)
				continue
			var/score = mover.cover_against(spot, target) * 2 - get_dist(start, spot) * 0.05 - mover.danger_at(spot) * 0.5
			if(score > best_score)
				best_score = score
				best = spot
	if(!best)
		return null
	var/list/route = list()
	if(get_dist(start, best) > 8)
		var/turf/halfway = locate(round((start.x + best.x) / 2), round((start.y + best.y) / 2), start.z)
		var/turf/mid = halfway ? mover.open_turf_near(halfway) : null
		if(mid && mid != best)
			route += mid
	route += best
	return route

/datum/human_ai_squad/proc/continue_flank(turf/focus_turf)
	for(var/datum/human_ai_brain/brain as anything in mover_orders.Copy())
		var/datum/npc_order/go = mover_orders[brain]
		var/aborted = FALSE
		if(!member_valid(brain) || brain.body.stat != CONSCIOUS)
			aborted = TRUE
		else if(go.status == HAI_ORDER_DONE)
			flanks_done++
			release_mover(brain)
			continue
		else if(go.status != HAI_ORDER_ACTIVE)
			aborted = TRUE
		else if(brain.stress >= 70 || clamp(brain.body.health / max(brain.body.maxHealth, 1), 0, 1) < mover_health[brain] - 0.3)
			aborted = TRUE
		if(aborted)
			flanks_aborted++
			release_mover(brain)
	if(!length(mover_orders))
		end_play("flank over")
		return
	if(world.time > play_until || get_dist(play_turf, focus_turf) > 5)
		flanks_aborted += length(mover_orders)
		end_play("flank timed out")

/datum/human_ai_brain/proc/flank_willingness()
	return (personality.trait("aggression") * 0.4 + personality.trait("initiative") * 0.4 + (100 - personality.trait("caution")) * 0.2) * 0.01 + (role?.flanks ? 0.6 : 0)

/// Tells the brain an enemy is out there, true when it took the news
/datum/human_ai_brain/proc/receive_callout(mob/living/subject, turf/where)
	if(QDELETED(subject) || subject.stat == DEAD || get_disposition(subject) < HAI_DISP_HOSTILE)
		return FALSE
	var/datum/ai_contact/contact = ensure_contact(subject)
	if(!contact)
		return FALSE
	if(!contact.visible)
		contact.notice = 1
		contact.confidence = max(contact.confidence, 0.7)
		if(contact.last_time < world.time - 20)
			contact.last_turf = where
			contact.last_time = world.time
		contact.threat = max(contact.threat, assess_threat(subject))
	alert_until = max(alert_until, world.time + 6 SECONDS)
	return TRUE

/// Closes up on the leader when the squad is moving and nothing else is going on
/datum/human_ai_action/keep_formation
	id = "keep_formation"
	conflicts = HAI_LIMB_LEGS
	intents = list(HAI_INTENT_IDLE, HAI_INTENT_ALERT, HAI_INTENT_ORDERED)

/datum/human_ai_action/keep_formation/get_weight(datum/human_ai_brain/brain)
	var/datum/human_ai_squad/squad = brain.squad
	if(!squad || brain.current_order || squad.leader == brain || !squad.member_valid(squad.leader))
		return 0
	return get_dist(brain.body, squad.leader.body) > HAI_SQUAD_LEASH ? 18 : 0

/datum/human_ai_action/keep_formation/trigger(datum/human_ai_brain/brain)
	var/datum/human_ai_squad/squad = brain.squad
	return brain.follow_leader(squad.leader.body, squad.slot_of(brain))

/client/proc/debug_form_human_ai_squad()
	set category = "Debug"
	set name = "Form Human AI Squad"

	var/list/nearby = list()
	for(var/mob/living/carbon/human/candidate in view(mob))
		if(candidate.ai_brain && !candidate.ai_brain.squad)
			nearby += candidate
	if(length(nearby) < 2)
		to_chat(src, SPAN_WARNING("Fewer than two AI humans without a squad are in view."))
		return
	var/mob/living/carbon/human/lead = tgui_input_list(src, "Who leads?", "Form Human AI Squad", nearby)
	if(!lead)
		return
	var/datum/human_ai_squad/made = create_human_ai_squad(nearby, lead)
	if(made)
		message_admins("[key_name_admin(src)] formed a squad of [length(made.members)] AI humans led by [lead].")
