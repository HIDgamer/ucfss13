// Defines for the NPC Human AI (SShuman_ai, /datum/human_ai_brain and friends).
// See code/modules/mob/living/carbon/human/ai/. Zombie AI lives separately in zombie_ai/.

/// Brain intents - gate which actions may score.
#define HAI_INTENT_IDLE 1
#define HAI_INTENT_ALERT 2
#define HAI_INTENT_INVESTIGATE 3
#define HAI_INTENT_ENGAGE 4
#define HAI_INTENT_ADVANCE 5
#define HAI_INTENT_HOLD 6
#define HAI_INTENT_FALLBACK 7
#define HAI_INTENT_BROKEN 8
#define HAI_INTENT_ORDERED 9

/// LOD tiers - the value is the think interval in deciseconds.
#define HAI_TIER_ENGAGED 2
#define HAI_TIER_ALERT 4
#define HAI_TIER_IDLE 10
#define HAI_TIER_DORMANT 30

/// Brains allowed to think at ENGAGED/ALERT/IDLE fidelity at once.
#define HAI_MAX_FULL 60
/// Brains allowed to exist at all, 0 for no limit. The ones past HAI_MAX_FULL are put to sleep and not refused, so the count is not what costs anything.
#define HAI_MAX_TOTAL 0

/// Errors a brain may throw before it is switched off.
#define HAI_MAX_ERRORS 5
/// A brain throwing HAI_MAX_ERRORS inside this window is disabled, errors older than this are forgiven.
#define HAI_ERROR_WINDOW (2 MINUTES)

/// Entries kept in each brain's decision ring buffer.
#define HAI_DECISION_LOG_SIZE 24

/// Rules of engagement.
#define HAI_ROE_WEAPONS_FREE 1
#define HAI_ROE_WEAPONS_TIGHT 2
#define HAI_ROE_WEAPONS_HOLD 3
#define HAI_ROE_NONLETHAL_ONLY 4

/// Disposition toward a mob or faction.
#define HAI_DISP_FRIEND 1
#define HAI_DISP_NEUTRAL 2
#define HAI_DISP_WARY 3
#define HAI_DISP_SUSPECT 4
#define HAI_DISP_HOSTILE 5

/// Limbs an action occupies, two actions sharing one cannot run together.
#define HAI_LIMB_HANDS (1<<0)
#define HAI_LIMB_LEGS (1<<1)
#define HAI_LIMB_MOUTH (1<<2)

/// Mood bands by stress.
#define HAI_MOOD_STEADY 1
#define HAI_MOOD_RATTLED 2
#define HAI_MOOD_SHAKEN 3
#define HAI_MOOD_BREAKING 4

/// Why a brain stopped, for the debug log.
#define HAI_STOP_DETACHED "detached"
#define HAI_STOP_DEAD "dead"
#define HAI_STOP_CLAIMED "claimed by a player"
#define HAI_STOP_ERRORS "too many errors"
#define HAI_STOP_DELETED "deleted"
#define HAI_STOP_SPECIES "species changed"

/// A walking destination counts as reached inside this many tiles.
#define HAI_ARRIVE_DISTANCE 1
/// Furthest a brain looks for a target, in tiles.
#define HAI_SIGHT_RANGE 9
/// A target unseen this long is forgotten.
#define HAI_TARGET_FORGET_TIME (8 SECONDS)
/// Minimum gap between two route requests from one brain.
#define HAI_PATH_REQUEST_COOLDOWN 5
/// Longest a brain keeps following one cached route before asking again.
#define HAI_PATH_MAX_AGE (6 SECONDS)

/// What stands in the way of a step.
#define HAI_OBS_NONE 0
#define HAI_OBS_DOOR 1
#define HAI_OBS_CLIMB 2
#define HAI_OBS_BLOCKED 3
#define HAI_OBS_MOB 4

/// Result of the last move_to call.
#define HAI_MOVE_WALKING 1
#define HAI_MOVE_ARRIVED 2
#define HAI_MOVE_BLOCKED 3

/// How long a denied or unreachable turf is avoided.
#define HAI_BLOCK_MEMORY (30 SECONDS)
/// Danger the pathfinder is given at a turf the body could not pass.
#define HAI_BLOCK_DANGER 400
/// Route requests the whole subsystem may make per fire.
#define HAI_PATH_REQUESTS_PER_FIRE 8
/// Standing still this long while trying to walk counts as stuck.
#define HAI_STUCK_TIME (3 SECONDS)
/// Stuck recoveries tried before the goal is given up.
#define HAI_GIVE_UP_LIMIT 3
/// Blocked routes tolerated before the goal is called unreachable.
#define HAI_ROUTE_RETRIES 2
/// Sprinting only starts beyond this distance and with this much energy.
#define HAI_SPRINT_MIN_DISTANCE 7
#define HAI_SPRINT_MIN_ENERGY 40
/// Tiles between followers and the one they follow.
#define HAI_FORMATION_SPACING 2

