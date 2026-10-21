/**
 * The Working Joe: a synthetic whose job is keeping the ship clean and in repair. It goes round mending lights, scrubbing mess, welding walls, laying
 * tiles and putting APCs right, comes out with its voice lines now and then, and warns people who do something it does not like. It does not take a
 * swing at anyone for a push or a stray shot, only when it has been bothered more than it will put up with, and then it fights back until it is
 * left alone. The lines are the ones the Joe's own voice synthesizer has, in the sounds it has.
 */
/datum/human_ai_role/working_joe
	id = "working_joe"
	name = "Working Joe"
	passive = TRUE
	tolerant = TRUE
	maintains = TRUE
	joe_voice = TRUE

/datum/human_ai_role/working_joe/equip_skills(mob/living/carbon/human/body)
	if(!body.skills)
		body.skills = new /datum/skills()
	if(body.skills.get_skill_level(SKILL_ENGINEER) < SKILL_ENGINEER_ENGI)
		body.skills.set_skill(SKILL_ENGINEER, SKILL_ENGINEER_ENGI)
	if(body.skills.get_skill_level(SKILL_CONSTRUCTION) < SKILL_CONSTRUCTION_ENGI)
		body.skills.set_skill(SKILL_CONSTRUCTION, SKILL_CONSTRUCTION_ENGI)

/// Whatever of the tools of the trade the Joe came without is added, what it already has is kept
/datum/human_ai_role/working_joe/equip_kit(datum/human_ai_brain/brain)
	if(!brain.find_lightreplacer())
		brain.give_kit_item(/obj/item/device/lightreplacer)
	if(!brain.find_welder())
		brain.give_kit_item(/obj/item/tool/weldingtool)
	if(!brain.find_tool(TRAIT_TOOL_CROWBAR))
		brain.give_kit_item(/obj/item/tool/crowbar)
	if(!brain.find_tool(TRAIT_TOOL_SCREWDRIVER))
		brain.give_kit_item(/obj/item/tool/screwdriver)
	if(!brain.find_tool(TRAIT_TOOL_WIRECUTTERS))
		brain.give_kit_item(/obj/item/tool/wirecutters)
	if(!brain.find_item_of(/obj/item/stack/cable_coil))
		brain.give_kit_item(/obj/item/stack/cable_coil, 30)
	if(!brain.find_item_of(/obj/item/stack/tile))
		brain.give_kit_item(/obj/item/stack/tile/plasteel, 20)
	if(!brain.find_item_of(/obj/item/frame/apc))
		brain.give_kit_item(/obj/item/frame/apc)
	if(!brain.find_item_of(/obj/item/circuitboard/apc))
		brain.give_kit_item(/obj/item/circuitboard/apc)
	if(!brain.find_item_of(/obj/item/cell))
		brain.give_kit_item(/obj/item/cell)
	if(!brain.find_item_of(/obj/item/stack/sheet/glass))
		brain.give_kit_item(/obj/item/stack/sheet/glass, 20)
	if(!brain.find_item_of(/obj/item/tool/mop))
		brain.give_kit_item(/obj/item/tool/mop)

/**
 * What a Joe says about each thing that goes on around it: the fewest deciseconds between two of that kind and the categories of its voice
 * synthesizer the line is picked from. Anything not in here it keeps quiet about, a Joe does not shout call-outs in a fight.
 */
GLOBAL_LIST_INIT(human_ai_joe_kinds, list(
	HAI_EXPR_QUIP = list(250, list(JOE_EMOTE_CATEGORY_QUIP)),
	HAI_EXPR_IDLE = list(300, list(JOE_EMOTE_CATEGORY_QUIP)),
	HAI_EXPR_TASK = list(200, list(JOE_EMOTE_CATEGORY_TASK_UPDATE)),
	HAI_EXPR_NOTICE = list(600, list(JOE_EMOTE_CATEGORY_NOTICE)),
	HAI_EXPR_WARN = list(80, list(JOE_EMOTE_CATEGORY_WARNING)),
	HAI_EXPR_WATCH_FIRE = list(50, list(JOE_EMOTE_CATEGORY_WARNING, JOE_EMOTE_CATEGORY_DAMAGE)),
	HAI_EXPR_HOSTILE = list(60, list(JOE_EMOTE_CATEGORY_DAMAGE, JOE_EMOTE_CATEGORY_RESTRICTED_AREA)),
	HAI_EXPR_CHALLENGE = list(80, list(JOE_EMOTE_CATEGORY_RESTRICTED_AREA, JOE_EMOTE_CATEGORY_QUESTION)),
	HAI_EXPR_PAIN = list(40, list(JOE_EMOTE_CATEGORY_DAMAGE)),
	HAI_EXPR_TAKING_FIRE = list(60, list(JOE_EMOTE_CATEGORY_DAMAGE)),
	HAI_EXPR_BATTLE_CRY = list(100, list(JOE_EMOTE_CATEGORY_DAMAGE)),
	HAI_EXPR_CONTACT = list(150, list(JOE_EMOTE_CATEGORY_NOTICE)),
	HAI_EXPR_XENO = list(150, list(JOE_EMOTE_CATEGORY_NOTICE)),
	HAI_EXPR_BACKUP = list(200, list(JOE_EMOTE_CATEGORY_NOTICE)),
	HAI_EXPR_GREET = list(600, list(JOE_EMOTE_CATEGORY_GREETING)),
	HAI_EXPR_CLEAR = list(200, list(JOE_EMOTE_CATEGORY_FAREWELL)),
	HAI_EXPR_MAN_DOWN = list(100, list(JOE_EMOTE_CATEGORY_QUESTION)),
))

