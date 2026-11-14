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
| **Left mouse** | Cast the selected spell (only with the Grimoire selected). Fireball: hold until the fireball forms (0.5 s), release to throw |
| **R (hold)** | Spell wheel: move the mouse toward a spell, release R to select it. Looking pauses while it's open; the game keeps running |
| **E** | Harvest, pick up, open, use |
| **I** or **Tab** | Open / close the inventory |
| **Mouse wheel** or **1–9** | Choose the hotbar slot (the item appears in your hand). While holding the Grimoire, the mouse wheel cycles your equipped spells instead; 1–9 still switch slots |
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
| `guild_hall.tscn` (main scene) | 20 × 30 m two-storey hall with an 8 m beamed ceiling, in a clearing in the woods (`Outside`). Front: barred double doors (spawn just inside). Back: reception desk and quest board, and the "DUNGEON" archway over the stairs down to the cellar (`Basement`), where the glowing dungeon gate is. West: tavern with fireplace. East: shop counter under a balcony, reached by stairs, with room doors (one is yours) | `default`, `from_room`, `from_dungeon` (in the cellar, in front of the gate) |
| `player_room.tscn` | 6 × 6 m plank floor, one warm room light, door back to the guild | `default`, `from_guild` |
| `dungeon_floor_1.tscn` (forest) | 200 × 200 m forest inside the dungeon, built by `scripts/world/forest_floor.gd` on the `Terrain` node (see **Dungeon floor 1** below) | `default`, `from_guild` (both at the arrival stairs) |

Moving between scenes: a **Scene Door** (or the **Dungeon Entrance**) calls
`SceneManager.change_scene(target_scene, target_spawn)`. The screen fades, the
player's inventory, stats, HP, mana and stamina carry over, and the player
appears at the `SpawnPoint` whose `spawn_id` matches, facing its −Z. Unknown
or empty ids use the `default` spawn. Storage chest contents are kept per
`storage_id`.

## Test sandbox (`scenes/test/`)

The original test scenes, linked to each other only:

- `test_room.tscn`: a 30 × 40 m stone chamber with 4 flickering torches, 2 braziers, a target dummy, two slimes and three Glowcap Herbs. Its exit leads to the guild kit test.
- `guild_kit_test.tscn`: a guild hall built with the whole kit, plus a showcase of stairs, a platform, pillars, railings and wall samples. Its dungeon entrance leads back to the test room, and the room door leads to the test room's own copy of the player room.
- `player_room_test.tscn`: bed, storage chest, table, banner, lantern and two "coming soon" spots.
- `forageables_demo.tscn`: one of each forageable in a row with labels (moss, berry bush, glowcap, mana flower, copper and iron ore against a wall). Walk up and press E.
- `spawn_area_demo.tscn`: an 80 × 80 m field with a spawn area for each kind. Slimes behind some pillars, moss by a pond, berry bushes in the open, copper (south half) and iron ore (north half) on the walls of a ravine, mana flowers among trees in a corner, glowcaps. Open it in the editor to see the outlines.

| Where (test room) | What |
|---|---|
| (0, 0, 16) | Player spawn, facing north |
| ~1.5 m ahead | 3 Glowcap Herbs (one holds a stack of 3) |
| (0, 0, 6) | Target dummy (shows last hit, hit count, total damage) |
| (−4, 0, 1) and (5, 0, −3) | Two slimes, idle at the start (out of their 12 m range) |

