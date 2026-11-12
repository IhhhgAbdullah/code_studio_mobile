import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String _threeHtml = r'''
<!DOCTYPE html>
<html dir="ltr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
<style>
  * { box-sizing: border-box; }
  body { margin: 0; padding: 10px; background: #0D2B52; color: #fff; font-family: sans-serif; }
  .card { background: #132F5A; border: 1px solid #D4AF37; border-radius: 14px; padding: 10px; margin-bottom: 10px; }
  .title { color: #D4AF37; font-weight: bold; font-size: 14px; margin-bottom: 8px; direction: rtl; text-align: right; }
  .row { display: flex; gap: 8px; margin-top: 8px; }
  .row > * { flex: 1; }
  .stage { width: 100%; height: 300px; border-radius: 10px; overflow: hidden; background: #0A1F3D; touch-action: none; }
  .stage canvas { display: block; width: 100% !important; height: 100% !important; }
  button { padding: 10px; font-size: 14px; border: none; border-radius: 10px;
    background: #D4AF37; color: #0D2B52; font-weight: bold; }
  button.alt { background: #2A4A7A; color: #fff; }
  button.danger { background: #8B2A2A; color: #fff; }
  button.sel { outline: 2px solid #fff; }
  button:disabled { opacity: 0.4; }
  input[type=text], select { width: 100%; padding: 10px; border-radius: 10px; border: 1px solid #D4AF37;
    background: #0A1F3D; color: #fff; font-size: 14px; margin-top: 8px; }
  textarea { width: 100%; height: 170px; background: #0A1F3D; color: #e6edf7; border: none;
    border-radius: 10px; padding: 10px; font-family: monospace; font-size: 13px; direction: ltr; }
  .prop { display: flex; align-items: center; gap: 8px; margin-top: 8px; font-size: 13px; }
  .prop label { min-width: 52px; }
  .prop input[type=range] { flex: 1; }
  .prop input[type=color] { width: 46px; height: 30px; border: none; background: none; }
  .prop span { min-width: 40px; text-align: left; direction: ltr; }
  .hint { font-size: 12px; color: #cfd8e6; margin-top: 8px; direction: rtl; text-align: right; }
  .msg { color: #D4AF37; font-size: 13px; margin-top: 6px; min-height: 16px; direction: rtl; text-align: right; }
  .err { color: #ff6b6b; }
  .hud { display: flex; justify-content: space-between; font-size: 14px; margin-top: 6px; direction: ltr; }
  .modes { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; }
</style>
</head>
<body>
<div class="card">
  <div class="modes">
    <button class="gold mode" data-mode="scene" id="mScene">مشهد 3D</button>
    <button class="mode" data-mode="physics" id="mPhys">لعبة الفيزياء</button>
  </div>
</div>

<div id="sceneMode">
<div class="card">
  <div class="title">مشهد 3D: اختر شكلاً ثم انقر على الأرضية لإضافته</div>
  <div class="row">
    <button class="alt kind" data-kind="box">مكعب</button>
    <button class="alt kind" data-kind="sphere">كرة</button>
    <button class="alt kind" data-kind="cylinder">أسطوانة</button>
    <button class="alt kind" data-kind="floor">أرضية</button>
  </div>
  <div class="stage" id="stage" style="margin-top:8px"></div>
  <div id="props" style="display:none">
    <div class="prop">
      <label>اللون</label>
      <input type="color" id="pcolor">
    </div>
    <div class="prop">
      <label>الحجم</label>
      <input type="range" id="psize" min="50" max="150" step="5" value="100">
      <span id="psizeOut">100%</span>
    </div>
  </div>
  <div class="row">
    <button id="delsel" class="danger" disabled>حذف المحدد</button>
    <button id="clear" class="danger">حذف الكل</button>
  </div>
  <div class="hint">انقر على شكل لتحديده. اسحبه لتحريكه، واسحب الفراغ لتدوير الكاميرا.</div>
  <div class="msg" id="msg"></div>
</div>
<div class="card">
  <div class="title">حفظ المشهد</div>
  <input type="text" id="sname" placeholder="اسم المشهد (مثال: مشهد1)">
  <div class="row">
    <button id="save" class="alt">حفظ المشهد</button>
    <button id="load" class="alt">فتح المحدد</button>
  </div>
  <select id="scenes"></select>
  <div class="row">
    <button id="delscene" class="danger">حذف المشهد المحفوظ</button>
  </div>
</div>
<div class="card">
  <div class="title">كود 3D (يعمل على المشهد): دوال setup و update</div>
  <textarea id="code"></textarea>
  <div class="row">
    <button id="run">تشغيل الكود</button>
    <button id="stopcode" class="danger">إيقاف الكود</button>
  </div>
</div>
</div>

<div id="physicsMode" style="display:none">
<div class="card">
  <div class="title">لعبة الفيزياء: اجمع الأعداء بالتدحرج، وتجنب الاصطدام المباشر</div>
  <div class="hud">
    <span id="hScore">النقاط: 0</span>
    <span id="hLives">الحياة: 3</span>
    <span id="hTime">الوقت: 60</span>
  </div>
  <div class="stage" id="pstage" style="margin-top:8px"></div>
  <div class="hint">اسحب الكرة الذهبية لتتحرك، أو استخدم الأسهم على لوحة المفاتيح.</div>
  <div class="row">
    <button id="restart">إعادة</button>
    <button id="pause" class="alt">إيقاف مؤقت</button>
  </div>
  <div class="msg" id="pmsg"></div>
</div>
</div>

<div class="card"><div class="msg err" id="err"></div></div>

<script>
  const errEl = document.getElementById('err');
  const msgEl = document.getElementById('msg');
  const pmsgEl = document.getElementById('pmsg');
  const SKEY = 'cs_3d_scenes';
  let kind = 'box';

  function loadLib(srcs) {
    return new Promise((resolve, reject) => {
      let i = 0;
      const tryNext = () => {
        if (i >= srcs.length) { reject(new Error('تعذّر تحميل المكتبة')); return; }
        const s = document.createElement('script');
        s.src = srcs[i++];
        s.onload = () => resolve(s.src);
        s.onerror = tryNext;
        document.head.appendChild(s);
      };
      tryNext();
    });
  }
  const THREE_SRCS = [
    'file:///android_asset/flutter_assets/assets/three/three.min.js',
    'https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js'
  ];
  const CANNON_SRCS = [
    'file:///android_asset/flutter_assets/assets/cannon/cannon.min.js',
    'https://cdnjs.cloudflare.com/ajax/libs/cannon.js/0.6.2/cannon.min.js'
  ];

  function getScenes() {
    try { return JSON.parse(localStorage.getItem(SKEY) || '{}'); }
    catch (e) { return {}; }
  }
  function setScenes(obj) { localStorage.setItem(SKEY, JSON.stringify(obj)); }
  function refreshScenes(selected) {
    const sel = document.getElementById('scenes');
    const scenes = getScenes();
    sel.innerHTML = '';
    Object.keys(scenes).sort().forEach(n => {
      const o = document.createElement('option');
      o.value = n; o.textContent = n;
      sel.appendChild(o);
    });
    if (selected) sel.value = selected;
  }

  // ===== وضع المشهد =====
  function startScene() {
    const stage = document.getElementById('stage');
    const W = () => stage.clientWidth;
    const H = () => stage.clientHeight;

    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0x0a1f3d);

    const camera = new THREE.PerspectiveCamera(50, W() / H(), 0.1, 200);
    let camTheta = 0.6, camPhi = 1.0, camRadius = 14;
    const target = new THREE.Vector3(0, 0, 0);
    function updateCamera() {
      camPhi = Math.max(0.2, Math.min(1.45, camPhi));
      camera.position.set(
        target.x + camRadius * Math.sin(camPhi) * Math.sin(camTheta),
        target.y + camRadius * Math.cos(camPhi),
        target.z + camRadius * Math.sin(camPhi) * Math.cos(camTheta)
      );
      camera.lookAt(target);
    }
    updateCamera();

    const renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.setSize(W(), H());
    stage.appendChild(renderer.domElement);

    scene.add(new THREE.AmbientLight(0xffffff, 0.5));
    const sun = new THREE.DirectionalLight(0xffffff, 0.9);
    sun.position.set(6, 10, 8);
    scene.add(sun);

    const base = new THREE.Mesh(new THREE.CircleGeometry(12, 64), new THREE.MeshStandardMaterial({ color: 0x1a3d6e }));
    base.rotation.x = -Math.PI / 2;
    scene.add(base);

    const shapes = [];
    const COLORS = [0xd4af37, 0x7cfc7c, 0xff6b6b, 0x82aaff, 0xffffff];
    let colorIdx = 0;
    let selected = null;
    const BASE_Y = { box: 0.7, sphere: 0.7, cylinder: 0.8, floor: 0.075 };

    function makeMesh(k, colorHex) {
      const color = colorHex !== undefined ? colorHex : COLORS[colorIdx++ % COLORS.length];
      const mat = new THREE.MeshStandardMaterial({ color: color, metalness: 0.2, roughness: 0.5 });
      let geo;
      if (k === 'sphere') geo = new THREE.SphereGeometry(0.7, 32, 24);
      else if (k === 'cylinder') geo = new THREE.CylinderGeometry(0.6, 0.6, 1.6, 32);
      else if (k === 'floor') geo = new THREE.BoxGeometry(2.4, 0.15, 2.4);
      else geo = new THREE.BoxGeometry(1.4, 1.4, 1.4);
      const m = new THREE.Mesh(geo, mat);
      m.userData.kind = k;
      m.userData.baseY = BASE_Y[k] || 0.7;
      return m;
    }

    const raycaster = new THREE.Raycaster();
    const ndc = new THREE.Vector2();
    const groundPlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
    const hitPoint = new THREE.Vector3();
    function setNdc(clientX, clientY) {
      const rect = renderer.domElement.getBoundingClientRect();
      ndc.x = ((clientX - rect.left) / rect.width) * 2 - 1;
      ndc.y = -((clientY - rect.top) / rect.height) * 2 + 1;
      raycaster.setFromCamera(ndc, camera);
    }
    function pickShape(x, y) { setNdc(x, y); const h = raycaster.intersectObjects(shapes, false); return h.length ? h[0].object : null; }
    function groundAt(x, y) { setNdc(x, y); return raycaster.ray.intersectPlane(groundPlane, hitPoint) ? hitPoint.clone() : null; }

    const propsEl = document.getElementById('props');
    const pcolor = document.getElementById('pcolor');
    const psize = document.getElementById('psize');
    const psizeOut = document.getElementById('psizeOut');
    const delsel = document.getElementById('delsel');

    function select(mesh) {
      selected = mesh;
      if (!mesh) { propsEl.style.display = 'none'; delsel.disabled = true; return; }
      propsEl.style.display = 'block';
      delsel.disabled = false;
      pcolor.value = '#' + mesh.material.color.getHexString();
      const pct = Math.round(mesh.scale.x * 100);
      psize.value = Math.max(50, Math.min(150, pct));
      psizeOut.textContent = psize.value + '%';
    }
    pcolor.addEventListener('input', () => { if (selected) selected.material.color.set(pcolor.value); });
    psize.addEventListener('input', () => {
      if (!selected) return;
      const s = Number(psize.value) / 100;
      selected.scale.set(s, s, s);
      selected.position.y = selected.userData.baseY * s;
      psizeOut.textContent = psize.value + '%';
    });

    function removeMesh(m) {
      scene.remove(m);
      m.geometry.dispose(); m.material.dispose();
      const i = shapes.indexOf(m);
      if (i >= 0) shapes.splice(i, 1);
    }
    delsel.onclick = () => { if (selected) { removeMesh(selected); select(null); } };
    document.getElementById('clear').onclick = () => { shapes.slice().forEach(removeMesh); select(null); };

    function snapshot() {
      return shapes.map(m => ({ kind: m.userData.kind, x: m.position.x, z: m.position.z,
        scale: m.scale.x, color: m.material.color.getHex() }));
    }
    function build(items) {
      shapes.slice().forEach(removeMesh);
      select(null);
      items.forEach(it => {
        const m = makeMesh(it.kind, it.color);
        m.scale.set(it.scale, it.scale, it.scale);
        m.position.set(it.x, m.userData.baseY * it.scale, it.z);
        scene.add(m);
        shapes.push(m);
      });
    }

    document.getElementById('save').onclick = () => {
      const name = document.getElementById('sname').value.trim();
      if (!name) { msgEl.textContent = 'اكتب اسم المشهد أولاً'; return; }
      const scenes = getScenes();
      scenes[name] = snapshot();
      try { setScenes(scenes); refreshScenes(name); msgEl.textContent = 'تم حفظ المشهد: ' + name; }
      catch (e) { msgEl.textContent = 'تعذّر الحفظ: ' + e; }
    };
    document.getElementById('load').onclick = () => {
      const name = document.getElementById('scenes').value;
      const scenes = getScenes();
      if (!name || !(name in scenes)) { msgEl.textContent = 'لا يوجد مشهد محدد لفتحه'; return; }
      build(scenes[name]);
      document.getElementById('sname').value = name;
      msgEl.textContent = 'تم فتح المشهد: ' + name;
    };
    document.getElementById('delscene').onclick = () => {
      const name = document.getElementById('scenes').value;
      const scenes = getScenes();
      if (!name || !(name in scenes)) { msgEl.textContent = 'لا يوجد مشهد محدد للحذف'; return; }
      delete scenes[name]; setScenes(scenes); refreshScenes();
      msgEl.textContent = 'تم حذف المشهد: ' + name;
    };

    // ===== محرك كود 3D =====
    let codeRaf = null;
    let codeObjects = [];
    function addBox(x, y, z, color) { const m = makeMesh('box', color); m.position.set(x, y, z); scene.add(m); shapes.push(m); codeObjects.push(m); return m; }
    function addSphere(x, y, z, color) { const m = makeMesh('sphere', color); m.position.set(x, y, z); scene.add(m); shapes.push(m); codeObjects.push(m); return m; }
    function addCylinder(x, y, z, color) { const m = makeMesh('cylinder', color); m.position.set(x, y, z); scene.add(m); shapes.push(m); codeObjects.push(m); return m; }
    function clearCodeObjects() { codeObjects.slice().forEach(removeMesh); codeObjects = []; }
    function stopCode() { if (codeRaf) cancelAnimationFrame(codeRaf); codeRaf = null; }
    function runCode() {
      stopCode();
      clearCodeObjects();
      errEl.textContent = '';
      const src = document.getElementById('code').value;
      let api;
      try {
        api = new Function('scene', 'THREE', 'addBox', 'addSphere', 'addCylinder', 'clear',
          src + '\n;return { setup: typeof setup === "function" ? setup : null, update: typeof update === "function" ? update : null };'
        )(scene, THREE, addBox, addSphere, addCylinder, clearCodeObjects);
        if (api.setup) api.setup();
      } catch (e) { errEl.textContent = 'خطأ في الكود: ' + e; return; }
      let last = performance.now();
      function frame(now) {
        const dt = Math.min(0.05, (now - last) / 1000);
        last = now;
        try { if (api.update) api.update(dt); }
        catch (e) { errEl.textContent = 'خطأ أثناء التشغيل: ' + e; codeRaf = null; return; }
        codeRaf = requestAnimationFrame(frame);
      }
      codeRaf = requestAnimationFrame(frame);
      msgEl.textContent = 'الكود يعمل';
    }
    document.getElementById('run').onclick = runCode;
    document.getElementById('stopcode').onclick = () => { stopCode(); msgEl.textContent = 'تم إيقاف الكود'; };
    document.getElementById('code').value = `let spin = 0;
let crate;

function setup() {
  addBox(0, 0.7, 0, 0xd4af37);
  addSphere(2, 0.7, 1, 0x7cfc7c);
  addCylinder(-2, 0.8, -1, 0x82aaff);
  crate = scene.children[scene.children.length - 3];
}

function update(dt) {
  spin += dt;
  if (crate) crate.rotation.y += dt * 1.2;
}`;

    // ===== الاختيار والسحب =====
    let drag = null;
    renderer.domElement.addEventListener('pointerdown', e => {
      const hit = pickShape(e.clientX, e.clientY);
      drag = { x: e.clientX, y: e.clientY, sx: e.clientX, sy: e.clientY, moved: false, mode: hit ? 'shape' : 'camera', mesh: hit };
      if (hit) select(hit);
    });
    renderer.domElement.addEventListener('pointermove', e => {
      if (!drag) return;
      const moveDist = Math.abs(e.clientX - drag.sx) + Math.abs(e.clientY - drag.sy);
      if (moveDist > 8) drag.moved = true;
      if (drag.mode === 'camera') {
        if (drag.moved) { camTheta -= (e.clientX - drag.x) * 0.008; camPhi -= (e.clientY - drag.y) * 0.006; updateCamera(); }
      } else if (drag.mode === 'shape' && drag.moved) {
        const g = groundAt(e.clientX, e.clientY);
        if (g) {
          const s = drag.mesh.scale.x;
          drag.mesh.position.x = Math.round(g.x * 2) / 2;
          drag.mesh.position.z = Math.round(g.z * 2) / 2;
          drag.mesh.position.y = drag.mesh.userData.baseY * s;
        }
      }
      drag.x = e.clientX; drag.y = e.clientY;
    });
    renderer.domElement.addEventListener('pointerup', e => {
      if (drag && drag.mode === 'camera' && !drag.moved) {
        const g = groundAt(e.clientX, e.clientY);
        if (g) {
          const m = makeMesh(kind);
          m.position.set(Math.round(g.x * 2) / 2, m.userData.baseY, Math.round(g.z * 2) / 2);
          scene.add(m); shapes.push(m); select(m);
        }
      }
      drag = null;
    });
    renderer.domElement.addEventListener('pointercancel', () => { drag = null; });

    document.querySelectorAll('.kind').forEach(b => {
      b.addEventListener('click', () => {
        kind = b.dataset.kind;
        document.querySelectorAll('.kind').forEach(x => x.classList.toggle('sel', x === b));
      });
    });
    document.querySelector('.kind[data-kind="box"]').classList.add('sel');

    window.addEventListener('resize', () => {
      camera.aspect = W() / H();
      camera.updateProjectionMatrix();
      renderer.setSize(W(), H());
    });
    function tick() { renderer.render(scene, camera); requestAnimationFrame(tick); }
    tick();
    refreshScenes();
    msgEl.textContent = 'المحرك جاهز';
  }

  // ===== لعبة الفيزياء =====
  let phys = null;
  function startPhysics() {
    const stage = document.getElementById('pstage');
    const W = () => stage.clientWidth;
    const H = () => stage.clientHeight;

    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0x0a1f3d);
    const camera = new THREE.PerspectiveCamera(55, W() / H(), 0.1, 200);
    camera.position.set(0, 14, 12);
    camera.lookAt(0, 0, 0);
    const renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.setSize(W(), H());
    stage.appendChild(renderer.domElement);
    scene.add(new THREE.AmbientLight(0xffffff, 0.6));
    const sun = new THREE.DirectionalLight(0xffffff, 0.8);
    sun.position.set(5, 12, 6);
    scene.add(sun);

    const world = new CANNON.World();
    world.gravity.set(0, -20, 0);
    world.broadphase = new CANNON.NaiveBroadphase();
    const matDefault = new CANNON.Material('default');
    world.defaultContactMaterial.friction = 0.3;
    world.defaultContactMaterial.restitution = 0.4;

    const groundBody = new CANNON.Body({ mass: 0, shape: new CANNON.Plane() });
    groundBody.quaternion.setFromEuler(-Math.PI / 2, 0, 0);
    world.addBody(groundBody);
    const ground = new THREE.Mesh(new THREE.CircleGeometry(10, 48), new THREE.MeshStandardMaterial({ color: 0x1a3d6e }));
    ground.rotation.x = -Math.PI / 2;
    scene.add(ground);

    const wallSize = 10, wallH = 2;
    const wallDefs = [
      [0, wallH / 2, -wallSize, wallSize * 2, wallH, 0.5],
      [0, wallH / 2, wallSize, wallSize * 2, wallH, 0.5],
      [-wallSize, wallH / 2, 0, 0.5, wallH, wallSize * 2],
      [wallSize, wallH / 2, 0, 0.5, wallH, wallSize * 2]
    ];
    wallDefs.forEach(([x, y, z, w, h, d]) => {
      const b = new CANNON.Body({ mass: 0, shape: new CANNON.Box(new CANNON.Vec3(w / 2, h / 2, d / 2)) });
      b.position.set(x, y, z);
      world.addBody(b);
      const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), new THREE.MeshStandardMaterial({ color: 0x2a4a7a }));
      m.position.set(x, y, z);
      scene.add(m);
    });

    const playerR = 0.6;
    const playerBody = new CANNON.Body({ mass: 2, shape: new CANNON.Sphere(playerR), material: matDefault });
    playerBody.position.set(0, 2, 6);
    playerBody.linearDamping = 0.3;
    world.addBody(playerBody);
    const playerMesh = new THREE.Mesh(new THREE.SphereGeometry(playerR, 24, 18), new THREE.MeshStandardMaterial({ color: 0xd4af37, metalness: 0.3, roughness: 0.4 }));
    scene.add(playerMesh);

    // إعدادات التوازن
    const SPAWN_EVERY = 3;      // ثوانٍ بين كل عدو
    const MAX_ENEMIES = 6;      // أقصى عدد أعداء في الساحة
    const HIT_SPEED = 4;        // أقل سرعة نسبية تُحسب اصطداماً مؤذياً
    const INVUL_TIME = 1.5;     // مهلة بعد كل خصم حياة

    let enemies = [];
    let score = 0, lives = 3, timeLeft = 60, over = false, paused = false, spawnT = 0, invul = 0;
    const hScore = document.getElementById('hScore');
    const hLives = document.getElementById('hLives');
    const hTime = document.getElementById('hTime');

    function spawnEnemy() {
      const r = 0.5;
      const body = new CANNON.Body({ mass: 1, shape: new CANNON.Sphere(r), material: matDefault });
      body.position.set((Math.random() - 0.5) * 12, 6, (Math.random() - 0.5) * 12);
      body.linearDamping = 0.1;
      world.addBody(body);
      const mesh = new THREE.Mesh(new THREE.SphereGeometry(r, 20, 14), new THREE.MeshStandardMaterial({ color: 0xff6b6b }));
      scene.add(mesh);
      enemies.push({ body, mesh, r });
    }

    function removeEnemy(e) {
      world.removeBody(e.body);
      scene.remove(e.mesh);
      e.mesh.geometry.dispose(); e.mesh.material.dispose();
    }

    function reset() {
      enemies.forEach(removeEnemy);
      enemies = [];
      playerBody.position.set(0, 2, 6);
      playerBody.velocity.set(0, 0, 0);
      playerBody.angularVelocity.set(0, 0, 0);
      score = 0; lives = 3; timeLeft = 60; over = false; paused = false; spawnT = 0; invul = 0;
      pmsgEl.textContent = '';
      updateHud();
    }

    function updateHud() {
      hScore.textContent = 'النقاط: ' + score;
      hLives.textContent = 'الحياة: ' + lives;
      hTime.textContent = 'الوقت: ' + Math.max(0, Math.ceil(timeLeft));
    }

    const keys = {};
    window.addEventListener('keydown', e => { keys[e.key] = true; if (e.key.startsWith('Arrow')) e.preventDefault(); });
    window.addEventListener('keyup', e => { keys[e.key] = false; });
    let pdrag = null;
    renderer.domElement.addEventListener('pointerdown', e => { pdrag = { x: e.clientX, y: e.clientY }; });
    renderer.domElement.addEventListener('pointermove', e => {
      if (!pdrag) return;
      const dx = (e.clientX - pdrag.x) * 0.02;
      const dz = (e.clientY - pdrag.y) * 0.02;
      playerBody.applyForce(new CANNON.Vec3(dx * 40, 0, dz * 40), playerBody.position);
      pdrag = { x: e.clientX, y: e.clientY };
    });
    renderer.domElement.addEventListener('pointerup', () => { pdrag = null; });
    renderer.domElement.addEventListener('pointercancel', () => { pdrag = null; });

    document.getElementById('restart').onclick = () => reset();
    document.getElementById('pause').onclick = (e) => {
      paused = !paused;
      e.target.textContent = paused ? 'متابعة' : 'إيقاف مؤقت';
    };

    let last = performance.now();
    function tick(now) {
      const dt = Math.min(0.05, (now - last) / 1000);
      last = now;
      if (!over && !paused) {
        const f = 25;
        if (keys.ArrowLeft) playerBody.applyForce(new CANNON.Vec3(-f, 0, 0), playerBody.position);
        if (keys.ArrowRight) playerBody.applyForce(new CANNON.Vec3(f, 0, 0), playerBody.position);
        if (keys.ArrowUp) playerBody.applyForce(new CANNON.Vec3(0, 0, -f), playerBody.position);
        if (keys.ArrowDown) playerBody.applyForce(new CANNON.Vec3(0, 0, f), playerBody.position);

        world.step(1 / 60, dt, 3);
        timeLeft -= dt;
        spawnT += dt;
        if (invul > 0) invul -= dt;
        if (spawnT > SPAWN_EVERY && enemies.length < MAX_ENEMIES) { spawnT = 0; spawnEnemy(); }

        enemies = enemies.filter(e => {
          const p = e.body.position;
          if (p.y < -2 || Math.abs(p.x) > 12 || Math.abs(p.z) > 12) {
            score += 10;
            removeEnemy(e);
            return false;
          }
          // الخصم يحدث فقط عند اصطدام قوي بعد انتهاء المهلة
          const dx = e.body.position.x - playerBody.position.x;
          const dy = e.body.position.y - playerBody.position.y;
          const dz = e.body.position.z - playerBody.position.z;
          const dist = Math.hypot(dx, dy, dz);
          const rv = e.body.velocity.vsub(playerBody.velocity);
          const relSpeed = Math.hypot(rv.x, rv.y, rv.z);
          if (dist < e.r + playerR + 0.1 && relSpeed > HIT_SPEED && invul <= 0) {
            lives--;
            invul = INVUL_TIME;
            removeEnemy(e);
            return false;
          }
          return true;
        });

        if (lives <= 0) { over = true; pmsgEl.textContent = 'انتهت اللعبة. نتيجتك: ' + score; }
        else if (timeLeft <= 0) { over = true; pmsgEl.textContent = 'انتهى الوقت. نتيجتك: ' + score; }
        updateHud();
      }

      playerMesh.position.copy(playerBody.position);
      playerMesh.quaternion.copy(playerBody.quaternion);
      enemies.forEach(e => {
        e.mesh.position.copy(e.body.position);
        e.mesh.quaternion.copy(e.body.quaternion);
      });

      renderer.render(scene, camera);
      requestAnimationFrame(tick);
    }
    phys = { reset };
    reset();
    requestAnimationFrame(tick);
    pmsgEl.textContent = 'اجمع الأعداء بالتدحرج. الأعداء التي تسقط خارج الساحة تعطيك نقاطاً.';
  }

  // ===== التبديل بين الوضعين =====
  document.querySelectorAll('.mode').forEach(b => {
    b.addEventListener('click', () => {
      const m = b.dataset.mode;
      document.querySelectorAll('.mode').forEach(x => x.classList.toggle('gold', x === b));
      document.getElementById('sceneMode').style.display = m === 'scene' ? 'block' : 'none';
      document.getElementById('physicsMode').style.display = m === 'physics' ? 'block' : 'none';
      if (m === 'physics' && !phys) {
        if (typeof CANNON === 'undefined') {
          pmsgEl.textContent = 'جاري تحميل محرك الفيزياء...';
          loadLib(CANNON_SRCS).then(() => startPhysics()).catch(() => { pmsgEl.textContent = 'تعذّر تحميل Cannon.js'; });
        } else {
          startPhysics();
        }
      }
    });
  });

  loadLib(THREE_SRCS)
    .then(() => startScene())
    .catch(() => { errEl.textContent = 'تعذّر تحميل Three.js من ملفات التطبيق أو الإنترنت.'; });
</script>
</body>
</html>
''';

class ThreePage extends StatefulWidget {
  const ThreePage({super.key});

  @override
  State<ThreePage> createState() => _ThreePageState();
}

class _ThreePageState extends State<ThreePage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(_threeHtml, baseUrl: 'https://localhost/');
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
