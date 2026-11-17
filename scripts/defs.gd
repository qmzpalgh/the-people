class_name Defs
extends RefCounted
## Static game data: needs, objects, interactions, careers, socials.

const NEEDS := ["hunger", "energy", "hygiene", "bladder", "fun", "social", "comfort", "room"]
const NEED_NAMES := {
	"hunger": "Hunger", "energy": "Energy", "hygiene": "Hygiene", "bladder": "Bladder",
	"fun": "Fun", "social": "Social", "comfort": "Comfort", "room": "Room",
}
## Points lost per game hour (needs run 0..100).
const DECAY := {
	"hunger": 6.0, "energy": 3.6, "hygiene": 2.8, "bladder": 5.0,
	"fun": 3.5, "social": 2.5, "comfort": 4.0, "room": 0.0,
}
## While out at work or school: [points per game hour, level it stops at].
const AWAY := {
	"hunger": [-3.0, 20.0], "energy": [-4.0, 10.0], "hygiene": [-2.5, 20.0], "bladder": [-3.0, 45.0],
	"fun": [-3.0, 10.0], "social": [3.0, 100.0], "comfort": [-2.0, 20.0],
}
## The body clock. Left to themselves people go to bed between their BEDTIME and WAKE
## once energy is under SLEEPY, and stay there until WAKE. By day they only nap, under
## NAPPY and no later than NAP_GAP hours before bed. Under EXHAUSTED the clock stops
## mattering.
const BEDTIME := {"child": 20.5, "adult": 22.0, "elder": 21.0}
const WAKE := 6.0
const SLEEPY := 75.0
const NAPPY := 40.0
const NAP_GAP := 3.0
const EXHAUSTED := 20.0
## People set off COMMUTE hours before a shift. Anyone whose shift would leave less
## than MORNING hours between WAKE and setting off runs their whole day (bed, waking,
## breakfast) that much earlier on work days.
const COMMUTE := 0.5
const MORNING := 2.0
## Mealtimes, [from, to]. Left to themselves adults cook one meal in each while they
## are home, unless fuller than FULL. Children, who cannot cook, and anyone with less
## than MEAL_TIME hours before setting off for work have a snack as their meal instead.
## Between meals people only snack, and only once hunger is under PECKISH. Under
## RAVENOUS the clock stops mattering.
const MEALS := [[6.0, 9.0], [12.0, 14.5], [18.0, 21.0]]
const MEAL_TIME := 1.25
const FULL := 80.0
const PECKISH := 50.0
const RAVENOUS := 20.0
const MOOD_W := {
	"hunger": 1.5, "energy": 1.5, "hygiene": 1.0, "bladder": 1.2,
	"fun": 1.0, "social": 1.0, "comfort": 0.8, "room": 0.6,
}
const SKILLS := ["cooking", "logic", "creativity", "fitness", "charisma"]
## Skills run 0..10. An interaction's "skill" rate is levels per game hour at level 0;
## each level already held makes the next one take SKILL_SLOWDOWN of a first level
## longer (see skill_pace). SCHOOL_LOGIC is the practice a school day is worth.
const SKILL_SLOWDOWN := 1.0
const SCHOOL_LOGIC := 0.12
const TRAITS := ["neat", "outgoing", "active", "playful", "nice"]
const DAYS := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
## Front direction of an object for rotation 0..3 (tile space, y = world z).
const FRONT := [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0)]

const FLOORS := [
	{"name": "Grass", "price": 0},
	{"name": "Wood planks", "tex": "wood", "tint": Color(0.62, 0.44, 0.26), "price": 4},
	{"name": "Blue tile", "tex": "tile", "tint": Color(0.55, 0.72, 0.8), "price": 5},
	{"name": "Carpet (rose)", "tex": "carpet", "tint": Color(0.7, 0.42, 0.45), "price": 4},
	{"name": "Stone", "tex": "stone", "tint": Color(0.62, 0.62, 0.6), "price": 3},
	{"name": "Checker tile", "tex": "tile", "tint": Color(0.25, 0.25, 0.28), "price": 5},
	{"name": "Carpet (teal)", "tex": "carpet", "tint": Color(0.3, 0.55, 0.55), "price": 4},
	{"name": "Dark wood", "tex": "wood", "tint": Color(0.4, 0.26, 0.16), "price": 5},
]

