/datum/computer_message
	var/sender_address
	var/recipient_address
	var/subject
	var/body
	var/sent_at
	var/read = FALSE
	/// Pre-seeded lore content vs. player-sent mail - display styling only, not behavior.
	var/system = FALSE
