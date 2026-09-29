/*Procedures in this file: robotic heart and brain repair.*/

///Possessives for messages, as seen by the surgeon and by bystanders
#define SURGEON_POV(user, target) (user == target ? "your own" : "[target]'s")
#define BYSTANDER_POV(user, target) (user == target ? "their own" : "[target]'s")

///Damages the limb and organ, sparks and leaks fluid after a botched robotic organ repair step
/datum/surgery_step/proc/synth_repair_mishap(mob/living/carbon/human/target, target_zone, organ_name, organ_damage, brute = 0, burn = 0)
	if(brute)
		target.apply_damage(brute, BRUTE, target_zone)
	if(burn)
		target.apply_damage(burn, BURN, target_zone)
	var/datum/internal_organ/organ = target.internal_organs_by_name[organ_name]
	if(organ && organ_damage)
		organ.take_damage(organ_damage, TRUE)
	target.add_splatter_floor(get_turf(target), TRUE)
	self_surgery_sparks(target)

/datum/surgery/cortex_recalibration
	name = "Synthetic Cortex Recalibration"
	priority = SURGERY_PRIORITY_HIGH
	possible_locs = list("head")
	invasiveness = list(SURGERY_DEPTH_DEEP)
	required_surgery_skill = SKILL_SURGERY_TRAINED
	pain_reduction_required = PAIN_REDUCTION_MEDIUM
	self_operable_expert = TRUE
	steps = list(
		/datum/surgery_step/cortex_access,
		/datum/surgery_step/cortex_rewire,
		/datum/surgery_step/cortex_trim,
		/datum/surgery_step/cortex_recalibrate,
	)

/datum/surgery/cortex_recalibration/can_start(mob/user, mob/living/carbon/human/patient, obj/limb/L, obj/item/tool)
	var/datum/internal_organ/brain/B = patient.internal_organs_by_name["brain"]
	return B && B.robotic == ORGAN_ROBOT && B.damage > 0

/datum/surgery_step/cortex_access
	name = "Expose Cortex"
	desc = "dig into the cortex housing"
	tools = SURGERY_TOOLS_PINCH
	time = 6 SECONDS
	preop_sound = 'sound/surgery/hemostat1.ogg'
	success_sound = 'sound/surgery/organ1.ogg'
	failure_sound = 'sound/surgery/organ2.ogg'

/datum/surgery_step/cortex_access/preop(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool, tool_type, datum/surgery/surgery)
	user.affected_message(target,
		SPAN_NOTICE("You begin digging into the cortex housing in [SURGEON_POV(user, target)] head with \the [tool], parting the shielding around the neural bundle."),
		SPAN_NOTICE("[user] begins digging into the cortex housing in your head with \the [tool]."),
		SPAN_NOTICE("[user] begins digging into the cortex housing in [BYSTANDER_POV(user, target)] head with \the [tool]."))

	log_interact(user, target, "[key_name(user)] began digging into [key_name(target)]'s cortex housing with \the [tool], possibly beginning [surgery].")

/datum/surgery_step/cortex_access/success(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool, tool_type, datum/surgery/surgery)
	user.affected_message(target,
		SPAN_NOTICE("You expose the scorched wiring around [SURGEON_POV(user, target)] cortex."),
		SPAN_NOTICE("[user] exposes the scorched wiring around your cortex."),
		SPAN_NOTICE("[user] exposes the scorched wiring around [BYSTANDER_POV(user, target)] cortex."))

	log_interact(user, target, "[key_name(user)] exposed the wiring around [key_name(target)]'s cortex with \the [tool], starting [surgery].")

/datum/surgery_step/cortex_access/failure(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool, tool_type, datum/surgery/surgery)
	user.affected_message(target,
		SPAN_WARNING("Your hand slips, dragging \the [tool] across the cortex bus and throwing a shower of sparks!"),
		SPAN_WARNING("[user]'s hand slips, dragging \the [tool] across your cortex bus and throwing a shower of sparks!"),
		SPAN_WARNING("[user]'s hand slips, dragging \the [tool] across [BYSTANDER_POV(user, target)] cortex bus and throwing a shower of sparks!"))

	synth_repair_mishap(target, target_zone, "brain", rand(4, 8), burn = rand(6, 10))
	log_interact(user, target, "[key_name(user)] slipped while digging into [key_name(target)]'s cortex housing with \the [tool].")
	return FALSE