const WALL_PRICE := 15
const DOOR_PRICE := 40
const WINDOW_PRICE := 30

const EAT := {"id": "eat", "label": "Eat", "needs": {"hunger": 130.0}, "dur": 0.35, "seat": true, "bubble": "Yum", "snd": "munch"}

## size = footprint at rotation 0 (x, depth). slots = local positions people occupy.
## acts = interactions. needs are points per game hour while doing.
const OBJECTS := {
	"bed_single": {
		"name": "Single bed", "price": 300, "cat": "Bedroom", "size": Vector2i(1, 2), "room": 1.0, "h": 0.6,
		"slots": [Vector3(0, 0.5, 0)],
		"acts": [{"id": "sleep", "label": "Sleep", "needs": {"energy": 9.0, "comfort": 20.0}, "until": "energy",
			"dur": 12.0, "pose": "lie", "sleep": true, "busy": true, "bubble": "Zzz"}],
	},
	"bed_double": {
		"name": "Double bed", "price": 650, "cat": "Bedroom", "size": Vector2i(2, 2), "room": 2.0, "h": 0.6,
		"slots": [Vector3(-0.5, 0.5, 0), Vector3(0.5, 0.5, 0)],
		"acts": [{"id": "sleep", "label": "Sleep", "needs": {"energy": 11.0, "comfort": 30.0}, "until": "energy",
			"dur": 12.0, "pose": "lie", "sleep": true, "busy": true, "bubble": "Zzz"}],
	},
	"sofa": {
		"name": "Sofa", "price": 400, "cat": "Seating", "size": Vector2i(2, 1), "room": 2.0, "h": 0.8,
		"seat": true, "comfort": 45.0, "slots": [Vector3(-0.5, 0.45, 0.05), Vector3(0.5, 0.45, 0.05)],
		"acts": [
			{"id": "sit", "label": "Relax", "needs": {"comfort": 45.0, "energy": 1.5}, "until": "comfort", "dur": 2.0, "pose": "sit"},
			{"id": "nap", "label": "Nap", "needs": {"energy": 7.0, "comfort": 30.0}, "until": "energy", "dur": 3.0,
				"pose": "sit", "sleep": true, "bubble": "Zzz"},
		],
	},
	"armchair": {
		"name": "Armchair", "price": 180, "cat": "Seating", "size": Vector2i(1, 1), "room": 1.0, "h": 0.8,
		"seat": true, "comfort": 50.0, "slots": [Vector3(0, 0.45, 0.05)],
		"acts": [{"id": "sit", "label": "Relax", "needs": {"comfort": 50.0, "energy": 1.5}, "until": "comfort", "dur": 2.0, "pose": "sit"}],
	},
	"chair": {
		"name": "Dining chair", "price": 60, "cat": "Seating", "size": Vector2i(1, 1), "h": 0.9,
		"seat": true, "comfort": 28.0, "slots": [Vector3(0, 0.47, 0)],
		"acts": [{"id": "sit", "label": "Sit", "needs": {"comfort": 28.0}, "until": "comfort", "dur": 1.5, "pose": "sit", "auto": false}],
	},
	"table": {"name": "Table", "price": 90, "cat": "Seating", "size": Vector2i(1, 1), "room": 0.5, "h": 0.8},
	"tv": {
		"name": "Television", "price": 500, "cat": "Fun", "size": Vector2i(1, 1), "room": 1.0, "h": 1.1, "cap": 4,
		"acts": [{"id": "watch", "label": "Watch TV", "needs": {"fun": 20.0}, "until": "fun", "dur": 2.5, "seat": true, "bubble": "Ha!", "snd": "tv"}],
	},
	"stereo": {
		"name": "Stereo", "price": 350, "cat": "Fun", "size": Vector2i(1, 1), "room": 1.0, "h": 1.0, "cap": 4,
		"acts": [{"id": "dance", "label": "Dance", "needs": {"fun": 24.0, "energy": -3.0}, "until": "fun", "dur": 1.2, "dance": true, "bubble": "La la", "snd": "music"}],
	},
	"bookshelf": {
		"name": "Bookshelf", "price": 250, "cat": "Skills", "size": Vector2i(1, 1), "room": 1.5, "h": 1.8, "cap": 3,
		"acts": [
			{"id": "read", "label": "Read a novel", "needs": {"fun": 13.0}, "until": "fun", "dur": 2.0, "seat": true},
			{"id": "study_cooking", "label": "Study cooking", "needs": {"fun": -3.0}, "skill": {"cooking": 0.45}, "dur": 2.0, "seat": true, "mood_min": 45},
			{"id": "study_logic", "label": "Study logic", "needs": {"fun": -3.0}, "skill": {"logic": 0.45}, "dur": 2.0, "seat": true, "mood_min": 45},
		],
	},
	"computer": {
		"name": "Computer desk", "price": 900, "cat": "Fun", "size": Vector2i(1, 1), "room": 1.0, "h": 1.2,
		"slots": [Vector3(0, 0.45, 0.25)], "face_back": true,
		"acts": [
			{"id": "play", "label": "Play games", "needs": {"fun": 26.0, "comfort": 10.0}, "until": "fun", "dur": 2.5, "pose": "sit", "snd": "keys"},
			{"id": "job", "label": "Find a job", "needs": {"comfort": 10.0}, "dur": 0.5, "pose": "sit", "cond": "no_job", "special": "job", "adult": true, "snd": "keys"},
			{"id": "puzzle", "label": "Solve puzzles", "needs": {"fun": 4.0, "comfort": 10.0}, "skill": {"logic": 0.5}, "dur": 2.0, "pose": "sit", "mood_min": 45, "snd": "keys"},
		],
	},
	"easel": {
		"name": "Easel", "price": 350, "cat": "Skills", "size": Vector2i(1, 1), "room": 1.0, "h": 1.5,
		"acts": [{"id": "paint", "label": "Paint (sells when done)", "needs": {"fun": 9.0}, "skill": {"creativity": 0.45}, "dur": 2.5, "special": "paint", "mood_min": 45}],
	},
	"weights": {
		"name": "Weight bench", "price": 450, "cat": "Skills", "size": Vector2i(1, 2), "h": 1.0,
		"slots": [Vector3(0, 0.45, 0)],
		"acts": [{"id": "workout", "label": "Work out", "needs": {"fun": 3.0, "hygiene": -14.0, "energy": -6.0}, "skill": {"fitness": 0.5}, "dur": 1.5, "pose": "lie", "mood_min": 45, "adult": true}],
	},
	"mirror": {
		"name": "Standing mirror", "price": 150, "cat": "Skills", "size": Vector2i(1, 1), "room": 1.0, "h": 1.7,
		"acts": [{"id": "speech", "label": "Practice speech", "needs": {"fun": -2.0}, "skill": {"charisma": 0.5}, "dur": 1.5, "mood_min": 45, "bubble": "Bla bla", "talk": true}],
	},
	"phone": {
		"name": "Telephone", "price": 120, "cat": "Fun", "size": Vector2i(1, 1), "h": 0.9,
		"acts": [
			{"id": "call", "label": "Chat on the phone", "needs": {"social": 32.0, "fun": 5.0}, "until": "social", "dur": 1.2, "bubble": "Bla bla", "talk": true},
			{"id": "invite", "label": "Invite a neighbour over", "dur": 0.15, "special": "invite", "cond": "can_invite", "gain": {"social": 30.0}, "bubble": "Bla bla", "talk": true},
			{"id": "adopt", "label": "Adopt a child ($500)", "dur": 0.3, "cost": 500, "special": "adopt", "cond": "can_adopt", "auto": false, "adult": true, "bubble": "Bla bla", "talk": true},
		],
	},
	"fridge": {
		"name": "Refrigerator", "price": 600, "cat": "Kitchen", "size": Vector2i(1, 1), "h": 1.8, "cap": 2,
		"acts": [
			{"id": "snack", "label": "Have a snack ($5)", "needs": {"hunger": 120.0}, "dur": 0.25, "cost": 5, "bubble": "Yum"},
			{"id": "meal", "label": "Cook a meal ($6)", "dur": 0.15, "cost": 6, "req": "stove",
				"gain": {"hunger": 45.0}, "adult": true, "then": {"kind": "stove", "id": "cook"}},
		],
	},
	"stove": {
		"name": "Stove", "price": 400, "cat": "Kitchen", "size": Vector2i(1, 1), "h": 0.9, "cap": 2,
		"acts": [{"id": "cook", "label": "Cook", "skill": {"cooking": 0.3}, "dur": 0.45, "hidden": true, "snd": "sizzle", "then": {"kind": "self", "id": "eat"}}],
	},
	"sink": {
		"name": "Sink", "price": 250, "cat": "Bathroom", "size": Vector2i(1, 1), "h": 0.9,
		"acts": [{"id": "wash", "label": "Wash up", "needs": {"hygiene": 120.0}, "dur": 0.2, "snd": "water"}],
	},
	"toilet": {
		"name": "Toilet", "price": 300, "cat": "Bathroom", "size": Vector2i(1, 1), "h": 0.8,
		"slots": [Vector3(0, 0.42, 0.05)],
		"acts": [{"id": "use", "label": "Use toilet", "needs": {"bladder": 500.0}, "until": "bladder", "dur": 0.5, "pose": "sit", "busy": true, "end_snd": "flush"}],
	},
	"shower": {
		"name": "Shower", "price": 550, "cat": "Bathroom", "size": Vector2i(1, 1), "h": 2.0,
		"slots": [Vector3(0, 0.08, 0)],
		"acts": [{"id": "shower", "label": "Take a shower", "needs": {"hygiene": 220.0}, "until": "hygiene", "dur": 0.6, "busy": true, "bubble": "La la", "snd": "water"}],
	},
	"bathtub": {
		"name": "Bathtub", "price": 800, "cat": "Bathroom", "size": Vector2i(2, 1), "room": 1.0, "h": 0.6,
		"slots": [Vector3(0.3, 0.2, 0)],
		"acts": [{"id": "bath", "label": "Take a bath", "needs": {"hygiene": 130.0, "comfort": 60.0}, "until": "hygiene", "dur": 1.0, "pose": "sit", "busy": true, "snd": "water"}],
	},
	"lamp": {"name": "Floor lamp", "price": 80, "cat": "Decor", "size": Vector2i(1, 1), "room": 3.0, "h": 1.7, "light": true},
	"plant": {"name": "House plant", "price": 60, "cat": "Decor", "size": Vector2i(1, 1), "room": 3.0, "h": 1.0},
	"sculpture": {"name": "Sculpture", "price": 400, "cat": "Decor", "size": Vector2i(1, 1), "room": 7.0, "h": 1.5},
	"tree": {"name": "Tree", "price": 120, "cat": "Garden", "size": Vector2i(1, 1), "room": 2.0, "h": 3.0},
	"bush": {"name": "Bush", "price": 40, "cat": "Garden", "size": Vector2i(1, 1), "room": 1.0, "h": 0.8},
	"flowers": {"name": "Flower bed", "price": 25, "cat": "Garden", "size": Vector2i(1, 1), "room": 2.0, "h": 0.4},
	"grave": {
		"name": "Memorial", "price": 0, "cat": "", "size": Vector2i(1, 1), "room": 0.0, "h": 1.0, "soft": true,
		"acts": [{"id": "mourn", "label": "Remember them", "needs": {"social": 10.0}, "dur": 0.3, "auto": false, "bubble": "..."}],
	},
	"puddle": {
		"name": "Puddle", "price": 0, "cat": "", "size": Vector2i(1, 1), "room": -8.0, "h": 0.1, "soft": true,
		"acts": [{"id": "mop", "label": "Mop up", "needs": {"hygiene": -6.0}, "dur": 0.2, "special": "remove", "gain": {"room": 12.0}}],
	},
}