/// Contacts one brain keeps at most.
#define HAI_MAX_CONTACTS 8
/// A brain with no enemy near and nothing remembered still looks around on every Nth scan, for enemies the grid does not track.
#define HAI_FULL_SCAN_EVERY 5
/// Ticks between looks while the brain is engaged, thinks in between work from the last look.
#define HAI_SCAN_ENGAGED_INTERVAL 5
/// Seconds an unseen contact stays remembered at neutral alertness.
#define HAI_CONTACT_MEMORY 20
/// Notice lost per second by a contact that is out of sight.
#define HAI_NOTICE_FADE 0.1
/// Notice at which the body turns to look at something it cannot make out yet.
#define HAI_SUSPECT_NOTICE 0.3
/// A target stays a target this long after it was last seen.
#define HAI_ENGAGE_MEMORY (3 SECONDS)
/// How long a brain searches for a lost target at neutral alertness.
#define HAI_SEARCH_PATIENCE (12 SECONDS)
#define HAI_SEARCH_RADIUS 4
#define HAI_SEARCH_POINTS 3

/// Noise kinds.
#define HAI_NOISE_GUNSHOT "gunshot"
#define HAI_NOISE_EXPLOSION "explosion"
#define HAI_NOISE_DOOR "door"
#define HAI_NOISE_GLASS "glass"
#define HAI_NOISE_MELEE "melee"
#define HAI_NOISE_ALARM "alarm"
#define HAI_NOISE_MISC "misc"
/// Quietest sound volume the noise bus passes on.
#define HAI_NOISE_MIN_VOLUME 40
/// Furthest a sound is heard, whatever its range.
#define HAI_NOISE_MAX_RANGE 60
/// Noise strength needed to turn the head, and to go and look.
#define HAI_NOISE_ALERT 0.15
#define HAI_NOISE_INVESTIGATE 0.35
/// Ticks before the same shooter's next shot is passed on as a new noise, a burst is one noise.
#define HAI_GUNSHOT_NOISE_REPEAT 5
/// Tiles of aim error per tile of distance when guessing where a noise came from.
#define HAI_NOISE_ERROR 0.15
/// A shot passing within this many tiles of a body tells it someone is shooting.
#define HAI_SHOT_NEAR_MISS 2
#define HAI_SHOT_NOTICE_RANGE 20

/// Gun families the appraisal sorts weapons into.
#define HAI_GUN_NONE 0
#define HAI_GUN_PISTOL 1
#define HAI_GUN_SMG 2
#define HAI_GUN_RIFLE 3
#define HAI_GUN_SHOTGUN 4
#define HAI_GUN_HEAVY 5
#define HAI_GUN_SNIPER 6
#define HAI_GUN_OTHER 7
#define HAI_GUN_LAUNCHER 8
#define HAI_GUN_FLAMER 9

/// How a gun takes its ammunition.
#define HAI_FEED_NONE 0
/// A detachable magazine.
#define HAI_FEED_MAGAZINE 1
/// A tube, cylinder or breech filled one round at a time.
#define HAI_FEED_INTERNAL 2
#define HAI_FEED_ROCKET 3
#define HAI_FEED_TANK 4
#define HAI_FEED_GRENADE 5

/// How a gun gets its next round chambered after a shot.
#define HAI_CYCLE_AUTO 0
/// Needs a unique action between shots (pump, lever, bolt).
#define HAI_CYCLE_MANUAL 1

/// Where a gun stands, from weapon_state().
#define HAI_WEAPON_READY 0
/// Rounds left but none chambered.
#define HAI_WEAPON_CYCLE 1
/// Breech or cylinder left open after loading.
#define HAI_WEAPON_OPEN 2
#define HAI_WEAPON_EMPTY 3
/// Safety or pilot light off.
#define HAI_WEAPON_SAFE 4

#define HAI_RELOAD_NONE 0
/// Waiting out the reload time before a magazine, tank or rocket goes in.
#define HAI_RELOAD_SWAP 1
#define HAI_RELOAD_OPEN 2
/// Putting rounds in one at a time.
#define HAI_RELOAD_LOAD 3
#define HAI_RELOAD_CLOSE 4
/// Fewest deciseconds a magazine swap takes.
#define HAI_RELOAD_MIN_TIME 10
/// Deciseconds per round loaded into a tube or cylinder.
#define HAI_RELOAD_ROUND_TIME 6
/// Deciseconds between pumps, levers and bolt cycles.
#define HAI_CYCLE_TIME 4
/// Deciseconds a search of the pockets for ammunition is trusted.
#define HAI_SPARE_CHECK_INTERVAL 30

