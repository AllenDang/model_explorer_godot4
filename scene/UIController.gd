extends Node

@export var Grid:Node

@onready var InfoPanel: PanelContainer = $InfoPanel
@onready var ToolPanel: PanelContainer = $ToolPanel
@onready var LoadingPanel: PanelContainer = $LoadingPanel
@onready var MsgPanel: PanelContainer = $MessagePanel
@onready var MsgLabel: Label = $MessagePanel/MarginContainer/Label
@onready var Row: VBoxContainer = $InfoPanel/MarginContainer/Row
@onready var CbWireframe: CheckBox = $ToolPanel/MarginContainer/Row/CbWireframe
@onready var CbExplode: CheckBox = $ToolPanel/MarginContainer/Row/CbExplode
@onready var CbHideGrid: CheckBox = $ToolPanel/MarginContainer/Row/CbHideGrid

const TextureViewer = preload("res://scene/TextureViewer.tscn")
var texViewer

const MaterialViewer = preload("res://scene/MaterialViewer.tscn")
var matViewer

const MeshInfoViewer = preload("res://scene/MeshInfo.tscn")
var meshViewer

const DYNAMIC_CONTROL_GROUP = "dynamic control"

var maxAabb:AABB

var animationPlayers: Array[Node]

var _originalPosDic: Dictionary

var _faceCountDic: Dictionary

class MeshInfo:
	var name:String
	var vertexCount:int
	var mesh:MeshInstance3D
	
class AnimationInfo:
	var name:String
	var length:float
	var player:AnimationPlayer

func _ready():
	GlobalSignal.trigger_texture_viewer.connect(_show_texture_viewer)

func _process(_delta):
	if Input.is_action_just_pressed("toggle_wireframe"):
		CbWireframe.button_pressed = not CbWireframe.button_pressed
	
	if Input.is_action_just_pressed("explode_meshes"):
		CbExplode.button_pressed = not CbExplode.button_pressed
		
	if Input.is_action_just_pressed("toggle_grid"):
		CbHideGrid.button_pressed = not CbHideGrid.button_pressed
		
	if Input.is_action_just_pressed("close_popup"):
		MeshExt.mesh_clear_all_outline()

func _on_root_gltf_start_to_load():
	InfoPanel.visible = false
	ToolPanel.visible = false
	MsgPanel.visible = false
	LoadingPanel.visible = true
	
	_originalPosDic.clear()
	_faceCountDic.clear()
	
	var dyna_controls = get_tree().get_nodes_in_group(DYNAMIC_CONTROL_GROUP)
	for ctl in dyna_controls:
		ctl.queue_free()

