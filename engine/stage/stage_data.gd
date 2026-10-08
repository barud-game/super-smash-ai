class_name StageData
extends Resource
## Pure stage-data in Melee-units (x rechts, y OMHOOG, y=0 = grondniveau).
## Rects zijn Rect2 met position = (links, onder) en size = (breedte, hoogte); onder < boven.
## Zie docs/stage.md voor bronnen.

@export var stage_name: String = ""
@export var ground_segments: Array[StageSegment] = []
@export var ledges: Array[StageLedge] = []
@export var blast_zone: Rect2 = Rect2()
@export var camera_bounds: Rect2 = Rect2()
@export var spawns: Array[Vector2] = []
@export var respawns: Array[Vector2] = []


## Meest linkse x van alle grondsegmenten.
func left() -> float:
	var m: float = INF
	for s: StageSegment in ground_segments:
		m = minf(m, minf(s.a.x, s.b.x))
	return m


## Meest rechtse x van alle grondsegmenten.
func right() -> float:
	var m: float = -INF
	for s: StageSegment in ground_segments:
		m = maxf(m, maxf(s.a.x, s.b.x))
	return m
