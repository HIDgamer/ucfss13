/// The AI tests grouped into the batches they are run in, one focus file per batch on the box keeps a run inside its time limit
GLOBAL_LIST_INIT(human_ai_regression_batches, list(
	"core" = list(
		/datum/unit_test/human_ai_basics,
		/datum/unit_test/human_ai_lifecycle,
		/datum/unit_test/human_ai_load,
		/datum/unit_test/human_ai_sight_load,
		/datum/unit_test/human_ai_movement,
		/datum/unit_test/human_ai_following,
		/datum/unit_test/human_ai_perception,
		/datum/unit_test/human_ai_soak,
		/datum/unit_test/native_pathfind_profiles,
	),
	"weapons" = list(
		/datum/unit_test/human_ai_gun_appraisal,
		/datum/unit_test/human_ai_weapon_handling,
		/datum/unit_test/human_ai_gun_sweep,
		/datum/unit_test/human_ai_gun_duels,
		/datum/unit_test/human_ai_sidearm,
		/datum/unit_test/human_ai_fire_discipline,
		/datum/unit_test/human_ai_grenades,
		/datum/unit_test/human_ai_melee,
		/datum/unit_test/human_ai_dispositions,
		/datum/unit_test/human_ai_friendly_fire,
		/datum/unit_test/human_ai_friendly_tolerance,
	),
	"tactics" = list(
		/datum/unit_test/human_ai_cover_geometry,
		/datum/unit_test/human_ai_cover_value,
		/datum/unit_test/human_ai_cover_choice,
		/datum/unit_test/human_ai_cover_improvised,
		/datum/unit_test/human_ai_orders_movement,
		/datum/unit_test/human_ai_orders_combat,
		/datum/unit_test/human_ai_orders_rules,
		/datum/unit_test/human_ai_squad_basics,
		/datum/unit_test/human_ai_squad_callouts,
		/datum/unit_test/human_ai_squad_flank,
		/datum/unit_test/human_ai_squad_fallback,
		/datum/unit_test/human_ai_squad_soak,
		/datum/unit_test/human_ai_table_climbing,
		/datum/unit_test/human_ai_table_wall,
		/datum/unit_test/human_ai_keep_distance,
		/datum/unit_test/human_ai_defensive_post,
		/datum/unit_test/human_ai_window_sight,
		/datum/unit_test/human_ai_rescue,
		/datum/unit_test/human_ai_real_loadouts,
		/datum/unit_test/human_ai_real_medics,
		/datum/unit_test/human_ai_ladders,
		/datum/unit_test/human_ai_hold_area,
		/datum/unit_test/human_ai_callouts,
		/datum/unit_test/human_ai_synthetics,
		/datum/unit_test/human_ai_forced_entry,
		/datum/unit_test/human_ai_hammer,
		/datum/unit_test/human_ai_classes,
		/datum/unit_test/human_ai_prisoner_escort,
		/datum/unit_test/human_ai_backup_call,
	),
	"personality" = list(
		/datum/unit_test/human_ai_presets,
		/datum/unit_test/human_ai_mood,
		/datum/unit_test/human_ai_ladder,
		/datum/unit_test/human_ai_compliance_matrix,
		/datum/unit_test/human_ai_preset_matrix,
		/datum/unit_test/human_ai_voice_banks,
		/datum/unit_test/human_ai_expression_rules,
		/datum/unit_test/human_ai_reactions,
		/datum/unit_test/human_ai_idle_life,
		/datum/unit_test/human_ai_chatter_audit,
	),
	"roles" = list(
		/datum/unit_test/human_ai_medic,
		/datum/unit_test/human_ai_specialists,
		/datum/unit_test/human_ai_security_force,
		/datum/unit_test/human_ai_breach,
		/datum/unit_test/human_ai_engineer,
		/datum/unit_test/human_ai_door_shock,
		/datum/unit_test/human_ai_door_trap,
		/datum/unit_test/human_ai_civilians,
		/datum/unit_test/human_ai_injection_safety,
		/datum/unit_test/human_ai_defibrillation,
		/datum/unit_test/human_ai_joe_kit,
		/datum/unit_test/human_ai_joe_maintenance,
		/datum/unit_test/human_ai_joe_apc,
		/datum/unit_test/human_ai_joe_patience,
		/datum/unit_test/human_ai_captives,
		/datum/unit_test/human_ai_camouflage,
		/datum/unit_test/human_ai_looting,
		/datum/unit_test/human_ai_door_hacking,
		/datum/unit_test/human_ai_door_hacking_tools,
		/datum/unit_test/human_ai_shutters,
		/datum/unit_test/human_ai_revival,
	),
	"command" = list(
		/datum/unit_test/human_ai_command_selection,
		/datum/unit_test/human_ai_command_orders,
		/datum/unit_test/human_ai_command_requests,
		/datum/unit_test/human_ai_command_panel,
		/datum/unit_test/human_ai_command_scale,
		/datum/unit_test/human_ai_command_scope,
		/datum/unit_test/human_ai_assign_tool,
		/datum/unit_test/human_ai_voice_commands,
	),
	"population" = list(
		/datum/unit_test/human_ai_population_profiles,
		/datum/unit_test/human_ai_population_director,
		/datum/unit_test/human_ai_population_map,
		/datum/unit_test/human_ai_population_hooks,
	),
	"tuning" = list(
		/datum/unit_test/human_ai_scaling,
		/datum/unit_test/human_ai_arbiter,
		/datum/unit_test/human_ai_soak_full,
		/datum/unit_test/human_ai_regression_coverage,
	),
))