/datum/surgery_step/cortex_rewire
	name = "Splice New Wiring"
	desc = "splice in new wiring"
	tools = list(/obj/item/stack/cable_coil = SURGERY_TOOL_MULT_IDEAL)
	time = 7 SECONDS
	preop_sound = 'sound/items/Deconstruct.ogg'
	success_sound = 'sound/machines/click.ogg'
	failure_sound = 'sound/items/Welder2.ogg'

/datum/surgery_step/cortex_rewire/extra_checks(mob/living/user, mob/living/carbon/target, target_zone, obj/item/tool, datum/surgery/surgery, repeating, skipped)
	var/obj/item/stack/cable_coil/coil = tool
	if(coil.amount < CORTEX_REWIRE_CABLE_COST)
		to_chat(user, SPAN_BOLDWARNING("You need at least [CORTEX_REWIRE_CABLE_COST] lengths of cable to rewire [SURGEON_POV(user, target)] cortex."))
		return FALSE
	return TRUE

/datum/surgery_step/cortex_rewire/preop(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool, tool_type, datum/surgery/surgery)
	user.affected_message(target,
		SPAN_NOTICE("You begin splicing fresh wiring through [SURGEON_POV(user, target)] cortex housing with \the [tool]."),
		SPAN_NOTICE("[user] begins splicing fresh wiring through your cortex housing with \the [tool]."),
		SPAN_NOTICE("[user] begins splicing fresh wiring through [BYSTANDER_POV(user, target)] cortex housing with \the [tool]."))

	log_interact(user, target, "[key_name(user)] began rewiring [key_name(target)]'s cortex with \the [tool].")

/datum/surgery_step/cortex_rewire/success(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool, tool_type, datum/surgery/surgery)
	var/obj/item/stack/cable_coil/coil = tool
	coil.use(CORTEX_REWIRE_CABLE_COST)

	user.affected_message(target,
		SPAN_NOTICE("You finish splicing new wiring through [SURGEON_POV(user, target)] cortex housing, replacing the burnt-out runs."),
		SPAN_NOTICE("[user] finishes splicing new wiring through your cortex housing."),
		SPAN_NOTICE("[user] finishes splicing new wiring through [BYSTANDER_POV(user, target)] cortex housing."))

	log_interact(user, target, "[key_name(user)] rewired [key_name(target)]'s cortex with \the [tool].")

/datum/surgery_step/cortex_rewire/failure(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool, tool_type, datum/surgery/surgery)
	user.affected_message(target,
		SPAN_WARNING("The new splice arcs against the cortex core!"),
		SPAN_WARNING("The new splice arcs against your cortex core!"),
		SPAN_WARNING("The new splice arcs against [BYSTANDER_POV(user, target)] cortex core!"))

	var/obj/item/stack/cable_coil/coil = tool
	coil.use(min(coil.amount, 2))
	synth_repair_mishap(target, target_zone, "brain", rand(3, 5), burn = rand(5, 8))
	log_interact(user, target, "[key_name(user)] shorted a splice in [key_name(target)]'s cortex with \the [tool].")
	return FALSE

/datum/surgery_step/cortex_trim
	name = "Trim And Crimp Splices"
	desc = "trim and crimp the new wiring"
	tools = list(/obj/item/tool/wirecutters = SURGERY_TOOL_MULT_IDEAL)
	time = 5 SECONDS
	preop_sound = 'sound/items/Wirecutter.ogg'
	success_sound = 'sound/machines/click.ogg'
	failure_sound = 'sound/items/Welder2.ogg'

/datum/surgery_step/cortex_trim/preop(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool, tool_type, datum/surgery/surgery)
	user.affected_message(target,
		SPAN_NOTICE("You begin trimming and crimping the new splices in [SURGEON_POV(user, target)] cortex with \the [tool]."),
		SPAN_NOTICE("[user] begins trimming and crimping the new splices in your cortex with \the [tool]."),
		SPAN_NOTICE("[user] begins trimming and crimping the new splices in [BYSTANDER_POV(user, target)] cortex with \the [tool]."))

	log_interact(user, target, "[key_name(user)] began trimming the new splices in [key_name(target)]'s cortex with \the [tool].")

