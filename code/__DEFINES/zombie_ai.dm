// Defines for the NPC Zombie AI foundation (zombie_ai_controller and friends).
// See code/modules/mob/living/carbon/human/zombie_ai/ for the implementation.
// Deliberately simpler than xeno_ai.dm's state machine: zombies are "brainless drones that
// will do anything to get to their target... ruthless" - no flee/retreat behavior at all,
// no pack/escort/hive coordination, no caste economy. RETURNING exists only for the leash
// disengage (lost/too-far target -> walk back toward anchor), never for fleeing when hurt.

/// Idle, no target, scanning at the slow idle heartbeat.
#define ZOMBIE_AI_STATE_IDLE 1
/// Target acquired, closing distance.
#define ZOMBIE_AI_STATE_APPROACHING 2
/// Adjacent to target, actively attacking.
#define ZOMBIE_AI_STATE_ATTACKING 3
/// Disengaging (target lost or too far from anchor), walking back to anchor_turf.
#define ZOMBIE_AI_STATE_RETURNING 4

/// Default scan radius (tiles) used for target acquisition.
#define ZOMBIE_AI_DEFAULT_ATTACK_DISTANCE 10
/// Default leash radius (tiles) from anchor_turf before an AI zombie disengages and returns.
#define ZOMBIE_AI_DEFAULT_RETURN_DISTANCE 15
/// Ticks slept between ai_loop() iterations while actively engaged with a target - as low as
/// sleep() grants, matching the xeno pattern (actual pacing is already gated for free by the
/// pilot's own movement_delay()/attack cooldown).
#define ZOMBIE_AI_DEFAULT_HEARTBEAT 1
/// Ticks slept between ai_loop() iterations while idle/no target - cheaper than the engaged
/// heartbeat, matching the xeno pattern (see AI_XENO_DEFAULT_IDLE_HEARTBEAT's doc comment for
/// why this matters at scale: server load from the idle AI population scales roughly linearly
/// with how low this is).
#define ZOMBIE_AI_DEFAULT_IDLE_HEARTBEAT 6

/// How close is "close enough to skip pathfinding and just step straight at the goal" - mirrors AI_TRAVEL_DIRECT_RANGE.
#define ZOMBIE_AI_TRAVEL_DIRECT_RANGE 3

/// Minimum world.time gap between AI-driven claw swings (mobs and obstacles alike) - the AI
/// calls zombie_claws' attack()/a structure's attack_zombie() directly, bypassing click.dm's
/// do_click() dispatch entirely, so nothing else paces it; without this the engaged heartbeat
/// (ZOMBIE_AI_DEFAULT_HEARTBEAT, as low as sleep() grants) would otherwise let it re-attack
/// every single tick. Matches zombie_claws' own attack_speed (black_goo.dm doesn't override
/// the /obj/item default) so an AI zombie's swing cadence feels the same as a player's.
#define ZOMBIE_AI_MELEE_ATTACK_DELAY 11

/// How long an AI zombie stays committed to a chosen blocking obstacle (see
/// get_blocking_obstacle()) before it's allowed to re-pick a different one - mirrors
/// AI_XENO_OBSTACLE_COMMIT_DURATION, prevents flip-flopping between two equally-valid
/// candidate obstacles every tick.
#define ZOMBIE_AI_OBSTACLE_COMMIT_DURATION 6 SECONDS

/// Damage an AI zombie's claws deal per hit against a structure (window/barricade/airlock)
/// when forcing through an obstacle blocking its path - matches zombie_claws' own melee force
/// (black_goo.dm) rather than inventing a separate balance number.
#define ZOMBIE_AI_STRUCTURE_DAMAGE MELEE_FORCE_TIER_6

/// How long navigate_around() commits to a winning sidestep direction before re-evaluating -
/// mirrors AI_XENO_FALLBACK_WALK_DURATION. Re-aiming fresh every tick instead reads as "walking
/// back and forth" against anything wider than a single tile.
#define ZOMBIE_AI_FALLBACK_WALK_DURATION 8 SECONDS

// --- Pathfinding (Phase 3) - mirrors xeno_ai.dm's AI_PATHFIND_*/PATH_* defines, same values,
// kept as separate zombie-owned knobs since a zombie horde's population/performance profile may
// end up wanting different tuning later. No escalation tier here (unlike xeno's
// AI_PATHFIND_ESCALATION_THRESHOLD/ESCALATED_* pair) - that exists purely to widen the search
// before xeno's attempt_dig_through_stuck() kicks in, and a zombie never digs through anything
// (Phase 2's should_smash_instead_of_climb() doc comment: no strength tiers to weigh), so a
// repeatedly-failing route just keeps falling back to greedy/obstacle-forcing every attempt
// instead of trying progressively wider searches.

/// Cell budget (width*height) for the bounded local solver (compute_path()) - same value as
/// XENO_PATHFIND_MAX_CELLS, reused as a plain constant since it describes the native solver's
/// own practical limit, not anything xeno-specific.
#define ZOMBIE_AI_PATHFIND_MAX_CELLS XENO_PATHFIND_MAX_CELLS
/// Smallest search margin around the direct pilot-goal bounding box compute_path() starts from.
#define ZOMBIE_AI_PATHFIND_MIN_MARGIN 2
/// Largest margin compute_path() will grow to even if the cell budget would allow more.
#define ZOMBIE_AI_PATHFIND_MAX_MARGIN 14
/// A route target that drifted this many tiles from path_goal still counts as "the same goal" - see advance_along_path().
#define ZOMBIE_AI_PATH_GOAL_REPLAN_TOLERANCE 2
/// How long a failed path attempt against the same goal is left alone before trying again.
#define ZOMBIE_AI_PATH_RETRY_COOLDOWN 2 SECONDS
/// Minimum gap between full replans against a goal that's still drifting within tolerance.
#define ZOMBIE_AI_PATH_REPLAN_MIN_INTERVAL 1 SECONDS
