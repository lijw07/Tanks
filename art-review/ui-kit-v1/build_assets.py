from pathlib import Path
import json
ROOT=Path(__file__).resolve().parent
C={'ink':'#263431','paper':'#101a20','panel':'#19262d','orange':'#f6a34a','mint':'#a9cbbb','blue':'#78b4ce','red':'#d77561','muted':'#a8bbc4','line':'#49616b'}
def svg(body,w=24,h=24):
 return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" fill="none">{body}</svg>\n'
paths={
'play':'<path d="m9 5 11 7-11 7Z" fill="#263431"/>',
'pause':'<path d="M8 5v14M16 5v14" stroke-width="4"/>',
'close':'<path d="m6 6 12 12M6 18 18 6"/>',
'back':'<path d="m10 5-7 7 7 7M3 12h18"/>',
'arrow':'<path d="m14 5 7 7-7 7M3 12h18"/>',
'check':'<path d="m5 12 5 5L20 6"/>',
'chevron':'<path d="m9 5 7 7-7 7"/>',
'plus':'<path d="M12 4v16M4 12h16"/>',
'minus':'<path d="M4 12h16"/>',
'home':'<path d="m3 11 9-8 9 8v10H3ZM9 21v-8h6v8"/>',
'map':'<path d="m3 5 6-2 6 2 6-2v16l-6 2-6-2-6 2ZM9 3v16M15 5v16"/>',
'shield':'<path d="m12 3 8 3v6c0 5-8 9-8 9s-8-4-8-9V6Z"/><path d="m8 11 3 3 5-6"/>',
'bolt':'<path d="m14 2-9 12h6l-1 8 9-12h-6Z" fill="#263431"/>',
'crosshair':'<circle cx="12" cy="12" r="7"/><path d="M12 1v6m0 10v6M1 12h6m10 0h6"/>',
'shell':'<path d="M8 20V9q0-5 4-7 4 2 4 7v11ZM8 16h8"/>',
'mine':'<circle cx="12" cy="12" r="6"/><path d="M12 2v4m0 12v4M2 12h4m12 0h4M5 5l3 3m8 8 3 3M5 19l3-3m8-8 3-3"/>',
'star':'<path d="m12 2 3 6 7 1-5 5 1 7-6-3-6 3 1-7-5-5 7-1Z"/>',
'cup':'<path d="M7 3h10v7a5 5 0 0 1-10 0ZM7 5H3v4q0 4 5 4m9-8h4v4q0 4-5 4M12 15v5m-5 1h10"/>',
'sound':'<path d="M3 9h4l5-5v16l-5-5H3ZM16 8q5 4 0 8m3-11q7 7 0 14"/>',
'mute':'<path d="M3 9h4l5-5v16l-5-5H3Zm13 0 5 6m-5 0 5-6"/>',
'fullscreen':'<path d="M9 3H3v6m12-6h6v6M3 15v6h6m12-6v6h-6"/>',
'retry':'<path d="M4 10a8 8 0 1 1 1 8M4 3v7h7"/>',
'lock':'<rect x="5" y="10" width="14" height="11" rx="2"/><path d="M8 10V6a4 4 0 0 1 8 0v4M12 14v3"/>',
'flag':'<path d="M5 22V3q4-3 8 0t7 0v10q-3 3-7 0t-8 0"/>',
'users':'<circle cx="9" cy="7" r="3"/><path d="M2 21v-3a7 7 0 0 1 14 0v3M16 4a3 3 0 0 1 0 6m3 4q3 1 3 7"/>',
'info':'<circle cx="12" cy="12" r="9"/><path d="M12 11v6m0-10v.2"/>',
'settings':'<path d="M3 6h18M3 12h18M3 18h18"/><path d="M8 3v6m8 0v6m-7 0v6" stroke-width="4"/>',
'garage':'<path d="m3 8 9-5 9 5v13H3ZM7 21V11h10v10M7 15h10M7 18h10"/>',
'heart':'<path d="M12 21 3 12C-2 4 8 0 12 7 16 0 26 4 21 12Z"/>',
'joystick':'<circle cx="12" cy="7" r="4"/><path d="M12 11v7M7 14H4l-2 7h20l-2-7h-3"/>'}
for name,body in paths.items():
 (ROOT/'icons'/f'{name}.svg').write_text(svg(f'<g stroke="#e5edf0" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">{body.replace(chr(35)+"263431",chr(35)+"e5edf0")}</g>'))