func _on_root_gltf_is_loaded(success, gltf, faceCountDic:Dictionary):
	Input.action_press("close_popup")
	
	if not success:
		MsgLabel.text = "Failed to load model..."
		LoadingPanel.visible = false
		MsgPanel.visible = true
		return
		
	InfoPanel.visible = true
	ToolPanel.visible = true
	LoadingPanel.visible = false
	
	_faceCountDic = faceCountDic
	
	animationPlayers = gltf.find_children("*", "AnimationPlayer")

	var meshes:Array[Node] = gltf.find_children("*", "MeshInstance3D")
	
	if meshes.size() > 0:
		# Create tree panel
		var meshInfoTree:Tree = Tree.new()
		meshInfoTree.add_to_group(DYNAMIC_CONTROL_GROUP)
		meshInfoTree.columns = 2
		meshInfoTree.column_titles_visible = true
		meshInfoTree.hide_root = true
		meshInfoTree.mouse_filter = Control.MOUSE_FILTER_PASS
		meshInfoTree.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		meshInfoTree.item_selected.connect(_on_mesh_item_selected.bind(meshInfoTree))
		meshInfoTree.item_activated.connect(_on_mesh_item_double_clicked.bind(meshInfoTree))
		
		meshInfoTree.set_column_title(0, "Mesh (%d)" % meshes.size())
		meshInfoTree.set_column_title(1, "Face count")
		
		var meshParent:TreeItem = meshInfoTree.create_item()

		# Mesh section
		var meshArray:Array[MeshInfo]
		
		const MAX_NAME_LENGTH = 20
		
		for mesh in meshes:
			mesh = mesh as MeshInstance3D
			
			# Record original positin if it is not ZERO in order to restore after explode
			if not mesh.position.is_zero_approx():
				_originalPosDic[mesh.get_instance_id()] = mesh.position
			
			# Calculate max aabb
			var aabb = mesh.mesh.get_aabb()
			if maxAabb.position > aabb.position:
				maxAabb.position = aabb.position
			if maxAabb.end < aabb.end:
				maxAabb.end = aabb.end
				
			var meshInfo = MeshInfo.new()
			meshInfo.name = mesh.name

			if _faceCountDic.has(mesh.name):
				meshInfo.vertexCount = _faceCountDic[mesh.name]
			meshInfo.mesh = mesh
			
			meshArray.append(meshInfo)
			
		meshArray.sort_custom(func(a, b): return a.vertexCount > b.vertexCount)
		
		for mi in meshArray:
			var short_name = String(mi.name)
			
			if short_name.length() > MAX_NAME_LENGTH:
				short_name = short_name.substr(0, MAX_NAME_LENGTH) + "..."
			
			var meshItem:TreeItem = meshInfoTree.create_item(meshParent)

			meshItem.set_text(0, short_name)
			meshItem.set_tooltip_text(0, mi.name)
			meshItem.set_text(1, "%d" % mi.vertexCount)
			meshItem.set_metadata(0, mi.mesh)

		Row.add_child(meshInfoTree)
		
		var material_array: Array[Material]
		var texture_array: Array[Variant]
		
		var add_texture_to_array = func(texture):
			if texture != null and not texture_array.has(texture):
				texture_array.append(texture)

		for mesh in meshes:
			# Gather material
			for si in mesh.mesh.get_surface_count():
				var mat = mesh.get_active_material(si) as Material
				if not material_array.has(mat):
					material_array.append(mat)

					if mat is BaseMaterial3D:
						# Gather texture
						add_texture_to_array.call(mat.albedo_texture)
						add_texture_to_array.call(mat.roughness_texture)
						add_texture_to_array.call(mat.metallic_texture)
						add_texture_to_array.call(mat.emission_texture)
						add_texture_to_array.call(mat.heightmap_texture)
						add_texture_to_array.call(mat.ao_texture)
						add_texture_to_array.call(mat.rim_texture)
						add_texture_to_array.call(mat.refraction_texture)
						add_texture_to_array.call(mat.heightmap_texture)
						add_texture_to_array.call(mat.normal_texture)
						add_texture_to_array.call(mat.clearcoat_texture)
						add_texture_to_array.call(mat.subsurf_scatter_texture)
					elif mat is ShaderMaterial:
						var parameters : Array[String] = [
							"_MainTex",
							"_ShadeTexture",
							"_ReceiveShadowTexture",
							"_ShadingGradeTexture",
							"_RimTexture",
							"_SphereAdd",
							"_EmissionMap",
						]
						for parameter_name in parameters:
							var parameter = (mat as ShaderMaterial).get_shader_parameter(parameter_name)
							add_texture_to_array.call(parameter)
		
		# Material section
		if material_array.size() > 0:
			var materialInfoTree:Tree = Tree.new()
			materialInfoTree.add_to_group(DYNAMIC_CONTROL_GROUP)
			materialInfoTree.columns = 1
			materialInfoTree.column_titles_visible = true
			materialInfoTree.hide_root = true
			materialInfoTree.mouse_filter = Control.MOUSE_FILTER_PASS
			materialInfoTree.size_flags_vertical = Control.SIZE_EXPAND_FILL

			materialInfoTree.item_activated.connect(_on_material_item_double_clicked.bind(materialInfoTree))

			materialInfoTree.set_column_title(0, "Material (%d)" % material_array.size())

			var matParent:TreeItem = materialInfoTree.create_item()

			for mat in material_array:
				var matItem:TreeItem = materialInfoTree.create_item(matParent)
				matItem.set_text(0, mat.resource_name)
				matItem.set_metadata(0, mat)

				var img:Image
				
				if mat is StandardMaterial3D:
					if mat.albedo_texture != null:
						matItem.set_text(0, mat.resource_name)

						img = mat.albedo_texture.get_image()
						img.resize(32, 32)
					else:
						img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
						img.fill(mat.albedo_color)
				elif mat is ShaderMaterial:
					var parameters : Array[String] = [
						"_MainTex",
						"_ShadeTexture",
						"_ReceiveShadowTexture",
						"_ShadingGradeTexture",
						"_RimTexture",
						"_SphereAdd",
						"_EmissionMap",
					]

					for parameter_name in parameters:
						if img != null:
							break
							
						var parameter : Variant = (mat as ShaderMaterial).get_shader_parameter(parameter_name)
						if parameter is Image and parameter_name == "_MainTex":
							matItem.set_text(0, parameter_name.trim_prefix("_").capitalize())
							img = mat.albedo_texture.get_image()
							img.resize(32, 32)
						elif parameter is Image:
							img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
							img.fill(parameter)
					
				matItem.set_icon(0, ImageTexture.create_from_image(img))
				
			Row.add_child(materialInfoTree)
			
		# Texture section
		if texture_array.size() > 0:
			var textureInfoTree:Tree = Tree.new()
			textureInfoTree.add_to_group(DYNAMIC_CONTROL_GROUP)
			textureInfoTree.columns = 1
			textureInfoTree.column_titles_visible = true
			textureInfoTree.hide_root = true
			textureInfoTree.mouse_filter = Control.MOUSE_FILTER_PASS
			textureInfoTree.size_flags_vertical = Control.SIZE_EXPAND_FILL

			textureInfoTree.item_activated.connect(_on_texture_double_clicked.bind(textureInfoTree))

			textureInfoTree.set_column_title(0, "Texture (%d)" % texture_array.size())

			var texParent = textureInfoTree.create_item()

			for tex in texture_array:
				if tex is Texture2D:
					var img = (tex as Texture2D).get_image()
					img.resize(50, 50)

					var texItem:TreeItem = textureInfoTree.create_item(texParent)
					texItem.set_icon(0, ImageTexture.create_from_image(img))
					texItem.set_text(0, "[%d x %d] %s" % [tex.get_width(), tex.get_height(), calc_data_size(tex.get_image().get_data().size())])
					texItem.set_metadata(0, tex)
				elif tex is Image:
					var img : Image = tex
					img.resize(50, 50)

					var texItem:TreeItem = textureInfoTree.create_item(texParent)
					texItem.set_icon(0, ImageTexture.create_from_image(img))
					texItem.set_text(0, "[%d x %d] %s" % [tex.get_width(), tex.get_height(), calc_data_size(tex.get_image().get_data().size())])
					texItem.set_metadata(0, tex)
				
			
			Row.add_child(textureInfoTree)
	
	for animationPlayer in animationPlayers:
		if animationPlayer == null:
			continue
			
		var animationArray:Array[AnimationInfo]
		
		var animLibList:Array[StringName] = animationPlayer.get_animation_library_list()
		for animLibName in animLibList:
			var animLib:AnimationLibrary = animationPlayer.get_animation_library(animLibName)
			var animList:Array[StringName] = animLib.get_animation_list()
			
			for animName in animList:
				# Get animation length
				var anim:Animation = animationPlayer.get_animation(animName)
				var animLength = anim.length
				
				var playableAnimName = String(animName)
				if not String(animLibName).is_empty():
					playableAnimName = "%s/%s" % [animLibName, animName]
					
				var animInfo = AnimationInfo.new()
				animInfo.name = playableAnimName
				animInfo.length = animLength
				animInfo.player = animationPlayer
				
				animationArray.append(animInfo)

		if animationArray.size() > 0:
			var animationTree:Tree = Tree.new()
			animationTree.add_to_group(DYNAMIC_CONTROL_GROUP)
			animationTree.columns = 2
			animationTree.column_titles_visible = true
			animationTree.hide_root = true
			animationTree.mouse_filter = Control.MOUSE_FILTER_PASS
			animationTree.size_flags_vertical = Control.SIZE_EXPAND_FILL

			animationTree.item_activated.connect(_on_animation_item_double_clicked.bind(animationTree))

			animationTree.set_column_title(0, "Animation (%d)" % animationArray.size())
			animationTree.select_mode = Tree.SELECT_ROW

			var animRoot = animationTree.create_item()

			for anim in animationArray:
				var animItem:TreeItem = animationTree.create_item(animRoot)
				animItem.set_text(0, anim.name)
				animItem.set_metadata(0, anim)
				animItem.set_text(1, "%.2f sec" % anim.length)

			Row.add_child(animationTree)
		
	# Create convex collision
	for mesh in meshes:
		mesh = mesh as MeshInstance3D
		mesh.create_convex_collision()
		
		var staticBody:StaticBody3D = mesh.get_node("%s_col" % mesh.name)
		staticBody.input_event.connect(_on_mesh_clicked.bind(mesh))

