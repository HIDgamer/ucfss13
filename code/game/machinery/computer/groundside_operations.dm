#define COMMAND_SQUAD "Command"

/obj/structure/machinery/computer/groundside_operations
	name = "groundside operations console"
	desc = "This can be used for various important functions."
	icon_state = "comm"
	req_access = list(ACCESS_MARINE_SENIOR)
	unslashable = TRUE
	unacidable = TRUE

	var/obj/structure/machinery/camera/cam = null
	var/obj/item/camera_holder = null
	var/datum/squad/current_squad = null

	var/minimap_type = MINIMAP_FLAG_USCM

	COOLDOWN_DECLARE(announcement_cooldown)
	var/announcement_title = COMMAND_ANNOUNCE
	var/announcement_faction = FACTION_MARINE
	var/add_pmcs = FALSE
	var/lz_selection = TRUE
	var/has_squad_overwatch = TRUE
	var/faction = FACTION_MARINE
	var/freq = CRYO_FREQ
	var/show_command_squad = FALSE

	var/list/concurrent_users = list()

	var/minimap_flag = MINIMAP_FLAG_USCM
	/// TGUI theme for this console
	var/ui_theme = "crtblue"

/obj/structure/machinery/computer/groundside_operations/Initialize()
	if(SSticker.mode && MODE_HAS_FLAG(MODE_FACTION_CLASH))
		add_pmcs = FALSE
	else if(SSticker.current_state < GAME_STATE_PLAYING)
		RegisterSignal(SSdcs, COMSIG_GLOB_MODE_PRESETUP, PROC_REF(disable_pmc))

	AddComponent(/datum/component/tacmap, has_drawing_tools = TRUE, minimap_flag = minimap_flag, has_update = TRUE)
	return ..()

/obj/structure/machinery/computer/groundside_operations/Destroy()
	QDEL_NULL(cam)
	current_squad = null
	concurrent_users = null
	if(!camera_holder)
		return ..()
	disconnect_holder()
	return ..()

/obj/structure/machinery/computer/groundside_operations/proc/connect_holder(new_holder)
	camera_holder = new_holder
	SEND_SIGNAL(camera_holder, COMSIG_OW_CONSOLE_OBSERVE_START, WEAKREF(src))
	RegisterSignal(camera_holder, COMSIG_BROADCAST_HEAR_TALK, PROC_REF(transfer_talk))
	RegisterSignal(camera_holder, COMSIG_BROADCAST_SEE_EMOTE, PROC_REF(transfer_emote))

/obj/structure/machinery/computer/groundside_operations/proc/disconnect_holder()
	SEND_SIGNAL(camera_holder, COMSIG_OW_CONSOLE_OBSERVE_END, WEAKREF(src))
	UnregisterSignal(camera_holder, COMSIG_BROADCAST_HEAR_TALK)
	UnregisterSignal(camera_holder, COMSIG_BROADCAST_SEE_EMOTE)
	camera_holder = null

/obj/structure/machinery/computer/groundside_operations/proc/disable_pmc()
	if(MODE_HAS_FLAG(MODE_FACTION_CLASH))
		add_pmcs = FALSE
	UnregisterSignal(SSdcs, COMSIG_GLOB_MODE_PRESETUP)

/obj/structure/machinery/computer/groundside_operations/attack_remote(mob/user as mob)
	return attack_hand(user)

/obj/structure/machinery/computer/groundside_operations/attack_hand(mob/user as mob)
	if(..() || !allowed(user) || inoperable())
		return

	tgui_interact(user)

// tgui boilerplate \\

/obj/structure/machinery/computer/groundside_operations/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "GroundsideOperations", name)
		ui.open()

/obj/structure/machinery/computer/groundside_operations/ui_status(mob/user, datum/ui_state/state)
	. = ..()
	if(!allowed(user))
		return UI_CLOSE
	if(inoperable())
		return UI_CLOSE

/obj/structure/machinery/computer/groundside_operations/ui_static_data(mob/user)
	var/list/data = list()
	data["theme"] = ui_theme
	return data

// tgui data \\

