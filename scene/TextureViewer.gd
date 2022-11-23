extends PanelContainer

@onready var BtnClose:Button = $Row/HBoxContainer/Button
@onready var Viewer:TextureRect = $Row/Panel/TextureRect

var texture:Texture2D

# Called when the node enters the scene tree for the first time.
func _ready():
	BtnClose.pressed.connect(_on_btn_close_pressed)
	if texture != null:
		Viewer.texture = texture
		
func _process(_delta):
	if Input.is_action_just_released("close_popup"):
		queue_free()

func set_texture(tex:Texture2D):
	texture = tex

func _on_btn_close_pressed():
	queue_free()
