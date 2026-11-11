# Dungeon

A first-person dungeon test game in **Godot 4.7** (GL Compatibility renderer,
Jolt physics). Charge and throw fireballs, fight hopping slimes that slam and
shoot back, forage herbs, manage a slot inventory with a hotbar, and level up.
Everything is built from Godot's own shapes, materials, particles and
generated textures; there are no imported art or sound files.

Open the project in Godot and press **F5**. The main scene is `scenes/main.tscn`.

## Controls

| Key | Action |
|---|---|
| **W A S D** | Move |
| **Shift** | Sprint (uses stamina) |
| **Space** | Jump (uses stamina). Tap for a short hop, hold for a full jump |
| **Ctrl** | Dodge dash in the move direction (or forward). You can't be hurt during it |
| **Mouse** | Look |
| **Left mouse (hold, then release)** | Charge and throw a fireball (only with the Fire Spellbook selected) |
| **E** | Harvest or pick up |
| **I** or **Tab** | Open / close the inventory |
| **Mouse wheel** or **1–9** | Choose the hotbar slot (the item appears in your hand) |
| **Q** | Drop one of the selected hotbar item. With the inventory open: drop one from the slot under the mouse |
| **Right-click a slot** | Drop one (inventory open) |
| **Esc** | Close the inventory, or release the mouse. Click the game to capture it again |

In the inventory, drag a slot onto another to move, swap or stack it
(including onto the hotbar). Drag it outside the window to drop the whole
stack. Hover a slot to see the item's name, grade and description.

## Player (`scenes/player.tscn`, `scripts/player.gd`)

| | Max | Details |
|---|---|---|
| **Health** | 100 | 0.6 s invulnerability after a hit, with a red screen flash. At 0: "You died", respawn at the start after 1.5 s with everything refilled. Inventory is kept |
| **Mana** | 100 | Refills 10/s, paused while charging. A pale strip previews the current charge's cost |
| **Stamina** | 100 | Sprint 15/s, jump 10, dash 25 (0.6 s cooldown). Refills 20/s after 1 s unused. At 0 the bar turns orange and sprint/jump/dash are locked until it's back to 20 |

- **Movement:** walk 5 m/s, sprint 8 m/s. Speeds up and slows down smoothly, and steers less in the air.
- **Jumping:** a jump still works just after leaving a ledge, and one pressed just before landing still goes off.
- **Stairs:** walks up ledges up to 0.35 m without jumping.
- **Interacting:** targets what you look at within 2.6 m, or anything close and roughly in front of you. The target glows and "Press [E] to…" appears.
- **Level & XP:** enemies give XP when they die. Level 2 needs 100 XP, and each level after needs 1.35× more. The thin purple bar above the hotbar shows progress, with "Lv N" beside it. Adventurer grade starts at F and can't be raised yet.
- **Stats tab** (in the inventory window): level, XP, adventurer grade, max HP, max mana, max stamina, fireball damage range and stamina regen.

## Fireball (`scenes/fireball.tscn`, `scenes/fireball_explosion.tscn`)

- **Charging:** select the Fire Spellbook, then hold LMB. The fireball grows above the open book for up to 1.5 s, and stops growing at the size your mana can pay for.
- **Mana cost:** 5 for a quick shot up to 40 for a full charge, paid on release. Esc, opening the inventory or switching slots cancels it for free.
- **Flight:** aims at the crosshair. Bigger fireballs fly slower and drop faster.
- **Direct hit:** 10–50 damage plus knockback.
- **Explosion:**
  - Area damage within 1.5–4 m, bigger with charge.
  - 5–30 damage at the centre, falling to 25% at the edge.
  - The directly hit target doesn't also take splash.
  - Your own explosion never hurts or pushes you.

## Inventory & hand (`scripts/inventory/`, `scripts/ui/`, `scenes/ui/`)

- **Slots:** 27, in rows of 9. The top row is the hotbar, which is always on screen; the selected slot has a gold border.
- **Window:** has **Items** and **Stats** tabs. Opening it frees the mouse and blocks looking, casting and interacting; you can still walk.
- **Held item:** shown in your hand at the lower right. It sways with the mouse, bobs while you walk and rises in when you switch (`scripts/player/held_item_view.gd`).
- **Dropping:** dropped items are tossed from chest height and bounce. Pick them up again with E.

## Items

| Item | Grade | Stack | Notes |
|---|---|---|---|
| Fire Spellbook | F | 1 | Needed to cast; fireballs charge from the open book in your hand |
| Glowcap Herb | F | 20 | Harvest the glowing plant with E; dropped herbs tumble and can be picked up |
| Slime Jelly | D | 20 | Every slime drops 1–2 |
| Slime Core | D | 20 | Half of slimes drop one |

Grades run S, A, B, C, D, E, F. Tooltips colour them: S gold, A red-orange,
B purple, C blue, D green, E white, F grey.

## The Slime (`scenes/enemies/slime.tscn`, `scripts/enemies/slime.gd`)

A translucent green blob with eyes and a glowing core: **50 HP, 20–50 XP**.
Hits always damage it and make it flash. Only idling and hopping can be
interrupted, at most once every 1.2 s, so its attacks can't be stunlocked.

