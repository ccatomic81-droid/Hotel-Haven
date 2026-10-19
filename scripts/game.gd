extends Node3D
## Original low-poly hotel tycoon with procedural geometry and offline saves.

const SAVE_PATH: String = "user://hotel_haven.json"
const ROOM_X = [-7.5, -2.5, 2.5, 7.5]
const ROOM_COST = [0, 70, 150, 275]
const ROOM_COUNT: int = 4
const NAVY: Color = Color("123d4f")
const TEAL: Color = Color("28c6ad")

var money: int = 40
var served: int = 0
var speed_level: int = 0
var decor_level: int = 0
var hired: bool = false
var unlocked: int = 1
var rooms: Array = []
var room_nodes: Array = []
var guests: Array = []
var player: Node3D
var cleaner: Node3D
var camera: Camera3D
var joystick: Control
var cash_label: Label
var info_label: Label
var hint_label: Label
var room_button: Button
var hire_button: Button
var speed_button: Button
var decor_button: Button
var guest_timer: float = 1.0
var checkin_wait: float = 0.0
var ui_time: float = 0.0
var save_time: float = 25.0
var saved_levels: Array = []

func _ready() -> void:
    randomize()
    _load_progress()
    _build_world()
    _build_interface()
    _refresh_ui()

func _process(delta: float) -> void:
    _move_player(delta)
    _guests_tick(delta)
    _rooms_tick(delta)
    _cleaner_tick(delta)
    checkin_wait = maxf(0.0, checkin_wait - delta)
    guest_timer -= delta
    if guest_timer <= 0.0:
        guest_timer = randf_range(4.0, 6.0)
        if guests.size() < 6:
            _spawn_guest()
    ui_time -= delta
    if ui_time <= 0.0:
        ui_time = 0.25
        _refresh_ui()
    save_time -= delta
    if save_time <= 0.0:
        save_time = 25.0
        _save_progress()

func _material(color: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.79
    return mat

func _box(parent: Node3D, location: Vector3, dimensions: Vector3, color: Color) -> void:
    var obj := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = dimensions
    obj.mesh = mesh
    obj.material_override = _material(color)
    obj.position = location
    parent.add_child(obj)

func _ball(parent: Node3D, location: Vector3, radius: float, color: Color) -> void:
    var obj := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    obj.mesh = mesh
    obj.material_override = _material(color)
    obj.position = location
    parent.add_child(obj)

func _cylinder(parent: Node3D, location: Vector3, radius: float, height: float, color: Color) -> void:
    var obj := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.height = height
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    obj.mesh = mesh
    obj.material_override = _material(color)
    obj.position = location
    parent.add_child(obj)

func _label3d(parent: Node3D, location: Vector3, content: String, color: Color = NAVY) -> void:
    var obj := Label3D.new()
    obj.text = content
    obj.position = location
    obj.font_size = 48
    obj.pixel_size = 0.007
    obj.modulate = color
    obj.outline_size = 8
    obj.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    obj.no_depth_test = true
    parent.add_child(obj)

func _character(outfit: Color, skin: Color) -> Node3D:
    var root := Node3D.new()
    add_child(root)
    _cylinder(root, Vector3(0, 0.83, 0), 0.33, 0.93, outfit)
    _ball(root, Vector3(0, 1.55, 0), 0.32, skin)
    _box(root, Vector3(-0.18, 0.27, 0), Vector3(0.18, 0.52, 0.24), NAVY)
    _box(root, Vector3(0.18, 0.27, 0), Vector3(0.18, 0.52, 0.24), NAVY)
    _ball(root, Vector3(-0.39, 0.92, 0), 0.14, skin)
    _ball(root, Vector3(0.39, 0.92, 0), 0.14, skin)
    return root

func _plant(parent: Node3D, x: float, z: float) -> void:
    _cylinder(parent, Vector3(x, 0.22, z), 0.35, 0.45, Color("d69676"))
    _ball(parent, Vector3(x, 0.98, z), 0.54, Color("49a970"))
    _ball(parent, Vector3(x - 0.25, 1.21, z), 0.33, Color("56c287"))

func _build_world() -> void:
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("b9e9df")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("fff9e6")
    env.ambient_light_energy = 0.7
    var world := WorldEnvironment.new()
    world.environment = env
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50, -35, 0)
    sun.light_energy = 1.3
    add_child(sun)
    _box(self, Vector3(0, -0.45, 0), Vector3(26, 0.7, 19), Color("5acda9"))
    _box(self, Vector3(0, -0.1, 0), Vector3(23, 0.12, 16), Color("fff1de"))
    _box(self, Vector3(0, 0, 3.1), Vector3(22, 0.07, 7.3), Color("e7d1b4"))
    _box(self, Vector3(-8.2, 0.48, 2.2), Vector3(3.2, 0.95, 0.9), Color("af795a"))
    _box(self, Vector3(-8.2, 0.99, 2.2), Vector3(3.3, 0.13, 1), Color("f9d8ac"))
    _label3d(self, Vector3(-8.2, 2.15, 2.2), "RECEPTION")
    _box(self, Vector3(0, 0.2, 4.2), Vector3(3.1, 0.13, 2.6), Color("a0decd"))
    _plant(self, -4.0, 5.2)
    _plant(self, 4.2, 5.4)
    _plant(self, -10.5, 0.0)
    _plant(self, 10.5, 0.0)
    _label3d(self, Vector3(8.2, 2.2, 6.7), "WELCOME!")
    for i in range(ROOM_COUNT):
        var root := Node3D.new()
        add_child(root)
        room_nodes.append(root)
        var state: String = "free" if i < unlocked else "locked"
        var level: int = 0
        if i < saved_levels.size():
            level = clampi(int(saved_levels[i]), 0, 3)
        rooms.append({"state": state, "level": level, "time": 0.0, "clean": 0.0})
        _refresh_room(i)
    player = _character(Color("f39c72"), Color("ffd5a9"))
    player.position = Vector3(-5, 0.04, 4.8)
    cleaner = _character(Color("66a9db"), Color("e9bc96"))
    cleaner.position = Vector3(0.8, 0.04, 4.9)
    cleaner.visible = hired
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.keep_aspect = Camera3D.KEEP_HEIGHT
    camera.size = 27.0
    camera.position = player.position + Vector3(14, 21, 22)
    add_child(camera)
    camera.current = true
    camera.look_at(player.position, Vector3.UP)