const GRAVE_NOTE := "grave"

const CATS := ["Seating", "Bedroom", "Kitchen", "Bathroom", "Fun", "Skills", "Decor", "Garden"]

const SOCIALS := [
	{"id": "chat", "label": "Chat", "social": 70.0, "fun": 10.0, "rel": 3.0, "min_rel": -100.0, "dur": 0.4, "trait": "outgoing", "bubble": "Bla bla"},
	{"id": "joke", "label": "Tell a joke", "social": 50.0, "fun": 60.0, "rel": 4.0, "min_rel": -20.0, "dur": 0.3, "trait": "playful", "bubble": "Ha ha!"},
	{"id": "compliment", "label": "Compliment", "social": 60.0, "fun": 0.0, "rel": 5.0, "min_rel": 5.0, "dur": 0.25, "trait": "nice", "bubble": "Nice!"},
	{"id": "hug", "label": "Hug", "social": 110.0, "fun": 10.0, "rel": 6.0, "min_rel": 35.0, "dur": 0.2, "trait": "nice", "bubble": "<3"},
	{"id": "baby", "label": "Have a child together", "social": 60.0, "fun": 20.0, "rel": 5.0, "min_rel": 70.0, "dur": 0.3, "trait": "nice", "bubble": "<3", "auto": false},
	{"id": "insult", "label": "Insult", "social": 20.0, "fun": 0.0, "rel": -10.0, "min_rel": -100.0, "dur": 0.2, "trait": "nice", "bubble": "Grr!"},
]

