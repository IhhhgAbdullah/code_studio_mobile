import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String _memoryJs = r'''
let cards, first, second, lock, moves, matched, timeLeft, state, best;
best = Number(localStorage.getItem('cs_memory_best') || 999);
const SYMBOLS = ['★', '♥', '♣', '♦', '●', '▲'];

function setup() {
  const pairs = [...SYMBOLS, ...SYMBOLS];
  for (let i = pairs.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [pairs[i], pairs[j]] = [pairs[j], pairs[i]];
  }
  cards = pairs.map((sym, i) => ({ sym, open: false, done: false,
    x: 20 + (i % 4) * 85, y: 80 + Math.floor(i / 4) * 85, w: 75, h: 75 }));
  first = null; second = null; lock = false;
  moves = 0; matched = 0; timeLeft = 90; state = 'play';
}

function update(dt) {
  if (state !== 'play') return;
  timeLeft -= dt;
  if (timeLeft <= 0) state = 'over';
}

function pick(x, y) {
  if (state !== 'play' || lock) return;
  const c = cards.find(k => !k.done && !k.open && x >= k.x && x <= k.x + k.w && y >= k.y && y <= k.y + k.h);
  if (!c) return;
  c.open = true;
  if (!first) { first = c; return; }
  second = c; moves++; lock = true;
  setTimeout(() => {
    if (first.sym === second.sym) {
      first.done = true; second.done = true; matched += 2;
      if (matched === cards.length) {
        state = 'win';
        const score = Math.max(0, Math.ceil(timeLeft)) + Math.max(0, 40 - moves);
        if (score > best) { best = score; localStorage.setItem('cs_memory_best', String(best)); }
      }
    } else { first.open = false; second.open = false; }
    first = null; second = null; lock = false;
  }, 700);
}

function draw(ctx) {
  ctx.fillStyle = '#fff'; ctx.font = '15px sans-serif';
  ctx.fillText('الحركات: ' + moves, 8, 22);
  ctx.fillText('الوقت: ' + Math.ceil(Math.max(0, timeLeft)), 250, 22);
  ctx.fillText('أفضل: ' + (best === 999 ? '-' : best), 250, 44);
  for (const c of cards) {
    ctx.fillStyle = c.done ? '#1f4a2a' : (c.open ? '#D4AF37' : '#2A4A7A');
    ctx.fillRect(c.x, c.y, c.w, c.h);
    if (c.open || c.done) {
      ctx.fillStyle = c.done ? '#7CFC7C' : '#0D2B52';
      ctx.font = 'bold 30px sans-serif';
      ctx.fillText(c.sym, c.x + 22, c.y + 50);
    }
  }
  if (state === 'over' || state === 'win') {
    ctx.fillStyle = 'rgba(0,0,0,0.6)'; ctx.fillRect(0, 0, 360, 480);
    ctx.fillStyle = '#D4AF37'; ctx.font = 'bold 24px sans-serif';
    ctx.fillText(state === 'win' ? 'أحسنت! أنهيت اللعبة' : 'انتهى الوقت', 70, 220);
    ctx.font = '16px sans-serif';
    ctx.fillText('الحركات: ' + moves, 135, 255);
    ctx.fillText('اضغط تشغيل للعب مرة أخرى', 40, 290);
  }
}
''';

