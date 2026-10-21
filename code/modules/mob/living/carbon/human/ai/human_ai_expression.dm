/**
 * How each kind of expression behaves: the fewest deciseconds between two of the kind, whether it always gets past the
 * chattiness roll, and the emote that goes with it. Kinds without a line only emote.
 */
GLOBAL_LIST_INIT(human_ai_expressions, list(
	HAI_EXPR_CONTACT = list(80, TRUE, null),
	HAI_EXPR_XENO = list(120, TRUE, null),
	HAI_EXPR_RELOAD = list(150, FALSE, null),
	HAI_EXPR_COVER_ME = list(200, FALSE, null),
	HAI_EXPR_FRAG = list(40, TRUE, null),
	HAI_EXPR_FLASH = list(40, TRUE, null),
	HAI_EXPR_SMOKE = list(40, TRUE, null),
	HAI_EXPR_PAIN = list(60, FALSE, "pain"),
	HAI_EXPR_MAN_DOWN = list(100, TRUE, null),
	HAI_EXPR_MEDIC = list(150, TRUE, "medic"),
	HAI_EXPR_TAKING_FIRE = list(100, FALSE, null),
	HAI_EXPR_FEAR = list(80, TRUE, "whimper"),
	HAI_EXPR_CHALLENGE = list(80, TRUE, null),
	HAI_EXPR_WARN = list(80, TRUE, null),
	HAI_EXPR_HOSTILE = list(80, TRUE, null),
	HAI_EXPR_SURRENDER = list(200, TRUE, null),
	HAI_EXPR_GREET = list(600, FALSE, "wave"),
	HAI_EXPR_CLEAR = list(200, FALSE, null),
	HAI_EXPR_KILL = list(150, FALSE, null),
	HAI_EXPR_TAUNT = list(200, FALSE, null),
	HAI_EXPR_BATTLE_CRY = list(250, FALSE, "warcry"),
	HAI_EXPR_IDLE = list(300, FALSE, null),
	HAI_EXPR_REFUSE = list(60, TRUE, "shakehead"),
	HAI_EXPR_ACK = list(100, FALSE, "nod"),
	HAI_EXPR_FALL_BACK = list(150, TRUE, null),
	HAI_EXPR_MOVING = list(150, FALSE, null),
	HAI_EXPR_EXPLOSION = list(100, FALSE, null),
	HAI_EXPR_CONVO = list(600, FALSE, null),
	HAI_EXPR_RALLY = list(120, TRUE, null),
	HAI_EXPR_WATCH_FIRE = list(60, TRUE, null),
	HAI_EXPR_BACKUP = list(200, TRUE, null),
))

/// Whether the body is in a state to talk or emote at all
/datum/human_ai_brain/proc/can_express()
	if(QDELETED(body) || body.stat != CONSCIOUS || body.is_mob_incapacitated() || body.silent)
		return FALSE
	return TRUE

/**
 * Says the line of the kind that suits the brain's side and nature, if it has the right to talk right now.
 * Costs a place in the brain's own pacing, the area's and the whole server's, so it can never flood the chat.
 * extra fills %dir% in the line, emote_override replaces the emote that goes with the kind.
 */
/datum/human_ai_brain/proc/express(kind, extra, emote_override)
	var/list/rule = GLOB.human_ai_expressions[kind]
	if(!rule || !can_express())
		return FALSE
	var/strained = SSlag_switch.measures[SIMPLIFY_HUMAN_AI] || SSlag_switch.measures[DISABLE_LANGCHAT]
	var/critical = rule[2]
	if(strained && !critical)
		return FALSE
	var/cooldown = rule[1] * personality.scaled("chattiness", 1.8, 0.6) * (strained ? 2 : 1) * (critical ? 1 : HAI_TALK_ROUTINE_COOLDOWN_MULT)
	var/last_said = talk_times[kind]
	if((!isnull(last_said) && world.time < last_said + cooldown) || (last_talk_time && world.time < last_talk_time + (critical ? HAI_TALK_CRITICAL_GAP : HAI_TALK_MIN_GAP)))
		return FALSE
	if(!critical && !prob(HAI_TALK_ROLL_BASE + personality.trait("chattiness") * HAI_TALK_ROLL_PER_CHATTINESS))
		talk_times[kind] = world.time
		return FALSE
	var/area/here = get_area(body)
	if(!SShuman_ai.talk_allowed(here))
		return FALSE
	var/datum/human_ai_voice/voice = get_human_ai_voice(body.faction)
	var/line = voice.line(kind, personality.id)
	var/emote = emote_override || rule[3]
	if(!line && !emote)
		return FALSE
	if(line)
		line = replacetext(line, "%dir%", extra || "ahead")
		line = replacetext(line, "%area%", here?.name || "this area")
		if(radio_worthy(kind))
			line = ";[line]"
	talk_times[kind] = world.time
	last_talk_time = world.time
	barks++
	SShuman_ai.note_talk(src, kind, line, here)
	if(kind == HAI_EXPR_MEDIC)
		GLOB.human_ai_medic_calls[REF(body)] = list(world.time, get_turf(body), body.faction)
	if(line)
		INVOKE_ASYNC(body, TYPE_PROC_REF(/mob, say), line)
	if(emote && (!line || prob(HAI_TALK_EMOTE_CHANCE)))
		INVOKE_ASYNC(body, TYPE_PROC_REF(/mob, emote), emote, null, null, FALSE, TRUE)
		emotes_made++
	return TRUE

