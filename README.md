# Hotel Haven 🏨

An original low-poly 3D hotel management game prototype for Android, built with Godot 4.4.1.

## Gameplay
- Move your hotel attendant with the mobile joystick (or WASD / arrow keys).
- Walk near the reception desk to check in guests.
- Guests pay when their stay finishes.
- Stand in dirty rooms to clean them.
- Unlock four rooms, hire an automatic cleaner, increase movement speed and upgrade room decor.
- Your progress is automatically saved locally on your device.

## Automatic GitHub APK builds
GitHub Actions runs **Android APK (debug)** when changes are pushed to `main`.
1. Open the **Actions** tab.
2. Select **Android APK (debug)**, then the latest successful run.
3. Download the **HotelHaven-Android-APK** artifact.
4. Unzip it and install `HotelHaven-debug.apk` on your Android device.

You may also run it manually using **Actions → Android APK (debug) → Run workflow**.

This is a first playable prototype with original procedural graphics, not a copy of SayGames' artwork or assets. A public Play Store release requires additional testing, polishing and release signing.


### v0.2 visual and gameplay update
- Bright cutaway interiors, tiled floors, windows, sofas, headboards, reception props and warm lighting.
- Bellhop uniforms, hats, gloves and animated walking limbs; player selection ring.
- Guests queue separately, stay, leave dirty rooms and pay into visible cash stacks.
- Walk beside reception to collect earnings; uncollected cash is saved across restarts.
- Room walls, beds, reception desk and locked rooms block player movement.
- Original procedural models and branding. This is an evolving four-room prototype, not a complete reproduction of another game.

Run gameplay checks: `godot --headless --path . --script tests/gameplay_smoke.gd`.