/// Deciseconds an alert neutral brain needs to line up a shot at something new.
#define HAI_REACTION_TIME 5
/// Tiles of miss per tile of distance for a calm, steady shooter.
#define HAI_AIM_ERROR_PER_TILE 0.04
/// Deciseconds between aimed shots of a neutral brain on semi-automatic, however fast the gun could cycle.
#define HAI_SEMI_INTERVAL 3
/// Deciseconds between changes of fire mode.
#define HAI_MODE_SWITCH_TIME 10
/// Shots a neutral brain fires on automatic before letting go of the trigger.
#define HAI_VOLLEY_SHOTS 4
#define HAI_VOLLEY_PAUSE 4
/// Trigger pulls with no shot before the gun is set aside for a moment.
#define HAI_FIRE_FAIL_LIMIT 4
#define HAI_GUN_BLOCK_TIME 60
/// Tiles around the target that must hold no friends before fire or blast is thrown at it.
#define HAI_AREA_SAFE_RADIUS 2
/// Cover: tiles searched around the body, the coverage fraction that counts as cover, the extra a new spot must offer over the current one,
/// deciseconds between searches, least cover desire that makes a brain look for any, and searches allowed per subsystem fire.
#define HAI_COVER_SEARCH_RADIUS 5
#define HAI_COVER_MIN_SCORE 0.5
#define HAI_COVER_HYSTERESIS 0.2
#define HAI_COVER_SEARCH_INTERVAL 20
#define HAI_COVER_MIN_DESIRE 0.7
#define HAI_COVER_SEARCHES_PER_FIRE 3
/// Deciseconds a hive's answer to whether it is allied is remembered.
#define HAI_HIVE_CACHE_TIME 100
/// Deciseconds between looks for live grenades and the like around the body.
#define HAI_HAZARD_CHECK_INTERVAL 5
/// Deciseconds between table flips, tiles around a live grenade or flame the body gets clear of.
#define HAI_FLIP_COOLDOWN 80
#define HAI_HAZARD_RADIUS 4
/// Shots fired from cover before the brain ducks, and deciseconds it stays down.
#define HAI_PEEK_SHOTS 4
#define HAI_PEEK_DUCK 15
/// Which humans a brain fights: only the enemy factions, every human of another faction, or no human at all.
#define HAI_AGGRO_FACTIONS 0
#define HAI_AGGRO_OTHERS 1
#define HAI_AGGRO_NONE 2
/// Deciseconds after a shot passes close that the brain still counts as being shot at.
#define HAI_SUPPRESSED_TIME 30
/// Least force that makes a held item a melee weapon.
#define HAI_MELEE_MIN_FORCE 12
/// Deciseconds between shoves, and between attempts to put out flames.
#define HAI_SHOVE_COOLDOWN 40
#define HAI_RESIST_FIRE_INTERVAL 20
/// What a grenade is for.
#define HAI_GRENADE_NONE 0
#define HAI_GRENADE_LETHAL 1
#define HAI_GRENADE_SMOKE 2
#define HAI_GRENADE_FLASH 3
/// Tiles the body keeps from the point where a lethal grenade lands, and from a smoke or flash grenade.
#define HAI_GRENADE_LETHAL_RANGE 5
#define HAI_GRENADE_SOFT_RANGE 4
/// Tiles around the landing point that must hold no friends.
#define HAI_GRENADE_SAFE_RADIUS 3
#define HAI_GRENADE_MAX_RANGE 8
/// Deciseconds between grenades, and how long a grenade that would not prime blocks the next try.
#define HAI_GRENADE_COOLDOWN 150
#define HAI_GRENADE_BLOCK_TIME 600
/// Fraction of a magazine below which a quiet moment is used to swap it.
#define HAI_TACTICAL_RELOAD_FRACTION 0.35
/// Deciseconds after the last sighting that still count as being in contact.
#define HAI_CONTACT_COOLDOWN 50
/// Deciseconds between changes of weapon.
#define HAI_SWITCH_COOLDOWN 15
/// Deciseconds without shooting after which a new target gets a fresh reaction delay.
#define HAI_REACTION_FORGET 40

/// How an order reaches the brain: forced, or a request that goes through the compliance roll.
#define HAI_DELIVERY_COMMAND 1
#define HAI_DELIVERY_REQUEST 2
/// Where an order stands.
#define HAI_ORDER_ACTIVE 1
#define HAI_ORDER_DONE 2
#define HAI_ORDER_REFUSED 3
#define HAI_ORDER_CANCELLED 4
#define HAI_ORDER_EXPIRED 5
#define HAI_ORDER_FAILED 6
/// Deciseconds a patrol or clear stops at a point, and how long orders that never finish by themselves run.
#define HAI_PATROL_PAUSE 20
#define HAI_SUPPRESS_TIME (8 SECONDS)
#define HAI_TAKE_COVER_TIME (30 SECONDS)
#define HAI_STAND_DOWN_TIME (30 SECONDS)
/// Tiles a fall back order carries the body from the threat.
#define HAI_FALL_BACK_DISTANCE 10

