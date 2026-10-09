class_name HitboxData
extends Resource
## Eén hitbox van een move (Melee-units, y omhoog, relatief aan de fighter-oorsprong = voeten;
## x wordt gespiegeld met facing). Zie docs/combat.md.

enum Element { NORMAL, FIRE, ELECTRIC, ICE, SLASH }

## Identiteit. Laagste id wint als meerdere hitboxen van één move tegelijk raken (prioriteit).
@export var id: int = 0
## Hit-groep: per (move-instantie, groep, doelwit) raakt maar één keer. Standaard 0 = hele move één keer;
## multi-hit moves geven elke hit een eigen groep.
@export var group: int = 0
## Actief op frames start_frame..end_frame (inclusief), gemeten in move-frames (0-based, = state_frame).
@export var start_frame: int = 0
@export var end_frame: int = 0
## Vanaf dit frame is de hit "late" (andere damage-waarden regelt de move zelf; dit is alleen voor debug-kleur). -1 = nooit.
@export var late_from: int = -1
@export var offset: Vector2 = Vector2.ZERO
@export var radius: float = 3.0
@export var damage: float = 5.0
## Launch-hoek in graden t.o.v. kijkrichting (0 = vooruit, 90 = omhoog, 361 = Sakurai-hoek).
@export var angle: float = 361.0
@export var base_kb: float = 0.0
@export var kb_growth: float = 100.0
## > 0 = set knockback (WDSK): kb_growth wordt genegeerd, deze waarde vervangt het damage/percentage-deel.
@export var set_kb: float = 0.0
@export var element: Element = Element.NORMAL
## Extra schade aan de shield bovenop damage.
@export var shield_damage: float = 0.0
@export var hitlag_mult: float = 1.0
## Clank/rebound met andere hitboxen.
@export var clank: bool = true
## Disjoint: raakt geen hurtbox van de eigenaar (informatief; resolver gebruikt het niet).
@export var disjoint: bool = false
## Alleen raken als doelwit op de grond / in de lucht is (beide uit = altijd).
@export var grounded_only: bool = false
@export var aerial_only: bool = false
## Grabs: negeren shield (raken de hurtbox gewoon).
@export var ignores_shield: bool = false


func is_active(frame: int) -> bool:
	return frame >= start_frame and frame <= end_frame


func is_late(frame: int) -> bool:
	return late_from >= 0 and frame >= late_from
