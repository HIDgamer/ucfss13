/// Every voice bank by id
GLOBAL_LIST_INIT(human_ai_voices, init_human_ai_voices())

/proc/init_human_ai_voices()
	var/list/banks = list()
	for(var/voice_type in subtypesof(/datum/human_ai_voice))
		var/datum/human_ai_voice/bank = new voice_type
		if(!bank.id)
			qdel(bank)
			continue
		banks[bank.id] = bank
	return banks

/// The bank that speaks for a faction
/proc/get_human_ai_voice(faction)
	RETURN_TYPE(/datum/human_ai_voice)
	var/voice_id
	switch(faction)
		if(FACTION_MARINE, FACTION_TWE)
			voice_id = "marine"
		if(FACTION_UPP)
			voice_id = "upp"
		if(FACTION_PMC, FACTION_WY, FACTION_HYPERDYNE, FACTION_WY_DEATHSQUAD, FACTION_CONTRACTOR)
			voice_id = "corporate"
		if(FACTION_CLF, FACTION_PIRATE, FACTION_MERCENARY, FACTION_FREELANCER, FACTION_DUTCH)
			voice_id = "rebel"
		if(FACTION_MARSHAL, FACTION_NSPA, FACTION_PAP)
			voice_id = "police"
		if(FACTION_COLONIST, FACTION_SURVIVOR, FACTION_NEUTRAL)
			voice_id = "civilian"
	return GLOB.human_ai_voices[voice_id] || GLOB.human_ai_voices["generic"]

/**
 * The lines a faction's people say. A bank holds only what is special to it, anything it lacks comes from the generic bank.
 * %dir% in a line is replaced by the compass direction of what was seen.
 */
/datum/human_ai_voice
	/// Unique key, empty leaves the type abstract
	var/id
	/// Kind of expression to the lines it can be said with
	var/list/lines = list()
	/// Personality id to kind to lines that suit that nature, mixed in with the bank's own half of the time
	var/list/flavor = list()
	/// Small talk, each entry is an opener followed by the answer
	var/list/convos = list()

/datum/human_ai_voice/proc/line(kind, personality_id)
	var/list/pool
	var/list/styled = flavor[personality_id]
	if(styled)
		pool = styled[kind]
	if(!length(pool) || prob(50))
		pool = lines[kind]
	if(!length(pool) && id != "generic")
		var/datum/human_ai_voice/fallback = GLOB.human_ai_voices["generic"]
		pool = fallback.lines[kind]
	return length(pool) ? pick(pool) : null

/datum/human_ai_voice/proc/small_talk()
	var/list/pool = length(convos) ? convos : null
	if(!pool && id != "generic")
		var/datum/human_ai_voice/fallback = GLOB.human_ai_voices["generic"]
		pool = fallback.convos
	return length(pool) ? pick(pool) : null

