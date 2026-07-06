/**
 * Queen AI - fundamentally different from every other caste's controller:
 * her default loop is hive economy and command (build the hive, sit her
 * throne, direct the hive toward threats), not chase-and-attack. She only
 * drops into the shared combat loop (via ..() -> the base tick()'s normal
 * state machine) when a threat is actually visible or the hive needs her,
 * matching the user's design: "if the hive is under heavy attack she would
 * assist if all other conditions such as the hive not needing eggs or
 * anything else check out."
 *
 * There is only ever one living Queen per hive at a time, so unlike every
 * other controller in this file, her AI is deliberately NOT budgeted for
 * population scale - she gets a wider awareness radius
 * (AI_QUEEN_ATTACK_DISTANCE/RETURN_DISTANCE) and does real per-tick
 * hive-wide reasoning (scanning GLOB.ai_xeno_list for a siege - see
 * check_lz_siege()) that would be inappropriate to give every Drone.
 *
 * Capabilities:
 * - Throne: once the Hive Core is up and nothing's actively threatening her,
 *   she mounts the ovipositor for real - "she can ovi for roleplay." Staying
 *   mounted keeps laying eggs (Life()'s own passive accumulation, unchanged)
 *   and, since Screech/the spit macro/shift_spits get force-granted to her
 *   the instant she mounts regardless of maturity (mount_ovipositor(),
 *   Queen.dm), she's never actually defenseless while sitting there even if
 *   she hasn't aged up naturally. She isn't idle on the throne either:
 *   she keeps issuing scouting orders and periodically uses expand_weeds (an
 *   ovi-exclusive remote-targeted ability) to grow the hive's territory
 *   without needing to physically move - "build and scout... in weeded
 *   areas" while staying on ovi. ("Queen Eye" itself - the player-facing
 *   remote-camera ability - only relocates a *client's* screen view
 *   (client.eye); an AI pilot has no client and already isn't limited by
 *   camera range in the first place (every scan here works off direct
 *   object/turf references), so literally invoking it would be a pure
 *   no-op dressed up as behavior. The scouting/building she already does
 *   from the throne below delivers the same intent - stay put, stay aware,
 *   stay useful - without pretending to use an ability that wouldn't do
 *   anything for her.) Dismounting is always instant and unthrottled - a
 *   real threat is a reflex, not a decision - but re-mounting afterward
 *   waits out AI_QUEEN_REMOUNT_COOLDOWN so a borderline threat-check can't
 *   thrash her in and out of ovi tick after tick.
 * - Economy: builds the Hive Core and expands weed coverage, on the ground
 *   before she's earned her throne and remotely once she has it.
 * - Command: broadcasts a hive-wide alert (hive_status.dm's
 *   queen_alert_turf/queen_alert_time) whenever she has a live target -
 *   every other same-hive AI xeno checks this during idle patrol
 *   (xeno_ai_controller.dm's respond_to_hive_alert()) and heads there
 *   instead of wandering. This is how she "commands" the hive without a
 *   hard command hierarchy.
 * - LZ siege response: if enough same-hive AI xenos are actively fighting
 *   near the marine LZ at once (AI_QUEEN_LZ_SIEGE_THRESHOLD within
 *   AI_QUEEN_LZ_SIEGE_RADIUS), she personally dismounts/stops patrolling
 *   and joins the assault, per the user's explicit direction that she
 *   should join her children once the hive is heavily attacking the LZ.
 * - Group Screech: "Screech is her most powerful ability" - when a target
 *   isn't alone (AI_QUEEN_GROUP_SCREECH_THRESHOLD or more hostiles clustered
 *   within AI_QUEEN_GROUP_SCREECH_RADIUS of it), she opens with Screech
 *   before closing the distance instead of only ever using it reactively
 *   once she's already adjacent and swinging.
 * - Last stand: overrides should_flee() so that when the base logic says
 *   she'd retreat (critically wounded/on fire) but she's the hive's only
 *   living member, she stands and fights instead - retreating would only
 *   delay the inevitable while abandoning the fight for nothing.
 *
 * Known interim simplification: threat assessment is still just "is there a
 * visible target," not a weighted evaluation of multiple simultaneous
 * threats, and there's no persistent "under sustained siege at home" memory
 * distinct from the momentary LZ-siege check - reasonable follow-ups once
 * this is proven in a real round.
 */
