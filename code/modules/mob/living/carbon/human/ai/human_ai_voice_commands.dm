/**
 * What a friendly player can say near a unit, and what it asks of it. The first group with a phrase in the sentence is the one used, so the
 * longer and more specific groups come first: "hold fire" has to be seen before "hold position" and "cover me" before "take cover". Only whole
 * phrases count, a bare "stay" or "stop" in passing chatter does nothing. Phrases are lower case and have no punctuation.
 */
GLOBAL_LIST_INIT(human_ai_voice_commands, list(
	"surrender" = list("i surrender", "we surrender", "surrender", "i give up", "we give up", "i yield", "im unarmed", "dont shoot im unarmed", "dont shoot me"),
	"stand_down" = list("hold fire", "cease fire", "ceasefire", "stand down", "stop shooting", "dont shoot", "do not shoot", "stop firing"),
	"carry_on" = list("weapons free", "open fire", "fire at will", "carry on", "as you were", "free to engage", "resume"),
	"medic" = list("medic", "medic here", "need a medic", "corpsman", "need a doc", "man down", "im hit", "im down"),
	"fortify" = list("fortify", "fortify here", "fortify this position", "dig in", "build a barricade", "build barricades", "set up defenses", "set up a defense", "barricade this"),
	"escort" = list("cover me", "watch my back", "watch my six", "guard me", "protect me"),
	"fall_back" = list("fall back", "pull back", "retreat", "back off", "withdraw"),
	"cover" = list("take cover", "get down", "get to cover", "find cover", "get in cover"),
	"regroup" = list("regroup", "rally on me", "rally here", "form up"),
	"follow" = list("follow me", "stick with me", "stay with me", "with me", "on me", "on my six"),
	"come" = list("come here", "come to me", "over here", "to me", "get over here", "move up"),
	"hold_area" = list("hold this area", "hold the area", "hold this room", "defend this area", "defend the area", "defend here", "secure this area", "secure the area"),
	"hold" = list("hold position", "hold here", "hold the line", "hold this position", "stay here", "stay put", "wait here"),
))

/// Rounds in the last utterance a speaker made that were answered, speaker reference text to list(when, answers)
GLOBAL_LIST_EMPTY(human_ai_voice_batches)

/// The words of a sentence in lower case with the punctuation taken out and a space at each end, so a phrase can be looked for between spaces
/proc/human_ai_speech_words(message)
	var/words = lowertext(copytext("[message]", 1, 160))
	for(var/mark in list("'", "`"))
		words = replacetext(words, mark, "")
	for(var/mark in list(",", ".", "!", "?", ";", ":", "\"", "-", "(", ")", "*", "~", "/", "\\"))
		words = replacetext(words, mark, " ")
	while(findtext(words, "  "))
		words = replacetext(words, "  ", " ")
	return " [trim(words)] "

/// The turf a stretch ahead of the mob, as far as the way is open
/proc/human_ai_turf_ahead(mob/looker, distance)
	RETURN_TYPE(/turf)
	var/turf/found = get_turf(looker)
	for(var/step_count in 1 to distance)
		var/turf/next_turf = get_step(found, looker.dir)
		if(!next_turf || next_turf.density)
			break
		found = next_turf
	return found

/// The command a sentence gives, null when it gives none
/proc/human_ai_voice_command(message)
	var/words = human_ai_speech_words(message)
	for(var/command in GLOB.human_ai_voice_commands)
		for(var/phrase in GLOB.human_ai_voice_commands[command])
			if(findtext(words, " [phrase] "))
				return command
	return null

/// Words spoken near a human reach its brain, which decides whether it was spoken to
/mob/living/carbon/human/hear_say(message, verb, datum/language/language, alt_name, italics, mob/speaker, sound/speech_sound, sound_vol)
	. = ..()
	if(ai_brain && speaker && speaker != src && say_understands(speaker, language))
		ai_brain.overhear(speaker, message)

/// Whether the words call this body by a name it goes by
/datum/human_ai_brain/proc/is_named_in(words)
	for(var/token in splittext(lowertext(body.real_name), " "))
		if(length(token) >= 3 && findtext(words, " [token] "))
			return TRUE
	return FALSE

/// Whether the words call someone else near the speaker by name, in which case they were not meant for this body
/datum/human_ai_brain/proc/names_someone_else(words, mob/speaker)
	for(var/mob/living/carbon/human/other in view(HAI_VOICE_RANGE, speaker))
		if(other != body && other.ai_brain && other.ai_brain.is_named_in(words))
			return TRUE
	return FALSE

/**
 * A sentence spoken near the body. A friendly player within earshot who gives a command, to everyone or by name, is treated as a request: the
 * unit obeys unless it balks at the danger. Other units, the other side and chatter that gives no command are ignored. True when it acted.
 */
