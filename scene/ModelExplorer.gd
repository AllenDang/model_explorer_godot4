extends Node3D

signal gltf_start_to_load
signal gltf_is_loaded(success:bool, gltf:Node, faceCountDic:Dictionary)

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
			var gltf_nodes = get_tree().get_nodes_in_group(GlobalSignal.GLTF_GROUP)
			for n in gltf_nodes:
				n.queue_free()

			worker = Worker.new(Callable(self, "_load_gltf").bind(files[0]))
			worker.start()
			
			gltf_start_to_load.emit()

func _load_gltf(file:String):
	var gltf_doc = GLTFDocument.new()
	var gltf_state = GLTFState.new()
	
	var err = gltf_doc.append_from_file(file, gltf_state)
	
	var faceCountDic:Dictionary
	
	var nodes = gltf_state.json["nodes"]
	var meshes = gltf_state.json["meshes"]
	var accessors = gltf_state.json["accessors"]
	
	var i = 1
	for node in nodes:
		var name = "Empty#%d" % i
		if node.has("name"):
			name = node["name"].replace(".", "")
		i += 1
		
		if not node.has("mesh"):
			continue
			
		var mesh = meshes[node["mesh"]]
		
		var indicesCount = 0
		for primitive in mesh["primitives"]:
			var indices = primitive["indices"]
			var a = accessors[indices]
			indicesCount += a["count"]
			
		faceCountDic[name] = indicesCount / 3
	
	var success = false
	var gltf:Node = null
	
	if err == OK:
		success = true
		gltf = gltf_doc.generate_scene(gltf_state)
		gltf.add_to_group(GlobalSignal.GLTF_GROUP)
		call_deferred("add_child", gltf)
	
	gltf_is_loaded.emit(success, gltf, faceCountDic)