/datum/surgery_step/cortex_trim/success(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool, tool_type, datum/surgery/surgery)
	user.affected_message(target,
		SPAN_NOTICE("You trim and crimp the new splices in [SURGEON_POV(user, target)] cortex until they sit flush."),
		SPAN_NOTICE("[user] trims and crimps the new splices in your cortex until they sit flush."),
		SPAN_NOTICE("[user] trims and crimps the new splices in [BYSTANDER_POV(user, target)] cortex until they sit flush."))

	log_interact(user, target, "[key_name(user)] trimmed the new splices in [key_name(target)]'s cortex with \the [tool].")

/datum/surgery_step/cortex_trim/failure(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool, tool_type, datum/surgery/surgery)
	user.affected_message(target,
		SPAN_WARNING("You snip the wrong lead with \the [tool] and the cortex flickers violently!"),
		SPAN_WARNING("[user] snips the wrong lead with \the [tool] and your cortex flickers violently!"),
		SPAN_WARNING("[user] snips the wrong lead with \the [tool] and [BYSTANDER_POV(user, target)] cortex flickers violently!"))

	synth_repair_mishap(target, target_zone, "brain", rand(6, 10), burn = 6)
	log_interact(user, target, "[key_name(user)] cut the wrong lead in [key_name(target)]'s cortex with \the [tool].")
	return FALSE

/datum/surgery_step/cortex_recalibrate
	name = "Recalibrate Cortex"
	desc = "recalibrate the cortex core"
	tools = list(/obj/item/device/multitool = SURGERY_TOOL_MULT_IDEAL)
	time = 8 SECONDS
	preop_sound = 'sound/machines/click.ogg'
	success_sound = 'sound/machines/chime.ogg'
	failure_sound = 'sound/machines/buzz-two.ogg'

/datum/surgery_step/cortex_recalibrate/preop(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool, tool_type, datum/surgery/surgery)
	user.affected_message(target,
		SPAN_NOTICE("You clip \the [tool] to the diagnostic port on [SURGEON_POV(user, target)] cortex core and begin recalibrating it."),
		SPAN_NOTICE("[user] clips \the [tool] to the diagnostic port on your cortex core and begins recalibrating it."),
		SPAN_NOTICE("[user] clips \the [tool] to the diagnostic port on [BYSTANDER_POV(user, target)] cortex core and begins recalibrating it."))

	log_interact(user, target, "[key_name(user)] began recalibrating [key_name(target)]'s cortex with \the [tool].")

/datum/surgery_step/cortex_recalibrate/success(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool, tool_type, datum/surgery/surgery)
	user.affected_message(target,
		SPAN_NOTICE("The cortex core chimes as it settles back within tolerances."),
		SPAN_NOTICE("Your cortex core chimes as it settles back within tolerances."),
		SPAN_NOTICE("[BYSTANDER_POV(user, target)] cortex core chimes as it settles back within tolerances."))

	user.count_niche_stat(STATISTICS_NICHE_SURGERY_BRAIN)

	var/datum/internal_organ/brain/B = target.internal_organs_by_name["brain"]
	if(B)
		B.rejuvenate()
	target.disabilities &= ~NERVOUS
	target.sdisabilities &= ~DISABILITY_DEAF
	target.sdisabilities &= ~DISABILITY_MUTE
	target.jitteriness = 0
	target.setBrainLoss(0)

	log_interact(user, target, "[key_name(user)] recalibrated [key_name(target)]'s cortex with \the [tool], ending [surgery].")

