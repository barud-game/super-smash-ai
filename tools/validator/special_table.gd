extends RefCounted
## Special-regels als data (docs/special-sjablonen.md: instellingen-bereiken + prijs-richtlijnen, director-besluiten).
## BIJ ELKE WIJZIGING IN docs/special-sjablonen.md MOET DIT BESTAND MEE (en andersom). Zie docs/specials.md.
## Bereiken: [min, max] (inclusief). Buiten bereik = FAIL. ⚠️ = eigen keuze (doc noemt geen bruikbaar bereik).

const MAX_TEMPLATES: int = 2
## Director-besluit 1: combinatie van 2 sjablonen = +2 utility.
const COMBO_UTILITY: int = 2
## Director-besluit 4: helpless_after = false bij een lucht-recovery kost +2 utility.
const NO_HELPLESS_UTILITY: int = 2
## Recovery-utility vanaf deze waarde (één bruikbare recovery per character, §0.5).
const RECOVERY_MIN_UTILITY: int = 5
## Score-afwijking t.o.v. de prijs-richtlijn: >= WARN_DIFF = WARN, >= FAIL_DIFF = FAIL.
const WARN_DIFF: int = 2
const FAIL_DIFF: int = 3
## Sjablonen die een recovery kunnen zijn (helpless-regel geldt bij up/side in de lucht).
const RECOVERY_TEMPLATES: Array[String] = ["teleport", "rising_multi", "dash_strike", "tether", "spin", "stall_fall"]
## Verplichte telegraaf (director-besluit 3).
const TELEGRAPH_TEMPLATES: Array[String] = ["charge", "buff", "trap"]

## Gedeelde instellingen (§0.2).
const SHARED: Dictionary = {
	"startup": [3, 40], "active_frames": [1, 60], "endlag": [0, 60], "momentum_scale": [0.0, 1.0],
	"gravity_scale": [0.0, 1.5], "steer_max_angle": [0.0, 90.0],
}
## SpecialDef-velden.
const DEF_FIELDS: Dictionary = {
	"landing_lag": [0, 40], "ledge_snap_range": [0.0, 40.0], "air_use_limit": [-1, 3],
}

## Per sjabloon (instellingen-tabellen). Sleutels met een _air/_ground-variant worden ook gecontroleerd.
const TEMPLATE: Dictionary = {
	"projectile": {"speed": [0.5, 6.0], "angle": [-90.0, 90.0], "gravity": [0.0, 0.1], "bounce_count": [0, 4],
		"lifetime": [20, 300], "max_range": [0.0, 600.0], "size": [3.0, 40.0], "count": [1, 5],
		"spread_angle": [0.0, 60.0], "max_alive": [1, 5], "hitlag_mult": [0.5, 1.0], "damage": [0.0, 30.0]},
	"charge": {"startup": [5, 12], "charge_min": [0, 20], "charge_max": [30, 180], "charge_stages": [0, 4],
		"keep_frames": [-1, 300], "scale_damage": [1.0, 6.0], "scale_kb": [1.0, 3.0], "scale_size": [1.0, 3.0],
		"scale_speed": [1.0, 3.0]},
	"teleport": {"distance": [40.0, 260.0], "vanish_frames": [2, 20], "arrival_frames": [0, 10]},
	"rising_multi": {"rise_speed": [1.0, 5.0], "rise_distance": [0.0, 250.0], "rise_frames": [10, 40],
		"rise_angle": [60.0, 90.0], "h_speed_max": [0.0, 2.0], "hits": [1, 10], "interval": [2, 6],
		"multi_damage": [0.0, 3.0], "finisher_damage": [0.0, 15.0]},
	"counter": {"window_frames": [8, 30], "min_damage": [0.0, 10.0], "counter_mult": [1.0, 1.5],
		"counter_cap": [20.0, 40.0], "counter_cooldown": [0, 180], "whiff_endlag": [20, 50]},
	"reflector": {"startup": [3, 10], "reflect_frames": [8, 40], "damage_mult": [1.0, 2.0],
		"speed_mult": [1.0, 2.0], "reflect_radius": [5.0, 35.0]},
	"absorber": {"startup": [4, 12], "absorb_frames": [10, 40], "max_heal_per_use": [0.0, 25.0],
		"absorb_radius": [5.0, 35.0]},
	"command_grab": {"grab_active": [2, 6], "grab_radius": [2.0, 35.0], "hold_frames": [6, 40],
		"miss_endlag": [20, 50]},
	"dash_strike": {"dash_speed": [2.0, 8.0], "dash_frames": [6, 25], "dash_distance": [0.0, 250.0],
		"dash_angle": [-60.0, 60.0]},
	"stall_fall": {"stall_frames": [10, 50], "stall_gravity": [0.0, 0.2], "fall_speed": [3.0, 6.0]},
	"multi_jump": {"flap_power": [1.5, 4.0], "power_decay": [0.0, 0.5], "h_drift": [0.5, 2.0],
		"flap_frames": [8, 20], "hover_frames": [20, 180], "hover_gravity_scale": [0.0, 0.3],
		"glide_fall_speed": [0.3, 1.0], "glide_h_speed": [1.0, 3.0], "cooldown_between": [0, 12]},
	"tether": {"max_length": [40.0, 300.0], "extend_speed": [5.0, 15.0], "pull_speed": [2.0, 10.0]},
	"trap": {"arm_time": [0, 90], "lifetime": [-1, 900], "max_alive": [1, 4], "explode_damage": [0.0, 25.0]},
	"buff": {"duration": [-1, 900], "cooldown": [0, 1800], "transform_frames": [5, 15]},
	"command_dash": {"distance": [40.0, 180.0], "move_frames": [8, 20], "window": [6, 20], "input_buffer": [2, 6],
		"chain_limit": [1, 3]},
	"spin": {"spin_frames": [15, 90], "hit_every": [3, 8], "radius": [4.0, 35.0], "h_speed": [0.0, 3.0],
		"rise_speed": [0.0, 2.5], "hold_extend": [0, 3]},
}
## Buff-modifiers: elk 0.6–1.6 (§14).
const MODIFIER_RANGE: Array = [0.6, 1.6]
## multi_jump: count = air_use_limit 1–6.
const MULTI_JUMP_COUNT: Array = [1, 6]


