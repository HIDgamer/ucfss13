
// Personal Computer - a real, addressed, read/unread-tracked mail system between every instance
// of this console. Previously just a static, read-only display of pre-written lore flavor text
// with no real sender/recipient - that content is preserved below as pre-seeded "SYSTEM" mail.

GLOBAL_LIST_EMPTY_TYPED(personal_computers, /obj/structure/machinery/computer/emails)

/obj/structure/machinery/computer/emails
	name = "Personal Computer"
	desc = "A personal computer used to send and receive messages."
	icon = 'icons/obj/structures/machinery/computer.dmi'
	icon_state = "terminal1"
	/// The type of pre-seeded lore emails this computer shows on spawn, e.g. USCM flavor mail on the Almayer.
	var/email_type = /datum/fluff_email/almayer
	/// Messages can only be sent between computers sharing this faction.
	var/faction = FACTION_MARINE
	/// This computer's own address, other computers message it at. Defaults to its area name, de-duplicated.
	var/computer_address
	var/list/datum/computer_message/inbox = list()
	var/ui_theme = "ntos"

/obj/structure/machinery/computer/emails/Initialize()
	. = ..()
	register_computer_address()
	seed_fluff_messages()
	GLOB.personal_computers += src

/obj/structure/machinery/computer/emails/Destroy()
	GLOB.personal_computers -= src
	QDEL_LIST(inbox)
	return ..()

/obj/structure/machinery/computer/emails/proc/register_computer_address()
	var/area/current_area = get_area(src)
	var/base = sanitize_area(current_area ? current_area.name : name)
	var/address = base
	var/suffix = 1
	while(address_taken(address))
		suffix++
		address = "[base] ([suffix])"
	computer_address = address

/obj/structure/machinery/computer/emails/proc/address_taken(address)
	for(var/obj/structure/machinery/computer/emails/other as anything in GLOB.personal_computers)
		if(other != src && other.computer_address == address)
			return TRUE
	return FALSE

/obj/structure/machinery/computer/emails/proc/seed_fluff_messages()
	var/list/pool = typesof(email_type) - email_type
	var/amount = rand(2, 4)
	for(var/i in 1 to amount)
		var/path = pick_n_take(pool)
		var/datum/fluff_email/fluff = new path()

		var/datum/computer_message/message = new
		message.sender_address = "SYSTEM"
		message.recipient_address = computer_address
		message.subject = fluff.title
		message.body = fluff.entry_text
		message.sent_at = world.time
		message.read = FALSE
		message.system = TRUE
		inbox += message

		qdel(fluff)

/obj/structure/machinery/computer/emails/proc/notify_new_mail()
	playsound(src, 'sound/machines/pda_ping.ogg', 15, TRUE)

// tgui boilerplate \\

/obj/structure/machinery/computer/emails/attack_hand(mob/user)
	if(..())
		return
	tgui_interact(user)

/obj/structure/machinery/computer/emails/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "PersonalComputer", name)
		ui.open()

/obj/structure/machinery/computer/emails/ui_static_data(mob/user)
	var/list/data = list()
	data["theme"] = ui_theme
	data["own_address"] = computer_address
	return data

/obj/structure/machinery/computer/emails/ui_data(mob/user)
	var/list/data = list()

	var/list/messages = list()
	for(var/datum/computer_message/message in inbox)
		messages += list(list(
			"ref" = REF(message),
			"sender" = message.sender_address,
			"subject" = message.subject,
			"sent_at" = message.sent_at,
			"read" = message.read,
			"system" = message.system,
		))
	data["messages"] = messages
	data["worldtime"] = world.time

	var/list/recipient_addresses = list()
	for(var/obj/structure/machinery/computer/emails/other as anything in GLOB.personal_computers)
		if(other != src && other.faction == faction)
			recipient_addresses += other.computer_address
	data["recipient_addresses"] = recipient_addresses

	return data

// tgui interact \\

/obj/structure/machinery/computer/emails/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/user = ui.user

	switch(action)
		if("open_message")
			var/datum/computer_message/message = locate(params["ref"]) in inbox
			if(!message)
				return
			message.read = TRUE
			. = TRUE

		if("delete_message")
			var/datum/computer_message/message = locate(params["ref"]) in inbox
			if(!message)
				return
			inbox -= message
			qdel(message)
			. = TRUE

		if("rename")
			var/new_address = sanitize_area(copytext(params["address"], 1, 42))
			if(!new_address)
				return
			if(address_taken(new_address))
				to_chat(user, SPAN_WARNING("That address is already in use."))
				return
			computer_address = new_address
			. = TRUE

		if("send")
			var/recipient_address = params["recipient"]
			var/subject = sanitize_text(params["subject"], "")
			var/html = params["html"]
			if(!recipient_address || !html)
				return

			var/obj/structure/machinery/computer/emails/target
			for(var/obj/structure/machinery/computer/emails/other as anything in GLOB.personal_computers)
				if(other.computer_address == recipient_address && other.faction == faction)
					target = other
					break
			if(!target)
				to_chat(user, SPAN_WARNING("No computer found at that address."))
				return

			html = sanitize_paper_html(html, FALSE)
			html = resolve_paper_placeholders(html, user)

			var/datum/computer_message/message = new
			message.sender_address = computer_address
			message.recipient_address = recipient_address
			message.subject = length(subject) ? subject : "(No subject)"
			message.body = html
			message.sent_at = world.time
			message.read = FALSE
			message.system = FALSE
			target.inbox += message
			target.notify_new_mail()
			. = TRUE

// end tgui \\