/// The acceptance scenarios of the roadmap and the test that proves each one
GLOBAL_LIST_INIT(human_ai_acceptance, list(
	"bait and flank" = /datum/unit_test/human_ai_squad_flank,
	"reload under cover" = /datum/unit_test/human_ai_weapon_handling,
	"breach and clear" = /datum/unit_test/human_ai_breach,
	"door ambush" = /datum/unit_test/human_ai_door_trap,
	"break and surrender" = /datum/unit_test/human_ai_mood,
	"panel order compliance" = /datum/unit_test/human_ai_command_requests,
	"map population seeding" = /datum/unit_test/human_ai_population_map,
	"60 AI soak" = /datum/unit_test/human_ai_soak_full,
))

/// Every AI test sits in exactly one batch and every acceptance scenario has its test, so a new test cannot be left out of the suite
/datum/unit_test/human_ai_regression_coverage

/datum/unit_test/human_ai_regression_coverage/Run()
	var/list/placed = list()
	for(var/batch in GLOB.human_ai_regression_batches)
		for(var/test_type in GLOB.human_ai_regression_batches[batch])
			TEST_ASSERT(ispath(test_type, /datum/unit_test), "The batch [batch] lists [test_type], which is not a test")
			TEST_ASSERT(!placed[test_type], "[test_type] is in two batches")
			placed[test_type] = batch
	for(var/test_type in subtypesof(/datum/unit_test))
		var/text = "[test_type]"
		if(!findtext(text, "/datum/unit_test/human_ai_") && text != "/datum/unit_test/native_pathfind_profiles")
			continue
		TEST_ASSERT(placed[test_type], "[test_type] is in no regression batch")
	for(var/scenario in GLOB.human_ai_acceptance)
		TEST_ASSERT(placed[GLOB.human_ai_acceptance[scenario]], "The acceptance scenario [scenario] has no test in a batch")

/// The difficulty follows the marine players, only while it is switched on, and a hand-set value ends that
/datum/unit_test/human_ai_scaling
	var/saved_aim
	var/saved_reaction
	var/saved_bias
	var/saved_auto
	var/saved_players

/datum/unit_test/human_ai_scaling/Destroy()
	SShuman_ai.aim_error_mult = saved_aim
	SShuman_ai.reaction_mult = saved_reaction
	SShuman_ai.aggression_bias = saved_bias
	SShuman_ai.auto_scale = saved_auto
	SShuman_ai.scale_players = saved_players
	return ..()

