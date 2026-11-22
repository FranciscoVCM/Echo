class_name WorldLayout
extends RefCounted
## Hand-designed world layout as data (edit freely; coordinates are in pixels).
##
## Each region:
##   rooms     [center, radius_x, radius_y, wobble 0..0.3, seed]   organic blobby spaces
##   corridors [[points...], width]                                 curved passages
##   rocks     [center, radius, seed]                               solid obstacles
##   ridges    [[points...], thickness]                             curved solid walls (maze-like bits)
##   sites     [center, radius]                                     where PCG places encounters
##   markers   name -> position                                     hand-placed content anchors
##
## Corridors may form loops between rooms on purpose: big explorable spaces with alcoves,
## never a single path with dead ends.


static func regions() -> Array:
	return [_hub(), _clearing(), _vista(), _som(), _tato()]


static func _hub() -> Dictionary:
	var ring: Array = []
	for index in range(23):
		# Sanctum ring around the centre, open at the bottom (sealed by a gate until C, M, Y).
		var angle := deg_to_rad(112.0 + index * (316.0 / 22.0))
		ring.append(Vector2(cos(angle), sin(angle)) * 330.0)
	return {
		"name": "hub", "title": "Nascente", "floor_color": Color(0.33, 0.30, 0.38),
		"flora": [Color(0.75, 0.6, 0.9), Color(0.6, 0.8, 0.85), Color(0.9, 0.85, 0.6)],
		"rooms": [
			[Vector2(0, 0), 740, 660, 0.08, 11],
			[Vector2(0, -600), 280, 220, 0.15, 12],
			[Vector2(-640, 0), 240, 280, 0.15, 13],
			[Vector2(640, 0), 240, 280, 0.15, 14],
			[Vector2(0, 600), 260, 200, 0.15, 15],
		],
		"corridors": [],
		"rocks": [
			[Vector2(-430, -380), 55, 101], [Vector2(450, -360), 50, 102],
			[Vector2(-470, 380), 50, 103], [Vector2(440, 420), 58, 104],
		],
		"ridges": [[ring, 48]],
		"sites": [],
		"markers": {
			"center": Vector2(0, 0), "sanctum_gate": Vector2(0, 330),
			"from_clearing": Vector2(0, 560), "test_start": Vector2(0, 520),
			"k_fragment_0": Vector2(-560, -260), "k_fragment_1": Vector2(560, -240),
			"k_fragment_2": Vector2(-520, 300), "k_fragment_3": Vector2(540, 320),
		},
	}


static func _clearing() -> Dictionary:
	return {
		"name": "clearing", "title": "Clareira", "floor_color": Color(0.24, 0.36, 0.29),
		"flora": [Color(0.5, 0.85, 0.55), Color(0.85, 0.9, 0.5), Color(0.55, 0.8, 0.9)],
		"rooms": [
			[Vector2(-430, 1840), 230, 200, 0.18, 21],  # start nest
			[Vector2(0, 1600), 560, 400, 0.12, 22],  # main glade (with the pond)
			[Vector2(-680, 1420), 260, 230, 0.15, 23],  # west nook (shy), roomy
			[Vector2(620, 1740), 280, 240, 0.15, 24],  # east glade (pair around rock)
			[Vector2(580, 1320), 170, 150, 0.2, 25],  # hidden alcove
			[Vector2(130, 2240), 190, 140, 0.18, 26],  # south pocket (behind the current)
		],
		"corridors": [
			[[Vector2(0, 1320), Vector2(30, 1080), Vector2(-10, 850), Vector2(0, 600)], 190],
			[[Vector2(650, 1530), Vector2(615, 1420), Vector2(580, 1320)], 120],
			[[Vector2(100, 1940), Vector2(115, 2050), Vector2(130, 2150)], 170],
		],
		"rocks": [
			[Vector2(620, 1740), 72, 201],
			[Vector2(-200, 1500), 45, 202], [Vector2(-560, 1640), 40, 204],
		],
		"ridges": [
			[[Vector2(-440, 1300), Vector2(-425, 1390)], 36],
		],
		# Mi waits on a lily pad in the pond: too far for a quick ping, so you learn to charge.
		"pools": [[Vector2(220, 1460), 240, 180, 27]],
		# A current in front of the south pocket: you learn to dash.
		"currents": [[Vector2(115, 2045), Vector2(185, 130), Vector2.UP]],
		"sites": [],
		"markers": {
			"start": Vector2(-470, 1880),
			"fa": Vector2(-180, 1760), "mi": Vector2(220, 1460),
			"shy": Vector2(-700, 1380),
			"pair_a": Vector2(470, 1740), "pair_b": Vector2(770, 1740),
			"stim": Vector2(140, 2260), "hidden": Vector2(590, 1300),
			"k_start": Vector2(-330, 1800), "gate": Vector2(0, 960),
			# Tutorial guide lights: exactly where to stand for each lesson.
			"g_fa": Vector2(-330, 1720), "g_mi": Vector2(220, 1685), "g_shy": Vector2(-600, 1530),
			"g_pair": Vector2(620, 1575), "g_current": Vector2(115, 1890), "g_stim": Vector2(140, 2140),
			"g_hidden": Vector2(630, 1460),
		},
	}


