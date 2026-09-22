/**
 * Asynchronously sends a message to TGS chat channels.
 *
 * message - The [/datum/tgs_message_content] to send.
 * channel_tag - Required. If "", the message with be sent to all connected (Game-type for TGS3) channels. Otherwise, it will be sent to TGS4 channels with that tag (Delimited by ','s).
 * admin_only - Determines if this communication can only be sent to admin only channels.
 */
/proc/send2chat(datum/tgs_message_content/message, channel_tag, admin_only = FALSE)
	set waitfor = FALSE
	if(channel_tag == null || !world.TgsAvailable())
		return

	var/datum/tgs_version/version = world.TgsVersion()
	if(channel_tag == "" || version.suite == 3)
		world.TgsTargetedChatBroadcast(message, admin_only)
		return

	var/list/channels_to_use = list()
	for(var/I in world.TgsChatChannelInfo())
		var/datum/tgs_chat_channel/channel = I
		var/list/applicable_tags = splittext(channel.custom_tag, ",")
		if((!admin_only || channel.is_admin_channel) && (channel_tag in applicable_tags))
			channels_to_use += channel

	if(length(channels_to_use))
		world.TgsChatBroadcast(message, channels_to_use)

/**
 * Builds a round-alert chat message with a rich embed (title/colour/fields/timestamp/footer)
 * instead of a single plain-text line - used by the round-restarted/round-started/round-completed
 * alerts (mapping.dm, world.dm). text is the plain-text fallback (also where a role mention, if
 * any, belongs - Discord only reliably pings from the top-level message text, not from inside an
 * embed) for chat providers that don't render embeds at all (TGS's own doc comment on
 * /datum/tgs_message_content/var/embed: "Not supported on all chat providers").
 */
/proc/build_round_alert_message(text, title, colour, list/datum/tgs_chat_embed/field/fields)
	var/datum/tgs_message_content/message = new(text)
	var/datum/tgs_chat_embed/structure/embed = new()
	embed.title = title
	embed.colour = colour
	embed.timestamp = time2text(world.timeofday, "YYYY-MM-DD hh:mm:ss")
	embed.footer = new(CONFIG_GET(string/servername) || "SS13")
	if(fields)
		embed.fields = fields
	message.embed = embed
	return message

/**
 * Sends a message to TGS admin chat channels.
 *
 * category - The category of the mssage.
 * message - The message to send.
 */
/proc/send2adminchat(category, message, embed_links = FALSE)
	category = replacetext(replacetext(category, "\proper", ""), "\improper", "")
	message = replacetext(replacetext(message, "\proper", ""), "\improper", "")
	if(!embed_links)
		message = GLOB.has_discord_embeddable_links.Replace(replacetext(message, "`", ""), " ```$1``` ")
	world.TgsTargetedChatBroadcast("[category] | [message]", TRUE)
