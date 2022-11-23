extends PanelContainer

@onready var BtnClose:Button = $VBoxContainer/HBoxContainer/Button
@onready var MatNameLabel:Label = $VBoxContainer/HBoxContainer/MarginContainer/Label
@onready var MatTree:Tree = $VBoxContainer/Tree

var materialView:StandardMaterial3D

func set_material_view(mat:StandardMaterial3D):
	materialView = mat

# Called when the node enters the scene tree for the first time.
func _ready():
	BtnClose.pressed.connect(_on_btn_close_pressed)
	MatTree.item_activated.connect(_on_material_property_double_clicked.bind(MatTree))
	
	if materialView != null:
		MatNameLabel.text = materialView.resource_name
		
		_setup_material_property(materialView)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_just_pressed("close_popup"):
		queue_free()

func _on_btn_close_pressed():
	queue_free()
	
func _on_material_property_double_clicked(tree:Tree):
	var item:TreeItem = tree.get_selected()
	var tex = item.get_metadata(1)
	if tex != null:
		GlobalSignal.trigger_texture_viewer.emit(tex)

func _create_property(root:TreeItem, name:String, value):
	if value == null:
		return
		
	var item:TreeItem = MatTree.create_item(root)
	item.set_text(0, name)
	
	if value is Texture2D:
		var img = value.get_image() as Image
		img.resize(50, 50)
		item.set_icon(1, ImageTexture.create_from_image(img))
		item.set_metadata(1, value)
	else:
		if value is Color:
			var img = Image.create(50, 20, false, Image.FORMAT_RGBA8)
			img.fill(value)
			item.set_icon(1, ImageTexture.create_from_image(img))
		else:
			item.set_text(1, "%s" % value)

func _setup_material_property(mat:StandardMaterial3D):
	var root = MatTree.create_item()
	
	_create_property(root, "albedo", mat.albedo_color)
	_create_property(root, "albedo texture", mat.albedo_texture)
	_create_property(root, "rough/metal", Vector2(mat.roughness, mat.metallic))
	_create_property(root, "rough/metal texture", mat.roughness_texture)
	_create_property(root, "emission", mat.emission)
	_create_property(root, "emission texture", mat.emission_texture)
	_create_property(root, "transparency", mat.transparency)
	_create_property(root, "normal map", mat.normal_texture)
	_create_property(root, "height map", mat.heightmap_texture)