/datum/unit_test/human_ai_scaling/Run()
	saved_aim = SShuman_ai.aim_error_mult
	saved_reaction = SShuman_ai.reaction_mult
	saved_bias = SShuman_ai.aggression_bias
	saved_auto = SShuman_ai.auto_scale
	saved_players = SShuman_ai.scale_players
	var/previous_aim = INFINITY
	var/previous_reaction = INFINITY
	var/previous_bias = -INFINITY
	var/previous_count = -1
	for(var/list/row as anything in GLOB.human_ai_difficulty_table)
		TEST_ASSERT(row[1] > previous_count, "The player counts of the difficulty table do not rise")
		TEST_ASSERT(row[2] <= previous_aim && row[3] <= previous_reaction, "More players made the AI worse at aiming or slower")
		TEST_ASSERT(row[4] >= previous_bias, "More players made the AI less aggressive")
		previous_count = row[1]
		previous_aim = row[2]
		previous_reaction = row[3]
		previous_bias = row[4]

	var/mob/living/carbon/human/soldier = allocate(/mob/living/carbon/human)
	soldier.faction = FACTION_MARINE
	TEST_ASSERT(attach_human_ai(soldier, "reckless"), "The test soldier took no brain")
	var/base_aggression = soldier.ai_brain.personality.trait("aggression")
	SShuman_ai.scale_players = -1
	TEST_ASSERT(SShuman_ai.apply_scaling(0), "The first scaling changed nothing")
	TEST_ASSERT_EQUAL(SShuman_ai.aim_error_mult, 1.6, "A near empty server did not make the AI clumsy")
	TEST_ASSERT(soldier.ai_brain.personality.trait("aggression") < base_aggression, "A near empty server did not calm the AI down")
	TEST_ASSERT(!SShuman_ai.apply_scaling(3), "The same row was applied twice")
	TEST_ASSERT(SShuman_ai.apply_scaling(100), "A full server did not change the row")
	TEST_ASSERT_EQUAL(SShuman_ai.aim_error_mult, 0.7, "A full server did not sharpen the AI")
	TEST_ASSERT(soldier.ai_brain.personality.trait("aggression") > base_aggression, "A full server did not make the AI bolder")

	var/mob/living/carbon/human/admin = allocate(/mob/living/carbon/human)
	var/datum/npc_command_console/console = new(admin)
	console.access_override = TRUE
	console.handle_action(admin, "set_difficulty", list("auto_scale" = TRUE))
	TEST_ASSERT(SShuman_ai.auto_scale, "The panel could not switch scaling on")
	console.handle_action(admin, "set_difficulty", list("aim_error" = 2))
	TEST_ASSERT(!SShuman_ai.auto_scale, "Setting a value by hand did not end the scaling")
	qdel(console)

/// The budget arbiter holds the idle brains back when all the AI together costs too much, and lets them go again slowly
/datum/unit_test/human_ai_arbiter
	var/saved_multiplier
	var/saved_load

/datum/unit_test/human_ai_arbiter/Destroy()
	SShuman_ai.arbiter_multiplier = saved_multiplier
	SShuman_ai.arbiter_load = saved_load
	return ..()

/datum/unit_test/human_ai_arbiter/Run()
	saved_multiplier = SShuman_ai.arbiter_multiplier
	saved_load = SShuman_ai.arbiter_load
	SShuman_ai.arbiter_multiplier = 1
	TEST_ASSERT_EQUAL(SShuman_ai.apply_budget(50, 20), 1, "A light load slowed the brains")
	var/slowed = SShuman_ai.apply_budget(150, 150)
	TEST_ASSERT(slowed > 1.4 && slowed < 1.6, "A load of one and a half gave a slowdown of [slowed]")
	TEST_ASSERT_EQUAL(SShuman_ai.apply_budget(900, 900), HAI_ARBITER_MAX_SLOWDOWN, "An overload was not capped")
	var/eased = SShuman_ai.apply_budget(10, 10)
	TEST_ASSERT_EQUAL(eased, HAI_ARBITER_MAX_SLOWDOWN - 0.25, "The slowdown did not ease off slowly")
	TEST_ASSERT_EQUAL(SShuman_ai.interval_for(HAI_TIER_ENGAGED), HAI_TIER_ENGAGED * SShuman_ai.interval_multiplier, "A brain in a fight was slowed")
	TEST_ASSERT_EQUAL(SShuman_ai.interval_for(HAI_TIER_IDLE), HAI_TIER_IDLE * SShuman_ai.interval_multiplier * eased, "An idle brain was not slowed")
	for(var/pass in 1 to 20)
		SShuman_ai.apply_budget(0, 0)
	TEST_ASSERT_EQUAL(SShuman_ai.arbiter_multiplier, 1, "The slowdown never went away")
	SShuman_ai.arbitrate()
	TEST_ASSERT(SShuman_ai.arbiter_load >= 0, "The arbiter measured a negative load")

/// Sixty AI humans in two firefighting lines at full fidelity for a minute, the cost of their thinking and of the server around them is recorded
/datum/unit_test/human_ai_soak_full
	var/budget_ms_per_second = 120
	var/seconds = 60

