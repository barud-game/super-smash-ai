class_name HurtboxData
extends Resource
## Hurtbox-capsule in fighter-lokale Melee-units (oorsprong = voeten, y omhoog, x gespiegeld met facing).

@export var a: Vector2 = Vector2.ZERO
@export var b: Vector2 = Vector2.ZERO
@export var radius: float = 3.0
## Per lichaamsdeel intangible (bv. been tijdens een aanval).
@export var intangible: bool = false


static func make(a_: Vector2, b_: Vector2, r_: float, intangible_: bool = false) -> HurtboxData:
	var h := HurtboxData.new()
	h.a = a_
	h.b = b_
	h.radius = r_
	h.intangible = intangible_
	return h


## Standaard: benen, romp, hoofd, afgeleid van de lichaamshoogte (units).
static func default_for_height(height: float) -> Array[HurtboxData]:
	var out: Array[HurtboxData] = []
	out.append(make(Vector2(0, height * 0.17), Vector2(0, height * 0.38), height * 0.17))
	out.append(make(Vector2(0, height * 0.45), Vector2(0, height * 0.62), height * 0.2))
	out.append(make(Vector2(0, height * 0.82), Vector2(0, height * 0.82), height * 0.15))
	return out


func world_a(origin: Vector2, facing: int) -> Vector2:
	return origin + Vector2(a.x * facing, a.y)


func world_b(origin: Vector2, facing: int) -> Vector2:
	return origin + Vector2(b.x * facing, b.y)
