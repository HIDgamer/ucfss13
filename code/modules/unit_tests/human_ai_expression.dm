/// Every voice bank is well formed and every line of it can come up
/datum/unit_test/human_ai_voice_banks

/datum/unit_test/human_ai_voice_banks/Run()
	var/datum/human_ai_voice/generic = GLOB.human_ai_voices["generic"]
	TEST_ASSERT_NOTNULL(generic, "There is no generic voice bank")
	for(var/kind in GLOB.human_ai_expressions)
		if(kind == HAI_EXPR_CONVO)
			continue
		TEST_ASSERT(length(generic.lines[kind]), "The generic bank has no line for [kind]")
	TEST_ASSERT(length(generic.convos) >= 3, "The generic bank has too little small talk")
	for(var/voice_id in GLOB.human_ai_voices)
		var/datum/human_ai_voice/bank = GLOB.human_ai_voices[voice_id]
		for(var/kind in bank.lines)
			TEST_ASSERT(GLOB.human_ai_expressions[kind], "[voice_id] has lines for [kind], which is not a kind of expression")
			var/list/seen = list()
			for(var/line in bank.lines[kind])
				TEST_ASSERT(istext(line) && length(line) >= 3 && length(line) <= 90, "[voice_id] [kind] has a line of the wrong size: [line]")
				TEST_ASSERT(!seen[line], "[voice_id] [kind] repeats [line]")
				seen[line] = TRUE
				TEST_ASSERT(!findtext(replacetext(replacetext(line, "%dir%", ""), "%area%", ""), "%"), "[voice_id] [kind] has an unknown placeholder in [line]")
		for(var/personality_id in bank.flavor)
			TEST_ASSERT(GLOB.human_ai_personalities[personality_id], "[voice_id] has flavor for [personality_id], which is not a personality")
			for(var/kind in bank.flavor[personality_id])
				TEST_ASSERT(GLOB.human_ai_expressions[kind], "[voice_id] flavor [personality_id] has [kind], which is not a kind of expression")
				TEST_ASSERT(length(bank.flavor[personality_id][kind]), "[voice_id] flavor [personality_id] [kind] is empty")
		for(var/list/talk in bank.convos)
			TEST_ASSERT_EQUAL(length(talk), 2, "[voice_id] has small talk that is not an opener and an answer")
			TEST_ASSERT(istext(talk[1]) && istext(talk[2]), "[voice_id] has small talk with something that is not text")

	for(var/voice_id in GLOB.human_ai_voices)
		var/datum/human_ai_voice/bank = GLOB.human_ai_voices[voice_id]
		for(var/kind in bank.lines)
			var/list/reached = list()
			for(var/draw in 1 to 120)
				reached[bank.line(kind, "neutral")] = TRUE
			for(var/line in bank.lines[kind])
				TEST_ASSERT(reached[line], "[voice_id] [kind] never says [line]")
		for(var/personality_id in bank.flavor)
			for(var/kind in bank.flavor[personality_id])
				var/list/reached = list()
				for(var/draw in 1 to 200)
					reached[bank.line(kind, personality_id)] = TRUE
				for(var/line in bank.flavor[personality_id][kind])
					TEST_ASSERT(reached[line], "[voice_id] [personality_id] [kind] never says [line]")

	TEST_ASSERT_EQUAL(get_human_ai_voice(FACTION_MARINE).id, "marine", "Marines do not talk like marines")
	TEST_ASSERT_EQUAL(get_human_ai_voice(FACTION_UPP).id, "upp", "The UPP does not talk like the UPP")
	TEST_ASSERT_EQUAL(get_human_ai_voice(FACTION_PMC).id, "corporate", "PMCs do not talk corporate")
	TEST_ASSERT_EQUAL(get_human_ai_voice(FACTION_CLF).id, "rebel", "The CLF does not talk like rebels")
	TEST_ASSERT_EQUAL(get_human_ai_voice(FACTION_MARSHAL).id, "police", "Marshals do not talk like police")
	TEST_ASSERT_EQUAL(get_human_ai_voice(FACTION_COLONIST).id, "civilian", "Colonists do not talk like civilians")
	TEST_ASSERT_EQUAL(get_human_ai_voice("nobody").id, "generic", "An unknown faction does not fall back to the generic voice")

