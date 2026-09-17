SUBSYSTEM_DEF(projectiles)
	name = "Projectiles"
	wait = 1
	init_order = SS_INIT_PROJECTILES
	flags = SS_TICKER
	priority = SS_PRIORITY_PROJECTILES

	/// List of projectiles handled by the subsystem
	VAR_PRIVATE/list/obj/projectile/projectiles
	/// Associative set (projectile = TRUE) of projectiles on hold due to sleeping - kept
	/// associative so building `flying` each tick is an O(1)-lookup skip per projectile
	/// instead of a full list-subtract every cycle.
	VAR_PRIVATE/list/obj/projectile/sleepers
	/// List of projectiles handled this controller firing
	VAR_PRIVATE/list/obj/projectile/flying
	/// Real-world time of last fire cycle start, used to compensate for server lag
	VAR_PRIVATE/last_fire_real_time = 0
	/// Delta time calculated at the start of each fire cycle, shared with resumed continuations
	VAR_PRIVATE/current_delta_time = 0
	/// Real elapsed time that couldn't be credited to movement this cycle because a single
	/// tick's movement is capped (to stop projectiles tunnelling through obstacles during
	/// extreme lag) - carried forward and paid out on later, less-laggy ticks instead of being
	/// permanently discarded, so a lag spike delays projectiles rather than costing them
	/// distance outright. Capped at the same per-tick ceiling so a sustained outage can't
	/// build up an unbounded catch-up debt.
	VAR_PRIVATE/banked_delta_time = 0

	/*
	 * Scheduling notes:
	 *  We have three different types of projectile collisions:
	 *
	 *   1. Travel hit: moving the bullet resulted in a scan collision.
	 *   This can be resolved immediately, on Subsystem time.
	 *   2. Passive hit: something else triggered Collide/Crossed()
	 *   -- This is scheduled on caller time for simplicity. --
	 *   It includes impacts as a direct result of firing the gun.
	 *   3. Chain hit: Collide/Crossed() is triggered on SS time.
	 *   This can happen eg. if a rocket knocks someone on a bullet.
	 *
	 * Aside from performance, this can matter for order of operations.
	 */

/datum/controller/subsystem/projectiles/stat_entry(msg)
	msg = " | #Proj: [length(projectiles)]"
	return ..()

/datum/controller/subsystem/projectiles/Initialize(start_timeofday)
	projectiles = list()
	flying = list()
	sleepers = list()
	return SS_INIT_SUCCESS

/datum/controller/subsystem/projectiles/fire(resumed = FALSE)
	if(!resumed)
		var/real_now = REALTIMEOFDAY
		var/normal_delta = wait * world.tick_lag * (1 SECONDS)
		var/real_delta = last_fire_real_time ? (real_now - last_fire_real_time) * (1 SECONDS) : normal_delta
		if(real_delta < 0) // REALTIMEOFDAY midnight rollover guard
			real_delta = normal_delta
			banked_delta_time = 0 // stale bank from before the rollover, discard it
		last_fire_real_time = real_now
		real_delta = max(real_delta, normal_delta) // never credit less than one nominal tick's worth

		// Cap at 4x normal tick to prevent bullet teleportation during extreme lag or pauses.
		// Anything beyond that cap is banked (not discarded) and paid out on subsequent ticks
		// once the lag eases, so a spike delays projectiles rather than permanently costing
		// them distance - previously the excess was thrown away every single tick, which is
		// why projectiles used to visibly fall behind ("freeze") during laggy stretches and
		// never catch back up.
		var/max_tick_delta = normal_delta * 4
		var/available_delta_time = banked_delta_time + real_delta
		current_delta_time = min(available_delta_time, max_tick_delta)
		banked_delta_time = min(available_delta_time - current_delta_time, max_tick_delta)

		flying = list()
		for(var/obj/projectile/candidate as anything in projectiles)
			if(!sleepers[candidate])
				flying += candidate
	while(length(flying))
		var/obj/projectile/projectile = flying[length(flying)]
		flying.len--
		handle_projectile_flight(projectile, current_delta_time)
		if(MC_TICK_CHECK)
			return

/datum/controller/subsystem/projectiles/proc/handle_projectile_flight(obj/projectile/projectile, delta_time)
	PRIVATE_PROC(TRUE)
	set waitfor = FALSE
	// We're in double-check land here because there ARE rulebreakers.
	if(QDELETED(projectile))
		log_debug("SSprojectiles: projectile '[projectile.name]' shot by '[projectile.firer]' is scheduled despite being deleted.")
	else if(projectile.speed > 0)
		. = process_wrapper(projectile, delta_time)
	else
		log_debug("SSprojectiles: projectile '[projectile.name]' shot by '[projectile.firer]' discarded due to invalid speed.")
	if(. == PROC_RETURN_SLEEP)
		log_debug("SSprojectiles: projectile '[projectile.name]' shot by '[projectile.firer]' at ([projectile.x],[projectile.y],[projectile.z]) found sleeping despite all the sleep prevention! Putting on hold.")
		sleepers[projectile] = TRUE
	else if(.)
		stop_projectile(projectile) // Ideally this was already done thru process()
		qdel(projectile)

/datum/controller/subsystem/projectiles/proc/process_wrapper(obj/projectile/projectile, delta_time)
	// set waitfor=TRUE
	. = PROC_RETURN_SLEEP
	. = projectile.process(delta_time)
	sleepers -= projectile // Recover from sleep

/datum/controller/subsystem/projectiles/proc/queue_projectile(obj/projectile/projectile)
	projectiles |= projectile
/datum/controller/subsystem/projectiles/proc/stop_projectile(obj/projectile/projectile)
	projectiles -= projectile
	flying -= projectile // avoids problems with deleted projs
	projectile.speed = 0
