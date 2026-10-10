extends TplStallFall
## Down-B "Stumble Kick": stall_fall met een grondvariant. Grond: korte startup, dan een glijdende trap (slide,
## rol "slide", stopt aan de rand). Lucht: gewone stall_fall (korte stall, schuine duiktrap omlaag, rol "fall",
## landing-shockwave + vaste landing lag); ledge-snap staat tijdens stall én val aan zodat de duik ook terug naar
## de ledge helpt. Geen helpless na afloop. Het sjabloon doet in de lucht alles zelf; hier zit alleen de grondtak.


func start() -> void:
	# Geen ground_hop: op de grond glijdt hij.
	set_phase("startup")


func step() -> void:
	if started_air:
		super.step()
		return
	match phase:
		"startup":
			if phase_frame >= startup_frames():
				set_phase("slide")
		"slide":
			if phase_frame >= maxi(pi_("slide_frames", 18), 1):
				set_phase("end")
		"end":
			if phase_frame >= pi_("endlag", 24):
				finish()


func phys() -> void:
	if not started_air and f.grounded:
		if phase == "slide":
			var n: float = float(maxi(pi_("slide_frames", 18), 1))
			var t: float = clampf(float(phase_frame) / n, 0.0, 1.0)
			f.gr_vel = f.facing * lerpf(pf("slide_speed", 3.2), pf("slide_speed_end", 1.2), t)
		else:
			f.apply_ground_friction()
		return
	if started_air and not f.grounded and (phase == "startup" or phase == "stall"):
		# Echte stall: verticale snelheid dooft uit naar een trage zakking (het sjabloon laat hem anders vallen).
		f.vel.y = move_toward(f.vel.y, -pf("stall_sink", 0.12), 0.2)
		f.vel.x = move_toward(f.vel.x, 0.0, 0.05)
		return
	super.phys()


func hitboxes() -> Array[ActiveHitbox]:
	if started_air:
		return super.hitboxes()
	if phase == "slide":
		return role_boxes("slide", phase_frame)
	return []


func ledge_snap_active() -> bool:
	if started_air and def.ledge_snap == "during" and (phase == "fall" or phase == "stall" or phase == "end"):
		return true
	return super.ledge_snap_active()


func default_pose() -> String:
	if started_air:
		return super.default_pose()
	if phase == "slide":
		return "pep_slide_kick"
	return "crouch"