/// Pacing, gating and the lag switch: what a brain may say and when
/datum/unit_test/human_ai_expression_rules

/datum/unit_test/human_ai_expression_rules/proc/fresh(datum/human_ai_brain/brain)
	brain.talk_times = list()
	brain.last_talk_time = 0
	SShuman_ai.talk_window_end = 0

/datum/unit_test/human_ai_expression_rules/Run()
	SShuman_ai.record_talk = TRUE
	SShuman_ai.talk_log = list()
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	body.faction = FACTION_UPP
	TEST_ASSERT(attach_human_ai(body, "professional"), "No brain")
	var/datum/human_ai_brain/brain = body.ai_brain
	fresh(brain)

	TEST_ASSERT(brain.express(HAI_EXPR_FRAG), "A critical expression was refused")
	TEST_ASSERT_EQUAL(length(SShuman_ai.talk_log), 1, "The expression was not logged")
	var/list/entry = SShuman_ai.talk_log[1]
	TEST_ASSERT_EQUAL(entry[3], HAI_EXPR_FRAG, "The log has the wrong kind")
	TEST_ASSERT(istext(entry[4]) && length(entry[4]), "The log has no line")
	TEST_ASSERT(!brain.express(HAI_EXPR_MAN_DOWN), "Two expressions came within the minimum gap")
	brain.last_talk_time = 0
	TEST_ASSERT(!brain.express(HAI_EXPR_FRAG), "The same kind came again within its cooldown")
	brain.last_talk_time = 0
	brain.talk_times = list()
	TEST_ASSERT(brain.express(HAI_EXPR_CONTACT, "north"), "A contact call was refused")
	entry = SShuman_ai.talk_log[length(SShuman_ai.talk_log)]
	TEST_ASSERT(!findtext(entry[4], "%"), "A placeholder was left in [entry[4]]")
	TEST_ASSERT(findtext(entry[4], "north"), "The direction missing from [entry[4]]")

	fresh(brain)
	body.set_stat(UNCONSCIOUS)
	TEST_ASSERT(!brain.express(HAI_EXPR_FRAG), "An unconscious body spoke")
	body.set_stat(CONSCIOUS)
	var/mob/living/carbon/human/dead_man = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	dead_man.death(create_cause_data("unit test"))
	var/datum/human_ai_brain/ghost_brain = new(dead_man)
	TEST_ASSERT(!ghost_brain.express(HAI_EXPR_FRAG), "A dead body spoke")
	qdel(ghost_brain)
	fresh(brain)

	var/logged = length(SShuman_ai.talk_log)
	SShuman_ai.talk_window_end = world.time + 50
	SShuman_ai.talk_count = HAI_TALK_GLOBAL_CAP
	TEST_ASSERT(!brain.express(HAI_EXPR_FRAG), "The server wide cap did not hold")
	SShuman_ai.talk_count = 0
	SShuman_ai.area_talk = list()
	SShuman_ai.area_talk[get_area(body)] = HAI_TALK_AREA_CAP
	TEST_ASSERT(!brain.express(HAI_EXPR_FRAG), "The area cap did not hold")
	TEST_ASSERT_EQUAL(length(SShuman_ai.talk_log), logged, "Refused expressions were logged")
	fresh(brain)

	SSlag_switch.measures[SIMPLIFY_HUMAN_AI] = TRUE
	TEST_ASSERT(!brain.express(HAI_EXPR_IDLE), "A routine remark got through the lag switch")
	TEST_ASSERT(brain.express(HAI_EXPR_FRAG), "A critical call was blocked by the lag switch")
	SSlag_switch.measures[SIMPLIFY_HUMAN_AI] = FALSE
	fresh(brain)

	var/talkative = 0
	var/quiet = 0
	for(var/trial in 1 to 300)
		brain.set_personality("friendly")
		fresh(brain)
		if(brain.express(HAI_EXPR_BATTLE_CRY))
			talkative++
		brain.set_personality("veteran")
		fresh(brain)
		if(brain.express(HAI_EXPR_BATTLE_CRY))
			quiet++
		SShuman_ai.talk_log = list()
	TEST_NOTICE(src, "Out of 300 tries a friendly brain makes a routine remark [talkative] times, a veteran [quiet] times")
	TEST_ASSERT(talkative > quiet + 25, "Chattiness does not change how much a brain says: [talkative] against [quiet]")

	var/obj/item/device/radio/headset/headset = new(body)
	headset.forceMove(body)
	body.wear_l_ear = headset
	TEST_ASSERT(body.wear_l_ear == headset, "The headset was not worn")
	var/mob/living/carbon/human/mate = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	attach_human_ai(mate)
	var/datum/human_ai_squad/squad = create_human_ai_squad(list(body, mate), body, "Radio Squad")
	brain.set_personality("professional")
	fresh(brain)
	SShuman_ai.talk_log = list()
	TEST_ASSERT(brain.express(HAI_EXPR_MAN_DOWN), "A man down call was refused")
	entry = SShuman_ai.talk_log[1]
	TEST_ASSERT(copytext(entry[4], 1, 2) == ";", "A squad member with a headset did not use the radio: [entry[4]]")
	TEST_ASSERT_EQUAL(squad.radio_calls, 1, "The radio call was not counted")
	brain.talk_times = list()
	brain.last_talk_time = 0
	TEST_ASSERT(brain.express(HAI_EXPR_MAN_DOWN), "The second call was refused")
	entry = SShuman_ai.talk_log[length(SShuman_ai.talk_log)]
	TEST_ASSERT(copytext(entry[4], 1, 2) != ";", "The squad radio was used twice within its gap")
	squad.disband()
	SShuman_ai.record_talk = FALSE
	detach_human_ai(body)
	detach_human_ai(mate)

