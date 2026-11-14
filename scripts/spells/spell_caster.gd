class_name SpellCaster
extends RefCounted
## How a spell is cast: one instance per cast, driven by the Player while
## the Grimoire is held. LMB pressed -> start(), every physics frame while
## held -> update(), LMB released -> release(); cancel() when the cast is
## interrupted (Grimoire put away, spell switched, inventory opened, death).
## Extend this for a new way of casting and set it as a Spell's `caster`.

var spell: Spell
var player: Player


## Begin casting. Return false if the cast can't start (e.g. not enough mana).
func start(_spell: Spell, _player: Player) -> bool:
	return false


func update(_delta: float) -> void:
	pass


## LMB released: finish the cast (spend mana, fire...).
func release() -> void:
	pass


## Interrupted: undo anything the cast created, spend nothing.
func cancel() -> void:
	pass


## Mana the cast would cost if released now (shown on the mana bar).
func pending_cost() -> float:
	return 0.0