static func _vista() -> Dictionary:
	return {
		"name": "vista", "title": "Grutas da Vista", "floor_color": Color(0.40, 0.35, 0.22),
		"flora": [Color(0.95, 0.85, 0.4), Color(0.9, 0.7, 0.3), Color(0.8, 0.9, 0.6)],
		"rooms": [
			[Vector2(-1800, 0), 330, 270, 0.15, 31],
			[Vector2(-2120, -620), 390, 270, 0.18, 32],
			[Vector2(-2160, 640), 370, 300, 0.18, 33],
			[Vector2(-2820, 0), 540, 470, 0.12, 34],
			[Vector2(-2920, -840), 310, 280, 0.2, 35],
			[Vector2(-2960, 840), 330, 290, 0.2, 36],
			[Vector2(-2380, -980), 160, 140, 0.25, 37],
			[Vector2(-1680, 860), 160, 150, 0.25, 38],
			[Vector2(-3380, 20), 190, 170, 0.25, 39],
			[Vector2(-3760, 0), 400, 360, 0.12, 40],  # Y chamber
		],
		"corridors": [
			[[Vector2(-640, 0), Vector2(-1000, 50), Vector2(-1350, -30), Vector2(-1620, 0)], 200],
			[[Vector2(-1860, -200), Vector2(-1960, -330), Vector2(-2040, -440)], 170],
			[[Vector2(-1860, 200), Vector2(-1980, 360), Vector2(-2060, 440)], 170],
			[[Vector2(-2080, 0), Vector2(-2230, 40), Vector2(-2350, 20)], 200],
			[[Vector2(-2420, -660), Vector2(-2560, -760), Vector2(-2700, -780)], 160],
			[[Vector2(-2850, -420), Vector2(-2870, -520), Vector2(-2890, -600)], 150],
			[[Vector2(-2460, 700), Vector2(-2600, 790), Vector2(-2720, 810)], 170],
			[[Vector2(-2860, 430), Vector2(-2890, 530), Vector2(-2910, 600)], 150],
			[[Vector2(-2230, -800), Vector2(-2300, -900), Vector2(-2380, -980)], 120],
			[[Vector2(-1950, 720), Vector2(-1820, 810), Vector2(-1680, 860)], 120],
			[[Vector2(-3280, 10), Vector2(-3330, 20), Vector2(-3400, 20)], 170],
			[[Vector2(-3520, 20), Vector2(-3580, 0), Vector2(-3640, 0)], 170],
		],
		"rocks": [
			[Vector2(-2820, 10), 70, 301], [Vector2(-2600, -220), 45, 302], [Vector2(-3060, 260), 50, 303],
			[Vector2(-2120, -620), 55, 304], [Vector2(-2240, 700), 48, 305], [Vector2(-1760, -60), 40, 306],
			[Vector2(-2980, -880), 50, 307],
			[Vector2(-3760, -150), 55, 309], [Vector2(-3640, 160), 50, 310], [Vector2(-3900, 140), 48, 311],
		],
		"ridges": [
			[[Vector2(-3080, -240), Vector2(-2900, -280), Vector2(-2700, -180)], 48],
			[[Vector2(-3040, 160), Vector2(-2840, 250), Vector2(-2640, 200)], 48],
			[[Vector2(-2300, 520), Vector2(-2160, 470), Vector2(-2020, 540)], 40],
		],
		"pools": [[Vector2(-2980, 860), 190, 140, 312]],  # dark lake (advanced challenge)
		"sites": [
			[Vector2(-1850, 40), 190], [Vector2(-2050, -560), 210], [Vector2(-2120, 700), 210],
			[Vector2(-2620, -20), 160], [Vector2(-3020, 30), 160], [Vector2(-1680, 860), 80],
			[Vector2(-3380, 20), 90], [Vector2(-2780, 370), 100], [Vector2(-2230, -740), 110],
		],
		"markers": {
			"entry": Vector2(-1500, 0), "vassal": Vector2(-3760, 0), "vassal_gate": Vector2(-3590, 0),
			"spark_0": Vector2(-3960, -180), "spark_1": Vector2(-3560, -250), "spark_2": Vector2(-3820, 280),
			"y_anchor_0": Vector2(-3900, -60), "y_anchor_1": Vector2(-3700, -280),
			"y_anchor_2": Vector2(-3600, 220), "y_anchor_3": Vector2(-3880, 230),
		},
	}


