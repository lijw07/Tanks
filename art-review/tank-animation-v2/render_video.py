import bpy
from pathlib import Path

out=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(out/'Pocket_Armor_Animation_Review.blend'))
scene=bpy.data.scenes['02 | AZURE SCOUT']
bpy.context.window.scene=scene
scene.render.resolution_x=960
scene.render.resolution_y=720
scene.cycles.samples=12
scene.frame_start=1
scene.frame_end=336
scene.frame_step=2
# Render every second timeline frame at 12 fps: the same 14-second timing as the 24 fps source.
scene.render.fps=12
scene.render.image_settings.media_type='VIDEO'
scene.render.image_settings.file_format='FFMPEG'
scene.render.ffmpeg.format='MPEG4'
scene.render.ffmpeg.codec='H264'
scene.render.ffmpeg.constant_rate_factor='HIGH'
scene.render.filepath=str(out/'previews/tank_animation_demo.mp4')
bpy.ops.render.render(animation=True)
print('ANIMATION_VIDEO_COMPLETE',flush=True)
