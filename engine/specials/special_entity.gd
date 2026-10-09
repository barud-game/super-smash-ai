class_name SpecialEntity
extends Node2D
## Basis voor zelfstandige special-objecten (projectiel, trap, tether-haak): owner-identiteit, eigen hitboxes,
## lifetime, hitlag, opruimen. Getickt door SpecialWorld (die zelf bij Sim geregistreerd is), in spawn-volgorde.
## Positie in Melee-units (y omhoog); de node-positie is alleen presentatie. Zie docs/specials.md.

## ActiveHitbox.instance van entities begint hier (botst nooit met Fighter.move_instance).
const INSTANCE_BASE: int = 1000000

var world: SpecialWorld
var owner_fighter: Fighter
## Fighter-id (= Fighter.player) van de eigenaar; wisselt bij reflect.
var owner_id: int = -1
var source_slot: String = ""
var kind: String = "entity"
## Spawn-volgorde binnen de wereld (deterministisch).
var serial: int = 0
## Hit-instantie voor HitResolver (owner:instance:group:target). Nieuw na een reflect.
var instance: int = 0
var pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var facing: int = 1
var age: int = 0
## Frames tot verdwijnen (-1 = onbeperkt).
var lifetime: int = 120
var alive: bool = true
var kill_reason: String = ""
## Eigen hitlag (bevriest alleen deze entity).
var hitlag: int = 0
## Hitboxes relatief aan `pos` (offset.x gespiegeld met facing). Frames t.o.v. `hit_clock()`;
## end_frame < 0 = altijd actief.
var hit_list: Array[HitboxData] = []
var damage_mult: float = 1.0
var already_hit: Dictionary = {}
var reflectable: bool = true
var absorbable: bool = true
## Clankt niet met andere entities (wel reflect/absorb).
var transcendent: bool = false
var reflect_count: int = 0
## Blijft bestaan als de eigenaar sterft (trap met clear_on_owner_death = false).
var survives_owner_death: bool = false
## Teken-straal (units) en kleur (presentatie).
var draw_radius: float = 3.0
var color: Color = Color(1.0, 0.8, 0.3)


func setup_entity(w: SpecialWorld, owner_: Fighter, slot: String) -> void:
	world = w
	owner_fighter = owner_
	owner_id = owner_.player if owner_ != null else -1
	source_slot = slot
	facing = owner_.facing if owner_ != null else 1


## Eén sim-frame (door SpecialWorld). Subclasses: super.tick() eerst aanroepen; false = bevroren/dood.
func tick() -> bool:
	if not alive:
		return false
	if hitlag > 0:
		hitlag -= 1
		return false
	age += 1
	if lifetime >= 0 and age > lifetime:
		kill("lifetime")
		return false
	return true


## Frame waartegen hitbox-vensters worden gemeten.
func hit_clock() -> int:
	return age


func hitboxes_live() -> bool:
	return alive and hitlag <= 0


func active_hitboxes() -> Array[ActiveHitbox]:
	var out: Array[ActiveHitbox] = []
	if not hitboxes_live():
		return out
	var t: int = hit_clock()
	for h: HitboxData in hit_list:
		if h.end_frame >= 0 and not h.is_active(t):
			continue
		var a: ActiveHitbox = ActiveHitbox.make(h, owner_id, instance, MoveData.world_pos(h, pos, facing), facing)
		a.damage = h.damage * damage_mult
		out.append(a)
	return out


## Hoogste damage van de actieve hitboxes (clank-regel).
func clank_damage() -> float:
	var m: float = 0.0
	for h: HitboxData in hit_list:
		m = maxf(m, h.damage * damage_mult)
	return m


## Botsingsstraal voor reflect/absorb/clank-tests.
func body_radius() -> float:
	var r: float = draw_radius
	for h: HitboxData in hit_list:
		r = maxf(r, h.radius)
	return r


## Treffer op een fighter (HIT). Subclass bepaalt pierce/multi-hit.
func on_hit_target(_ev: HitEvent) -> void:
	pass


## Treffer op een shield.
func on_shield(_ev: HitEvent) -> void:
	kill("shield")


## Wordt gereflecteerd: richting om, eigenaar wisselt, damage/snelheid geschaald, lifetime reset.
## Geeft false als de reflect-limiet bereikt is (entity verdwijnt dan).
func reflect(by: Fighter, dmg_mult: float, spd_mult: float, limit: int) -> bool:
	reflect_count += 1
	if limit >= 0 and reflect_count > limit:
		kill("reflect_limit")
		return false
	owner_fighter = by
	owner_id = by.player
	vel = Vector2(-vel.x, vel.y) * spd_mult
	facing = -facing
	damage_mult *= dmg_mult
	age = 0
	already_hit.clear()
	if world != null:
		instance = world.next_instance()
	return true


func kill(reason: String) -> void:
	if not alive:
		return
	alive = false
	kill_reason = reason
	visible = false


func _process(_delta: float) -> void:
	# Alleen presentatie.
	position = Units.to_px(pos)
	queue_redraw()


func _draw() -> void:
	if not alive:
		return
	var r: float = body_radius() * Units.UNIT_TO_PX
	draw_circle(Vector2.ZERO, r, Color(color, 0.85))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 20, Color(1, 1, 1, 0.7), 2.0)
