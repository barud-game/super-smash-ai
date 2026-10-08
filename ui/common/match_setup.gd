extends Node
## Autoload `MatchSetup`: de keuzes uit de menu's, bedoeld voor de match-scène (M6).
## Alleen data. `picks[p]` = character-id van speler p (0 = P1). In training is picks[1] de dummy.

const MODE_FIGHT: String = "fight"
const MODE_TRAINING: String = "training"

var mode: String = MODE_FIGHT
var picks: Array[String] = ["", ""]
## True als de keuze via Random kwam (alleen voor weergave).
var was_random: Array[bool] = [false, false]
var rules: MatchRules = MatchRules.new()


func reset() -> void:
	mode = MODE_FIGHT
	picks = ["", ""]
	was_random = [false, false]
	rules = MatchRules.new()
