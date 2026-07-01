/**
 * Visual quality update for the APC status light.
 * update_glow_visuals() is called from update_icon() in apc.dm.
 * The colored glow filter has been removed per "physical lights only" policy;
 * APC status is conveyed via icon states alone.
 */

/// Called by update_icon() to keep visuals in sync with APC state.
/obj/structure/machinery/power/apc/proc/update_glow_visuals()
	remove_filter("apc_glow") // clean up any filter applied by older code
