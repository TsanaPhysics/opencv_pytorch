// เก็บไฟล์ทั้งหมดไว้ในเครื่อง เพื่อใช้งานกลางสวนได้แม้ไม่มีอินเทอร์เน็ต
const CACHE='mbt-v2026-10-16';
const FILES=['./','./index.html','./manifest.json','./fonts/Mitr-Medium.ttf','./fonts/Mitr-SemiBold.ttf','./fonts/IBMPlexSansThai-Regular.ttf','./fonts/IBMPlexSansThai-Medium.ttf','./fonts/IBMPlexSansThai-SemiBold.ttf','./app_model.onnx','./ort-wasm-simd-threaded.wasm','./sample1.jpg','./sample2.jpg','./sample3.jpg','./sample4.jpg','./icon-192.png','./icon-512.png'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(CACHE).then(c=>c.addAll(FILES)).then(()=>self.skipWaiting()));});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));});
self.addEventListener('fetch',e=>{if(e.request.method!=='GET')return;e.respondWith(caches.match(e.request,{ignoreSearch:true}).then(r=>r||fetch(e.request).then(res=>{if(res.ok&&new URL(e.request.url).origin===location.origin){const cp=res.clone();caches.open(CACHE).then(c=>c.put(e.request,cp));}return res;})));});