/datum/human_ai_brain/proc/overhear(mob/speaker, message)
	if(stopped || QDELETED(body) || body.stat != CONSCIOUS || is_civilian() || surrendered || broken_kind)
		return FALSE
	if(!ishuman(speaker))
		return FALSE
	var/mob/living/carbon/human/commander = speaker
	if(commander.ai_brain || commander.stat != CONSCIOUS || commander.handcuffed || commander.z != body.z || get_dist(body, commander) > HAI_VOICE_RANGE)
		return FALSE
	var/command = human_ai_voice_command(message)
	if(!command)
		return FALSE
	var/speaker_key = REF(commander)
	var/friendly = get_disposition(commander) <= HAI_DISP_FRIEND
	// Giving up means something to the other side only, a friend saying it is just talk
	if(command == "surrender")
		return !friendly && hear_surrender(commander)
	if(world.time < voice_heard[speaker_key] + HAI_VOICE_GAP || !friendly)
		return FALSE
	var/words = human_ai_speech_words(message)
	var/named = is_named_in(words)
	if(!named && names_someone_else(words, commander))
		return FALSE
	// A shout reaches a limited number of units, the ones who happen to hear it first
	var/list/batch = GLOB.human_ai_voice_batches[speaker_key]
	if(!named)
		if(batch && batch[1] == world.time && batch[2] >= HAI_VOICE_ANSWERS)
			return FALSE
		if(!batch || batch[1] != world.time)
			batch = list(world.time, 0)
			if(length(GLOB.human_ai_voice_batches) >= 30)
				GLOB.human_ai_voice_batches.Cut(1, 2)
			GLOB.human_ai_voice_batches[speaker_key] = batch
		batch[2]++
	if(length(voice_heard) >= 6)
		voice_heard.Cut(1, 2)
	voice_heard[speaker_key] = world.time
	return obey_voice(command, commander)

/// Whether a man holds a gun in either hand
/proc/human_ai_holds_gun(mob/living/carbon/human/other)
	return istype(other.l_hand, /obj/item/weapon/gun) || istype(other.r_hand, /obj/item/weapon/gun)

/**
 * An enemy in earshot calls out that they give up. A unit with some mercy takes them at their word for a while and stops fighting them, as long as
 * they keep their hands off a gun, and it will put restraints on them if it can. Zealots and the merciless do not care.
 */
/datum/human_ai_brain/proc/hear_surrender(mob/living/carbon/human/captive)
	if(personality.trait("mercy") < HAI_SURRENDER_MERCY || human_ai_holds_gun(captive) || !(captive in view(HAI_VOICE_RANGE, body)))
		return FALSE
	if(length(surrender_accepted) >= 6)
		surrender_accepted.Cut(1, 2)
	surrender_accepted[REF(captive)] = world.time + HAI_SURRENDER_ACCEPT_TIME
	if(get_target() == captive)
		set_target(null)
	remove_contact(captive)
	body.face_atom(captive)
	surrenders_taken++
	log_decision("took the surrender of [captive]")
	return TRUE

/// Whether this human gave up to the brain not long ago and has not picked a gun up since
/datum/human_ai_brain/proc/accepts_surrender_of(mob/living/carbon/human/other)
	var/until = surrender_accepted[REF(other)]
	if(!until || world.time > until)
		return FALSE
	return !human_ai_holds_gun(other) && other.stat != DEAD

/// Turns a spoken command into the order or the action it asks for, true when the unit took it up
/datum/human_ai_brain/proc/obey_voice(command, mob/living/carbon/human/commander)
	var/turf/there = get_turf(commander)
	// Where trouble is thought to be: where the unit's own enemy stands, or a stretch ahead of the one who spoke
	var/turf/threat = get_target() ? get_turf(get_target()) : human_ai_turf_ahead(commander, 6)
	if(threat == there)
		threat = null
	var/datum/npc_order/order
	switch(command)
		if("medic")
			// Not an order: the nearest medics pick the call up
			GLOB.human_ai_medic_calls[REF(commander)] = list(world.time, there, commander.faction)
			voice_orders++
			log_decision("heard [commander] call for a medic")
			return TRUE
		if("carry_on")
			end_stand_down()
			if(current_order)
				cancel_order("[commander] said to carry on")
			express(HAI_EXPR_ACK)
			voice_orders++
			return TRUE
		if("stand_down")
			order = new /datum/npc_order/stand_down
		if("fortify")
			// Only an engineer with something to build with takes this up, nobody else answers
			if(!role?.supports_order("fortify") || !find_building_stack())
				return FALSE
			var/datum/npc_order/fortify/fortify_order = new
			fortify_order.target_turf = human_ai_turf_ahead(commander, 3)
			fortify_order.facing = commander.dir
			order = fortify_order
		if("escort")
			var/datum/npc_order/escort/guard_order = new
			guard_order.set_target(commander)
			order = guard_order
		if("fall_back")
			var/datum/npc_order/fall_back/retreat_order = new
			retreat_order.target_turf = (threat ? retreat_turf(threat) : null) || there
			order = retreat_order
		if("cover")
			var/datum/npc_order/take_cover/cover_order = new
			cover_order.target_turf = threat
			order = cover_order
		if("regroup")
			var/datum/npc_order/regroup/regroup_order = new
			regroup_order.target_turf = there
			order = regroup_order
		if("follow")
			var/datum/npc_order/follow/follow_order = new
			follow_order.set_target(commander)
			order = follow_order
		if("come")
			var/datum/npc_order/move/move_order = new
			move_order.target_turf = there
			move_order.radius = 2
			order = move_order
		if("hold_area")
			var/datum/npc_order/hold_area/area_order = new
			area_order.target_turf = there
			order = area_order
		if("hold")
			order = new /datum/npc_order/hold
	if(!order)
		return FALSE
	order.issuer = commander.real_name
	if(!give_order(order, HAI_DELIVERY_REQUEST))
		return FALSE
	voice_orders++
	return TRUE
