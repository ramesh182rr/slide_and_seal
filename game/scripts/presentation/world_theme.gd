class_name WorldTheme
extends RefCounted
## Per-world art direction (docs/07 world bible, docs/06 palette): sky, stone, foliage and light
## colours shared by the 3D board, its island diorama and the 2D backdrops. Presentation only.
## Energy colours that carry meaning (route cyan, seal mint, gate amber, …) stay in Palette so a
## mechanism always looks the same in every world.

## Environment family (M13): what the board stands on and what surrounds it.
enum Style { ISLAND, FROST, FOUNDRY, PORTAL, TEMPLE, NEON, VOID, COLOSSAL }

var world_id := ""
var style := Style.ISLAND
## Glow showing through the gaps between floor tiles (lava cracks, circuit seams); alpha 0 = none.
var seam_glow := Color(0, 0, 0, 0)
## Floor finish: polished ice and metal are glossier than stone.
var tile_roughness := 0.86
var tile_metallic := 0.0
## Scanned surfaces (MaterialLibrary.pbr): [texture set, tint, uv scale, roughness ×, metalness ×].
var floor_surface: Array = ["mossy_rock", Color(0.4, 0.54, 0.58), 0.55, 1.0, 1.0]
var wall_surface: Array = ["castle_wall_slates", Color(0.58, 0.66, 0.6), 0.8, 1.0, 1.0]
var rock_surface: Array = ["cliff_side", Color(0.75, 0.72, 0.7), 0.3, 1.0, 1.0]
var metal_surface: Array = ["rusty_metal_02", Color(0.7, 0.7, 0.72), 0.6, 0.9, 0.4]
## Tint for the scanned rock models (island underside, floating rocks).
var rock_model_tint := Color(0.85, 0.82, 0.8)
## Display name (the catalog has the same titles; the theme keeps its own for in-level headers).
var title := "Slide & Seal"
## One line shown under the world's title (world selection).
var tagline := ""
## The world's signature colour (titles, card borders, trim glow).
var accent := Palette.CYAN_ENERGY
var sky_top := Color("#050A18")
var sky_bottom := Color("#14284A")
## Glow near the horizon line of the backdrop.
var horizon := Color("#2C6E8A")
## Soft nebula clouds in the backdrop.
var nebula := Color("#3B4F9A")
## Floor tiles, wall blocks and the island's top rim.
var stone := Color("#4A5868")
var stone_dark := Color("#2A3442")
## The rock underneath the island.
var rock := Color("#2C2A33")
## Moss/foliage on stone edges; alpha = how much there is (0 = none).
var foliage := Color(0.35, 0.62, 0.32, 0.0)
## Decorative crystal clusters on the island (alpha 0 = none).
var crystal := Color(0.4, 0.75, 1.0, 0.0)
var key_light := Color("#FFE9C8")
var fill_light := Color("#6FA8FF")
var ambient := Color("#8DA2C0")
var fog := Color("#1A2C4A")


## The seven worlds of the campaign in order (docs/07). Worlds without levels yet show as
## "Coming soon" with a display-only board from data/showcase/.
const ALL_WORLDS: Array[String] = ["world_01_awakening", "world_02_gravity_works", "world_03_push_protocol",
	"world_04_portal_nexus", "world_05_sealed_chambers", "world_06_shifting_labyrinth", "world_07_final_machine"]
const SHOWCASE_DIR := "res://data/showcase"


## A display-only board for a world that has no levels yet ("" if none).
static func showcase_path(id: String) -> String:
	var number := id.split("_")[1] if id.split("_").size() > 1 else ""
	var path := "%s/world_%s_showcase.json" % [SHOWCASE_DIR, number]
	return path if FileAccess.file_exists(path) else ""