/datum/xeno_ai_controller/queen
	/// Current half-width of the area broadcast_scout_order() picks a point within, centered on her anchor - grows over time (up to AI_QUEEN_SCOUT_RADIUS_MAX) while nothing's been found yet, "slowly expanding the search."
	var/scout_radius = AI_QUEEN_SCOUT_RADIUS_MIN
	/// world.time she can next issue a scout order - throttles broadcast_scout_order() to a slow cadence instead of re-picking a point every idle tick.
	var/next_scout_order = 0
	/// Successful plant_weeds actions committed since spawning - see AI_QUEEN_MIN_INITIAL_BUILDS/tick()'s build-before-ovi gate.
	var/initial_builds_done = 0
	/// world.time she's next willing to mount the ovipositor - set on dismount, see AI_QUEEN_REMOUNT_COOLDOWN.
	var/next_mount_attempt = 0
	/// world.time she can next use expand_weeds from the throne - throttles attempt_expand_weeds() the same way next_scout_order throttles scouting orders.
	var/next_expand_weeds_attempt = 0

/datum/xeno_ai_controller/queen/New(mob/living/carbon/xenomorph/new_pilot)
	. = ..()
	attack_distance = AI_QUEEN_ATTACK_DISTANCE
	return_distance = AI_QUEEN_RETURN_DISTANCE
	scout_radius = AI_QUEEN_SCOUT_RADIUS_MIN

