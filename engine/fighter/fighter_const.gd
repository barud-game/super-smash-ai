class_name FighterConst
extends RefCounted
## Gedeelde constanten voor fighter-code.

## Marge voor float-vergelijkingen tegen stickdrempels.
const EPS: float = 0.000001

# --- Ledge / respawn (M2) ---
## ⚠️ Stick-y <= -deze waarde in de lucht voorkomt een ledge grab (Melee: x480, waarde onbekend).
const LEDGE_GRAB_DOWN_BLOCK: float = 0.6875
## ⚠️ Getup: stick richting de stage >= dit; stick omhoog >= LEDGE_UP_THRESHOLD.
const LEDGE_GETUP_THRESHOLD: float = 0.5
const LEDGE_UP_THRESHOLD: float = 0.6875
## ⚠️ Loslaten: stick omlaag of van de stage af >= dit.
const LEDGE_DROP_THRESHOLD: float = 0.6875
## ⚠️ Respawn-platform: max wachttijd (5 s), minimum voordat input telt, standaard invincibility (2 s).
const REBIRTH_MAX_FRAMES: int = 300
const REBIRTH_MIN_FRAMES: int = 20
const REBIRTH_INVINCIBLE_FRAMES: int = 120
