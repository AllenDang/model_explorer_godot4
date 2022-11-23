extends Node3D

const GLTF_GROUP = "gltf group"

signal gltf_start_to_load
signal gltf_is_loaded(success:bool, gltf:Node)

const Worker = preload("res://script/Worker.gd")
var worker: Worker

# Called when the node enters the scene tree for the first time.
func _ready():
	get_viewport().files_dropped.connect(_on_file_dropped)

func _on_file_dropped(files:PackedStringArray):
	if files.size() == 1:
		var ext = files[0].get_extension()
		if ext == "glb" or ext == "gltf":
			gltf_start_to_load.emit()
			
			# unload previous loaded scene
			var gltf_nodes = get_tree().get_nodes_in_group(GLTF_GROUP)
			for n in gltf_nodes:
				n.queue_free()

			worker = Worker.new(Callable(self, "_load_gltf").bind(files[0]))
			worker.start()
			
			gltf_start_to_load.emit()

func _load_gltf(file:String):
	var gltf_doc = GLTFDocument.new()
	var gltf_state = GLTFState.new()
	var err = gltf_doc.append_from_file(file, gltf_state)
	
	var success = false
	var gltf:Node = null
	
	if err != OK:
		print("failed to load gltf model")
	else:
		success = true
		gltf = gltf_doc.generate_scene(gltf_state)
		gltf.add_to_group(GLTF_GROUP)
		call_deferred("add_child", gltf)
		
	gltf_is_loaded.emit(success, gltf)