// No /proc/ keyword - overriding the base tick(), which itself overrides
// /datum/proc/process(delta_time) (see xeno_ai_controller.dm's own note on
// this). Deliberately does not call ..() at the top the way a normal
// override might - the Queen's decision loop replaces the base one, only
// falling through to it (via explicit ..() calls below) once she's
// committed to fighting.
/datum/xeno_ai_controller/queen/tick()
	var/mob/living/carbon/xenomorph/queen/queen_pilot = pilot
	if(!istype(queen_pilot))
		return

	// Keep scanning for danger even while mounted (immobilized) - the one
	// exception to the base tick()'s "incapacitated means do nothing"
	// shortcut, since a mounted Queen still needs to notice a threat in
	// order to decide to dismount.
	if(!current_target)
		process_target()

	if(current_target)
		broadcast_hive_alert(queen_pilot)

	// Two distinct kinds of "this is bad enough to personally join" - a heavy
	// push at the marine LZ (check_lz_siege(), unchanged) and, now, a real
	// attack on the hive itself back home (check_home_siege()) - previously
	// she had no notion of the latter at all, so a raid that reached the hive
	// while she was off patrolling or mid-ovi never registered as anything
	// worth reacting to distinctly from her own personal current_target.
	var/lz_siege = check_lz_siege(queen_pilot)
	var/home_siege = !lz_siege && check_home_siege(queen_pilot)
	var/heavy_siege = lz_siege || home_siege
	broadcast_escort_call(queen_pilot, heavy_siege)

	if(queen_pilot.ovipositor)
		if(current_target || heavy_siege)
			queen_pilot.dismount_ovipositor(TRUE) // TRUE = instant, no confirmation dialog, no player-facing channel - she needs to react immediately, not wait through the flavor animation a player would.
			next_mount_attempt = world.time + AI_QUEEN_REMOUNT_COOLDOWN
			if(heavy_siege)
				xeno_message(SPAN_XENOANNOUNCE("Queen: I am coming, my children!"), 3, queen_pilot.hivenumber)
			return
		// Still active from the throne, not just laying eggs and waiting -
		// keeps directing the hive (scouting) and keeps growing its
		// territory (expand_weeds, an ovi-exclusive remote ability) instead
		// of going fully dormant the moment she sits down.
		broadcast_scout_order(queen_pilot)
		attempt_expand_weeds(queen_pilot)
		// "When the Queen is on ovi it should say Queen is either commanding
		// or idle" - AI_STATE_IDLE alone doesn't distinguish "mounted and
		// actively directing the hive via an alert/escort broadcast this
		// tick" from "mounted with nothing going on."
		var/broadcasting = queen_pilot.hive && (world.time - queen_pilot.hive.queen_alert_time <= AI_XENO_HIVE_ALERT_WINDOW || world.time - queen_pilot.hive.queen_escort_time <= AI_XENO_HIVE_ALERT_WINDOW)
		idle_activity = broadcasting ? IDLE_ACTIVITY_COMMANDING : IDLE_ACTIVITY_BUILD
		return // Otherwise stay mounted - TRAIT_IMMOBILIZED already prevents movement/melee, and everything above is remote/passive.

	if(queen_pilot.is_mob_incapacitated() || HAS_TRAIT(queen_pilot, TRAIT_IMMOBILIZED))
		return

	if(current_target)
		return ..() // Hand off to the shared approach/attack/leash state machine - she defends herself and the hive normally once committed.

	if(should_flee())
		return ..() // Critically wounded/on fire and not the hive's last defender - let the base flee-and-resist logic run even though she's not mounted.

	if(lz_siege)
		head_to_lz(queen_pilot)
		return

	if(home_siege)
		patrol() // Already home (that's what triggered check_home_siege()) - keep her active nearby (building/scouting, wander()'s own pull back toward anchor) rather than mounting the ovipositor mid-attack; her own process_target() picks up the attacker the moment they're within her scan radius.
		return

	// "Build her hive before going to ovi" - she still won't mount at all
	// until the Hive Core actually exists (should_mount_ovipositor() below
	// checks this too), so the throne is something she's earned, not an
	// escape hatch from an unfinished hive. No time cap on these build gates
	// either - "does not wait for [plasma] to regenerate to continue
	// building" was the previous cap giving up and abandoning the attempt;
	// now she just keeps building for as long as it takes, checking plasma
	// properly each time instead of giving up on it.
	if(queen_pilot.hive && !queen_pilot.hive.has_structure(XENO_STRUCTURE_CORE))
		idle_activity = IDLE_ACTIVITY_BUILD
		// "Queen needs to weed, she is trying to build without weeds" - weed
		// her own tile first if it isn't hers yet, only attempt the actual
		// core once she's standing on real hive weeds.
		var/obj/effect/alien/weeds/own_weeds = locate(/obj/effect/alien/weeds) in get_turf(queen_pilot)
		if(!own_weeds || own_weeds.linked_hive.hivenumber != queen_pilot.hivenumber)
			attempt_plant_weeds()
			return
		// "She is unable to finish building the hive core once its
		// construction node is built" - once the node exists, it needs
		// feeding in small amounts as plasma regenerates (attempt_build_
		// hive_core()'s own internal check), not the full 400 up front -
		// gating the call itself on the full placement cost meant she'd
		// never even attempt a feed until she'd banked 400 again. Both the
		// placement path (place_construction's own use_ability()) and the
		// feed path check their own plasma sufficiency internally, so this
		// is safe to call every tick regardless of her current plasma.
		attempt_build_hive_core(queen_pilot)
		return

	if(initial_builds_done < AI_QUEEN_MIN_INITIAL_BUILDS)
		if(attempt_plant_weeds())
			initial_builds_done++
		patrol()
		return

	// "She can ovi for roleplay" - the hive's actually built and there's
	// nothing pressing to do on foot, so she settles onto her throne. Still
	// productive once there (see the ovipositor branch above), and instant
	// to snap out of the moment that stops being true.
	if(should_mount_ovipositor(queen_pilot))
		var/datum/action/xeno_action/onclick/grow_ovipositor/mount_ability = get_ability(/datum/action/xeno_action/onclick/grow_ovipositor)
		mount_ability?.use_ability(queen_pilot)
		return

	patrol()

