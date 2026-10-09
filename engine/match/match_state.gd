class_name MatchState
extends RefCounted
## Pure wedstrijdlogica (geen nodes, geen Sim): stocks, falls/KO's/SD's, timer, einde en tiebreak.
## De MatchController voedt dit met events en leest de uitkomst. Alles in sim-frames, deterministisch.

const NO_ONE: int = -1

var rules: MatchRules = MatchRules.new()
## Training: oneindige stocks, geen timer, het einde komt nooit.
var training: bool = false
var stocks: Array[int] = [4, 4]
var kos: Array[int] = [0, 0]
var falls: Array[int] = [0, 0]
var sds: Array[int] = [0, 0]
## Gespeelde frames (alleen telling tijdens PLAYING).
var elapsed: int = 0
var sudden_death: bool = false


func start(new_rules: MatchRules, is_training: bool) -> void:
	rules = new_rules
	training = is_training
	stocks = [rules.stocks, rules.stocks]
	kos = [0, 0]
	falls = [0, 0]
	sds = [0, 0]
	elapsed = 0
	sudden_death = false


## Speler `p` verliest een stock. `by` = tegenstander die de laatste klap gaf, of NO_ONE voor een zelfvernietiging.
## Geeft true als p daarmee uitgeschakeld is. In training gaat er nooit een stock af.
func lose_stock(p: int, by: int) -> bool:
	falls[p] += 1
	if by == NO_ONE or by == p:
		sds[p] += 1
	else:
		kos[by] += 1
	if training:
		return false
	stocks[p] = maxi(stocks[p] - 1, 0)
	return stocks[p] <= 0


func tick() -> void:
	elapsed += 1


## Resterende frames, of -1 zonder tijdslimiet (training, sudden death, 0 minuten).
func time_left() -> int:
	if training or sudden_death or rules.time_frames() <= 0:
		return -1
	return maxi(rules.time_frames() - elapsed, 0)


func time_up() -> bool:
	return time_left() == 0


func begin_sudden_death() -> void:
	sudden_death = true
	stocks = [1, 1]
	elapsed = 0


## Is de wedstrijd afgelopen? `percents` = huidige % per speler (voor de tiebreak bij tijd-op).
## Resultaat: {over, winner (-1 = geen/gelijk), reason ("ko" | "time" | "draw" | ""), sudden_death (bool)}.
func evaluate(percents: Array[float]) -> Dictionary:
	var out: Dictionary = {"over": false, "winner": NO_ONE, "reason": "", "sudden_death": false}
	if training:
		return out
	var alive: Array[int] = []
	for p in 2:
		if stocks[p] > 0:
			alive.append(p)
	if alive.size() == 1:
		out["over"] = true
		out["winner"] = alive[0]
		out["reason"] = "ko"
		return out
	if alive.is_empty():
		return _tie(out)
	if time_up():
		out["reason"] = "time"
		if stocks[0] != stocks[1]:
			out["over"] = true
			out["winner"] = 0 if stocks[0] > stocks[1] else 1
		elif absf(percents[0] - percents[1]) > 0.01:
			out["over"] = true
			out["winner"] = 0 if percents[0] < percents[1] else 1
		else:
			return _tie(out)
	return out


func _tie(out: Dictionary) -> Dictionary:
	if rules.sudden_death:
		out["sudden_death"] = true
	else:
		out["over"] = true
		out["reason"] = "draw"
	return out