static func _som() -> Dictionary:
	var basin_stones: Array = []
	for index in range(6):
		var angle := TAU * index / 6.0 + 0.3
		basin_stones.append([Vector2(0, -2450) + Vector2(cos(angle), sin(angle)) * 230.0, 42, 420 + index])
	var rocks: Array = [
		[Vector2(-300, -1640), 40, 401], [Vector2(-90, -1700), 38, 402], [Vector2(130, -1630), 40, 403],
		[Vector2(340, -1690), 38, 404], [Vector2(-640, -2960), 46, 405], [Vector2(820, -2120), 45, 409],
		[Vector2(-1330, -1980), 32, 407], [Vector2(1330, -1980), 32, 408],
	]
	rocks.append_array(basin_stones)
	return {
		"name": "som", "title": "Vale dos Ecos", "floor_color": Color(0.20, 0.34, 0.40),
		"flora": [Color(0.4, 0.85, 0.95), Color(0.6, 0.95, 0.9), Color(0.5, 0.7, 0.95)],
		"rooms": [
			[Vector2(0, -1650), 580, 300, 0.12, 41],
			[Vector2(-820, -2120), 420, 360, 0.15, 42],
			[Vector2(820, -2120), 420, 360, 0.15, 43],
			[Vector2(0, -2450), 480, 390, 0.1, 44],
			[Vector2(-520, -3060), 330, 300, 0.18, 45],
			[Vector2(560, -3060), 330, 300, 0.18, 46],
			[Vector2(-1260, -1900), 180, 170, 0.22, 47],
			[Vector2(1260, -1900), 180, 170, 0.22, 48],
			[Vector2(0, -3520), 430, 330, 0.12, 49],  # C chamber
		],
		"corridors": [
			[[Vector2(0, -620), Vector2(40, -900), Vector2(-20, -1150), Vector2(0, -1400)], 210],
			[[Vector2(-380, -1800), Vector2(-520, -1880), Vector2(-660, -1960)], 200],
			[[Vector2(380, -1800), Vector2(520, -1880), Vector2(660, -1960)], 200],
			[[Vector2(0, -1900), Vector2(10, -2000), Vector2(0, -2090)], 220],
			[[Vector2(-470, -2310), Vector2(-420, -2360), Vector2(-360, -2400)], 160],
			[[Vector2(470, -2310), Vector2(420, -2360), Vector2(360, -2400)], 160],
			[[Vector2(-250, -2760), Vector2(-330, -2840), Vector2(-420, -2900)], 170],
			[[Vector2(250, -2760), Vector2(340, -2840), Vector2(450, -2900)], 170],
			[[Vector2(-1150, -2000), Vector2(-1200, -1950), Vector2(-1260, -1900)], 140],
			[[Vector2(1150, -2000), Vector2(1200, -1950), Vector2(1260, -1900)], 140],
			[[Vector2(-420, -3300), Vector2(-320, -3380), Vector2(-220, -3440)], 170],
			[[Vector2(420, -3300), Vector2(320, -3380), Vector2(220, -3440)], 170],
		],
		"rocks": rocks,
		"ridges": [
			[[Vector2(-1080, -2270), Vector2(-920, -2400), Vector2(-720, -2420)], 44],
			[[Vector2(1080, -2270), Vector2(920, -2400), Vector2(720, -2420)], 44],
			[[Vector2(-890, -2190), Vector2(-830, -2140), Vector2(-770, -2090)], 40],
		],
		"pools": [[Vector2(560, -3060), 180, 140, 413]],  # singing island (advanced challenge)
		"sites": [
			[Vector2(-420, -1600), 170], [Vector2(420, -1600), 170], [Vector2(0, -2450), 140],
			[Vector2(-480, -3100), 170], [Vector2(-1240, -1880), 90], [Vector2(1240, -1880), 90],
			[Vector2(0, -1760), 110],
		],
		"markers": {
			"entry": Vector2(0, -1350), "vassal": Vector2(0, -3540), "vassal_gate": Vector2(0, -3200),
			"stone_0": Vector2(-280, -3600), "stone_1": Vector2(0, -3750), "stone_2": Vector2(280, -3600),
		},
	}


