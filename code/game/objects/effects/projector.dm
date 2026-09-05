/obj/effect/projector
	density = FALSE
	unacidable = TRUE
	anchored = TRUE
	invisibility = 101
	layer = TURF_LAYER
	var/vector_x = 0
	var/vector_y = 0
	var/firing_id = "generic"
	var/mask_layer = null // all actual layers are divided by 10 and then subtracted from the mask layer.
	var/movables_projection_plane = -6 //necessary to change when making a movable go under a turf (whose plane is -7)
	var/modify_turf = TRUE
	var/projected_mouse_opacity = 1
	var/projected_opacity
	icon = 'icons/landmarks.dmi'
	icon_state = "projector"//for map editor
	// The facsimile create_clone() spawned via this projector (modify_turf=FALSE case only). Tracked
	// here, not just on the master turf's own `.clone` var, because a real turf-swap (ChangeTurf(),
	// e.g. a dropship physically docking/undocking at an outer port) replaces the master turf with a
	// brand-new datum whose `.clone` resets to null - silently severing the only other reference to
	// this facsimile and reopening fz_transitions.dm's re-creation guard every single cycle, while the
	// old facsimile itself (which lives on a different, projected-to turf) is never found again to be
	// torn down. A projector is an independent movable that survives that swap, so anchoring the
	// teardown here instead guarantees the facsimile dies with its projector regardless of what
	// happens to the master turf's identity in between.
	var/atom/movable/clone/spawned_clone = null

/obj/effect/projector/Initialize(mapload, ...)
	. = ..()
	return INITIALIZE_HINT_LATELOAD

/obj/effect/projector/LateInitialize()
	. = ..()
	if(SSfz_transitions.selective_update[firing_id])
		GLOB.projectors.Add(src)
	else
		GLOB.deselected_projectors.Add(src)

/obj/effect/projector/Destroy()
	if(spawned_clone)
		var/atom/master = spawned_clone.mstr
		if(master?.clone == spawned_clone)
			master.clone = null
		GLOB.clones_t.Remove(master)
		qdel(spawned_clone, TRUE)
		spawned_clone = null
	. = ..()
	// Don't re-derive which list this was added to from the current selective_update flag - the
	// dropship airlock cycle flips that flag repeatedly via toggle_selective_update() between this
	// projector's creation and its destruction, so re-checking it here can pick the wrong list and
	// silently no-op, leaving a dangling destroyed reference behind. Just remove from both.
	GLOB.projectors -= src
	GLOB.deselected_projectors -= src

/obj/effect/projector/onShuttleMove(turf/newT, turf/oldT, list/movement_force, move_dir, obj/docking_port/stationary/old_dock, obj/docking_port/mobile/moving_dock)
	return TRUE
	// we don't want projectors moving

/obj/effect/projector/airlock
	modify_turf = FALSE
	mask_layer = 1.9
	movables_projection_plane = -7
	projected_mouse_opacity = 0
	projected_opacity = 0
	firing_id = "airlock"
