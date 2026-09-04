/obj/structure/machinery/cm_vending/clothing/k9_synth
	name = "\improper Wey-Yu Synthetic K9 Equipment Requisitions"
	desc = "An automated equipment vendor for Synthetic K9s."
	show_points = FALSE
	req_access = list(ACCESS_MARINE_SYNTH)
	vendor_role = list(JOB_SYNTH_K9)

/obj/structure/machinery/cm_vending/clothing/k9_synth/get_listed_products(mob/user)
	return GLOB.cm_vending_clothing_k9_synth

//------------GEAR---------------

GLOBAL_LIST_INIT(cm_vending_clothing_k9_synth, list(
		list("STANDARD EQUIPMENT (TAKE ALL)", 0, null, null, null),
		list("Headset", 0, /obj/item/device/radio/headset/almayer/mcom/synth, MARINE_CAN_BUY_EAR, VENDOR_ITEM_MANDATORY),
		list("K9 Serial ID Tags", 0, /obj/item/clothing/under/rank/synthetic/synth_k9, MARINE_CAN_BUY_UNIFORM, VENDOR_ITEM_MANDATORY),
		list("Name Changer", 0, /obj/item/k9_name_changer/, MARINE_CAN_BUY_ACCESSORY, VENDOR_ITEM_MANDATORY),

		list("HANDLER KIT (CHOOSE 1)", 0, null, null, null),
		list("Squad Corpsman -> K9 Handler", 0, /obj/item/storage/box/kit/k9_handler/corpsman, MARINE_CAN_BUY_ESSENTIALS, VENDOR_ITEM_RECOMMENDED),
		list("Military Police -> K9 Handler", 0, /obj/item/storage/box/kit/k9_handler/mp, MARINE_CAN_BUY_ESSENTIALS, VENDOR_ITEM_REGULAR),

		list("CARRYPACK (CHOOSE 1)", 0, null, null, null),
		list("Medical Carry Harness", 0, /obj/item/storage/backpack/marine/k9_synth/medicalpack, MARINE_CAN_BUY_BACKPACK, VENDOR_ITEM_RECOMMENDED),
		list("Cargo Carry Harness", 0, /obj/item/storage/backpack/marine/k9_synth/cargopack, MARINE_CAN_BUY_BACKPACK, VENDOR_ITEM_REGULAR),
		list("MP Carry Harness", 0, /obj/item/storage/backpack/marine/k9_synth/mppack, MARINE_CAN_BUY_BACKPACK, VENDOR_ITEM_REGULAR),
	))

//------------SNOWFLAKE VENDOR---------------
// Cosmetic variety (vests, headwear, masks, eyewear) bought with snowflake points, same idea as
// /obj/structure/machinery/cm_vending/clothing/synth/snowflake in synthetic.dm.

GLOBAL_LIST_INIT(cm_vending_clothing_k9_synth_snowflake, list(
		list("VEST (CHOOSE 1)", 0, null, null, null),
		list("Safety Vest", 12, /obj/item/clothing/suit/k9_vest, null, VENDOR_ITEM_REGULAR),
		list("Medical Vest", 12, /obj/item/clothing/suit/k9_vest/medical, null, VENDOR_ITEM_REGULAR),
		list("Tactical Vest", 12, /obj/item/clothing/suit/k9_vest/tactical, null, VENDOR_ITEM_REGULAR),

		list("HEADWEAR (CHOOSE 1)", 0, null, null, null),
		list("Drill Instructor's Hat", 12, /obj/item/clothing/head/k9_drillhat, null, VENDOR_ITEM_REGULAR),
		list("MP Beret", 12, /obj/item/clothing/head/k9_mpberet, null, VENDOR_ITEM_REGULAR),
		list("Engineering Beret", 12, /obj/item/clothing/head/k9_engiberet, null, VENDOR_ITEM_REGULAR),
		list("Purple Beret", 12, /obj/item/clothing/head/k9_purpleberet, null, VENDOR_ITEM_REGULAR),

		list("MASK (CHOOSE 1)", 0, null, null, null),
		list("Bandana", 12, /obj/item/clothing/mask/k9_bandana, null, VENDOR_ITEM_REGULAR),
		list("Red Bandana", 12, /obj/item/clothing/mask/k9_bandana/red, null, VENDOR_ITEM_REGULAR),
		list("Yellow Bandana", 12, /obj/item/clothing/mask/k9_bandana/yellow, null, VENDOR_ITEM_REGULAR),
		list("Purple Bandana", 12, /obj/item/clothing/mask/k9_bandana/purple, null, VENDOR_ITEM_REGULAR),
		list("Blue Bandana", 12, /obj/item/clothing/mask/k9_bandana/blue, null, VENDOR_ITEM_REGULAR),
		list("Green Bandana", 12, /obj/item/clothing/mask/k9_bandana/green, null, VENDOR_ITEM_REGULAR),
		list("Black Bandana", 12, /obj/item/clothing/mask/k9_bandana/black, null, VENDOR_ITEM_REGULAR),

		list("EYEWEAR (CHOOSE 1)", 0, null, null, null),
		list("Marine Goggles", 12, /obj/item/clothing/glasses/k9_goggles, null, VENDOR_ITEM_REGULAR),
		list("Marine Goggles (Mk 2)", 12, /obj/item/clothing/glasses/k9_goggles/v2, null, VENDOR_ITEM_REGULAR),
	))

/obj/structure/machinery/cm_vending/clothing/k9_synth/snowflake
	name = "\improper W-Y K9 Conformity Unit"
	desc = "A vendor with a large snowflake on it. Provided by Wey-Yu Fashion Division(TM), fitted for K9 Rescue Units."
	icon_state = "snowflake"
	show_points = TRUE
	use_snowflake_points = TRUE
	vendor_theme = VENDOR_THEME_COMPANY
	vend_delay = 1 SECONDS

/obj/structure/machinery/cm_vending/clothing/k9_synth/snowflake/get_listed_products(mob/user)
	return GLOB.cm_vending_clothing_k9_synth_snowflake
