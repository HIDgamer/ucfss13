// __xeno_pathfind.dm - DM bindings for the xeno_pathfind native extension
// (tools/rust/xeno_pathfind/). Not a fork of rust-g - a separate library
// using the same call_ext()-compatible C ABI convention (see __rust_g.dm for
// the reference pattern this mirrors). See
// code/modules/mob/living/carbon/xenomorph/ai/xeno_ai_movement.dm for the
// BYOND-side grid-building and fallback-to-step_towards() logic that calls
// into this - the AI must work correctly even if this library is entirely
// absent from a given host.

#ifndef XENO_PATHFIND_LIB
/var/__xeno_pathfind_lib

/proc/__detect_xeno_pathfind_lib()
	if(world.system_type == UNIX)
		if(fexists("./libxeno_pathfind.so"))
			return __xeno_pathfind_lib = "./libxeno_pathfind.so"
		return __xeno_pathfind_lib = "libxeno_pathfind.so"
	else
		return __xeno_pathfind_lib = "xeno_pathfind"

#define XENO_PATHFIND_LIB (__xeno_pathfind_lib || __detect_xeno_pathfind_lib())
#endif

#if DM_VERSION >= 515
#define XENO_PATHFIND_CALL call_ext
#else
#define XENO_PATHFIND_CALL call
#endif

// Plain globals rather than GLOBAL_VAR_INIT()/GLOB - this file is included
// before code/__DEFINES/_globals.dm in colonialmarines.dme (same position as
// __rust_g.dm, which does the same thing), so that machinery isn't defined
// yet at this point in the build.

/// Set once the first call either succeeds or fails, so a missing library is only probed once instead of retried every AI tick.
/var/__xeno_pathfind_checked = FALSE
/// Whether the native library is actually present and callable on this host.
/var/__xeno_pathfind_available = FALSE

/**
 * Calls the native A* solver. grid_desc is
 * "width,height,start_x,start_y,end_x,end_y" (grid-local coordinates);
 * blocked_map is a width*height-length string of '0'/'1' characters,
 * row-major. Returns a ';'-separated list of "x,y" grid-local coordinates
 * from start to end inclusive, or an empty string if no path exists, the
 * input was malformed, or the native library isn't present on this host.
 *
 * Always safe to call - never throws. Callers must treat an empty result as
 * "fall back to the existing step_towards()-based movement", since that's
 * also the answer for a genuinely missing library, not just "no path."
 */
/proc/rustg_xeno_pathfind(grid_desc, blocked_map)
	if(__xeno_pathfind_checked && !__xeno_pathfind_available)
		return ""
	. = ""
	try
		. = XENO_PATHFIND_CALL(XENO_PATHFIND_LIB, "xeno_pathfind")(grid_desc, blocked_map)
		__xeno_pathfind_available = TRUE
	catch
		__xeno_pathfind_available = FALSE
	__xeno_pathfind_checked = TRUE
