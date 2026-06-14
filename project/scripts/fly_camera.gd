class_name FlyCamera
extends Camera3D

@export var speed: float = 5.0
@export var mouse_sensitivity: float = 0.002

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * mouse_sensitivity
		rotation.x -= event.relative.y * mouse_sensitivity
		rotation.x = clamp(rotation.x, -PI/2, PI/2)
		rotation.z = 0

func _process(delta: float) -> void:
	var input_dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): input_dir.z -= 1
	if Input.is_physical_key_pressed(KEY_S): input_dir.z += 1
	if Input.is_physical_key_pressed(KEY_A): input_dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D): input_dir.x += 1
	if Input.is_physical_key_pressed(KEY_E): input_dir.y += 1
	if Input.is_physical_key_pressed(KEY_Q): input_dir.y -= 1
	
	input_dir = input_dir.normalized()
	
	var forward_backward = transform.basis.z
	var right = transform.basis.x
	var up = Vector3.UP
	
	var move_vec = right * input_dir.x + forward_backward * input_dir.z + up * input_dir.y
	
	var current_speed = speed
	if Input.is_physical_key_pressed(KEY_SHIFT):
		current_speed *= 3.0
		
	position += move_vec * current_speed * delta