/// Squad formations.
#define HAI_FORM_WEDGE 1
#define HAI_FORM_COLUMN 2
#define HAI_FORM_LINE 3
#define HAI_FORM_SCATTER 4
/// What a squad member is doing for the squad plan.
#define HAI_SQUAD_ROLE_NONE 0
#define HAI_SQUAD_ROLE_FIRE 1
#define HAI_SQUAD_ROLE_MANEUVER 2
#define HAI_SQUAD_ROLE_ANCHOR 3
#define HAI_SQUAD_ROLE_OVERWATCH 4
/// Squad plays.
#define HAI_PLAY_NONE 0
#define HAI_PLAY_HOLD_LINE 1
#define HAI_PLAY_FLANK 2
#define HAI_PLAY_FALLBACK 3
#define HAI_SQUAD_MAX_MEMBERS 12
/// Deciseconds between squad plans, and tiles a member may stray from its leader before it closes up.
#define HAI_SQUAD_PLAN_INTERVAL 10
#define HAI_SQUAD_LEASH 5
/// Longest and shortest deciseconds a call-out takes to reach the squad.
#define HAI_CALLOUT_DELAY_MAX 12
#define HAI_CALLOUT_DELAY_MIN 4
/// Deciseconds before the same contact is reported again.
#define HAI_CALLOUT_REPEAT 30
/// Deciseconds a flank is committed to, and the wait before the squad tries another one.
#define HAI_FLANK_COMMIT (20 SECONDS)
#define HAI_FLANK_COOLDOWN (25 SECONDS)
/// Smallest angle off the line of fire a flanking position must have.
#define HAI_FLANK_MIN_ARC 60
/// Deciseconds the target must have held its ground before the squad flanks it.
#define HAI_PINNED_TIME (4 SECONDS)
/// Deciseconds a fall back is committed to, and the wait before the squad pulls back again.
#define HAI_FALLBACK_COMMIT (15 SECONDS)
#define HAI_FALLBACK_COOLDOWN (30 SECONDS)
/// Deciseconds a squad member holds the rally point after it gets there.
#define HAI_RALLY_HOLD (15 SECONDS)

/// How one faction regards another.
#define HAI_REL_FRIENDLY 1
#define HAI_REL_NEUTRAL 2
#define HAI_REL_HOSTILE 3
/// What a brain does when its stress tops out.
#define HAI_BREAK_NONE null
#define HAI_BREAK_FLEE "flee"
#define HAI_BREAK_FREEZE "freeze"
#define HAI_BREAK_SURRENDER "surrender"
#define HAI_BREAK_BERSERK "berserk"
#define HAI_BREAK_HIDE "hide"
/// Deciseconds between mood updates and the shortest and longest spell of breaking.
#define HAI_MOOD_INTERVAL 10
#define HAI_BREAK_MIN_TIME (6 SECONDS)
#define HAI_BREAK_MAX_TIME (14 SECONDS)
/// Stress a brain is left with after a spell of breaking, and how long a surrender lasts.
#define HAI_BREAK_RECOVERY_STRESS 55
#define HAI_SURRENDER_TIME (40 SECONDS)
/// Stress for an ally falling nearby, the range that counts as nearby and the relief of a kill.
#define HAI_ALLY_DOWN_STRESS 12
#define HAI_ALLY_DOWN_RANGE 7
#define HAI_KILL_RELIEF 8
/// Stages of the ladder of force with a human who is not an enemy yet.
#define HAI_WATCH_OBSERVE 1
#define HAI_WATCH_CHALLENGE 2
#define HAI_WATCH_WARN 3
#define HAI_WATCH_HOSTILE 4
/// Humans a brain keeps an eye on, how long it remembers one it lost sight of, the range at which an armed stranger is challenged and how long an escalation lasts.
#define HAI_MAX_WATCHED 3
#define HAI_WATCH_MEMORY (10 SECONDS)
#define HAI_CHALLENGE_RANGE 5
#define HAI_ESCALATION_MEMORY (60 SECONDS)

/// Kinds of things a brain says or emotes.
#define HAI_EXPR_CONTACT "contact"
#define HAI_EXPR_XENO "xeno"
#define HAI_EXPR_RELOAD "reload"
#define HAI_EXPR_COVER_ME "cover_me"
#define HAI_EXPR_FRAG "frag"
#define HAI_EXPR_FLASH "flash"
#define HAI_EXPR_SMOKE "smoke"
#define HAI_EXPR_PAIN "pain"
#define HAI_EXPR_MAN_DOWN "man_down"
#define HAI_EXPR_MEDIC "medic"
#define HAI_EXPR_TAKING_FIRE "taking_fire"
#define HAI_EXPR_FEAR "fear"
#define HAI_EXPR_CHALLENGE "challenge"
#define HAI_EXPR_WARN "warn"
#define HAI_EXPR_HOSTILE "hostile"
#define HAI_EXPR_SURRENDER "surrender"
#define HAI_EXPR_GREET "greet"
#define HAI_EXPR_CLEAR "clear"
#define HAI_EXPR_KILL "kill"
#define HAI_EXPR_TAUNT "taunt"
#define HAI_EXPR_BATTLE_CRY "battle_cry"
#define HAI_EXPR_IDLE "idle"
#define HAI_EXPR_REFUSE "refuse"
#define HAI_EXPR_ACK "ack"
#define HAI_EXPR_FALL_BACK "fall_back"
#define HAI_EXPR_MOVING "moving"
#define HAI_EXPR_EXPLOSION "explosion"
#define HAI_EXPR_CONVO "convo"
/// Fewest deciseconds between two things one brain says, and between two when the later one is a call-out that matters.
#define HAI_TALK_MIN_GAP 80
#define HAI_TALK_CRITICAL_GAP 30
/// Things all brains together may say in one window, and in one area in the same window.
#define HAI_TALK_AREA_WINDOW 150
#define HAI_TALK_AREA_CAP 3
#define HAI_TALK_GLOBAL_CAP 15
/// How many times longer a routine remark waits than a call-out that matters, the base chance and the chance per point of chattiness that it is said at all, and the chance an emote goes along with a line.
#define HAI_TALK_ROUTINE_COOLDOWN_MULT 3
#define HAI_TALK_ROLL_BASE 5
#define HAI_TALK_ROLL_PER_CHATTINESS 0.4
#define HAI_TALK_EMOTE_CHANCE 15
/// Fewest deciseconds between two radio calls of one squad.
#define HAI_RADIO_GAP 60
/// Deciseconds between idle things, tiles an idle brain strolls from home, deciseconds between conversations of one brain and how long a stranger stays greeted.
#define HAI_IDLE_GAP_MIN 80
#define HAI_IDLE_GAP_MAX 200
#define HAI_IDLE_WANDER_RADIUS 5
#define HAI_CONVO_GAP 2400
#define HAI_GREET_MEMORY 3000

