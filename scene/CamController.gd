extends Node3D

const ZOOM_FACTOR = 1.2
const ROTATE_SPEED = 0.1
const PAN_SPEED = 0.005

@export var UiNode: Control

var enable_cam_control: bool = true

func _ready():
	var _discard = UiNode.connect("mouse_entered", _ui_mouse_entered)
	_discard = UiNode.connect("mouse_exited", _ui_mouse_exited)
	
func _ui_mouse_entered():
	enable_cam_control = false
	
func _ui_mouse_exited():
	enable_cam_control = true

func _input(event):
	if not enable_cam_control:
		return
		
	if event is InputEventMouseMotion:
		if event.button_mask == MOUSE_BUTTON_MASK_RIGHT:
			# Rotate
			self.rotate_y(deg_to_rad(-1 * event.get_relative().x * ROTATE_SPEED))
			$CamRotHelper.rotate_x(deg_to_rad(-1 * event.get_relative().y * ROTATE_SPEED))

			#Stop rotation over top or bottom
			var camera_rot = $CamRotHelper.rotation
			camera_rot.x = clamp(camera_rot.x, -90, 90)
			$CamRotHelper.rotation = camera_rot
		elif event.button_mask == MOUSE_BUTTON_MASK_MIDDLE:
			# Pan
			self.translate(Vector3(
				-1 * event.get_relative().x * PAN_SPEED,
				event.get_relative().y * PAN_SPEED,
				0.0
			))
	elif event is InputEventMouseButton and event.is_pressed():
		# Zoom
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			self.scale_object_local(Vector3.ONE * (ZOOM_FACTOR))
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			self.scale_object_local(Vector3.ONE * (1/ZOOM_FACTOR))
