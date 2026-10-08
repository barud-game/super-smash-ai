class_name Pose
extends RefCounted
## Eén animatie/pose: keyframes met rotaties (graden) en offsets (px) per bot, op frames (60 Hz).
## Puur visueel. Zie docs/rig.md voor het JSON-formaat.
##
## Rotaties: Godot-conventie, positief = kloksgewijs op het scherm (character kijkt naar rechts).
##   romp/hoofd: + = voorover. arm/been (hangt omlaag): + = naar achteren zwaaien. knie: shin + = knie buigt.
##   voet (wijst naar voren): + = neus omlaag.

var name: String = ""
var length: float = 1.0           ## duur in frames (bij loop: de periode)
var loop: bool = false
var blend: float = 4.0            ## frames crossfade vanuit de vorige pose bij play()
var spline: bool = false          ## Catmull-Rom i.p.v. lineair tussen keys
var times: PackedFloat32Array = PackedFloat32Array()
var rot: Array = []               ## per key: Dictionary bone -> graden
var off: Array = []               ## per key: Dictionary bone -> Vector2
var bones: Array = []             ## alle bot-namen die deze pose aanstuurt


static func from_dict(pose_name: String, d: Dictionary) -> Pose:
	var p := Pose.new()
	p.name = pose_name
	p.loop = bool(d.get("loop", false))
	p.blend = float(d.get("blend", 4))
	p.spline = String(d.get("interp", "spline" if p.loop else "linear")) == "spline"
	var keys: Array = d.get("keys", [])
	var seen: Dictionary = {}
	for k: Dictionary in keys:
		var r: Dictionary = {}
		var o: Dictionary = {}
		for b: String in k.get("r", {}):
			r[b] = float(k["r"][b])
		for b: String in k.get("o", {}):
			var a: Array = k["o"][b]
			o[b] = Vector2(float(a[0]), float(a[1]))
		if k.has("drop"):
			_apply_drop(float(k["drop"]), r, o)
		for b in r:
			seen[b] = true
		for b in o:
			seen[b] = true
		p.times.append(float(k.get("t", 0)))
		p.rot.append(r)
		p.off.append(o)
	p.bones = seen.keys()
	var last_t: float = p.times[p.times.size() - 1] if p.times.size() > 0 else 1.0
	p.length = maxf(1.0, float(d.get("length", last_t)))
	return p


## Hip zakt `drop` px; beide benen krijgen automatisch hoeken zodat de voeten onder de heup blijven staan
## en plat op de grond (twee-botten-IK, verticaal). Expliciete waarden in de key winnen.
static func _apply_drop(drop: float, r: Dictionary, o: Dictionary) -> void:
	var target: float = Rig.THIGH_LEN + Rig.SHIN_LEN - drop
	var a: float = Rig.THIGH_LEN
	var b: float = Rig.SHIN_LEN
	var theta: float = 0.0   # dijhoek naar voren
	var lo: float = 0.0
	var hi: float = PI * 0.5
	for i in 40:
		theta = (lo + hi) * 0.5
		var sin_beta: float = clampf(a * sin(theta) / b, -1.0, 1.0)
		var height: float = a * cos(theta) + b * cos(asin(sin_beta))
		if height > target:
			lo = theta
		else:
			hi = theta
	var beta: float = asin(clampf(a * sin(theta) / b, -1.0, 1.0))   # scheenhoek (wereld), richting achteren
	var th: float = -rad_to_deg(theta)
	var sh: float = rad_to_deg(theta + beta)
	var ft: float = -rad_to_deg(beta)
	for side in ["_l", "_r"]:
		if not r.has("thigh" + side):
			r["thigh" + side] = th
		if not r.has("shin" + side):
			r["shin" + side] = sh
		if not r.has("foot" + side):
			r["foot" + side] = ft
	if not o.has("hip"):
		o["hip"] = Vector2(0, drop)
	else:
		o["hip"] = Vector2(o["hip"].x, o["hip"].y + drop)


## Waarden op tijd t (frames). Geeft {"r": {bone: graden}, "o": {bone: Vector2}} voor alle bones van de pose.
func sample(t: float) -> Dictionary:
	var n: int = times.size()
	var out_r: Dictionary = {}
	var out_o: Dictionary = {}
	if n == 0:
		return {"r": out_r, "o": out_o}
	if loop:
		t = fposmod(t, length)
	else:
		t = clampf(t, 0.0, times[n - 1])
	# zoek segment [i, i+1]
	var i: int = 0
	var j: int = 0
	var u: float = 0.0
	if n == 1:
		i = 0
		j = 0
	else:
		var found: bool = false
		for s in n - 1:
			if t >= times[s] and t <= times[s + 1]:
				i = s
				j = s + 1
				var span: float = times[j] - times[i]
				u = 0.0 if span <= 0.0 else (t - times[i]) / span
				found = true
				break
		if not found:
			if loop and t > times[n - 1]:
				# wrap-segment: laatste key -> eerste key (+length)
				i = n - 1
				j = 0
				var span2: float = times[0] + length - times[n - 1]
				u = 0.0 if span2 <= 0.0 else (t - times[n - 1]) / span2
			else:
				i = 0
				j = 0
	for b: String in bones:
		out_r[b] = _chan_r(b, i, j, u, n)
		out_o[b] = _chan_o(b, i, j, u, n)
	return {"r": out_r, "o": out_o}


func _idx(i: int, n: int) -> int:
	if loop:
		return posmod(i, n)
	return clampi(i, 0, n - 1)


func _chan_r(b: String, i: int, j: int, u: float, n: int) -> float:
	var p1: float = float(rot[i].get(b, 0.0))
	var p2: float = float(rot[j].get(b, 0.0))
	if not spline or n < 3:
		return lerpf(p1, p2, u)
	var p0: float = float(rot[_idx(i - 1, n)].get(b, 0.0))
	var p3: float = float(rot[_idx(j + 1, n)].get(b, 0.0))
	return _cr(p0, p1, p2, p3, u)


func _chan_o(b: String, i: int, j: int, u: float, n: int) -> Vector2:
	var p1: Vector2 = off[i].get(b, Vector2.ZERO)
	var p2: Vector2 = off[j].get(b, Vector2.ZERO)
	if not spline or n < 3:
		return p1.lerp(p2, u)
	var p0: Vector2 = off[_idx(i - 1, n)].get(b, Vector2.ZERO)
	var p3: Vector2 = off[_idx(j + 1, n)].get(b, Vector2.ZERO)
	return Vector2(_cr(p0.x, p1.x, p2.x, p3.x, u), _cr(p0.y, p1.y, p2.y, p3.y, u))


static func _cr(p0: float, p1: float, p2: float, p3: float, u: float) -> float:
	var u2: float = u * u
	var u3: float = u2 * u
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u3)
