/// The twelve launch personalities, traits are 0 to 100 and each multiplier scales the weight of one action

/datum/human_ai_personality/hostile
	id = "hostile"
	name = "Hostile"
	desc = "Shoots first, never challenges, pursues and finishes the downed."
	traits = list("aggression" = 90, "caution" = 25, "discipline" = 40, "courage" = 80, "paranoia" = 35, "sociability" = 15, "alertness" = 55, "mercy" = 10, "composure" = 60, "initiative" = 70, "loyalty" = 50, "chattiness" = 40)
	action_mults = list("close_in" = 1.3, "move_to_cover" = 0.7, "melee" = 1.2, "throw_grenade" = 1.1)

/datum/human_ai_personality/paranoid
	id = "paranoid"
	name = "Paranoid"
	desc = "Jumpy at noises, sees threats early and shakes under stress."
	traits = list("aggression" = 55, "caution" = 70, "discipline" = 35, "courage" = 40, "paranoia" = 95, "sociability" = 20, "alertness" = 90, "mercy" = 30, "composure" = 35, "initiative" = 50, "loyalty" = 40, "chattiness" = 45)
	action_mults = list("investigate" = 1.5, "move_to_cover" = 1.3, "throw_grenade" = 1.2)

/datum/human_ai_personality/friendly
	id = "friendly"
	name = "Friendly"
	desc = "Greets, warns, challenges for long and forgives quickly."
	traits = list("aggression" = 25, "caution" = 45, "discipline" = 55, "courage" = 55, "paranoia" = 15, "sociability" = 95, "alertness" = 60, "mercy" = 90, "composure" = 60, "initiative" = 45, "loyalty" = 70, "chattiness" = 85)
	action_mults = list("close_in" = 0.6, "fire_gun" = 0.9, "move_to_cover" = 1.1)

/datum/human_ai_personality/cautious
	id = "cautious"
	name = "Cautious"
	desc = "Cover first, bounds forward, uses grenades, falls back early and never charges."
	traits = list("aggression" = 30, "caution" = 90, "discipline" = 65, "courage" = 45, "paranoia" = 55, "sociability" = 40, "alertness" = 75, "mercy" = 60, "composure" = 70, "initiative" = 30, "loyalty" = 65, "chattiness" = 35)
	action_mults = list("close_in" = 0.35, "move_to_cover" = 1.6, "flip_cover" = 1.4, "throw_grenade" = 1.4, "melee" = 0.7)

/datum/human_ai_personality/professional
	id = "professional"
	name = "Professional"
	desc = "Doctrine, a strict ladder of force, clean call-outs, flanks and suppresses."
	traits = list("aggression" = 55, "caution" = 55, "discipline" = 95, "courage" = 75, "paranoia" = 40, "sociability" = 45, "alertness" = 70, "mercy" = 60, "composure" = 90, "initiative" = 55, "loyalty" = 85, "chattiness" = 40)
	action_mults = list("move_to_cover" = 1.2, "weapon_care" = 1.1, "throw_grenade" = 1.1)

/datum/human_ai_personality/reckless
	id = "reckless"
	name = "Reckless"
	desc = "Charges, loud, ignores its health until it is low and risks hitting friends."
	traits = list("aggression" = 95, "caution" = 10, "discipline" = 15, "courage" = 95, "paranoia" = 20, "sociability" = 35, "alertness" = 40, "mercy" = 20, "composure" = 40, "initiative" = 90, "loyalty" = 35, "chattiness" = 70)
	action_mults = list("close_in" = 1.7, "move_to_cover" = 0.4, "flip_cover" = 0.4, "throw_grenade" = 1.3, "melee" = 1.4)

/datum/human_ai_personality/skittish
	id = "skittish"
	name = "Skittish"
	desc = "Flees, hides and surrenders, the default for civilians."
	traits = list("aggression" = 10, "caution" = 85, "discipline" = 10, "courage" = 10, "paranoia" = 70, "sociability" = 50, "alertness" = 70, "mercy" = 85, "composure" = 15, "initiative" = 15, "loyalty" = 40, "chattiness" = 55)
	action_mults = list("close_in" = 0.15, "fire_gun" = 0.8, "move_to_cover" = 1.8, "melee" = 0.4)

/datum/human_ai_personality/veteran
	id = "veteran"
	name = "Veteran"
	desc = "Calm, slow to react, accurate and quiet, holds the line."
	traits = list("aggression" = 50, "caution" = 60, "discipline" = 85, "courage" = 90, "paranoia" = 45, "sociability" = 25, "alertness" = 80, "mercy" = 55, "composure" = 95, "initiative" = 60, "loyalty" = 80, "chattiness" = 15)
	action_mults = list("move_to_cover" = 1.2, "close_in" = 0.8, "weapon_care" = 1.15)

/datum/human_ai_personality/ruthless
	id = "ruthless"
	name = "Ruthless"
	desc = "Executes the downed, taunts and finishes what it flashes."
	traits = list("aggression" = 85, "caution" = 35, "discipline" = 70, "courage" = 80, "paranoia" = 45, "sociability" = 20, "alertness" = 65, "mercy" = 5, "composure" = 85, "initiative" = 70, "loyalty" = 40, "chattiness" = 50)
	action_mults = list("close_in" = 1.2, "throw_grenade" = 1.3, "melee" = 1.1)

/datum/human_ai_personality/guardian
	id = "guardian"
	name = "Guardian"
	desc = "Sticks to its leader or charge, body-blocks and drags the wounded out."
	traits = list("aggression" = 45, "caution" = 60, "discipline" = 80, "courage" = 85, "paranoia" = 50, "sociability" = 40, "alertness" = 80, "mercy" = 60, "composure" = 75, "initiative" = 25, "loyalty" = 100, "chattiness" = 30)
	action_mults = list("close_in" = 0.7, "keep_formation" = 2)

/datum/human_ai_personality/zealot
	id = "zealot"
	name = "Zealot"
	desc = "Never retreats or surrenders and chants as it comes."
	traits = list("aggression" = 100, "caution" = 5, "discipline" = 30, "courage" = 100, "paranoia" = 10, "sociability" = 25, "alertness" = 40, "mercy" = 0, "composure" = 80, "initiative" = 80, "loyalty" = 70, "chattiness" = 60)
	action_mults = list("close_in" = 1.9, "move_to_cover" = 0.2, "flip_cover" = 0.2, "melee" = 1.5)

/datum/human_ai_personality/scout
	id = "scout"
	name = "Scout"
	desc = "Point man: investigates, walks, calls contact first."
	traits = list("aggression" = 40, "caution" = 55, "discipline" = 60, "courage" = 55, "paranoia" = 60, "sociability" = 30, "alertness" = 100, "mercy" = 55, "composure" = 70, "initiative" = 80, "loyalty" = 50, "chattiness" = 25)
	action_mults = list("investigate" = 1.6, "close_in" = 0.9, "move_to_cover" = 1.1)

/datum/human_ai_personality/synthetic
	id = "synthetic"
	name = "Synthetic"
	desc = "Calm and collected: composed under fire, disciplined, slow to anger, gentle with the wounded and sparing with words."
	traits = list("aggression" = 20, "caution" = 55, "discipline" = 95, "courage" = 85, "paranoia" = 10, "sociability" = 40, "alertness" = 85, "mercy" = 75, "composure" = 100, "initiative" = 45, "loyalty" = 85, "chattiness" = 30)
	action_mults = list("close_in" = 0.7, "move_to_cover" = 1.1)