/// Says a line the caller already chose, for conversations
/datum/human_ai_brain/proc/express_line(kind, line)
	if(!can_express() || !line)
		return FALSE
	var/area/here = get_area(body)
	if((last_talk_time && world.time < last_talk_time + HAI_TALK_MIN_GAP) || !SShuman_ai.talk_allowed(here))
		return FALSE
	talk_times[kind] = world.time
	last_talk_time = world.time
	barks++
	SShuman_ai.note_talk(src, kind, line, here)
	INVOKE_ASYNC(body, TYPE_PROC_REF(/mob, say), line)
	return TRUE

/// Whether the body wears a headset to speak into
/datum/human_ai_brain/proc/has_headset()
	return istype(body.wear_l_ear, /obj/item/device/radio/headset) || istype(body.wear_r_ear, /obj/item/device/radio/headset)

/// Time a faction's units may next call for backup over the radio, so a whole firefight does not drown the channel
GLOBAL_LIST_EMPTY(human_ai_backup_radio)

/**
 * Kinds that go over the radio when the body wears a headset: a squad's call-outs at most once in a while per squad, and a call for backup from
 * anyone, squad or not, at most once in a while per faction.
 */
/datum/human_ai_brain/proc/radio_worthy(kind)
	if(!has_headset())
		return FALSE
	if(kind == HAI_EXPR_BACKUP)
		if(world.time < GLOB.human_ai_backup_radio[body.faction])
			return FALSE
		GLOB.human_ai_backup_radio[body.faction] = world.time + HAI_BACKUP_RADIO_GAP
		return TRUE
	if(!squad || !(kind in list(HAI_EXPR_CONTACT, HAI_EXPR_XENO, HAI_EXPR_MAN_DOWN, HAI_EXPR_MEDIC, HAI_EXPR_FALL_BACK)))
		return FALSE
	return squad.take_radio()

/// Compass word for where the thing is from the body, for call-outs
/datum/human_ai_brain/proc/direction_to(atom/thing)
	return dir2text(get_dir(body, thing))

/datum/human_ai_squad/proc/take_radio()
	if(world.time < next_radio_time)
		return FALSE
	next_radio_time = world.time + HAI_RADIO_GAP
	radio_calls++
	return TRUE

/datum/controller/subsystem/human_ai/proc/talk_allowed(area/where)
	if(!where)
		return FALSE
	if(world.time >= talk_window_end)
		talk_window_end = world.time + HAI_TALK_AREA_WINDOW
		talk_count = 0
		area_talk = list()
	if(talk_count >= HAI_TALK_GLOBAL_CAP || area_talk[where] >= HAI_TALK_AREA_CAP)
		return FALSE
	area_talk[where]++
	talk_count++
	return TRUE

/datum/controller/subsystem/human_ai/proc/note_talk(datum/human_ai_brain/brain, kind, line, area/where)
	total_barks++
	if(!record_talk)
		return
	talk_log += list(list(world.time, brain, kind, line, where, brain.body.stat))
	if(length(talk_log) > 400)
		talk_log.Cut(1, 2)

/// Hooks into the rest of the brain: what happens in the fight makes the brain say something

/datum/human_ai_brain/proc/announce_contact(mob/living/subject)
	panic()
	// The first contact of a fight is a call for backup naming the area, the ones after it are the plain call-outs
	if(call_for_backup(subject))
		return
	if(isxeno(subject) || iszombie(subject))
		express(HAI_EXPR_XENO, direction_to(subject))
	else
		express(HAI_EXPR_CONTACT, direction_to(subject))

/datum/human_ai_brain/proc/announce_kill()
	if(personality.trait("mercy") <= 20)
		express(HAI_EXPR_TAUNT)
	else if(!express(HAI_EXPR_KILL))
		express(HAI_EXPR_CLEAR)

/datum/human_ai_brain/proc/announce_break(kind)
	switch(kind)
		if(HAI_BREAK_SURRENDER)
			express(HAI_EXPR_SURRENDER)
		if(HAI_BREAK_BERSERK)
			express(HAI_EXPR_BATTLE_CRY, null, "scream")
		if(HAI_BREAK_FLEE)
			express(HAI_EXPR_FEAR, null, "scream")
		else
			express(HAI_EXPR_FEAR)