const String _dodgeJs = r'''
let player, obstacles, score, lives, spawnT, timeLeft, state, best;
best = Number(localStorage.getItem('cs_dodge_best') || 0);

function setup() {
  player = { x: 180, y: 420, r: 16, speed: 260 };
  obstacles = []; score = 0; lives = 3; spawnT = 0; timeLeft = 60; state = 'play';
}

function update(dt) {
  if (state !== 'play') return;
  timeLeft -= dt;
  if (timeLeft <= 0) { state = 'over'; saveBest(); return; }
  const s = player.speed * dt;
  if (keys.ArrowLeft) player.x -= s;
  if (keys.ArrowRight) player.x += s;
  if (touch.down) player.x += (touch.x - player.x) * 0.2;
  player.x = Math.max(player.r, Math.min(360 - player.r, player.x));
  spawnT -= dt;
  if (spawnT <= 0) {
    spawnT = Math.max(0.35, 0.9 - score * 0.01);
    obstacles.push({ x: 20 + Math.random() * 320, y: -20, r: 14 + Math.random() * 10, v: 140 + score * 2 });
  }
  for (const o of obstacles) o.y += o.v * dt;
  obstacles = obstacles.filter(o => {
    if (o.y > 480 + o.r) { score += 1; return false; }
    if (Math.hypot(o.x - player.x, o.y - player.y) < o.r + player.r) {
      lives--;
      if (lives <= 0) { state = 'over'; saveBest(); }
      return false;
    }
    return true;
  });
}

function saveBest() {
  if (score > best) { best = score; localStorage.setItem('cs_dodge_best', String(best)); }
}

function draw(ctx) {
  ctx.fillStyle = '#FF6B6B';
  for (const o of obstacles) { ctx.beginPath(); ctx.arc(o.x, o.y, o.r, 0, Math.PI * 2); ctx.fill(); }
  ctx.fillStyle = '#7CFC7C';
  ctx.beginPath(); ctx.arc(player.x, player.y, player.r, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = '#fff'; ctx.font = '15px sans-serif';
  ctx.fillText('النقاط: ' + score, 8, 22);
  ctx.fillText('الحياة: ' + '♥'.repeat(Math.max(0, lives)), 8, 44);
  ctx.fillText('الوقت: ' + Math.ceil(Math.max(0, timeLeft)), 250, 22);
  ctx.fillText('أفضل: ' + best, 250, 44);
  if (state === 'over') {
    ctx.fillStyle = 'rgba(0,0,0,0.6)'; ctx.fillRect(0, 0, 360, 480);
    ctx.fillStyle = '#D4AF37'; ctx.font = 'bold 24px sans-serif';
    ctx.fillText('انتهت اللعبة', 95, 220);
    ctx.font = '16px sans-serif';
    ctx.fillText('نتيجتك: ' + score, 130, 255);
    ctx.fillText('اضغط تشغيل للعب مرة أخرى', 40, 290);
  }
}
''';

const String _coinsJs = r'''
let player, coins, score, timeLeft, state;

function setup() {
  player = { x: 180, y: 420, r: 14, speed: 240 };
  coins = [];
  for (let i = 0; i < 8; i++) coins.push({ x: 30 + Math.random() * 300, y: 30 + Math.random() * 380, r: 9 });
  score = 0; timeLeft = 40; state = 'play';
}

function update(dt) {
  if (state !== 'play') return;
  timeLeft -= dt;
  if (timeLeft <= 0) { state = 'over'; return; }
  const s = player.speed * dt;
  if (keys.ArrowLeft) player.x -= s;
  if (keys.ArrowRight) player.x += s;
  if (keys.ArrowUp) player.y -= s;
  if (keys.ArrowDown) player.y += s;
  if (touch.down) { player.x += (touch.x - player.x) * 0.15; player.y += (touch.y - player.y) * 0.15; }
  player.x = Math.max(player.r, Math.min(360 - player.r, player.x));
  player.y = Math.max(player.r, Math.min(480 - player.r, player.y));
  coins = coins.filter(c => {
    if (Math.hypot(c.x - player.x, c.y - player.y) < c.r + player.r) { score += 10; return false; }
    return true;
  });
  if (coins.length === 0) {
    for (let i = 0; i < 8; i++) coins.push({ x: 30 + Math.random() * 300, y: 30 + Math.random() * 380, r: 9 });
  }
}

function draw(ctx) {
  ctx.fillStyle = '#D4AF37';
  for (const c of coins) { ctx.beginPath(); ctx.arc(c.x, c.y, c.r, 0, Math.PI * 2); ctx.fill(); }
  ctx.fillStyle = '#7CFC7C';
  ctx.beginPath(); ctx.arc(player.x, player.y, player.r, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = '#fff'; ctx.font = '15px sans-serif';
  ctx.fillText('النقاط: ' + score, 8, 22);
  ctx.fillText('الوقت: ' + Math.ceil(Math.max(0, timeLeft)), 250, 22);
  if (state === 'over') {
    ctx.fillStyle = 'rgba(0,0,0,0.6)'; ctx.fillRect(0, 0, 360, 480);
    ctx.fillStyle = '#D4AF37'; ctx.font = 'bold 24px sans-serif';
    ctx.fillText('انتهى الوقت', 100, 230);
    ctx.font = '16px sans-serif';
    ctx.fillText('نتيجتك: ' + score, 130, 262);
    ctx.fillText('اضغط تشغيل للعب مرة أخرى', 40, 295);
  }
}
''';