/**
 * Gates mounting the ovipositor: the hive needs its Core already (the
 * throne is earned, not a shortcut around unfinished building), she needs
 * to actually be standing on her own hive's weeds (mount_ovipositor() has no
 * location requirement of its own, but a Queen anchoring herself in a
 * random hallway would be a strange place to hold court), the remount
 * cooldown from her last dismount needs to have passed, and grow_ovipositor
 * needs to still be off cooldown (it's the same action a player mounts
 * with, and use_ability() already no-ops safely if it isn't ready).
 */
/datum/xeno_ai_controller/queen/proc/should_mount_ovipositor(mob/living/carbon/xenomorph/queen/queen_pilot)
	if(queen_pilot.ovipositor || world.time < next_mount_attempt)
		return FALSE
	if(!queen_pilot.hive || !queen_pilot.hive.has_structure(XENO_STRUCTURE_CORE))
		return FALSE
	var/obj/effect/alien/weeds/own_weeds = locate(/obj/effect/alien/weeds) in get_turf(queen_pilot)
	if(!own_weeds || own_weeds.linked_hive.hivenumber != queen_pilot.hivenumber)
		return FALSE
	var/datum/action/xeno_action/onclick/grow_ovipositor/mount_ability = get_ability(/datum/action/xeno_action/onclick/grow_ovipositor)
	return mount_ability && mount_ability.action_cooldown_check()

/**
 * Ovi-exclusive remote-targeted build ability (mount_ovipositor()'s
 * immobile_abilities list, Queen.dm) - lets her keep growing the hive's
 * weed footprint from the throne instead of that work stopping dead the
 * moment she mounts. Picks a plain nearby candidate rather than a careful
 * frontier search - expand_weeds' own use_ability() already validates
 * weedability/area eligibility and just silently no-ops on a bad tile, so a
 * wasted attempt here and there costs nothing.
 */
/datum/xeno_ai_controller/queen/proc/attempt_expand_weeds(mob/living/carbon/xenomorph/queen/queen_pilot)
	if(world.time < next_expand_weeds_attempt)
		return
	var/datum/action/xeno_action/activable/expand_weeds/expand_ability = get_ability(/datum/action/xeno_action/activable/expand_weeds)
	if(!expand_ability || !expand_ability.action_cooldown_check())
		return
	next_expand_weeds_attempt = world.time + AI_QUEEN_EXPAND_WEEDS_INTERVAL

	var/list/candidates = list()
	for(var/turf/candidate in range(AI_QUEEN_EXPAND_WEEDS_RADIUS, queen_pilot))
		if(candidate.density || candidate.is_weedable() < FULLY_WEEDABLE)
			continue
		if(locate(/obj/effect/alien/weeds) in candidate)
			continue // Already weeded - nothing to expand there.
		candidates += candidate
	if(!length(candidates))
		return
	expand_ability.use_ability(pick(candidates))

/**
 * "She is unable to finish building the hive core once its construction
 * node is built (you have to keep filling it with plasma as you regenerate
 * plasma, don't spam it either just wait long enough)" - place_construction
 * can never re-place the Hive Core once the empty node exists
 * (check_alien_construction(), XenoProcs.dm, treats the node itself as an
 * obstacle and refuses), so retrying it forever was a dead end: the plasma
 * cost she was banking for a re-placement was never the real requirement.
 * The node's actual 1000-plasma build cost (construction_template_xenomorph.dm -
 * a completely separate number from the 400-plasma placement fee below) is
 * meant to be fed
 * incrementally by attacking the standing node with something other than
 * harm intent (construction_node.dm's attack_alien() -> add_crystal(),
 * which drains her current plasma into it and makes her stand still for
 * its own 4-second windup) - exactly the real "wait for plasma, feed again,
 * don't spam" mechanic. Locates the node once it exists and feeds it
 * instead of endlessly retrying the placement ability against it.
 */