/datum/human_ai_voice/generic
	id = "generic"
	lines = list(
		"contact" = list("Contact, %dir%!", "Enemy %dir%!", "Hostile to the %dir%!", "I've got movement, %dir%!"),
		"xeno" = list("Xeno, %dir%!", "Xenomorph! %dir%!", "Bugs! %dir%!", "Hive-things, %dir%!"),
		"reload" = list("Reloading!", "Changing mag!", "Reloading, hold on!", "Mag change!"),
		"cover_me" = list("Cover me, I'm reloading!", "Reloading, someone cover me!", "Need cover, reloading!"),
		"frag" = list("Frag out!", "Grenade!", "Fire in the hole!", "Throwing a frag!"),
		"flash" = list("Flash out!", "Flashbang, eyes down!", "Flash!"),
		"smoke" = list("Smoke out!", "Popping smoke!", "Smoke, smoke!"),
		"pain" = list("Argh!", "I'm hit!", "Ugh!", "That hurt!"),
		"man_down" = list("Man down!", "We've got a man down!", "Someone's hit!", "They got one of us!"),
		"medic" = list("Medic!", "I need a medic here!", "Medic, over here!", "Get me a medic!"),
		"taking_fire" = list("Taking fire!", "They're shooting at us!", "Get down, incoming fire!", "Shots fired!"),
		"fear" = list("Get away from me!", "I can't do this!", "No, no, no!", "Run!"),
		"challenge" = list("Hands where I can see them!", "Drop the weapon!", "Stop right there!", "Put it down, now!"),
		"warn" = list("Last warning, drop it!", "I will fire, put the weapon down!", "Don't make me shoot you!", "Final warning!"),
		"hostile" = list("Weapon up, hostile!", "He's hostile, engage!", "Open fire!", "That's a threat, engaging!"),
		"surrender" = list("Don't shoot! I give up!", "I surrender! Please!", "Okay, okay, I'm done!", "Don't shoot, don't shoot!"),
		"greet" = list("Hey there.", "Morning.", "Good to see a friendly face.", "Hello."),
		"clear" = list("Clear.", "Area's clear.", "All clear here.", "Looks clear."),
		"kill" = list("Target down.", "Got one.", "Hostile down.", "He's down."),
		"taunt" = list("Stay down.", "Should've stayed home.", "That's what you get.", "Next."),
		"battle_cry" = list("Keep it tight!", "Stay sharp!", "Push on!", "Hold your fire lanes!"),
		"idle" = list("Quiet out here.", "Nothing to report.", "I could use some coffee.", "Long shift."),
		"refuse" = list("No way, that's suicide!", "You can't be serious!", "I'm not doing that!", "Not a chance!"),
		"ack" = list("Copy.", "Roger.", "On it.", "Understood."),
		"fall_back" = list("Falling back!", "Pulling back, cover us!", "Back, back, fall back!", "We're moving back!"),
		"moving" = list("Moving!", "Going round!", "Flanking, cover me!", "On the move!"),
		"explosion" = list("Explosion!", "What was that blast?", "Incoming!", "That was close!"),
		"rally" = list("Hold the line!", "Stay with me!", "Keep it together!", "Steady, steady!"),
		"watch_fire" = list("Watch your fire!", "Hey, I'm on your side!", "Friendly! Check your fire!", "Careful, that's a friendly!"),
		"backup" = list("Contact %dir% in %area%, need backup!", "Engaged in %area%, hostiles %dir%, send help!", "Taking fire in %area%, %dir%, I need backup!", "Under attack in %area%, enemy %dir%, backup now!"),
	)
	convos = list(
		list("Did you eat yet?", "Not yet, the mess was out of everything good."),
		list("You hear anything on the net?", "Nothing, dead quiet since the last check."),
		list("Think it'll stay quiet tonight?", "It never does."),
		list("My boots are killing me.", "Mine too. Worst posting I've had."),
		list("How long till we rotate?", "Another few days, if command remembers us."),
	)

/datum/human_ai_voice/marine
	id = "marine"
	lines = list(
		"contact" = list("Contact, %dir%!", "Tango, %dir%!", "Enemy in sight, %dir%!"),
		"reload" = list("Reloading!", "Mag out, reloading!", "Changing mags!"),
		"frag" = list("Frag out!", "Grenade, get down!", "Fire in the hole!"),
		"man_down" = list("Man down!", "Marine down!", "We've got a Marine down!"),
		"medic" = list("Corpsman up!", "Doc, I need a corpsman!", "Medic!"),
		"fall_back" = list("Fall back, fall back!", "Pull back to the line!", "Bounding back, cover us!"),
		"kill" = list("Hostile down.", "Splash one.", "Got him."),
		"clear" = list("Clear.", "Sector clear.", "Nothing left standing."),
		"ack" = list("Roger that.", "Copy, Marines.", "Aye, on it."),
	)
	flavor = list(
		"professional" = list("contact" = list("Contact, %dir%, engaging.", "Enemy %dir%, distance noted, engaging."), "challenge" = list("US Colonial Marines, drop your weapon!", "Hands up, weapon on the ground!")),
		"ruthless" = list("taunt" = list("Semper fi, scumbag.", "Welcome to the Corps."), "kill" = list("Another one for the count.")),
		"zealot" = list("battle_cry" = list("For the Corps!", "Oorah!", "No retreat, no surrender!")),
		"reckless" = list("battle_cry" = list("Let's go, let's go!", "Come get some!")),
	)
	convos = list(
		list("Chow was awful today.", "Every day, Marine."),
		list("You think the old man knows what he's doing?", "Doesn't matter, we do the job anyway."),
	)