String _pageHtml(String gameJs, String title) {
  return '''
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
  button { padding: 10px; font-size: 14px; border: none; border-radius: 10px;
    background: #D4AF37; color: #0D2B52; font-weight: bold; width: 100%; }
  button.alt { background: #2A4A7A; color: #fff; }
  canvas { width: 100%; height: auto; background: #0A1F3D; border-radius: 10px; display: block; touch-action: none; }
  .row { display: flex; gap: 8px; margin-top: 8px; }
  .row > * { flex: 1; }
  .err { color: #ff6b6b; font-size: 13px; margin-top: 6px; min-height: 16px; }
</style>
</head>
<body>
<div class="card">
  <div class="title">$title (حرّك اللاعب بالأسهم أو بالسحب)</div>
  <canvas id="cv" width="360" height="480"></canvas>
  <div class="row">
    <button id="run">تشغيل</button>
    <button id="stop" class="alt">إيقاف</button>
  </div>
  <div id="err" class="err"></div>
</div>
<script>
$gameJs
</script>
<script>
  const W = 360, H = 480;
  const cv = document.getElementById('cv');
  const ctx = cv.getContext('2d');
  const errEl = document.getElementById('err');
  const keys = {};
  const touch = { down: false, x: 0, y: 0 };
  let raf = null;
  let game = null;

  function pos(e) {
    const r = cv.getBoundingClientRect();
    return { x: (e.clientX - r.left) * W / r.width, y: (e.clientY - r.top) * H / r.height };
  }
  cv.addEventListener('pointerdown', e => { touch.down = true; const p = pos(e); touch.x = p.x; touch.y = p.y; });
  cv.addEventListener('pointermove', e => { if (!touch.down) return; const p = pos(e); touch.x = p.x; touch.y = p.y; });
  cv.addEventListener('pointerup', e => {
    touch.down = false;
    const p = pos(e);
    if (game && typeof game.pick === 'function') { try { game.pick(p.x, p.y); } catch (err) { errEl.textContent = 'خطأ: ' + err; } }
  });
  cv.addEventListener('pointercancel', () => { touch.down = false; });
  window.addEventListener('keydown', e => { keys[e.key] = true; if (e.key.startsWith('Arrow')) e.preventDefault(); });
  window.addEventListener('keyup', e => { keys[e.key] = false; });

  function stop() { if (raf) cancelAnimationFrame(raf); raf = null; }

  function run() {
    stop();
    errEl.textContent = '';
    try {
      game = { setup, update, draw, pick: typeof pick === 'function' ? pick : null };
      game.setup();
    } catch (e) { errEl.textContent = 'خطأ في اللعبة: ' + e; return; }
    let last = performance.now();
    function frame(now) {
      const dt = Math.min(0.05, (now - last) / 1000);
      last = now;
      try {
        game.update(dt);
        ctx.fillStyle = '#0A1F3D';
        ctx.fillRect(0, 0, W, H);
        game.draw(ctx);
      } catch (e) { errEl.textContent = 'خطأ أثناء التشغيل: ' + e; raf = null; return; }
      raf = requestAnimationFrame(frame);
    }
    raf = requestAnimationFrame(frame);
  }

  document.getElementById('run').onclick = run;
  document.getElementById('stop').onclick = () => { stop(); errEl.textContent = 'متوقفة'; };
  run();
</script>
</body>
</html>
''';
}

class GamePage extends StatefulWidget {
  const GamePage({super.key, this.template = 'memory'});

  // القيم الممكنة: memory أو dodge أو coins
  final String template;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    final String js;
    final String title;
    switch (widget.template) {
      case 'dodge':
        js = _dodgeJs;
        title = 'تجنب العوائق';
        break;
      case 'coins':
        js = _coinsJs;
        title = 'جمع العملات';
        break;
      default:
        js = _memoryJs;
        title = 'الذاكرة';
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(_pageHtml(js, title), baseUrl: 'https://localhost/');
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
