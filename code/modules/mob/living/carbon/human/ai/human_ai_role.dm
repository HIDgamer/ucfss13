/// Every role kit by id
GLOBAL_LIST_INIT(human_ai_roles, init_human_ai_roles())

/proc/init_human_ai_roles()
	var/list/kits = list()
	for(var/role_type in subtypesof(/datum/human_ai_role))
		var/datum/human_ai_role/kit = new role_type
		if(!kit.id)
			qdel(kit)
			continue
		kits[kit.id] = kit
	return kits

/proc/get_human_ai_role(id)
	return GLOB.human_ai_roles[id] || GLOB.human_ai_roles["rifleman"]

/**
 * The role a job calls for, null when it is none of the ones with duties of their own. The jobs of the different sides are named too differently for
 * a list of them, so the words in the name decide: a corpsman, a field medic and a trauma surgeon all treat the wounded.
 */
/proc/human_ai_role_for_job(job)
	var/text = lowertext("[job]")
	if(!length(text))
		return null
	for(var/keyword in list("working joe", "hazmat joe", "hazard joe", "dzho automaton"))
		if(findtext(text, keyword))
			return "working_joe"
	for(var/keyword in list("corpsman", "medic", "doctor", "surgeon", "nurse"))
		if(findtext(text, keyword))
			return "medic"
	for(var/keyword in list("engineer", "combat technician", "maintenance technician", "ordnance technician", "field technician", "corporate technician", "security technician"))
		if(findtext(text, keyword))
			return "engineer"
	for(var/keyword in list("police", "warden", "marshal", "enforcer", "inspector", "politsiya", "chief mp", "honor guard"))
		if(findtext(text, keyword))
			return "security"
	return null

/// What a brain does for a living: the orders beyond the base set it can carry out
/datum/human_ai_role
	/// Unique key, empty leaves the type abstract
	var/id
	var/name
	var/list/orders = list()
	/// Added to the leader election score
	var/leader_bonus = 0
	/// Picks a covered nest and holds it
	var/nests = FALSE
	/// Never closes in on an enemy
	var/passive = FALSE
	/// Charges in without caring for cover or range
	var/rushes = FALSE
	/// Is who a squad sends round the side
	var/flanks = FALSE
	/// Holds fire until the enemy is close or has found it
	var/ambush = FALSE
	/// Arms a grenade in its hand and runs at the enemy
	var/bomber = FALSE
	/// Puts up with hits from anyone it is not at war with and only fights back once it has been bothered more than it will stand
	var/tolerant = FALSE
	/// Goes round mending, cleaning and putting right what is broken
	var/maintains = FALSE
	/// Speaks in the lines of a Working Joe's voice synthesizer
	var/joe_voice = FALSE

/// Adds what the role's duties need and the equipment left out
/datum/human_ai_role/proc/equip_kit(datum/human_ai_brain/brain)
	return

/// Makes one of the item and puts it in the first bag that takes it, nothing is kept if there is no room
/datum/human_ai_brain/proc/give_kit_item(item_type, amount)
	var/obj/item/item = amount ? new item_type(body, amount) : new item_type(body)
	if(!stow_item(item) && !QDELETED(item))
		qdel(item)

/datum/human_ai_role/proc/supports_order(order_id)
	return order_id in orders

/datum/human_ai_role/rifleman
	id = "rifleman"
	name = "Rifleman"

/datum/human_ai_role/medic
	id = "medic"
	name = "Medic"
	orders = list("triage")

/datum/human_ai_role/medic/equip_kit(datum/human_ai_brain/brain)
	var/list/supplies = brain.medical_supplies()
	if(!length(supplies[HAI_MED_BANDAGE]))
		brain.give_kit_item(/obj/item/stack/medical/bruise_pack)
	if(!length(supplies[HAI_MED_SALVE]))
		brain.give_kit_item(/obj/item/stack/medical/ointment)
	if(!length(supplies[HAI_MED_SPLINT]))
		brain.give_kit_item(/obj/item/stack/medical/splint)
	if(!length(supplies[HAI_MED_INJECTOR]))
		brain.give_kit_item(/obj/item/reagent_container/hypospray/autoinjector/bicaridine/skillless)
		brain.give_kit_item(/obj/item/reagent_container/hypospray/autoinjector/kelotane/skillless)
		brain.give_kit_item(/obj/item/reagent_container/hypospray/autoinjector/tricord/skillless)
	brain.med_cache = null

/datum/human_ai_role/engineer
	id = "engineer"
	name = "Engineer"
	orders = list("fortify", "demolish", "rig_door", "guard_door")

/datum/human_ai_role/engineer/equip_kit(datum/human_ai_brain/brain)
	if(!brain.find_building_stack())
		brain.give_kit_item(/obj/item/stack/sheet/metal, 50)

/datum/human_ai_role/security
	id = "security"
	name = "Security"
	orders = list("breach")

/datum/human_ai_role/security/equip_kit(datum/human_ai_brain/brain)
	if(!brain.find_cuffs())
		brain.give_kit_item(/obj/item/restraint/handcuffs)
	if(!brain.find_baton())
		brain.give_kit_item(/obj/item/weapon/baton)

/datum/human_ai_role/leader
	id = "leader"
	name = "Leader"
	leader_bonus = 60

/datum/human_ai_role/sniper
	id = "sniper"
	name = "Sniper"
	nests = TRUE

/datum/human_ai_role/machinegunner
	id = "machinegunner"
	name = "Machinegunner"
	nests = TRUE

/datum/human_ai_role/grenadier
	id = "grenadier"
	name = "Grenadier"

/datum/human_ai_role/civilian
	id = "civilian"
	name = "Civilian"
	passive = TRUE

/datum/human_ai_brain/proc/set_role(role_id)
	role = get_human_ai_role(role_id)
	med_cache = null
	role.equip_skills(body)
	log_decision("role [role.id]")
