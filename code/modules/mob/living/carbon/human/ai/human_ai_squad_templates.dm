/**
 * Squads that can be spawned whole: who is in each and what each one carries, by the name of the equipment preset. The first member is the leader. An admin arms one in the NPC
 * command panel and clicks where it is to appear, which is faster and truer to how the factions field their people than spawning one equipment preset at a time.
 */
GLOBAL_LIST_INIT(human_ai_squad_templates, list(
	"uscm_fireteam" = list("name" = "USCM fireteam", "members" = list(
		list("job" = "USCM Squad Leader (Equipped)", "count" = 1),
		list("job" = "USCM Squad Rifleman (Equipped)", "count" = 3),
		list("job" = "USCM Squad Smartgunner (Equipped)", "count" = 1),
		list("job" = "USCM Squad Hospital Corpsman (Equipped)", "count" = 1),
	)),
	"uscm_heavy" = list("name" = "USCM heavy section", "members" = list(
		list("job" = "USCM Squad Leader (Equipped)", "count" = 1),
		list("job" = "USCM Squad Rifleman (Equipped)", "count" = 2),
		list("job" = "USCM Squad Weapons Specialist (Equipped)", "count" = 1),
		list("job" = "USCM Squad Smartgunner (Equipped)", "count" = 1),
		list("job" = "USCM Squad Combat Technician (Equipped)", "count" = 1),
	)),
	"upp_squad" = list("name" = "UPP rifle squad", "members" = list(
		list("job" = "UPP Squad Leader", "count" = 1),
		list("job" = "UPP Soldier", "count" = 4),
		list("job" = "UPP Machinegunner", "count" = 1),
		list("job" = "UPP Specialist", "count" = 1),
		list("job" = "UPP Medic", "count" = 1),
	)),
	"pmc_team" = list("name" = "PMC strike team", "members" = list(
		list("job" = "Weyland-Yutani PMC (Leader)", "count" = 1),
		list("job" = "Weyland-Yutani PMC (Standard)", "count" = 3),
		list("job" = "Weyland-Yutani PMC (Gunner)", "count" = 1),
		list("job" = "Weyland-Yutani PMC (Sniper)", "count" = 1),
		list("job" = "Weyland-Yutani PMC (Corporate Medic)", "count" = 1),
	)),
	"clf_cell" = list("name" = "CLF cell", "members" = list(
		list("job" = "CLF Leader", "count" = 1),
		list("job" = "CLF Soldier", "count" = 4),
		list("job" = "CLF Specialist", "count" = 1),
		list("job" = "CLF Engineer", "count" = 1),
		list("job" = "CLF Medic", "count" = 1),
	)),
	"colony_security" = list("name" = "Colony security detail", "members" = list(
		list("job" = "Colonist - Security", "count" = 4),
	)),
))

/// How many people a template has
/proc/human_ai_template_size(list/template)
	var/size = 0
	for(var/list/entry in template["members"])
		size += entry["count"]
	return size