static func for_world(id: String) -> WorldTheme:
	var t := WorldTheme.new()
	t.world_id = id
	match id:
		"world_01_awakening":
			t.title = "The Awakening"
			t.rock_surface = ["mossy_rock", Color(0.8, 0.85, 0.78), 0.35, 1.0, 1.0]
			# M16: a colossal overgrown maze in mist (owner direction).
			t.style = Style.COLOSSAL
			t.sky_top = Color("#0B1418")
			t.sky_bottom = Color("#3C5A58")
			t.horizon = Color("#8FB4A4")
			t.nebula = Color("#3A5A5E")
			t.fog = Color("#5E7F78")
			t.key_light = Color("#FFF1D6")
			t.fill_light = Color("#8FC6C0")
			t.ambient = Color("#A8C0B8")
			t.tagline = "Ancient stone wakes to soft cyan energy."
			t.accent = Color("#5FE3C8")
			t.sky_top = Color("#040B17")
			t.sky_bottom = Color("#123247")
			t.horizon = Color("#2B8C8A")
			t.nebula = Color("#2E5E8C")
			t.stone = Color("#5B6660")
			t.stone_dark = Color("#2E3634")
			t.rock = Color("#2B2A2C")
			t.foliage = Color(0.3, 0.48, 0.3, 0.85)
			t.crystal = Color(0.38, 0.92, 0.85, 0.5)
			t.key_light = Color("#FFE6C2")
			t.fill_light = Color("#5FD0E0")
			t.ambient = Color("#8FB0B8")
			t.fog = Color("#173444")
		"world_02_gravity_works":
			t.title = "Gravity Works"
			t.tagline = "Blue crystal chambers bend the pull of the world."
			t.accent = Color("#6FB4FF")
			t.sky_top = Color("#03081A")
			t.sky_bottom = Color("#142A5C")
			t.horizon = Color("#3A64C8")
			t.nebula = Color("#4A3FA0")
			t.stone = Color("#55627A")
			t.stone_dark = Color("#262E44")
			t.rock = Color("#232638")
			t.foliage = Color(0.3, 0.5, 0.4, 0.0)
			t.crystal = Color(0.42, 0.7, 1.0, 1.0)
			t.key_light = Color("#E6EEFF")
			t.fill_light = Color("#5B7CFF")
			t.ambient = Color("#8796C8")
			t.fog = Color("#16224A")
			t.style = Style.FROST
			t.tile_roughness = 0.6
			t.stone = Color("#4C6886")
			t.stone_dark = Color("#22364F")
			t.rock = Color("#1C2A44")
			t.sky_top = Color("#02060F")
			t.sky_bottom = Color("#0F2648")
			t.floor_surface = ["snow_02", Color(0.34, 0.46, 0.7), 0.6, 0.5, 1.0]
			t.wall_surface = ["castle_wall_slates", Color(0.86, 0.94, 1.0), 0.8, 0.5, 1.0]
			t.rock_surface = ["cliff_side", Color(0.45, 0.55, 0.75), 0.3, 1.0, 1.0]
			t.rock_model_tint = Color(0.5, 0.6, 0.8)
		"world_03_push_protocol":
			t.title = "The Push Protocol"
			t.tagline = "Amber pressure machinery pushes back."
			t.accent = Palette.MECHANISM_AMBER
			t.sky_top = Color("#0A0710")
			t.sky_bottom = Color("#3A2418")
			t.horizon = Color("#B8642A")
			t.nebula = Color("#6A3A2A")
			t.stone = Color("#665C52")
			t.stone_dark = Color("#33291F")
			t.rock = Color("#2E241E")
			t.crystal = Color(1.0, 0.72, 0.35, 0.4)
			t.key_light = Color("#FFD8A8")
			t.fill_light = Color("#FF9A55")
			t.ambient = Color("#B09A88")
			t.fog = Color("#2E2018")
			t.style = Style.FOUNDRY
			t.seam_glow = Color(1.0, 0.45, 0.12, 0.9)
			t.tile_roughness = 0.5
			t.tile_metallic = 0.55
			t.stone = Color("#4A4C52")
			t.stone_dark = Color("#24252A")
			t.rock = Color("#2A2522")
			t.floor_surface = ["metal_plate", Color(0.62, 0.55, 0.5), 0.7, 0.9, 0.25]
			t.wall_surface = ["rusty_metal_02", Color(0.5, 0.4, 0.36), 0.7, 1.0, 0.4]
			t.rock_surface = ["dark_rock", Color(0.6, 0.5, 0.45), 0.4, 1.0, 1.0]
			t.metal_surface = ["rusty_metal_02", Color(0.75, 0.68, 0.62), 0.6, 0.9, 0.4]
			t.rock_model_tint = Color(0.45, 0.38, 0.35)
		"world_04_portal_nexus":
			t.title = "Portal Nexus"
			t.tagline = "Violet gateways fold space together."
			t.accent = Palette.PORTAL_VIOLET
			t.sky_top = Color("#07041A")
			t.sky_bottom = Color("#2C1650")
			t.horizon = Color("#7A4AD0")
			t.nebula = Color("#8A3AA0")
			t.stone = Color("#5A566E")
			t.stone_dark = Color("#2A2640")
			t.rock = Color("#241F33")
			t.crystal = Color(0.7, 0.5, 1.0, 0.9)
			t.key_light = Color("#F0E2FF")
			t.fill_light = Color("#A070FF")
			t.ambient = Color("#9A8CC0")
			t.fog = Color("#22163E")
			t.style = Style.PORTAL
			t.floor_surface = ["marble_01", Color(0.3, 0.26, 0.52), 0.5, 0.8, 1.0]
			t.wall_surface = ["castle_wall_slates", Color(0.66, 0.6, 0.88), 0.8, 1.0, 1.0]
			t.rock_surface = ["cliff_side", Color(0.55, 0.48, 0.75), 0.3, 1.0, 1.0]
			t.rock_model_tint = Color(0.6, 0.52, 0.8)
		"world_05_sealed_chambers":
			t.title = "The Sealed Chambers"
			t.tagline = "Gold-lit gates guard the sacred receivers."
			t.accent = Color("#F2C46A")
			t.sky_top = Color("#08060E")
			t.sky_bottom = Color("#2A2216")
			t.horizon = Color("#C8963A")
			t.nebula = Color("#5A4A2A")
			t.stone = Color("#6E665A")
			t.stone_dark = Color("#363024")
			t.rock = Color("#2A251E")
			t.crystal = Color(1.0, 0.85, 0.45, 0.6)
			t.key_light = Color("#FFE4B0")
			t.fill_light = Color("#F2C46A")
			t.ambient = Color("#B0A488")
			t.fog = Color("#2A2216")
			t.style = Style.TEMPLE
			t.stone = Color("#6E7278")
			t.stone_dark = Color("#3C3E44")
			t.floor_surface = ["marble_01", Color(0.62, 0.54, 0.44), 0.5, 0.7, 1.0]
			t.wall_surface = ["marble_01", Color(1.0, 0.98, 0.94), 0.9, 0.6, 1.0]
		"world_06_shifting_labyrinth":
			t.title = "The Shifting Labyrinth"
			t.tagline = "Turning floors and charged stone shift beneath you."
			t.accent = Palette.POLARITY_RED
			t.sky_top = Color("#04060F")
			t.sky_bottom = Color("#1A1A40")
			t.horizon = Color("#B8404A")
			t.nebula = Color("#2A3A8A")
			t.stone = Color("#535A6A")
			t.stone_dark = Color("#262A38")
			t.rock = Color("#221F2A")
			t.crystal = Color(1.0, 0.42, 0.45, 0.7)
			t.key_light = Color("#FFE2E0")
			t.fill_light = Color("#5B9CFF")
			t.ambient = Color("#9098B8")
			t.fog = Color("#1A1A38")
			t.style = Style.NEON
			t.seam_glow = Color(0.95, 0.25, 0.65, 0.75)
			t.tile_roughness = 0.6
			t.tile_metallic = 0.3
			t.stone = Color("#3E4656")
			t.stone_dark = Color("#1B1F2A")
			t.sky_top = Color("#0A0410")
			t.sky_bottom = Color("#3A0E22")
			t.horizon = Color("#D0306A")
			t.nebula = Color("#1E6A80")
			t.crystal = Color(0.3, 0.95, 0.9, 0.8)
			t.fog = Color("#2A0C1C")
			t.floor_surface = ["blue_metal_plate", Color(0.36, 0.36, 0.5), 0.5, 0.8, 0.5]
			t.wall_surface = ["blue_metal_plate", Color(0.2, 0.2, 0.28), 0.6, 0.8, 0.5]
			t.rock_surface = ["dark_rock", Color(0.5, 0.45, 0.55), 0.4, 1.0, 1.0]
			t.metal_surface = ["blue_metal_plate", Color(0.4, 0.4, 0.5), 0.6, 0.8, 1.0]
			t.rock_model_tint = Color(0.42, 0.38, 0.48)
		"world_07_final_machine":
			t.title = "The Final Machine"
			t.tagline = "The final engine waits for its seal."
			t.accent = Color("#9AE8FF")
			t.sky_top = Color("#05041A")
			t.sky_bottom = Color("#1E1650")
			t.horizon = Color("#5A8AE8")
			t.nebula = Color("#7A3AC0")
			t.stone = Color("#5A607A")
			t.stone_dark = Color("#262A44")
			t.rock = Color("#211E33")
			t.crystal = Color(0.6, 0.8, 1.0, 1.0)
			t.key_light = Color("#EEF0FF")
			t.fill_light = Color("#9A70FF")
			t.ambient = Color("#9AA0D0")
			t.fog = Color("#1A1844")
			t.style = Style.VOID
			t.seam_glow = Color(1.0, 0.55, 0.15, 0.85)
			t.stone = Color("#383A42")
			t.stone_dark = Color("#16171C")
			t.rock = Color("#121318")
			t.sky_top = Color("#03030A")
			t.sky_bottom = Color("#141838")
			t.horizon = Color("#C86A2A")
			t.nebula = Color("#2A4AA8")
			t.crystal = Color(0.55, 0.8, 1.0, 0.6)
			t.floor_surface = ["dark_rock", Color(0.55, 0.55, 0.62), 0.5, 0.8, 1.0]
			t.wall_surface = ["dark_rock", Color(1.0, 1.0, 1.1), 0.6, 0.9, 1.0]
			t.rock_surface = ["dark_rock", Color(0.5, 0.5, 0.55), 0.35, 1.0, 1.0]
			t.rock_model_tint = Color(0.35, 0.35, 0.4)
		_:
			t.tagline = "Reconfigure reality. Control the maze. Complete the seal."
	return t


const REFLECTION_HDRI := "res://assets/third_party/polyhaven/kloofendal_misty_morning_puresky/kloofendal_misty_morning_puresky.hdr"

## One soft-sky HDRI shared by every stage, for reflections only (the visible background stays
## the painted Backdrop). Metal, ice and polished stone pick up real highlights from it.
static var _reflection_sky: Sky


static func reflection_sky() -> Sky:
	if _reflection_sky == null:
		var material := PanoramaSkyMaterial.new()
		material.panorama = load(REFLECTION_HDRI)
		material.energy_multiplier = 0.35
		_reflection_sky = Sky.new()
		_reflection_sky.sky_material = material
		_reflection_sky.radiance_size = Sky.RADIANCE_SIZE_128
		_reflection_sky.process_mode = Sky.PROCESS_MODE_QUALITY
	return _reflection_sky


## Lights and environment of a 3D stage, tuned to this world.
func apply_to_stage(environment: Environment, key: DirectionalLight3D, fill: DirectionalLight3D) -> void:
	environment.sky = reflection_sky()
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.ambient_light_color = ambient
	environment.fog_light_color = fog
	if key != null:
		key.light_color = key_light
	if fill != null:
		fill.light_color = fill_light
