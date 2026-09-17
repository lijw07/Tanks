# Battlefield HUD and cursor feedback

Fire and Mine now use matching cartoon menu panels with weapon icons and live cooldown progress. The bars empty when used, fill from the actual gameplay timers, and show Ready when usable. No tank counter or ammo quantities appear in the battlefield HUD.

The Mortar meter uses its actual slower reload duration. Mines use the same 2.5-second constant as gameplay. Pausing freezes both timers, and resuming preserves progress. Keyboard labels reflect saved bindings. Mobile layouts retain the touch movement pad without overlapping the weapon controls.

The crosshair is a screen-space marker centered on the pointer-event coordinates used by the aim ray. It is independent of the floor projection and camera zoom. UI hover, pause, spectating, and returning to the menu restore the normal cursor. Spectator controls remain available and hide weapon meters and shortcuts.

Validation: tests/hud_feedback.gd exercises actual button clicks and cooldowns, two camera views, cursor and aim projection, pause/resume, spectator transition, and 1280×800, 390×844, 820×1180, 844×390, and 320×568 native viewport renders. The JSON report and previews are in this folder; these are native window checks, not physical browser-device tests.
