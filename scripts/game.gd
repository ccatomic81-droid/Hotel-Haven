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
var materials: Dictionary = {}
var pending_cash: int = 0
var cash_pile: Node3D
var action_ring: MeshInstance3D
var progress_label: Label
var elapsed: float = 0.0

func _ready() -> void:
    randomize()
    _load_progress()
    _build_world()
    _build_interface()
    _refresh_ui()

func _process(delta: float) -> void:
    elapsed += delta
    _move_player(delta)
    _animate_people(delta)
    _collect_cash()
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
    if materials.has(color):
        return materials[color]
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.85
    materials[color] = mat
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

func _character(outfit: Color, skin: Color, staff: bool = false) -> Node3D:
    var root := Node3D.new()
    add_child(root)
    var rig := Node3D.new()
    rig.name = "Rig"
    root.add_child(rig)
    _cylinder(rig, Vector3(0, 0.91, 0), 0.30, 0.72, outfit)
    _ball(rig, Vector3(0, 1.51, 0), 0.30, skin)
    _ball(rig, Vector3(0, 1.61, -0.08), 0.27, Color("493a43"))
    for side in [-1.0, 1.0]:
        var leg := Node3D.new()
        leg.name = "LeftLeg" if side < 0 else "RightLeg"
        leg.position = Vector3(side * 0.16, 0.61, 0)
        rig.add_child(leg)
        _cylinder(leg, Vector3(0, -0.22, 0), 0.105, 0.44, NAVY)
        _box(leg, Vector3(0, -0.46, 0.06), Vector3(0.24, 0.12, 0.36), Color("293445"))
        var arm := Node3D.new()
        arm.name = "LeftArm" if side < 0 else "RightArm"
        arm.position = Vector3(side * 0.34, 1.13, 0)
        rig.add_child(arm)
        _cylinder(arm, Vector3(0, -0.18, 0), 0.105, 0.36, outfit)
        _ball(arm, Vector3(0, -0.40, 0), 0.12, Color("fff9ed") if staff else skin)
        _ball(rig, Vector3(side * 0.10, 1.54, 0.27), 0.035, NAVY)
    if staff:
        _cylinder(rig, Vector3(0, 1.82, 0), 0.31, 0.17, outfit)
        _cylinder(rig, Vector3(0, 1.75, 0.03), 0.35, 0.045, Color("ffcf66"))
        for y in [0.80, 0.99, 1.17]:
            _ball(rig, Vector3(0, y, 0.30), 0.035, Color("ffe29a"))
    root.set_meta("last_position", root.position)
    root.set_meta("phase", randf() * TAU)
    return root

func _plant(parent: Node3D, x: float, z: float) -> void:
    _cylinder(parent, Vector3(x, 0.22, z), 0.35, 0.45, Color("d69676"))
    _ball(parent, Vector3(x, 0.98, z), 0.54, Color("49a970"))
    _ball(parent, Vector3(x - 0.25, 1.21, z), 0.33, Color("56c287"))

