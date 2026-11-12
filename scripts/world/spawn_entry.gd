@tool
class_name SpawnEntry
extends Resource
## One thing a SpawnArea can spawn, and how often. Weights are relative:
## 90 and 10 mean 90% / 10%; 3 and 1 mean 75% / 25%.

@export var scene: PackedScene
@export_range(0.0, 1000.0, 0.1, "or_greater") var weight: float = 1.0