/// What a medical item treats.
#define HAI_MED_BANDAGE "bandage"
#define HAI_MED_SALVE "salve"
#define HAI_MED_SPLINT "splint"
/// Tiles a medic looks for patients within, deciseconds between searches, how long a patient stays claimed, how long a treatment keeps the hands busy and how long a triage order runs.
#define HAI_MEDIC_RANGE 12
#define HAI_PATIENT_SEARCH_INTERVAL 10
#define HAI_PATIENT_CLAIM_TIME 80
#define HAI_TREAT_TIME 25
#define HAI_SPLINT_TIME 90
#define HAI_TRIAGE_TIME (2 MINUTES)
/// Tiles a call for a medic carries, and how long it is remembered.
#define HAI_MEDIC_CALL_RANGE 20
#define HAI_MEDIC_CALL_MEMORY (15 SECONDS)
/// Tiles around a casualty a medic looks for cover to drag them to, and deciseconds between those searches.
#define HAI_DRAG_SEARCH_RADIUS 5
#define HAI_DRAG_SEARCH_INTERVAL 10

/// Tiles a sniper sees through the scope.
#define HAI_SNIPER_RANGE 14
/// Hits on a nest that make its occupant leave, and how long the nest is avoided after.
#define HAI_NEST_HITS 3
#define HAI_NEST_AVOID_TIME (60 SECONDS)
/// Deciseconds an enemy that ducked out of sight is still shot at by a gunner.
#define HAI_SUPPRESS_MEMORY 60
/// Stress a leader's word takes off a wavering squadmate, the range it reaches and the wait before the next try.
#define HAI_RALLY_RELIEF 20
#define HAI_RALLY_RANGE 8
#define HAI_RALLY_COOLDOWN 80
#define HAI_EXPR_RALLY "rally"
#define HAI_EXPR_WATCH_FIRE "watch_fire"
#define HAI_EXPR_BACKUP "backup"

/// Tiles around a security brain that it looks for someone to cuff within.
#define HAI_PRISONER_RANGE 8
/// Stages of a breach.
#define HAI_BREACH_IDLE 0
#define HAI_BREACH_STACK 1
#define HAI_BREACH_OPEN 2
#define HAI_BREACH_THROW 3
#define HAI_BREACH_WAIT 4
#define HAI_BREACH_ENTER 5
#define HAI_BREACH_CLEAR 6
/// Longest a breach may take, and how long the team has to clear the room after going in.
#define HAI_BREACH_TIMEOUT (90 SECONDS)
#define HAI_BREACH_CLEAR_TIME (15 SECONDS)
/// How far from where a team goes in the spots it is sent to clear may be, and how many it tries to find one it can walk to.
#define HAI_BREACH_SECTOR_RANGE 14
#define HAI_BREACH_SECTOR_TRIES 24

/// Sheets one metal barricade costs, deciseconds it takes to build, free turfs the builder must keep around it, mines laid per order.
#define HAI_BARRICADE_COST 4
#define HAI_BUILD_TIME 40
#define HAI_ROOM_NEEDED 14
#define HAI_MAX_MINES 3
/// Stages of fortifying and of demolishing.
#define HAI_FORTIFY_BUILD "build"
#define HAI_FORTIFY_SENTRY "sentry"
#define HAI_FORTIFY_MINES "mines"
#define HAI_DEMOLISH_PLANT "plant"
#define HAI_DEMOLISH_RETREAT "retreat"
#define HAI_DEMOLISH_WAIT "wait"

/// Sent by a door when it finishes opening, with the mob that tried it if known.
#define COMSIG_DOOR_OPENED "door_opened"
/// Seconds a door an engineer electrified stays live, the traps one side may have rigged at once, and how long a door guard waits between looks.
#define HAI_SHOCK_TIME 25
#define HAI_MAX_TRAPS 10
#define HAI_DOOR_GUARD_INTERVAL 10
/// Tiles around a guarded door that count as the approach, and as the doorstep.
#define HAI_DOOR_APPROACH 10
#define HAI_DOOR_STEP 3

/// How long a civilian stays frightened after the last sign of danger, tiles it looks for a roof within, how far from the danger it wants to be, deciseconds between searches, range at which a gun turned on it makes it put its hands up and how long they stay up.
#define HAI_PANIC_TIME (20 SECONDS)
#define HAI_SHELTER_RADIUS 10
#define HAI_SHELTER_SAFE_DISTANCE 6
#define HAI_SHELTER_SEARCH_INTERVAL 30
#define HAI_HANDS_UP_RANGE 7
#define HAI_HANDS_UP_TIME (20 SECONDS)