/datum/human_ai_voice/upp
	id = "upp"
	lines = list(
		"contact" = list("Enemy, %dir%!", "Contact, comrades, %dir%!", "Target %dir%!"),
		"reload" = list("Reloading!", "Magazine!", "Changing magazine, cover!"),
		"frag" = list("Grenade!", "Granata out!", "Throwing grenade!"),
		"man_down" = list("Comrade down!", "Soldier down!", "They hit one of us!"),
		"medic" = list("Medic! Medic!", "I need a medic, comrade!", "Wounded here!"),
		"fall_back" = list("Fall back to the line!", "Retreat, retreat!", "Pull back, regroup!"),
		"challenge" = list("Drop your weapon, comrade!", "Stop! Hands up!", "Halt!"),
		"kill" = list("Enemy neutralised.", "One less.", "Target down."),
		"ack" = list("Understood.", "Da, copy.", "Acknowledged."),
	)
	flavor = list(
		"zealot" = list("battle_cry" = list("For the Union!", "Glory to the motherland!", "Forward, for the people!")),
		"professional" = list("contact" = list("Contact, %dir%. Engaging on my command.")),
	)
	convos = list(
		list("The tea is cold again.", "Cold tea is better than no tea."),
		list("Do you think we will be home for the holidays?", "Keep dreaming, comrade."),
	)

/datum/human_ai_voice/corporate
	id = "corporate"
	lines = list(
		"contact" = list("Contact, %dir%. Engaging.", "Hostiles, %dir%!", "Target acquired, %dir%."),
		"reload" = list("Reloading.", "Mag change.", "Reloading, cover."),
		"man_down" = list("Operator down!", "Man down, call it in!", "We lost one!"),
		"medic" = list("Need a medic!", "Medical assistance, now!", "Get a medic over here!"),
		"fall_back" = list("Withdrawing, cover fire!", "Pulling back, protect the asset!", "Fall back to the fallback point!"),
		"challenge" = list("This is private property, drop your weapon!", "Security! Put the weapon down!"),
		"kill" = list("Target neutralised.", "Threat eliminated.", "Contact down."),
		"ack" = list("Copy that.", "Understood, proceeding.", "Affirmative."),
	)
	flavor = list(
		"ruthless" = list("taunt" = list("Consider it a liquidation.", "Nothing personal. Company policy."), "kill" = list("Asset secured. Witness removed.")),
		"professional" = list("challenge" = list("Weyland-Yutani security, stand down!")),
	)
	convos = list(
		list("My bonus is going to be gone after this.", "If you get a bonus at all."),
		list("They don't pay enough for this.", "They never do."),
	)

/datum/human_ai_voice/rebel
	id = "rebel"
	lines = list(
		"contact" = list("They're here, %dir%!", "Enemy, %dir%! Get them!", "Corporate dogs, %dir%!"),
		"reload" = list("Reloading!", "Out of ammo, reloading!", "Hang on, new mag!"),
		"frag" = list("Grenade out!", "Boom incoming!", "Take this!"),
		"man_down" = list("They got one of ours!", "Man down! Man down!", "Damn it, we lost someone!"),
		"medic" = list("Anyone got a medkit?!", "I'm hit, help me!", "Medic, somebody!"),
		"fall_back" = list("Fall back, fall back!", "Retreat! Live to fight tomorrow!", "Get out of here, move!"),
		"challenge" = list("Hold it right there!", "Don't move!", "Freeze!"),
		"kill" = list("One for the cause.", "Got him!", "Down he goes."),
		"ack" = list("Yeah, got it.", "On it.", "Right."),
	)
	flavor = list(
		"zealot" = list("battle_cry" = list("For the colonies!", "Freedom or death!", "No more corporate chains!")),
		"hostile" = list("taunt" = list("This is our home!", "Should've stayed off our planet.")),
		"reckless" = list("battle_cry" = list("Burn it all down!", "Come on, come on!")),
	)
	convos = list(
		list("Think we'll win this?", "We'd better, we've got nowhere else to go."),
		list("Got any smokes left?", "Last pack went three days ago."),
	)