/// The things that happen in a fight make the brain say the right thing
/datum/unit_test/human_ai_reactions
	var/datum/human_ai_brain/brain

/datum/unit_test/human_ai_reactions/proc/said(kind)
	for(var/list/entry in SShuman_ai.talk_log)
		if(entry[3] == kind)
			return TRUE
	return FALSE

/// What was said since the last reset, as kind and line
/datum/unit_test/human_ai_reactions/proc/said_so_far()
	var/list/heard = list()
	for(var/list/entry in SShuman_ai.talk_log)
		heard += "[entry[3]]: [entry[4]]"
	return heard.Join(" | ")

/datum/unit_test/human_ai_reactions/proc/reset()
	brain.talk_times = list()
	brain.last_talk_time = 0
	SShuman_ai.talk_window_end = 0
	SShuman_ai.talk_log = list()

/datum/unit_test/human_ai_reactions/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	SShuman_ai.record_talk = TRUE
	var/datum/human_ai_arena/yard = new(list(
		"##############################",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"##############################",
	), run_loc_floor_bottom_left)
	var/turf/start = locate(yard.origin_x + 4, yard.origin_y + 2, yard.z)
	var/mob/living/carbon/human/soldier = make_soldier(start, FACTION_MARINE, TRUE, "friendly")
	brain = soldier.ai_brain
	reset()
	var/mob/living/carbon/xenomorph/drone/dummy = make_target_dummy(locate(start.x + 8, start.y, start.z))
	// The first contact of a fight is a call for backup that gives the direction and names the area
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(said), HAI_EXPR_BACKUP), 8), "The soldier never called for backup on first contact, log [SShuman_ai.talk_log.len]")
	var/list/entry
	for(var/list/candidate in SShuman_ai.talk_log)
		if(candidate[3] == HAI_EXPR_BACKUP)
			entry = candidate
	TEST_ASSERT(findtext(entry[4], "east") || findtext(entry[4], "ahead"), "The call for backup has no direction: [entry[4]]")
	var/area/here = get_area(soldier)
	TEST_ASSERT(findtext(entry[4], here.name), "The call for backup does not name the area [here.name]: [entry[4]]")

	// The next xeno is called out plainly, backup was only just called for
	reset()
	var/mob/living/carbon/xenomorph/drone/second = make_target_dummy(locate(start.x + 5, start.y + 1, start.z))
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(said), HAI_EXPR_XENO), 20), "The soldier never called the second xeno out, it said [said_so_far()], contacts [length(brain.contacts)], target [brain.get_target()], second at [second.x],[second.y] and soldier at [soldier.x],[soldier.y], backup ready at [brain.next_backup_call] and now [world.time]: [brain.decision_log.Join(" | ")]")
	for(var/list/candidate in SShuman_ai.talk_log)
		if(candidate[3] == HAI_EXPR_XENO)
			entry = candidate
	TEST_ASSERT(findtext(entry[4], "east") || findtext(entry[4], "ahead"), "The call-out has no direction: [entry[4]]")
	qdel(second)

	reset()
	brain.give_order(new /datum/npc_order/fortify)
	TEST_ASSERT(said(HAI_EXPR_REFUSE), "A refused order drew no protest")
	reset()
	var/datum/npc_order/hold/stay = new
	brain.give_order(stay)
	for(var/attempt in 1 to 30)
		if(said(HAI_EXPR_ACK))
			break
		brain.talk_times = list()
		brain.last_talk_time = 0
		brain.cancel_order()
		brain.give_order(new /datum/npc_order/hold)
	TEST_ASSERT(said(HAI_EXPR_ACK), "A command was never acknowledged")
	brain.cancel_order()
	reset()
	brain.begin_break(HAI_BREAK_FLEE)
	TEST_ASSERT(said(HAI_EXPR_FEAR), "A brain that broke made no sound")
	brain.broken_until = world.time - 1
	brain.check_break()
	reset()
	brain.begin_break(HAI_BREAK_SURRENDER)
	TEST_ASSERT(said(HAI_EXPR_SURRENDER), "A surrendering brain said nothing")
	brain.end_surrender("test")
	brain.broken_until = world.time - 1
	brain.check_break()
	reset()
	brain.hear_noise(start, HAI_NOISE_EXPLOSION, 3, 20, null)
	for(var/attempt in 1 to 40)
		if(said(HAI_EXPR_EXPLOSION))
			break
		reset()
		brain.hear_noise(start, HAI_NOISE_EXPLOSION, 3, 20, null)
	TEST_ASSERT(said(HAI_EXPR_EXPLOSION), "An explosion drew no remark")
	reset()
	var/mob/living/carbon/human/friend = make_soldier(locate(start.x + 1, start.y + 1, start.z), FACTION_MARINE, FALSE, "friendly")
	var/datum/human_ai_brain/friends_brain = friend.ai_brain
	friend.death(create_cause_data("unit test"))
	for(var/attempt in 1 to 20)
		if(said(HAI_EXPR_MAN_DOWN))
			break
		sleep(2)
	TEST_ASSERT(said(HAI_EXPR_MAN_DOWN), "A death beside the brain drew no call")
	reset()
	var/hit = FALSE
	for(var/attempt in 1 to 40)
		reset()
		brain.announce_kill()
		for(var/list/spoken in SShuman_ai.talk_log)
			if(spoken[3] == HAI_EXPR_KILL || spoken[3] == HAI_EXPR_CLEAR || spoken[3] == HAI_EXPR_TAUNT)
				hit = TRUE
		if(hit)
			break
	TEST_ASSERT(hit, "A kill never drew a remark")

	qdel(dummy)
	soldier.forceMove(run_loc_floor_bottom_left)
	var/datum/human_ai_arena/gate = new(list(
		"####################",
		"#..................#",
		"#..................#",
		"####################",
	), run_loc_floor_bottom_left)
	soldier.forceMove(locate(gate.origin_x + 4, gate.origin_y + 1, gate.z))
	brain.set_personality("professional")
	brain.stress = 0
	brain.broken_kind = HAI_BREAK_NONE
	brain.surrendered = FALSE
	reset()
	var/mob/living/carbon/human/stranger = allocate(/mob/living/carbon/human, locate(gate.origin_x + 8, gate.origin_y + 1, gate.z))
	stranger.faction = "raiders"
	var/obj/item/weapon/gun/rifle/m41a/theirs = new(stranger)
	stranger.put_in_hands(theirs)
	stranger.setDir(WEST)
	SSspatial_grid.track(stranger, SPATIAL_GRID_TRACK_NPC)
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(said), HAI_EXPR_CHALLENGE), 12), "The guard never challenged the stranger aloud")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(said), HAI_EXPR_WARN), 20), "The guard never warned the stranger aloud")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(said), HAI_EXPR_HOSTILE), 30), "The guard never called the stranger hostile aloud")
	TEST_ASSERT_EQUAL(brain.error_total + friends_brain.error_total, 0, "A brain threw errors")
	SShuman_ai.record_talk = FALSE
	detach_human_ai(soldier)