Slimes placed by hand don't respawn; ones from a spawn area do (see
**Spawn areas**). Press F6 to restart a scene.

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
| | `railing.tscn`, `pillar.tscn`, `roof.tscn` | length (2 m steps, 1.1 m stone barrier) and a KayKit column post at each end (post start / end; turn one off where two railings share a corner or an end goes into a wall); height (evenly scaled pillar); tiles, height, beam rows |
| **Furniture** | `scenes/guild/furniture/table.tscn`, `chair.tscn`, `bench.tscn`, `barrel.tscn`, `crate.tscn`, `shelf.tscn` | kind, size (the height sets an even scale; the bench is a row of stools), shelf count, shelf items |
| | `bed.tscn` (E: rest, refills HP/mana/stamina) | length (the rest follows evenly) |
| | `banner.tscn`, `lantern.tscn`, `fireplace.tscn` | colour/width; chain length and optional light; size, chimney height and light (the fireplace keeps its box look) |
| **Stations** | `scenes/guild/stations/quest_board.tscn` | size, title, message |
| | `reception_desk.tscn`, `shop_counter.tscn` | role, size, sign text |
| | `storage_chest.tscn` | storage id (chests with the same id share contents), title, slot count, size |
| | `dungeon_entrance.tscn` | footprint, pit depth, steps, arch, target scene / spawn, auto enter, sign text, prompt, locked text (when set, E only shows it and nothing loads) |
| | `furniture_spot.tscn` ("coming soon" marker) | text, size |
| **Props** | `scenes/props/torch.tscn`, `brazier.tscn` | light on/off, energy, range, colour, flicker |
| | `target_dummy.tscn` | idle text, label hold time |
| | `barrel_breakable.tscn`, `crate_breakable.tscn` | health, respawn time, kill height |
| **Enemies** | `scenes/enemies/slime.tscn` | every number, grouped as Health, Senses, Leash, Hop, Contact, Jump Attack, Fireball Attack, Dodge, Hurt, Squash & Stretch, Death & Loot |
| **Harvestables** | `scenes/harvestables/glowcap_herb.tscn`, `healing_moss.tscn`, `wild_berry_bush.tscn`, `copper_ore_node.tscn`, `iron_ore_node.tscn`, `mana_flower.tscn` | item, amount (and amount max for a random amount), verb, presses needed, drop as pickups, regrow time and what hides meanwhile, shake / chip effects, glow, tint |
| **Spawning** | `scenes/world/spawn_area.tscn` | shape and size, what to spawn with weights, max alive, respawn time, spawn all at start, placement (ground / against a wall), spacing, clearance, player distance and sight, leash. See **Spawn areas** |
| **Pickups** | `scenes/items/*_pickup.tscn` | item (falls back to the scene's default item), amount, verb, outline thickness, settling (speed, spin and time before it stops) |
| **Level setup** | `scenes/player/player.tscn`, `scenes/ui/hud.tscn` | Every level needs one of each. The HUD finds the Player by itself |
| | Spawn point: a `Marker3D` with `scripts/core/spawn_point.gd` | spawn id |

The renderer lights each object with at most 8 lights. Lanterns have their
light off by default, so turn it on for only a few.

## Player (`scenes/player/player.tscn`, `scripts/player/player.gd`)

| | Max | Details |
|---|---|---|
| **Health** | 100 | 0.6 s invulnerability after a hit, with a red screen flash. At 0: "You died", respawn at the last spawn point after 1.5 s with everything refilled. Inventory is kept |
| **Mana** | 100 | Refills 10/s, paused while casting. Once a spell is ready to cast, a pale strip previews what releasing will cost |
| **Stamina** | 100 | Sprint 15/s, jump 10, dash 25 (0.6 s cooldown). Refills 20/s after 1 s unused. At 0 the bar turns orange and sprint/jump/dash are locked until it's back to 20 |

- **Movement:** walk 5 m/s, sprint 8 m/s. Speeds up and slows down smoothly, and steers less in the air.
- **Jumping:** a jump still works just after leaving a ledge, and one pressed just before landing still goes off.
- **Stairs:** walks up ledges up to 0.35 m without jumping.
- **Interacting:** targets what you look at within 2.6 m, or anything close and roughly in front of you. The target glows and "Press [E] to…" appears.
- **Level & XP:** enemies give XP when they die. Level 2 needs 100 XP, and each level after needs 1.35× more. The thin purple bar above the hotbar shows progress, with "Lv N" beside it. Adventurer grade starts at F and can't be raised yet.
- **Stats tab** (in the inventory window): level, XP, adventurer grade, max HP, max mana, max stamina, fireball damage and stamina regen.

## Spells (`spells/`, `scripts/spells/`)

- **Grimoire:** the item you hold to cast. A new game starts with it in hotbar slot 1, selected, with **Fireball** learned and equipped (Player → **Start With Grimoire**, **Starting Spell**). LMB casts the selected spell; without the Grimoire in hand nothing is cast.
- **Learning:** there's no way to learn spells in the game yet. Call `player.learn_spell(spell)` (it returns false if the spell is already known) from whatever should teach one.
- **Spell Library** (the **Spells** tab of the inventory window): every learned spell with its icon, name, grade, mana cost and description, and the 8 spell wheel slots above it. Equip a spell by dragging it onto a slot, or click it and then a slot. Drag a slot onto another to swap them; right-click a slot or drag it back onto the list to unequip it.
- **Spell wheel:** hold R to open it in the middle of the screen. Moving the mouse points at a slot (slot 1 at the top, then clockwise); releasing R selects it. While holding the Grimoire, the mouse wheel steps through the equipped spells (empty slots are skipped), and the selected spell's icon and name show to the right of the hotbar.
- Learned spells, the wheel and the selected spell carry over between scenes like the inventory.

## Fireball (`spells/fireball.tres`, `scenes/spells/fireball.tscn`, `scenes/spells/fireball_explosion.tscn`)

- **Casting:** hold the Grimoire with Fireball selected, then hold LMB. At first there's no fireball, only embers spiralling inward to a point above the book, faster and denser as you hold. At 0.5 s (**Min Charge Time** on `spells/fireball.tres`) they collapse into the fireball, which forms in a quick, smooth burst: now it can be thrown; release LMB to shoot it. Holding longer changes nothing: it stays the same size and keeps flickering until you release. Releasing before it forms (or Esc, opening the inventory, switching slots or spells, opening the spell wheel) cancels for free: the embers scatter and fade (a formed fireball shrinks and fizzles out instead). The casting look is tuned on the Fireball scene (**Casting Look** group).
- **Mana cost:** 22.5 per fireball (the spell's **Mana Cost**), paid on release; you need that much to start casting.
- **Every fireball is the same:** size, speed, drop, damage and explosion are settings on the Fireball scene.
- **Flight:** aims at the crosshair at 21 m/s, dropping at 8 m/s².
- **Direct hit:** 30 damage plus knockback.
- **Explosion:**
  - Area damage within 2.75 m.
  - 17.5 damage at the centre, falling to 25% at the edge.
  - The directly hit target doesn't also take splash.
  - Your own explosion never hurts or pushes you.

## Inventory & hand (`scripts/inventory/`, `scripts/ui/`, `scenes/ui/`)

- **Slots:** 36, in rows of 9. The first 9 are the hotbar, which is always on screen (the selected slot has a gold border); the other 27 are the bag.
- **Window:** has **Items**, **Stats** and **Spells** tabs. Opening it frees the mouse and blocks looking, casting and interacting; you can still walk. An open storage chest shows its slots above the bag; Shift+click moves a stack between them.
- **Held item:** shown in your hand at the lower right. It sways with the mouse, bobs while you walk and rises in when you switch (`scripts/player/held_item_view.gd`).
- **Dropping:** dropped items are tossed from chest height, tumble a little and soon settle (high friction, damping, little bounce; once landed and slow they stop completely). Pickups lying in the world have an outline in their grade colour (S gold, A red-orange, B purple, C blue, D green, E white, F grey), drawn as an inverted hull (`shaders/effects/pickup_outline.gdshader`); held items and inventory icons have none. Pick them up again with E.
- **Icons:** generated at startup from each item's 3D model by the `IconBaker` autoload, and cached in `user://icon_cache`.

## Items (`items/`)

| Item | Grade | Stack | Notes |
|---|---|---|---|
| Grimoire | F | 1 | Needed to cast; spells form above the book in your hand. A new game starts with it in hotbar slot 1, selected (Player → **Start With Grimoire**) |
| Glowcap Herb | F | 20 | Harvest the glowing plant with E; dropped herbs tumble and can be picked up |
| Healing Moss | F | 20 | Gather a moss patch with E (1–2). Put its spawn areas near water |
| Wild Berries | F | 20 | Pick a berry bush with E (2–4). The bush stays and regrows its berries in 90 s. Eating isn't in the game yet, so the stamina is description only |
| Copper Ore | F | 20 | Ore node on a wall: a warm grey rock studded with orange-brown copper chunks and veins (softly glowing, easy to spot in the dark). 3 presses of E to mine, drops 1–3 ore pickups |
| Iron Ore | E | 20 | Rarer ore node: a dark rock with dark grey metal chunks and bright silvery glints. Mined the same way |
| Mana Flower | D | 20 | Rare glowing blue flower, pick with E. Put it deep in the forest |
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
| RETURN | Chased farther than its leash range from home (spawn-area slimes) | Hops home ignoring you until it's within 40% of the leash, then idles. Only chases players inside its leash circle | gives up after 12 s |
| DEAD | 0 HP | Flattens and fades, drops loot, gives XP | see Items |

## Dungeon floor 1 (`scenes/world/dungeon_floor_1.tscn`)

A 500 × 500 m forest of giant trees inside the magic dungeon. Everything about the land is
generated by `scripts/world/forest_floor.gd` on the **Terrain** node, live in
the editor (it rebuilds when you change a setting, or press **Rebuild**). The
same **Layout Seed** always gives the same floor. +Z is south.

| Place | Where | What |
|---|---|---|
| Arrival | south, (0, 190) | Stone stairs up from the guild in a calm clearing, no spawns nearby. Walking down the stairs (or E at the "GUILD" arch) returns to the guild. Spawn points `default` / `from_guild` are just north of the arch |
| Forest | most of the floor | Every KayKit tree model, slightly tinted, turned and leaning a little: the slim ones redwood-sized (40–70 m tall), the stout ones smaller (about 17–36 m), all with 3–5 m trunks sunk into the ground; some have rocks, bushes or a log at the base. Also bushes, rocks and fallen logs on gentle hills, with dirt paths from the arrival to the meadow, the lake, the cave and the exit |
| Lake & stream | west, (−137.5, 62.5) | A lake with shallow edges and reeds, fed by a stream from a small pool at the foot of the south edge cliff. The pool, stream and lake are one water system: the stream is one strip of water from inside the pool to inside the lake (hidden where it lies under them, so no gap or double layer), its level sloping smoothly from the pool's down to the lake's, and the ground is carved along the whole way so it stays under the water. Lighter streaks drift with the flow (`shaders/world/floor1_water.gdshader`). Above the pool stands a waterfall (`scenes/world/waterfall.tscn`: a thick column of water (default 2 m deep) built from stacked, overlapping rounded low-poly chunks, round at the front and flat against the cliff at the back, with three strands over it, each scrolling at its own speed in its own shade; it rolls over a rounded lip at the cliff top, follows the cliff face down and widens a little towards the bottom; white foam rings, churning foam, splashing drops and light mist where it lands; **Height**, **Width**, **Thickness** and **Flow Speed** in the Inspector, updating live, and a **Snap To Cliff** button that raycasts the cliff behind it and fits the water to it, top on the cliff top, back flush on the face. The Terrain keeps cliff rocks off every waterfall's path, so after moving one press **Rebuild** on the Terrain) placed by hand as the `Waterfall` node |
| Meadow | east, (125, 87.5) | Flatter open grass with scattered bushes and coloured flowers |
| Cave | north-east, mouth at about (100, −134) | Cut into a high rocky spur of the north cliff wall. A path leads to the foot of a steep rock face, where the mouth is a rough, irregular opening in the cliff (wherever the cave's vault breaks out of the rock), blending into the cliff around it. A wooden mine entrance (`scenes/world/cave_entrance.tscn`: two thick posts and a beam of KayKit logs, with collision; **Width**, **Height** and **Beam Thickness** in the Inspector, updating live) stands in the mouth as the `CaveEntrance` node: move and turn it by hand, the terrain never touches it. Inside, passages about 14 m wide and 9 m high open into big chambers: an entry hall (about 32 m across), a main chamber (about 60 m across, up to 22 m high), an east chamber (about 40 m) and a west alcove (about 30 m). The walls wander, the ceiling is lumpy with hanging rock, the floor is uneven, and KayKit rocks and rubble line the walls, with rock spires in the chambers. Glowing crystal clusters (cyan and violet) and glowing mushrooms grow along the walls (decoration only). No sunlight inside: the cave's inside, its rocks, crystals, mushrooms and the ore spawned there are on render layer 2, which the sun's cull mask leaves out, so only the crystals, mushrooms and one soft light per chamber (4 lights) light it. Near the mouth the rock is brighter, as if daylight spills in, fading out over about 20 m. About 7 m in, the `Lighting/CaveDarkness` area fades the ambient light down to a dark cave level (and back when you leave) |
| Exit | north-west, (−140, −180) | Stone archway with stairs down, sealed: "Floor 2 coming soon" |
| Edges | all round | An irregular outline (a rounded square pushed in by up to 40 m in bays and outcrops, but never near the portals or spawn areas) with stepped cliffs (ledges between steep faces, about 24–56 m high, varying along the edge), densely covered in many smaller KayKit rocks (mostly small and medium, a few large), turned at random, overlapping and half buried so they read as rough rock, with rubble at the foot. The cave's cliff spur gets the same, steep slopes inside the floor get some, and the cave's walls and ceiling are covered the same way (no collision there; head room kept over the floor, 3.5 m along the way in, and only thin rocks at the foot of the walls so ore veins, crystals and mushrooms stay visible). Rocks near the foot are solid; none reach out past the foot. Invisible walls at the map border. No trees, rocks, bushes or logs on the cliffs (or the cave's cliff spur) or within **Edge Margin** (10 m) of them, and no spawn areas there |

**Look:** like the KayKit models, the terrain is low-poly and flat-shaded,
one flat palette colour per face: greens for grass, warm dirt for paths, sand
on shores and the lake bed, blue-grey rock on cliffs and steep slopes, darker
rock in the cave. Water is a flat teal. The palette colours are sRGB (the terrain material reads its vertex colours as sRGB), with a linear tonemap, a soft ambient light and light glow (for the crystals and mushrooms), so colours stay as rich as the KayKit models. No fog, no light shafts.

**Terrain node settings:** size and vertex spacing, hills, edge cliffs, the
portals to cut holes for, lake (centre, radius, depth, water level), stream
and paths (lines of points), meadow, cave (the cliff spur it's cut into: area, height, slope; chambers
and passages as [x1, z1, x2, z2, radius, ceiling height]; mouth position;
roughness), forest and grass density, tree spacing, tree height and trunk width, the edge margin, the wall rocks (**Cliff Rocks** and **Cave Rocks**: density in rocks per m² of wall, min / max size, how deep they sink in),
and the scene roots it fills (Nature, Water, Lighting/CaveDarkness). **Snap to Ground** puts every
direct child of `Portals` and `Spawns` on the terrain (it also runs on every
build and when the game starts). Give a node the meta `snap_offset` (float)
to lift or sink it, or `no_snap` to leave it alone.

**Scene tree:** `Terrain` (ground mesh, cave, collision, bounds), `Nature`
(generated MultiMesh chunks: Trees, Bushes, Rocks, Logs, CliffRocks, CliffSmall, CliffRubble, CaveSkin, Grass, Flowers,
Reeds, plus their colliders), `Water`, `Portals` (both stairs, their glows,
the spawn points), `Spawns` (spawn areas), `Lighting` (sun,
fireflies and magic motes that follow the player, cave darkness).

**No clipping:** every tree, bush, rock and log claims its footprint, so none
overlap; grass, flowers and reeds skip taken spots; nothing grows on paths,
in water or at the cave walls; rocks, logs and bushes lean with the slope and
trees sit deeper on slopes. Bushes and small rocks have invisible colliders on
layer 6, so spawn areas never place anything inside them.

**Spawn areas** (none overlap): 4 slime areas (max 4–5, respawn 3 min, leashed 45 m) in the
forest and by the lake; Healing Moss on the lake's east and north shores and
along the stream; Wild Berries on the meadow; in the cave, Copper Ore on the
walls of the entry hall and the main chamber, Iron Ore (max 2, 120 s) on the east
chamber's walls and a mixed copper/iron area on the alcove floor; 2 Mana Flower
areas (max 1, 180 s) deep in the forest; 3 Glowcap areas in shady spots.

**Performance:** the vegetation is MultiMeshes in chunks (trees 64 m, grass
and flowers 32 m, the rest 48 m), each drawn only within its own distance
(grass and flowers 45 m, bushes 140 m, logs 180 m, cliff rocks 400 m (small ones 140 m, rubble 90 m), cave wall rocks 80 m, rocks 220 m, trees 600 m so the forest reaches across the whole floor now there is no fog,
with a small margin so chunks don't flicker at the edge). The imported KayKit meshes have auto-generated LODs. The ground
is 2 m cells split into 50 m chunk meshes, so what's behind the camera is
culled. The only real lights are the sun, the two portal glows and one light
per cave chamber.

## Spawn areas (`scenes/world/spawn_area.tscn`, `scripts/world/spawn_area.gd`)

A spawn area keeps a number of enemies or forageables alive in a box or
circle and refills it over time. The same node works for both. Try
`scenes/test/spawn_area_demo.tscn`.

### Setting one up
1. Drag `scenes/world/spawn_area.tscn` into the level (under `Enemies` or `Harvestables`) and place it **at ground level** in the middle of where things should appear.
2. **Area:** pick **Box** (set **Size**, X × Z in metres) or **Circle** (set **Radius**). A coloured outline shows the area in the editor only. The faint upper outline is how high above the node the ground may be, and the orange ring is the leash range. Give each area its own **Editor Color** so they're easy to tell apart.
3. **Spawning → Entries:** add an element, choose **New SpawnEntry**, and set its **Scene** (e.g. `scenes/enemies/slime.tscn`) and **Weight**. Weights are relative, so 90 and 10 give 90% / 10%. The outline's label shows the resulting percentages.
4. Set **Max Alive** (default 6), **Respawn Time** (default 30 s) and **Spawn All At Start** (on: full when the level loads; off: the slots fill one by one over the first respawn time).
5. **Placement:** **Ground** for creatures and plants. **Against Wall** for ore: each spawn goes to the foot of the nearest wall within **Wall Search Distance**, facing out of it. Raise **Clearance Radius / Height** for big things (bushes 0.7, ore 0.5 × 1.2) and **Min Spacing** to spread them out.
6. **Leash** (enemies): slimes won't chase farther than **Leash Range** from the area's centre; past it they hop home. Set it to 0 for forageables (they ignore it anyway).

### How it decides where to spawn
- A random point in the area is raycast straight down to find the ground (**Ground Mask**, default layer 1). The ground must be within **Max Rise** above and **Max Drop** below the node, and no steeper than **Max Slope**. That keeps spawns off crates and wall tops; raise Max Rise on hilly ground.
- The spot must be free: an upright capsule (**Clearance Radius / Height**) may not touch walls, bodies or other interactables (**Blocker Mask**, layers 1 and 3), so nothing spawns inside walls, rocks or other spawns. It must also be **Min Spacing** away from this area's other spawns.
- Never closer than **Min Player Distance** (10 m) to the player, and, with **Hide From Player** on, never where the player's camera can see it. A blocked spawn waits **Retry Interval** (2 s) and tries again. The start-of-level fill skips the sight rule unless **Check Sight At Start** is on, but still keeps the distance.
- **Tries Per Attempt** random spots are tried each time before waiting.

### Respawning
Spawns become children of the area. When one leaves the scene (a slime dies,
moss is gathered, ore is mined out), its slot frees up and refills after
**Respawn Time**, using the same rules. Berry bushes stay when picked and
regrow their own berries, so they keep their slot. The area emits `spawned`
and `despawned` signals, and `get_alive()` lists what's alive.

### Making something spawnable
Any scene with a 3D root works. Its origin should be at its base (on the
ground). For a leash, give it `set_leash(center: Vector3, range: float)`, as
the Slime has. For a forageable, use `scripts/interaction/harvestable.gd` on an
`Area3D` (layer 3) and let it `queue_free()` when harvested (the default).

## Extending it

### Physics layers

| Layer | Name | What's on it |
|---|---|---|
| 1 | `world` | Floor, walls, player, slimes, dummy, props, furniture. Fireballs only hit this layer |
| 2 | `player_only` | Invisible helpers only the player touches, such as stair ramps |
| 3 | `interactable` | Growing herbs, dropped pickups, doors, beds, chests, stations. Fireballs pass through the herbs and pickups |
| 5 | water | Lake and stream surfaces on floor 1. Nothing collides with them (you wade through); spawn areas skip spots under water (their **Avoid Mask**) |
| 6 | scenery | Invisible colliders around floor 1's bushes and small rocks. Only spawn areas see them (in their **Blocker Mask**), so nothing spawns inside a bush |

Colliders in the `no_spawn_ground` group (floor 1's tree trunks, boulders and
logs) never count as ground or walls for spawn areas.

### Adding a level
1. Duplicate one of the `scenes/world/` scenes and clear out what you don't need.
2. Give it `SpawnPoint` markers with unique `spawn_id`s, one per way in.
3. Point a Scene Door's **Target Scene** and **Target Spawn** at it from the scene you come from.

### Adding an item
1. In the FileSystem dock, right-click `items/` → **New Resource → InventoryItem**. Set its name, grade, category, description, stacking and stack limit.
2. To make it droppable, build a pickup scene in `scenes/items/`: a `RigidBody3D` on layer 3 with `scripts/interaction/item_pickup.gd` and some meshes. Set it as the item's **World Scene**, and set the pickup's **Default Item** to the item's file. Its icon is generated from these meshes.
3. Tune how it sits in the hand under **Held In Hand**: offset, rotation and scale. For a custom hand model, set a held scene. A `Marker3D` named `CastPoint` in it marks where spells are cast from.
4. A pickup scene can't hold its item directly, because the item already points at the scene and Godot refuses to load two resources that point at each other. That's why **Default Item** is a file path.

### Adding a spell
A spell is a `Spell` resource (`scripts/spells/spell.gd`): name, description,
icon, grade, mana cost, and what casts it. It needs no new code if it casts
like an existing spell.

1. In the FileSystem dock, right-click `spells/` → **New Resource → Spell**. Set its name, description, icon (any texture) and grade.
2. **Mana:** **Mana Cost** is spent on every cast (and is the least mana needed to start one).
3. **Casting:** **Min Charge Time** is how long LMB must be held before the spell can be cast (releasing sooner cancels it for free; 0 = cast as soon as LMB is released). **Scene** is what the spell spawns. **Caster** is the script that casts it; leave it empty (or set `charged_projectile_caster.gd`) for a projectile cast like the fireball.
4. For a projectile, build its scene like `scenes/spells/fireball.tscn`: the root needs `get_radius()`, `launch(direction, caster)` and a `damage_multiplier` property; `gather()`, `set_gather_progress(progress)`, `form()`, `scatter()` and `fizzle()` are optional (the casting look). The quickest way is to duplicate the fireball scene and change its look and numbers.
5. Teach it with `player.learn_spell(load("res://spells/your_spell.tres"))`, or set it as the Player's **Starting Spell** to start a new game with it.

For a spell that works differently (a beam, a shield, a teleport), add a
script that extends `SpellCaster` (`scripts/spells/spell_caster.gd`) and set
it as the spell's **Caster**. The Player calls `start(spell, player)` when LMB
is pressed (return false if it can't be cast), `update(delta)` every physics
frame while it's held, `release()` when it's let go and `cancel()` if the
cast is interrupted; `pending_cost()` is shown on the mana bar while casting.

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
spells/                Spell definitions (.tres)
materials/
  surfaces/            wood, iron, burlap, stone floor / wall / pillar
  effects/             fire particle material and flame process
  world/               forest_ground, grass_ground, dirt_path, floor1_terrain, water
shaders/
  spells/              fireball_shell.gdshader
scenes/
  world/               guild_hall, player_room, dungeon_floor_1 (the real game), spawn_area
  test/                test_room, guild_kit_test, player_room_test, forageables_demo, spawn_area_demo (sandbox)
  player/              player
  ui/                  hud, inventory_ui, inventory_slot
  spells/              fireball, fireball_explosion
  enemies/             slime
  building/            floors, walls, corner, door, scene_door, stairs, railing, pillar, roof
  guild/furniture/     table, chair, bench, barrel, crate, shelf, bed, banner, lantern, fireplace
  guild/stations/      quest_board, reception_desk, shop_counter, storage_chest, dungeon_entrance, furniture_spot
  props/               torch, brazier, target_dummy, barrel_breakable, crate_breakable, magic_glow
  harvestables/        glowcap_herb, healing_moss, wild_berry_bush, copper_ore_node, iron_ore_node, mana_flower
  items/               pickups, held Grimoire model, herb / moss / berry / flower visuals
scripts/
  core/                game_state, scene_manager (autoloads), spawn_point
  player/              player, held_item_view, player_stats
  ui/                  hud, inventory_ui, inventory_slot_ui, inventory_drop_zone, stats_panel, spell_library_ui, spell_wheel_ui
  spells/              spell, spell_caster, charged_projectile_caster, fireball, fireball_explosion
  enemies/             slime
  building/            kit_piece (base), kit_*, scene_door
  guild/furniture/     furniture, bed, banner, lantern, fireplace
  guild/stations/      quest_board, guild_counter, storage_chest, dungeon_entrance, furniture_spot
  props/               breakable, target_dummy, fire_light_prop
  effects/             flicker_light, hit_flash, follow_player
  interaction/         harvestable, item_pickup
  world/               spawn_area, spawn_entry, forest_floor (floor 1 generator), outside (guild surroundings), ambience_zone
  inventory/           inventory_item, inventory, item_visuals, icon_baker (autoload)
addons/godot_ai/       editor plugin (MCP bridge), not part of the game
```