const GREET := {"id": "greet", "label": "Greet", "social": 60.0, "fun": 0.0, "rel": 3.0, "min_rel": -100.0, "dur": 0.15, "trait": "nice", "bubble": "Hi!", "auto": false}

## Life stages, in days of age.
const CHILD_DAYS := 6.0
const ELDER_AT := 30.0
const SCHOOL := {"start": 8.0, "hours": 6.0}
const PENSION := 40
const MAX_HOUSEHOLD := 6

## start = hour of day, pay per shift by level.
const CAREERS := [
	{"name": "Culinary", "skill": "cooking", "start": 9.0, "hours": 8.0, "pay": [90, 140, 210, 300, 420],
		"titles": ["Dishwasher", "Line Cook", "Sous Chef", "Head Chef", "Restaurateur"]},
	{"name": "Science", "skill": "logic", "start": 9.0, "hours": 8.0, "pay": [100, 150, 220, 320, 450],
		"titles": ["Lab Assistant", "Technician", "Researcher", "Lead Scientist", "Institute Director"]},
	{"name": "Arts", "skill": "creativity", "start": 11.0, "hours": 6.0, "pay": [70, 120, 200, 300, 440],
		"titles": ["Gallery Sitter", "Illustrator", "Designer", "Art Director", "Celebrated Artist"]},
	{"name": "Athletics", "skill": "fitness", "start": 7.0, "hours": 7.0, "pay": [80, 130, 210, 310, 460],
		"titles": ["Ball Fetcher", "Bench Warmer", "Starter", "Team Captain", "Champion"]},
	{"name": "Business", "skill": "charisma", "start": 8.0, "hours": 9.0, "pay": [110, 160, 230, 330, 480],
		"titles": ["Mail Clerk", "Assistant", "Manager", "Vice President", "Chief Executive"]},
]

