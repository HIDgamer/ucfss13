// Defines for the NPC Xenomorph AI foundation (xeno_ai_controller and friends).
// See code/modules/mob/living/carbon/xenomorph/ai/ for the implementation.

/// Idle, no target, scanning at the slow idle heartbeat.
#define AI_STATE_IDLE 1
/// Named sub-states of AI_STATE_IDLE - "Idle" alone used to cover wandering, building, following, hiding, and patrolling all as one flat label with no memory between ticks. See patrol()/xeno_ai_controller.dm's idle_activity var.
#define IDLE_ACTIVITY_NONE "Idle"
#define IDLE_ACTIVITY_ALERT "Responding to alert"
#define IDLE_ACTIVITY_ESCORT "Escorting Queen"
#define IDLE_ACTIVITY_VENT "Vent ambush"
#define IDLE_ACTIVITY_SCOUT "Scouting"
#define IDLE_ACTIVITY_PACK "Regrouping"
#define IDLE_ACTIVITY_AMBUSH "Ambush hiding"
#define IDLE_ACTIVITY_LONG_PATROL "Long patrol"
#define IDLE_ACTIVITY_WANDER "Wandering"
#define IDLE_ACTIVITY_BUILD "Building"
#define IDLE_ACTIVITY_COMMANDING "Commanding"
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
/// How far the pilot can drift from where process_target()'s scan rectangle was last centered before it's considered stale and recomputed - keeps the scan following her as she patrols/wanders instead of staying pinned to wherever she happened to be during her last unsuccessful scan.
#define AI_XENO_TARGET_SCAN_REFRESH_DISTANCE 3
/// Per-swing cooldown the AI's plain melee is held to (execute_attack()'s plain-melee branch, xeno_ai_attack.dm) - attack_alien() itself never sets this, only click_adjacent()'s own `next_move += 4` does, and only for a real player's click. 4 is the bare code-permitted floor though (2.5 attacks/sec sustained), far faster than a real player's actual click cadence in practice (aiming, reacting, missing a click here and there) - "no click delay... can melt a player to death with just slashing" was this AI attacking at that literal floor nonstop, which no human sustains. Set higher to read as a real melee pace instead of the theoretical maximum.
#define XENO_MELEE_ATTACK_DELAY 8
/// Percent chance a plain melee swing against a human uses INTENT_DISARM (a real tackle attempt, can knock down) instead of INTENT_HARM (plain claw damage).
#define AI_XENO_DISARM_CHANCE 20
/// Ticks slept between ai_loop() iterations while actively engaged with a target. Deliberately as low as
/// BYOND's sleep() grants (1 tick) - actual movement/attack pacing is already gated for free by the pilot's
/// own next_move (same movement_delay()/attack cooldown a real player is bound by via step()/attack_alien()),
/// so there's no reason to lay a second, slower artificial cadence on top of it. At 5 this was the real
/// bottleneck behind "pathfinding far too slow" and "never walks and acts in the same window" - a fast
/// caste's true move_delay could be well under 5 ticks, but tick() (and therefore any new step or attack)
/// couldn't run again until the full 5 had passed regardless.
#define AI_XENO_DEFAULT_HEARTBEAT 1
/// Ticks slept between ai_loop() iterations while idle/no target (cheaper than the engaged heartbeat).
#define AI_XENO_DEFAULT_IDLE_HEARTBEAT 15
/// Health fraction (0-1) below which an AI xeno even considers disengaging - see should_flee() for the rest of the decision (target's own health, nearby backup). Raised from 0.25 - "normal casts should really use fleeing better" - combined with the old ally threshold of 1, most fights had an excuse not to disengage until nearly dead.
#define AI_XENO_FLEE_HEALTH_PERCENT 0.35
/// Queen-specific flee threshold, higher than the population default - "she is big and slow and easy to kill," a huge investment worth breaking off with sooner rather than overcommitting.
#define AI_QUEEN_FLEE_HEALTH_PERCENT 0.5
/// Tiles within which a living same-hive AI xeno counts as "backup" for should_flee()'s decision.
#define AI_XENO_FLEE_ALLY_RADIUS 7
/// Nearby same-hive allies (see count_nearby_hive_allies()) at/above which a hurt xeno keeps fighting instead of disengaging - not fighting alone, so the hive's numbers carry it instead. Raised from 1 - a single other daughter happening to be nearby isn't real backup, it was just cancelling the flee decision almost every time.
#define AI_XENO_FLEE_ALLY_THRESHOLD 2
/// Health fraction (0-1) below which a fleeing xeno gives up on running and turns to fight instead - "unless they are very desperate and want to live." Well below the flee threshold: by this point a parting hit while her back's turned is just as likely to kill her as standing and swinging, so running only pays off if she can actually reach safety, not just because she's hurt. Only relevant while already fleeing (return_to_anchor()) and only when there's still a real target adjacent to turn on.
#define AI_XENO_DESPERATE_HEALTH_PERCENT 0.12
/// Drone-specific flee threshold, higher than the population default - "many casts like... drones... dive to their deaths." She's a builder pressed into a fight, not a frontline unit, so she should break off sooner than a caste actually built to brawl.
#define AI_DRONE_FLEE_HEALTH_PERCENT 0.35
/// Radius (tiles) find_defensible_turf() searches for a corner/wall position with limited approach angles - "they should also consider corners and walls as defensive positions" for fleeing/kiting castes instead of always retreating across open ground.
#define AI_XENO_DEFENSIBLE_SEARCH_RADIUS 6
/// Cardinally-adjacent dense tiles a candidate turf needs before find_defensible_turf() considers it "defensible" (fewer open approach directions).
#define AI_XENO_DEFENSIBLE_MIN_DENSE_SIDES 2
/// How long an AI xeno will keep investigating a lost target's last known position before giving up.
#define AI_XENO_SEARCH_TIMEOUT 15 SECONDS
/// Largest local grid (width*height tiles) handed to the native pathfinder. Beyond this the old greedy step_towards() chase handles it fine - this is for routing around nearby obstacles, not long-range travel.
#define XENO_PATHFIND_MAX_CELLS 900
/// Tiles a live target can drift from where a cached path was computed for before advance_along_path() throws it out and replans - keeps a moving target from forcing a fresh plan (and a fresh solver tie-break near corners) every single tick.
#define PATH_GOAL_REPLAN_TOLERANCE 2
/// How long a committed obstacle-skirt (navigate_around()/attempt_skirt_obstacle()) keeps walking one direction before it's willing to re-aim at the goal - "long pathfinding to go around a building is not possible" needed enough distance in one direction to actually clear a building's corner, not just one sidestep.
#define AI_XENO_SKIRT_DURATION 8 SECONDS
/// How far an idle xeno will wander from its anchor while patrolling.
#define AI_XENO_PATROL_RADIUS 10
/// Percent chance per idle tick that a hurt xeno standing on healing-eligible weeds opportunistically rests to heal up, rather than only ever resting once critically hurt and already back at anchor_turf.
#define AI_XENO_OPPORTUNISTIC_REST_CHANCE 8
/// Hard cap on how long wander() lets her rest before standing back up regardless of health - see rest_timeout.
#define AI_XENO_MAX_REST_DURATION 1 MINUTES
/// Percent chance per idle tick that a patrolling xeno takes a wander step, so it doesn't move every single idle tick.
#define AI_XENO_PATROL_CHANCE 33
/// How long wander() commits to a single heading before picking a new one - see wander()'s doc comment for why this exists.
#define AI_XENO_WANDER_COMMIT_TIME 6 SECONDS
/// Percent chance per idle tick (once no higher-priority order applies) that a xeno starts a long patrol leg instead of short-range wander() - see start_long_patrol().
#define AI_XENO_LONG_PATROL_CHANCE 10
/// Percent chance a long patrol leg specifically targets the marine LZ (once one's been chosen) instead of a random distant point.
#define AI_XENO_LONG_PATROL_LZ_CHANCE 40
/// How many tiles current_patrol_radius() grows per minute of round time.
#define AI_XENO_LONG_PATROL_RADIUS_GROWTH_PER_MINUTE 2
/// Cap on how far current_patrol_radius() can grow.
#define AI_XENO_LONG_PATROL_RADIUS_MAX 60
/// Percent chance per idle tick that an AI Drone attempts a build action (plant weeds) instead of wandering. Kept low - every Drone in the hive rolls this independently on its own idle heartbeat, so even a modest chance adds up fast across a full population ("weeding everywhere").
#define AI_DRONE_BUILD_CHANCE 8
/// Percent chance per idle tick that an eligible builder caste (Drone/Hivelord/Burrower) attempts a defensive resin wall at the hive perimeter instead of just weeding - see attempt_build_defense().
#define AI_DEFENSE_BUILD_CHANCE 6
/// Nearest a defensive perimeter wall is allowed to anchor_turf - keeps walls from boxing in the hive core itself.
#define AI_XENO_DEFENSE_PERIMETER_MIN_RADIUS 4
/// Farthest a defensive perimeter wall is allowed from anchor_turf.
#define AI_XENO_DEFENSE_PERIMETER_MAX_RADIUS 8
/// Percent chance per idle tick that a Burrower actually burrows to ambush instead of wandering - kept low, same reasoning as AI_VENT_AMBUSH_CHANCE.
#define AI_BURROWER_AMBUSH_CHANCE 5
/// Percent chance per movement tick, while chasing a target still out of melee range, that a Burrower burrows in place to set up a tunnel-ambush instead of just walking the rest of the way over.
#define AI_BURROWER_AMBUSH_ENGAGE_CHANCE 35
/// Health fraction below which a Burrower starts actually weighing whether to retreat mid-fight, once the target's back up and still a real threat - "they should consider slashing until the enemy is up, and then they get to decide to flee or keep fighting," not a flat dice roll after every swing regardless of how the fight's going.
#define AI_BURROWER_CAUTIOUS_HEALTH_PERCENT 0.6
/// How long a Burrower's tactical retreat lasts once triggered - long enough to actually put distance on the target before reconsidering.
#define AI_BURROWER_RETREAT_DURATION 6 SECONDS
/// Distance from the target a retreating Burrower wants before she ducks back underground to wait out the rest of the retreat safely, rather than just standing in the open.
#define AI_BURROWER_RETREAT_SAFE_DISTANCE 4
/// Percent chance per idle tick that the Queen attempts a build action - she's a single unit, not a population, so this can run a bit higher than a Drone's without the same compounding effect.
#define AI_QUEEN_BUILD_CHANCE 12
/// Tiles an AI ranged xeno tries to stay from its target - closer than this and it backs off instead of closing to melee.
#define AI_XENO_RANGED_PREFERRED_DISTANCE 5
/// If the target closes to within this distance, a ranged xeno actively backs away instead of just holding position.
#define AI_XENO_RANGED_MIN_DISTANCE 2
/// How long other hive members will respond to the Queen's last hive-alert broadcast before it goes stale (see hive_status.dm's queen_alert_turf).
#define AI_XENO_HIVE_ALERT_WINDOW 30 SECONDS
/// How far away a hive-alert will actually pull an idle builder off what she's doing - a fight on the far side of the map shouldn't empty out every drone's weeding queue.
#define AI_XENO_HIVE_ALERT_RESPONSE_RANGE 25
/// Plasma cost for an AI xeno's own opportunistic combat pheromone burst - matches emit_pheromones()'s own default cost (general_powers.dm) rather than inventing a separate balance number.
#define AI_XENO_PHEROMONE_COST 30
/// There's only ever one Queen at a time, so she can afford a much wider awareness radius than population-scale castes.
#define AI_QUEEN_ATTACK_DISTANCE 18
#define AI_QUEEN_RETURN_DISTANCE 28
/// King is the same kind of solo boss unit as Queen (one per round, not a population-budgeted caste) - "should be as deadly if not more deadly than the Queen," but had no override at all and was stuck on the flat population-default radius, noticing threats far later and giving up chases far sooner than she does.
#define AI_KING_ATTACK_DISTANCE 18
#define AI_KING_RETURN_DISTANCE 28
/// Radius around the Queen used to count how many same-hive daughters already count as her escort.
#define AI_QUEEN_ESCORT_RADIUS 7
/// Stops calling for more escorts once this many are already nearby - "up to 10 daughters."
#define AI_QUEEN_ESCORT_MAX 10
/// Tiles from the Queen an escorting daughter holds at instead of stacking directly on her tile.
#define AI_QUEEN_ESCORT_HOLD_DISTANCE 2
/// How often the Queen issues a fresh scouting order while idle.
#define AI_QUEEN_SCOUT_INTERVAL 60 SECONDS
/// How long other hive members will respond to the Queen's last scouting order before it goes stale.
#define AI_QUEEN_SCOUT_ORDER_WINDOW 90 SECONDS
/// Starting half-width of the Queen's scouting search area, in tiles.
#define AI_QUEEN_SCOUT_RADIUS_MIN 10
/// How much the scouting search radius grows each time a new order is issued.
#define AI_QUEEN_SCOUT_RADIUS_GROWTH 5
/// Cap on how far the scouting search radius can expand to.
#define AI_QUEEN_SCOUT_RADIUS_MAX 40
/// Successful plant_weeds actions the Queen commits to before considering her build duties satisfied - "build her hive" as a real, ongoing priority.
#define AI_QUEEN_MIN_INITIAL_BUILDS 3
/// Radius around the marine LZ used to judge whether the hive's attack on it counts as a "heavy" siege worth the Queen personally joining.
#define AI_QUEEN_LZ_SIEGE_RADIUS 12
/// Number of same-hive AI xenos actively fighting near the LZ before the Queen considers it a heavy siege and moves to join.
#define AI_QUEEN_LZ_SIEGE_THRESHOLD 3
/// Minimum time the Queen waits after dismounting before she's willing to mount the ovipositor again - dismounting itself is always instant/unthrottled (a threat is a reflex), only settling back down is a considered decision worth a cooldown so a borderline threat-check doesn't thrash her in and out of ovi every tick.
#define AI_QUEEN_REMOUNT_COOLDOWN 20 SECONDS
/// How often a mounted Queen uses expand_weeds to grow the hive's territory from her throne - "build... in weeded areas" while staying productive on ovi instead of only ever laying eggs.
#define AI_QUEEN_EXPAND_WEEDS_INTERVAL 45 SECONDS
/// Radius expand_weeds' frontier-tile search covers from the Queen's own position.
#define AI_QUEEN_EXPAND_WEEDS_RADIUS 6
/// Living hostiles clustered within this radius of a target before the Queen leads with Screech instead of just closing to melee/spitting range - "Screech is her most powerful ability," worth opening with against a group instead of only using it reactively once already swinging.
#define AI_QUEEN_GROUP_SCREECH_RADIUS 3
/// Minimum clustered hostiles (the primary target plus this many more) before a pre-emptive Screech opener is worth it - a single marine doesn't justify announcing her position before she's even in range.
#define AI_QUEEN_GROUP_SCREECH_THRESHOLD 2
/// Health fraction below which a Crusher disengages - lower than the population-wide default since it's meant to be the hive's tank, not a caste that breaks off early, but not so low she has no margin left to actually reach safety - "crusher... dive to their deaths."
#define AI_CRUSHER_FLEE_HEALTH_PERCENT 0.18
/// Percent chance after a Ravager's attack that it sidesteps to a flanking tile instead of standing still - the behavioral stand-in for its "nimble/evasive" identity (there's no actual dodge/evasion stat on the caste).
#define AI_RAVAGER_REPOSITION_CHANCE 25
/// Minimum nearby hostiles before a Ravager uses Scissor Cut instead of a plain melee swing.
#define AI_RAVAGER_SCISSOR_MIN_TARGETS 2
/// Minimum nearby hostiles before a Ravager arms Empower - matches the ability's own super-empower payoff threshold, so it's only used in a real group fight where the buff is worth it.
#define AI_RAVAGER_EMPOWER_MIN_TARGETS 3
/// How long a Praetorian/Ravager's tactical retreat lasts once triggered (see start_tactical_retreat()) - "hop into action, slash marines, and hop back into safety, and repeat."
#define AI_PRAETORIAN_RETREAT_DURATION 4 SECONDS
/// Percent chance per plain melee swing (Acid Ball not currently up) that a Praetorian decides she's landed enough hits and retreats anyway.
#define AI_PRAETORIAN_RETREAT_CHANCE 15
/// Same shape as AI_PRAETORIAN_RETREAT_DURATION - Ravager is meant to behave the same way once she's landed a hit.
#define AI_RAVAGER_RETREAT_DURATION 4 SECONDS
/// Percent chance per plain melee swing (Scissor Cut not currently up) that a Ravager retreats anyway, same reasoning as AI_PRAETORIAN_RETREAT_CHANCE.
#define AI_RAVAGER_RETREAT_CHANCE 15
/// How long a Lurker's tactical retreat lasts once triggered - "make retreating a strategic part of their attack plan too, as they attack and die."
#define AI_LURKER_RETREAT_DURATION 5 SECONDS
/// Percent chance per plain melee swing (Assassinate not currently up) that a Lurker retreats to re-cloak instead of continuing to trade blows in the open.
#define AI_LURKER_RETREAT_CHANCE 20
/// Health fraction below which a Runner flees - higher than the population default since she's the hive's glass cannon (lowest HP, no armor), meant to hit and run rather than trade hits.
#define AI_RUNNER_FLEE_HEALTH_PERCENT 0.4
/// Minimum valid targets already adjacent before a Defender uses Tail Sweep instead of a plain melee swing.
#define AI_DEFENDER_SWEEP_MIN_TARGETS 2
/// Boiler's own scan/leash radius - wider than the population default so she notices and starts bombarding from well outside melee range instead of needing a target to wander close first.
#define AI_BOILER_ATTACK_DISTANCE 14
/// Health fraction below which a Boiler flees - higher than the population default since she's fire-vulnerable and low on melee damage, and getting run down is close to a worst case for this caste.
#define AI_BOILER_FLEE_HEALTH_PERCENT 0.4
/// Distance a Boiler retreats to while both her ranged abilities are on cooldown ("attack ranged, hide, then come out again once recharged") - wider than the plain ranged kiting band so she's actually out of easy melee reach while waiting, not just standing at the edge of it.
#define AI_BOILER_HIDE_DISTANCE 8
/// Percent chance per idle tick that a Hivelord attempts a build action - higher than a Drone's own AI_DRONE_BUILD_CHANCE since her build_time_mult (0.5x) makes her genuinely more efficient at it, not just eager.
#define AI_HIVELORD_BUILD_CHANCE 12
/// Health fraction below which a Carrier disengages - higher than the population default since she has no offensive tools to actually win a fight she's already losing.
#define AI_CARRIER_FLEE_HEALTH_PERCENT 0.4
/// Percent chance per idle tick that an eligible xeno (can_ventcrawl()) ducks into a nearby vent instead of wandering normally. Only rolled once hive-alert/escort/long-patrol-continuation have all already passed (see tick()'s idle chain), so the real-world frequency is well below this number by itself - raised from 5 since that compounded rarity read as "never happens" in practice.
#define AI_VENT_AMBUSH_CHANCE 20
/// Percent chance per idle tick that a xeno with no better order gravitates toward a nearby idle ally instead of wandering solo - "stick together sometimes in a group."
#define AI_PACK_COHESION_CHANCE 20
/// How close counts as "already sticking together" for pack cohesion - stops short of stacking exactly on the buddy's tile.
#define AI_PACK_COHESION_HOLD_DISTANCE 3
/// Percent chance per idle tick that a xeno instead treks out toward the marine LZ to hide and wait - "hiding to ambush" instead of only ever patrolling near the hive.
#define AI_XENO_AMBUSH_CHANCE 6
/// Half-width of the area around the LZ attempt_ambush_hide() picks a hiding tile within.
#define AI_XENO_AMBUSH_LZ_RADIUS 10
/// How long an ambush hide holds before giving up and resuming normal patrol if nothing shows up.
#define AI_XENO_AMBUSH_HIDE_DURATION 40 SECONDS
/// Minimum/maximum hops through the connected pipe graph before popping back out - see vent_travel() in xeno_ai_vents.dm.
#define AI_VENT_MIN_HOPS 2
#define AI_VENT_MAX_HOPS 6
