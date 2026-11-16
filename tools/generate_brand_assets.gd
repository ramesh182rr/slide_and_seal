extends SceneTree
## Generates the app icon, Android adaptive icon layers and boot splash image from code, so no
## image editor or third-party art is involved. Needs a renderer (not --headless):
##   godot --path game --script ../tools/generate_brand_assets.gd
## Writes PNGs to res://assets/brand/. Re-run after changing the emblem.

const OUT := "res://assets/brand"
const SKY_TOP := Color("#071225")
const SKY_BOTTOM := Color("#0F3442")

## [file name, size, kind]
const JOBS := [
	["icon.png", 512, "full"],
	["icon_192.png", 192, "full"],
	["icon_foreground_432.png", 432, "foreground"],
	["icon_background_432.png", 432, "background"],
	["icon_monochrome_432.png", 432, "monochrome"],
	["splash.png", 1024, "splash"],
]

var _frame := 0
var _viewports: Array[SubViewport] = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for job: Array in JOBS:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(job[1], job[1])
		viewport.transparent_bg = job[2] == "foreground" or job[2] == "monochrome"
		viewport.disable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		var art := Art.new()
		art.kind = job[2]
		art.size = Vector2(job[1], job[1])
		viewport.add_child(art)
		root.add_child(viewport)
		_viewports.append(viewport)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 4:
		for i: int in JOBS.size():
			var path := "%s/%s" % [OUT, JOBS[i][0]]
			_viewports[i].get_texture().get_image().save_png(path)
			print("wrote ", path)
		quit(0)
	return false


class Art:
	extends Control

	var kind := "full"

	func _draw() -> void:
		var s := size.x
		var c := size * 0.5
		match kind:
			"full":
				_background(s)
				BrandMark.draw_emblem(self, c, s * 0.3)
			"background":
				_background(s)
			"foreground":
				# Adaptive icons crop to the centre ~61%: keep the emblem well inside it.
				BrandMark.draw_emblem(self, c, s * 0.2)
			"monochrome":
				BrandMark.draw_emblem(self, c, s * 0.2, Color.WHITE, Color.WHITE, false)
			"splash":
				draw_rect(Rect2(Vector2.ZERO, size), BrandMark.SPLASH_BG)
				var layout := BrandMark.splash_layout(c, s)
				BrandMark.draw_emblem(self, layout[0], layout[1])
				BrandMark.draw_wordmark(self, layout[2], layout[3])

	func _background(s: float) -> void:
		var bands := 64
		for i: int in bands:
			var f := float(i) / (bands - 1)
			draw_rect(Rect2(0, s * i / bands, s, s / bands + 1.0), SKY_TOP.lerp(SKY_BOTTOM, f))
		# A soft glow behind the emblem.
		for i: int in 24:
			var f := 1.0 - float(i) / 24.0
			draw_circle(size * 0.5, s * 0.46 * f, Color(BrandMark.RING, 0.012))
