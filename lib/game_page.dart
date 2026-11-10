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
  textarea { width: 100%; height: 170px; background: #0A1F3D; color: #e6edf7; border: none;
    border-radius: 10px; padding: 10px; font-family: monospace; font-size: 13px; direction: ltr; }
  .row { display: flex; gap: 8px; margin-top: 8px; }
  .row > * { flex: 1; }
  button { padding: 10px; font-size: 14px; border: none; border-radius: 10px;
    background: #D4AF37; color: #0D2B52; font-weight: bold; }
  button.alt { background: #2A4A7A; color: #fff; }
  button.danger { background: #8B2A2A; color: #fff; }
  button.sel { outline: 2px solid #fff; }
  #wrap { width: 100%; }
  canvas { width: 100%; height: auto; background: #0A1F3D; border-radius: 10px; display: block; touch-action: none; }
  .list { margin-top: 8px; max-height: 120px; overflow-y: auto; }
  .item { display: flex; justify-content: space-between; align-items: center;
    background: #0A1F3D; border-radius: 8px; padding: 6px 10px; margin-bottom: 4px; font-size: 13px; }
  .msg { color: #ff6b6b; font-size: 13px; margin-top: 6px; min-height: 16px; direction: ltr; text-align: left; }
</style>
</head>
<body>
<div class="card">
  <div class="title">الشاشة: اختر كائناً ثم انقر على الشاشة لإضافته</div>
  <div class="row">
    <button class="alt kind" data-kind="player">لاعب</button>
    <button class="alt kind" data-kind="coin">عملة</button>
    <button class="alt kind" data-kind="enemy">عدو</button>
    <button class="alt kind" data-kind="wall">حاجز</button>
  </div>
  <div id="wrap" style="margin-top:8px"><canvas id="cv" width="360" height="480"></canvas></div>
  <div id="list" class="list"></div>
</div>
<div class="card">
  <div class="title">كود اللعبة (يتولّد تلقائياً من الشاشة، ويمكن تعديله)</div>
  <textarea id="code"></textarea>
  <div class="row">
    <button id="gen">توليد من الشاشة</button>
    <button id="run">تشغيل</button>
    <button id="stop" class="danger">إيقاف</button>
  </div>
  <div id="err" class="msg"></div>
</div>
<script>
  const cv = document.getElementById('cv');
  const ctx2d = cv.getContext('2d');
  const codeEl = document.getElementById('code');
  const errEl = document.getElementById('err');
  const listEl = document.getElementById('list');
  const keys = {};
  const touch = { down: false, x: 0, y: 0 };
  let raf = null;
  let kind = 'coin';
  let objects = [];

  const COLORS = { player: '#7CFC7C', coin: '#D4AF37', enemy: '#FF6B6B', wall: '#7A8CA8' };
  const SIZES = { player: 24, coin: 20, enemy: 28, wall: 40 };
  const LABELS = { player: 'لاعب', coin: 'عملة', enemy: 'عدو', wall: 'حاجز' };

  // ===== الأصول المدمجة =====
  const sprites = {};
  function makeSprite(name, w, h, draw) {
    const c = document.createElement('canvas');
    c.width = w; c.height = h;
    draw(c.getContext('2d'), w, h);
    sprites[name] = c;
  }
  makeSprite('coin', 24, 24, (g, w, h) => {
    g.fillStyle = '#D4AF37';
    g.beginPath(); g.arc(w / 2, h / 2, 11, 0, Math.PI * 2); g.fill();
    g.fillStyle = '#F7E08A';
    g.beginPath(); g.arc(w / 2 - 3, h / 2 - 3, 4, 0, Math.PI * 2); g.fill();
  });
  makeSprite('enemy', 32, 32, (g, w, h) => {
    g.fillStyle = '#FF6B6B';
    g.beginPath(); g.arc(w / 2, h / 2, 14, 0, Math.PI * 2); g.fill();
    g.fillStyle = '#fff';
    g.fillRect(w / 2 - 6, h / 2 - 4, 4, 4);
    g.fillRect(w / 2 + 2, h / 2 - 4, 4, 4);
  });
  makeSprite('player', 28, 28, (g, w, h) => {
    g.fillStyle = '#7CFC7C';
    g.fillRect(2, 2, w - 4, h - 4);
    g.fillStyle = '#173404';
    g.fillRect(8, 9, 4, 4);
    g.fillRect(16, 9, 4, 4);
  });

  // ===== الأصوات المولّدة =====
  let audioCtx = null;
  function beep(freq, dur, type) {
    try {
      if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
      const o = audioCtx.createOscillator();
      const g = audioCtx.createGain();
      o.type = type || 'square';
      o.frequency.value = freq;
      g.gain.value = 0.08;
      o.connect(g); g.connect(audioCtx.destination);
      o.start();
      o.stop(audioCtx.currentTime + dur);
    } catch (e) {}
  }
  const sounds = {
    coin: () => beep(880, 0.08, 'sine'),
    hit: () => beep(140, 0.25, 'sawtooth'),
    win: () => { beep(523, 0.1, 'triangle'); setTimeout(() => beep(784, 0.2, 'triangle'), 110); },
    over: () => { beep(330, 0.2, 'sawtooth'); setTimeout(() => beep(220, 0.4, 'sawtooth'), 200); }
  };
  function sprite(c, name, x, y) {
    const img = sprites[name];
    if (img) c.drawImage(img, x - img.width / 2, y - img.height / 2);
  }
  function sound(name) { if (sounds[name]) sounds[name](); }

  // ===== المحرر المرئي =====
  function redrawEditor() {
    ctx2d.fillStyle = '#0A1F3D';
    ctx2d.fillRect(0, 0, cv.width, cv.height);
    for (const o of objects) {
      if (o.kind === 'wall') {
        ctx2d.fillStyle = COLORS.wall;
        ctx2d.fillRect(o.x - 20, o.y - 10, 40, 20);
      } else {
        ctx2d.fillStyle = COLORS[o.kind];
        ctx2d.beginPath();
        ctx2d.arc(o.x, o.y, SIZES[o.kind] / 2, 0, Math.PI * 2);
        ctx2d.fill();
      }
    }
  }

  function renderList() {
    listEl.innerHTML = '';
    objects.forEach((o, i) => {
      const row = document.createElement('div');
      row.className = 'item';
      const label = document.createElement('span');
      label.textContent = LABELS[o.kind] + ' (' + Math.round(o.x) + ', ' + Math.round(o.y) + ')';
      const del = document.createElement('button');
      del.className = 'danger';
      del.textContent = 'حذف';
      del.onclick = () => { objects.splice(i, 1); refresh(); };
      row.appendChild(label);
      row.appendChild(del);
      listEl.appendChild(row);
    });
    if (!objects.length) listEl.textContent = 'لا توجد كائنات بعد.';
  }

  function refresh() {
    redrawEditor();
    renderList();
    generateCode();
  }

  function pos(e) {
    const r = cv.getBoundingClientRect();
    return {
      x: Math.round((e.clientX - r.left) * cv.width / r.width),
      y: Math.round((e.clientY - r.top) * cv.height / r.height)
    };
  }

  cv.addEventListener('click', e => {
    const p = pos(e);
    if (kind === 'player') {
      objects = objects.filter(o => o.kind !== 'player');
    }
    objects.push({ kind, x: p.x, y: p.y });
    refresh();
  });

  document.querySelectorAll('.kind').forEach(b => {
    b.addEventListener('click', () => {
      kind = b.dataset.kind;
      document.querySelectorAll('.kind').forEach(x => x.classList.toggle('sel', x === b));
    });
  });

  // توليد الكود من الكائنات المرسومة
  function generateCode() {
    const player = objects.find(o => o.kind === 'player') || { x: 180, y: 420 };
    const coins = objects.filter(o => o.kind === 'coin').map(o => `{ x: ${o.x}, y: ${o.y} }`);
    const enemies = objects.filter(o => o.kind === 'enemy').map(o => `{ x: ${o.x}, y: ${o.y}, vx: 80, vy: 60 }`);
    const walls = objects.filter(o => o.kind === 'wall').map(o => `{ x: ${o.x}, y: ${o.y} }`);
    codeEl.value = `let player, coins, enemies, walls, score, timeLeft;

function setup() {
  player = { x: ${player.x}, y: ${player.y}, speed: 200 };
  coins = [${coins.join(', ')}];
  enemies = [${enemies.join(', ')}];
  walls = [${walls.join(', ')}];
  score = 0;
  timeLeft = 30;
}

function update(dt) {
  timeLeft -= dt;
  const s = player.speed * dt;
  if (keys.ArrowLeft) player.x -= s;
  if (keys.ArrowRight) player.x += s;
  if (keys.ArrowUp) player.y -= s;
  if (keys.ArrowDown) player.y += s;
  if (touch.down) {
    player.x += (touch.x - player.x) * 0.1;
    player.y += (touch.y - player.y) * 0.1;
  }
  player.x = Math.max(14, Math.min(W - 14, player.x));
  player.y = Math.max(14, Math.min(H - 14, player.y));
  for (const e of enemies) {
    e.x += e.vx * dt;
    e.y += e.vy * dt;
    if (e.x < 16 || e.x > W - 16) e.vx = -e.vx;
    if (e.y < 16 || e.y > H - 16) e.vy = -e.vy;
  }
  coins = coins.filter(c => {
    if (Math.hypot(c.x - player.x, c.y - player.y) < 24) { score += 10; sound('coin'); return false; }
    return true;
  });
}

function draw(ctx) {
  for (const w of walls) {
    ctx.fillStyle = '#7A8CA8';
    ctx.fillRect(w.x - 20, w.y - 10, 40, 20);
  }
  for (const c of coins) sprite(ctx, 'coin', c.x, c.y);
  for (const e of enemies) sprite(ctx, 'enemy', e.x, e.y);
  sprite(ctx, 'player', player.x, player.y);
  ctx.fillStyle = '#fff';
  ctx.font = '15px sans-serif';
  ctx.fillText('النقاط: ' + score, 8, 22);
  ctx.fillText('الوقت: ' + Math.ceil(timeLeft), 250, 22);
}`;
  }

  // تشغيل الكود على الشاشة نفسها
  let frameCtx = null;
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
      g = new Function('ctx', 'keys', 'touch', 'W', 'H', 'sprite', 'sound', src)(ctx, keys, touch, cv.width, cv.height, sprite, sound);
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

  window.addEventListener('pointerup', () => { touch.down = false; });
  cv.addEventListener('pointerdown', e => {
    touch.down = true;
    const p = pos(e); touch.x = p.x; touch.y = p.y;
  });
  cv.addEventListener('pointermove', e => {
    if (!touch.down) return;
    const p = pos(e); touch.x = p.x; touch.y = p.y;
  });
  window.addEventListener('keydown', e => {
    keys[e.key] = true;
    if (e.key.startsWith('Arrow')) e.preventDefault();
  });
  window.addEventListener('keyup', e => { keys[e.key] = false; });

  document.getElementById('gen').onclick = () => generateCode();
  document.getElementById('run').onclick = run;
  document.getElementById('stop').onclick = () => { stop(); errEl.textContent = 'متوقفة'; };

  document.querySelector('.kind[data-kind="coin"]').classList.add('sel');
  redrawEditor();
  renderList();
  generateCode();
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
