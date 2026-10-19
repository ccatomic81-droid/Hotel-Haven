extends Control
## A touch-friendly analog joystick with mouse testing support.
var direction: Vector2 = Vector2.ZERO
var active_touch: int = -1
var center: Vector2 = Vector2.ZERO
var radius: float = 70.0
var knob: Vector2 = Vector2.ZERO

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    resized.connect(_layout)
    _layout()

func _layout() -> void:
    center = size * 0.5
    radius = minf(size.x, size.y) * 0.35
    if active_touch == -1:
        knob = center
    queue_redraw()

func _draw() -> void:
    draw_circle(center, radius + 13.0, Color(1, 1, 1, 0.18))
    draw_circle(center, radius, Color(0.05, 0.20, 0.24, 0.28))
    draw_circle(knob, radius * 0.44, Color(1, 1, 1, 0.9))
    draw_circle(knob, radius * 0.29, Color(0.2, 0.73, 0.63, 0.9))

func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and active_touch == -1:
            active_touch = event.index
            _set_stick(event.position)
        elif not event.pressed and active_touch == event.index:
            _release()
    elif event is InputEventScreenDrag and event.index == active_touch:
        _set_stick(event.position)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            active_touch = -2
            _set_stick(event.position)
        elif active_touch == -2:
            _release()
    elif event is InputEventMouseMotion and active_touch == -2:
        _set_stick(event.position)

func _set_stick(pos: Vector2) -> void:
    direction = (pos - center).limit_length(radius) / radius
    knob = center + direction * radius
    queue_redraw()

func _release() -> void:
    active_touch = -1
    direction = Vector2.ZERO
    knob = center
    queue_redraw()
