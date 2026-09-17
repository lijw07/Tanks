# Cartoon menu redesign

Native Godot UI using centered main-menu selections, rounded Fredoka lettering, thick dark outlines, a faceted navy backdrop, warm yellow primary actions, and portraits of the actual low-poly tank models.

The main menu and tank picker now share the same visual language. Pause, settings, results, and the HUD inherit the shared theme. Tank selection displays gameplay-derived speed, hull, shell damage, reload interval, and shells per volley; no balance values were changed.

Run the main project with F5. The connected flow remains Play → choose one of eight tanks → Roll out → random arena. The game-flow test exercises pointer input on the main menu and tank choices, verifies selected models and reload values, and checks pause/restart/results/return/quit behavior. The validation report and native renders are in this directory.

Responsive captures cover desktop 1280×800, phone 390×844, tablet 820×1180, landscape 844×390, and small phone 320×568. Short phones omit the large preview to keep all eight choices, stats, and actions visible. These are native window checks; browser export and physical-device testing remain separate.

The font and its license are packaged in assets/ui/fonts. Portrait source models are the existing game assets; tools/render_ui_portraits.gd regenerates the images without an external art service.