| State | When | What it does | Numbers |
|---|---|---|---|
| IDLE | Player farther than 12 m | Wobbles in place | — |
| HOP | Player within 12 m (gives up past 18 m) | Hops toward you; touching you deals a bump | 8 dmg, 1 s cooldown |
| JUMP_ATTACK | Player within 4 m | 0.3 s squash and shake, rises ~6.5 m over where you stood, hangs 0.3 s, then slams down. The shadow shows the full damage area; shockwave ring on landing | 3 m radius, 20→6 dmg, 3 s cooldown |
| FIRE_ATTACK | Player 6–15 m away, in clear view | Glows orange for 0.8 s, shoots a small fireball. Its explosion hurts within 2 m but never hurts other slimes | 12 direct, 10→3 splash, 4 s cooldown |
| DODGE | Your fireball will pass within ~1.3 m in the next 0.6 s | 30% chance (once per shot) to hop sideways. Only from IDLE / HOP | 2 s cooldown |
| HURT | Hit while idling or hopping | Brief flinch and knockback | 0.35 s |
| DEAD | 0 HP | Flattens and fades, drops loot, gives XP | 1–2 jelly, 50% core |

Every number is an Inspector setting on the slime, grouped as Health, Senses,
Hop, Contact, Jump Attack, Fireball Attack, Dodge, Hurt, Squash & Stretch, and
Death & Loot.

## Test room (`scenes/main.tscn`)

A 30 × 40 m stone chamber with an 8 m ceiling and moody lighting: dim ambient
light, light fog, glow, a soft fill light, 4 flickering wall torches and 2
braziers.

| Where | What |
|---|---|
| (0, 0, 16) | Player spawn, facing north |
| ~1.5 m ahead | Fire Spellbook, 3 Glowcap Herbs (one holds a stack of 3) |
| (0, 0, 6) | Target dummy (shows last hit, hit count, total damage) |
| (−4, 0, 1) and (5, 0, −3) | Two slimes, idle at the start (out of their 12 m range) |

Slimes don't respawn yet; press F5 to restart. Kept for later in
`scenes/props/`: a crate and barrel (take damage, break, return after 5 s),
plus a dummy, torch and brazier.

## Building on it

### Physics layers

| Layer | Name | What's on it |
|---|---|---|
| 1 | `world` | Floor, walls, player, slimes, dummy, props. Fireballs only hit this layer |
| 2 | `player_only` | Invisible helpers only the player touches, such as stair ramps |
| 3 | `interactable` | Growing herbs and dropped pickups. Fireballs pass through them |

### Adding an item
1. In the FileSystem dock, right-click → **New Resource → InventoryItem**, and save it under `items/`. Set its name, grade, description, icon, stacking and stack limit.
2. To make it droppable, build a pickup scene: a `RigidBody3D` on layer 3 with `item_pickup.gd` and some meshes. Set it as the item's world scene.
3. Tune how it sits in the hand under **Held In Hand**: offset, rotation and scale. For a custom hand model, set a held scene. A `Marker3D` named `CastPoint` in it marks where spells charge from.
4. When placing it in a level, set its item in the Inspector, not inside its own scene. The item already points at that scene; if the scene pointed back, Godot would refuse to load either.

### Adding an enemy
- Give it `take_damage(amount)` and `apply_knockback(impulse)`. Fireballs and explosions call those.
- Put it in the `enemies` group, so its own fireballs never hurt its allies.
- Call `player.gain_xp(amount)` when it dies. Find the player through the `player` group.
- Player fireballs in flight are in the `fireballs` group, which is how the slime sees shots coming.

### Good to know
- Stacks match items by their `.tres` file, so always use the same file for the same item.
- The player's base maximums are `base_max_health`, `base_max_mana` and `base_max_stamina`. The real maximums come from those.
- `Player/Stats` also holds four hidden stats (Vitality, Magic, Endurance, Agility), all at 0 with no effect yet. Code can raise them with `set_stat()` for a future system.
- Almost every number is an Inspector setting on the Player, the hand (`Player/CameraPivot/Camera3D/Hand`), the Fireball, FireballExplosion, the Slime and the HUD.

### Watch out for
- The renderer lights each object with at most 8 lights. The room uses 6, and every fireball and explosion brings one, so several at once can briefly knock lights off the floor. Raise `rendering/limits/opengl/max_lights_per_object` in Project Settings if it shows.
- The project isn't under version control yet, so there's no undo history. Run `git init` before big changes.

## Project layout

```
items/            fire_spellbook, glowcap_herb, slime_jelly, slime_core (.tres)
materials/        stone, wood, iron, burlap, fire particles
scenes/           main, player, hud, fireball, fireball_explosion
  enemies/        slime
  items/          herb plant + visual, pickups, spellbook held model
  props/          crate, barrel, target dummy, torch, brazier
  ui/             inventory window and slot
scripts/          player, fireball, explosion, hud, props, lights
  enemies/        slime.gd
  interaction/    harvestable.gd, item_pickup.gd
  inventory/      inventory_item.gd, inventory.gd
  player/         held_item_view.gd, player_stats.gd
  ui/             inventory_ui.gd, inventory_slot_ui.gd, inventory_drop_zone.gd, stats_panel.gd
shaders/          fireball_shell.gdshader
```