func calc_data_size(byte_size:int) -> String:
	var unit = "KB"
	
	# KB
	var size = byte_size / 1024.0
	
	# MB
	if size > 1024:
		size /= 1024.0
		unit = "MB"
	
	# GB
	if size > 1024:
		size /= 1024.0
		unit = "GB"
	
	return "%.2f %s" % [size, unit]

func _on_cb_wireframe_toggled(button_pressed):
	if button_pressed:
		get_viewport().debug_draw = Viewport.DEBUG_DRAW_WIREFRAME
	else:
		get_viewport().debug_draw = Viewport.DEBUG_DRAW_DISABLED

func _on_mesh_item_selected(tree:Tree):
	var meshItem:TreeItem = tree.get_selected()
	MeshExt.mesh_clear_all_outline()
	MeshExt.mesh_create_outline(meshItem.get_metadata(0))

func _on_mesh_item_double_clicked(tree:Tree):
	var meshItem:TreeItem = tree.get_selected()
	var mesh:MeshInstance3D = meshItem.get_metadata(0)
	if mesh != null:
		var uvLines = MeshExt.draw_uv_texture(mesh.mesh)
		if uvLines.size() > 0:
			GlobalSignal.trigger_texture_viewer.emit(uvLines)
		
#		GlobalSignal.reposition_camera.emit(mesh.mesh.get_aabb())
		
