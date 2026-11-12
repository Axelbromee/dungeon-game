# Dungeon

A first-person dungeon game in **Godot 4.7** (GL Compatibility renderer,
Jolt physics). Charge and throw fireballs, fight hopping slimes that slam and
shoot back, forage herbs, manage a slot inventory with a hotbar, and level up.
Buildings, furniture, props and the spellbook use the KayKit low-poly models in
`KayKit/` (the dungeon kit in `KayKit/Assets/gltf`); everything else (slimes,
spells, effects, herbs and loot) is built from Godot's own shapes, materials,
particles and generated textures. There are no sound files.

Open the project in Godot and press **F5**. The game starts in the guild hall,
`scenes/world/guild_hall.tscn`. To try a scene on its own, open it and press **F6**.

## Controls

| Key | Action |
|---|---|
| **W A S D** | Move |
| **Shift** | Sprint (uses stamina) |
| **Space** | Jump (uses stamina). Tap for a short hop, hold for a full jump |
| **Ctrl** | Dodge dash in the move direction (or forward). You can't be hurt during it |
| **Mouse** | Look |
| **Left mouse (hold, then release)** | Charge and throw a fireball (only with the Fire Spellbook selected) |
| **E** | Harvest, pick up, open, use |
| **I** or **Tab** | Open / close the inventory |
| **Mouse wheel** or **1–9** | Choose the hotbar slot (the item appears in your hand) |
| **Q** | Drop one of the selected hotbar item. With the inventory open: drop one from the slot under the mouse |
| **Right-click a slot** | Split the stack in half (inventory open) |
| **Esc** | Close the inventory, or release the mouse. Click the game to capture it again |

In the inventory, drag a slot onto another to move, swap or stack it
(including onto the hotbar). Drag it outside the window to drop the whole
stack. Hover a slot to see the item's name, grade and description.

## The world

The playable world lives in `scenes/world/`. Each scene already has a
WorldEnvironment, lighting, a floor, invisible bounds walls, the Player, the HUD,
spawn points and ways to the other scenes. The guild hall is grouped into `Structure`,
`Stations`, `Furniture`, `Lighting` and `Decoration`; the room and the forest have empty
`Building`, `Furniture`, `Stations`, `Props`, `Enemies` and `Harvestables` nodes to sort what you add.

| Scene | What's there | Spawn points |
|---|---|---|
| `guild_hall.tscn` (main scene) | 20 × 30 m two-storey hall with an 8 m beamed ceiling. Front: barred double doors (spawn just inside). Back: reception desk and quest board, the lit dungeon entrance. West: tavern with fireplace. East: shop counter under a balcony, reached by stairs, with room doors (one is yours) | `default`, `from_room`, `from_dungeon` |
| `player_room.tscn` | 6 × 6 m plank floor, one warm room light, door back to the guild | `default`, `from_guild` |
| `dungeon_floor_1.tscn` (forest) | 80 × 80 m forest ground, sky, green fog, a sun with shadows, exit back to the guild | `default`, `from_guild` |

Moving between scenes: a **Scene Door** (or the **Dungeon Entrance**) calls
`SceneManager.change_scene(target_scene, target_spawn)`. The screen fades, the
player's inventory, stats, HP, mana and stamina carry over, and the player
appears at the `SpawnPoint` whose `spawn_id` matches, facing its −Z. Unknown
or empty ids use the `default` spawn. Storage chest contents are kept per
`storage_id`.

## Test sandbox (`scenes/test/`)

The original test scenes, linked to each other only:

- `test_room.tscn`: a 30 × 40 m stone chamber with 4 flickering torches, 2 braziers, a target dummy, two slimes, the Fire Spellbook and three Glowcap Herbs. Its exit leads to the guild kit test.
- `guild_kit_test.tscn`: a guild hall built with the whole kit, plus a showcase of stairs, a platform, pillars, railings and wall samples. Its dungeon entrance leads back to the test room, and the room door leads to the test room's own copy of the player room.
- `player_room_test.tscn`: bed, storage chest, table, banner, lantern and two "coming soon" spots.

| Where (test room) | What |
|---|---|
| (0, 0, 16) | Player spawn, facing north |
| ~1.5 m ahead | Fire Spellbook, 3 Glowcap Herbs (one holds a stack of 3) |
| (0, 0, 6) | Target dummy (shows last hit, hit count, total damage) |
| (−4, 0, 1) and (5, 0, −3) | Two slimes, idle at the start (out of their 12 m range) |

