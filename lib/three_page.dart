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
  #stage { width: 100%; height: 360px; border-radius: 10px; overflow: hidden; background: #0A1F3D; }
  #stage canvas { display: block; width: 100% !important; height: 100% !important; }
  button { width: 100%; margin-top: 10px; padding: 12px; font-size: 15px; border: none;
    border-radius: 10px; background: #D4AF37; color: #0D2B52; font-weight: bold; }
  .msg { color: #ff6b6b; font-size: 13px; margin-top: 6px; min-height: 16px; }
</style>
</head>
<body>
<div class="card">
  <div class="title">مشهد 3D (اختبار Three.js)</div>
  <div id="stage"></div>
  <button id="toggle">إيقاف الدوران</button>
  <div id="err" class="msg"></div>
</div>
<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
<script>
  const errEl = document.getElementById('err');
  const btn = document.getElementById('toggle');
  let spinning = true;

  if (typeof THREE === 'undefined') {
    errEl.textContent = 'تعذّر تحميل Three.js. تأكد من اتصال الإنترنت.';
  } else {
    const stage = document.getElementById('stage');
    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0x0a1f3d);

    const camera = new THREE.PerspectiveCamera(50, stage.clientWidth / stage.clientHeight, 0.1, 100);
    camera.position.set(0, 1.5, 4);
    camera.lookAt(0, 0, 0);

    const renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.setSize(stage.clientWidth, stage.clientHeight);
    stage.appendChild(renderer.domElement);

    scene.add(new THREE.AmbientLight(0xffffff, 0.5));
    const sun = new THREE.DirectionalLight(0xffffff, 0.9);
    sun.position.set(3, 4, 5);
    scene.add(sun);

    const cube = new THREE.Mesh(
      new THREE.BoxGeometry(1.4, 1.4, 1.4),
      new THREE.MeshStandardMaterial({ color: 0xd4af37, metalness: 0.3, roughness: 0.4 })
    );
    scene.add(cube);

    const floor = new THREE.Mesh(
      new THREE.CircleGeometry(2.2, 48),
      new THREE.MeshStandardMaterial({ color: 0x1a3d6e })
    );
    floor.rotation.x = -Math.PI / 2;
    floor.position.y = -1.1;
    scene.add(floor);

    function tick() {
      if (spinning) {
        cube.rotation.x += 0.01;
        cube.rotation.y += 0.015;
      }
      renderer.render(scene, camera);
      requestAnimationFrame(tick);
    }
    tick();

    btn.onclick = () => {
      spinning = !spinning;
      btn.textContent = spinning ? 'إيقاف الدوران' : 'تشغيل الدوران';
    };
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