static func _tato() -> Dictionary:
	var rooms: Array = [
		[Vector2(1850, 0), 340, 280, 0.15, 51],
		[Vector2(2260, -660), 380, 300, 0.18, 52],
		[Vector2(2260, 660), 380, 300, 0.18, 53],
		[Vector2(2860, 0), 490, 430, 0.12, 54],
		[Vector2(3160, -800), 300, 280, 0.2, 55],
		[Vector2(3160, 800), 300, 280, 0.2, 56],
		[Vector2(2000, -1060), 170, 150, 0.25, 57],
		[Vector2(2000, 1060), 170, 150, 0.25, 58],
		[Vector2(3760, 0), 390, 350, 0.12, 59],  # M chamber
	]
	var sites: Array = [
		[Vector2(1850, 0), 180], [Vector2(2150, -600), 150], [Vector2(2390, -730), 140],
		[Vector2(2150, 600), 150], [Vector2(2390, 730), 140], [Vector2(2700, -120), 190],
		[Vector2(3020, 140), 190], [Vector2(2000, 1060), 80], [Vector2(2690, 250), 110],
	]
	# Places reserved for the hand-designed advanced challenges (no trunks there).
	var keep_clear: Array = [[Vector2(3160, -800), 190], [Vector2(3160, 820), 190], [Vector2(2000, -1060), 110]]
	# Tree trunks: small rocks scattered through the forest rooms, kept away from sites.
	var rocks: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for room_index in range(6):
		var room: Array = rooms[room_index]
		var placed := 0
		var attempts := 0
		while placed < 7 and attempts < 80:
			attempts += 1
			var angle := rng.randf() * TAU
			var distance := sqrt(rng.randf()) * 0.85
			var at: Vector2 = room[0] + Vector2(cos(angle) * room[1], sin(angle) * room[2]) * distance
			var clear := true
			for site in sites + keep_clear:
				if at.distance_to(site[0]) < site[1] + 60.0:
					clear = false
			for rock in rocks:
				if at.distance_to(rock[0]) < 120.0:
					clear = false
			if clear:
				rocks.append([at, rng.randf_range(22.0, 36.0), 600 + rocks.size()])
				placed += 1
	return {
		"name": "tato", "title": "Bosque do Toque", "floor_color": Color(0.38, 0.24, 0.33),
		"flora": [Color(0.95, 0.5, 0.75), Color(0.85, 0.4, 0.6), Color(0.7, 0.9, 0.55)],
		"rooms": rooms,
		"corridors": [
			[[Vector2(640, 0), Vector2(1000, -50), Vector2(1350, 30), Vector2(1620, 0)], 200],
			[[Vector2(1910, -220), Vector2(2010, -340), Vector2(2100, -450)], 170],
			[[Vector2(1910, 220), Vector2(2010, 340), Vector2(2100, 450)], 170],
			[[Vector2(2150, 0), Vector2(2280, 30), Vector2(2420, 0)], 200],
			[[Vector2(2520, -520), Vector2(2590, -420), Vector2(2660, -330)], 160],
			[[Vector2(2520, 520), Vector2(2590, 420), Vector2(2660, 330)], 160],
			[[Vector2(2620, -720), Vector2(2760, -770), Vector2(2880, -780)], 160],
			[[Vector2(2620, 720), Vector2(2760, 770), Vector2(2880, 780)], 160],
			[[Vector2(3020, -390), Vector2(3060, -470), Vector2(3090, -540)], 150],
			[[Vector2(3020, 390), Vector2(3060, 470), Vector2(3090, 540)], 150],
			[[Vector2(2130, -870), Vector2(2060, -960), Vector2(2000, -1060)], 130],
			[[Vector2(2130, 870), Vector2(2060, 960), Vector2(2000, 1060)], 130],
			[[Vector2(3320, 0), Vector2(3420, 20), Vector2(3500, 0)], 180],
		],
		"rocks": rocks,
		"ridges": [
			[[Vector2(2620, -260), Vector2(2760, -330), Vector2(2900, -300)], 40],
			[[Vector2(2840, 300), Vector2(2980, 330), Vector2(3100, 260)], 40],
		],
		"pools": [[Vector2(3160, 820), 150, 110, 514]],  # gentle lake (advanced challenge)
		# Currents guarding the two alcoves: dash to get in, the flow carries you out.
		"currents": [
			[Vector2(2075, -950), Vector2(200, 110), Vector2(0.56, 0.83)],
			[Vector2(2075, 950), Vector2(200, 110), Vector2(0.56, -0.83)],
		],
		"sites": sites,
		"markers": {
			"entry": Vector2(1500, 0), "vassal": Vector2(3800, 0), "vassal_gate": Vector2(3470, 0),
			"m_anchor_0": Vector2(3880, -120), "m_anchor_1": Vector2(3680, 200), "m_anchor_2": Vector2(3950, 180),
		},
	}
