/**
 * Units that have nothing to fight stand about and look round, they do not spin on the spot. Four soldiers of a squad are watched for half a minute at ease,
 * with the sound of shooting from a room they cannot get into, standing guard and sent on a patrol to places they cannot reach, and how often each turns
 * without having moved is counted along with what the unit was doing when it did: a man walking turns as he goes round things, that is not it.
 */
/datum/unit_test/human_ai_turning
	var/list/turns = list()
	var/list/states = list()
	var/list/last_place = list()

/datum/unit_test/human_ai_turning/proc/on_turn(mob/living/carbon/human/source, olddir, newdir)
	SIGNAL_HANDLER
	if(olddir == newdir || !source.ai_brain)
		return
	var/turf/here = get_turf(source)
	var/stayed = last_place[source] == here
	last_place[source] = here
	if(!stayed)
		return
	turns[source] = (turns[source] || 0) + 1
	var/datum/human_ai_brain/brain = source.ai_brain
	var/key = "[brain.intent]/[brain.current_order?.id || "-"]/[brain.investigate_turf ? "looking" : "-"]/[brain.move_state]"
	states[key] = (states[key] || 0) + 1

/// Watches the squad for the seconds and says how many times each of them turned per minute, the most of any one of them
/datum/unit_test/human_ai_turning/proc/watch(list/soldiers, seconds)
	turns = list()
	states = list()
	last_place = list()
	var/start_time = world.time
	sleep(seconds SECONDS)
	var/worst = 0
	for(var/mob/living/carbon/human/soldier as anything in soldiers)
		worst = max(worst, (turns[soldier] || 0))
	return worst * 60 / max(1, (world.time - start_time) / 10)

/datum/unit_test/human_ai_turning/proc/describe_states()
	var/list/lines = list()
	for(var/key in states)
		lines += "[key] x[states[key]]"
	return lines.Join("; ")

/datum/unit_test/human_ai_turning/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/wall = ""
	var/open_row = "#"
	var/closed_row = "#"
	for(var/column in 1 to 40)
		wall += "#"
	for(var/column in 1 to 34)
		open_row += "."
		closed_row += "."
	open_row += "#...#"
	closed_row += "#####"
	var/list/rows = list(wall)
	for(var/row in 1 to 10)
		// A room nobody can get into at the far end
		rows += (row >= 3 && row <= 5) ? open_row : closed_row
	rows += wall
	var/datum/human_ai_arena/field = new(rows, run_loc_floor_bottom_left)
	var/list/soldiers = list()
	for(var/index in 0 to 3)
		var/mob/living/carbon/human/soldier = make_soldier(locate(field.origin_x + 5 + index, field.origin_y + 6 + index % 2, field.z), FACTION_CLF, TRUE, "reckless")
		RegisterSignal(soldier, COMSIG_ATOM_DIR_CHANGE, PROC_REF(on_turn))
		soldiers += soldier
	var/datum/human_ai_squad/squad = create_human_ai_squad(soldiers, soldiers[1], "Idlers")
	TEST_ASSERT_NOTNULL(squad, "No squad was made")
	var/list/report = list()
	var/list/too_busy = list()

	// At ease
	sleep(4 SECONDS)
	var/at_ease = watch(soldiers, 40)
	report += "at ease [round(at_ease, 0.1)] turns a minute at worst ([describe_states()])"
	if(at_ease > 10)
		too_busy += "at ease"

	// Shooting from a room they cannot get into
	var/mob/living/carbon/xenomorph/drone/shooter = make_target_dummy(locate(field.origin_x + 37, field.origin_y + 7, field.z))
	for(var/round_count in 1 to 8)
		human_ai_noise(get_turf(shooter), 90, 40, shooter, "sound/weapons/gunshot.ogg")
		sleep(5 SECONDS)
	var/noisy = watch(soldiers, 30)
	report += "after shots they could not trace [round(noisy, 0.1)] turns a minute at worst ([describe_states()])"
	if(noisy > 14)
		too_busy += "after shots"

	// Standing guard
	for(var/mob/living/carbon/human/soldier as anything in soldiers)
		soldier.ai_brain.cancel_order("test")
		soldier.ai_brain.end_investigation()
		soldier.ai_brain.give_order(new /datum/npc_order/guard)
	sleep(3 SECONDS)
	var/guarding = watch(soldiers, 40)
	report += "on guard [round(guarding, 0.1)] turns a minute at worst ([describe_states()])"
	if(guarding > 12)
		too_busy += "on guard"

	// A patrol to places that cannot be reached
	var/list/sealed = list(locate(field.origin_x + 36, field.origin_y + 8, field.z), locate(field.origin_x + 37, field.origin_y + 7, field.z), locate(field.origin_x + 38, field.origin_y + 6, field.z))
	var/list/routes = list()
	for(var/mob/living/carbon/human/soldier as anything in soldiers)
		var/datum/npc_order/patrol/route = new
		route.waypoints = sealed.Copy()
		soldier.ai_brain.give_order(route)
		routes += route
	var/patrolling = watch(soldiers, 40)
	report += "on a patrol to nowhere [round(patrolling, 0.1)] turns a minute at worst ([describe_states()])"
	var/still_going = 0
	for(var/datum/npc_order/patrol/route as anything in routes)
		if(route.status == HAI_ORDER_ACTIVE)
			still_going++
	if(patrolling > 10 || still_going)
		too_busy += "on a patrol to nowhere ([still_going] still at it)"

	for(var/mob/living/carbon/human/soldier as anything in soldiers)
		UnregisterSignal(soldier, COMSIG_ATOM_DIR_CHANGE)
	TEST_ASSERT(!length(too_busy), "Units spin on the spot [too_busy.Join(", ")]: [report.Join(" | ")]")
	TEST_NOTICE(src, report.Join(" | "))
	squad.disband()
	for(var/mob/living/carbon/human/soldier as anything in soldiers)
		TEST_ASSERT_EQUAL(soldier.ai_brain.error_total, 0, "A brain threw errors")
		detach_human_ai(soldier)