/// The voice lines of the Joe's own synthesizer that are in one of the categories, as emote types
/datum/human_ai_brain/proc/joe_lines(list/categories)
	var/list/pool = GLOB.wj_emotes
	if(ishazardjoe(body))
		pool = GLOB.hj_emotes
	else if(isuppjoe(body))
		pool = GLOB.uppj_emotes
	var/list/fits = list()
	for(var/datum/emote/living/carbon/human/synthetic/working_joe/candidate as anything in pool)
		if(initial(candidate.category) in categories)
			fits += candidate
	return fits

/// Says a line for what is going on in the Joe's voice, an emote with its sound for a Joe and the same words said for a body that is not one. True when it did.
/datum/human_ai_brain/proc/joe_express(kind)
	var/list/rule = GLOB.human_ai_joe_kinds[kind]
	if(!rule || !can_express())
		return FALSE
	var/last_said = talk_times[kind]
	if((!isnull(last_said) && world.time < last_said + rule[1]) || (last_talk_time && world.time < last_talk_time + HAI_TALK_CRITICAL_GAP))
		return FALSE
	var/area/here = get_area(body)
	if(!SShuman_ai.talk_allowed(here))
		return FALSE
	var/list/fits = joe_lines(rule[2])
	if(!length(fits))
		return FALSE
	var/datum/emote/living/carbon/human/synthetic/working_joe/choice = pick(fits)
	var/key = initial(choice.key)
	var/text = initial(choice.say_message)
	talk_times[kind] = world.time
	last_talk_time = world.time
	barks++
	SShuman_ai.note_talk(src, kind, text, here)
	if(isworkingjoe(body))
		INVOKE_ASYNC(body, TYPE_PROC_REF(/mob, emote), key, null, null, FALSE, TRUE)
		emotes_made++
	else
		INVOKE_ASYNC(body, TYPE_PROC_REF(/mob, say), text)
	return TRUE

/// Whether a hit from the person is put up with for a while instead of answered, which for a Joe goes for anyone who is not an enemy to it
/datum/human_ai_brain/proc/tolerates_hits_from(mob/living/other)
	var/disposition = get_disposition(other)
	if(role?.tolerant)
		return disposition <= HAI_DISP_NEUTRAL
	return disposition <= HAI_DISP_FRIEND

/// Whatever is in the hands that is no weapon goes away, a Joe hits harder with its fists than with a mop or a welder
/datum/human_ai_brain/proc/ready_fists()
	for(var/obj/item/held in list(body.get_active_hand(), body.get_inactive_hand()))
		if(QDELETED(held) || (held.flags_item & (NODROP|ITEM_ABSTRACT)) || istype(held, /obj/item/weapon))
			continue
		power_down_welder(held)
		power_down_defibrillator(held)
		stow_item(held)

/// Lets a word slip now and then, and looks over the people close by for something to say about them
/datum/human_ai_action/joe_manner
	id = "joe_manner"
	intents = list(HAI_INTENT_IDLE, HAI_INTENT_ALERT)

/datum/human_ai_action/joe_manner/get_weight(datum/human_ai_brain/brain)
	if(!brain.role?.joe_voice || brain.surrendered || brain.broken_kind)
		return 0
	return (world.time >= brain.next_joe_quip || world.time >= brain.next_joe_watch) ? 5 : 0

/datum/human_ai_action/joe_manner/trigger(datum/human_ai_brain/brain)
	// A Joe that has only just been switched on takes a while before its first word
	if(!brain.next_joe_quip)
		brain.next_joe_quip = world.time + rand(HAI_JOE_QUIP_GAP_MIN, HAI_JOE_QUIP_GAP_MAX)
	else if(world.time >= brain.next_joe_quip)
		brain.next_joe_quip = world.time + rand(HAI_JOE_QUIP_GAP_MIN, HAI_JOE_QUIP_GAP_MAX)
		brain.express(HAI_EXPR_QUIP)
	if(world.time >= brain.next_joe_watch)
		brain.next_joe_watch = world.time + HAI_JOE_WATCH_GAP
		brain.watch_people()
	// Takes no limbs of its own, a word does not stop the work
	return FALSE

/// Runners get told to slow down, and somebody carrying a gun gets asked about it, each person only once in a while
/datum/human_ai_brain/proc/watch_people()
	for(var/key in joe_noticed)
		if(joe_noticed[key] < world.time)
			joe_noticed -= key
	for(var/mob/living/carbon/human/other in view(HAI_JOE_WATCH_RANGE, body))
		if(other == body || other.stat != CONSCIOUS || joe_noticed[REF(other)] || get_disposition(other) > HAI_DISP_NEUTRAL)
			continue
		if(other.sprinting)
			joe_noticed[REF(other)] = world.time + 30 SECONDS
			body.face_atom(other)
			express(HAI_EXPR_WARN)
			return
		if(istype(other.get_active_hand(), /obj/item/weapon/gun) && !isworkingjoe(other))
			joe_noticed[REF(other)] = world.time + 90 SECONDS
			body.face_atom(other)
			express(HAI_EXPR_NOTICE)
			return