func _refresh_room(i: int) -> void:
    var root: Node3D = room_nodes[i]
    for child in root.get_children():
        child.queue_free()
    var x: float = float(ROOM_X[i])
    var room: Dictionary = rooms[i]
    var closed: bool = room["state"] == "locked"
    var tile := Color("d2ded7") if closed else Color("f9dfd9")
    if int(room["level"]) > 0:
        tile = Color("e6d6fa")
    _box(root, Vector3(x, 0.05, -3.8), Vector3(4.9, 0.15, 6.15), tile)
    _box(root, Vector3(x, 1, -6.88), Vector3(4.9, 2, 0.2), Color("f4d1ba"))
    _box(root, Vector3(x - 2.42, 0.8, -3.85), Vector3(0.15, 1.6, 6), Color("f4d1ba"))
    _box(root, Vector3(x + 2.42, 0.8, -3.85), Vector3(0.15, 1.6, 6), Color("f4d1ba"))
    if closed:
        _box(root, Vector3(x, 0.25, -3.7), Vector3(2.8, 0.4, 3), Color("b6ceca"))
        _label3d(root, Vector3(x, 2.3, -3), "ROOM %d\nLOCKED" % (i + 1), Color("44827b"))
        return
    _box(root, Vector3(x, 0.37, -4.25), Vector3(2.4, 0.44, 3.2), Color("d8a086"))
    _box(root, Vector3(x, 0.62, -4.25), Vector3(2.22, 0.18, 3.03), Color("f7fbff"))
    _box(root, Vector3(x, 0.75, -5.15), Vector3(2.18, 0.16, 1.05), Color("a8dedb"))
    _box(root, Vector3(x - 0.55, 0.84, -5.25), Vector3(0.85, 0.16, 0.6), Color("fff9e8"))
    _box(root, Vector3(x + 0.55, 0.84, -5.25), Vector3(0.85, 0.16, 0.6), Color("fff9e8"))
    _box(root, Vector3(x + 1.73, 0.33, -5.5), Vector3(0.58, 0.65, 0.6), Color("c8917c"))
    _ball(root, Vector3(x + 1.73, 0.79, -5.5), 0.22, Color("ffdf8f"))
    _plant(root, x - 1.8, -2.1)
    var status: String = "READY"
    var status_color: Color = TEAL
    if room["state"] == "occupied":
        status = "GUEST INSIDE"
        status_color = Color("e6a14f")
    elif room["state"] == "dirty":
        status = "CLEAN ME!"
        status_color = Color("e96f6f")
        _box(root, Vector3(x, 0.8, -3.7), Vector3(2, 0.14, 1.5), Color("e2a393"))
    _label3d(root, Vector3(x, 2.45, -3.0), "ROOM %d\n%s" % [i + 1, status], status_color)