/obj/structure/machinery/computer/groundside_operations/ui_data(mob/user)
	var/list/data = list()

	data["isAnnouncementActive"] = COOLDOWN_FINISHED(src, announcement_cooldown)
	data["announcementCooldown"] = COOLDOWN_COMM_MESSAGE
	data["announcementEndTime"] = announcement_cooldown
	data["worldtime"] = world.time

	var/datum/squad/marine/echo/echo_squad = locate() in GLOB.RoleAuthority.squads
	data["hasEchoOption"] = (echo_squad && !echo_squad.active && faction == FACTION_MARINE)

	data["hasLzSelection"] = lz_selection && SSticker.mode && (isnull(SSticker.mode.active_lz) || isnull(SSticker.mode.active_lz.loc))

	data["hasSquadOverwatch"] = has_squad_overwatch
	if(has_squad_overwatch)
		var/list/squad_list = list()
		for(var/datum/squad/S in GLOB.RoleAuthority.squads)
			if(S.active && S.faction == faction)
				squad_list += S.name
		squad_list += COMMAND_SQUAD
		data["squadList"] = squad_list

		data["showCommandSquad"] = show_command_squad
		data["currentSquad"] = current_squad ? current_squad.name : null

		if(show_command_squad)
			get_marine_list_data(data, list(GLOB.marine_leaders[JOB_CO], GLOB.marine_leaders[JOB_XO]) + GLOB.marine_leaders[JOB_SO])
		else if(current_squad)
			get_marine_list_data(data, current_squad.marines_list)

	return data

// end tgui data \\

/obj/structure/machinery/computer/groundside_operations/proc/get_marine_list_data(list/data, list/marine_list)
	var/list/rows = list()

	var/living_count = 0
	var/almayer_count = 0
	var/SSD_count = 0
	var/helmetless_count = 0
	var/total_count = 0

	for(var/X in marine_list)
		if(!X)
			continue
		total_count++
		var/mob_name = "unknown"
		var/mob_state = ""
		var/role = "unknown"
		var/area_name = "???"
		var/mob/living/carbon/human/H
		var/act_sl = ""
		if(ishuman(X))
			H = X
			mob_name = H.real_name
			var/area/A = get_area(H)
			var/turf/M_turf = get_turf(H)
			if(A)
				area_name = sanitize_area(A.name)

			var/obj/item/card/id/card = H.get_idcard()
			if(H.job)
				role = H.job
			else if(card?.rank) //decapitated marine is mindless,
				role = card.rank

			switch(H.stat)
				if(CONSCIOUS)
					mob_state = "Conscious"
					living_count++
				if(UNCONSCIOUS)
					mob_state = "Unconscious"
					living_count++
				else
					continue

			if(!is_ground_level(M_turf.z))
				almayer_count++
				continue
			if(!H.get_camera_holder())
				helmetless_count++
				continue
			if(!H.key || !H.client)
				SSD_count++
				continue
			if(current_squad)
				if(H == current_squad.squad_leader && role != JOB_SQUAD_LEADER)
					act_sl = " (ASL)"

			rows += list(list(
				"name" = mob_name,
				"ref" = REF(H),
				"role" = role,
				"actingSl" = act_sl,
				"state" = mob_state,
				"areaName" = area_name,
			))

	data["marines"] = rows
	data["totalDeployed"] = total_count
	data["livingCount"] = living_count
	data["almayerCount"] = almayer_count
	data["ssdCount"] = SSD_count
	data["helmetlessCount"] = helmetless_count
	return data

// tgui interact \\

