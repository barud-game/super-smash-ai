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

Gevecht in de fighter (M3; aanvallen, hitlag, knockback, DI, tech, L-cancel, hitfall):

    <godot_console> --headless --path . --script res://tests/test_fighter_combat.gd

Match-flow (M6; stocks, timer, tiebreak, sudden death, pauze, training):

    <godot_console> --headless --path . --script res://tests/test_match.gd

Verdediging (M4; shield, lightshield, shield-HP/break, powershield, OoS, rolls, grab/pummel/throws, release):

    <godot_console> --headless --path . --script res://tests/test_defense.gd

Aerial-bereik (afspraak 8, SH-aerials tegen staande hurtboxes; geometrisch, `-- --table` toont de invoer-vensters):

    <godot_console> --headless --path . --script res://tests/test_aerial_reach.gd

Character-pipeline (stats per character, taunt + tekstwolkje, props, move-override, validator-velden, match/sandbox; gebruikt een tijdelijke map in `user://`):

    <godot_console> --headless --path . --script res://tests/test_character_pipeline.gd

Wall jump (vlag, smash weg van de muur, richting, special-reset, cooldown, determinisme):

    <godot_console> --headless --path . --script res://tests/test_wall_jump.gd
