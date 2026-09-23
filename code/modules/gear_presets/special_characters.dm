/**
 * One-off VIP character presets - not real jobs, not round-start selectable (EQUIPMENT_PRESET_EXTRA
 * only, same flag "Zombie"/"Gladiator" use in other.dm), applied entirely through admin action.
 * restricted_to_ckeys (_select_equipment.dm's base /datum/equipment_preset var) is enforced at
 * every real "apply a preset" call site - event_tab.dm's do_redress()/do_spawn_humans(),
 * select_equipment.dm's cmd_admin_dress_human(), and buildmode's outfit.dm - so only an admin
 * whose own ckey is listed can actually apply one of these, regardless of which of those paths
 * they use. GLOB.gear_name_presets_list/arm_equipment() themselves stay completely ungated (an
 * unrestricted preset elsewhere is unaffected), the restriction lives entirely in this list.
 */
// Same as /datum/skills/commander but with surgery bumped to expert (level 3) for this character.
/datum/skills/commander/chrismmar
	skills = list(
		SKILL_ENGINEER = SKILL_ENGINEER_TRAINED,
		SKILL_CONSTRUCTION = SKILL_CONSTRUCTION_ENGI,
		SKILL_LEADERSHIP = SKILL_LEAD_MASTER,
		SKILL_OVERWATCH = SKILL_OVERWATCH_TRAINED,
		SKILL_MEDICAL = SKILL_MEDICAL_DOCTOR,
		SKILL_SURGERY = SKILL_SURGERY_EXPERT,
		SKILL_POLICE = SKILL_POLICE_SKILLED,
		SKILL_FIREMAN = SKILL_FIREMAN_SKILLED,
		SKILL_VEHICLE = SKILL_VEHICLE_LARGE,
		SKILL_CQC = SKILL_CQC_SKILLED,
		SKILL_POWERLOADER = SKILL_POWERLOADER_MASTER,
		SKILL_ENDURANCE = SKILL_ENDURANCE_TRAINED,
		SKILL_JTAC = SKILL_JTAC_MASTER,
		SKILL_EXECUTION = SKILL_EXECUTION_TRAINED,
		SKILL_INTEL = SKILL_INTEL_EXPERT,
		SKILL_NAVIGATIONS = SKILL_NAVIGATIONS_TRAINED,
	)

/datum/equipment_preset/other/commander_chrismmar
	name = "Commander C++ (Chrismmar)"
	flags = EQUIPMENT_PRESET_EXTRA
	restricted_to_ckeys = list("chrismmar", "hidgamer")

	idtype = /obj/item/card/id/gold
	assignment = JOB_CO
	rank = "Commander C++"
	role_comm_title = "CO"
	faction = FACTION_MARINE
	faction_group = FACTION_LIST_MARINE
	skills = /datum/skills/commander/chrismmar
	// /datum/equipment_preset/other (this preset's parent) defaults paygrades to Civilian, which
	// displays as a gendered "Mr./Ms./Mx." prefix (paygrades/helper.dm) instead of a rank - override
	// to Major (MO4) so it shows a real USCM rank instead.
	paygrades = list(PAY_SHORT_MO4 = JOB_PLAYTIME_TIER_0)
	languages = list(LANGUAGE_ENGLISH)

	minimap_icon = "co"
	minimap_background = "background_command"

/datum/equipment_preset/other/commander_chrismmar/New()
	. = ..()
	access = get_access(ACCESS_LIST_MARINE_ALL)

/datum/equipment_preset/other/commander_chrismmar/load_gear(mob/living/carbon/human/new_human)
	// Uniform with the tactical waistcoat attached as a real accessory (attach_accessory() BEFORE
	// equipping, same order clothing_accessories.dm's own convention uses elsewhere) rather than
	// two separate worn pieces.
	var/obj/item/clothing/under/marine/officer/bridge/uniform = new()
	var/obj/item/clothing/accessory/storage/black_vest/waistcoat/waistcoat = new()
	uniform.attach_accessory(new_human, waistcoat)
	new_human.equip_to_slot_or_del(uniform, WEAR_BODY)

	new_human.equip_to_slot_or_del(new /obj/item/clothing/suit/storage/jacket/marine/dress/fur_lined_trench_coat(new_human), WEAR_JACKET)
	new_human.equip_to_slot_or_del(new /obj/item/clothing/gloves/marine/insulated/black(new_human), WEAR_HANDS)
	new_human.equip_to_slot_or_del(new /obj/item/clothing/glasses/sunglasses/sechud(new_human), WEAR_EYES)
	new_human.equip_to_slot_or_del(new /obj/item/clothing/head/beret/marine/commander/black(new_human), WEAR_HEAD)
	new_human.equip_to_slot_or_del(new /obj/item/clothing/shoes/marine(new_human), WEAR_FEET)
	new_human.equip_to_slot_or_del(new /obj/item/storage/pouch/medical/socmed/full(new_human), WEAR_L_STORE)
	new_human.equip_to_slot_or_del(new /obj/item/storage/backpack/satchel/lockable(new_human), WEAR_BACK)
	new_human.equip_to_slot_or_del(new /obj/item/device/radio/headset/almayer/mcom/cdrcom(new_human), WEAR_L_EAR)

	// The engraved Mateba rig worn in the suit-storage slot (WEAR_J_STORE), under the trench coat,
	// instead of the waist - see belt.dm's /obj/item/storage/belt/gun/mateba/chrismmar for the
	// SLOT_SUIT_STORE flag that makes this possible.
	new_human.equip_to_slot_or_del(new /obj/item/storage/belt/gun/mateba/chrismmar(new_human), WEAR_J_STORE)

	. = ..()
