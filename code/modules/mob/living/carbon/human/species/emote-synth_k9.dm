/datum/emote/living/carbon/human/synthetic/synth_k9/New()  //K9's are blacklisted from human emotes on emote.dm, we need to not block the new emotes below
	. = ..()

//Synth K9 Emotes
/datum/emote/living/carbon/human/synthetic/synth_k9
	species_type_allowed_typecache = list(/datum/species/synthetic/synth_k9)
	species_type_blacklist_typecache = list()
	keybind_category = CATEGORY_SYNTH_EMOTE
	volume = 75
	/// A general category for the emote, for use in the K9 emote panel. See [code/__DEFINES/emote_panels.dm] for categories.
	var/category = ""
	/// Override text for the emote to be displayed in the K9 emote panel
	var/override_say = ""

//Standard Bark
/datum/emote/living/carbon/human/synthetic/synth_k9/bark
	key = "bark"
	key_third_person = "barks"
	message = "barks."
	category = K9_EMOTE_CATEGORY_BARK
	audio_cooldown = 3 SECONDS
	emote_type = EMOTE_AUDIBLE|EMOTE_VISIBLE

/datum/emote/living/carbon/human/synthetic/synth_k9/bark/get_sound(mob/living/user)
	return pick('sound/voice/barkstrong1.ogg','sound/voice/barkstrong2.ogg','sound/voice/barkstrong3.ogg')

/datum/emote/living/carbon/human/synthetic/synth_k9/bark/run_emote(mob/user, params, type_override, intentional = FALSE)
	. = ..()
	if(. && ishuman(user))
		var/mob/living/carbon/human/H = user
		H.open_mouth()

//Alternate Bark
/datum/emote/living/carbon/human/synthetic/synth_k9/bark_alt
	key = "barkalt"
	key_third_person = "barks"
	message = "barks."
	override_say = "Bark (Alt)"
	category = K9_EMOTE_CATEGORY_BARK
	sound = 'sound/voice/synth_k9/bark_alt.ogg'
	audio_cooldown = 3 SECONDS
	emote_type = EMOTE_AUDIBLE|EMOTE_VISIBLE

/datum/emote/living/carbon/human/synthetic/synth_k9/bark_alt/run_emote(mob/user, params, type_override, intentional = FALSE)
	. = ..()
	if(. && ishuman(user))
		var/mob/living/carbon/human/H = user
		H.open_mouth()

//Threatening Growl
/datum/emote/living/carbon/human/synthetic/synth_k9/growl
	key = "growl"
	key_third_person = "growls"
	message = "growls."
	category = K9_EMOTE_CATEGORY_GROWL
	audio_cooldown = 3 SECONDS
	emote_type = EMOTE_AUDIBLE|EMOTE_VISIBLE

/datum/emote/living/carbon/human/synthetic/synth_k9/growl/get_sound(mob/living/user)
	return pick('sound/voice/growl1.ogg','sound/voice/growl2.ogg','sound/voice/growl3.ogg','sound/voice/growl4.ogg')

/datum/emote/living/carbon/human/synthetic/synth_k9/growl/run_emote(mob/user, params, type_override, intentional = FALSE)
	. = ..()
	if(. && ishuman(user))
		var/mob/living/carbon/human/H = user
		H.open_mouth()

//Bark & Snarl
/datum/emote/living/carbon/human/synthetic/synth_k9/snarl
	key = "snarl"
	key_third_person = "snarls"
	message = "barks and snarls viciously."
	override_say = "Bark & Snarl"
	category = K9_EMOTE_CATEGORY_GROWL
	sound = 'sound/voice/synth_k9/bark_snarl.ogg'
	audio_cooldown = 3 SECONDS
	emote_type = EMOTE_AUDIBLE|EMOTE_VISIBLE

/datum/emote/living/carbon/human/synthetic/synth_k9/snarl/run_emote(mob/user, params, type_override, intentional = FALSE)
	. = ..()
	if(. && ishuman(user))
		var/mob/living/carbon/human/H = user
		H.open_mouth()

//Pain yelps
/datum/emote/living/carbon/human/synthetic/synth_k9/pain1
	key = "painyelp1"
	key_third_person = "whimpers"
	message = "yelps in pain."
	override_say = "Pain (1)"
	category = K9_EMOTE_CATEGORY_PAIN
	sound = 'sound/voice/synth_k9/pain1.ogg'
	audio_cooldown = 3 SECONDS
	emote_type = EMOTE_AUDIBLE|EMOTE_VISIBLE

/datum/emote/living/carbon/human/synthetic/synth_k9/pain2
	key = "painyelp2"
	key_third_person = "whimpers"
	message = "yelps in pain."
	override_say = "Pain (2)"
	category = K9_EMOTE_CATEGORY_PAIN
	sound = 'sound/voice/synth_k9/pain2.ogg'
	audio_cooldown = 3 SECONDS
	emote_type = EMOTE_AUDIBLE|EMOTE_VISIBLE

/datum/emote/living/carbon/human/synthetic/synth_k9/pain3
	key = "painyelp3"
	key_third_person = "whimpers"
	message = "yelps in pain."
	override_say = "Pain (3)"
	category = K9_EMOTE_CATEGORY_PAIN
	sound = 'sound/voice/synth_k9/pain3.ogg'
	audio_cooldown = 3 SECONDS
	emote_type = EMOTE_AUDIBLE|EMOTE_VISIBLE

//Panting
/datum/emote/living/carbon/human/synthetic/synth_k9/panting
	key = "panting"
	key_third_person = "pants"
	message = "pants."
	category = K9_EMOTE_CATEGORY_MISC
	sound = 'sound/voice/synth_k9/panting.ogg'
	audio_cooldown = 3 SECONDS
	emote_type = EMOTE_AUDIBLE|EMOTE_VISIBLE