/obj/structure/machinery/computer/groundside_operations/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/user = ui.user
	user.set_interaction(src)

	switch(action)
		if("mapview")
			var/datum/component/tacmap/tacmap_component = GetComponent(/datum/component/tacmap)
			tacmap_component.show_tacmap(user)
			. = TRUE

		if("announce")
			var/mob/living/carbon/human/human_user = user
			var/obj/item/card/id/idcard = human_user.get_active_hand()
			var/bio_fail = FALSE
			if(!istype(idcard))
				idcard = human_user.get_idcard()
			if(!idcard)
				bio_fail = TRUE
			else if(!idcard.check_biometrics(human_user))
				bio_fail = TRUE
			if(bio_fail)
				to_chat(human_user, SPAN_WARNING("Biometrics failure! You require an authenticated ID card to perform this action!"))
				return

			if(user.client.prefs.muted & MUTE_IC)
				to_chat(user, SPAN_DANGER("You cannot send Announcements (muted)."))
				return

			if(!COOLDOWN_FINISHED(src, announcement_cooldown))
				to_chat(user, SPAN_WARNING("Please allow at least [COOLDOWN_COMM_MESSAGE*0.1] second\s to pass between announcements."))
				return
			if(announcement_faction != FACTION_MARINE && user.faction != announcement_faction)
				to_chat(user, SPAN_WARNING("Access denied."))
				return

			var/input = html_encode(trim(params["message"], MAX_MESSAGE_LEN))
			if(!input || !COOLDOWN_FINISHED(src, announcement_cooldown) || !(user in dview(1, src)))
				return

			var/signed = null
			if(ishuman(user))
				var/paygrade = get_paygrades(idcard.paygrade, FALSE, human_user.gender)
				signed = "[paygrade] [idcard.registered_name]"

			marine_announcement(input, announcement_title, faction_to_display = announcement_faction, add_PMCs = add_pmcs, signature = signed)
			COOLDOWN_START(src, announcement_cooldown, COOLDOWN_COMM_MESSAGE)
			message_admins("[key_name(user)] has made a command announcement.")
			log_announcement("[key_name(user)] has announced the following: [input]")
			. = TRUE

		if("award")
			open_medal_panel(user, src)
			. = TRUE

		if("select_lz")
			if(!lz_selection || (SSticker.mode && SSticker.mode.active_lz))
				return
			var/new_lz = params["lz"]
			if(new_lz == "lz1")
				SSticker.mode.select_lz(locate(/obj/structure/machinery/computer/shuttle/dropship/flight/lz1))
			else if(new_lz == "lz2")
				SSticker.mode.select_lz(locate(/obj/structure/machinery/computer/shuttle/dropship/flight/lz2))
			else
				return
			. = TRUE

		if("pick_squad")
			if(!has_squad_overwatch)
				return
			var/name_sel = params["squad"]
			if(name_sel == COMMAND_SQUAD)
				show_command_squad = TRUE
				current_squad = null
			else
				var/datum/squad/selected
				for(var/datum/squad/S in GLOB.RoleAuthority.squads)
					if(S.active && S.faction == faction && S.name == name_sel)
						selected = S
						break
				if(!selected)
					return
				show_command_squad = FALSE
				current_squad = selected
			. = TRUE

		if("use_cam")
			if(isRemoteControlling(user))
				to_chat(user, "[icon2html(src, user)] [SPAN_WARNING("Unable to override console camera viewer. Track with camera instead. ")]")
				return
			if(!current_squad && !show_command_squad)
				return
			var/mob/living/carbon/human/cam_target = locate(params["target_ref"])
			if(!cam_target)
				return
			var/obj/item/new_holder = cam_target.get_camera_holder()
			var/obj/structure/machinery/camera/new_cam
			if(new_holder)
				new_cam = new_holder.get_camera()
			if(!new_cam || !new_cam.can_use())
				to_chat(user, "[icon2html(src, user)] [SPAN_WARNING("Searching for camera. No camera found for this marine! Tell your squad to put their cameras on!")]")
			else if(cam && cam == new_cam) //click the camera you're watching a second time to stop watching.
				visible_message("[icon2html(src, viewers(src))] [SPAN_BOLDNOTICE("Stopping camera view of [cam_target].")]")
				for(var/datum/weakref/user_ref in concurrent_users)
					var/mob/concurrent = user_ref.resolve()
					if(!concurrent)
						continue
					concurrent.reset_view(null)
					concurrent.UnregisterSignal(cam, COMSIG_PARENT_QDELETING)
				disconnect_holder()
				cam = null
			else if(user.client.view != GLOB.world_view_size)
				to_chat(user, SPAN_WARNING("You're too busy peering through binoculars."))
			else
				for(var/datum/weakref/user_ref in concurrent_users)
					var/mob/concurrent = user_ref.resolve()
					if(!concurrent)
						continue
					if(cam)
						concurrent.UnregisterSignal(cam, COMSIG_PARENT_QDELETING)
					concurrent.reset_view(new_cam)
					concurrent.RegisterSignal(new_cam, COMSIG_PARENT_QDELETING, TYPE_PROC_REF(/mob, reset_observer_view_on_deletion))
				if(camera_holder)
					disconnect_holder()
				cam = new_cam
				connect_holder(new_holder)
			. = TRUE

		if("activate_echo")
			var/mob/living/carbon/human/human_user = user
			var/obj/item/card/id/idcard = human_user.get_active_hand()
			var/bio_fail = FALSE
			if(!istype(idcard))
				idcard = human_user.get_idcard()
			if(!idcard)
				bio_fail = TRUE
			else if(!idcard.check_biometrics(human_user))
				bio_fail = TRUE
			if(bio_fail)
				to_chat(human_user, SPAN_WARNING("Biometrics failure! You require an authenticated ID card to perform this action!"))
				return

			var/reason = html_encode(trim(params["reason"], MAX_MESSAGE_LEN))
			if(!reason)
				return
			var/datum/squad/marine/echo/echo_squad = locate() in GLOB.RoleAuthority.squads
			if(!echo_squad)
				visible_message(SPAN_BOLDNOTICE("ERROR: Unable to locate Echo Squad database."))
				return
			echo_squad.engage_squad(TRUE)
			message_admins("[key_name(user)] activated Echo Squad for '[reason]'.")
			. = TRUE

	add_fingerprint(user)

// end tgui interact \\

// end tgui \\

