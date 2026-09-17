# Icon-only weapon HUD

The health panel is removed. Fire and Mine are represented only by their icons, with no surrounding cards, labels, counts, timer text, or separate bars. A shader fills each icon from bottom to top using the actual weapon cooldown; a subtle moving edge makes the recharge visible. Full gold means ready. The controls remain clickable with 72–80 pixel touch targets.

Pause, touch movement, and the cursor-aligned reticle remain. Spectator mode replaces the weapon icons with previous/next arrows and a subject label.

The game is rendered in an isolated Godot viewport for interaction and responsive checks, preventing desktop pointer motion from interfering with injected test events. Validation covers cooldown progress, pause/resume, input, layout bounds, crosshair alignment, and spectator behavior at desktop, tablet, and phone sizes. Captures show ready, reloading, and partial-fill states.
