class_name KnockbackResult
extends RefCounted

var kb: float = 0.0             ## uiteindelijke knockback-waarde (na crouch cancel)
var angle: float = 0.0          ## wereldhoek in graden (na 361-regel en facing-spiegeling), 0 = rechts, 90 = omhoog
var hitstun: int = 0            ## frames
var speed: float = 0.0          ## launch-snelheid (units/frame) = kb * 0.03
var launch_vel: Vector2 = Vector2.ZERO  ## units/frame, y omhoog
var tumble: bool = false        ## KB >= TUMBLE_KB: geen actie tot hitstun voorbij (DamageFly)
var stays_grounded: bool = false ## grounded doelwit blijft op de grond (glijdt) i.p.v. gelanceerd te worden
var crouch_cancelled: bool = false
var set_kb: bool = false