/datum/xeno_ai_controller/queen/proc/attempt_build_hive_core(mob/living/carbon/xenomorph/queen/queen_pilot)
	if(!queen_pilot.hive || queen_pilot.hive.has_structure(XENO_STRUCTURE_CORE))
		return

	var/obj/effect/alien/resin/construction/node = locate(/obj/effect/alien/resin/construction) in get_turf(queen_pilot)
	if(!node)
		for(var/obj/effect/alien/resin/construction/nearby_node in range(3, queen_pilot))
			if(nearby_node.linked_hive == queen_pilot.hive)
				node = nearby_node
				break

	if(node && node.linked_hive == queen_pilot.hive)
		if(!queen_pilot.Adjacent(node))
			if(!advance_along_path(node))
				cardinal_step_towards(node)
			return
		if(queen_pilot.plasma_stored <= 0)
			return // "Don't spam it either, just wait long enough" - nothing to contribute yet, don't burn the feed windup for free.
		queen_pilot.a_intent = INTENT_HELP // attack_alien() destroys the node under INTENT_HARM instead of feeding it.
		node.attack_alien(queen_pilot)
		return

	if(queen_pilot.hive.hivecore_cooldown)
		return
	var/datum/action/xeno_action/activable/place_construction/action = get_ability(/datum/action/xeno_action/activable/place_construction)
	if(!action)
		return
	action.use_ability(get_turf(queen_pilot)) // Safe to call speculatively even without enough plasma yet - use_ability() checks check_plasma(400) itself before deducting anything.

/**
 * She has plant_weeds in her own base_actions same as a Drone (see
 * Queen.dm) but the base controller never called it for her - same
 * build-duty pattern as drone_worker.dm, just her own (higher, since
 * she's one unit rather than a population) chance. Also issues a fresh
 * scout order every so often while idle - "constantly order her hive to
 * focus on specific areas... slowly expand their scouting area" - see
 * broadcast_scout_order().
 */
/datum/xeno_ai_controller/queen/patrol()
	if(respond_to_hive_alert())
		idle_activity = IDLE_ACTIVITY_ALERT
		return
	var/mob/living/carbon/xenomorph/queen/queen_pilot = pilot
	if(istype(queen_pilot))
		broadcast_scout_order(queen_pilot)
	if(prob(AI_QUEEN_BUILD_CHANCE) && attempt_plant_weeds())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	// "Queen should weed like drones" - attempt_plant_weeds() only ever
	// weeds whatever tile she's already standing on, same as a Drone, but
	// falling straight to wander() (rather than the base patrol()'s full
	// idle state machine - long patrols, pack cohesion, scouting) kept her
	// drifting over the same small patch near anchor_turf instead of
	// covering ground the way a Drone's own patrol() fallthrough does.
	return ..()

/// Higher than the population default - "she is big and slow and easy to kill," a huge investment that's hard to save if she overcommits, so she breaks off earlier than a disposable population-scale caste would.
/datum/xeno_ai_controller/queen/get_flee_threshold()
	return AI_QUEEN_FLEE_HEALTH_PERCENT

/**
 * Only flees if the base logic would AND she isn't the hive's last living
 * member - if she's alone, retreating accomplishes nothing but delaying the
 * inevitable while abandoning the fight, so she makes her stand instead.
 */
/datum/xeno_ai_controller/queen/should_flee()
	if(!..())
		return FALSE
	var/mob/living/carbon/xenomorph/queen/queen_pilot = pilot
	if(!istype(queen_pilot))
		return TRUE
	if(is_last_defender(queen_pilot))
		return FALSE
	return TRUE

/datum/xeno_ai_controller/queen/proc/is_last_defender(mob/living/carbon/xenomorph/queen/queen_pilot)
	if(!queen_pilot.hive)
		return FALSE
	for(var/mob/living/carbon/xenomorph/hive_member as anything in queen_pilot.hive.totalXenos)
		if(hive_member == queen_pilot || hive_member.stat == DEAD)
			continue
		return FALSE
	return TRUE

