extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var save_path := "user://hotel_haven.json"
    var had_save := FileAccess.file_exists(save_path)
    var original := FileAccess.get_file_as_bytes(save_path) if had_save else PackedByteArray()
    var game = load("res://scripts/game.gd").new()
    root.add_child(game)
    game.set_process(false)
    game.money = 40
    game.pending_cash = 0
    game.served = 0
    game.player.position = Vector3(-7, 0.04, 4.6)
    game._spawn_guest()
    game.guests[0]["state"] = "waiting"
    game._guests_tick(0.05)
    assert(game.rooms[0]["state"] == "occupied", "Guest must reserve a free room")
    for n in range(1200):
        game._guests_tick(0.05)
    assert(game.guests.is_empty(), "Guest must leave after staying")
    assert(game.rooms[0]["state"] == "dirty", "Used room must need cleaning")
    assert(game.pending_cash > 0 and game.money == 40, "Earnings must wait for collection")
    game.player.position = Vector3(-7.5, 0.04, -1.65)
    for n in range(50):
        game._rooms_tick(0.05)
    assert(game.rooms[0]["state"] == "free", "Cleaning must reopen room")
    var earned: int = game.pending_cash
    game.player.position = Vector3(-9.3, 0.04, 3.8)
    game._collect_cash()
    game._collect_cash()
    assert(game.money == 40 + earned and game.pending_cash == 0, "Cash collected exactly once")
    assert(not game._walkable(Vector3(-7.5, 0, -4)), "Bed must block walking")
    assert(not game._walkable(Vector3(-2.5, 0, -2)), "Locked room must block walking")
    assert(game._walkable(Vector3(-7.5, 0, -1.6)), "Open room entrance must be accessible")
    for n in range(3):
        game._spawn_guest()
    assert(game._queue_index(2) == 2, "Guests must have separate queue positions")
    game.pending_cash = 37
    game._save_progress()
    game.pending_cash = 0
    game._load_progress()
    assert(game.pending_cash == 37, "Uncollected cash must survive restart")
    if had_save:
        var file := FileAccess.open(save_path, FileAccess.WRITE)
        file.store_buffer(original)
        file.close()
    else:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
    print("PASS: guest stay, cleaning, cash collection, collision, queue, save recovery")
    game.queue_free()
    await process_frame
    quit()
