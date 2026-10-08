class_name StageSegment
extends Resource
## Eén grondsegment (lijnstuk) in Melee-units. Alleen data, geen physics.

enum Type { SOLID, PLATFORM }

@export var a: Vector2 = Vector2.ZERO
@export var b: Vector2 = Vector2.ZERO
@export var type: Type = Type.SOLID