/**
 * "Modify the sentinel and queen AI to only use ranged, and to use melee if
 * unable to escape or enemies are too close" - overrides process_attack()
 * so melee is only ever the cornered case, and delegates positioning to the
 * shared maintain_kiting_distance() helper (xeno_ai_movement.dm) the same
 * way Boiler/Sentinel do, instead of the old "close to melee, only back off
 * once already hurt" policy.
 */
/datum/xeno_ai_controller/queen/process_attack()
	var/mob/living/carbon/xenomorph/queen/queen_pilot = pilot
	if(!istype(queen_pilot) || !current_target)
		ai_state = AI_STATE_IDLE
		return
	if(!is_valid_target(current_target))
		drop_target()
		return

	attempt_group_screech(current_target) // Screech's own range comfortably covers this before she's even adjacent - no-ops silently off cooldown/against a lone target, safe to call every tick.

	if(pilot.Adjacent(current_target)) // Cornered - fight back rather than just standing there.
		execute_attack(current_target)
		return

	attempt_ranged_spit(current_target) // No-ops silently if it's on cooldown - safe to call speculatively.
	ai_state = AI_STATE_APPROACHING // Always re-decide positioning next tick.

/**
 * "Screech is her most powerful ability" - opens with it against a real
 * cluster instead of only ever using it reactively once she's already
 * adjacent and swinging (see use_caste_ability()'s own attempt_screech()
 * call, unchanged, for that reactive case). attempt_screech() itself is
 * cooldown/plasma-safe to call speculatively, so the only extra gate needed
 * here is "is this actually a group" - a lone marine doesn't justify
 * announcing her position from range for a single-target AoE.
 */
/datum/xeno_ai_controller/queen/proc/attempt_group_screech(mob/living/target)
	var/nearby_hostiles = 0
	for(var/mob/living/nearby in orange(AI_QUEEN_GROUP_SCREECH_RADIUS, target))
		if(nearby == target || !is_valid_target(nearby))
			continue
		nearby_hostiles++
		if(nearby_hostiles >= AI_QUEEN_GROUP_SCREECH_THRESHOLD)
			attempt_screech()
			return

/datum/xeno_ai_controller/queen/process_movement()
	if(!pilot || !current_target)
		return
	if(!is_valid_target(current_target))
		drop_target()
		return

	last_seen_turf = get_turf(current_target)
	maintain_kiting_distance(current_target, AI_XENO_RANGED_PREFERRED_DISTANCE)

/**
 * "Spitting is her main ability in combat, make sure she switches between
 * neuro spit and acid spit on demand, not at random" - shift_spits is a
 * plain toggle (cycles to whichever ammo type comes next in
 * caste.spit_types), so with exactly two entries "on demand" just means
 * comparing her current ammo against the one the situation calls for and
 * toggling only when they differ, instead of never touching it at all
 * (leaving her stuck on whichever type she happened to spawn with for the
 * whole round). Acid Spatter up close for the bigger single hit, Neurotoxin
 * at range for the harassing DoT/slow while she's still closing or holding
 * distance.
 */
/datum/xeno_ai_controller/queen/proc/select_spit_type(mob/living/target)
	var/mob/living/carbon/xenomorph/queen/queen_pilot = pilot
	if(!istype(queen_pilot) || !queen_pilot.caste)
		return
	var/desired_type = (get_dist(queen_pilot, target) <= AI_XENO_RANGED_MIN_DISTANCE + 1) ? /datum/ammo/xeno/acid/spatter : /datum/ammo/xeno/toxin/queen
	if(queen_pilot.ammo == GLOB.ammo_list[desired_type])
		return
	var/datum/action/xeno_action/onclick/shift_spits/shift = get_ability(/datum/action/xeno_action/onclick/shift_spits)
	shift?.use_ability(queen_pilot)