const _SYL_A := ["Mi", "Ta", "Jo", "Ke", "Lu", "Sa", "Ro", "Ne", "Vi", "Ar", "El", "Da", "Fi", "Ha", "Ol", "Pe", "Zu", "Bri", "Ca", "Wen"]
const _SYL_B := ["ra", "len", "na", "ri", "do", "ven", "la", "mi", "son", "ka", "the", "lo", "ya", "bel", "dy", "ton", "sha", "vo"]
const _SUR_A := ["Tol", "Mar", "Has", "Pen", "Gar", "Wil", "Ash", "Bram", "Cor", "Dun", "Fen", "Hol", "Lind", "Oak", "Rav", "Stel", "Thorn", "Wex"]
const _SUR_B := ["ven", "ley", "wick", "ford", "son", "by", "ridge", "more", "dale", "ham", "croft", "well", "stone", "shaw"]


## How fast a skill at `level` climbs, as a share of the pace at level 0.
static func skill_pace(level: float) -> float:
	return 1.0 / (1.0 + SKILL_SLOWDOWN * level)


static func first_name(rng: RandomNumberGenerator) -> String:
	var s: String = _SYL_A[rng.randi() % _SYL_A.size()] + _SYL_B[rng.randi() % _SYL_B.size()]
	if rng.randf() < 0.25:
		s += _SYL_B[rng.randi() % _SYL_B.size()]
	return s


static func surname(rng: RandomNumberGenerator) -> String:
	return _SUR_A[rng.randi() % _SUR_A.size()] + _SUR_B[rng.randi() % _SUR_B.size()]
