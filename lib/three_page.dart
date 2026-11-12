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
  #stage { width: 100%; height: 300px; border-radius: 10px; overflow: hidden; background: #0A1F3D; touch-action: none; }
  #stage canvas { display: block; width: 100% !important; height: 100% !important; }
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
</style>
</head>
<body>
<div class="card">
  <div class="title">مشهد 3D: اختر شكلاً ثم انقر على الأرضية لإضافته</div>
  <div class="row">
    <button class="alt kind" data-kind="box">مكعب</button>
    <button class="alt kind" data-kind="sphere">كرة</button>
    <button class="alt kind" data-kind="cylinder">أسطوانة</button>
    <button class="alt kind" data-kind="floor">أرضية</button>
  </div>
  <div id="stage" style="margin-top:8px"></div>
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
  <div id="msg" class="msg"></div>
  <div id="err" class="msg err"></div>
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
  <div class="hint">المتاح في الكود: addBox(x, y, z, color)، addSphere(...)، addCylinder(...)، scene، THREE، dt، clear()</div>
</div>
<script src="file:///android_asset/flutter_assets/assets/three/three.min.js"></script>
<script>
  const errEl = document.getElementById('err');
  const msgEl = document.getElementById('msg');
  const SKEY = 'cs_3d_scenes';
  let kind = 'box';

  const SAMPLE = `let spin = 0;
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

  function getScenes() {
    try { return JSON.parse(localStorage.getItem(SKEY) || '{}'); }
    catch (e) { return {}; }
  }
  function setScenes(obj) {
    localStorage.setItem(SKEY, JSON.stringify(obj));
  }
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

    const base = new THREE.Mesh(
      new THREE.CircleGeometry(12, 64),
      new THREE.MeshStandardMaterial({ color: 0x1a3d6e })
    );
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
    function pickShape(clientX, clientY) {
      setNdc(clientX, clientY);
      const hits = raycaster.intersectObjects(shapes, false);
      return hits.length ? hits[0].object : null;
    }
    function groundAt(clientX, clientY) {
      setNdc(clientX, clientY);
      return raycaster.ray.intersectPlane(groundPlane, hitPoint) ? hitPoint.clone() : null;
    }

    const propsEl = document.getElementById('props');
    const pcolor = document.getElementById('pcolor');
    const psize = document.getElementById('psize');
    const psizeOut = document.getElementById('psizeOut');
    const delsel = document.getElementById('delsel');

    function hexOf(color) { return '#' + color.getHexString(); }

    function select(mesh) {
      selected = mesh;
      if (!mesh) {
        propsEl.style.display = 'none';
        delsel.disabled = true;
        return;
      }
      propsEl.style.display = 'block';
      delsel.disabled = false;
      pcolor.value = hexOf(mesh.material.color);
      const pct = Math.round(mesh.scale.x * 100);
      psize.value = Math.max(50, Math.min(150, pct));
      psizeOut.textContent = psize.value + '%';
    }

    pcolor.addEventListener('input', () => {
      if (selected) selected.material.color.set(pcolor.value);
    });
    psize.addEventListener('input', () => {
      if (!selected) return;
      const s = Number(psize.value) / 100;
      selected.scale.set(s, s, s);
      selected.position.y = selected.userData.baseY * s;
      psizeOut.textContent = psize.value + '%';
    });

    function removeMesh(m) {
      scene.remove(m);
      m.geometry.dispose();
      m.material.dispose();
      const i = shapes.indexOf(m);
      if (i >= 0) shapes.splice(i, 1);
    }

    delsel.onclick = () => {
      if (!selected) return;
      removeMesh(selected);
      select(null);
    };
    document.getElementById('clear').onclick = () => {
      shapes.slice().forEach(removeMesh);
      select(null);
    };

    function snapshot() {
      return shapes.map(m => ({
        kind: m.userData.kind,
        x: m.position.x, z: m.position.z,
        scale: m.scale.x,
        color: m.material.color.getHex()
      }));
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
      try {
        setScenes(scenes);
        refreshScenes(name);
        msgEl.textContent = 'تم حفظ المشهد: ' + name + ' (' + shapes.length + ' شكل)';
      } catch (e) {
        msgEl.textContent = 'تعذّر الحفظ: ' + e;
      }
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
      delete scenes[name];
      setScenes(scenes);
      refreshScenes();
      msgEl.textContent = 'تم حذف المشهد: ' + name;
    };

    // ===== محرك الكود 3D =====
    let codeState = null;
    let codeRaf = null;
    let codeObjects = [];

    function addBox(x, y, z, color) {
      const m = makeMesh('box', color);
      m.position.set(x, y, z);
      scene.add(m);
      shapes.push(m);
      codeObjects.push(m);
      return m;
    }
    function addSphere(x, y, z, color) {
      const m = makeMesh('sphere', color);
      m.position.set(x, y, z);
      scene.add(m);
      shapes.push(m);
      codeObjects.push(m);
      return m;
    }
    function addCylinder(x, y, z, color) {
      const m = makeMesh('cylinder', color);
      m.position.set(x, y, z);
      scene.add(m);
      shapes.push(m);
      codeObjects.push(m);
      return m;
    }
    function clearCodeObjects() {
      codeObjects.slice().forEach(removeMesh);
      codeObjects = [];
    }

    function stopCode() {
      if (codeRaf) cancelAnimationFrame(codeRaf);
      codeRaf = null;
      codeState = null;
    }

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
      } catch (e) {
        errEl.textContent = 'خطأ في الكود: ' + e;
        return;
      }
      let last = performance.now();
      function frame(now) {
        const dt = Math.min(0.05, (now - last) / 1000);
        last = now;
        try {
          if (api.update) api.update(dt);
        } catch (e) {
          errEl.textContent = 'خطأ أثناء التشغيل: ' + e;
          codeRaf = null;
          return;
        }
        codeRaf = requestAnimationFrame(frame);
      }
      codeRaf = requestAnimationFrame(frame);
      msgEl.textContent = 'الكود يعمل';
    }

    document.getElementById('run').onclick = runCode;
    document.getElementById('stopcode').onclick = () => {
      stopCode();
      msgEl.textContent = 'تم إيقاف الكود';
    };
    document.getElementById('code').value = SAMPLE;

    // ===== الاختيار والسحب =====
    let drag = null;
    renderer.domElement.addEventListener('pointerdown', e => {
      const hit = pickShape(e.clientX, e.clientY);
      drag = {
        x: e.clientX, y: e.clientY, sx: e.clientX, sy: e.clientY,
        moved: false, mode: hit ? 'shape' : 'camera', mesh: hit
      };
      if (hit) select(hit);
    });
    renderer.domElement.addEventListener('pointermove', e => {
      if (!drag) return;
      const moveDist = Math.abs(e.clientX - drag.sx) + Math.abs(e.clientY - drag.sy);
      if (moveDist > 8) drag.moved = true;
      if (drag.mode === 'camera') {
        if (drag.moved) {
          camTheta -= (e.clientX - drag.x) * 0.008;
          camPhi -= (e.clientY - drag.y) * 0.006;
          updateCamera();
        }
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
          scene.add(m);
          shapes.push(m);
          select(m);
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

    function tick() {
      renderer.render(scene, camera);
      requestAnimationFrame(tick);
    }
    tick();
    refreshScenes();
    msgEl.textContent = 'المحرك جاهز (من ملفات التطبيق)';
  }

  if (typeof THREE === 'undefined') {
    errEl.textContent = 'تعذّر تحميل Three.js من ملفات التطبيق.';
  } else {
    startScene();
  }
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