/datum/xeno_ai_controller/queen/proc/attempt_ranged_spit(mob/living/target)
	var/datum/action/xeno_action/activable/xeno_spit/queen_macro/spit = get_ability(/datum/action/xeno_action/activable/xeno_spit/queen_macro)
	if(!spit || !spit.action_cooldown_check())
		return
	select_spit_type(target)
	pilot.setDir(get_dir(pilot, target))
	spit.use_ability(target)

/// AoE fear/disorient - "she should use her special ability Screech too." Opportunistic, no real downside to firing it the moment it's off cooldown while cornered into melee.
/datum/xeno_ai_controller/queen/proc/attempt_screech()
	var/datum/action/xeno_action/onclick/screech/screech = get_ability(/datum/action/xeno_action/onclick/screech)
	if(!screech || !screech.action_cooldown_check())
		return FALSE
	screech.use_ability(pilot)
	return TRUE

/**
 * Only offensive melee special she has worth reaching for as an AI: an
 * 8-second, fully-interruptible windup that instantly gibs whatever's
 * adjacent when it completes (queen_gut() in Queen.dm). "Queen should only
 * gib if the enemy that just attacked is dead and not moving, otherwise she
 * should stop trying to gib mid battle" - the old gate only checked whether
 * anything ELSE nearby could interrupt her, not whether the target itself
 * was actually helpless, so she'd still commit the whole windup against a
 * live, mobile opponent that could just walk or hit her out of it. Now only
 * used to finish something already down (dead or floored/incapacitated),
 * never as a mid-fight opener against something still fighting back.
 */
/datum/xeno_ai_controller/queen/use_caste_ability(mob/living/target)
	var/mob/living/carbon/xenomorph/queen/queen_pilot = pilot
	if(!istype(queen_pilot))
		return FALSE

	attempt_screech() // Side effect only (own cooldown/plasma cost) - never blocks also gutting/slashing the same tick below.

	var/target_helpless = target.stat == DEAD || HAS_TRAIT(target, TRAIT_FLOORED) || target.is_mob_incapacitated()
	if(target_helpless)
		var/datum/action/xeno_action/activable/gut/gut_ability = get_ability(/datum/action/xeno_action/activable/gut)
		if(gut_ability && gut_ability.action_cooldown_check())
			for(var/mob/living/nearby in orange(3, queen_pilot))
				if(nearby == target)
					continue
				if(is_valid_target(nearby))
					return attempt_tail_stab(target) // Not a clean opportunity - something else could interrupt the windup or jump her while she's committed.
			gut_ability.use_ability(target)
			return TRUE

	return attempt_tail_stab(target)

// broadcast_hive_alert()/count_nearby_escorts()/broadcast_escort_call() now
// live on the base controller (xeno_ai_controller.dm) - promoted there so
// King can share them too ("coordination with other AI xenos is very
// poor" - he never had an equivalent before). Queen inherits the identical
// behavior automatically.

/**
 * Issues a fresh "scout toward here" order on a slow cadence while idle,
 * expanding the search radius each time (up to AI_QUEEN_SCOUT_RADIUS_MAX)
 * - "constantly order her hive to focus on specific areas of the colony...
 * slowly expand their scouting area." Deliberately doesn't check whether
 * marines have actually been spotted anywhere in the round (that state
 * lives on the gamemode, not the hive/controller) - it only fires while
 * she herself is idle with nothing to fight, which is a reasonable proxy
 * for "nothing's happened near me yet."
 */
