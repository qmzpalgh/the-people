extends RefCounted
## Balance probe for the headless test run (TP_TEST). Samples everyone each simulated
## minute and reports how needs, time use and sleep actually play out, so that decay
## rates can be tuned against numbers rather than by feel.

const GROUPS := ["worker", "jobless", "child", "elder"]
const SKILL_MARKS := [2, 4, 6, 8, 10]

var game
var acc := {}      # group -> {hours, mood, needs: {need: [sum, low, zero]}, acts: {label: hours}, night_awake, night}
var sleeps := []   # [group, kind, start_hour, hours, energy_before, energy_after, finished]
var returns := []  # [group, hour, needs, next_action]
var incidents := {}
var track := {}    # pid -> per-person state for the current run
var deaths := 0
var meals := []    # [group, hour, hunger_after, cooked]
var skills := {}   # "run:pid" -> {group, top, career, level, reached: {level: day}}
var runs := 0


func begin(g) -> void:
	game = g
	track = {}
	runs += 1


func _group(p) -> String:
	match p.stage():
		"child": return "child"
		"elder": return "elder"
	return "worker" if p.job != null else "jobless"


func _label(p) -> String:
	if p.away and p.vstate == "home":
		return "(at work or school)"
	if p.vstate != "home":
		return "(out visiting)"
	if p.cur == null:
		return "(idle)"
	if p.cur.state != "do":
		return "(walking)"
	return p.cur.label.split(":")[0].split(" (")[0]


func step(dh: float) -> void:
	var h: float = game.hour()
	var seen := {}
	for p in game.everyone():
		seen[p.pid] = true
		var g := _group(p)
		if not acc.has(g):
			acc[g] = {"hours": 0.0, "mood": 0.0, "needs": {}, "acts": {}, "night": 0.0, "night_awake": 0.0}
			for n in Defs.NEEDS:
				acc[g]["needs"][n] = [0.0, 0.0, 0.0]
		var a: Dictionary = acc[g]
		a["hours"] += dh
		a["mood"] += p.mood() * dh
		for n in Defs.NEEDS:
			var v: float = p.needs[n]
			var s: Array = a["needs"][n]
			s[0] += v * dh
			if v < 25.0:
				s[1] += dh
			if v <= 0.0:
				s[2] += dh
		var lab := _label(p)
		a["acts"][lab] = a["acts"].get(lab, 0.0) + dh
		var at_work: bool = p.away and p.vstate == "home"
		var asleep: bool = p.cur != null and p.cur.state == "do" and p.cur.get("def", {}).get("sleep", false)
		if h < 5.0 and not at_work:
			a["night"] += dh
			if not asleep:
				a["night_awake"] += dh
		var t: Dictionary = track.get(p.pid, {"sleep": null, "work": false, "back": null, "stats": {},
			"meal": p.meal_t, "eaten": p.stats.get("Eat", 0)})
		if p.meal_t != t["meal"]:
			# A mealtime snack moves meal_t too; only a finished "Eat" is a cooked meal.
			meals.append([g, h, p.needs.hunger, p.stats.get("Eat", 0) > t["eaten"]])
			t["meal"] = p.meal_t
			t["eaten"] = p.stats.get("Eat", 0)
		if asleep and t["sleep"] == null:
			# Counted from the moment it starts, so sleep still running at the end of
			# the run is not lost; length and energy come from finished sessions only.
			t["sleep"] = [g, lab, h, 0.0, p.needs.energy, 0.0, false]
			sleeps.append(t["sleep"])
		elif t["sleep"] != null:
			if asleep:
				t["sleep"][3] += dh
			else:
				t["sleep"][5] = p.needs.energy
				t["sleep"][6] = true
				t["sleep"] = null
		if t["work"] and not at_work:
			t["back"] = [g, h, p.needs.duplicate(), ""]
			returns.append(t["back"])
		t["work"] = at_work
		if t["back"] != null and p.cur != null and p.cur.state == "do" and p.cur.kind in ["use", "eat", "social"]:
			t["back"][3] = lab
			t["back"] = null
		for k in ["passed out", "accident", "failed"]:
			var c: int = p.stats.get(k, 0)
			if c > t["stats"].get(k, 0):
				incidents[k] = incidents.get(k, 0) + c - t["stats"].get(k, 0)
				t["stats"][k] = c
		_skills(p, g, h)
		t["last"] = "%s (%s, household %d) %s, doing %s, hunger %d energy %d, failed %d" % [p.pname, g, p.household,
			p.vstate, lab, int(p.needs.hunger), int(p.needs.energy), p.stats.get("failed", 0)]
		track[p.pid] = t
	for pid in track.keys():
		if not seen.has(pid):
			print("LOST run %d day %d %05.2f: %s" % [runs, game.day, h, track[pid]["last"]])
			track.erase(pid)
			deaths += 1


## Follows each person's best skill: where it stands now and the day it first passed
## each level, so the pace of progression can be read off the report.
func _skills(p, g: String, h: float) -> void:
	var key := "%d:%d" % [runs, p.pid]
	if not skills.has(key):
		skills[key] = {"group": g, "top": 0.0, "career": -1.0, "level": -1, "reached": {}}
	var s: Dictionary = skills[key]
	s["group"] = g
	var top := 0.0
	for k in Defs.SKILLS:
		top = maxf(top, p.skills[k])
	s["top"] = top
	if p.job != null:
		s["career"] = p.skills[Defs.CAREERS[p.job.career]["skill"]]
		s["level"] = p.job.level
	for lv in SKILL_MARKS:
		if top >= lv and not s["reached"].has(lv):
			s["reached"][lv] = game.day + h / 24.0