/datum/unit_test/human_ai_soak_full/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, the soak needs it")
	var/list/rows = list("############################################################")
	for(var/row in 1 to 22)
		rows += "#..........................................................#"
	rows += "############################################################"
	var/datum/human_ai_arena/field = new(rows, run_loc_floor_bottom_left)
	for(var/offset in 4 to 19)
		var/obj/structure/barricade/metal/cover = new(locate(field.origin_x + 29, field.origin_y + offset, field.z))
		cover.setDir(EAST)
		var/obj/structure/barricade/metal/answer = new(locate(field.origin_x + 31, field.origin_y + offset, field.z))
		answer.setDir(WEST)

	var/list/crowd = list()
	var/list/teams = list()
	for(var/side in 1 to 2)
		var/faction = (side == 1) ? FACTION_MARINE : FACTION_CLF
		var/x_start = (side == 1) ? 2 : 54
		for(var/squad_index in 1 to 6)
			var/list/squad_members = list()
			for(var/member_index in 1 to 5)
				var/turf/where = locate(field.origin_x + x_start + (member_index % 3), field.origin_y + 1 + squad_index * 3 + (member_index > 3 ? 1 : 0), field.z)
				var/mob/living/carbon/human/soldier = make_soldier(where, faction, TRUE, pick("professional", "veteran", "reckless", "cautious", "neutral"))
				soldier.ai_brain.set_role(member_index == 1 ? "leader" : pick("rifleman", "rifleman", "machinegunner"))
				squad_members += soldier
				crowd += soldier
			var/datum/human_ai_squad/squad = create_human_ai_squad(squad_members, squad_members[1], "[faction] [squad_index]")
			teams += squad
	TEST_ASSERT_EQUAL(length(crowd), 60, "The crowd is the wrong size")
	TEST_ASSERT_EQUAL(SShuman_ai.full_count, 60, "Not every brain got full fidelity")

	for(var/datum/human_ai_squad/squad as anything in teams)
		var/datum/npc_order/move/advance = new
		advance.target_turf = locate(field.origin_x + 30, field.origin_y + 11, field.z)
		advance.danger = 0
		squad.issue_order(advance)

	SShuman_ai.reset_cost_meter()
	var/list/cpu_samples = list()
	var/list/tick_samples = list()
	for(var/second in 1 to seconds)
		sleep(1 SECONDS)
		cpu_samples += world.cpu
		tick_samples += world.tick_usage
	var/cost_per_second = (SShuman_ai.total_cost_ms - SShuman_ai.gun_cost_ms) / seconds
	var/gun_per_second = SShuman_ai.gun_cost_ms / seconds
	var/cpu_total = 0
	var/cpu_peak = 0
	for(var/sample in cpu_samples)
		cpu_total += sample
		cpu_peak = max(cpu_peak, sample)
	var/tick_peak = 0
	for(var/sample in tick_samples)
		tick_peak = max(tick_peak, sample)
	var/shots = 0
	var/dead = 0
	for(var/mob/living/carbon/human/soldier as anything in crowd)
		shots += soldier.ai_brain?.shots_fired || 0
		if(soldier.stat == DEAD)
			dead++
	TEST_NOTICE(src, "[SShuman_ai.total_thinks] thinks in [seconds] s: [round(cost_per_second, 0.1)] ms/s of AI work and [round(gun_per_second, 0.1)] ms/s of stock gun code, world cpu average [round(cpu_total / length(cpu_samples), 0.1)] peak [round(cpu_peak, 0.1)], tick usage peak [round(tick_peak, 0.1)], [shots] shots, [dead] dead, budget slowdown [round(SShuman_ai.arbiter_multiplier, 0.01)]")
	TEST_ASSERT(shots >= 60, "The two lines barely fought, only [shots] shots")
	TEST_ASSERT(cost_per_second <= budget_ms_per_second, "Sixty fighting brains cost [round(cost_per_second, 0.1)] ms/s outside the gun code, over the [budget_ms_per_second] ms/s budget")
	TEST_ASSERT_EQUAL(SShuman_ai.disabled_count, 0, "A brain was switched off for errors")
	for(var/mob/living/carbon/human/soldier as anything in crowd)
		TEST_ASSERT_EQUAL(soldier.ai_brain?.error_total || 0, 0, "A fighting brain threw errors")
