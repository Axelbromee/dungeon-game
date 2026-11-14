class_name HUD
extends CanvasLayer
## On-screen HUD: mana bar, crosshair, interaction prompt, pickup toasts,
## the spell wheel and the inventory UI. Listens to the Player's signals. While charging, a pale
## mana segment shows what the shot will cost on release.

## Left empty, the HUD uses the scene's Player (the node in group "player").
@export var player: Player
## Higher = bars catch up faster.
@export var smoothing: float = 12.0
## Seconds a pickup/drop message stays fully visible before fading.
@export var toast_hold_time: float = 1.2
## Seconds a station's info panel stays up (it also closes on E / Esc).
@export var info_duration: float = 5.0

## Seconds the pale "chip" segment waits before draining after damage.
@export var health_chip_delay: float = 0.4
@export var stamina_color: Color = Color(0.55, 0.85, 0.25)
## Stamina bar colour while exhausted (locked until it refills).
@export var stamina_exhausted_color: Color = Color(0.95, 0.4, 0.2)

var _stamina: float = 0.0
var _max_stamina: float = 1.0
var _shown_stamina: float = 0.0
var _stamina_fill: StyleBoxFlat

var _toast_tween: Tween
var _flash_tween: Tween
var _info_timer: float = 0.0

var _health: float = 0.0
var _max_health: float = 1.0
var _shown_health_chip: float = 0.0
var _chip_delay_timer: float = 0.0

var _mana: float = 0.0
var _max_mana: float = 1.0
var _pending_cost: float = 0.0
var _shown_mana: float = 0.0
var _shown_remaining: float = 0.0

@onready var _pending_bar: ProgressBar = $ManaPanel/Bars/PendingBar
@onready var _mana_bar: ProgressBar = $ManaPanel/Bars/ManaBar
@onready var _label: Label = $ManaPanel/Bars/ManaLabel
@onready var _health_bar: ProgressBar = $HealthPanel/Bars/HealthBar
@onready var _health_chip: ProgressBar = $HealthPanel/Bars/ChipBar
@onready var _health_label: Label = $HealthPanel/Bars/HealthLabel
@onready var _damage_flash: ColorRect = $DamageFlash
@onready var _stamina_bar: ProgressBar = $StaminaBar
@onready var _xp_bar: ProgressBar = $XPBar
@onready var _level_label: Label = $LevelLabel
@onready var _crosshair: Control = $Crosshair
@onready var _prompt: Label = $PromptLabel
@onready var _toast: Label = $ToastLabel
@onready var _inventory_ui: InventoryUI = $InventoryUI
@onready var _spell_wheel: SpellWheelUI = $SpellWheel
@onready var _info_panel: Control = $InfoPanel
@onready var _info_title: Label = $InfoPanel/Margin/VBox/Title
@onready var _info_body: Label = $InfoPanel/Margin/VBox/Body


func _ready() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
	if player == null:
		push_warning("HUD: no Player in the scene; HUD disabled.")
		set_process(false)
		return
	if not player.is_node_ready():
		await player.ready  # HUD placed above the Player in the scene tree.
	player.mana_changed.connect(_on_mana_changed)
	player.charge_cost_changed.connect(_on_charge_cost_changed)
	# Player may have emitted its initial value before we connected.
	_on_mana_changed(player.mana, player.max_mana)
	_shown_mana = _mana
	_shown_remaining = _mana
	player.health_changed.connect(_on_health_changed)
	player.damaged.connect(_on_damaged)
	_on_health_changed(player.health, player.max_health)
	_shown_health_chip = _health

	_stamina_fill = (_stamina_bar.get_theme_stylebox("fill") as StyleBoxFlat).duplicate()
	_stamina_bar.add_theme_stylebox_override("fill", _stamina_fill)
	player.stamina_changed.connect(_on_stamina_changed)
	_on_stamina_changed(player.stamina, player.max_stamina, player.is_exhausted)
	_shown_stamina = _stamina
	player.stats.xp_changed.connect(_on_xp_changed)
	_on_xp_changed(player.stats.xp, player.stats.xp_to_next_level(), player.stats.level)
	_apply()

	player.interact_prompt_changed.connect(_on_prompt_changed)
	player.notified.connect(_on_notified)
	_inventory_ui.setup(player)
	_spell_wheel.setup(player)
	_inventory_ui.open_changed.connect(_on_inventory_open_changed)
	_on_prompt_changed("")

	player.info_shown.connect(_on_info_shown)
	player.storage_opened.connect(func(storage: Inventory, title: String, on_close: Callable) -> void:
		_hide_info()
		_inventory_ui.open_storage(storage, title, on_close)
	)
	_info_panel.visible = false


