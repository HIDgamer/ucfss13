// Pallets (code/game/objects/structures/crates_lockers/pallets.dm) and weapon/ammo racks
// (code/game/machinery/auto_rack.dm), both ported from Neroid-Sector/LV-254-2.0. Both
// self-fill/self-stock on spawn, so no `contains` list is needed - the containertype alone
// arrives already loaded.

/datum/supply_packs/pallet_standard
	name = "pallet of supplies"
	cost = 40
	containertype = /obj/structure/pallet/standard
	containername = "pallet of supplies"
	group = "Supplies"

/datum/supply_packs/pallet_med
	name = "pallet of medical supplies"
	cost = 60
	containertype = /obj/structure/pallet/med
	containername = "pallet of medical supplies"
	group = "Supplies"

/datum/supply_packs/pallet_engi
	name = "pallet of engineering supplies"
	cost = 60
	containertype = /obj/structure/pallet/engi
	containername = "pallet of engineering supplies"
	group = "Supplies"

/datum/supply_packs/pallet_food
	name = "pallet of food supplies"
	cost = 30
	containertype = /obj/structure/pallet/food
	containername = "pallet of food supplies"
	group = "Supplies"

/datum/supply_packs/pallet_weapon
	name = "pallet of weapon crates"
	cost = 80
	containertype = /obj/structure/pallet/weapon
	containername = "pallet of weapon crates"
	group = "Supplies"

/datum/supply_packs/pallet_ammo_mk1
	name = "pallet of MK1 HEAP magazines"
	cost = 70
	containertype = /obj/structure/pallet/ammo_mk1
	containername = "pallet of MK1 HEAP magazines"
	group = "Supplies"

/datum/supply_packs/rack_m41a_mk1
	name = "M41A MK1 rifle rack"
	cost = 150
	containertype = /obj/structure/machinery/auto_rack/m41a_mk1
	containername = "M41A MK1 rifle rack"
	group = "Supplies"

/datum/supply_packs/rack_m39
	name = "M39 submachinegun rack"
	cost = 120
	containertype = /obj/structure/machinery/auto_rack/m39
	containername = "M39 submachinegun rack"
	group = "Supplies"

/datum/supply_packs/rack_m4ra
	name = "M4RA battle rifle rack"
	cost = 150
	containertype = /obj/structure/machinery/auto_rack/m4ra
	containername = "M4RA battle rifle rack"
	group = "Supplies"

/datum/supply_packs/rack_mk221
	name = "MK221 combat shotgun rack"
	cost = 130
	containertype = /obj/structure/machinery/auto_rack/mk221
	containername = "MK221 combat shotgun rack"
	group = "Supplies"

/datum/supply_packs/rack_mk1_heap
	name = "MK1 HEAP magazine rack"
	cost = 100
	containertype = /obj/structure/machinery/auto_rack/mk1_heap
	containername = "MK1 HEAP magazine rack"
	group = "Supplies"

/datum/supply_packs/rack_m4ra_heap
	name = "M4RA HEAP magazine rack"
	cost = 100
	containertype = /obj/structure/machinery/auto_rack/m4ra_heap
	containername = "M4RA HEAP magazine rack"
	group = "Supplies"

/datum/supply_packs/rack_m39_heap
	name = "M39 HEAP magazine rack"
	cost = 100
	containertype = /obj/structure/machinery/auto_rack/m39_heap
	containername = "M39 HEAP magazine rack"
	group = "Supplies"

/datum/supply_packs/rack_buckshot
	name = "buckshot tin rack"
	cost = 90
	containertype = /obj/structure/machinery/auto_rack/buckshot
	containername = "buckshot tin rack"
	group = "Supplies"

/datum/supply_packs/rack_shotgun_slugs
	name = "slug tin rack"
	cost = 90
	containertype = /obj/structure/machinery/auto_rack/shotgun_slugs
	containername = "slug tin rack"
	group = "Supplies"

/datum/supply_packs/rack_beanbag
	name = "beanbag tin rack"
	cost = 90
	containertype = /obj/structure/machinery/auto_rack/beanbag
	containername = "beanbag tin rack"
	group = "Supplies"

/datum/supply_packs/rack_smartgun_ammo
	name = "smartgun ammo drum rack"
	cost = 110
	containertype = /obj/structure/machinery/auto_rack/smartgun_ammo
	containername = "smartgun ammo drum rack"
	group = "Supplies"
