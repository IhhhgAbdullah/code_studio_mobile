import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String _horrorHtml = r'''
<!DOCTYPE html>
<html dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
<script src="file:///android_asset/flutter_assets/assets/three/three.min.js"></script>
<style>
  * { box-sizing: border-box; }
  body { margin: 0; padding: 8px; background: #0D2B52; color: #fff; font-family: sans-serif; }
  #stage { width: 100%; height: 400px; border-radius: 10px; overflow: hidden; background: #000; touch-action: none; }
  #stage canvas { display: block; width: 100% !important; height: 100% !important; }
  .hud { display: flex; justify-content: space-between; font-size: 14px; margin: 6px 0; direction: ltr; }
  .msg { color: #D4AF37; font-size: 14px; text-align: center; min-height: 20px; }
  button { width: 100%; padding: 12px; font-size: 15px; border: none; border-radius: 10px;
    background: #D4AF37; color: #0D2B52; font-weight: bold; margin-top: 6px; }
</style>
</head>
<body>
<div class="hud"><span id="hBat">البطارية: 100</span><span id="hState">الهروب من الظلام</span></div>
<div id="stage"></div>
<div class="msg" id="msg">اسحب الشاشة للتحرك وتدوير الكاميرا. اهرب إلى المخرج الأخضر.</div>
<button id="restart">إعادة اللعب</button>
<script>
  const stage = document.getElementById('stage');
  const msgEl = document.getElementById('msg');
  const hBat = document.getElementById('hBat');
  const hState = document.getElementById('hState');

  function W() { return stage.clientWidth; }
  function H() { return stage.clientHeight; }

  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0x000000);
  scene.fog = new THREE.Fog(0x000000, 2, 14);

  const camera = new THREE.PerspectiveCamera(65, W() / H(), 0.1, 50);
  const renderer = new THREE.WebGLRenderer({ antialias: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.setSize(W(), H());
  stage.appendChild(renderer.domElement);

  // مصباح يدوي
  const flashlight = new THREE.SpotLight(0xffeeaa, 1.6, 12, Math.PI / 6, 0.4, 1);
  scene.add(flashlight);
  scene.add(flashlight.target);
  scene.add(new THREE.AmbientLight(0x111122, 0.25));

  // خريطة بسيطة: 1 = جدار، 0 = ممر، 2 = المخرج
  const MAP = [
    '1111111111',
    '1000000001',
    '1011110101',
    '1010000101',
    '1010111101',
    '1000100001',
    '1110101111',
    '1000100001',
    '1011111101',
    '1200000001',
    '1111111111'
  ];
  const ROWS = MAP.length, COLS = MAP[0].length, CELL = 2;
  const wallMat = new THREE.MeshStandardMaterial({ color: 0x3a3a48, roughness: 0.9 });
  const floorMat = new THREE.MeshStandardMaterial({ color: 0x1a1a22, roughness: 1 });
  const exitMat = new THREE.MeshStandardMaterial({ color: 0x33ff66, emissive: 0x22aa44, emissiveIntensity: 0.8 });
  const walls = [];
  let exitPos = null;

  for (let r = 0; r < ROWS; r++) for (let c = 0; c < COLS; c++) {
    const ch = MAP[r][c];
    const x = (c - COLS / 2) * CELL, z = (r - ROWS / 2) * CELL;
    if (ch === '1') {
      const m = new THREE.Mesh(new THREE.BoxGeometry(CELL, 2.2, CELL), wallMat);
      m.position.set(x, 1.1, z);
      scene.add(m);
      walls.push({ x, z });
    }
    if (ch === '2') {
      exitPos = { x, z };
      const e = new THREE.Mesh(new THREE.BoxGeometry(1.2, 1.2, 0.2), exitMat);
      e.position.set(x, 1.0, z);
      scene.add(e);
    }
  }
  const floor = new THREE.Mesh(new THREE.PlaneGeometry(COLS * CELL, ROWS * CELL), floorMat);
  floor.rotation.x = -Math.PI / 2;
  scene.add(floor);

  // حالة اللعب
  const player = { x: 0, z: 0, yaw: 0, speed: 2.4 };
  let battery = 100, state = 'play', lastT = performance.now(), flicker = 0;
  let monster = { x: 0, z: 0, speed: 1.4, alert: false };

  function findStart() {
    for (let r = 0; r < ROWS; r++) for (let c = 0; c < COLS; c++) {
      if (MAP[r][c] === '0') {
        const x = (c - COLS / 2) * CELL, z = (r - ROWS / 2) * CELL;
        if (Math.hypot(x - exitPos.x, z - exitPos.z) > 8) return { x, z };
      }
    }
    return { x: 0, z: 0 };
  }

  function reset() {
    const s = findStart();
    player.x = s.x; player.z = s.z; player.yaw = 0;
    monster = { x: exitPos.x, z: exitPos.z, speed: 1.4, alert: false };
    battery = 100; state = 'play';
    msgEl.textContent = 'اسحب الشاشة للتحرك وتدوير الكاميرا. اهرب إلى المخرج الأخضر.';
  }

  // التحكم باللمس: سحب أفقي يدور، سحب عمودي يمشي للأمام/الخلف
  let drag = null, move = { f: 0 };
  stage.addEventListener('pointerdown', e => { drag = { x: e.clientX, y: e.clientY }; });
  stage.addEventListener('pointermove', e => {
    if (!drag) return;
    player.yaw -= (e.clientX - drag.x) * 0.008;
    move.f = Math.max(-1, Math.min(1, (drag.y - e.clientY) * 0.02));
    drag.x = e.clientX; drag.y = e.clientY;
  });
  const stopDrag = () => { drag = null; move.f = 0; };
  stage.addEventListener('pointerup', stopDrag);
  stage.addEventListener('pointercancel', stopDrag);

  // اصطدام بسيط مع الجدران
  function blocked(x, z) {
    const c = Math.round(x / CELL + COLS / 2 - 0.5);
    const r = Math.round(z / CELL + ROWS / 2 - 0.5);
    if (r < 0 || c < 0 || r >= ROWS || c >= COLS) return true;
    return MAP[r][c] === '1';
  }

  // الوحش: يلاحق اللاعب إذا رآه، ويعود للتجوّل إذا اختبأ
  function seesPlayer() {
    const dx = player.x - monster.x, dz = player.z - monster.z;
    const d = Math.hypot(dx, dz);
    if (d > 8) return false;
    const steps = Math.ceil(d / 0.5);
    for (let i = 1; i < steps; i++) {
      const t = i / steps;
      if (blocked(monster.x + dx * t, monster.z + dz * t)) return false;
    }
    return true;
  }

  function update(dt) {
    if (state !== 'play') return;
    battery -= dt * 1.2;
    if (battery <= 0) { battery = 0; state = 'lost'; msgEl.textContent = 'نفدت البطارية! اضغط إعادة اللعب.'; }

    // الحركة
    const sin = Math.sin(player.yaw), cos = Math.cos(player.yaw);
    const fx = -sin * move.f * player.speed * dt, fz = -cos * move.f * player.speed * dt;
    if (!blocked(player.x + fx, player.z)) player.x += fx;
    if (!blocked(player.x, player.z + fz)) player.z += fz;

    // الوحش
    monster.alert = seesPlayer();
    const tx = monster.alert ? player.x : monster.x;
    const tz = monster.alert ? player.z : monster.z;
    const dx = tx - monster.x, dz = tz - monster.z, d = Math.hypot(dx, dz);
    if (d > 0.05) {
      const sp = monster.speed * (monster.alert ? 1.6 : 0.6) * dt;
      const nx = monster.x + dx / d * sp, nz = monster.z + dz / d * sp;
      if (!blocked(nx, monster.z)) monster.x = nx;
      if (!blocked(monster.x, nz)) monster.z = nz;
    }
    if (Math.hypot(monster.x - player.x, monster.z - player.z) < 0.7) {
      state = 'lost';
      msgEl.textContent = 'أمسك بك الوحش! اضغط إعادة اللعب.';
    }

    // الوصول إلى المخرج
    if (exitPos && Math.hypot(player.x - exitPos.x, player.z - exitPos.z) < 1.2) {
      state = 'won';
      msgEl.textContent = 'نجوت! وصلت إلى المخرج.';
    }
  }

  function render(now) {
    const dt = Math.min(0.05, (now - lastT) / 1000);
    lastT = now;
    update(dt);

    camera.position.set(player.x, 1.5, player.z);
    camera.rotation.set(0, player.yaw, 0, 'YXZ');
    flashlight.position.set(player.x, 1.4, player.z);
    flashlight.target.position.set(player.x - Math.sin(player.yaw) * 4, 1, player.z - Math.cos(player.yaw) * 4);
    flicker = battery < 25 ? (Math.random() > 0.85 ? 0.3 : 1) : 1;
    flashlight.intensity = 1.6 * flicker * Math.max(0.2, battery / 100);

    // الوحش يظهر كمكعب أحمر داخل الظلام فقط إذا كان قريباً
    renderer.render(scene, camera);
    hBat.textContent = 'البطارية: ' + Math.ceil(battery);
    hState.textContent = monster.alert ? 'الوحش يطاردك!' : 'الهروب من الظلام';
    requestAnimationFrame(render);
  }

  document.getElementById('restart').onclick = reset;
  window.addEventListener('resize', () => {
    camera.aspect = W() / H();
    camera.updateProjectionMatrix();
    renderer.setSize(W(), H());
  });

  reset();
  requestAnimationFrame(render);
</script>
</body>
</html>
''';

class HorrorPage extends StatefulWidget {
  const HorrorPage({super.key});

  @override
  State<HorrorPage> createState() => _HorrorPageState();
}

class _HorrorPageState extends State<HorrorPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(_horrorHtml, baseUrl: 'https://localhost/');
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