func _process(delta: float) -> void:
	if _info_panel.visible:
		_info_timer -= delta
		if _info_timer <= 0.0:
			_hide_info()
	var t := 1.0 - exp(-smoothing * delta)
	_shown_mana = lerpf(_shown_mana, _mana, t)
	_shown_remaining = lerpf(_shown_remaining, maxf(_mana - _pending_cost, 0.0), t)
	# Health: the real bar is instant; the pale chip waits, then drains to it.
	if _health >= _shown_health_chip:
		_shown_health_chip = _health
	else:
		_chip_delay_timer -= delta
		if _chip_delay_timer <= 0.0:
			_shown_health_chip = lerpf(_shown_health_chip, _health, t * 0.6)
	_shown_stamina = lerpf(_shown_stamina, _stamina, t)
	_apply()


func _apply() -> void:
	_health_bar.max_value = _max_health
	_health_chip.max_value = _max_health
	_health_bar.value = _health
	_health_chip.value = _shown_health_chip
	_health_label.text = "%d / %d" % [ceili(_health), roundi(_max_health)]

	_stamina_bar.max_value = _max_stamina
	_stamina_bar.value = _shown_stamina

	_pending_bar.max_value = _max_mana
	_mana_bar.max_value = _max_mana
	_pending_bar.value = _shown_mana
	_mana_bar.value = _shown_remaining
	if _pending_cost > 0.0:
		_label.text = "%d / %d   (-%d)" % [roundi(_mana), roundi(_max_mana), roundi(_pending_cost)]
	else:
		_label.text = "%d / %d" % [roundi(_mana), roundi(_max_mana)]


func _on_mana_changed(current: float, maximum: float) -> void:
	_mana = current
	_max_mana = maxf(maximum, 0.001)


func _on_charge_cost_changed(cost: float) -> void:
	_pending_cost = cost


func _on_health_changed(current: float, maximum: float) -> void:
	_health = current
	_max_health = maxf(maximum, 0.001)


func _on_stamina_changed(current: float, maximum: float, exhausted: bool) -> void:
	_stamina = current
	_max_stamina = maxf(maximum, 0.001)
	_stamina_fill.bg_color = stamina_exhausted_color if exhausted else stamina_color


func _on_xp_changed(xp: int, xp_to_next: int, level: int) -> void:
	_xp_bar.max_value = maxi(xp_to_next, 1)
	_xp_bar.value = xp
	_level_label.text = "Lv %d" % level


func _on_damaged(_amount: float) -> void:
	_chip_delay_timer = health_chip_delay
	_damage_flash.modulate.a = 1.0
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_damage_flash, "modulate:a", 0.0, 0.4)


func _on_prompt_changed(text: String) -> void:
	_prompt.text = text
	_prompt.visible = text != "" and not _inventory_ui.is_open


func _on_notified(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(toast_hold_time)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


func _on_info_shown(title: String, body: String) -> void:
	_info_title.text = title
	_info_body.text = body
	_info_panel.visible = true
	_info_timer = info_duration


func _hide_info() -> void:
	_info_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	# Dismiss the info panel with Esc (E is handled by stations re-showing it).
	if _info_panel.visible and event.is_action_pressed("ui_cancel"):
		_hide_info()
		get_viewport().set_input_as_handled()


func _on_inventory_open_changed(is_open: bool) -> void:
	if is_open:
		_hide_info()
	player.set_ui_open(is_open)
	_crosshair.visible = not is_open
	_prompt.visible = not is_open and _prompt.text != ""