/// Tiles into the room the breach team aims its flash, and the tiles around a flash that catch anyone with unprotected eyes.
#define HAI_BREACH_DEPTH 6
#define HAI_FLASH_RANGE 7

/// Tiles within which a security brain closes in with its baton on someone with empty hands.
#define HAI_BATON_RANGE 4

/// Shift the aggressive and cautious postures put on the aggression and caution traits.
#define HAI_POSTURE_CAUTIOUS -1
#define HAI_POSTURE_NORMAL 0
#define HAI_POSTURE_AGGRESSIVE 1
#define HAI_POSTURE_SHIFT 25
/// The fastest way a brain may move, set from the command panel.
#define HAI_MOVE_CAP_WALK 1
#define HAI_MOVE_CAP_JOG 2
#define HAI_MOVE_CAP_SPRINT 3
/// Rows per roster page, deciseconds a roster snapshot is reused, deciseconds between orders of one kind from one panel and the longest delay an order may be staged for.
#define HAI_COMMAND_PAGE_SIZE 25
#define HAI_COMMAND_SNAPSHOT_TIME 10
#define HAI_COMMAND_ORDER_COOLDOWN 5
#define HAI_COMMAND_MAX_DELAY 60
#define HAI_COMMAND_MAX_SPAWN 40

/// When a population group is placed: at the start of the round, after the first dropship lands, kept topped up, or only when an admin or event asks.
#define HAI_POP_ROUNDSTART 1
#define HAI_POP_ON_LANDING 2
#define HAI_POP_TRICKLE 3
#define HAI_POP_ON_EVENT 4
/// What a placed group does with its time.
#define HAI_POP_LOITER "loiter"
#define HAI_POP_PATROL "patrol"
#define HAI_POP_GUARD "guard"
#define HAI_POP_SHELTER "shelter"
#define HAI_POP_WANDER "wander"
/// Deciseconds between director runs, after the start of the round before the first group is placed, humans placed per run, the gap between trickle placements of one group and the time a body lies before it is cleared when nobody sees it.
#define HAI_POP_CHECK_INTERVAL (5 SECONDS)
#define HAI_POP_ROUNDSTART_DELAY (30 SECONDS)
#define HAI_POP_BURST 6
#define HAI_POP_TRICKLE_GAP (30 SECONDS)
#define HAI_POP_CORPSE_TIME (10 MINUTES)
/// Tiles a placed human must be from any player, placement tries per human and tiles around the spawn the stacking check covers.
#define HAI_POP_MIN_PLAYER_DISTANCE 16
#define HAI_POP_PLACE_TRIES 24
#define HAI_POP_POCKET_SIZE 20

/// Deciseconds between difficulty scalings from the player count, between budget checks, the milliseconds a second all AI together may cost before the human AI backs off and the most it slows brains that are not in a fight.
#define HAI_SCALE_INTERVAL (30 SECONDS)
#define HAI_ARBITER_INTERVAL (10 SECONDS)
#define HAI_BUDGET_TOTAL_MS 200
#define HAI_ARBITER_MAX_SLOWDOWN 3

/// Tiles around home an idle armed brain looks for a place to stand watch, the spots it weighs, how long it keeps a post before weighing again and the tiles it can see from one.
#define HAI_POST_RADIUS 7
#define HAI_POST_CANDIDATES 40
#define HAI_POST_RECHECK (3 MINUTES)
#define HAI_POST_VIEW 8

/// Deciseconds a brain remembers having turned down a climb, how long it waits between two vaults and how many times it looks for a way round before it climbs when nothing presses it.
#define HAI_DETOUR_MEMORY (12 SECONDS)
#define HAI_VAULT_COOLDOWN (6 SECONDS)
#define HAI_CLIMB_DETOURS 2
/// How long a door that will not open for the brain is left alone.
#define HAI_DOOR_DENIED_MEMORY (3 MINUTES)

/// Tiles past the target that a missed shot is still checked for friends, the most spread in tiles a friend beside the target is tolerated at, aim rolls tried before holding fire and how long fire is held when no aim is safe.
#define HAI_FF_OVERSHOOT 5
#define HAI_FF_SPREAD 0.5
#define HAI_FF_AIM_TRIES 3
#define HAI_FF_HOLD 10

/// Tiles a brain wants to keep between itself and something that wins by getting close, and anything else, how far it looks to back off to, deciseconds between steps back and how many it takes before it stands and fights.
#define HAI_KEEP_AWAY_MELEE 5
#define HAI_KEEP_AWAY_OTHER 3
#define HAI_KITE_RADIUS 3
#define HAI_KITE_INTERVAL 6
#define HAI_KITE_STEP_LIMIT 6
#define HAI_KITE_WINDOW (12 SECONDS)