func _hist(values: Array, edges: Array) -> String:
	var out := ""
	for i in edges.size():
		var lo: float = edges[i]
		var hi: float = edges[(i + 1) % edges.size()]
		var c := 0
		for v in values:
			if (lo < hi and v >= lo and v < hi) or (lo > hi and (v >= lo or v < hi)):
				c += 1
		out += "  %02d-%02d %3d%%" % [int(lo), int(hi), roundi(100.0 * c / maxi(1, values.size()))]
	return out


func _mean(values: Array) -> float:
	var s := 0.0
	for v in values:
		s += v
	return s / maxf(1.0, values.size())


func report() -> void:
	var total := 0.0
	for g in acc:
		total += acc[g]["hours"]
	print("\n======== BALANCE REPORT: %.0f person-days ========" % (total / 24.0))
	print("\nNEEDS: average level / % of time under 25 / % of time at zero")
	var head := "  %-8s %6s %5s" % ["", "days", "mood"]
	for n in Defs.NEEDS:
		head += "  %-12s" % n
	print(head)
	for g in GROUPS:
		if not acc.has(g):
			continue
		var a: Dictionary = acc[g]
		var line := "  %-8s %6.0f %5.0f" % [g, a["hours"] / 24.0, a["mood"] / a["hours"]]
		for n in Defs.NEEDS:
			var s: Array = a["needs"][n]
			line += "  %3.0f /%2.0f /%2.0f  " % [s[0] / a["hours"], 100.0 * s[1] / a["hours"], 100.0 * s[2] / a["hours"]]
		print(line)
	print("\nTIME USE: hours per day")
	for g in GROUPS:
		if not acc.has(g):
			continue
		var a: Dictionary = acc[g]
		var keys: Array = a["acts"].keys()
		keys.sort_custom(func(x, y): return a["acts"][x] > a["acts"][y])
		var line := "  %-8s" % g
		for k in keys:
			var hpd: float = a["acts"][k] / a["hours"] * 24.0
			if hpd >= 0.1:
				line += " %s %.1f," % [k, hpd]
		print(line)
		print("  %-8s awake %.0f%% of the time between midnight and 05:00" % ["", 100.0 * a["night_awake"] / maxf(0.01, a["night"])])
	print("\nSLEEP: when it starts (% of sessions by hour of day)")
	var edges := [6.0, 12.0, 17.0, 20.0, 22.0, 0.0, 3.0]
	for g in GROUPS:
		for kind in ["Sleep", "Nap", "Passed out"]:
			var ss := sleeps.filter(func(s): return s[0] == g and s[1] == kind and (s[3] >= 0.25 or not s[6]))
			if ss.is_empty():
				continue
			var fin := ss.filter(func(s): return s[6])
			var line := "  %-8s %-10s %4.2f/day %s | " % [g, kind, ss.size() / (acc[g]["hours"] / 24.0),
				_hist(ss.map(func(s): return s[2]), edges)]
			if fin.is_empty():
				line += "none finished"
			else:
				line += "%.1fh long, energy %2.0f -> %3.0f" % [_mean(fin.map(func(s): return s[3])),
					_mean(fin.map(func(s): return s[4])), _mean(fin.map(func(s): return s[5]))]
			print(line)
	print("\nMEALS: by hour of day")
	for g in GROUPS:
		for cooked in [true, false]:
			var ms := meals.filter(func(m): return m[0] == g and m[3] == cooked)
			if not ms.is_empty():
				print("  %-8s %-13s %4.2f/day %s | hunger after %2.0f" % [g, "cooked" if cooked else "snack as meal",
					ms.size() / (acc[g]["hours"] / 24.0), _hist(ms.map(func(m): return m[1]), [4.0, 10.0, 15.0, 22.0]),
					_mean(ms.map(func(m): return m[2]))])
	print("\nHOME FROM WORK OR SCHOOL: needs on arrival, then the first thing they do")
	for g in GROUPS:
		var rs := returns.filter(func(r): return r[0] == g)
		if rs.is_empty():
			continue
		var line := "  %-8s %3d returns |" % [g, rs.size()]
		for n in Defs.NEEDS:
			line += " %s %2.0f" % [n.substr(0, 3), _mean(rs.map(func(r): return r[2][n]))]
		print(line)
		var firsts := {}
		for r in rs:
			firsts[r[3]] = firsts.get(r[3], 0) + 1
		var keys: Array = firsts.keys()
		keys.sort_custom(func(x, y): return firsts[x] > firsts[y])
		line = "           first:"
		for k in keys.slice(0, 7):
			line += " %s %d%%," % [k if k != "" else "(nothing)", roundi(100.0 * firsts[k] / rs.size())]
		print(line)
	print("\nSKILLS: best skill at the end, then share of people past each level and the average day they got there")
	for g in GROUPS:
		var ps: Array = skills.values().filter(func(s): return s["group"] == g)
		if ps.is_empty():
			continue
		var line := "  %-8s %3d people | best %4.1f" % [g, ps.size(), _mean(ps.map(func(s): return s["top"]))]
		var cs := ps.filter(func(s): return s["career"] >= 0.0)
		if not cs.is_empty():
			line += ", career skill %4.1f, job level %3.1f" % [_mean(cs.map(func(s): return s["career"])), _mean(cs.map(func(s): return s["level"]))]
		line += " |"
		for lv in SKILL_MARKS:
			var got := ps.filter(func(s): return s["reached"].has(lv))
			line += "  L%d %3d%%" % [lv, roundi(100.0 * got.size() / ps.size())]
			if not got.is_empty():
				line += " day %4.1f" % _mean(got.map(func(s): return s["reached"][lv]))
		print(line)
	print("\nINCIDENTS per 100 person-days: ", incidents.keys().map(func(k): return "%s %.1f" % [k, incidents[k] * 2400.0 / total]),
		", people lost: %d" % deaths)
