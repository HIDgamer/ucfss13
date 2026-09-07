// Server-side allow-list sanitizer for HTML submitted by the rich-text paper/email editors.
//
// The old bracket-markup system was safe by construction: the server alone ever emitted HTML
// tags, and a player's typed text only ever became an escaped text node. The contentEditable
// editor inverts this - the client now composes and submits real HTML - so nothing coming through
// ui_act() can be trusted as-is. This proc is the actual security boundary; the frontend toolbar
// only restricting which buttons are shown is a UX nicety, not a guarantee.
//
// Strategy: walk the submitted string tag-by-tag. Any tag matching one of a small, fixed set of
// known-safe constructs (mirroring exactly what /obj/item/paper/proc/parsepencode() has always
// been able to legitimately produce) is rebuilt from scratch using only validated pieces of it -
// never the original attribute text - and canonicalized. Everything else, including the plain text
// between tags, is dropped down to inert escaped text via html_encode(). <script>/<style> blocks
// are excised (tag and contents) before the general pass since their contents could otherwise
// confuse a naive tag walk.

#define PAPER_SANITIZER_MAX_LEN 8000

/proc/sanitize_paper_html(html, iscrayon = FALSE)
	if(!html)
		return ""
	if(length(html) > PAPER_SANITIZER_MAX_LEN)
		html = copytext(html, 1, PAPER_SANITIZER_MAX_LEN)

	var/static/regex/script_re = regex(@"<script\b[^>]*>[\s\S]*?</script>", "gi")
	var/static/regex/style_re = regex(@"<style\b[^>]*>[\s\S]*?</style>", "gi")
	html = script_re.Replace(html, "")
	html = style_re.Replace(html, "")

	var/list/allowed_plain = list("b", "/b", "/font", "/span")
	if(!iscrayon)
		allowed_plain += list("i", "/i", "u", "/u", "h1", "/h1", "h2", "/h2", "h3", "/h3", \
			"center", "/center", "hr", "br", "ul", "/ul", "li", "/li")

	var/list/allowed_logo_urls = list()
	if(!iscrayon)
		var/datum/asset/asset = get_asset_datum(/datum/asset/simple/paper)
		var/list/mappings = asset.get_url_mappings()
		allowed_logo_urls = list(
			mappings["logo_wy.png"],
			mappings["logo_wy_inv.png"],
			mappings["logo_uscm.png"],
			mappings["logo_upp.png"],
			mappings["logo_cmb.png"],
		)

	var/static/regex/tag_re = regex(@"<[^>]*>", "g")
	var/static/regex/tagname_re = regex(@"^<\s*(/?)\s*([a-zA-Z0-9]+)")
	var/static/regex/font_re = regex(@{"^<font\s+face\s*=\s*["']([^"']*)["']\s+color\s*=\s*["']?([#a-zA-Z0-9]*)["']?"}, "i")
	var/static/regex/img_re = regex(@{"^<img\s+src\s*=\s*["']?([^"'>\s]*)["']?"}, "i")
	var/static/regex/color_re = regex(@"^(#[0-9a-fA-F]{6}|[a-zA-Z]+)$")

	var/result = ""
	var/pos = 1
	while(tag_re.Find(html, pos))
		var/match_start = tag_re.index
		var/match_text = tag_re.match
		result += html_encode(copytext(html, pos, match_start))

		var/replacement = "" // unrecognized tags are dropped outright (their own text was already handled above)
		if(tagname_re.Find(match_text))
			var/is_close = tagname_re.group[1] == "/"
			var/tagname = lowertext(tagname_re.group[2])
			var/full_name = is_close ? "/[tagname]" : tagname

			if(full_name in allowed_plain)
				replacement = "<[full_name]>"
			else if(!is_close && tagname == "span")
				if(findtext(match_text, "paper_field"))
					replacement = "<span class=\"paper_field\">"
				else if(findtext(match_text, "paper_sign_placeholder"))
					replacement = "<span class=\"paper_sign_placeholder\">"
				else if(findtext(match_text, "paper_date_placeholder"))
					replacement = "<span class=\"paper_date_placeholder\">"
			else if(!iscrayon && !is_close && tagname == "font" && font_re.Find(match_text))
				var/face = font_re.group[1]
				var/color = font_re.group[2]
				if((face == "Verdana" || face == "Times New Roman" || face == "Comic Sans MS") && color_re.Find(color))
					replacement = "<font face=\"[face]\" color=\"[color]\">"
			else if(!iscrayon && !is_close && tagname == "img" && img_re.Find(match_text))
				var/src_url = img_re.group[1]
				if(src_url in allowed_logo_urls)
					replacement = "<img src=\"[src_url]\">"

		result += replacement

		var/next_pos = tag_re.next
		if(!next_pos || next_pos <= match_start)
			break // guard against a degenerate/zero-length match looping forever
		pos = next_pos

	result += html_encode(copytext(html, pos))
	return result

// Resolves the placeholder markers the editor inserts for [sign]/[date] into the same text
// parsepencode() would have produced, using whoever actually committed the paper (not whoever
// opened the editor) - mirroring paper.dm's existing signfont/date formatting exactly.
/proc/resolve_paper_placeholders(html, mob/user)
	var/signfont = "Times New Roman" // matches /obj/item/paper's own default signfont

	var/static/regex/sign_re = regex(@{"<span class="paper_sign_placeholder"></span>"}, "g")
	var/static/regex/date_re = regex(@{"<span class="paper_date_placeholder"></span>"}, "g")

	html = sign_re.Replace(html, "<font face=\"[signfont]\"><i>[user ? user.real_name : "Anonymous"]</i></font>")
	html = date_re.Replace(html, "<font face=\"[signfont]\"><i>[time2text(REALTIMEOFDAY, "Day DD Month [GLOB.game_year]")]</i></font>")
	return html
