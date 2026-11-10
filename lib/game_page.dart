import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String _gameHtml = r'''
<!DOCTYPE html>
<html dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
<style>
  * { box-sizing: border-box; }
  body { font-family: sans-serif; margin: 0; padding: 10px; background: #0D2B52; color: #fff; }
  .card { background: #132F5A; border: 1px solid #D4AF37; border-radius: 14px; padding: 10px; margin-bottom: 10px; }
  .title { color: #D4AF37; font-weight: bold; font-size: 14px; margin-bottom: 6px; }
  textarea { width: 100%; height: 190px; background: #0A1F3D; color: #e6edf7; border: none;
    border-radius: 10px; padding: 10px; font-family: monospace; font-size: 14px; direction: ltr; }
  .row { display: flex; gap: 8px; margin-top: 8px; }
  .row > * { flex: 1; }
  button { padding: 12px; font-size: 15px; border: none; border-radius: 10px;
    background: #D4AF37; color: #0D2B52; font-weight: bold; }
  button.alt { background: #2A4A7A; color: #fff; }
  button.danger { background: #8B2A2A; color: #fff; }
  canvas { width: 100%; background: #0A1F3D; border-radius: 10px; display: block; touch-action: none; }
  .msg { color: #ff6b6b; font-size: 13px; margin-top: 6px; min-height: 16px; direction: ltr; text-align: left; }
</style>
</head>
<body>
<div class="card">
  <div class="title">كود اللعبة (JavaScript): دوال setup و update و draw</div>
  <textarea id="code"></textarea>
  <div class="row">
    <button id="run">تشغيل</button>
    <button id="stop" class="danger">إيقاف</button>
    <button id="sample" class="alt">نموذج</button>
  </div>
  <div id="err" class="msg"></div>
</div>
<div class="card">
  <div class="title">الشاشة (على الهاتف حرّك اللاعب بلمس الشاشة)</div>
  <canvas id="cv" width="360" height="480"></canvas>
</div>
<script>
  const cv = document.getElementById('cv');
  const codeEl = document.getElementById('code');
  const errEl = document.getElementById('err');
  const keys = {};
  const touch = { down: false, x: 0, y: 0 };
  let raf = null;

  const SAMPLE = `let x = 180, y = 240, coins = [], score = 0;
function setup() {
  for (let i = 0; i < 6; i++) {
    coins.push({ x: 40 + i * 55, y: 80 + (i % 2) * 300, r: 12 });
  }
}
function update(dt) {
  const s = 180 * dt;
  if (keys.ArrowLeft) x -= s;
  if (keys.ArrowRight) x += s;
  if (keys.ArrowUp) y -= s;
  if (keys.ArrowDown) y += s;
  if (touch.down) {
    x += (touch.x - x) * 0.12;
    y += (touch.y - y) * 0.12;
  }
  x = Math.max(16, Math.min(W - 16, x));
  y = Math.max(16, Math.min(H - 16, y));
  coins = coins.filter(c => {
    if (Math.hypot(c.x - x, c.y - y) < c.r + 16) { score++; return false; }
    return true;
  });
}
function draw(ctx) {
  ctx.fillStyle = '#D4AF37';
  coins.forEach(c => {
    ctx.beginPath();
    ctx.arc(c.x, c.y, c.r, 0, Math.PI * 2);
    ctx.fill();
  });
  ctx.fillStyle = '#7CFC7C';
  ctx.fillRect(x - 16, y - 16, 32, 32);
  ctx.fillStyle = '#fff';
  ctx.font = '16px sans-serif';
  ctx.fillText('النقاط: ' + score, 10, 24);
}`;

  codeEl.value = SAMPLE;

  function pos(e) {
    const r = cv.getBoundingClientRect();
    return {
      x: (e.clientX - r.left) * cv.width / r.width,
      y: (e.clientY - r.top) * cv.height / r.height
    };
  }

  cv.addEventListener('pointerdown', e => {
    touch.down = true;
    const p = pos(e); touch.x = p.x; touch.y = p.y;
  });
  cv.addEventListener('pointermove', e => {
    if (!touch.down) return;
    const p = pos(e); touch.x = p.x; touch.y = p.y;
  });
  window.addEventListener('pointerup', () => { touch.down = false; });
  window.addEventListener('keydown', e => {
    keys[e.key] = true;
    if (e.key.startsWith('Arrow')) e.preventDefault();
  });
  window.addEventListener('keyup', e => { keys[e.key] = false; });

  function stop() {
    if (raf) cancelAnimationFrame(raf);
    raf = null;
  }

  function run() {
    stop();
    errEl.textContent = '';
    const ctx = cv.getContext('2d');
    let g;
    try {
      const src = codeEl.value + '\n;return { setup: typeof setup === "function" ? setup : null, update: typeof update === "function" ? update : null, draw: typeof draw === "function" ? draw : null };';
      g = new Function('ctx', 'keys', 'touch', 'W', 'H', src)(ctx, keys, touch, cv.width, cv.height);
      if (g.setup) g.setup();
    } catch (e) {
      errEl.textContent = 'خطأ في الكود: ' + e;
      return;
    }
    let last = performance.now();
    function frame(now) {
      const dt = Math.min(0.05, (now - last) / 1000);
      last = now;
      try {
        if (g.update) g.update(dt);
        ctx.fillStyle = '#0A1F3D';
        ctx.fillRect(0, 0, cv.width, cv.height);
        if (g.draw) g.draw(ctx);
      } catch (e) {
        errEl.textContent = 'خطأ أثناء التشغيل: ' + e;
        raf = null;
        return;
      }
      raf = requestAnimationFrame(frame);
    }
    raf = requestAnimationFrame(frame);
  }

  document.getElementById('run').addEventListener('click', run);
  document.getElementById('stop').addEventListener('click', () => { stop(); errEl.textContent = 'متوقفة'; });
  document.getElementById('sample').addEventListener('click', () => { codeEl.value = SAMPLE; });
</script>
</body>
</html>
''';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(_gameHtml, baseUrl: 'https://localhost/');
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
