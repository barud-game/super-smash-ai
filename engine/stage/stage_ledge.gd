class_name StageLedge
extends Resource
## Een grijpbare rand in Melee-units. `side` = kant van de stage waar de ledge zit:
## -1 = linker rand (fighter hangt links van het punt), +1 = rechter rand.

@export var position: Vector2 = Vector2.ZERO
@export var side: int = 1
