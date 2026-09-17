extends RefCounted

const MAPS = [
	{"id": "01_crossfire_court", "name": "Crossfire Court", "description": "Three broad lanes with staggered cover and outer flanks."},
	{"id": "02_courtyard_keep", "name": "Courtyard Keep", "description": "Four wide gates lead into a fortified central courtyard."},
	{"id": "03_canal_crossings", "name": "Canal Crossings", "description": "Three bridges connect two banks; water blocks tank movement."},
	{"id": "04_switchback_works", "name": "Switchback Works", "description": "Long offset partitions create winding routes and ambush pockets."},
	{"id": "05_freight_exchange", "name": "Freight Exchange", "description": "Cargo blocks form service lanes, junctions, and firing alleys."},
	{"id": "06_crater_circuit", "name": "Crater Circuit", "description": "A central crater divides a broad ring of broken cover."},
]

static func scene_path(index: int) -> String:
	return "res://scenes/maps/%s.tscn" % MAPS[index].id