/datum/surgery_step/cortex_recalibrate/failure(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool, tool_type, datum/surgery/surgery)
	user.affected_message(target,
		SPAN_WARNING("The core desyncs and feedback whips through the cortex!"),
		SPAN_WARNING("Your core desyncs and feedback whips through your cortex!"),
		SPAN_WARNING("[BYSTANDER_POV(user, target)] core desyncs and feedback whips through the cortex!"))

	synth_repair_mishap(target, target_zone, "brain", rand(8, 12), burn = 6)
	log_interact(user, target, "[key_name(user)] desynced [key_name(target)]'s cortex with \the [tool].")
	return FALSE

/datum/surgery/pump_overhaul
	name = "Fluid Pump Overhaul"
	priority = SURGERY_PRIORITY_HIGH
	possible_locs = list("chest")
	invasiveness = list(SURGERY_DEPTH_DEEP)
	required_surgery_skill = SKILL_SURGERY_TRAINED
	pain_reduction_required = PAIN_REDUCTION_HEAVY
	self_operable_expert = TRUE
	steps = list(
		/datum/surgery_step/pump_clamp,
		/datum/surgery_step/pump_weld,
		/datum/surgery_step/pump_remount,
		/datum/surgery_step/pump_flush,
	)

/datum/surgery/pump_overhaul/can_start(mob/user, mob/living/carbon/human/patient, obj/limb/L, obj/item/tool)
	var/datum/internal_organ/heart/H = patient.internal_organs_by_name["heart"]
	return H && H.robotic == ORGAN_ROBOT && H.damage > 0

/datum/surgery_step/pump_clamp
	name = "Clamp Coolant Lines"
	desc = "clamp off the coolant lines"
	tools = SURGERY_TOOLS_PINCH
	time = 5 SECONDS
	preop_sound = 'sound/surgery/hemostat1.ogg'
	success_sound = 'sound/surgery/hemostat1.ogg'
	failure_sound = 'sound/surgery/organ2.ogg'

/datum/surgery_step/pump_clamp/preop(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool, tool_type, datum/surgery/surgery)
	user.affected_message(target,
		SPAN_NOTICE("You begin clamping off the coolant lines feeding [SURGEON_POV(user, target)] fluid pump with \the [tool]."),
		SPAN_NOTICE("[user] begins clamping off the coolant lines feeding your fluid pump with \the [tool]."),
		SPAN_NOTICE("[user] begins clamping off the coolant lines feeding [BYSTANDER_POV(user, target)] fluid pump with \the [tool]."))

	target.custom_pain("Something is being pinched shut deep inside your chest!", 1)
	log_interact(user, target, "[key_name(user)] began clamping the coolant lines to [key_name(target)]'s fluid pump with \the [tool], possibly beginning [surgery].")

/datum/surgery_step/pump_clamp/success(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool, tool_type, datum/surgery/surgery)
	user.affected_message(target,
		SPAN_NOTICE("You clamp off the coolant lines, and the cracked pump housing stops weeping fluid."),
		SPAN_NOTICE("[user] clamps off the coolant lines, and your cracked pump housing stops weeping fluid."),
		SPAN_NOTICE("[user] clamps off the coolant lines, and the cracked pump housing stops weeping fluid."))

	log_interact(user, target, "[key_name(user)] clamped the coolant lines to [key_name(target)]'s fluid pump with \the [tool], starting [surgery].")

/datum/surgery_step/pump_clamp/failure(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool, tool_type, datum/surgery/surgery)
	user.affected_message(target,
		SPAN_WARNING("Your hand slips and a coolant line sprays fluid across the cavity!"),
		SPAN_WARNING("[user]'s hand slips and a coolant line sprays fluid across your chest cavity!"),
		SPAN_WARNING("[user]'s hand slips and a coolant line sprays fluid across the chest cavity!"))

	synth_repair_mishap(target, target_zone, "heart", 4, burn = 5)
	log_interact(user, target, "[key_name(user)] slipped while clamping the coolant lines to [key_name(target)]'s fluid pump with \the [tool].")
	return FALSE

/datum/surgery_step/pump_weld
	name = "Reseal Pump Housing"
	desc = "reseal the pump housing"
	tools = list(/obj/item/tool/weldingtool = SURGERY_TOOL_MULT_IDEAL)
	time = 7 SECONDS
	preop_sound = 'sound/items/weldingtool_weld.ogg'
	success_sound = 'sound/items/Welder2.ogg'
	failure_sound = 'sound/items/Welder.ogg'

