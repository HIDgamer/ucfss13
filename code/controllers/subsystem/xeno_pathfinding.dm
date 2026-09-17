/**
 * Owns the native pathfinder's persistent full-map walkability grid
 * (tools/rust/xeno_pathfind - see code/__DEFINES/__xeno_pathfind.dm for the
 * FFI wrappers). Bulk-loads every z-level's turf walkability once at round
 * start, then keeps the native grid in sync through a batched delta pipeline
 * fed by the two places tile passability actually changes at runtime:
 * ChangeTurf() (walls built/destroyed, resin placed/melted - the single
 * canonical funnel for all turf type changes, hooked at its tail) and door
 * density flips (door.dm's finish_open()/close()/Destroy()).
 *
 * Everything degrades gracefully: if the native library is missing or too
 * old for the persistent entry points, `available` stays FALSE and the AI
 * keeps using the bounded local-grid solver exactly as before.
 */
SUBSYSTEM_DEF(xeno_pathfinding)
	name = "Xeno Pathfinding"
	wait = 5 SECONDS
	init_order = SS_INIT_XENO_PATHFINDING
	priority = SS_PRIORITY_XENO_PATHFINDING

	/// TRUE once every z-level loaded into the native grid successfully - the AI only routes globally while this holds.
	var/available = FALSE
	/// Pending "z,x,y,c" delta strings, flushed to the native side each fire() or the moment the batch grows past XENO_PATHFIND_DELTA_FLUSH_AT.
	var/list/pending_deltas = list()
	/// fire() counter driving the periodic threat decay (see Rust-side xeno_pathfind_decay()).
	var/decay_counter = 0

/datum/controller/subsystem/xeno_pathfinding/Initialize()
	// The DLL outlives world reboots (the Dream Daemon process doesn't
	// restart between rounds) - wipe last round's grid/threat before
	// rebuilding for this one.
	rust_xeno_pathfind_clear()

	var/loaded_count = 0
	for(var/z in 1 to world.maxz)
		if(load_z_level(z))
			loaded_count++
		else
			log_debug("SSxeno_pathfinding: failed to load z-level [z] into the native grid.")
	// Partial availability is fine - a route on an unloaded z just returns
	// "" and that mob falls back to the bounded local solver; demanding every
	// z-level meant one oddball level silently disabled routing everywhere.
	available = loaded_count > 0 && __xeno_pathfind_persistent_available
	if(!available)
		log_debug("SSxeno_pathfinding: native grid unavailable ([loaded_count]/[world.maxz] z-levels loaded, persistent_available=[__xeno_pathfind_persistent_available]) - AI falls back to bounded local pathfinding.")

	// Threat layer: every xeno death marks its tile (radius-2 falloff,
	// native side) as costly to route through, decaying via fire() below -
	// approach routes bend around marine kill zones, so flanking emerges
	// from the cost function with no per-caste code at all.
	RegisterSignal(SSdcs, COMSIG_GLOB_XENO_DEATH, PROC_REF(on_xeno_death))
	return SS_INIT_SUCCESS

/datum/controller/subsystem/xeno_pathfinding/proc/on_xeno_death(datum/source, mob/living/carbon/xenomorph/dead_xeno, gibbed)
	SIGNAL_HANDLER
	if(!available)
		return
	var/turf/death_turf = get_turf(dead_xeno)
	if(!death_turf)
		return
	rust_xeno_pathfind_threat("[death_turf.z],[death_turf.x],[death_turf.y],[AI_THREAT_DEATH_AMOUNT]")

/**
 * Re-injects threat at every currently-active sentry's tile, same threat
 * layer as on_xeno_death() above and the same live-check is_valid_target()
 * already uses to decide a sentry is a real threat. Re-injects every decay
 * cycle rather than firing once, so a destroyed/turned-off turret's
 * contribution simply stops being added and decays away naturally over the
 * next couple of cycles - no explicit removal call needed.
 */
/datum/controller/subsystem/xeno_pathfinding/proc/refresh_turret_threat()
	for(var/obj/structure/machinery/defenses/sentry/turret as anything in GLOB.sentry_turret_list)
		if(turret.stat == DEFENSE_DESTROYED || !turret.turned_on)
			continue
		var/turf/turret_turf = get_turf(turret)
		if(turret_turf)
			rust_xeno_pathfind_threat("[turret_turf.z],[turret_turf.x],[turret_turf.y],[AI_THREAT_TURRET_AMOUNT]")