/datum/human_ai_voice/police
	id = "police"
	lines = list(
		"contact" = list("Suspect, %dir%!", "Armed suspect, %dir%!", "Contact, %dir%, stay behind cover!"),
		"man_down" = list("Officer down!", "Officer down, call it in!", "We have an officer down!"),
		"medic" = list("I need medical here!", "Medic, officer down!", "Get a medic, now!"),
		"challenge" = list("Police! Drop your weapon!", "Hands where I can see them!", "Colonial Marshals, don't move!"),
		"warn" = list("Last warning, drop the weapon!", "Drop it or I will use force!", "Final warning, put it down!"),
		"hostile" = list("Suspect is armed and dangerous, engaging!", "Deadly force authorised!", "Shots fired, shots fired!"),
		"kill" = list("Suspect down.", "Threat neutralised.", "Suspect is down, secure the scene."),
		"clear" = list("Scene secure.", "Clear, area secure.", "All clear, stand by."),
		"ack" = list("Copy, dispatch.", "Understood.", "Moving to comply."),
	)
	flavor = list(
		"professional" = list("challenge" = list("Police! You are ordered to put the weapon on the ground now!")),
		"friendly" = list("challenge" = list("Hey, easy now, put the gun down so we can talk.", "Friend, please lower the weapon.")),
	)
	convos = list(
		list("Quiet shift so far.", "Don't jinx it."),
		list("Paperwork's going to bury us.", "It always does."),
	)

/datum/human_ai_voice/civilian
	id = "civilian"
	lines = list(
		"contact" = list("There's something out there, %dir%!", "Over there, %dir%!", "Look, %dir%!"),
		"xeno" = list("Monsters! %dir%!", "What is that thing?! %dir%!", "Oh god, %dir%!"),
		"frag" = list("Oh no, grenade!", "Get down!", "Run!"),
		"man_down" = list("Oh my god, he's down!", "Somebody help him!", "He's been hit!"),
		"medic" = list("Help! Please, help!", "Is there a doctor?!", "Somebody help me!"),
		"fear" = list("Please, don't hurt me!", "I just want to go home!", "Leave me alone!", "No, please!"),
		"surrender" = list("Don't shoot, I'm unarmed!", "Please, I'm just a worker!", "I give up, I give up!"),
		"challenge" = list("Stay back!", "Who are you?!", "Don't come any closer!"),
		"greet" = list("Hello? Are you here to help?", "Thank goodness, someone's here.", "Hi, are you with the Marines?"),
		"idle" = list("This place gives me the creeps.", "I wish the shift was over.", "Did you hear something?"),
		"refuse" = list("I'm not going out there!", "No, I can't!", "Are you insane?!"),
		"ack" = list("Okay, okay.", "If you say so.", "Alright."),
		"fall_back" = list("Get out of here!", "Everybody run!", "Back inside, quickly!"),
	)
	flavor = list(
		"skittish" = list("fear" = list("I don't want to die!", "Oh god, oh god, oh god!")),
		"friendly" = list("greet" = list("Oh, thank goodness, are you hurt?", "Hi! Stay safe out there.")),
	)
	convos = list(
		list("Do you think someone's coming for us?", "They said the Marines were on the way."),
		list("I haven't slept in two days.", "None of us have."),
		list("What was that noise?", "Probably the generators again. Probably."),
	)
