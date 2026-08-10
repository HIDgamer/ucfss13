/datum/loadout_picker/ui_static_data(mob/user)
	. = ..()

	.["categories"] = list()
	for(var/category in GLOB.gear_datums_by_category)
		var/list/datum/gear/gears = GLOB.gear_datums_by_category[category]

		var/items = list()

		for(var/gear_key as anything in gears)
			var/datum/gear/gear = gears[gear_key]
			items += list(
				list("name" = gear.display_name, "cost" = gear.cost, "icon" = gear.gear_icon, "icon_state" = gear.gear_icon_state)
			)

		.["categories"] += list(
			list("name" = category, "items" = items)
		)

	.["max_points"] = MAX_GEAR_COST

/datum/loadout_picker/ui_data(mob/user)
	. = ..()

	var/datum/preferences/prefs = user.client?.prefs
	if(!prefs)
		return

	var/points = 0

	.["loadout"] = list()

	for(var/item in prefs.gear)
		var/datum/gear/gear = GLOB.gear_datums_by_name[item]
		// Defensive: saved prefs can reference gear that's since been renamed/removed — skip
		// instead of crashing ui_data() outright, which takes the whole picker down for anyone
		// with a stale loadout pick.
		if(!gear)
			continue
		points += gear.cost

		.["loadout"] += list(
			list("name" = gear.display_name, "cost" = gear.cost, "icon" = gear.gear_icon, "icon_state" = gear.gear_icon_state)
		)

	.["points"] = points

/datum/loadout_picker/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()

	var/datum/preferences/prefs = ui.user.client?.prefs
	if(!prefs)
		return

	switch(action)
		if("add")
			var/datum/gear/gear = GLOB.gear_datums_by_name[params["name"]]
			if(!istype(gear))
				return

			var/total_cost = 0
			for(var/gear_name in prefs.gear)
				var/datum/gear/owned_gear = GLOB.gear_datums_by_name[gear_name]
				total_cost += owned_gear.cost

			total_cost += gear.cost
			if(total_cost > MAX_GEAR_COST)
				return

			prefs.gear += gear.display_name

		if("remove")
			var/datum/gear/gear = GLOB.gear_datums_by_name[params["name"]]
			if(!istype(gear))
				return

			prefs.gear -= gear.display_name

		if("clear")
			prefs.gear = list()

	// Refreshes the live preview instead of the legacy popup.
	prefs.update_preview_icon()
	return TRUE

/datum/loadout_picker/tgui_interact(mob/user, datum/tgui/ui)
	. = ..()

	ui = SStgui.try_update_ui(user, src, ui)

	if(!ui)
		ui = new(user, src, "LoadoutPicker", "Loadout Picker")
		ui.open()
		ui.set_autoupdate(FALSE)

	winset(user, ui.window.id, "focus=true")

/datum/loadout_picker/ui_state(mob/user)
	return GLOB.always_state