assets=[]
for tone,color in [('primary',C['orange']),('secondary',C['panel']),('mint',C['mint']),('danger',C['red'])]:
 for state in ['normal','hover','pressed','disabled','focus']:
  fill='#1c272d' if state=='disabled' else color
  y=7 if state=='pressed' else 3
  outline=C['muted'] if state=='disabled' else C['ink']
  body=f'<rect x="3" y="7" width="234" height="46" rx="13" fill="{outline}"/><rect x="3" y="{y}" width="234" height="44" rx="13" fill="{fill}" stroke="{outline}" stroke-width="2"/>'
  if state=='hover':body+='<path d="M19 10h201" stroke="#ffffff" stroke-width="3" opacity=".6"/>'
  if state=='focus':body+='<rect x=".75" y=".75" width="238.5" height="54.5" rx="16" stroke="#286fa0" stroke-width="1.5"/>'
  name=f'button-{tone}-{state}'
  (ROOT/'surfaces'/f'{name}.svg').write_text(svg(body,240,56))
  assets.append({'id':name,'size':[240,56],'nine_slice':[18,18,18,18],'min_size':[56,56],'text_baked_in':False})
for name,fill in [('panel-cream',C['panel']),('panel-dark',C['ink']),('panel-mint',C['mint']),('panel-selected',C['orange'])]:
 (ROOT/'surfaces'/f'{name}.svg').write_text(svg(f'<rect x="2" y="5" width="156" height="113" rx="18" fill="{C["ink"]}"/><rect x="2" y="2" width="156" height="112" rx="18" fill="{fill}" stroke="{C["ink"]}" stroke-width="2"/>',160,120))
 assets.append({'id':name,'size':[160,120],'nine_slice':[24,24,24,24],'min_size':[64,64]})
for name,fill in [('health-track',C['ink']),('health-fill',C['mint']),('health-low',C['red']),('reload-fill',C['orange'])]:
 (ROOT/'surfaces'/f'{name}.svg').write_text(svg(f'<rect x="1" y="1" width="158" height="14" rx="7" fill="{fill}"/>',160,16))
 assets.append({'id':name,'size':[160,16],'nine_slice':[8,7,8,7],'min_size':[16,16]})
for name,rad,fill in [('joystick-base',61,'#19262d'),('joystick-knob',29,'#a9cbbb'),('fire-button',52,'#f6a34a')]:
 (ROOT/'surfaces'/f'{name}.svg').write_text(svg(f'<circle cx="64" cy="64" r="{rad}" fill="{fill}" fill-opacity=".85" stroke="#263431" stroke-width="3"/>',128,128))
colors=['#68afd2','#8fc9ae','#df7460','#edc754','#b2a0ca','#e9e2c8','#e8a055','#899fa6']
names=['azure','mint','red','gold','violet','ivory','orange','slate']
for n,color in zip(names,colors):
 body=f'<g stroke="#263431" stroke-width="3" stroke-linejoin="round"><rect x="23" y="39" width="25" height="68" rx="9" fill="#46524c"/><rect x="88" y="39" width="25" height="68" rx="9" fill="#46524c"/><path d="M28 50h15m-15 13h15m-15 13h15m-15 13h15m50-39h15m-15 13h15m-15 13h15m-15 13h15" stroke="#7c8780"/><path d="m43 36 50 0 9 14v47H34V50Z" fill="{color}"/><path d="M35 86h67v11H35Z" fill="#263431" opacity=".15"/><path d="m52 47 32 0 9 13-8 22H51l-8-22Z" fill="{color}"/><path d="M62 15h12v43H62Z" fill="{color}"/><path d="M61 70l7 5 7-5" fill="none" stroke="#fffaf0" stroke-width="4"/></g>'
 (ROOT/'badges'/f'tank-{n}.svg').write_text(svg(body,136,120))
(ROOT/'brand-mark.svg').write_text(svg('<rect x="2" y="2" width="60" height="60" rx="18" fill="#f6a34a" stroke="#263431" stroke-width="3"/><g stroke="#263431" stroke-width="4" stroke-linejoin="round"><path d="M17 27h30v21H17Z" fill="#f6f1e5"/><path d="M13 25v25m38-25v25M25 25h14v14H25Z"/><path d="M32 12v15" stroke-width="7"/></g>',64,64))
(ROOT/'tokens.json').write_text(json.dumps({'colors':C,'spacing':[4,8,12,16,24,32,48,64],'radii':{'small':10,'medium':16,'large':24},'type_px':{'caption':12,'body':16,'button':16,'heading':32,'display':64},'touch_target_min_px':48,'breakpoints_px':{'phone_max':599,'tablet_max':1099,'desktop_min':1100},'content_max_px':1440,'safe_area':'Respect all four device safe-area insets; compact landscape uses the phone HUD.'},indent=2)+'\n')
(ROOT/'manifest.json').write_text(json.dumps({'name':'Pocket Armor UI Kit','version':1,'status':'review-only','vector_count':len(list(ROOT.rglob('*.svg'))),'icons':list(paths),'tank_badges':names,'surfaces':assets,'notes':['SVG icons use literal charcoal strokes for Godot compatibility; web can mask them for tint.','Buttons and panels must use nine-slicing or equivalent code styling, never nonuniform image stretching.','All text is live and separate from vector assets.','Tank badges are new UI symbols based on existing colors, not replacements for the 3D tanks.']},indent=2)+'\n')
print('Generated',len(list(ROOT.rglob('*.svg'))),'vector assets')