/// Brains left alone take a post and stay on it, glancing about now and then and seldom saying anything, within their budgets
/datum/unit_test/human_ai_idle_life
	var/list/datum/human_ai_brain/crowd = list()

/datum/unit_test/human_ai_idle_life/proc/talked()
	var/convos = 0
	var/answers = 0
	for(var/datum/human_ai_brain/brain as anything in crowd)
		convos += brain.convos_started
		answers += brain.convo_answers
	return convos >= 1 && answers >= 1

/datum/unit_test/human_ai_idle_life/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	SShuman_ai.record_talk = TRUE
	SShuman_ai.talk_log = list()
	var/datum/human_ai_arena/hall = new(list(
		"##################",
		"#................#",
		"#................#",
		"#................#",
		"#................#",
		"#................#",
		"##################",
	), run_loc_floor_bottom_left)
	var/turf/middle = locate(hall.origin_x + 8, hall.origin_y + 3, hall.z)
	var/list/homes = list()
	for(var/index in 0 to 7)
		var/mob/living/carbon/human/idler = make_soldier(locate(middle.x + (index % 4) - 1, middle.y + round(index / 4) - 1, middle.z), FACTION_MARINE, FALSE, index % 2 ? "friendly" : "neutral")
		crowd += idler.ai_brain
		homes[idler.ai_brain] = get_turf(idler)
	TEST_ASSERT_EQUAL(length(crowd), 8, "Not every idler got a brain")
	// Idlers rarely chat on their own now, so the conversation itself is started by hand and the rest of the time is spent watching how quiet they stay
	var/datum/human_ai_brain/opener = crowd[1]
	opener.next_convo_time = 0
	TEST_ASSERT(opener.start_conversation(), "A brain among idle friends could not start a conversation")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(talked)), 10), "The neighbor never answered the conversation")
	sleep(60 SECONDS)
	var/posted = 0
	for(var/datum/human_ai_brain/brain as anything in crowd)
		if(brain.post_turf)
			posted++
		TEST_ASSERT_EQUAL(brain.idle_wanders, 0, "An idler on watch strolled about")
		TEST_ASSERT(get_dist(brain.body, homes[brain]) <= HAI_POST_RADIUS + 1, "An idler went [get_dist(brain.body, homes[brain])] tiles from home")
		TEST_ASSERT_EQUAL(brain.intent, HAI_INTENT_IDLE, "An idler left the idle intent")
		TEST_ASSERT_EQUAL(brain.error_total, 0, "An idler's brain threw errors")
	TEST_ASSERT(posted >= 6, "Only [posted] of 8 idlers took a post")
	TEST_NOTICE(src, "[SShuman_ai.total_barks] things said by 8 idlers, [posted] on a post")
	for(var/list/entry in SShuman_ai.talk_log)
		TEST_ASSERT(entry[3] == HAI_EXPR_IDLE || entry[3] == HAI_EXPR_CONVO || entry[3] == HAI_EXPR_GREET, "An idler said something of kind [entry[3]]")
	TEST_ASSERT(length(SShuman_ai.talk_log) <= 10, "Eight idlers said [length(SShuman_ai.talk_log)] things in a minute and a half")
	SShuman_ai.record_talk = FALSE
	for(var/datum/human_ai_brain/brain as anything in crowd)
		detach_human_ai(brain.body)

