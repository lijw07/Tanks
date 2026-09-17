from pathlib import Path
import json, base64
from PIL import Image, ImageDraw, ImageFont

OUT=Path(__file__).resolve().parent
maps=json.loads((OUT/'manifest.json').read_text())['maps']
sheet=Image.new('RGB',(1800,1110),'#142126')
d=ImageDraw.Draw(sheet)
font='/System/Library/Fonts/Helvetica.ttc'
title=ImageFont.truetype(font,38)
label=ImageFont.truetype(font,22)
small=ImageFont.truetype(font,15)
d.text((32,23),'POCKET ARMOR / MAP STUDIES',font=title,fill='#eee4cc')
d.text((34,72),'Six editable Blender scenes  ·  Charcoal outlines + clearer lighting',font=small,fill='#acb8b8')
for i,m in enumerate(maps):
    x=20+(i%3)*595; y=115+(i//3)*490
    image=Image.open(OUT/'previews'/f"{m['slug']}.png").convert('RGB')
    image.thumbnail((575,449),Image.Resampling.LANCZOS)
    sheet.paste(image,(x,y))
    d.text((x+12,y+446),f"{m['number']:02d}  {m['name']}",font=label,fill='#eee4cc')
sheet.save(OUT/'previews/00_all_maps.jpg',quality=94)
for m in maps:
    for field,suffix in [('angled',''),('overhead','_overhead')]:
        m[field]='data:image/png;base64,'+base64.b64encode((OUT/'previews'/f"{m['slug']}{suffix}.png").read_bytes()).decode()
html='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Pocket Armor · Map Studies</title>
<style>*{box-sizing:border-box}body{margin:0;background:#142126;color:#f2e9d5;font:16px system-ui,sans-serif}header{max-width:1500px;margin:auto;padding:44px 28px 25px}.eyebrow{color:#b1bfb9;letter-spacing:.22em;font-size:12px}h1{font-size:clamp(32px,4vw,56px);font-weight:550;margin:14px 0}header p{color:#b1bfb9;max-width:760px;line-height:1.6}.toolbar{display:flex;gap:10px;align-items:center;margin:24px 0 0;flex-wrap:wrap}button{font:inherit;cursor:pointer;border:1px solid #4e6367;color:inherit;background:#22363c;border-radius:7px;padding:10px 18px}button[aria-pressed=true]{background:#e7d6b4;color:#15252a;border-color:#e7d6b4}button:focus-visible{outline:3px solid #64b7cf;outline-offset:3px}.toolbar span{color:#9aadaf;font-size:13px;margin-left:auto}main{max-width:1500px;margin:auto;padding:0 28px 50px;display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:22px}article{border:1px solid #34474c;border-radius:12px;overflow:hidden;background:#1b2c32}.image-button{padding:0;border:0;border-radius:0;background:none;width:100%;display:block}.image-button img{display:block;width:100%;aspect-ratio:1.28;object-fit:contain;background:#24353b}.copy{padding:20px}h2{font-size:20px;margin:0 0 9px}.number{color:#93bcbf;font-size:13px;margin-right:8px}.copy p{color:#b2c0bd;font-size:14px;line-height:1.6;margin:0}footer{max-width:1500px;padding:0 28px 35px;margin:auto;color:#93a8aa;font-size:13px}dialog{max-width:96vw;width:1400px;max-height:96vh;padding:18px;background:#142126;color:#eee4cc;border:1px solid #4e6367;border-radius:12px}dialog::backdrop{background:#000b}.dialog-bar{display:flex;align-items:center;gap:12px;margin-bottom:12px}.dialog-bar strong{flex:1}dialog img{display:block;max-width:100%;max-height:78vh;margin:auto}@media(max-width:1000px){main{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:650px){main{grid-template-columns:1fr}.toolbar span{width:100%;margin:5px 0}.dialog-bar{flex-wrap:wrap}}
</style><header><div class="eyebrow">POCKET ARMOR / ENVIRONMENT EXPLORATION</div><h1>Sharper edges. Clearer battles.</h1><p>Six toy-tank arenas with fine charcoal outlines and clearer lighting. Compare the scenery, then switch to overhead to study lanes, cover, and starting positions.</p><div class="toolbar"><button id="angled" aria-pressed="true">Angled view</button><button id="overhead" aria-pressed="false">Overhead layout</button><span>24 × 18 m boards · Click a map to enlarge</span></div></header><main id="maps"></main><footer>Static map concepts · Blue and coral mark starting areas · Gameplay and hazard behavior are not implemented</footer><dialog id="viewer"><div class="dialog-bar"><strong id="view-title"></strong><button id="prev" aria-label="Previous map">←</button><button id="next" aria-label="Next map">→</button><button id="close">Close</button></div><img id="large" alt=""></dialog><script>
const maps=MAP_DATA;let mode='angled',selected=0;const grid=document.querySelector('#maps'),dialog=document.querySelector('#viewer');
maps.forEach((m,i)=>{const a=document.createElement('article');a.innerHTML=`<button class="image-button" aria-label="Enlarge ${m.name}"><img alt="${m.name}: angled map concept" src="${m.angled}"></button><div class="copy"><h2><span class="number">0${m.number}</span>${m.name}</h2><p>${m.description}</p></div>`;a.querySelector('button').onclick=()=>{selected=i;refreshLarge();dialog.showModal()};grid.append(a)});
function refreshLarge(){const m=maps[selected];document.querySelector('#view-title').textContent=`0${m.number} / ${m.name} — ${mode==='angled'?'Angled view':'Overhead layout'}`;document.querySelector('#large').src=m[mode];document.querySelector('#large').alt=m.name+' '+mode+' view'}
for(const key of ['angled','overhead'])document.getElementById(key).onclick=()=>{mode=key;for(const k of ['angled','overhead'])document.getElementById(k).setAttribute('aria-pressed',k===key);grid.querySelectorAll('img').forEach((im,i)=>{im.src=maps[i][key];im.alt=maps[i].name+': '+key+' map concept'});refreshLarge()};
document.querySelector('#close').onclick=()=>dialog.close();document.querySelector('#prev').onclick=()=>{selected=(selected+5)%6;refreshLarge()};document.querySelector('#next').onclick=()=>{selected=(selected+1)%6;refreshLarge()};document.addEventListener('keydown',e=>{if(dialog.open&&e.key==='ArrowRight')document.querySelector('#next').click();if(dialog.open&&e.key==='ArrowLeft')document.querySelector('#prev').click()});
</script></html>'''
(OUT/'index.html').write_text(html.replace('MAP_DATA',json.dumps(maps)))
compare=Image.new('RGB',(2000,850),'#142126')
draw=ImageDraw.Draw(compare)
for x,folder,text in [(0,'map-concepts-v1','BEFORE'),(1000,'map-concepts-v2-outline','AFTER / CHARCOAL OUTLINES')]:
    preview=Image.open(OUT.parent/folder/'previews/01_crossfire_court.png').convert('RGB')
    preview.thumbnail((1000,782),Image.Resampling.LANCZOS)
    compare.paste(preview,(x,58))
    draw.text((x+25,18),text,font=label,fill='#eee4cc')
compare.save(OUT/'previews/00_before_after.jpg',quality=95)
print('Gallery, comparison sheet, and before-after created')
