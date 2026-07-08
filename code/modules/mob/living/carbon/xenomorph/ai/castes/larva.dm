/**
 * Larva AI - "larva needs to hide, and just in general be scared since they
 * are fragile." Unlike every other caste's controller, spotting a living
 * hostile at all is the flee trigger here, not taking damage - a larva has
 * no attack worth using and dies in one or two hits, so the generic
 * approach-and-attack default (inherited from the base controller before
 * this file existed) was actively suicidal. should_flee() is completely
 * overridden rather than just tuning get_flee_threshold() higher, since the
 * base version's health/ally-count/target-condition reasoning ("finish it
 * off," "not fighting alone") all assume a xeno that can actually win a
 * fight - none of that applies to her. She never enters AI_STATE_ATTACKING
 * at all: the base tick()'s flee-check runs before movement/attack logic
 * every tick, so an unconditional should_flee() intercepts her before she'd
 * ever close distance on a target.
 */
/datum/xeno_ai_controller/larva

/**
 * Spotting any valid living hostile is reason enough to run - no health/
 * ally/target-condition exceptions, she can't win a fight regardless of the
 * numbers.
 *
 * "The larva returns into the core as soon as they spawn" - an organic-
 * growth larva's anchor_turf IS the Hive Core (spawn_organic() spawns her
 * there with no anchor_override), so return_to_anchor()'s destination is
 * that same tile - fleeing "home" while already standing on it just reads
 * as never having left at all. She's not in any more danger standing still
 * there than she would be after "fleeing" a single tile back to the exact
 * spot she's already on, so skip the whole flee cycle while already this
 * close to anchor instead of visibly panicking in place.
 */
/datum/xeno_ai_controller/larva/should_flee()
	if(!pilot || !current_target || !is_valid_target(current_target))
		return FALSE
	if(anchor_turf && get_dist(pilot, anchor_turf) <= AI_XENO_LARVA_SAFE_HOME_RADIUS)
		return FALSE
	return TRUE

/// Never - she has no attack worth turning around for, cornered or not. Always keep running/hiding instead of return_to_anchor()'s generic desperate-stand fallback.
/datum/xeno_ai_controller/larva/get_desperate_threshold()
	return 0
