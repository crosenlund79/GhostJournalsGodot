class_name OldHouseLayout
extends RefCounted
## Handcrafted, data-driven layout for the prototype house ("Hollow Lane").
##
## Grid legend:
##   '#' wall          'X' yard fence        ' ' void (unreachable)
##   'D' interior door 'F' front door        'O' yard (outside)
##   any other letter = floor cell belonging to the room with that key.
## Furniture entries are [type, x, y, w, h] in tile coordinates. Walls,
## collisions, light occluders, doors and navigation are all generated from
## this data by [House], so a procedural generator only needs to emit the
## same dictionary.


static func data() -> Dictionary:
	return {
		"name": "Hollow Lane House",
		"grid": [
			"############################################",
			"#BBBBBBBBBB#WWWWWW#UUUUUUU#SSSSS#CCCCCCCCCC#",
			"#BBBBBBBBBB#WWWWWW#UUUUUUU#SSSSS#CCCCCCCCCC#",
			"#BBBBBBBBBB#WWWWWW#UUUUUUU#SSSSS#CCCCCCCCCC#",
			"#BBBBBBBBBB#WWWWWW#UUUUUUU#SSSSS#CCCCCCCCCC#",
			"#BBBBBBBBBB#WWWWWW#UUUUUUU#SSSSS#CCCCCCCCCC#",
			"#BBBBBBBBBB#WWWWWW#UUUUUUU#SSSSS#CCCCCCCCCC#",
			"#BBBBBBBBBB#WWWWWW#UUUUUUU#SSSSS#CCCCCCCCCC#",
			"#####D########D#######D######D####D#########",
			"#HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH#KKKKKKKKKK#",
			"#HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHDKKKKKKKKKK#",
			"########D#########HHHH###########KKKKKKKKKK#",
			"#LLLLLLLLLLLLLLLL#HHHH#NNNNNNNNN#KKKKKKKKKK#",
			"#LLLLLLLLLLLLLLLL#HHHH#NNNNNNNNN#KKKKKKKKKK#",
			"#LLLLLLLLLLLLLLLL#HHHH#NNNNNNNNN#KKKKKKKKKK#",
			"#LLLLLLLLLLLLLLLLDHHHHDNNNNNNNNN#KKKKKKKKKK#",
			"#LLLLLLLLLLLLLLLL#HHHH#NNNNNNNNNDKKKKKKKKKK#",
			"#LLLLLLLLLLLLLLLL#HHHH#NNNNNNNNN#KKKKKKKKKK#",
			"#LLLLLLLLLLLLLLLL#HHHH#NNNNNNNNN#KKKKKKKKKK#",
			"###################F########################",
			"XOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOX",
			"XOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOX",
			"XOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOX",
			"XOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOX",
			"XOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOX",
			"XOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOX",
			"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
		],
		"rooms": {
			"B": {"id": "bedroom", "name": "Master Bedroom", "floor": "carpet", "light": 0.85, "temp": 18.0,
				"switch": [6, 7], "lights": [[5.5, 4.0]], "favorite": true},
			"W": {"id": "bathroom", "name": "Bathroom", "floor": "checker", "light": 0.7, "temp": 17.5,
				"switch": [15, 7], "lights": [[15.0, 4.0]], "favorite": true},
			"U": {"id": "utility", "name": "Utility Room", "floor": "concrete", "light": 0.6, "temp": 16.0,
				"switch": [21, 7], "lights": [[22.5, 4.0]], "favorite": true},
			"S": {"id": "storage", "name": "Storage Room", "floor": "dark_wood", "light": 0.65, "temp": 17.0,
				"switch": [28, 7], "lights": [[29.5, 4.5]], "favorite": false},
			"H": {"id": "hallway", "name": "Hallway", "floor": "dark_wood", "light": 0.75, "temp": 18.5,
				"switch": [20, 18], "lights": [[6.0, 10.0], [16.0, 10.0], [26.0, 10.0], [20.0, 15.0]], "favorite": false},
			"L": {"id": "living_room", "name": "Living Room", "floor": "wood", "light": 1.0, "temp": 19.5,
				"switch": [9, 12], "lights": [[8.5, 15.5]], "favorite": true},
			"N": {"id": "dining_room", "name": "Dining Room", "floor": "wood", "light": 0.9, "temp": 19.0,
				"switch": [23, 14], "lights": [[27.5, 15.5]], "favorite": true},
			"C": {"id": "kids_room", "name": "Kids' Room", "floor": "carpet", "light": 0.7, "temp": 18.0,
				"switch": [35, 7], "lights": [[38.0, 4.0]], "favorite": true},
			"K": {"id": "kitchen", "name": "Kitchen", "floor": "tile", "light": 0.95, "temp": 19.0,
				"switch": [33, 11], "lights": [[38.0, 14.0]], "favorite": true},
		},
		"outdoor_key": "O",
		"safe_room": "S",
		"furniture": [
			# Master bedroom
			["bed", 3, 1, 3, 4], ["nightstand", 2, 1, 1, 1], ["nightstand", 6, 1, 1, 1],
			["wardrobe", 8, 1, 3, 1], ["dresser", 10, 4, 1, 2], ["rug", 2, 5, 5, 2],
			# Bathroom
			["bathtub", 12, 1, 2, 3], ["toilet", 17, 1, 1, 1], ["bath_sink", 17, 4, 1, 1], ["bathmat", 14, 2, 2, 1],
			# Utility
			["washer", 19, 1, 1, 1], ["washer", 20, 1, 1, 1], ["water_heater", 25, 1, 1, 1],
			["shelf", 19, 5, 1, 2], ["boxes", 25, 6, 1, 1],
			# Storage (safe room)
			["shelf", 27, 1, 1, 3], ["boxes", 31, 1, 1, 2], ["boxes", 31, 6, 1, 1],
			# Hallway & foyer
			["plant", 1, 9, 1, 1], ["side_table", 12, 9, 2, 1], ["runner", 23, 9, 6, 2],
			["coat_rack", 21, 18, 1, 1], ["plant", 31, 9, 1, 1],
			# Living room
			["tv_stand", 3, 12, 3, 1], ["rug", 3, 14, 6, 3], ["coffee_table", 5, 15, 2, 1],
			["sofa", 4, 17, 4, 2], ["armchair", 10, 14, 1, 1], ["bookshelf", 1, 15, 1, 3],
			["fireplace", 12, 12, 3, 1], ["plant", 16, 12, 1, 1],
			# Dining room
			["rug", 24, 13, 6, 4], ["dining_table", 25, 14, 4, 2],
			["chair", 26, 13, 1, 1], ["chair", 27, 13, 1, 1], ["chair", 26, 16, 1, 1], ["chair", 27, 16, 1, 1],
			["chair", 24, 14, 1, 1], ["chair", 29, 15, 1, 1], ["cabinet", 31, 12, 1, 2],
			# Kitchen
			["counter", 35, 9, 3, 1], ["stove", 38, 9, 1, 1], ["sink", 39, 9, 1, 1], ["counter", 40, 9, 2, 1],
			["fridge", 42, 9, 1, 2], ["counter", 42, 12, 1, 3], ["island", 37, 13, 3, 2],
			["kitchen_table", 34, 16, 2, 1], ["trash", 33, 18, 1, 1],
			# Kids' room
			["kids_bed", 40, 1, 2, 3], ["toy_chest", 33, 1, 2, 1], ["rug", 36, 3, 4, 3],
			["bookshelf", 42, 5, 1, 2], ["toys", 33, 5, 1, 1], ["nightstand", 39, 1, 1, 1],
			# Yard
			["van", 4, 21, 7, 3], ["rack", 13, 21, 3, 1], ["rack", 13, 23, 3, 1],
			["tree", 32, 22, 2, 2], ["tree", 38, 21, 2, 2], ["bush", 26, 24, 1, 1], ["bush", 2, 25, 1, 1],
		],
		"fuse_box": [23, 1],
		"safe_shrine": [29, 3],
		"player_spawn": [17.5, 22.5],
		"exit_point": [11.5, 22.5],
		"yard_light": [12.0, 22.0],
		"rack_slots": [[13, 21], [14, 21], [15, 21], [13, 23], [14, 23], [15, 23]],
		# Appliances sit on furniture: [type, x, y] in tile units (fractions allowed).
		# No radio in the kids' room: the doll has to walk to one.
		"appliances": [
			["tv", 4.5, 12.5], ["tv", 10.5, 5.0],
			["radio", 36.5, 9.5], ["radio", 31.5, 12.5], ["radio", 12.5, 9.5],
		],
		"doll_spot": [37.5, 4.0],
		"kids_room": "C",
		"book_spots": {
			"B": [[7, 3]], "W": [[15, 3]], "U": [[23, 5]], "L": [[6, 13]], "N": [[30, 17]], "K": [[35, 12]],
		},
	}