/datum/surgery_step/pump_weld/extra_checks(mob/living/user, mob/living/carbon/target, target_zone, obj/item/tool, datum/surgery/surgery, repeating, skipped)
	var/obj/item/tool/weldingtool/welder = tool
	if(!welder.isOn())
		to_chat(user, SPAN_BOLDWARNING("You need to switch \the [welder] on first!"))
		return FALSE
	if(!welder.remove_fuel(PUMP_WELD_FUEL_COST, user))
		return FALSE
	return TRUE

/datum/surgery_step/pump_weld/preop(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool, tool_type, datum/surgery/surgery)
	user.affected_message(target,
		SPAN_NOTICE("You begin welding the cracked pump housing in [SURGEON_POV(user, target)] chest shut with \the [tool]."),
		SPAN_NOTICE("[user] begins welding the cracked pump housing in your chest shut with \the [tool]."),
		SPAN_NOTICE("[user] begins welding the cracked pump housing in [BYSTANDER_POV(user, target)] chest shut with \the [tool]."))

	target.custom_pain("Something white-hot is being pressed against your insides!", 1)
	log_interact(user, target, "[key_name(user)] began welding [key_name(target)]'s fluid pump housing with \the [tool].")

/datum/surgery_step/pump_weld/success(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool, tool_type, datum/surgery/surgery)
	user.affected_message(target,
		SPAN_NOTICE("You weld the cracked pump housing shut along its seam."),
		SPAN_NOTICE("[user] welds the cracked pump housing in your chest shut along its seam."),
		SPAN_NOTICE("[user] welds the cracked pump housing shut along its seam."))

	log_interact(user, target, "[key_name(user)] welded [key_name(target)]'s fluid pump housing with \the [tool].")

/datum/surgery_step/pump_weld/failure(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool, tool_type, datum/surgery/surgery)
	user.affected_message(target,
		SPAN_WARNING("The torch flares against the pump housing and scorches everything around it!"),
		SPAN_WARNING("The torch flares against your pump housing and scorches everything around it!"),
		SPAN_WARNING("The torch flares against the pump housing and scorches everything around it!"))

	synth_repair_mishap(target, target_zone, "heart", 5, burn = 8)
	log_interact(user, target, "[key_name(user)] scorched [key_name(target)]'s fluid pump housing with \the [tool].")
	return FALSE

/datum/surgery_step/pump_remount
	name = "Re-seat Pump Mounts"
	desc = "re-seat and torque down the pump mounts"
	tools = list(/obj/item/tool/wrench = SURGERY_TOOL_MULT_IDEAL)
	time = 6 SECONDS
	preop_sound = 'sound/items/Ratchet.ogg'
	success_sound = 'sound/machines/click.ogg'
	failure_sound = 'sound/effects/bone_break4.ogg'

/datum/surgery_step/pump_remount/preop(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool, tool_type, datum/surgery/surgery)
	user.affected_message(target,
		SPAN_NOTICE("You begin re-seating the mounts of [SURGEON_POV(user, target)] fluid pump with \the [tool]."),
		SPAN_NOTICE("[user] begins re-seating the mounts of your fluid pump with \the [tool]."),
		SPAN_NOTICE("[user] begins re-seating the mounts of [BYSTANDER_POV(user, target)] fluid pump with \the [tool]."))

	target.custom_pain("Something in your chest is being wrenched back into place!", 1)
	log_interact(user, target, "[key_name(user)] began re-seating the mounts of [key_name(target)]'s fluid pump with \the [tool].")

/datum/surgery_step/pump_remount/success(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool, tool_type, datum/surgery/surgery)
	user.affected_message(target,
		SPAN_NOTICE("You torque the pump mounts down until the whole assembly sits true."),
		SPAN_NOTICE("[user] torques the pump mounts in your chest down until the whole assembly sits true."),
		SPAN_NOTICE("[user] torques the pump mounts down until the whole assembly sits true."))

	log_interact(user, target, "[key_name(user)] re-seated the mounts of [key_name(target)]'s fluid pump with \the [tool].")

