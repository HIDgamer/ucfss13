/// One enemy a brain knows about, seen or remembered
/datum/ai_contact
	var/datum/weakref/subject_ref
	var/turf/last_turf
	var/first_time = 0
	var/last_time = 0
	/// How well the subject has been made out, 1 means identified
	var/notice = 0
	/// Falls while the subject is out of sight, 0 and the contact is dropped
	var/confidence = 1
	var/visible = FALSE
	var/threat = 0
	var/next_report = 0
	/// The marker over the head that was last shown for this contact, so that each is shown once
	var/cue_stage = 0

/datum/ai_contact/Destroy()
	subject_ref = null
	last_turf = null
	return ..()

/datum/ai_contact/proc/get_subject()
	return subject_ref?.resolve()

/datum/ai_contact/proc/identified()
	return notice >= 1

/datum/human_ai_brain/proc/get_contact(mob/living/subject)
	RETURN_TYPE(/datum/ai_contact)
	return contacts[REF(subject)]

/datum/human_ai_brain/proc/remove_contact(mob/living/subject)
	var/datum/ai_contact/contact = contacts[REF(subject)]
	if(!contact)
		return
	contacts -= REF(subject)
	qdel(contact)

/// Creates the contact for a subject or returns the one that exists, null when the list is full of contacts in view and force is off
/datum/human_ai_brain/proc/ensure_contact(mob/living/subject, force = FALSE)
	var/key = REF(subject)
	var/datum/ai_contact/contact = contacts[key]
	if(contact)
		return contact
	if(length(contacts) >= HAI_MAX_CONTACTS && !drop_weakest_contact(force))
		return null
	contact = new
	contact.subject_ref = WEAKREF(subject)
	contact.first_time = world.time
	contact.last_turf = get_turf(subject)
	contacts[key] = contact
	return contact

/// Frees one slot by dropping the weakest contact, contacts in view are only dropped when force is on
/datum/human_ai_brain/proc/drop_weakest_contact(force = FALSE)
	var/weakest_key
	var/weakest_score = INFINITY
	for(var/key in contacts)
		var/datum/ai_contact/contact = contacts[key]
		if(contact.visible && !force)
			continue
		var/score = contact.confidence + contact.notice
		if(score < weakest_score)
			weakest_score = score
			weakest_key = key
	if(!weakest_key)
		return FALSE
	qdel(contacts[weakest_key])
	contacts -= weakest_key
	return TRUE

/// Marks a subject as clearly seen right now, used when it shoots or hits the body
/datum/human_ai_brain/proc/identify_now(mob/living/subject)
	var/datum/ai_contact/contact = ensure_contact(subject, TRUE)
	contact.notice = 1
	contact.confidence = 1
	contact.visible = TRUE
	contact.last_time = world.time
	contact.last_turf = get_turf(subject)
	contact.threat = assess_threat(subject)
	report_to_squad(subject, contact)
	return contact

/// Forgets contacts that are gone and fades the ones out of sight
/datum/human_ai_brain/proc/decay_contacts(seconds)
	for(var/key in contacts)
		var/datum/ai_contact/contact = contacts[key]
		var/mob/living/subject = contact.get_subject()
		if(!subject || QDELETED(subject) || subject.stat == DEAD)
			contacts -= key
			qdel(contact)
			continue
		if(contact.visible)
			continue
		contact.confidence -= seconds / memory_seconds()
		if(!contact.identified())
			contact.notice = max(0, contact.notice - seconds * HAI_NOTICE_FADE)
		if(contact.confidence <= 0)
			contacts -= key
			qdel(contact)

/// Tells the squad about an enemy that is clearly made out, at most once in a while per enemy
/datum/human_ai_brain/proc/report_to_squad(mob/living/subject, datum/ai_contact/contact)
	if(!squad || !contact.identified() || world.time < contact.next_report)
		return
	contact.next_report = world.time + HAI_CALLOUT_REPEAT
	squad.report_contact(src, subject, contact)

/datum/human_ai_brain/proc/memory_seconds()
	return HAI_CONTACT_MEMORY * (0.7 + personality.trait("alertness") * 0.006)