/// Packs one z-level's turf walkability row-major from (1,1) and bulk-loads it into the native grid. Returns whether the native side accepted it.
/datum/controller/subsystem/xeno_pathfinding/proc/load_z_level(z)
	var/list/cells = list()
	for(var/y in 1 to world.maxy)
		for(var/x in 1 to world.maxx)
			var/turf/scanned = locate(x, y, z)
			var/code = turf_cell_code(scanned)
			// Belt-and-suspenders against turf_cell_code() ever returning
			// something outside the single-character '0'-'4' set the native
			// side accepts - the Rust decoder rejects the *entire* payload on
			// the first unrecognized byte (see xeno_pathfind_init_z's own
			// validation), so one bad turf silently fails the whole z-level
			// with no indication of which turf or byte was the culprit. This
			// was live-diagnosed as exactly this failure mode (every z-level
			// on a real round returning "" with a byte-for-byte-correct
			// length) without ever pinning down the actual bad turf, because
			// nothing logged what the bad code/turf actually was - only that
			// the aggregate call failed. Logs the one-shot detail then keeps
			// going with a safe fallback code so this doesn't also block
			// every other turf's data from loading.
			if(length(code) != 1 || !(code in list("0", "1", "2", "3", "4")))
				log_debug("SSxeno_pathfinding: turf_cell_code() returned invalid code [code ? "\"[code]\"" : "null"] for turf ([x],[y],[z]) ([scanned ? "[scanned.type]" : "null turf"]) - substituting \"1\" (blocked) and continuing.")
				code = "1"
			cells += code
		CHECK_TICK
	var/result = rust_xeno_pathfind_init_z("[z],[world.maxx],[world.maxy]", cells.Join(""))
	// "Failed to load z-level N" with no further detail was already fixed
	// for the case where the native call throws (see __xeno_pathfind.dm's
	// catch blocks) - this covers the other failure shape: the call
	// completing without throwing but the native side rejecting the
	// payload for some reason (bad dimensions, cell-string length mismatch,
	// an internal panic that doesn't cross the FFI boundary as a DM
	// exception). Logs the literal return value so that's distinguishable
	// from "call never actually reached the library" at a glance.
	if(result != "ok")
		log_debug("SSxeno_pathfinding: xeno_pathfind_init_z(z=[z]) returned [result ? "\"[result]\"" : "null/empty"] instead of \"ok\" - cells=[length(cells)], expected=[world.maxx * world.maxy]")
	return result == "ok"

/**
 * The native cell code for a turf's current state: '1' dense turf (wall, or
 * a dense structure the AI can genuinely never get through - see
 * `unslashable` below), '2' walkable turf with a dense, forceable door on
 * it, '3' walkable turf with some other dense breakable structure (window,
 * girder - priced far above a door so routes only smash through glass as a
 * last resort, never as a shortcut), '4' walkable turf with a directional
 * (ON_BORDER) structure (platform, most barricades, flipped tables) -
 * priced modestly above open ground rather than skipped outright. A
 * full-tile cost still can't represent "blocks from one side, open from
 * another" exactly (the per-step obstacle handling still does the real work
 * on contact), but leaving these completely invisible to route planning -
 * as CELL_OPEN, the same as bare floor - let long routes get planned
 * straight through/across clusters of them with zero accounting for the
 * real crossing cost, which is what actually produced the "going insane
 * near platforms" reports: the router's plan and the per-step reality
 * disagreed about whether a tile was free. '0' open.
 *
 * `unslashable` structures (blast doors/shutters, and any other structure
 * flagged that way) are priced as a hard block ('1'), not their normal type
 * cost - get_blocking_obstacle() (xeno_ai_movement.dm) excludes any
 * unslashable blocker from obstacle-forcing entirely (nothing to smash,
 * nothing to climb), so the AI can never actually get through one no matter
 * what a route assumed. Pricing an unslashable door the same as a normal
 * forceable one (its old behavior) planned routes straight at permanently
 * shut security doors with a real path around through other open doors -
 * live-diagnosed as "AI stuck running back and forth against an impassible
 * shutter, ignoring a valid path a few tiles over." Checked before the door
 * type check below since an unslashable door is a door, but the AI must
 * treat it like a wall instead.
 */
/datum/controller/subsystem/xeno_pathfinding/proc/turf_cell_code(turf/scanned)
	if(!scanned || scanned.density)
		return "1"
	var/has_obstacle = FALSE
	var/has_border = FALSE
	for(var/obj/structure/blocker in scanned)
		if(!blocker.density)
			continue
		if(blocker.flags_atom & ON_BORDER)
			has_border = TRUE
			continue
		if(blocker.unslashable)
			return "1"
		if(istype(blocker, /obj/structure/machinery/door))
			return "2"
		if(blocker.climbable)
			continue // Tables/racks - vaulted over, not smashed; near-free for movement.
		has_obstacle = TRUE
	if(has_obstacle)
		return "3"
	return has_border ? "4" : "0"

/**
 * Re-reads one turf's walkability and queues the delta for the native grid.
 * Called from ChangeTurf()'s tail (every turf type change funnels through
 * it) and from door.dm's density-flip sites. Cheap enough to call
 * redundantly - a delta that doesn't actually change the cell is harmless
 * on the native side.
 *
 * turf_cell_code() can return "3" (a breakable obstacle - window/girder) or
 * "4" (an ON_BORDER structure - platform/barricade/flipped table), matching
 * the Rust side's own CELL_OBSTACLE/CELL_BORDER codes - the mapping below
 * must produce both, or a structure placed or revealed mid-round (e.g. a
 * wall demolished down to a girder, or a barricade dropped) syncs into the
 * native grid as a zero-cost open tile instead of its intended cost,
 * degrading route quality without erroring.
 */
/datum/controller/subsystem/xeno_pathfinding/proc/push_delta(turf/changed)
	if(!available || !changed)
		return
	var/code_char = turf_cell_code(changed)
	var/code = (code_char == "1") ? 1 : ((code_char == "2") ? 2 : ((code_char == "3") ? 3 : ((code_char == "4") ? 4 : 0)))
	pending_deltas += "[changed.z],[changed.x],[changed.y],[code]"
	if(length(pending_deltas) >= XENO_PATHFIND_DELTA_FLUSH_AT)
		flush_deltas()

/datum/controller/subsystem/xeno_pathfinding/proc/flush_deltas()
	if(!length(pending_deltas))
		return
	rust_xeno_pathfind_update(pending_deltas.Join(";"))
	pending_deltas = list()

/datum/controller/subsystem/xeno_pathfinding/fire(resumed = FALSE)
	if(!available)
		return
	flush_deltas()
	decay_counter++
	if(decay_counter >= XENO_PATHFIND_DECAY_EVERY_FIRES)
		decay_counter = 0
		rust_xeno_pathfind_decay()
		refresh_turret_threat()