/datum/surgery_step/pump_remount/failure(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool, tool_type, datum/surgery/surgery)
	user.affected_message(target,
		SPAN_WARNING("Your hand slips and \the [tool] strips a mounting bolt, wrenching the whole pump sideways!"),
		SPAN_WARNING("[user]'s hand slips and \the [tool] strips a mounting bolt, wrenching your whole pump sideways!"),
		SPAN_WARNING("[user]'s hand slips and \the [tool] strips a mounting bolt, wrenching the whole pump sideways!"))

	synth_repair_mishap(target, target_zone, "heart", 5, brute = 6)
	log_interact(user, target, "[key_name(user)] stripped a mounting bolt on [key_name(target)]'s fluid pump with \the [tool].")
	return FALSE

/datum/surgery_step/pump_flush
	name = "Flush Pump"
	desc = "flush the pump with repair nanites"
	tools = list(/obj/item/stack/nanopaste = SURGERY_TOOL_MULT_IDEAL)
	time = 6 SECONDS
	preop_sound = 'sound/handling/bandage.ogg'
	success_sound = 'sound/machines/chime.ogg'
	failure_sound = 'sound/surgery/organ2.ogg'

/datum/surgery_step/pump_flush/extra_checks(mob/living/user, mob/living/carbon/target, target_zone, obj/item/tool, datum/surgery/surgery, repeating, skipped)
	var/obj/item/stack/nanopaste/paste = tool
	if(paste.amount < PUMP_FLUSH_PASTE_COST)
		to_chat(user, SPAN_BOLDWARNING("You need at least [PUMP_FLUSH_PASTE_COST] doses of nanopaste to flush [SURGEON_POV(user, target)] fluid pump."))
		return FALSE
	return TRUE

/datum/surgery_step/pump_flush/preop(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool, tool_type, datum/surgery/surgery)
	user.affected_message(target,
		SPAN_NOTICE("You begin flushing [SURGEON_POV(user, target)] fluid pump with nanites from \the [tool], sealing its micro-fractures."),
		SPAN_NOTICE("[user] begins flushing your fluid pump with nanites from \the [tool]."),
		SPAN_NOTICE("[user] begins flushing [BYSTANDER_POV(user, target)] fluid pump with nanites from \the [tool]."))

	log_interact(user, target, "[key_name(user)] began flushing [key_name(target)]'s fluid pump with \the [tool].")

/datum/surgery_step/pump_flush/success(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool, tool_type, datum/surgery/surgery)
	var/obj/item/stack/nanopaste/paste = tool
	paste.use(PUMP_FLUSH_PASTE_COST)

	user.affected_message(target,
		SPAN_NOTICE("The nanites finish sealing the pump's micro-fractures, and it spools up smoothly."),
		SPAN_NOTICE("The nanites finish sealing your pump's micro-fractures, and it spools up smoothly."),
		SPAN_NOTICE("The nanites finish sealing the pump's micro-fractures, and it spools up smoothly."))

	user.count_niche_stat(STATISTICS_NICHE_SURGERY_ORGAN_REPAIR)

	var/datum/internal_organ/heart/H = target.internal_organs_by_name["heart"]
	if(H)
		H.rejuvenate()

	log_interact(user, target, "[key_name(user)] flushed [key_name(target)]'s fluid pump with \the [tool], ending [surgery].")

/datum/surgery_step/pump_flush/failure(mob/user, mob/living/carbon/human/target, target_zone, obj/item/tool, tool_type, datum/surgery/surgery)
	user.affected_message(target,
		SPAN_WARNING("The nanite slurry pools in the wrong place and starts eating into the pump's casing!"),
		SPAN_WARNING("The nanite slurry pools in the wrong place and starts eating into your pump's casing!"),
		SPAN_WARNING("The nanite slurry pools in the wrong place and starts eating into the pump's casing!"))

	synth_repair_mishap(target, target_zone, "heart", 3, burn = 4)
	log_interact(user, target, "[key_name(user)] pooled nanites in the wrong place in [key_name(target)]'s fluid pump with \the [tool].")
	return FALSE

#undef SURGEON_POV
#undef BYSTANDER_POV