func _build_world() -> void:
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("a8dfea")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("fff9e6")
    env.ambient_light_energy = 0.85
    var world := WorldEnvironment.new()
    world.environment = env
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50, -35, 0)
    sun.light_energy = 1.0
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 45.0
    add_child(sun)
    _box(self, Vector3(0, -0.45, 0), Vector3(26, 0.7, 19), Color("62caa1"))
    _box(self, Vector3(0, -0.1, 0), Vector3(23, 0.12, 16), Color("fff1de"))
    for tx in range(-11, 12):
        for tz in range(-7, 8):
            if (tx + tz) % 2 == 0:
                _box(self, Vector3(tx, -0.025, tz), Vector3(0.98, 0.015, 0.98), Color("f6e7cd"))
    _box(self, Vector3(0, 0, 3.1), Vector3(22, 0.07, 7.3), Color("df758b"))
    _box(self, Vector3(-8.2, 0.48, 2.2), Vector3(3.2, 0.95, 0.9), Color("af795a"))
    _box(self, Vector3(-8.2, 0.99, 2.2), Vector3(3.3, 0.13, 1), Color("f9d8ac"))
    _label3d(self, Vector3(-8.2, 2.15, 2.2), "CHECK IN", Color("ffffff"))
    _box(self, Vector3(-8.4, 1.16, 2.2), Vector3(0.7, 0.3, 0.45), NAVY)
    _ball(self, Vector3(-7.2, 1.15, 2.3), 0.13, Color("ffce5e"))
    _box(self, Vector3(0, 0.08, 2.2), Vector3(22, 0.05, 0.12), Color("f7c97c"))
    _box(self, Vector3(0, 0.08, 5.8), Vector3(22, 0.05, 0.12), Color("f7c97c"))
    for x in [-2.0, 3.3, 8.2]:
        _sofa(self, Vector3(x, 0, 5.5), Color("49a9b1"))
    cash_pile = Node3D.new()
    add_child(cash_pile)
    _update_cash_pile()
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
    player = _character(Color("eb6573"), Color("ffd5a9"), true)
    player.position = Vector3(-5, 0.04, 4.8)
    cleaner = _character(Color("66a9db"), Color("e9bc96"), true)
    cleaner.position = Vector3(0.8, 0.04, 4.9)
    cleaner.visible = hired
    action_ring = MeshInstance3D.new()
    var ring := TorusMesh.new()
    ring.inner_radius = 0.55
    ring.outer_radius = 0.65
    action_ring.mesh = ring
    action_ring.material_override = _material(Color("ffe49b"))
    player.add_child(action_ring)
    action_ring.position.y = 0.07
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.keep_aspect = Camera3D.KEEP_HEIGHT
    camera.size = 27.0
    camera.position = player.position + Vector3(4, 25, 18)
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
    var tile := Color("b6cdc9") if closed else Color("ffe8ae")
    if int(room["level"]) > 0:
        tile = Color("e6d6fa")
    _box(root, Vector3(x, 0.05, -3.8), Vector3(4.9, 0.15, 6.15), tile)
    _box(root, Vector3(x, 1, -6.88), Vector3(4.9, 2, 0.2), Color("59bbc7"))
    _box(root, Vector3(x - 2.42, 0.8, -3.85), Vector3(0.15, 1.6, 6), Color("59bbc7"))
    _box(root, Vector3(x + 2.42, 0.8, -3.85), Vector3(0.15, 1.6, 6), Color("59bbc7"))
    _box(root, Vector3(x, 2.04, -6.88), Vector3(4.95, 0.13, 0.26), Color("c2faf0"))
    _box(root, Vector3(x, 1.2, -6.75), Vector3(1.5, 0.85, 0.06), Color("a7e7f2"))
    _box(root, Vector3(x, 1.2, -6.70), Vector3(0.06, 0.9, 0.06), Color("ffffff"))
    for side in [-1.0, 1.0]:
        _box(root, Vector3(x + side * 1.8, 0.65, -0.82), Vector3(1.2, 1.3, 0.20), Color("59bbc7"))
        _box(root, Vector3(x + side * 1.14, 0.65, -0.82), Vector3(0.12, 1.4, 0.26), Color("ffdf96"))
    if closed:
        _box(root, Vector3(x, 0.25, -3.7), Vector3(2.8, 0.4, 3), Color("b6ceca"))
        _label3d(root, Vector3(x, 2.3, -3), "BUILD ROOM %d\n$%d" % [i + 1, int(ROOM_COST[i])], Color("44827b"))
        return
    _box(root, Vector3(x, 0.37, -4.25), Vector3(2.4, 0.44, 3.2), Color("ba8058"))
    _box(root, Vector3(x, 0.62, -4.25), Vector3(2.22, 0.18, 3.03), Color("f7fbff"))
    _box(root, Vector3(x, 0.75, -5.15), Vector3(2.18, 0.16, 1.05), Color("608be4"))
    _box(root, Vector3(x - 0.55, 0.84, -5.25), Vector3(0.85, 0.16, 0.6), Color("fff9e8"))
    _box(root, Vector3(x + 0.55, 0.84, -5.25), Vector3(0.85, 0.16, 0.6), Color("fff9e8"))
    _box(root, Vector3(x + 1.73, 0.33, -5.5), Vector3(0.58, 0.65, 0.6), Color("c8917c"))
    _ball(root, Vector3(x + 1.73, 0.79, -5.5), 0.22, Color("ffdf8f"))
    _box(root, Vector3(x, 0.9, -5.9), Vector3(2.5, 0.95, 0.18), Color("bd855d"))
    _box(root, Vector3(x, 0.17, -3.8), Vector3(3.5, 0.04, 4.4), Color("f5c97f"))
    _box(root, Vector3(x - 1.8, 0.8, -4.9), Vector3(0.1, 0.8, 1.1), NAVY)
    _plant(root, x - 1.8, -2.1)
    if room["state"] == "occupied":
        _ball(root, Vector3(x, 0.97, -5.15), 0.25, Color("efc49e"))
    if room["state"] == "dirty":
        for n in range(4):
            _ball(root, Vector3(x - 1.3 + n * 0.72, 0.16, -1.5), 0.15, Color("bba18a"))
    var status: String = "READY"
    var status_color: Color = TEAL
    if room["state"] == "occupied":
        status = "GUEST INSIDE"
        status_color = Color("e6a14f")
    elif room["state"] == "dirty":
        status = "CLEAN ME!"
        status_color = Color("e96f6f")
        _box(root, Vector3(x, 0.8, -3.7), Vector3(2, 0.14, 1.5), Color("e2a393"))
    _label3d(root, Vector3(x, 2.45, -3.0), "%d • %s" % [101 + i, status], status_color)

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
                var place: int = _queue_index(index)
                if _move_towards(person, Vector3(-5.8 + place * 1.0, 0.04, 4.65), delta, 2.8):
                    guest["state"] = "waiting"
            "waiting":
                var place: int = _queue_index(index)
                _move_towards(person, Vector3(-5.8 + place * 1.0, 0.04, 4.65), delta, 2.8)
                if place == 0 and player.position.distance_to(Vector3(-7, 0.04, 4.6)) < 2.9 and checkin_wait <= 0:
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
                    pending_cash += tip
                    _update_cash_pile()
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
        var next := player.position + step
        next.x = clampf(next.x, -10.6, 10.6)
        next.z = clampf(next.z, -5.8, 6.65)
        if _walkable(Vector3(next.x, player.position.y, player.position.z)):
            player.position.x = next.x
        if _walkable(Vector3(player.position.x, player.position.y, next.z)):
            player.position.z = next.z
        player.rotation.y = lerp_angle(player.rotation.y, atan2(step.x, step.z), minf(delta * 12, 1))
    var goal := player.position + Vector3(4, 25, 18)
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
    info_label.text = "★ %d     •     %d / 4 rooms     •     %d guests" % [1 + served / 10, unlocked, served]
    var dirty: int = 0
    var waiting: int = 0
    for room in rooms:
        if room["state"] == "dirty":
            dirty += 1
    for guest in guests:
        if guest["state"] == "waiting":
            waiting += 1
    if pending_cash > 0:
        hint_label.text = "Collect $%d beside reception!" % pending_cash
    elif dirty > 0:
        hint_label.text = "Clean dirty rooms to welcome new guests!"
    elif waiting > 0:
        hint_label.text = "Stand near RECEPTION to check in guests!"
    else:
        hint_label.text = "Check in guests • Clean rooms • Collect cash"
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
    pending_cash = maxi(0, int(data.get("pending_cash", 0)))
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
    var data := {"pending_cash": pending_cash, "money": money, "served": served, "unlocked": unlocked, "hired": hired, "speed": speed_level, "decor": decor_level, "levels": lv}
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(data))

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
        _save_progress()