Slimes don't respawn yet; press F6 to restart the scene.

## Building blocks

Everything below works when dragged into any scene, and its settings are on
the root node in the Inspector. Building and guild pieces are `@tool` scripts:
they rebuild live in the editor as you change their settings. Their origin is
at floor level, they snap to a 2 m grid, and their front is +Z.

| Kind | Scene | Settings |
|---|---|---|
| **Building** | `scenes/building/floor_plank.tscn`, `floor_stone.tscn` | tiles X/Z (2 m each, one KayKit tile per cell), collision thickness |
| | `wall.tscn`, `wall_window.tscn`, `wall_doorway.tscn` | style, width (2 m steps; window and doorway pieces are 4 m), height (whole 4 m storeys). KayKit walls at real size: 1 m thick, doorway opening 2.3 × 2.56 m |
| | `wall_corner.tscn` | height (whole storeys; a 1.5 m KayKit pillar) |
| | `door.tscn` (opens with E) | open angle and time, hinge side, start open, locked (stays shut and shows its locked text). The leaf is the KayKit doorway's own |
| | `scene_door.tscn` (E loads another scene) | target scene, target spawn, prompt, sign text, plus the doorway wall settings |
| | `stairs.tscn` | step colliders, rise (width and run follow evenly: 3.26 × 5.93 m at 4 m), smooth ramp |
| | `railing.tscn`, `pillar.tscn`, `roof.tscn` | length (2 m steps, 1.1 m stone barrier); height (evenly scaled pillar); tiles, height, beam rows |
| **Furniture** | `scenes/guild/furniture/table.tscn`, `chair.tscn`, `bench.tscn`, `barrel.tscn`, `crate.tscn`, `shelf.tscn` | kind, size (the height sets an even scale; the bench is a row of stools), shelf count, shelf items |
| | `bed.tscn` (E: rest, refills HP/mana/stamina) | length (the rest follows evenly) |
| | `banner.tscn`, `lantern.tscn`, `fireplace.tscn` | colour/width; chain length and optional light; size, chimney height and light (the fireplace keeps its box look) |
| **Stations** | `scenes/guild/stations/quest_board.tscn` | size, title, message |
| | `reception_desk.tscn`, `shop_counter.tscn` | role, size, sign text |
| | `storage_chest.tscn` | storage id (chests with the same id share contents), title, slot count, size |
| | `dungeon_entrance.tscn` | footprint, pit depth, steps, arch, target scene / spawn, auto enter |
| | `furniture_spot.tscn` ("coming soon" marker) | text, size |
| **Props** | `scenes/props/torch.tscn`, `brazier.tscn` | light on/off, energy, range, colour, flicker |
| | `target_dummy.tscn` | idle text, label hold time |
| | `barrel_breakable.tscn`, `crate_breakable.tscn` | health, respawn time, kill height |
| **Enemies** | `scenes/enemies/slime.tscn` | every number, grouped as Health, Senses, Hop, Contact, Jump Attack, Fireball Attack, Dodge, Hurt, Squash & Stretch, Death & Loot |
| **Harvestables** | `scenes/harvestables/glowcap_herb.tscn` | item (Glowcap Herb by default), amount, verb, glow |
| **Pickups** | `scenes/items/*_pickup.tscn` | item (falls back to the scene's default item), amount, verb |
| **Level setup** | `scenes/player/player.tscn`, `scenes/ui/hud.tscn` | Every level needs one of each. The HUD finds the Player by itself |
| | Spawn point: a `Marker3D` with `scripts/core/spawn_point.gd` | spawn id |

The renderer lights each object with at most 8 lights. Lanterns have their
light off by default, so turn it on for only a few.

## Player (`scenes/player/player.tscn`, `scripts/player/player.gd`)

| | Max | Details |
|---|---|---|
| **Health** | 100 | 0.6 s invulnerability after a hit, with a red screen flash. At 0: "You died", respawn at the last spawn point after 1.5 s with everything refilled. Inventory is kept |
| **Mana** | 100 | Refills 10/s, paused while charging. A pale strip previews the current charge's cost |
| **Stamina** | 100 | Sprint 15/s, jump 10, dash 25 (0.6 s cooldown). Refills 20/s after 1 s unused. At 0 the bar turns orange and sprint/jump/dash are locked until it's back to 20 |

- **Movement:** walk 5 m/s, sprint 8 m/s. Speeds up and slows down smoothly, and steers less in the air.
- **Jumping:** a jump still works just after leaving a ledge, and one pressed just before landing still goes off.
- **Stairs:** walks up ledges up to 0.35 m without jumping.
- **Interacting:** targets what you look at within 2.6 m, or anything close and roughly in front of you. The target glows and "Press [E] to…" appears.
- **Level & XP:** enemies give XP when they die. Level 2 needs 100 XP, and each level after needs 1.35× more. The thin purple bar above the hotbar shows progress, with "Lv N" beside it. Adventurer grade starts at F and can't be raised yet.
- **Stats tab** (in the inventory window): level, XP, adventurer grade, max HP, max mana, max stamina, fireball damage range and stamina regen.

## Fireball (`scenes/spells/fireball.tscn`, `scenes/spells/fireball_explosion.tscn`)

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

- **Slots:** 36, in rows of 9. The first 9 are the hotbar, which is always on screen (the selected slot has a gold border); the other 27 are the bag.
- **Window:** has **Items** and **Stats** tabs. Opening it frees the mouse and blocks looking, casting and interacting; you can still walk. An open storage chest shows its slots above the bag; Shift+click moves a stack between them.
- **Held item:** shown in your hand at the lower right. It sways with the mouse, bobs while you walk and rises in when you switch (`scripts/player/held_item_view.gd`).
- **Dropping:** dropped items are tossed from chest height and bounce. Pick them up again with E.
- **Icons:** generated at startup from each item's 3D model by the `IconBaker` autoload, and cached in `user://icon_cache`.

## Items (`items/`)

| Item | Grade | Stack | Notes |
|---|---|---|---|
| Fire Spellbook | F | 1 | Needed to cast; fireballs charge from the open book in your hand |
| Glowcap Herb | F | 20 | Harvest the glowing plant with E; dropped herbs tumble and can be picked up |
| Slime Jelly | F | 20 | Every slime drops 1–2 |
| Magic Core (F) | F | 20 | Every slime drops one, matching its grade |
| Slime Crystal | D | 20 | 15% of slimes |
| Royal Jelly | B | 20 | 5% of slimes |
| Royal Crystal | A | 20 | 1% of slimes |

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
| JUMP_ATTACK | Player within 4 m | 0.3 s squash and shake, rises up to 5 m (less under a low ceiling) over where you stood, hangs 0.3 s, then slams down. The shadow shows the full damage area; shockwave ring on landing | 3 m radius, 20→6 dmg, 3 s cooldown |
| FIRE_ATTACK | Player 6–15 m away, in clear view | Glows orange for 0.8 s, shoots a small fireball. Its explosion hurts within 2 m but never hurts other slimes | 12 direct, 10→3 splash, 4 s cooldown |
| DODGE | Your fireball will pass within ~1.3 m in the next 0.6 s | 30% chance (once per shot) to hop sideways. Only from IDLE / HOP | 2 s cooldown |
| HURT | Hit while idling or hopping | Brief flinch and knockback | 0.35 s |
| DEAD | 0 HP | Flattens and fades, drops loot, gives XP | see Items |

## Extending it

### Physics layers

| Layer | Name | What's on it |
|---|---|---|
| 1 | `world` | Floor, walls, player, slimes, dummy, props, furniture. Fireballs only hit this layer |
| 2 | `player_only` | Invisible helpers only the player touches, such as stair ramps |
| 3 | `interactable` | Growing herbs, dropped pickups, doors, beds, chests, stations. Fireballs pass through the herbs and pickups |

### Adding a level
1. Duplicate one of the `scenes/world/` scenes and clear out what you don't need.
2. Give it `SpawnPoint` markers with unique `spawn_id`s, one per way in.
3. Point a Scene Door's **Target Scene** and **Target Spawn** at it from the scene you come from.

### Adding an item
1. In the FileSystem dock, right-click `items/` → **New Resource → InventoryItem**. Set its name, grade, category, description, stacking and stack limit.
2. To make it droppable, build a pickup scene in `scenes/items/`: a `RigidBody3D` on layer 3 with `scripts/interaction/item_pickup.gd` and some meshes. Set it as the item's **World Scene**, and set the pickup's **Default Item** to the item's file. Its icon is generated from these meshes.
3. Tune how it sits in the hand under **Held In Hand**: offset, rotation and scale. For a custom hand model, set a held scene. A `Marker3D` named `CastPoint` in it marks where spells charge from.
4. A pickup scene can't hold its item directly, because the item already points at the scene and Godot refuses to load two resources that point at each other. That's why **Default Item** is a file path.

### Adding a building piece
Extend `KitPiece` (`scripts/building/kit_piece.gd`) with `@tool`, export its
settings and build it in `_build()`. Models: `add_model(kk("wall"), 1.0, pos)` places a
KayKit model at an even scale with its bottom centre at `pos` (optionally turned, or
only some of its parts); models are never stretched. `add_model_sized()` and
`add_model_posed()` size one by its height or longest side.
Shapes: `add_box()`, `add_cylinder()`, `add_sphere()`, `add_label()`; add
collision with `add_collision_box()` (the model helpers add none). Shared materials come
from `KitPiece.mat("wood")`, `mat("stone_wall")` and so on. Add `interact(player)`
and `get_interaction_text()` to make it usable with E, and put it on
`LAYER_WORLD | LAYER_INTERACTABLE`.

### Adding an enemy
- Give it `take_damage(amount)` and `apply_knockback(impulse)`. Fireballs and explosions call those.
- Put it in the `enemies` group, so its own fireballs never hurt its allies.
- Call `player.gain_xp(amount)` when it dies. Find the player through the `player` group.
- Player fireballs in flight are in the `fireballs` group, which is how the slime sees shots coming.

### Good to know
- Stacks match items by their `.tres` file, so always use the same file for the same item.
- The player's base maximums are `base_max_health`, `base_max_mana` and `base_max_stamina`. The real maximums come from those plus `Player/Stats`.
- `Player/Stats` also holds four hidden stats (Vitality, Magic, Endurance, Agility), all at 0. Code can raise them with `set_stat()` for a future system.
- Almost every number is an Inspector setting on the Player, the hand (`Player/CameraPivot/Camera3D/Hand`), the Fireball, FireballExplosion, the Slime and the HUD.

### Watch out for
- Every fireball and explosion brings its own light. With several at once near a well-lit spot, some objects can briefly lose lights (8 per object). Raise `rendering/limits/opengl/max_lights_per_object` in Project Settings if it shows.

## Project layout

```
project.godot          main scene: scenes/world/guild_hall.tscn
KayKit/                KayKit model packs (dungeon kit, resources, nature, weapons); not moved or renamed
items/                 InventoryItem definitions (.tres)
materials/
  surfaces/            wood, iron, burlap, stone floor / wall / pillar
  effects/             fire particle material and flame process
  world/               forest_ground
shaders/
  spells/              fireball_shell.gdshader
scenes/
  world/               guild_hall, player_room, dungeon_floor_1 (the real game)
  test/                test_room, guild_kit_test, player_room_test (sandbox)
  player/              player
  ui/                  hud, inventory_ui, inventory_slot
  spells/              fireball, fireball_explosion
  enemies/             slime
  building/            floors, walls, corner, door, scene_door, stairs, railing, pillar, roof
  guild/furniture/     table, chair, bench, barrel, crate, shelf, bed, banner, lantern, fireplace
  guild/stations/      quest_board, reception_desk, shop_counter, storage_chest, dungeon_entrance, furniture_spot
  props/               torch, brazier, target_dummy, barrel_breakable, crate_breakable
  harvestables/        glowcap_herb
  items/               pickups, held spellbook model, herb visual
scripts/
  core/                game_state, scene_manager (autoloads), spawn_point
  player/              player, held_item_view, player_stats
  ui/                  hud, inventory_ui, inventory_slot_ui, inventory_drop_zone, stats_panel
  spells/              fireball, fireball_explosion
  enemies/             slime
  building/            kit_piece (base), kit_*, scene_door
  guild/furniture/     furniture, bed, banner, lantern, fireplace
  guild/stations/      quest_board, guild_counter, storage_chest, dungeon_entrance, furniture_spot
  props/               breakable, target_dummy, fire_light_prop
  effects/             flicker_light, hit_flash
  interaction/         harvestable, item_pickup
  inventory/           inventory_item, inventory, item_visuals, icon_baker (autoload)
addons/godot_ai/       editor plugin (MCP bridge), not part of the game
```