/obj/structure/machinery/computer/groundside_operations/on_set_interaction(mob/user)
	if(user.interactee != src)
		user.unset_interaction()
	..()
	if(!isRemoteControlling(user))
		concurrent_users += WEAKREF(user)
		if(cam)
			user.reset_view(cam)
			user.RegisterSignal(cam, COMSIG_PARENT_QDELETING, TYPE_PROC_REF(/mob, reset_observer_view_on_deletion))

/obj/structure/machinery/computer/groundside_operations/on_unset_interaction(mob/user)
	..()

	var/datum/component/tacmap/tacmap_component = GetComponent(/datum/component/tacmap)
	tacmap_component.on_unset_interaction(user)

	if(!isRemoteControlling(user))
		if(cam)
			user.UnregisterSignal(cam, COMSIG_PARENT_QDELETING)
		user.reset_view(null)
		concurrent_users -= WEAKREF(user)

/obj/structure/machinery/computer/groundside_operations/check_eye(mob/user)
	if(user.is_mob_incapacitated(TRUE) || get_dist(user, src) > 1 || user.blinded)
		user.unset_interaction()
	else if(!cam || !cam.can_use())
		for(var/datum/weakref/user_ref in concurrent_users)
			var/mob/concurrent = user_ref.resolve()
			if(!concurrent)
				continue
			if(cam)
				concurrent.UnregisterSignal(cam, COMSIG_PARENT_QDELETING)
			concurrent.reset_view(null)
		if(camera_holder)
			disconnect_holder()
		cam = null

/obj/structure/machinery/computer/groundside_operations/proc/transfer_talk(obj/item/camera, mob/living/sourcemob, message, verb = "says", datum/language/language, italics = FALSE, show_message_above_tv = FALSE)
	SIGNAL_HANDLER
	if(inoperable())
		return
	var/target_zs = SSradio.get_available_tcomm_zs(freq)
	if(!(z == sourcemob.z) && !((z in target_zs) && (sourcemob.z in target_zs)))
		return
	if(show_message_above_tv)
		langchat_speech(message, get_mobs_in_view(7, src), language, sourcemob.langchat_color, FALSE, LANGCHAT_FAST_POP, list(sourcemob.langchat_styles))
	for(var/datum/weakref/user_ref in concurrent_users)
		var/mob/user = user_ref.resolve()
		if(user?.client?.prefs && !user.client.prefs.lang_chat_disabled && !user.ear_deaf && user.say_understands(sourcemob, language))
			sourcemob.langchat_display_image(user)

/obj/structure/machinery/computer/groundside_operations/proc/transfer_emote(obj/item/camera, mob/living/sourcemob, emote, audible = FALSE, show_message_above_tv = FALSE)
	SIGNAL_HANDLER
	if(inoperable())
		return
	var/target_zs = SSradio.get_available_tcomm_zs(freq)
	if(audible && !(z == sourcemob.z) && !((z in target_zs) && (sourcemob.z in target_zs)))
		return
	if(show_message_above_tv)
		langchat_speech(emote, get_mobs_in_view(7, src), skip_language_check = TRUE, animation_style = LANGCHAT_FAST_POP, additional_styles = list("emote"))
	for(var/datum/weakref/user_ref in concurrent_users)
		var/mob/user = user_ref.resolve()
		if(user?.client?.prefs && (user.client.prefs.toggles_langchat & LANGCHAT_SEE_EMOTES) && (!audible || !user.ear_deaf))
			sourcemob.langchat_display_image(user)

/obj/structure/machinery/computer/groundside_operations/upp
	announcement_title = UPP_COMMAND_ANNOUNCE
	announcement_faction = FACTION_UPP
	add_pmcs = FALSE
	lz_selection = FALSE
	has_squad_overwatch = FALSE
	minimap_type = MINIMAP_FLAG_UPP
	freq = UPP_FREQ
	ui_theme = "crtupp"

/obj/structure/machinery/computer/groundside_operations/clf
	announcement_title = CLF_COMMAND_ANNOUNCE
	announcement_faction = FACTION_CLF
	add_pmcs = FALSE
	lz_selection = FALSE
	has_squad_overwatch = FALSE
	minimap_type = MINIMAP_FLAG_CLF
	freq = CLF_FREQ

/obj/structure/machinery/computer/groundside_operations/pmc
	announcement_title = PMC_COMMAND_ANNOUNCE
	announcement_faction = FACTION_PMC
	add_pmcs = TRUE
	lz_selection = FALSE
	has_squad_overwatch = FALSE
	minimap_type = MINIMAP_FLAG_WY
	freq = PMC_FREQ
	ui_theme = "weyland"

/obj/structure/machinery/computer/groundside_operations/arc
	icon = 'icons/obj/vehicles/interiors/arc.dmi'
	icon_state = "groundsideop_computer"

#undef COMMAND_SQUAD
