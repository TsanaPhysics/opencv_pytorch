import os, shutil, json
src=open('src/app.html',encoding='utf-8').read()
ort=open('src/ort_inline.js',encoding='utf-8').read()
page=src.replace('/*ORT_BUNDLE*/',ort)
open('build/index.html','w',encoding='utf-8').write(page.replace('const MODEL_URL = "app_model.onnx";','const MODEL_URL = "app_model.b64.txt";'))
import base64; open('build/app_model.b64.txt','w').write(base64.b64encode(open('build/app_model.onnx','rb').read()).decode())          # สำหรับเผยแพร่เป็น Artifact
# ---------- รุ่นติดตั้งเอง (XAMPP / เว็บไซต์ HTTPS) เป็นเอกสาร HTML สมบูรณ์ + PWA ----------
d='selfhost'; shutil.rmtree(d,ignore_errors=True); os.makedirs(d)
head='<!doctype html>\n<html lang="th">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">\n<link rel="manifest" href="manifest.json">\n<link rel="icon" href="icon-192.png">\n<link rel="apple-touch-icon" href="icon-192.png">\n<style>*,*::before,*::after{box-sizing:border-box}:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}body{margin:0}img{max-width:100%}[hidden]{display:none!important}</style>\n'
title_end=page.index('<style>')
import re
FONT_CSS='<style>'+''.join(f"@font-face{{font-family:'{fam}';src:url('fonts/{fn}') format('truetype');font-weight:{w};font-display:swap}}" for fam,fn,w in [('Mitr','Mitr-Medium.ttf',500),('Mitr','Mitr-SemiBold.ttf',600),('IBM Plex Sans Thai','IBMPlexSansThai-Regular.ttf',400),('IBM Plex Sans Thai','IBMPlexSansThai-Medium.ttf',500),('IBM Plex Sans Thai','IBMPlexSansThai-SemiBold.ttf',600)])+'</style>\n'
local=re.sub(r'<link rel="preconnect"[^>]*>\n','',page)
local=re.sub(r'<link rel="stylesheet" href="https://fonts.googleapis.com[^>]*>\n',FONT_CSS,local)
assert 'fonts.googleapis' not in local
title_end=local.index('<style>:root') if '<style>:root' in local else local.index('<style>\n/* Layout')
full=head+local[:title_end]+'</head>\n<body>\n'+local[title_end:]+'\n</body>\n</html>\n'
# ย้าย <style> ของแอปให้อยู่ใน body ได้ (เบราว์เซอร์รองรับ) — คงไว้เพื่อให้โค้ดชุดเดียวกับ Artifact
open(f'{d}/index.html','w',encoding='utf-8').write(full)
for f in ['app_model.onnx','ort-wasm-simd-threaded.wasm','sample1.jpg','sample2.jpg','sample3.jpg','sample4.jpg']: shutil.copy(f'build/{f}',d)
os.makedirs(f'{d}/fonts',exist_ok=True)
for f in os.listdir('/home/claude/fonts'): shutil.copy('/home/claude/fonts/'+f,f'{d}/fonts/')
json.dump({"name":"หมอใบทุเรียน","short_name":"หมอใบทุเรียน","description":"ตรวจโรคใบทุเรียนด้วยปัญญาประดิษฐ์ ทำงานในเครื่อง","lang":"th","start_url":"./index.html","scope":"./","display":"standalone","background_color":"#eef2ec","theme_color":"#1f4d33",
  "icons":[{"src":"icon-192.png","sizes":"192x192","type":"image/png"},{"src":"icon-512.png","sizes":"512x512","type":"image/png","purpose":"any maskable"}]},open(f'{d}/manifest.json','w',encoding='utf-8'),ensure_ascii=False,indent=1)
open(f'{d}/sw.js','w').write("""// เก็บไฟล์ทั้งหมดไว้ในเครื่อง เพื่อใช้งานกลางสวนได้แม้ไม่มีอินเทอร์เน็ต
const CACHE='mbt-v2026-10-16';
const FILES=['./','./index.html','./manifest.json','./fonts/Mitr-Medium.ttf','./fonts/Mitr-SemiBold.ttf','./fonts/IBMPlexSansThai-Regular.ttf','./fonts/IBMPlexSansThai-Medium.ttf','./fonts/IBMPlexSansThai-SemiBold.ttf','./app_model.onnx','./ort-wasm-simd-threaded.wasm','./sample1.jpg','./sample2.jpg','./sample3.jpg','./sample4.jpg','./icon-192.png','./icon-512.png'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(CACHE).then(c=>c.addAll(FILES)).then(()=>self.skipWaiting()));});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));});
self.addEventListener('fetch',e=>{if(e.request.method!=='GET')return;e.respondWith(caches.match(e.request,{ignoreSearch:true}).then(r=>r||fetch(e.request).then(res=>{if(res.ok&&new URL(e.request.url).origin===location.origin){const cp=res.clone();caches.open(CACHE).then(c=>c.put(e.request,cp));}return res;})));});
""")
# ไอคอนแอป
from PIL import Image, ImageDraw
for s in (192,512):
    im=Image.new('RGB',(s,s),'#1f4d33'); dr=ImageDraw.Draw(im); k=s/34
    pts=[]
    import math
    # ใบไม้ทรงรีเอียง
    for i in range(60):
        t=i/59*math.pi*2; x=17+11*math.cos(t); y=17+5.2*math.sin(t)
        a=-math.pi/4; X=17+(x-17)*math.cos(a)-(y-17)*math.sin(a); Y=17+(x-17)*math.sin(a)+(y-17)*math.cos(a); pts.append((X*k,Y*k))
    dr.polygon(pts,fill='#d9a656'); dr.line([(9*k,25*k),(25*k,9*k)],fill='#1f4d33',width=max(2,int(k*1.6)))
    im.save(f'{d}/icon-{s}.png')
print('built', os.path.getsize('build/index.html')//1024,'KB')

# ---------- รุ่น APK (WebView): ไม่มี manifest/service worker ----------
a='apk_assets'; shutil.rmtree(a,ignore_errors=True); shutil.copytree(d,a)
for f in ['manifest.json','sw.js','icon-192.png','icon-512.png']: os.remove(f'{a}/{f}')
h=open(f'{a}/index.html',encoding='utf-8').read()
h=h.replace('<link rel="manifest" href="manifest.json">\n','').replace('<link rel="icon" href="icon-192.png">\n','').replace('<link rel="apple-touch-icon" href="icon-192.png">\n','')
assert 'manifest.json' not in h
open(f'{a}/index.html','w',encoding='utf-8').write(h)
print('apk assets ok')