/// Thirty armed brains in three squads fight a few enemies for half a minute: the chat stays inside its budgets
/datum/unit_test/human_ai_chatter_audit

/datum/unit_test/human_ai_chatter_audit/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/list/rows = list("######################################")
	for(var/row in 1 to 20)
		rows += "#....................................#"
	rows += "######################################"
	var/datum/human_ai_arena/field = new(rows, run_loc_floor_bottom_left)
	var/list/presets = list("friendly", "professional", "reckless", "paranoid", "ruthless", "zealot", "scout", "cautious", "veteran", "hostile")
	var/list/bodies = list()
	for(var/index in 0 to 29)
		var/mob/living/carbon/human/soldier = make_soldier(locate(field.origin_x + 3 + (index % 10), field.origin_y + 4 + round(index / 10) * 6, field.z), FACTION_MARINE, TRUE, presets[(index % 10) + 1])
		soldier.ai_brain.set_personality(presets[(index % 10) + 1], 0, list("chattiness" = 100))
		bodies += soldier
	for(var/squad_index in 0 to 2)
		create_human_ai_squad(bodies.Copy(squad_index * 10 + 1, squad_index * 10 + 11), bodies[squad_index * 10 + 1], "Audit [squad_index]")
	for(var/dummy_index in 0 to 3)
		make_target_dummy(locate(field.origin_x + 16 + dummy_index * 3, field.origin_y + 3 + dummy_index * 4, field.z))
	SShuman_ai.record_talk = TRUE
	SShuman_ai.talk_log = list()
	SShuman_ai.total_barks = 0
	SShuman_ai.reset_cost_meter()
	var/seconds = 40
	sleep(seconds SECONDS)
	SShuman_ai.record_talk = FALSE
	var/total = length(SShuman_ai.talk_log)
	var/list/kinds = list()
	var/list/last_by_brain = list()
	var/list/last_by_kind = list()
	var/list/times = list()
	var/list/area_times = list()
	for(var/list/entry in SShuman_ai.talk_log)
		var/when = entry[1]
		var/datum/human_ai_brain/who = entry[2]
		var/kind = entry[3]
		var/line = entry[4]
		kinds[kind] = TRUE
		TEST_ASSERT(GLOB.human_ai_expressions[kind], "A bark of an unknown kind [kind]")
		TEST_ASSERT_EQUAL(entry[6], CONSCIOUS, "A [kind] bark came from a body that was not conscious")
		TEST_ASSERT(!line || (istext(line) && !findtext(line, "%")), "A bark has a broken line: [line]")
		if(last_by_brain[who])
			TEST_ASSERT(when - last_by_brain[who] >= HAI_TALK_CRITICAL_GAP, "[who.body] spoke twice within [when - last_by_brain[who]] ticks")
		last_by_brain[who] = when
		var/list/rule = GLOB.human_ai_expressions[kind]
		var/key = "[REF(who)][kind]"
		if(last_by_kind[key])
			TEST_ASSERT(when - last_by_kind[key] >= rule[1] * 0.6 - 1, "[who.body] said [kind] twice within [when - last_by_kind[key]] ticks")
		last_by_kind[key] = when
		times += when
		var/area/where = entry[5]
		if(!area_times[where])
			area_times[where] = list()
		area_times[where] += when
	TEST_NOTICE(src, "[total] barks of [length(kinds)] kinds in [seconds] seconds from 30 brains, [SShuman_ai.total_barks] counted")
	TEST_ASSERT(total >= 3, "Thirty fighting brains said only [total] things")
	TEST_ASSERT(length(kinds) >= 2, "The chatter had only [length(kinds)] kinds")
	TEST_ASSERT(total <= HAI_TALK_GLOBAL_CAP * (seconds / 10 + 1), "[total] barks in [seconds] seconds broke the global cap")
	for(var/index in 1 to length(times))
		var/inside = 0
		for(var/other in times)
			if(other >= times[index] && other < times[index] + HAI_TALK_AREA_WINDOW)
				inside++
		TEST_ASSERT(inside <= HAI_TALK_GLOBAL_CAP * 2, "[inside] barks fell inside one second window")
	for(var/area/where as anything in area_times)
		var/list/stamps = area_times[where]
		for(var/index in 1 to length(stamps))
			var/inside = 0
			for(var/other in stamps)
				if(other >= stamps[index] && other < stamps[index] + HAI_TALK_AREA_WINDOW)
					inside++
			TEST_ASSERT(inside <= HAI_TALK_AREA_CAP * 2, "[inside] barks fell inside one second window in [where]")
	for(var/mob/living/carbon/human/soldier as anything in bodies)
		if(soldier.ai_brain)
			TEST_ASSERT_EQUAL(soldier.ai_brain.error_total, 0, "A brain threw errors during the audit: [soldier.ai_brain.decision_log.Join(" | ")]")
	for(var/mob/living/carbon/human/soldier as anything in bodies)
		detach_human_ai(soldier)
	for(var/datum/human_ai_squad/squad as anything in GLOB.human_ai_squads.Copy())
		qdel(squad)
