/**
 * Wall/ceiling-mounted emergency rotating cone light.
 *
 * Placed by mappers in Almayer corridors and key rooms.
 * Normally OFF (invisible light, idle fixture sprite).
 * Activates on DELTA alert via COMSIG_GLOB_SECURITY_LEVEL_CHANGED,
 * or can be triggered manually via activate() / deactivate().
 *
 * Emits an actual MOVABLE_LIGHT using the rotating mask variant —
 * the lighting plane shows the characteristic spinning sweep effect.
 */

// ─── Emergency cone light fixture ─────────────────────────────────────────────

/obj/structure/machinery/emergency_cone_light
	name = "emergency light"
	desc = "A ceiling-mounted rotating emergency beacon. Activates during shipwide emergencies."
	icon = 'icons/obj/structures/flasher.dmi'
	icon_state = "mflash1"
	anchored = TRUE
	layer = ABOVE_OBJ_LAYER
	light_system = MOVABLE_LIGHT
	light_mask_type = /atom/movable/lighting_mask/rotating
	needs_power = FALSE
	light_range = 5
	light_power = 2.5
	light_color = "#ff2200"
	light_on = FALSE

	var/emergency_active = FALSE
	var/emergency_color = "#ff2200"
	var/emit_range = 5
	var/emit_power = 2.5

/obj/structure/machinery/emergency_cone_light/Initialize(mapload)
	. = ..()
	RegisterSignal(SSdcs, COMSIG_GLOB_SECURITY_LEVEL_CHANGED, PROC_REF(on_security_level_changed))

/obj/structure/machinery/emergency_cone_light/Destroy(force)
	UnregisterSignal(SSdcs, COMSIG_GLOB_SECURITY_LEVEL_CHANGED)
	deactivate()
	return ..()

/obj/structure/machinery/emergency_cone_light/proc/on_security_level_changed(datum/source, new_level)
	SIGNAL_HANDLER
	if(new_level == SEC_LEVEL_DELTA)
		activate()
	else
		deactivate()

/obj/structure/machinery/emergency_cone_light/proc/activate()
	if(emergency_active)
		return
	emergency_active = TRUE
	set_light(emit_range, emit_power, emergency_color)

/obj/structure/machinery/emergency_cone_light/proc/deactivate()
	if(!emergency_active)
		return
	emergency_active = FALSE
	set_light(0)

// ── Amber variant used on dropship launch pads ──────────────────────────────
// Controlled by the stationary docking port's turn_on/off_warning_beacons() procs.
// Also locks on when a hijacked dropship crashes into the ship and releases
// only when security returns to GREEN or BLUE.
//
// Icon states (floor_flood_*):
//   floor_flood_1 — on and healthy (normal active state / idle fixture)
//   floor_flood_0 — burnt but still on (after a crash damages the fixture)
//   floor_flood_2 — destroyed (heavy explosion; beacon ceases to function)

/obj/structure/machinery/emergency_cone_light/dropship
	name = "launch warning beacon"
	desc = "A rotating amber warning beacon. Active during dropship launch and landing."
	icon = 'icons/obj/structures/machinery/floodlight.dmi'
	icon_state = "floor_flood_1"
	light_color = "#ff8800"
	emergency_color = "#ff8800"
	emit_range = 9
	emit_power = 3.5
	light_range = 9
	light_power = 3.5
	unslashable = TRUE
	unacidable = TRUE

	/// TRUE while a hijack crash is ongoing — deactivate() is a no-op until security clears
	var/hijack_lock = FALSE
	/// TRUE after a heavy explosion physically wrecks the beacon
	var/beacon_destroyed = FALSE

/obj/structure/machinery/emergency_cone_light/dropship/Initialize(mapload)
	. = ..()
	UnregisterSignal(SSdcs, COMSIG_GLOB_SECURITY_LEVEL_CHANGED)
	RegisterSignal(SSdcs, COMSIG_GLOB_HIJACK_IMPACTED, PROC_REF(on_hijack_crash))
	RegisterSignal(SSdcs, COMSIG_GLOB_SECURITY_LEVEL_CHANGED, PROC_REF(on_security_level_changed_beacon))

/obj/structure/machinery/emergency_cone_light/dropship/Destroy(force)
	UnregisterSignal(SSdcs, COMSIG_GLOB_HIJACK_IMPACTED)
	return ..()

/obj/structure/machinery/emergency_cone_light/dropship/ex_act(severity)
	if(beacon_destroyed)
		return
	var/destroy_chance = 0
	if(severity < EXPLOSION_THRESHOLD_LOW)
		destroy_chance = 25
	else if(severity < EXPLOSION_THRESHOLD_MEDIUM)
		destroy_chance = 65
	else
		destroy_chance = 100
	if(!prob(destroy_chance))
		return
	beacon_destroyed = TRUE
	hijack_lock = FALSE
	emergency_active = FALSE
	icon_state = "floor_flood_2"
	set_light(0)
	UnregisterSignal(SSdcs, list(COMSIG_GLOB_HIJACK_IMPACTED, COMSIG_GLOB_SECURITY_LEVEL_CHANGED))

/// When the dropship crashes, lock beacons on and switch to the burnt-but-on visual.
/// turn_off_warning_beacons() calls from the docking port are ignored while locked.
/obj/structure/machinery/emergency_cone_light/dropship/proc/on_hijack_crash(datum/source)
	SIGNAL_HANDLER
	if(beacon_destroyed)
		return
	hijack_lock = TRUE
	icon_state = "floor_flood_0"  // fixture took damage but keeps running
	if(!emergency_active)
		emergency_active = TRUE
		set_light(emit_range, emit_power, emergency_color)

/// Release the hijack lock and turn off only when security drops back to GREEN or BLUE.
/obj/structure/machinery/emergency_cone_light/dropship/proc/on_security_level_changed_beacon(datum/source, new_level)
	SIGNAL_HANDLER
	if(new_level == SEC_LEVEL_GREEN || new_level == SEC_LEVEL_BLUE)
		hijack_lock = FALSE
		deactivate()

/obj/structure/machinery/emergency_cone_light/dropship/activate()
	if(emergency_active || beacon_destroyed)
		return
	emergency_active = TRUE
	icon_state = "floor_flood_1"
	// Steady amber light — the rotating mask (light_mask_type) provides the spinning sweep
	// visual on the lighting plane. No power-cycling loop eliminates the race condition
	// that caused orphaned rotating mask overlays after deactivation.
	set_light(emit_range, emit_power, emergency_color)

/// deactivate() is blocked while hijack_lock is set or the beacon is destroyed.
/obj/structure/machinery/emergency_cone_light/dropship/deactivate()
	if(hijack_lock || beacon_destroyed)
		return
	if(!emergency_active)
		return
	emergency_active = FALSE
	icon_state = "floor_flood_1"  // back to idle — healthy fixture, no light
	set_light(0)

/obj/structure/machinery/emergency_cone_light/dropship/alamo
	name = "Alamo launch warning beacon"

/obj/structure/machinery/emergency_cone_light/dropship/normandy
	name = "Normandy launch warning beacon"

