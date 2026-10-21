/// Counts how often it was picked, can be told to throw
/datum/human_ai_action/test_probe
	var/weight = 1
	var/hits = 0
	var/explode = FALSE

/datum/human_ai_action/test_probe/get_weight(datum/human_ai_brain/brain)
	return weight

/datum/human_ai_action/test_probe/trigger(datum/human_ai_brain/brain)
	hits++
	if(explode)
		throw "probe explosion"
	return TRUE

/// Attach, detach, caps, cleanup, error containment and action picking for the human AI brain
/datum/unit_test/human_ai_lifecycle
	var/saved_max_total
	var/saved_max_full

/datum/unit_test/human_ai_lifecycle/proc/make_human()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human, pick(block(run_loc_floor_bottom_left, run_loc_floor_top_right)))
	return human

/datum/unit_test/human_ai_lifecycle/proc/make_probe(id, weight, conflicts = NONE)
	var/datum/human_ai_action/test_probe/probe = new
	probe.id = id
	probe.weight = weight
	probe.conflicts = conflicts
	return probe

/datum/unit_test/human_ai_lifecycle/Destroy()
	if(!isnull(saved_max_total))
		SShuman_ai.max_total = saved_max_total
	if(!isnull(saved_max_full))
		SShuman_ai.max_full = saved_max_full
	return ..()

