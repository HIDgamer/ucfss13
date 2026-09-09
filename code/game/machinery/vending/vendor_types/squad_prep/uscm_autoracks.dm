// USCM weapon/ammo racks, ported from Neroid-Sector/LV-254-2.0's uscm_autoracks.dm (see
// code/game/machinery/auto_rack.dm for the base type). A representative core set for a first
// pass - locked/riot/honorguard/empty variants can be added later following this same pattern.
//
// icon_state per subtype matches the real per-weapon states already present in
// icons/obj/structures/machinery/vending.dmi (confirmed directly against the DMI catalog).
// max_stored is capped to match how many numbered frames actually exist for each state, since
// update_icon() (auto_rack.dm) requests "[icon_state]_[count]" and a count past what the sheet
// actually has would just render blank.

/obj/structure/machinery/auto_rack/m41a_mk1
	name = "\improper M41A MK1 rack"
	icon_state = "mk1rack"
	stocked_weapon = /obj/item/weapon/gun/rifle/m41aMK1

/obj/structure/machinery/auto_rack/m39
	name = "\improper M39 submachinegun rack"
	icon_state = "m39rack"
	stocked_weapon = /obj/item/weapon/gun/smg/m39

/obj/structure/machinery/auto_rack/m4ra
	name = "\improper M4RA battle rifle rack"
	icon_state = "m4rarack"
	stocked_weapon = /obj/item/weapon/gun/rifle/m4ra
	max_stored = 3

/obj/structure/machinery/auto_rack/mk221
	name = "\improper MK221 combat shotgun rack"
	icon_state = "mk221rack"
	stocked_weapon = /obj/item/weapon/gun/shotgun/combat

/obj/structure/machinery/auto_rack/mk1_heap
	name = "\improper MK1 HEAP magazine rack"
	icon_state = "mk1_magrack"
	stocked_weapon = /obj/item/ammo_magazine/rifle/m41aMK1/heap
	max_stored = 4

/obj/structure/machinery/auto_rack/m4ra_heap
	name = "\improper M4RA HEAP magazine rack"
	icon_state = "m4ra_magrack"
	stocked_weapon = /obj/item/ammo_magazine/rifle/m4ra/heap
	max_stored = 4

/obj/structure/machinery/auto_rack/m39_heap
	name = "\improper M39 HEAP magazine rack"
	icon_state = "m39_magrack"
	stocked_weapon = /obj/item/ammo_magazine/smg/m39/heap
	max_stored = 4

/obj/structure/machinery/auto_rack/buckshot
	name = "\improper buckshot tin rack"
	icon_state = "buckshot_magrack"
	stocked_weapon = /obj/item/ammo_magazine/shotgun/buckshot
	max_stored = 4

/obj/structure/machinery/auto_rack/shotgun_slugs
	name = "\improper slug tin rack"
	icon_state = "slugs_magrack"
	stocked_weapon = /obj/item/ammo_magazine/shotgun/slugs
	max_stored = 3

/obj/structure/machinery/auto_rack/beanbag
	name = "\improper beanbag tin rack"
	icon_state = "beanbag_magrack"
	stocked_weapon = /obj/item/ammo_magazine/shotgun/beanbag
	max_stored = 4

/obj/structure/machinery/auto_rack/smartgun_ammo
	name = "\improper smartgun ammo drum rack"
	icon_state = "smartgun_magrack"
	stocked_weapon = /obj/item/ammo_magazine/smartgun
	max_stored = 8
	req_access = list(ACCESS_MARINE_CARGO)