func _free_room() -> int:
    for i in range(ROOM_COUNT):
        if rooms[i]["state"] == "free":
            return i
    return -1

func _spawn_guest() -> void:
    var shades := [Color("bb8adb"), Color("f1a95d"), Color("6b9fd5"), Color("d7809a")]
    var guest := _character(shades[randi() % shades.size()], Color("efc49e"))
    guest.position = Vector3(11, 0.04, 5.7)
    guests.append({"node": guest, "state": "arriving", "room": -1})

func _move_towards(person: Node3D, target: Vector3, delta: float, speed: float) -> bool:
    var before := person.position
    var after := before.move_toward(target, delta * speed)
    person.position = after
    if before.distance_to(target) > 0.04:
        person.rotation.y = lerp_angle(person.rotation.y, atan2(after.x - before.x, after.z - before.z), minf(delta * 9, 1))
    return after.distance_to(target) < 0.16

func _guests_tick(delta: float) -> void:
    for index in range(guests.size() - 1, -1, -1):
        var guest: Dictionary = guests[index]
        var person: Node3D = guest["node"]
        match guest["state"]:
            "arriving":
                if _move_towards(person, Vector3(-5.8, 0.04, 4.65), delta, 2.8):
                    guest["state"] = "waiting"
            "waiting":
                if player.position.distance_to(Vector3(-7, 0.04, 4.6)) < 2.9 and checkin_wait <= 0:
                    var room_id := _free_room()
                    if room_id >= 0:
                        guest["room"] = room_id
                        guest["state"] = "hall"
                        rooms[room_id]["state"] = "occupied"
                        rooms[room_id]["time"] = randf_range(9, 13)
                        _refresh_room(room_id)
                        checkin_wait = 1.2
            "hall":
                if _move_towards(person, Vector3(float(ROOM_X[guest["room"]]), 0.04, 1.0), delta, 3):
                    guest["state"] = "entering"
            "entering":
                if _move_towards(person, Vector3(float(ROOM_X[guest["room"]]), 0.04, -2.4), delta, 2.6):
                    guest["state"] = "staying"
                    person.visible = false
            "staying":
                var room: Dictionary = rooms[int(guest["room"])]
                room["time"] = float(room["time"]) - delta
                if float(room["time"]) <= 0.0:
                    room["state"] = "dirty"
                    _refresh_room(int(guest["room"]))
                    guest["state"] = "exit_hall"
                    person.visible = true
            "exit_hall":
                if _move_towards(person, Vector3(float(ROOM_X[guest["room"]]), 0.04, 1.0), delta, 3):
                    guest["state"] = "leaving"
            "leaving":
                if _move_towards(person, Vector3(11, 0.04, 5.7), delta, 3.3):
                    var tip: int = 27 + decor_level * 13
                    money += tip
                    served += 1
                    _save_progress()
                    person.queue_free()
                    guests.remove_at(index)

func _move_player(delta: float) -> void:
    var dx: float = 0.0
    var dz: float = 0.0
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        dx -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        dx += 1.0
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        dz -= 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        dz += 1.0
    var direction := Vector2(dx, dz)
    if joystick != null:
        var stick: Vector2 = joystick.get("direction")
        if stick.length() > 0.08:
            direction = stick
    direction = direction.limit_length(1.0)
    if direction.length() > 0.06:
        var step := Vector3(direction.x, 0, direction.y) * delta * (4.8 + speed_level * 0.7)
        player.position.x = clampf(player.position.x + step.x, -10.6, 10.6)
        player.position.z = clampf(player.position.z + step.z, -5.8, 6.65)
        player.rotation.y = lerp_angle(player.rotation.y, atan2(step.x, step.z), minf(delta * 12, 1))
    var goal := player.position + Vector3(14, 21, 22)
    camera.position = camera.position.lerp(goal, minf(delta * 4.3, 1))
    camera.look_at(player.position + Vector3(0, 0.4, 0), Vector3.UP)
    var size := get_viewport().get_visible_rect().size
    camera.size = lerpf(camera.size, 27.0 if size.y > size.x else 21.0, minf(delta * 3, 1))

