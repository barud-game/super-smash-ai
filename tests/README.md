# Tests

Headless, geen scène nodig. Exit code is 0 bij succes, 1 bij falen. Eerst één keer importeren
(maakt de class-cache aan), daarna draaien (vanuit de repo-root):

```
"C:\Users\yassi\Downloads\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe" --headless --import --path .
"C:\Users\yassi\Downloads\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe" --headless --path . --script res://tests/run_tests.gd
```

Visual/rig:

    <godot_console> --headless --path . --script res://tests/test_visual.gd

Movement (M1, vergelijking met Melee-waarden per archetype; gescripte input, geen controller nodig):

    <godot_console> --headless --path . --script res://tests/test_movement.gd

Ledge, teeter, KO-API en respawn (M2):

    <godot_console> --headless --path . --script res://tests/test_ledge.gd
