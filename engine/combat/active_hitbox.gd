class_name ActiveHitbox
extends RefCounted
## Een hitbox die op dit frame actief is, in wereldcoördinaten. Invoer voor HitResolver.

var data: HitboxData
var owner: int = 0          ## fighter-id van de aanvaller
var instance: int = 0       ## unieke move-instantie (teller per uitgevoerde aanval)
var pos: Vector2 = Vector2.ZERO
var facing: int = 1
var damage: float = 0.0     ## na staling e.d.; standaard data.damage
var late: bool = false
## Grab-hitbox (M4): raakt alleen hurtboxes (negeert shield), clankt niet, geeft HitEvent.Kind.GRAB i.p.v. knockback.
var is_grab: bool = false


static func make(d: HitboxData, owner_: int, instance_: int, world_pos: Vector2, facing_: int, late_: bool = false) -> ActiveHitbox:
	var h := ActiveHitbox.new()
	h.data = d
	h.owner = owner_
	h.instance = instance_
	h.pos = world_pos
	h.facing = facing_
	h.damage = d.damage
	h.late = late_
	return h
