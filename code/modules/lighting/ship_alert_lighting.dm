/**
 * Minimal base type — exists only to share indestructibility flags with subtypes.
 * Alert visuals on the Almayer are handled by fire alarms (sec_changed proc).
 */

/obj/structure/machinery/light/almayer/alert
	needs_power = FALSE
	indestructible_by_overload = TRUE

/obj/structure/machinery/light/almayer/alert/ex_act(severity)
	return

/obj/structure/machinery/light/almayer/alert/power_change()
	return

// ─── Hangar / industrial amber warning light ───────────────────────────────
//
// Placed in hangars and maintenance spaces. Pulses amber on BLUE or RED alert.
// Completely indestructible so it cannot be disabled during an emergency.

/obj/structure/machinery/light/almayer/alert/hangar
	name = "warning light"
	desc = "An industrial amber warning light for hangars and maintenance spaces."

	var/alert_mode = null
	/// Emission range when active
	var/emit_range = 8
	/// Emission power when active
	var/emit_power = 1.3

/obj/structure/machinery/light/almayer/alert/hangar/Initialize(mapload)
	. = ..()
	seton(FALSE)
	RegisterSignal(SSdcs, COMSIG_GLOB_SECURITY_LEVEL_CHANGED, PROC_REF(on_security_level_changed))

/obj/structure/machinery/light/almayer/alert/hangar/Destroy(force)
	UnregisterSignal(SSdcs, COMSIG_GLOB_SECURITY_LEVEL_CHANGED)
	return ..()

// Block all destruction paths so the light can never be disabled in combat.
/obj/structure/machinery/light/almayer/alert/hangar/attackby(obj/item/W, mob/user)
	return

/obj/structure/machinery/light/almayer/alert/hangar/bullet_act(obj/projectile/P)
	return COMPONENT_CANCEL_BULLET_ACT

/obj/structure/machinery/light/almayer/alert/hangar/attack_alien(mob/living/carbon/xenomorph/M)
	return XENO_NO_DELAY_ACTION

/obj/structure/machinery/light/almayer/alert/hangar/fire_act(temperature, volume)
	return

/obj/structure/machinery/light/almayer/alert/hangar/proc/on_security_level_changed(datum/source, new_level)
	SIGNAL_HANDLER
	alert_mode = null
	seton(FALSE)
	set_light(0)
	if(new_level == SEC_LEVEL_BLUE || new_level == SEC_LEVEL_RED)
		alert_mode = "active"
		color = "#ff7700"
		update_icon()
		start_pulse(10, 15)
	else
		color = null
		update_icon()

/obj/structure/machinery/light/almayer/alert/hangar/proc/start_pulse(on_ticks, off_ticks)
	var/my_mode = alert_mode
	spawn(0)
		while(alert_mode == my_mode && !QDELETED(src))
			seton(TRUE)
			set_light(emit_range, emit_power, "#ff7700")
			sleep(on_ticks)
			if(alert_mode != my_mode || QDELETED(src))
				break
			seton(FALSE)
			set_light(0)
			sleep(off_ticks)
		if(!QDELETED(src) && alert_mode != my_mode)
			seton(FALSE)
			set_light(0)