func _sofa(parent: Node3D, location: Vector3, color: Color) -> void:
    _box(parent, location + Vector3(0, 0.43, 0), Vector3(2.2, 0.65, 0.9), color)
    _box(parent, location + Vector3(0, 0.91, 0.3), Vector3(2.2, 0.65, 0.25), color)
    for side in [-1.0, 1.0]:
        _box(parent, location + Vector3(side * 1.0, 0.77, 0), Vector3(0.25, 0.4, 0.9), color.lightened(0.15))
        _box(parent, location + Vector3(side * 0.48, 0.78, 0), Vector3(0.8, 0.12, 0.65), color.lightened(0.12))

func _queue_index(index: int) -> int:
    var count: int = 0
    for i in range(index):
        if guests[i]["state"] in ["waiting", "arriving"]:
            count += 1
    return count

func _walkable(point: Vector3) -> bool:
    # Room partitions and beds block movement; open doorways stay accessible.
    if point.z < -0.8:
        var room_id: int = clampi(int(floor((point.x + 10.0) / 5.0)), 0, ROOM_COUNT - 1)
        if room_id >= unlocked:
            return false
        var center: float = float(ROOM_X[room_id])
        if absf(point.x - center) > 1.98:
            return false
        if absf(point.x - center) < 1.5 and point.z < -2.3:
            return false
    if point.x > -10.1 and point.x < -6.2 and point.z > 1.3 and point.z < 3.1:
        return false
    return true

func _animate_people(_delta: float) -> void:
    var people: Array = [player, cleaner]
    for guest in guests:
        people.append(guest["node"])
    for person in people:
        var last: Vector3 = person.get_meta("last_position", person.position)
        var moving: bool = person.position.distance_to(last) > 0.001
        var rig: Node3D = person.get_node("Rig")
        var phase: float = elapsed * 12.0 + float(person.get_meta("phase", 0.0))
        var swing: float = sin(phase) * 0.55 if moving else 0.0
        rig.position.y = absf(sin(phase)) * 0.065 if moving else 0.0
        rig.get_node("LeftLeg").rotation.x = swing
        rig.get_node("RightLeg").rotation.x = -swing
        rig.get_node("LeftArm").rotation.x = -swing * 0.65
        rig.get_node("RightArm").rotation.x = swing * 0.65
        person.set_meta("last_position", person.position)
    action_ring.scale = Vector3.ONE * (1.0 + sin(elapsed * 4.0) * 0.05)

func _update_cash_pile() -> void:
    for child in cash_pile.get_children():
        child.queue_free()
    if pending_cash <= 0:
        return
    for n in range(mini(12, ceili(pending_cash / 15.0))):
        var pos := Vector3(-9.7 + (n % 2) * 0.6, 0.15 + (n / 4) * 0.18, 3.6 + ((n / 2) % 2) * 0.4)
        _box(cash_pile, pos, Vector3(0.5, 0.16, 0.32), Color("4bd989"))
        _box(cash_pile, pos + Vector3(0, 0.085, 0), Vector3(0.13, 0.02, 0.33), Color("fff5ce"))
    _label3d(cash_pile, Vector3(-9.3, 1.6, 3.8), "$%d" % pending_cash, Color("ffffff"))

func _collect_cash() -> void:
    if pending_cash <= 0 or player.position.distance_to(Vector3(-9.3, 0.04, 3.8)) > 1.6:
        return
    money += pending_cash
    pending_cash = 0
    _update_cash_pile()
    _save_progress()
    _refresh_ui()
