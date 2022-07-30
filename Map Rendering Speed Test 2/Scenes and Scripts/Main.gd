extends Control

""" Tile Set """
const TILES_PATH = "res://Assets/Tiles/"
enum TILE_STATS {Collisions}

const MAFIC_TILES = ["Felsic", "Intermediate", "Mafic", "Ultra Mafic"]
const TILES_TO_ADD = {
	"Felsic": [false],
	"Intermediate": [false],
	"Mafic": [false],
	"Ultra Mafic": [false]
}

""" Setup """
onready var setup_center_container = get_node("Camera2D/Setup")

const DEFAULT_SCALE = 1.0
const CELL_SIZE = 16
onready var tile_scale = get_node("Camera2D/Setup/VBoxContainer/Tile Scale/Tile Scale")


""" Render """
onready var render_vbox = get_node("Camera2D/Render")
onready var scroll_left = get_node("Camera2D/Render/Scroll Left/Scroll Left")

const DEFAULT_CAMERA_SPEED = 1000.0
onready var camera_speed = get_node("Camera2D/Render/Camera Speed/Camera Speed")

const DEFAULT_LOW_FPS = 25
onready var high_used_tiles_line = get_node("Camera2D/Render/Clear Once Used Tiles is Greater Than X/LineEdit")
onready var high_used_tiles_check = get_node("Camera2D/Render/Clear Once Used Tiles is Greater Than X/Check")
onready var low_fps_line = get_node("Camera2D/Render/Clear Once FPS is Less Than X/LineEdit")
onready var low_fps_check = get_node("Camera2D/Render/Clear Once FPS is Less Than X/Check")

onready var startup_time = get_node("Camera2D/Render/Startup Time/Startup Time")
onready var time_per_render = get_node("Camera2D/Render/Time Per Render/Time Per Render")
onready var fps = get_node("Camera2D/Render/FPS/FPS")
onready var tiles_on_map = get_node("Camera2D/Render/Tiles On Map/Tiles on Map")
onready var used_tiles = get_node("Camera2D/Render/Used Tiles/Used Tiles")
onready var tile_map = get_node("TileMap")

onready var camera = get_node("Camera2D")

""" Time Vars """
var time_start
var time_now

""" Misc Vars """
var rng: RandomNumberGenerator
var simplex_map: OpenSimplexNoise
var tile_set: TileSet

""" Simplex Noise """
func setup_simplex():
	""" Setup Simplex Map """
	
	simplex_map = OpenSimplexNoise.new()
	simplex_map.seed = rng.randi()
	simplex_map.octaves = 1
	simplex_map.period = 10
	simplex_map.persistence = 1.0

func get_mafic_tile(pos):
	""" Get Simplex Map Value """
	
	var value = 1 - (simplex_map.get_noise_2dv(pos) + 1)/2.0
	value = min(int(value*4), 3)
	return TILES_TO_ADD.keys().find(MAFIC_TILES[value])

""" Setup Functions """
func _ready():
	randomize()
	rng = RandomNumberGenerator.new()
	rng.seed = randi()
	
	tile_scale.text = str(DEFAULT_SCALE)
	camera_speed.text = str(DEFAULT_CAMERA_SPEED)
	
	setup_center_container.show()
	render_vbox.hide()

func _on_Setup_Button_pressed():
	setup_center_container.hide()
	render_vbox.show()
	setup()

func setup():
	""" Setup """
	
	time_start = OS.get_ticks_msec()
	tile_map.scale = Vector2(1,1)*float(tile_scale.text)
	
	setup_simplex()
	
	render_tile_map()
	high_used_tiles_line.text = str(int(tiles_on_map.text)*4)
	low_fps_line.text = str(DEFAULT_LOW_FPS)
	time_now = OS.get_ticks_msec()
	startup_time.text = str((time_now - time_start)/1000.0)

func setup_tile_set():
	""" Create the Tile Set """
	
	tile_set = TileSet.new()
	var id
	for tile in TILES_TO_ADD.keys():
		
		id = tile_set.get_last_unused_tile_id()
		tile_set.create_tile(id)
		tile_set.tile_set_name(id, tile)
		tile_set.tile_set_texture(id, load(TILES_PATH))
	
	"""
	var ts = TileSet.new()
	var id = ts.get_last_unused_tile_id()
	ts.create_tile(id)
	ts.tile_set_name(id, ...)
	ts.tile_set_texture(id, ...)
	ts.tile_set_region(id, ...)
	...
	ResourceSaver.save("res://tiles.tres", ts)
	
	"""

func pos_to_tile_map(pos):
	""" Convert Pos to TileMap Pos """
	
	var hold = pos/(CELL_SIZE*float(tile_scale.text))
	return Vector2(round(hold.x), round(hold.y))

""" Render """
const MAX_FPS_WAIT_COUNTER = 10
var FPS_WAIT_COUNTER = MAX_FPS_WAIT_COUNTER
func render_tile_map():
	""" Render the Tile Map by getting its rect and adding all unused tiles inside of it """
	
	var time_start = OS.get_ticks_msec()
	
	# Clear
	if high_used_tiles_check.pressed and (int(used_tiles.text) >= int(high_used_tiles_line.text)):
		tile_map.clear()
	
	if low_fps_check.pressed and (int(fps.text) < int(low_fps_line.text)):
		FPS_WAIT_COUNTER += 1
		if FPS_WAIT_COUNTER >= MAX_FPS_WAIT_COUNTER:
			FPS_WAIT_COUNTER = 0
			tile_map.clear()
	
	var camera_starting_tile = pos_to_tile_map($Camera2D.position)
	var camera_ending_tile = pos_to_tile_map($Camera2D.position + Vector2(1024, 600))
	var tiles_per_axis = (camera_ending_tile - camera_starting_tile)/float(tile_scale.text)
	
	var loc
	for x in tiles_per_axis.x:
		for y in tiles_per_axis.y:
			loc = camera_starting_tile + Vector2(x,y)
			if tile_map.get_cellv(loc) == -1:
				tile_map.set_cellv(loc, get_mafic_tile(loc))
	
	tiles_on_map.text = str(round(tiles_per_axis.x*tiles_per_axis.y))
	used_tiles.text = str(len(tile_map.get_used_cells()))
	
	if int(used_tiles.text) >= int(high_used_tiles_line.text):
		used_tiles.modulate = Color(1,0,0)
	else:
		used_tiles.modulate = Color(0,1,0)
	
	var time_now = OS.get_ticks_msec()
	time_per_render.text = str((time_now - time_start)/1000.0)

func _process(delta):
	
	fps.text = str(round(1.0/delta))
	if float(fps.text) < float(low_fps_line.text):
		fps.modulate = Color(1,0,0)
	else:
		fps.modulate = Color(0,1,0)

	if scroll_left.pressed:
		camera.position.x -= float(camera_speed.text)*delta
		render_tile_map()
	
	