func _on_material_item_double_clicked(tree:Tree):
	var matItem:TreeItem = tree.get_selected()
	var mat:StandardMaterial3D = matItem.get_metadata(0)
	if mat != null:
		if matViewer != null:
			matViewer.queue_free()
		
		matViewer = MaterialViewer.instantiate()
		matViewer.add_to_group(DYNAMIC_CONTROL_GROUP)
		matViewer.set_material_view(mat)
		add_child(matViewer)

func _on_texture_double_clicked(tree:Tree):
	var texItem:TreeItem = tree.get_selected()
	var tex:Texture2D = texItem.get_metadata(0)
	if tex != null:
		GlobalSignal.trigger_texture_viewer.emit(tex)
		

func _on_animation_item_double_clicked(tree:Tree):
	var animItem:TreeItem = tree.get_selected()
	
	var animInfo = animItem.get_metadata(0) as AnimationInfo
	
	var animationPlayer:AnimationPlayer = animInfo.player
	if animationPlayer != null and animationPlayer.has_animation(animInfo.name):
		animationPlayer.queue(animInfo.name)


func _show_texture_viewer(tex):
	if texViewer != null:
		texViewer.queue_free()
			
	texViewer = TextureViewer.instantiate()
	texViewer.add_to_group(DYNAMIC_CONTROL_GROUP)
	texViewer.set_draw_data(tex)
	add_child(texViewer)


func _on_cb_explode_toggled(button_pressed):
	var nodes = get_tree().get_nodes_in_group(GlobalSignal.GLTF_GROUP)
			
	for n in nodes:
		var meshes:Array[Node] = n.find_children("*", "MeshInstance3D")
		for m in meshes:
			m = m as MeshInstance3D
			
			if button_pressed:
				if m.position.is_zero_approx():
					m.position = m.get_aabb().get_center() - maxAabb.get_center()
				else:
					m.position *= 3.0
			else:
				if _originalPosDic.has(m.get_instance_id()):
					m.position = _originalPosDic[m.get_instance_id()]
				else:
					m.position = Vector3.ZERO


func _on_cb_hide_grid_toggled(button_pressed):
	if Grid != null:
		Grid.visible = not button_pressed

func _on_mesh_clicked(camera: Node, event: InputEvent, position: Vector3, normal: Vector3, shape_idx: int, mesh: MeshInstance3D):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if meshViewer != null:
			meshViewer.queue_free()
			
		if MeshExt.mesh_has_outline(mesh):
			MeshExt.mesh_remove_outline(mesh)
			return
			
		MeshExt.mesh_clear_all_outline()
		MeshExt.mesh_create_outline(mesh)
		
		if meshViewer != null:
			meshViewer.queue_free()
		
		meshViewer = MeshInfoViewer.instantiate()
		meshViewer.add_to_group(DYNAMIC_CONTROL_GROUP)
		var faceCount = 0
		if _faceCountDic.has(mesh.name):
			faceCount = _faceCountDic[mesh.name]
		meshViewer.set_data(mesh, faceCount)
		
		var pos = event.position + Vector2(60, -100)
		# Prevent window out of screen
		var viewportSize = get_viewport().size / 2
		if pos.x > viewportSize.x:
			pos.x = viewportSize.x
		if pos.y < 0:
			pos.y = 0
			
		meshViewer.position = pos

		add_child(meshViewer)
