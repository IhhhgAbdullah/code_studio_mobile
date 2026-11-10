import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String _gameHtml = r'''
<!DOCTYPE html>
<html dir="ltr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
<style>
  * { box-sizing: border-box; }
  body { font-family: sans-serif; margin: 0; padding: 10px; background: #0D2B52; color: #fff; }
  .card { background: #132F5A; border: 1px solid #D4AF37; border-radius: 14px; padding: 10px; margin-bottom: 10px; }
  .title { color: #D4AF37; font-weight: bold; font-size: 14px; margin-bottom: 6px; direction: rtl; text-align: right; }
  textarea { width: 100%; height: 170px; background: #0A1F3D; color: #e6edf7; border: none;
    border-radius: 10px; padding: 10px; font-family: monospace; font-size: 14px; direction: ltr; }
  .row { display: flex; gap: 8px; margin-top: 8px; }
  .row > * { flex: 1; }
  button { padding: 12px; font-size: 15px; border: none; border-radius: 10px;
    background: #D4AF37; color: #0D2B52; font-weight: bold; }
  button.alt { background: #2A4A7A; color: #fff; }
  button.danger { background: #8B2A2A; color: #fff; }
  #wrap { width: 100%; }
  canvas { width: 100%; height: auto; background: #0A1F3D; border-radius: 10px; display: block; touch-action: none; }
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
  <div class="title">الشاشة (حرّك اللاعب بالأسهم أو بلمس الشاشة)</div>
  <div id="wrap"><canvas id="cv" width="360" height="480"></canvas></div>
</div>
<script>
  const cv = document.getElementById('cv');
  const codeEl = document.getElementById('code');
  const errEl = document.getElementById('err');
  const keys = {};
  const touch = { down: false, x: 0, y: 0 };
  let raf = null;

  const SAMPLE = `let player, coins, enemies, score, lives, level, timeLeft, state;
let best = Number(localStorage.getItem('cs_best') || 0);

function startLevel() {
  const n = 6 + level * 2;
  coins = [];
  enemies = [];
  for (let i = 0; i < n; i++) {
    coins.push({ x: 30 + Math.random() * 300, y: 30 + Math.random() * 300, r: 9 });
  }
  for (let i = 0; i < Math.min(1 + level, 6); i++) {
    enemies.push({
      x: 40 + Math.random() * 280,
      y: 60 + Math.random() * 200,
      vx: (Math.random() < 0.5 ? -1 : 1) * (70 + level * 15),
      vy: (Math.random() < 0.5 ? -1 : 1) * (60 + level * 15),
      r: 14
    });
  }
  player.x = 180; player.y = 420;
  timeLeft = 30;
}

function setup() {
  player = { x: 180, y: 420, speed: 220 };
  score = 0;
  lives = 3;
  level = 1;
  state = 'play';
  startLevel();
}

function endGame() {
  state = 'over';
  if (score > best) {
    best = score;
    localStorage.setItem('cs_best', String(best));
  }
}

function update(dt) {
  if (state !== 'play') return;
  timeLeft -= dt;
  if (timeLeft <= 0) { lives--; if (lives <= 0) return endGame(); startLevel(); return; }

  const s = player.speed * dt;
  if (keys.ArrowLeft) player.x -= s;
  if (keys.ArrowRight) player.x += s;
  if (keys.ArrowUp) player.y -= s;
  if (keys.ArrowDown) player.y += s;
  if (touch.down) {
    player.x += (touch.x - player.x) * 0.1;
    player.y += (touch.y - player.y) * 0.1;
  }
  player.x = Math.max(12, Math.min(W - 12, player.x));
  player.y = Math.max(12, Math.min(H - 12, player.y));

  for (const e of enemies) {
    e.x += e.vx * dt;
    e.y += e.vy * dt;
    if (e.x < e.r || e.x > W - e.r) e.vx = -e.vx;
    if (e.y < e.r || e.y > H - e.r) e.vy = -e.vy;
    if (Math.hypot(e.x - player.x, e.y - player.y) < e.r + 12) {
      lives--;
      player.x = 180; player.y = 420;
      if (lives <= 0) return endGame();
    }
  }

  coins = coins.filter(c => {
    if (Math.hypot(c.x - player.x, c.y - player.y) < c.r + 14) { score += 10; return false; }
    return true;
  });

  if (coins.length === 0) {
    level++;
    score += 50;
    startLevel();
  }
}

function draw(ctx) {
  ctx.fillStyle = '#D4AF37';
  for (const c of coins) {
    ctx.beginPath();
    ctx.arc(c.x, c.y, c.r, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.fillStyle = '#FF6B6B';
  for (const e of enemies) {
    ctx.beginPath();
    ctx.arc(e.x, e.y, e.r, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.fillStyle = '#7CFC7C';
  ctx.fillRect(player.x - 12, player.y - 12, 24, 24);

  ctx.fillStyle = '#fff';
  ctx.font = '15px sans-serif';
  ctx.fillText('النقاط: ' + score, 8, 22);
  ctx.fillText('المرحلة: ' + level, 130, 22);
  ctx.fillText('الوقت: ' + Math.ceil(timeLeft), 250, 22);
  ctx.fillText('الحياة: ' + '♥'.repeat(Math.max(0, lives)), 8, 44);
  ctx.fillText('أفضل: ' + best, 250, 44);

  if (state === 'over') {
    ctx.fillStyle = 'rgba(0,0,0,0.6)';
    ctx.fillRect(0, 0, W, H);
    ctx.fillStyle = '#D4AF37';
    ctx.font = 'bold 26px sans-serif';
    ctx.fillText('انتهت اللعبة', 90, 220);
    ctx.font = '18px sans-serif';
    ctx.fillText('نتيجتك: ' + score, 115, 255);
    ctx.fillText('أفضل نتيجة: ' + best, 100, 285);
    ctx.fillText('اضغط تشغيل للعب مرة أخرى', 40, 320);
  }
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
