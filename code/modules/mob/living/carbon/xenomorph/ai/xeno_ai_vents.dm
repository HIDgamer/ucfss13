/**
 * Vent-crawl ambush support for xeno_ai_controller. Reuses the existing
 * pipe network (/obj/structure/pipes/vents, relaymove()'s connected_to
 * graph) rather than building a parallel travel system, but bypasses the
 * two player-facing entry points (handle_ventcrawl()/start_ventcrawl() in
 * ventcrawl.dm) entirely - both are built around an interactive
 * tgui_input_list vent picker and a do_after windup whose completion check
 * includes `!client`, a disconnect guard that makes no sense for a mob
 * that was never connected to begin with and would silently cancel every
 * AI attempt. relaymove() itself (the actual movement between connected
 * pipe segments once inside, and the exit path) only needed one small
 * patch elsewhere (pipes.dm) - `user.client.eye = next_pipe` would
 * null-reference for a clientless caller, guarded the same way every
 * other client-touching line in that file already is.
 *
 * Deliberately does not path toward a specific destination through the
 * pipe network - that's a real graph-search problem distinct from the
 * tile-based A* this AI already does elsewhere, and is a reasonable
 * follow-up. Instead this is "duck into the vents and pop out somewhere
 * else nearby": a bounded random walk of the connected_to graph, then
 * exit. Still delivers the actual ask (xenos disappearing into vents and
 * resurfacing to surprise someone) without the added risk of a rushed
 * pathing algorithm through shared player-facing pipe code.
 */
/datum/xeno_ai_controller/proc/attempt_vent_ambush()
	if(!pilot || !pilot.can_ventcrawl() || pilot.is_ventcrawling)
		return FALSE

	var/obj/structure/pipes/vents/entry_vent = locate(/obj/structure/pipes/vents) in range(1, pilot)
	if(!entry_vent || entry_vent.welded || !length(entry_vent.connected_to))
		return FALSE

	var/obj/effect/alien/weeds/entry_weeds = locate(/obj/effect/alien/weeds) in entry_vent.loc
	if(entry_weeds && entry_weeds.linked_hive.hivenumber != pilot.hivenumber)
		return FALSE // Enemy hive's weeds block the entrance, same rule a player would hit.

	pilot.visible_message(SPAN_DANGER("[pilot] scrambles into [entry_vent]!"))
	playsound(pilot, pick('sound/effects/alien_ventpass1.ogg', 'sound/effects/alien_ventpass2.ogg'), 35, TRUE)
	pilot.forceMove(entry_vent)
	pilot.update_pipe_icons(entry_vent)

	INVOKE_ASYNC(src, PROC_REF(vent_travel))
	return TRUE

/**
 * Bounded random walk through the connected pipe graph, then exits - see
 * attempt_vent_ambush()'s doc comment for why this isn't targeted routing.
 * Runs as its own coroutine (started via INVOKE_ASYNC, same pattern as
 * ai_loop() itself) since relaymove()'s exit branch does a real do_after
 * wait - this must not block the main ai_loop() coroutine, which is kept
 * from running a conflicting tick() concurrently by tick()'s own
 * is_ventcrawling check instead.
 */
/datum/xeno_ai_controller/proc/vent_travel()
	for(var/i in 1 to rand(AI_VENT_MIN_HOPS, AI_VENT_MAX_HOPS))
		if(!pilot || QDELETED(pilot) || !pilot.is_ventcrawling)
			return // Detached, died, or already forced out some other way.

		var/obj/structure/pipes/current_pipe = pilot.loc
		if(!istype(current_pipe))
			return

		var/list/usable_dirs = list()
		for(var/dir_option in current_pipe.valid_directions)
			if(current_pipe.get_connection(dir_option))
				usable_dirs += dir_option

		if(!length(usable_dirs))
			break // Dead end - exit from here instead of continuing the walk.

		current_pipe.relaymove(pilot, pick(usable_dirs))
		sleep(3)

	if(!pilot || QDELETED(pilot) || !pilot.is_ventcrawling)
		return

	var/obj/structure/pipes/final_pipe = pilot.loc
	if(!istype(final_pipe))
		return

	// relaymove() with a direction that has no further connection is
	// exactly the branch that triggers the real exit windup/message/
	// forceMove in relaymove() itself - reused as-is rather than
	// duplicating it here.
	for(var/dir_option in final_pipe.valid_directions)
		if(!final_pipe.get_connection(dir_option))
			final_pipe.relaymove(pilot, dir_option)
			return

	// Every direction from here still connects somewhere (a fully-connected
	// junction) - take one more hop instead of getting stuck inside forever.
	final_pipe.relaymove(pilot, pick(final_pipe.valid_directions))