/// What a chemical treatment is, how much of a patient's damage it takes to be worth an injection, the gap between two injections of one chemical into one patient and the share of the overdose limit a patient may be brought up to.
#define HAI_MED_INJECTOR "injector"
#define HAI_INJECT_MIN_DAMAGE 15
#define HAI_INJECT_GAP (20 SECONDS)
#define HAI_INJECT_OD_MARGIN 0.9

/// How long it takes a hacker to break into a door it has no access to.
#define HAI_HACK_TIME (7 SECONDS)

/// Whitelist flags that make a job senior staff for the NPC panel, the commander tiers, and the scope that matches no faction at all.
#define HAI_COMMAND_WHITELISTS (WHITELIST_COMMANDER|WHITELIST_COMMANDER_COUNCIL|WHITELIST_COMMANDER_COUNCIL_LEGACY|WHITELIST_COMMANDER_LEADER|WHITELIST_COMMANDER_COLONEL)
#define HAI_COMMAND_NO_SCOPE "no faction"

/// How long after a body is revived the brain waits for a player to take it before the AI takes it back.
#define HAI_REVIVE_GRACE (5 SECONDS)

/// Hits from its own side a brain forgives before it hits back, how long hits are counted over and how long it holds the grudge afterwards.
#define HAI_TOLERANCE_HITS 3
#define HAI_TOLERANCE_WINDOW (30 SECONDS)
#define HAI_TOLERANCE_GRUDGE (60 SECONDS)

/// Tiles a call for backup carries, how many allies answer it, how long a caller waits before calling again and the shortest gap between two backup calls over the radio from one faction.
#define HAI_BACKUP_RANGE 25
#define HAI_BACKUP_ANSWERS 4
#define HAI_BACKUP_GAP (25 SECONDS)
#define HAI_BACKUP_RADIO_GAP (8 SECONDS)

/// Tiles around the body it looks for something worth picking up, deciseconds between two pick-ups and the most a brain picks up in its life.
#define HAI_LOOT_RANGE 5
#define HAI_LOOT_GAP (4 SECONDS)
#define HAI_LOOT_LIMIT 12

/// Tiles a player's voice command carries to a unit, how many units answer one command and how long a unit waits before it takes another from the same player.
#define HAI_VOICE_RANGE 7
#define HAI_VOICE_ANSWERS 8
#define HAI_VOICE_GAP (3 SECONDS)

/// How far a body must be mended past the point of death before a shock is tried, how long a medic spends on one shock, how long a body that did not take is left alone, and how far a rescuer looks for a downed friend.
#define HAI_DEFIB_MARGIN 10
#define HAI_DEFIB_TIME (12 SECONDS)
#define HAI_DEFIB_RETRY (25 SECONDS)
#define HAI_RESCUE_RANGE 5
/// How loyal a soldier that is not a medic has to be to risk dragging a downed friend out of fire.
#define HAI_RESCUE_LOYALTY 35

/// How long a unit waits before it rigs a ghillie suit up again.
#define HAI_CAMO_GAP (30 SECONDS)

/// How much mercy a unit needs to take the surrender of an enemy who calls it out, how long it keeps its word, and how much mercy a soldier that is not a guard needs to put restraints on a captive.
#define HAI_SURRENDER_MERCY 40
#define HAI_SURRENDER_ACCEPT_TIME (45 SECONDS)
#define HAI_CAPTIVE_MERCY 30

/// How long a unit reckons a ladder climb takes, and so how long it holds still for it.
#define HAI_LADDER_TIME (4 SECONDS)

/// Tiles around the point a unit told to hold an area keeps to.
#define HAI_HOLD_AREA_RADIUS 6

/// How far from itself a unit looks for a cell to put a prisoner in, and how far from it a captive can be and still be taken away.
#define HAI_HOLDING_RANGE 25
#define HAI_ESCORT_RANGE 7

/// Tiles from the enemy at which a suicider arms its grenade, and the tiles from which a stealth unit that has not been found opens fire.
#define HAI_BOMBER_RANGE 7
#define HAI_AMBUSH_RANGE 7

/// The stages of forcing a door with a charge: none under way, planting it, backing off and waiting for it to go off.
#define HAI_FORCE_NONE 0
#define HAI_FORCE_PLANT 1
#define HAI_FORCE_RETREAT 2
#define HAI_FORCE_WAIT 3

/// What a welder and a coil of cable do for a machine's wounds, how much damage on a limb is worth the repair and how long a repair takes on another and on oneself.
#define HAI_MED_WELD "weld"
#define HAI_MED_CABLE "cable"
#define HAI_SYNTH_REPAIR_MIN 6
#define HAI_REPAIR_TIME 25
#define HAI_REPAIR_SELF_TIME 45

/// How far a maintenance unit looks for work, the gap between two looks, how long it leaves alone what it could not mend, the share of jobs it starts with a word, the damage on a wall that is worth a welder and how long the longest single job is expected to take.
#define HAI_MAINT_RANGE 9
#define HAI_MAINT_SCAN_GAP (3 SECONDS)
#define HAI_MAINT_SKIP (3 MINUTES)
#define HAI_MAINT_QUIP_CHANCE 30
#define HAI_WALL_REPAIR_MIN 10
#define HAI_MAINT_JOB_TIME (90 SECONDS)

