// Defines for the NPC Xenomorph AI foundation (xeno_ai_controller and friends).
// See code/modules/mob/living/carbon/xenomorph/ai/ for the implementation.

/// Idle, no target, scanning at the slow idle heartbeat.
#define AI_STATE_IDLE 1
/// Target acquired, closing distance.
#define AI_STATE_APPROACHING 2
/// Adjacent to target, actively attacking.
#define AI_STATE_ATTACKING 3
/// Disengaging, walking back to anchor_turf.
#define AI_STATE_RETURNING 4
/// Chasing down the last known position of a target that escaped rather than died (may involve a ladder to cross z-levels).
#define AI_STATE_SEARCHING 5

/// Default scan radius (tiles) used for both target acquisition and re-acquisition.
#define AI_XENO_DEFAULT_ATTACK_DISTANCE 10
/// Default leash radius (tiles) from anchor_turf before an AI xeno disengages and returns.
#define AI_XENO_DEFAULT_RETURN_DISTANCE 15
/// Ticks slept between ai_loop() iterations while actively engaged with a target.
#define AI_XENO_DEFAULT_HEARTBEAT 5
/// Ticks slept between ai_loop() iterations while idle/no target (cheaper than the engaged heartbeat).
#define AI_XENO_DEFAULT_IDLE_HEARTBEAT 15
/// Health fraction (0-1) below which an AI xeno disengages and heads home instead of continuing to fight.
#define AI_XENO_FLEE_HEALTH_PERCENT 0.25
/// How long an AI xeno will keep investigating a lost target's last known position before giving up.
#define AI_XENO_SEARCH_TIMEOUT 15 SECONDS
/// Largest local grid (width*height tiles) handed to the native pathfinder. Beyond this the old greedy step_towards() chase handles it fine - this is for routing around nearby obstacles, not long-range travel.
#define XENO_PATHFIND_MAX_CELLS 900
/// How far an idle xeno will wander from its anchor while patrolling.
#define AI_XENO_PATROL_RADIUS 5
/// Percent chance per idle tick that a patrolling xeno takes a wander step, so it doesn't move every single idle tick.
#define AI_XENO_PATROL_CHANCE 33
/// Percent chance per idle tick that an AI Drone attempts a build action (plant weeds) instead of wandering.
#define AI_DRONE_BUILD_CHANCE 20
/// Tiles an AI ranged xeno tries to stay from its target - closer than this and it backs off instead of closing to melee.
#define AI_XENO_RANGED_PREFERRED_DISTANCE 5
/// If the target closes to within this distance, a ranged xeno actively backs away instead of just holding position.
#define AI_XENO_RANGED_MIN_DISTANCE 2