func _rooms_tick(delta: float) -> void:
    for i in range(ROOM_COUNT):
        var room: Dictionary = rooms[i]
        if room["state"] != "dirty":
            continue
        var door := Vector3(float(ROOM_X[i]), 0.04, -1.65)
        if player.position.distance_to(door) < 2.35:
            room["clean"] = float(room["clean"]) + delta
        else:
            room["clean"] = maxf(0.0, float(room["clean"]) - delta * 0.2)
        if float(room["clean"]) >= 1.8:
            _clean_room(i)

func _clean_room(i: int) -> void:
    rooms[i]["state"] = "free"
    rooms[i]["clean"] = 0.0
    _refresh_room(i)

func _cleaner_tick(delta: float) -> void:
    if not hired:
        return
    var target: int = -1
    for i in range(ROOM_COUNT):
        if rooms[i]["state"] == "dirty":
            target = i
            break
    if target >= 0:
        if _move_towards(cleaner, Vector3(float(ROOM_X[target]), 0.04, -1.7), delta, 3.1):
            rooms[target]["clean"] = float(rooms[target]["clean"]) + delta * 0.65
            if float(rooms[target]["clean"]) >= 1.8:
                _clean_room(target)
    else:
        _move_towards(cleaner, Vector3(0.4, 0.04, 4.7), delta, 2.2)

func _style(color: Color) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = color
    s.set_corner_radius_all(16)
    s.content_margin_left = 12
    s.content_margin_top = 8
    s.content_margin_right = 12
    s.content_margin_bottom = 8
    return s

func _make_button(txt: String, color: Color) -> Button:
    var b := Button.new()
    b.text = txt
    b.custom_minimum_size = Vector2(166, 54)
    b.add_theme_font_size_override("font_size", 15)
    b.add_theme_color_override("font_color", NAVY)
    b.add_theme_stylebox_override("normal", _style(color))
    b.add_theme_stylebox_override("disabled", _style(Color("e1e9e5")))
    return b

func _build_interface() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var root := Control.new()
    layer.add_child(root)
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var header := PanelContainer.new()
    root.add_child(header)
    header.anchor_right = 1
    header.offset_left = 16
    header.offset_right = -16
    header.offset_top = 24
    header.offset_bottom = 116
    header.mouse_filter = Control.MOUSE_FILTER_IGNORE
    header.add_theme_stylebox_override("panel", _style(Color("fff9e8ee")))
    var bar := HBoxContainer.new()
    header.add_child(bar)
    var title := Label.new()
    title.text = "HOTEL\nHAVEN"
    title.add_theme_font_size_override("font_size", 26)
    title.add_theme_color_override("font_color", NAVY)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bar.add_child(title)
    cash_label = Label.new()
    cash_label.add_theme_font_size_override("font_size", 30)
    cash_label.add_theme_color_override("font_color", Color("16866e"))
    bar.add_child(cash_label)
    var status := PanelContainer.new()
    root.add_child(status)
    status.anchor_right = 1
    status.offset_left = 16
    status.offset_right = -16
    status.offset_top = 125
    status.offset_bottom = 171
    status.mouse_filter = Control.MOUSE_FILTER_IGNORE
    status.add_theme_stylebox_override("panel", _style(Color("fffffff0")))
    info_label = Label.new()
    info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info_label.add_theme_color_override("font_color", NAVY)
    status.add_child(info_label)
    hint_label = Label.new()
    root.add_child(hint_label)
    hint_label.anchor_left = 0
    hint_label.anchor_right = 1
    hint_label.anchor_top = 1
    hint_label.anchor_bottom = 1
    hint_label.offset_top = -320
    hint_label.offset_bottom = -267
    hint_label.offset_left = 14
    hint_label.offset_right = -14
    hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    hint_label.add_theme_font_size_override("font_size", 16)
    hint_label.add_theme_color_override("font_color", NAVY)
    hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var shop := VBoxContainer.new()
    root.add_child(shop)
    shop.anchor_left = 1
    shop.anchor_right = 1
    shop.anchor_top = 1
    shop.anchor_bottom = 1
    shop.offset_left = -188
    shop.offset_right = -14
    shop.offset_top = -259
    shop.offset_bottom = -16
    shop.add_theme_constant_override("separation", 7)
    room_button = _make_button("OPEN ROOM", Color("b0f3d9"))
    hire_button = _make_button("HIRE CLEANER", Color("cbe4ff"))
    speed_button = _make_button("MOVE FASTER", Color("ffe7b1"))
    decor_button = _make_button("ROOM DECOR", Color("f7d9e8"))
    for button in [room_button, hire_button, speed_button, decor_button]:
        button.size_flags_vertical = Control.SIZE_EXPAND_FILL
        shop.add_child(button)
    room_button.pressed.connect(_buy_room)
    hire_button.pressed.connect(_hire_cleaner)
    speed_button.pressed.connect(_buy_speed)
    decor_button.pressed.connect(_buy_decor)
    joystick = Control.new()
    joystick.set_script(load("res://scripts/joystick.gd"))
    root.add_child(joystick)
    joystick.anchor_top = 1
    joystick.anchor_bottom = 1
    joystick.offset_top = -224
    joystick.offset_bottom = -25
    joystick.offset_left = 12
    joystick.offset_right = 208