/// A maintenance unit's chatter: the quips it lets slip, the word it has about the job it takes up and the remark it makes about what it notices.
#define HAI_EXPR_QUIP "quip"
#define HAI_EXPR_TASK "task"
#define HAI_EXPR_NOTICE "notice"

/// How far a medic goes for a wounded or dead man of its squad wherever he is, how long it leaves one it could not get to, how many times one body is shocked back within the window,
/// the health share below which a unit counts as hurt and how far it goes to fetch the gear it was wearing when it died.
#define HAI_SQUAD_AID_RANGE 90
#define HAI_PATIENT_SKIP (30 SECONDS)
#define HAI_REVIVE_LIMIT 2
#define HAI_REVIVE_WINDOW (3 MINUTES)
#define HAI_HURT_FRACTION 0.7
#define HAI_REGEAR_RANGE 25

/// The fake stairs: the smallest jump a trigger has to make to count as a stair, how close triggers must lie to be one flight, how many pairs of turfs are remembered as walkable or not and for how long,
/// the wait between two searches for a stair, how long a stair walk may take, how near the exit a body has to be to count as across, how long it may stand on the stair without being carried and how long a stair that failed is left alone.
#define HAI_STAIR_MIN_VECTOR 6
#define HAI_STAIR_GROUP_RANGE 4
#define HAI_REACH_CACHE_SIZE 400
#define HAI_REACH_CACHE_TIME (30 SECONDS)
#define HAI_STAIR_PLAN_GAP (4 SECONDS)
#define HAI_STAIR_TIME (60 SECONDS)
#define HAI_STAIR_LANDING 3
#define HAI_STAIR_WAIT (4 SECONDS)
#define HAI_STAIR_SKIP (2 MINUTES)
/// How many of the stairs of a real map the test of them tries.
#define HAI_REAL_STAIR_SAMPLES 3

/// How long it takes to pull a grenade and pull its pin with a gun in the hands before it is thrown, and how long the hands are busy afterwards getting the gun back up. Nothing is shot in either.
#define HAI_GRENADE_DRAW_TIME (1.2 SECONDS)
#define HAI_GRENADE_RECOVER_TIME (1 SECONDS)

/// What a unit can make out in the dark and of something hiding: the light on a tile below which it counts as dark, the light at and above which it is as good as daylight, the share of a subject it makes out at the dark limit,
/// the farthest a cloaked or camouflaged body can be made out from, and the alpha at or below which a body counts as camouflaged.
#define HAI_DARK_LIGHT 0.15
#define HAI_LIT_LIGHT 0.45
#define HAI_DIM_CLARITY 0.3
#define HAI_CONCEAL_SIGHT 2
#define HAI_CONCEAL_ALPHA 100
/// How far a unit wearing night vision goggles makes things out in the dark, and how far the eyes reach when they are blurred.
#define HAI_NIGHT_VISION_REACH 20
#define HAI_BLURRY_REACH 4

/// Staying unseen. How long an alarm takes to die down, how long a body that was found is remembered, the sound a step makes, how far a man running and one crawling are heard,
/// the gap between two markers over a head and the share of the alarm a squad mate takes from what another has found.
#define HAI_VIGILANCE_FADE (2 MINUTES)
#define HAI_BODY_MEMORY (5 MINUTES)
#define HAI_NOISE_STEP "step"
#define HAI_FOOTSTEP_RANGE 6
#define HAI_FOOTSTEP_CRAWL_RANGE 2
#define HAI_CUE_GAP (3 SECONDS)
#define HAI_SQUAD_ALARM_SHARE 0.6

/// The markers over a head: something stirred it, and it knows.
#define HAI_CUE_SUSPECT 1
#define HAI_CUE_ALERT 2

/// Gear. The gap between two looks over what is worn, the light on a tile below which a lamp is wanted and how long a welding mask stays down after the last bit of welding.
#define HAI_GEAR_GAP (2 SECONDS)
#define HAI_LAMP_LIGHT 0.3
/// Most lamps the AI keeps lit at once on the whole server, the lights are not free.
#define HAI_LAMP_CAP 60
#define HAI_WELD_HOLD (12 SECONDS)

/// How far a unit that has lost its gun looks for one to take up, the gap between two looks and how long a gun that could not be reached is left alone.
#define HAI_RECOVER_RANGE 9
#define HAI_RECOVER_SEARCH_GAP (1.5 SECONDS)
#define HAI_RECOVER_SKIP (20 SECONDS)

/// The kinds of work a maintenance unit takes up.
#define HAI_MAINT_LIGHT "light"
#define HAI_MAINT_CLEAN "clean"
#define HAI_MAINT_WALL "wall"
#define HAI_MAINT_FLOOR "floor"
#define HAI_MAINT_APC "apc"

/// The most single steps it takes to put an APC right, the time between a maintenance unit's quips and looks at the people around it, and the tiles it watches them from.
#define HAI_APC_STEP_LIMIT 24
#define HAI_JOE_QUIP_GAP_MIN (25 SECONDS)
#define HAI_JOE_QUIP_GAP_MAX (70 SECONDS)
#define HAI_JOE_WATCH_GAP (4 SECONDS)
#define HAI_JOE_WATCH_RANGE 5
