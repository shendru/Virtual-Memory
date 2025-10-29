extends Camera2D

var dragStartMousePos = Vector2.ZERO
var dragStartCameraPos = Vector2.ZERO
var isDragging : bool = false

func _process(delta):
	Zoom()
	ClickAndDrag()


func Zoom():
	if Input.is_action_just_pressed("camera_zoom_in"):
		zoom *= 1.1
	if Input.is_action_just_pressed("camera_zoom_out"):
		zoom *= 0.9

func ClickAndDrag():
	if !isDragging and Input.is_action_just_pressed("click"):
		dragStartMousePos = get_viewport().get_mouse_position()
		dragStartCameraPos = position
		isDragging = true
	
	if isDragging and Input.is_action_just_released("click"):
		isDragging = false
	
	if isDragging:
		var moveVector = get_viewport().get_mouse_position() - dragStartMousePos
		position = dragStartCameraPos - moveVector * 1/zoom.x