/datum/unit_test/human_ai_lifecycle/Run()
	saved_max_total = SShuman_ai.max_total
	saved_max_full = SShuman_ai.max_full

	var/mob/living/carbon/human/first = make_human()
	TEST_ASSERT(attach_human_ai(first), "A plain human did not take a brain")
	var/datum/human_ai_brain/brain = first.ai_brain
	TEST_ASSERT_NOTNULL(brain, "The brain was not stored on the mob")
	TEST_ASSERT(first.is_human_ai_controlled && first.was_human_ai_spawned, "The control flags were not set")
	TEST_ASSERT(first in GLOB.ai_human_list, "The human is missing from the AI list")
	TEST_ASSERT(brain in SShuman_ai.brains, "The brain is not on the schedule")
	TEST_ASSERT_NOTNULL(brain.tier, "The brain has no tier")
	TEST_ASSERT_EQUAL(brain.personality.id, "neutral", "The default personality is not neutral")
	TEST_ASSERT(!attach_human_ai(first), "A second brain was attached")

	var/mob/living/carbon/human/zombie = make_human()
	zombie.set_species(SPECIES_ZOMBIE)
	TEST_ASSERT(!attach_human_ai(zombie), "A zombie took a human brain")

	SShuman_ai.max_total = length(SShuman_ai.brains)
	var/mob/living/carbon/human/over_cap = make_human()
	TEST_ASSERT(!attach_human_ai(over_cap), "The population cap did not hold")
	// 0 is no limit, and that is how the game starts
	SShuman_ai.max_total = 0
	TEST_ASSERT(SShuman_ai.has_room(), "No limit still said there was no room")
	TEST_ASSERT(attach_human_ai(over_cap), "No limit still refused a brain")
	detach_human_ai(over_cap)
	TEST_ASSERT_EQUAL(HAI_MAX_TOTAL, 0, "The default is a limit on how many brains exist")
	SShuman_ai.max_total = saved_max_total

	TEST_ASSERT(detach_human_ai(first), "Detach reported failure")
	TEST_ASSERT(isnull(first.ai_brain) && !first.is_human_ai_controlled, "Detach left the control state behind")
	TEST_ASSERT(!(first in GLOB.ai_human_list), "Detach left the human in the AI list")
	TEST_ASSERT(QDELETED(brain), "Detach did not delete the brain")
	TEST_ASSERT(!(brain in SShuman_ai.brains), "Detach left the brain scheduled")
	TEST_ASSERT(!detach_human_ai(first), "Detaching twice reported success")

	var/mob/living/carbon/human/dying = make_human()
	attach_human_ai(dying)
	var/datum/human_ai_brain/dying_brain = dying.ai_brain
	dying.death(create_cause_data("unit test"))
	TEST_ASSERT(isnull(dying.ai_brain) && QDELETED(dying_brain), "Death left the brain running")
	TEST_ASSERT(!(dying in GLOB.ai_human_list), "Death left the human in the AI list")
	TEST_ASSERT(!attach_human_ai(dying), "A dead human took a brain")

	var/mob/living/carbon/human/turning = make_human()
	attach_human_ai(turning)
	turning.set_species(SPECIES_ZOMBIE)
	TEST_ASSERT(attach_zombie_ai(turning), "The zombie controller did not take over")
	TEST_ASSERT(isnull(turning.ai_brain) && turning.zombie_ai_controller, "The human brain stayed behind when the zombie controller attached")
	TEST_ASSERT(!(turning in GLOB.ai_human_list), "The turned human stayed in the AI list")
	detach_zombie_ai(turning)

	var/mob/living/carbon/human/deleted = make_human()
	attach_human_ai(deleted)
	var/datum/human_ai_brain/deleted_brain = deleted.ai_brain
	allocated -= deleted
	qdel(deleted)
	TEST_ASSERT(QDELETED(deleted_brain), "Deleting the mob left the brain alive")
	TEST_ASSERT(!(null in GLOB.ai_human_list), "A deleted mob left a null in the AI list")

	SShuman_ai.max_full = 2
	var/list/crowd = list()
	for(var/index in 1 to 4)
		var/mob/living/carbon/human/member = make_human()
		attach_human_ai(member)
		member.ai_brain.keep_awake = TRUE
		crowd += member
	var/dormant = 0
	for(var/mob/living/carbon/human/member as anything in crowd)
		if(member.ai_brain.tier == HAI_TIER_DORMANT)
			dormant++
	TEST_ASSERT_EQUAL(dormant, 2, "The full fidelity cap did not push the extra brains to dormant")
	TEST_ASSERT_EQUAL(SShuman_ai.full_count, 2, "The full fidelity count drifted")
	for(var/mob/living/carbon/human/member as anything in crowd)
		detach_human_ai(member)
	TEST_ASSERT_EQUAL(SShuman_ai.full_count, 0, "Detaching the crowd left the full fidelity count above zero")
	SShuman_ai.max_full = saved_max_full

	var/mob/living/carbon/human/clumsy = make_human()
	attach_human_ai(clumsy)
	var/datum/human_ai_brain/clumsy_brain = clumsy.ai_brain
	var/datum/human_ai_action/test_probe/bomb = make_probe("bomb", 5)
	bomb.explode = TRUE
	clumsy_brain.action_pool = list(bomb)
	clumsy_brain.keep_awake = TRUE
	clumsy_brain.suppress_error_log = TRUE
	var/disabled_before = SShuman_ai.disabled_count
	for(var/attempt in 1 to HAI_MAX_ERRORS - 1)
		clumsy_brain.run_think()
	TEST_ASSERT(clumsy.ai_brain == clumsy_brain, "The brain was switched off too early")
	TEST_ASSERT_EQUAL(clumsy_brain.error_total, HAI_MAX_ERRORS - 1, "Errors were not counted")
	clumsy_brain.run_think()
	TEST_ASSERT(isnull(clumsy.ai_brain), "A brain that kept throwing stayed attached")
	TEST_ASSERT_EQUAL(SShuman_ai.disabled_count, disabled_before + 1, "The disabled count did not move")
	TEST_ASSERT(!QDELETED(clumsy), "Switching the brain off took the body with it")

	var/mob/living/carbon/human/picker = make_human()
	attach_human_ai(picker)
	var/datum/human_ai_brain/picker_brain = picker.ai_brain
	picker_brain.keep_awake = TRUE
	var/datum/human_ai_action/test_probe/aim = make_probe("aim", 5, HAI_LIMB_HANDS)
	var/datum/human_ai_action/test_probe/clash = make_probe("clash", 3, HAI_LIMB_HANDS)
	var/datum/human_ai_action/test_probe/walk = make_probe("walk", 1, HAI_LIMB_LEGS)
	var/datum/human_ai_action/test_probe/idle = make_probe("idle", 0)
	picker_brain.action_pool = list(clash, idle, walk, aim)
	picker_brain.run_think()
	TEST_ASSERT(aim.hits == 1 && walk.hits == 1, "The best action and the one with free limbs did not both run")
	TEST_ASSERT(clash.hits == 0, "An action sharing hands with a better one ran")
	TEST_ASSERT(idle.hits == 0, "A zero weight action ran")

	var/datum/human_ai_personality/eager = new
	eager.id = "eager"
	eager.action_mults = list("clash" = 10, "aim" = 0)
	picker_brain.personality = eager
	picker_brain.run_think()
	TEST_ASSERT(clash.hits == 1 && aim.hits == 1, "The personality multiplier did not reorder or silence the actions")

	picker_brain.stress = 0
	SShuman_ai.set_tier(picker_brain, HAI_TIER_DORMANT)
	var/hits_before = clash.hits + aim.hits + walk.hits
	picker_brain.keep_awake = FALSE
	picker_brain.run_think()
	TEST_ASSERT_EQUAL(clash.hits + aim.hits + walk.hits, hits_before, "A dormant brain acted")

	var/mob/living/carbon/human/scheduled = make_human()
	attach_human_ai(scheduled)
	var/datum/human_ai_brain/scheduled_brain = scheduled.ai_brain
	var/datum/human_ai_action/test_probe/ticker = make_probe("ticker", 1)
	scheduled_brain.action_pool = list(ticker)
	scheduled_brain.keep_awake = TRUE
	sleep(4 SECONDS)
	TEST_ASSERT(ticker.hits >= 2, "The subsystem did not drive the brain, got [ticker.hits] thinks")
	TEST_ASSERT(ticker.hits <= 6, "The idle tier thought too often, got [ticker.hits] thinks")

	for(var/datum/human_ai_brain/stray as anything in SShuman_ai.brains)
		TEST_ASSERT_NOTNULL(stray.body, "A scheduled brain has no body")