func _refresh_ui() -> void:
    cash_label.text = "$%d" % money
    info_label.text = "%d / 4 rooms     •     %d guests served" % [unlocked, served]
    var dirty: int = 0
    var waiting: int = 0
    for room in rooms:
        if room["state"] == "dirty":
            dirty += 1
    for guest in guests:
        if guest["state"] == "waiting":
            waiting += 1
    if dirty > 0:
        hint_label.text = "Clean dirty rooms to welcome new guests!"
    elif waiting > 0:
        hint_label.text = "Stand near RECEPTION to check in guests!"
    else:
        hint_label.text = "Serve guests, earn cash, expand your hotel!"
    if unlocked < ROOM_COUNT:
        room_button.text = "OPEN ROOM   $%d" % int(ROOM_COST[unlocked])
    else:
        room_button.text = "ALL ROOMS OPEN"
    room_button.disabled = unlocked >= ROOM_COUNT or (unlocked < ROOM_COUNT and money < int(ROOM_COST[unlocked]))
    hire_button.text = "CLEANER HIRED" if hired else "HIRE CLEANER  $175"
    hire_button.disabled = hired or money < 175
    var speed_cost: int = 95 + speed_level * 80
    speed_button.text = "MAX SPEED" if speed_level >= 5 else "MOVE FASTER  $%d" % speed_cost
    speed_button.disabled = speed_level >= 5 or money < speed_cost
    var decor_cost: int = 85 + decor_level * 95
    decor_button.text = "MAX DECOR" if decor_level >= 3 else "ROOM DECOR  $%d" % decor_cost
    decor_button.disabled = decor_level >= 3 or money < decor_cost

func _buy_room() -> void:
    if unlocked >= ROOM_COUNT or money < int(ROOM_COST[unlocked]):
        return
    money -= int(ROOM_COST[unlocked])
    rooms[unlocked]["state"] = "free"
    _refresh_room(unlocked)
    unlocked += 1
    _save_progress()
    _refresh_ui()

func _hire_cleaner() -> void:
    if hired or money < 175:
        return
    money -= 175
    hired = true
    cleaner.visible = true
    _save_progress()
    _refresh_ui()

func _buy_speed() -> void:
    var cost: int = 95 + speed_level * 80
    if speed_level >= 5 or money < cost:
        return
    money -= cost
    speed_level += 1
    _save_progress()
    _refresh_ui()

func _buy_decor() -> void:
    var cost: int = 85 + decor_level * 95
    if decor_level >= 3 or money < cost:
        return
    money -= cost
    decor_level += 1
    for i in range(unlocked):
        rooms[i]["level"] = decor_level
        _refresh_room(i)
    _save_progress()
    _refresh_ui()

func _load_progress() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return
    var data = JSON.parse_string(file.get_as_text())
    if not (data is Dictionary):
        return
    money = maxi(0, int(data.get("money", 40)))
    served = maxi(0, int(data.get("served", 0)))
    unlocked = clampi(int(data.get("unlocked", 1)), 1, ROOM_COUNT)
    hired = bool(data.get("hired", false))
    speed_level = clampi(int(data.get("speed", 0)), 0, 5)
    decor_level = clampi(int(data.get("decor", 0)), 0, 3)
    var lv = data.get("levels", [])
    if lv is Array:
        saved_levels = lv

func _save_progress() -> void:
    var lv: Array = []
    for room in rooms:
        lv.append(int(room["level"]))
    var data := {"money": money, "served": served, "unlocked": unlocked, "hired": hired, "speed": speed_level, "decor": decor_level, "levels": lv}
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(data))

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
        _save_progress()