## Drempeltabel -> score: eerste rij [max_waarde, score] waarvoor waarde <= max_waarde.
static func band(value: float, rows: Array, fallback: int) -> int:
	for r: Array in rows:
		if value <= float(r[0]):
			return int(r[1])
	return fallback


# --- prijs-richtlijn (per as; alleen wat uit de parameters volgt) -----------------------------

## Snelheid: eerste actieve frame (1-based = startup + 1).
const SPEED_PROJECTILE: Array = [[6, 5], [10, 4], [15, 3], [20, 2]]      # anders 1
const SPEED_TELEPORT: Array = [[8, 5], [14, 4], [20, 3]]                   # anders 2
const SPEED_RISING: Array = [[6, 5], [10, 4], [16, 3]]                     # anders 2
const SPEED_COUNTER: Array = [[6, 5], [10, 4], [15, 3]]                    # anders 2
const SPEED_GRAB: Array = [[9, 5], [15, 4], [22, 3]]                       # anders 2
const SPEED_REFLECT: Array = [[5, 5], [8, 4], [12, 3]]                     # anders 2
const SPEED_CHARGE_FULL: Array = [[40, 4], [80, 3]]                        # anders 2
## Bereik.
const RANGE_PROJECTILE: Array = [[75, 1], [150, 2], [300, 3], [500, 4]]    # anders 5 (afstand units)
const RANGE_TELEPORT: Array = [[59, 1], [110, 2], [160, 3], [220, 4]]      # anders 5
const RANGE_RISING: Array = [[79, 1], [120, 2], [180, 3]]                  # anders 4
const RANGE_DASH: Array = [[69, 1], [120, 2], [180, 3], [240, 4]]          # anders 5
const RANGE_TETHER: Array = [[79, 2], [150, 3], [220, 4]]                  # anders 5
const RANGE_GRAB: Array = [[29, 1], [50, 2]]                               # anders 3
const RANGE_REFLECT: Array = [[34, 1], [55, 2]]                            # anders 3 (diameter)
## Veiligheid (endlag).
const SAFETY_PROJECTILE: Array = [[20, 5], [28, 4]]                        # anders 2
const SAFETY_COUNTER: Array = [[25, 4], [40, 3]]                           # anders 1
const SAFETY_GRAB: Array = [[25, 4], [40, 2]]                              # anders 1
const SAFETY_REFLECT: Array = [[20, 4], [30, 3]]                           # anders 2
