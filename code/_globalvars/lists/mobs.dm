GLOBAL_LIST_EMPTY(clients) //all clients
GLOBAL_LIST_EMPTY(admins) //all clients whom are admins
GLOBAL_PROTECT(admins)

GLOBAL_LIST_EMPTY(directory) //all ckeys with associated client

GLOBAL_LIST_EMPTY(player_list) //all mobs **with clients attached**.

GLOBAL_LIST_EMPTY(observer_list) //all /mob/dead/observer

GLOBAL_LIST_EMPTY(new_player_list) //all /mob/dead/new_player, in theory all should have clients and those that don't are in the process of spawning and get deleted when done.

GLOBAL_LIST_EMPTY_TYPED(mob_list, /mob)

GLOBAL_LIST_EMPTY_TYPED(living_mob_list, /mob/living)
GLOBAL_LIST_EMPTY_TYPED(alive_mob_list, /mob)

GLOBAL_LIST_EMPTY_TYPED(dead_mob_list, /mob) // excludes /mob/new_player

GLOBAL_LIST_EMPTY_TYPED(human_mob_list, /mob/living/carbon/human)
GLOBAL_LIST_EMPTY_TYPED(alive_human_list, /mob/living/carbon/human) // list of alive marines

GLOBAL_LIST_EMPTY_TYPED(xeno_mob_list, /mob/living/carbon/xenomorph)
GLOBAL_LIST_EMPTY_TYPED(living_xeno_list, /mob/living/carbon/xenomorph)
GLOBAL_LIST_EMPTY_TYPED(xeno_cultists, /mob/living/carbon/human)
GLOBAL_LIST_EMPTY_TYPED(player_embryo_list, /obj/item/alien_embryo)

GLOBAL_LIST_EMPTY_TYPED(hellhound_list, /mob/living/carbon/xenomorph/hellhound)
GLOBAL_LIST_EMPTY_TYPED(zombie_list, /mob/living/carbon/human)
GLOBAL_LIST_EMPTY_TYPED(yautja_mob_list, /mob/living/carbon/human)

/// All xenomorphs currently piloted by a xeno_ai_controller (no client). Maintained by the AI lifecycle procs, not derived on demand.
GLOBAL_LIST_EMPTY_TYPED(ai_xeno_list, /mob/living/carbon/xenomorph)
/// Count of currently active AI-piloted xenos, used to enforce GLOB.ai_xeno_max_active.
GLOBAL_VAR_INIT(ai_xeno_active_count, 0)
/// Hard cap on concurrently AI-piloted xenos, enforced in spawn_ai_xeno().
GLOBAL_VAR_INIT(ai_xeno_max_active, 40)
/// Optional per-caste caps (caste_type text -> max count), enforced alongside ai_xeno_max_active in attach_xeno_ai(). A caste absent from this list has no cap beyond the total. Set live from the admin mission control panel.
GLOBAL_LIST_EMPTY(ai_xeno_max_per_caste)
/// Live-adjustable multiplier on every AI xeno's flee-health-fraction threshold, applied at should_flee() check time (see xeno_ai_controller.dm/crusher.dm) - below 1 makes xenos fight longer before disengaging, above 1 makes them flee earlier. Set from the admin mission control panel's behavior preset. Defaults below 1 - xenomorphs are meant to be ruthless, not skittish, so out of the box they fight well past the point a squishier AI would peel off.
GLOBAL_VAR_INIT(ai_flee_multiplier, 0.6)
/// Live-adjustable multiplier on attack_distance/return_distance, applied once at controller creation (xeno_ai_controller.dm's New()) - only affects xenos spawned after the change, same as ai_xeno_max_active.
GLOBAL_VAR_INIT(ai_distance_multiplier, 1.0)
/// Live-adjustable overall AI difficulty knob (admin AI difficulty panel) - purely a display/backing value for the numeric slider and behavior presets, which is what actually drives ai_flee_multiplier/ai_distance_multiplier.
GLOBAL_VAR_INIT(ai_difficulty_multiplier, 1.0)
/// Xenos spawned while the AI population cap was already full - kept clientless but otherwise idle, promoted to real AI control first-in-first-out as slots free up (see promote_backlogged_xeno() in xeno_ai_lifecycle.dm). Still directly claimable by a ghost at any time regardless of queue position.
GLOBAL_LIST_EMPTY(ai_xeno_backlog)

