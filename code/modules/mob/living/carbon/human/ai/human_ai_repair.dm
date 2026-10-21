/**
 * Synthetics are no use as patients for bandages and injections: a dented limb needs a welder and a burnt one needs cable, which is engineering and
 * not medicine. This is how a synthetic mends itself, or anyone with a welder and cable mends one.
 */
/datum/human_ai_brain/proc/repair(mob/living/carbon/human/patient, kind, obj/limb/limb)
	var/obj/item/tool
	for(var/obj/item/candidate as anything in medical_supplies()[kind])
		if(!QDELETED(candidate) && human_ai_medical_kind(candidate) == kind)
			tool = candidate
			break
	if(!tool || !hand_item(tool))
		return FALSE
	if(kind == HAI_MED_WELD)
		var/obj/item/tool/weldingtool/welder = tool
		prepare_to_weld()
		if(!welder.welding)
			welder.toggle()
		if(!welder.welding)
			return FALSE
	body.zone_selected = limb.name
	body.face_atom(patient)
	if(body.a_intent != INTENT_HELP)
		body.a_intent_change(INTENT_HELP)
	acting_until = world.time + ((patient == body) ? HAI_REPAIR_SELF_TIME : HAI_REPAIR_TIME)
	med_cache_time = 0
	utility_ref = WEAKREF(tool)
	INVOKE_ASYNC(tool, TYPE_PROC_REF(/obj/item, attack), patient, body)
	repairs++
	treatments++
	log_decision("repairing [limb.name] of [patient] with [tool]")
	if(patient != body)
		GLOB.human_ai_patient_claims[REF(patient)] = list(src, world.time + HAI_PATIENT_CLAIM_TIME)
	return TRUE

/// A welder that is lit is too hot and too bulky to put away
/datum/human_ai_brain/proc/power_down_welder(obj/item/thing)
	var/obj/item/tool/weldingtool/welder = thing
	if(istype(welder) && welder.welding)
		welder.toggle()

/// Synthetics go in with the tools to mend themselves, whatever they already carry is kept
/datum/human_ai_brain/proc/issue_repair_tools()
	if(!issynth(body))
		return
	var/list/supplies = medical_supplies()
	if(!length(supplies[HAI_MED_WELD]))
		pack_tool(new /obj/item/tool/weldingtool(get_turf(body)))
	if(!length(supplies[HAI_MED_CABLE]))
		pack_tool(new /obj/item/stack/cable_coil(get_turf(body)))
	med_cache = null
