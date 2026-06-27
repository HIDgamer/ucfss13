/datum/action/human_action/synth_bracer/tactical_map
	name = "View Tactical Map"
	action_icon_state = "minimap"
	human_adaptable = TRUE

/datum/action/human_action/synth_bracer/tactical_map/action_activate()
	..()
	if(COOLDOWN_FINISHED(synth_bracer, sound_cooldown))
		COOLDOWN_START(synth_bracer, sound_cooldown, 5 SECONDS)
		playsound(synth_bracer, 'sound/machines/terminal_processing.ogg', 35, TRUE)
	GLOB.tacmap_viewer.tgui_interact(usr)
