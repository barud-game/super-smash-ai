class_name MatchResult
extends RefCounted
## Uitslag van de laatste wedstrijd, voor het results-scherm. `last` blijft staan tot de volgende match.

static var last: MatchResult = null

## 0/1 = winnaar, -1 = gelijkspel.
var winner: int = -1
## "ko", "time" of "draw".
var reason: String = "ko"
var sudden_death: bool = false
var picks: Array[String] = ["", ""]
var stocks: Array[int] = [0, 0]
var percents: Array[float] = [0.0, 0.0]
var kos: Array[int] = [0, 0]
var falls: Array[int] = [0, 0]
var sds: Array[int] = [0, 0]
## Gespeelde frames.
var frames: int = 0