/datum/xeno_ai_controller/queen/proc/broadcast_scout_order(mob/living/carbon/xenomorph/queen/queen_pilot)
	if(!queen_pilot.hive || world.time < next_scout_order)
		return
	next_scout_order = world.time + AI_QUEEN_SCOUT_INTERVAL
	scout_radius = min(scout_radius + AI_QUEEN_SCOUT_RADIUS_GROWTH, AI_QUEEN_SCOUT_RADIUS_MAX)

	var/turf/anchor = anchor_turf || get_turf(queen_pilot)
	if(!anchor)
		return
	var/target_x = clamp(anchor.x + rand(-scout_radius, scout_radius), 1, world.maxx)
	var/target_y = clamp(anchor.y + rand(-scout_radius, scout_radius), 1, world.maxy)
	var/turf/scout_turf = locate(target_x, target_y, anchor.z)
	if(!scout_turf)
		return

	queen_pilot.hive.queen_scout_turf = scout_turf
	queen_pilot.hive.queen_scout_time = world.time

/**
 * Counts same-hive AI xenos actively fighting (AI_STATE_APPROACHING/ATTACKING)
 * near the marine LZ - if enough are engaged at once, this counts as a heavy
 * siege worth the Queen personally joining, per explicit design direction.
 * Cheap only because there's a single Queen instance doing this scan, not
 * something every caste's controller could afford.
 */
/datum/xeno_ai_controller/queen/proc/check_lz_siege(mob/living/carbon/xenomorph/queen/queen_pilot)
	var/turf/lz_turf = get_lz_turf()
	if(!lz_turf)
		return FALSE

	var/attackers_at_lz = 0
	for(var/mob/living/carbon/xenomorph/hive_member as anything in GLOB.ai_xeno_list)
		if(hive_member == queen_pilot || hive_member.hivenumber != queen_pilot.hivenumber)
			continue
		var/datum/xeno_ai_controller/member_controller = hive_member.ai_controller
		if(!member_controller || (member_controller.ai_state != AI_STATE_APPROACHING && member_controller.ai_state != AI_STATE_ATTACKING))
			continue
		if(get_dist(hive_member, lz_turf) <= AI_QUEEN_LZ_SIEGE_RADIUS)
			attackers_at_lz++
			if(attackers_at_lz >= AI_QUEEN_LZ_SIEGE_THRESHOLD)
				return TRUE
	return FALSE

/**
 * Same scan as check_lz_siege(), centered on her own anchor_turf instead of
 * the marine LZ - "a persistent under-sustained-siege-at-home read, distinct
 * from the momentary LZ-siege check." Previously she had no notion of a raid
 * reaching the hive itself unless a marine wandered directly into her own
 * personal scan radius - several daughters already fighting for their lives
 * right next to her patrol area went completely unnoticed if she personally
 * hadn't spotted anyone yet.
 */
/datum/xeno_ai_controller/queen/proc/check_home_siege(mob/living/carbon/xenomorph/queen/queen_pilot)
	if(!anchor_turf)
		return FALSE

	var/defenders_at_home = 0
	for(var/mob/living/carbon/xenomorph/hive_member as anything in GLOB.ai_xeno_list)
		if(hive_member == queen_pilot || hive_member.hivenumber != queen_pilot.hivenumber)
			continue
		var/datum/xeno_ai_controller/member_controller = hive_member.ai_controller
		if(!member_controller || (member_controller.ai_state != AI_STATE_APPROACHING && member_controller.ai_state != AI_STATE_ATTACKING))
			continue
		if(get_dist(hive_member, anchor_turf) <= AI_QUEEN_LZ_SIEGE_RADIUS)
			defenders_at_home++
			if(defenders_at_home >= AI_QUEEN_LZ_SIEGE_THRESHOLD)
				return TRUE
	return FALSE

// get_lz_turf() moved to the base xeno_ai_controller (xeno_ai_controller.dm) - shared with attempt_ambush_hide().

/datum/xeno_ai_controller/queen/proc/head_to_lz(mob/living/carbon/xenomorph/queen/queen_pilot)
	var/turf/lz_turf = get_lz_turf()
	if(!lz_turf)
		patrol()
		return
	travel_to_broadcast_turf(lz_turf) // Same obstacle-handling fix as respond_to_hive_alert()/respond_to_queen_escort() - a bare advance_along_path()/cardinal_step_towards() left her stuck on any real obstacle between here and the LZ.
