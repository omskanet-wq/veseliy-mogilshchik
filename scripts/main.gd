extends Node
## Root entry point. Builds the entire game tree procedurally so the project
## ships without hand-edited scene resources beyond the main scene stub.

const HUDClass := preload("res://scripts/ui/hud.gd")

var game: Game
var hud: Control


func _ready() -> void:
	_build_world()
	_build_hud()


func _build_world() -> void:
	game = preload("res://scripts/game.gd").new()
	game.name = "Game"
	# Environment.
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.55, 0.78)
	sky_mat.sky_horizon_color = Color(0.78, 0.78, 0.70)
	sky_mat.ground_horizon_color = Color(0.6, 0.55, 0.45)
	sky_mat.ground_bottom_color = Color(0.32, 0.27, 0.22)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_density = 0.005
	env.fog_light_color = Color(0.78, 0.80, 0.82)
	env_node.environment = env
	game.add_child(env_node)
	# Sun.
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	game.add_child(sun)
	# Camera rig.
	var rig := preload("res://scripts/camera_rig.gd").new()
	rig.name = "CameraRig"
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 55
	rig.add_child(cam)
	game.add_child(rig)
	# Grid.
	var grid := preload("res://scripts/grid.gd").new()
	grid.name = "Grid"
	game.add_child(grid)
	# Player.
	var player := preload("res://scripts/player.gd").new()
	player.name = "Player"
	game.add_child(player)
	# Dog.
	var dog := preload("res://scripts/dog.gd").new()
	dog.name = "Dog"
	dog.position = Vector3(2, 0, 2)
	game.add_child(dog)
	add_child(game)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UILayer"
	add_child(layer)
	hud = HUDClass.new()
	hud.name = "HUD"
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.game = game
	hud.main = self
	layer.add_child(hud)


func open_name_dialog(cell: Cell) -> void:
	hud.open_name_dialog(cell)
