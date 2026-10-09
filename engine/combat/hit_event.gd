class_name HitEvent
extends RefCounted
## Resultaat van de resolver; de fighter past het later toe. Geen side effects hier.

enum Kind { HIT, SHIELD, CLANK, GRAB }

var kind: Kind = Kind.HIT
var attacker: int = -1
var defender: int = -1          ## bij CLANK: de eigenaar van de andere hitbox
var hitbox: ActiveHitbox
var other_hitbox: ActiveHitbox  ## alleen CLANK
var key: String = ""            ## toevoegen aan de already_hit-set van de aanvaller
var damage: float = 0.0
var attacker_hitlag: int = 0
var defender_hitlag: int = 0
var knockback: KnockbackResult  ## alleen HIT
var shield_stun: int = 0        ## alleen SHIELD
var shield_damage: float = 0.0  ## alleen SHIELD: ruwe schade (damage + hitbox.shield_damage); de verdediger past de shield-multiplier toe
## CLANK: welke kanten rebounden (bij damage-verschil >= 9 alleen de zwakkere).
var attacker_rebounds: bool = false
var defender_rebounds: bool = false

## Hitfall (docs/movement.md, Rivals-aanpak): de aanvaller mag tijdens zijn hitlag fast fallen na een
## echte treffer (HIT), niet na een treffer op een shield of een clank.
var attacker_hitfall_allowed: bool = false


func is_shield_hit() -> bool:
	return kind == Kind.SHIELD
