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
  .card { background: #132F5A; border: 1px solid #D4AF37; border-radius: 14px; padding: 10px; }
  .title { color: #D4AF37; font-weight: bold; font-size: 14px; margin-bottom: 8px; }
  .row { display: flex; gap: 8px; margin-top: 8px; }
  .row > * { flex: 1; }
  #stage { width: 100%; height: 360px; border-radius: 10px; overflow: hidden; background: #0A1F3D; touch-action: none; }
  #stage canvas { display: block; width: 100% !important; height: 100% !important; }
  button { padding: 10px; font-size: 14px; border: none; border-radius: 10px;
    background: #D4AF37; color: #0D2B52; font-weight: bold; }
  button.alt { background: #2A4A7A; color: #fff; }
  button.danger { background: #8B2A2A; color: #fff; }
  button.sel { outline: 2px solid #fff; }
  .hint { font-size: 12px; color: #cfd8e6; margin-top: 8px; }
  .msg { color: #ff6b6b; font-size: 13px; margin-top: 6px; min-height: 16px; }
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
  <div class="row">
    <button id="clear" class="danger">حذف الكل</button>
  </div>
  <div class="hint">سحب بإصبع واحد لتدوير الكاميرا.</div>
  <div id="err" class="msg"></div>
</div>
<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
<script>
  const errEl = document.getElementById('err');
  let kind = 'box';

  if (typeof THREE === 'undefined') {
    errEl.textContent = 'تعذّر تحميل Three.js. تأكد من اتصال الإنترنت.';
  } else {
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

    // أرضية الأساس (ثابتة، مرئية دائماً)
    const base = new THREE.Mesh(
      new THREE.CircleGeometry(12, 64),
      new THREE.MeshStandardMaterial({ color: 0x1a3d6e })
    );
    base.rotation.x = -Math.PI / 2;
    scene.add(base);

    const shapes = [];
    const COLORS = [0xd4af37, 0x7cfc7c, 0xff6b6b, 0x82aaff, 0xffffff];
    let colorIdx = 0;

    function makeMesh(k) {
      const mat = new THREE.MeshStandardMaterial({
        color: COLORS[colorIdx % COLORS.length], metalness: 0.2, roughness: 0.5
      });
      colorIdx++;
      let geo;
      if (k === 'sphere') geo = new THREE.SphereGeometry(0.7, 32, 24);
      else if (k === 'cylinder') geo = new THREE.CylinderGeometry(0.6, 0.6, 1.6, 32);
      else if (k === 'floor') geo = new THREE.BoxGeometry(2.4, 0.15, 2.4);
      else geo = new THREE.BoxGeometry(1.4, 1.4, 1.4);
      return new THREE.Mesh(geo, mat);
    }

    // الأرضية الحقيقية تُضاف كطبقة بسيطة فوق الأساس
    const raycaster = new THREE.Raycaster();
    const ndc = new THREE.Vector2();
    const groundPlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
    const hitPoint = new THREE.Vector3();

    function addAt(clientX, clientY) {
      const rect = renderer.domElement.getBoundingClientRect();
      ndc.x = ((clientX - rect.left) / rect.width) * 2 - 1;
      ndc.y = -((clientY - rect.top) / rect.height) * 2 + 1;
      raycaster.setFromCamera(ndc, camera);
      if (!raycaster.ray.intersectPlane(groundPlane, hitPoint)) return;
      const m = makeMesh(kind);
      const lift = kind === 'floor' ? 0.075 : (kind === 'sphere' ? 0.7 : (kind === 'cylinder' ? 0.8 : 0.7));
      m.position.set(Math.round(hitPoint.x * 2) / 2, lift, Math.round(hitPoint.z * 2) / 2);
      scene.add(m);
      shapes.push(m);
    }

    // تدوير الكاميرا بسحب إصبع واحد، والنقر القصير يضيف شكلاً
    let drag = null;
    renderer.domElement.addEventListener('pointerdown', e => {
      drag = { x: e.clientX, y: e.clientY, moved: false, sx: e.clientX, sy: e.clientY };
    });
    renderer.domElement.addEventListener('pointermove', e => {
      if (!drag) return;
      const dx = e.clientX - drag.x;
      const dy = e.clientY - drag.y;
      if (Math.abs(e.clientX - drag.sx) + Math.abs(e.clientY - drag.sy) > 8) drag.moved = true;
      if (drag.moved) {
        camTheta -= dx * 0.008;
        camPhi -= dy * 0.006;
        updateCamera();
      }
      drag.x = e.clientX; drag.y = e.clientY;
    });
    renderer.domElement.addEventListener('pointerup', e => {
      if (drag && !drag.moved) addAt(e.clientX, e.clientY);
      drag = null;
    });
    renderer.domElement.addEventListener('pointercancel', () => { drag = null; });

    document.getElementById('clear').onclick = () => {
      shapes.forEach(s => { scene.remove(s); s.geometry.dispose(); s.material.dispose(); });
      shapes.length = 0;
    };

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
