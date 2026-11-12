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
  .item.sel { outline: 1px solid #D4AF37; }
  .props { background: #0A1F3D; border-radius: 10px; padding: 10px; margin-top: 8px; }
  .prop { display: flex; align-items: center; gap: 8px; margin-bottom: 8px; font-size: 13px; }
  .prop label { min-width: 52px; }
  .prop input[type=range] { flex: 1; }
  .prop input[type=color] { width: 46px; height: 30px; border: none; background: none; }
  .prop span { min-width: 36px; text-align: left; direction: ltr; }
  .msg { color: #ff6b6b; font-size: 13px; margin-top: 6px; min-height: 16px; direction: ltr; text-align: left; }
  .tpl { display: grid; grid-template-columns: repeat(3, 1fr); gap: 6px; }
  .tpl button { font-size: 13px; padding: 8px 2px; }
</style>
</head>
<body>
<div class="card">
  <div class="title">ألعاب جاهزة: اختر لعبة لتشغيلها مباشرة</div>
  <div class="tpl">
    <button class="alt tplBtn" data-tpl="memory">الذاكرة</button>
    <button class="alt tplBtn" data-tpl="dodge">تجنب العوائق</button>
    <button class="alt tplBtn" data-tpl="coins">جمع العملات</button>
  </div>
</div>
<div class="card">
  <div class="title">الشاشة: اختر كائناً ثم انقر على الشاشة لإضافته، أو اسحب كائناً موجوداً لتحريكه</div>
  <div class="row">
    <button class="alt kind" data-kind="player">لاعب</button>
    <button class="alt kind" data-kind="coin">عملة</button>
    <button class="alt kind" data-kind="enemy">عدو</button>
    <button class="alt kind" data-kind="wall">حاجز</button>
  </div>
  <div id="wrap" style="margin-top:8px"><canvas id="cv" width="360" height="480"></canvas></div>
  <div id="list" class="list"></div>
  <div id="props" class="props" style="display:none"></div>
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
  const propsEl = document.getElementById('props');
  const keys = {};
  const touch = { down: false, x: 0, y: 0 };
  let raf = null;
  let kind = 'coin';
  let objects = [];
  let selected = -1;
  let drag = null;
  let gameRef = null;

  const DEFAULTS = {
    player: { color: '#7CFC7C', size: 24, speed: 200 },
    coin: { color: '#D4AF37', size: 20, speed: 0 },
    enemy: { color: '#FF6B6B', size: 28, speed: 80 },
    wall: { color: '#7A8CA8', size: 40, speed: 0 }
  };
  const LABELS = { player: 'لاعب', coin: 'عملة', enemy: 'عدو', wall: 'حاجز' };

  // ===== قوالب الألعاب الجاهزة =====
  const TEMPLATES = {
    memory: `let cards, first, second, lock, moves, matched, timeLeft, state, best;
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
    ctx.fillStyle = 'rgba(0,0,0,0.6)'; ctx.fillRect(0, 0, W, H);
    ctx.fillStyle = '#D4AF37'; ctx.font = 'bold 24px sans-serif';
    ctx.fillText(state === 'win' ? 'أحسنت! أنهيت اللعبة' : 'انتهى الوقت', 70, 220);
    ctx.font = '16px sans-serif';
    ctx.fillText('الحركات: ' + moves, 135, 255);
    ctx.fillText('اضغط تشغيل للعب مرة أخرى', 40, 290);
  }
}`,
    dodge: `let player, obstacles, score, lives, spawnT, timeLeft, state, best;
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
  player.x = Math.max(player.r, Math.min(W - player.r, player.x));
  spawnT -= dt;
  if (spawnT <= 0) {
    spawnT = Math.max(0.35, 0.9 - score * 0.01);
    obstacles.push({ x: 20 + Math.random() * (W - 40), y: -20, r: 14 + Math.random() * 10, v: 140 + score * 2 });
  }
  for (const o of obstacles) o.y += o.v * dt;
  obstacles = obstacles.filter(o => {
    if (o.y > H + o.r) { score += 1; return false; }
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
    ctx.fillStyle = 'rgba(0,0,0,0.6)'; ctx.fillRect(0, 0, W, H);
    ctx.fillStyle = '#D4AF37'; ctx.font = 'bold 24px sans-serif';
    ctx.fillText('انتهت اللعبة', 95, 220);
    ctx.font = '16px sans-serif';
    ctx.fillText('نتيجتك: ' + score, 130, 255);
    ctx.fillText('اضغط تشغيل للعب مرة أخرى', 40, 290);
  }
}`,
    coins: `let player, coins, score, timeLeft, state;

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
  player.x = Math.max(player.r, Math.min(W - player.r, player.x));
  player.y = Math.max(player.r, Math.min(H - player.r, player.y));
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
    ctx.fillStyle = 'rgba(0,0,0,0.6)'; ctx.fillRect(0, 0, W, H);
    ctx.fillStyle = '#D4AF37'; ctx.font = 'bold 24px sans-serif';
    ctx.fillText('انتهى الوقت', 100, 230);
    ctx.font = '16px sans-serif';
    ctx.fillText('نتيجتك: ' + score, 130, 262);
    ctx.fillText('اضغط تشغيل للعب مرة أخرى', 40, 295);
  }
}`
  };

  function pos(e) {
    const r = cv.getBoundingClientRect();
    return { x: Math.round((e.clientX - r.left) * cv.width / r.width), y: Math.round((e.clientY - r.top) * cv.height / r.height) };
  }

  // ===== المحرر المرئي للكائنات =====
  function redrawEditor() {
    ctx2d.fillStyle = '#0A1F3D';
    ctx2d.fillRect(0, 0, cv.width, cv.height);
    objects.forEach((o, i) => {
      ctx2d.fillStyle = o.color;
      if (o.kind === 'wall') ctx2d.fillRect(o.x - o.size / 2, o.y - o.size / 4, o.size, o.size / 2);
      else { ctx2d.beginPath(); ctx2d.arc(o.x, o.y, o.size / 2, 0, Math.PI * 2); ctx2d.fill(); }
      if (i === selected) {
        ctx2d.strokeStyle = '#fff'; ctx2d.lineWidth = 2;
        ctx2d.strokeRect(o.x - o.size / 2 - 4, o.y - o.size / 2 - 4, o.size + 8, o.size + 8);
      }
    });
  }

  function renderList() {
    listEl.innerHTML = '';
    objects.forEach((o, i) => {
      const row = document.createElement('div');
      row.className = 'item' + (i === selected ? ' sel' : '');
      const label = document.createElement('span');
      label.textContent = LABELS[o.kind] + ' (' + Math.round(o.x) + ', ' + Math.round(o.y) + ')';
      label.style.cursor = 'pointer';
      label.onclick = () => { selected = i; refresh(); };
      const del = document.createElement('button');
      del.className = 'danger'; del.textContent = 'حذف';
      del.onclick = () => {
        objects.splice(i, 1);
        if (selected === i) selected = -1; else if (selected > i) selected--;
        refresh();
      };
      row.appendChild(label); row.appendChild(del);
      listEl.appendChild(row);
    });
    if (!objects.length) listEl.textContent = 'لا توجد كائنات بعد.';
  }

  function renderProps() {
    const o = objects[selected];
    if (!o) { propsEl.style.display = 'none'; propsEl.innerHTML = ''; return; }
    propsEl.style.display = 'block';
    propsEl.innerHTML = '';
    const title = document.createElement('div');
    title.className = 'title';
    title.textContent = 'خصائص: ' + LABELS[o.kind];
    propsEl.appendChild(title);
    propsEl.appendChild(sliderRow('الحجم', 10, 60, 1, o.size, v => { o.size = v; }));
    if (o.kind === 'enemy' || o.kind === 'player') propsEl.appendChild(sliderRow('السرعة', 0, 300, 10, o.speed, v => { o.speed = v; }));
    propsEl.appendChild(colorRow('اللون', o.color, v => { o.color = v; }));
  }

  function sliderRow(label, min, max, step, value, onChange) {
    const row = document.createElement('div');
    row.className = 'prop';
    const l = document.createElement('label'); l.textContent = label;
    const r = document.createElement('input');
    r.type = 'range'; r.min = min; r.max = max; r.step = step; r.value = value;
    const s = document.createElement('span'); s.textContent = Math.round(value);
    r.oninput = () => { const v = Math.round(Number(r.value)); s.textContent = v; onChange(v); redrawEditor(); generateCode(); };
    row.appendChild(l); row.appendChild(r); row.appendChild(s);
    return row;
  }

  function colorRow(label, value, onChange) {
    const row = document.createElement('div');
    row.className = 'prop';
    const l = document.createElement('label'); l.textContent = label;
    const c = document.createElement('input');
    c.type = 'color'; c.value = value;
    c.oninput = () => { onChange(c.value); redrawEditor(); generateCode(); };
    row.appendChild(l); row.appendChild(c);
    return row;
  }

  function refresh() { redrawEditor(); renderList(); renderProps(); generateCode(); }

  function hitTest(x, y) {
    for (let i = objects.length - 1; i >= 0; i--) {
      const o = objects[i];
      const half = o.size / 2 + 8;
      if (Math.abs(x - o.x) <= half && Math.abs(y - o.y) <= half) return i;
    }
    return -1;
  }

  cv.addEventListener('pointerdown', e => {
    const p = pos(e);
    const hit = hitTest(p.x, p.y);
    if (hit >= 0) { selected = hit; drag = { index: hit, moved: false }; refresh(); }
    else { drag = null; touch.down = true; touch.x = p.x; touch.y = p.y; }
  });

  cv.addEventListener('pointermove', e => {
    const p = pos(e);
    if (drag) {
      const o = objects[drag.index];
      o.x = Math.max(0, Math.min(cv.width, p.x));
      o.y = Math.max(0, Math.min(cv.height, p.y));
      drag.moved = true; redrawEditor(); return;
    }
    if (touch.down) { touch.x = p.x; touch.y = p.y; }
  });

  cv.addEventListener('pointerup', e => {
    const p = pos(e);
    if (drag) { drag = null; refresh(); return; }
    touch.down = false;
    if (gameRef && typeof gameRef.pick === 'function') {
      try { gameRef.pick(p.x, p.y); } catch (err) { errEl.textContent = 'خطأ في النقر: ' + err; }
    }
    if (kind === 'player') objects = objects.filter(o => o.kind !== 'player');
    const d = DEFAULTS[kind];
    objects.push({ kind, x: p.x, y: p.y, color: d.color, size: d.size, speed: d.speed });
    selected = objects.length - 1;
    refresh();
  });

  cv.addEventListener('pointercancel', () => { drag = null; touch.down = false; });

  document.querySelectorAll('.kind').forEach(b => {
    b.addEventListener('click', () => {
      kind = b.dataset.kind;
      document.querySelectorAll('.kind').forEach(x => x.classList.toggle('sel', x === b));
    });
  });

  // اختيار قالب جاهز: يضع كوده في الحقل ويشغّله
  document.querySelectorAll('.tplBtn').forEach(b => {
    b.addEventListener('click', () => {
      const key = b.dataset.tpl;
      codeEl.value = TEMPLATES[key];
      run();
    });
  });

  function generateCode() {
    const p = objects.find(o => o.kind === 'player');
    const px = p ? p.x : 180, py = p ? p.y : 420;
    const pspeed = p ? p.speed : 200;
    const coins = objects.filter(o => o.kind === 'coin').map(o => `{ x: ${o.x}, y: ${o.y}, r: ${o.size / 2} }`);
    const enemies = objects.filter(o => o.kind === 'enemy').map(o => `{ x: ${o.x}, y: ${o.y}, r: ${o.size / 2}, vx: ${o.speed}, vy: ${Math.round(o.speed * 0.7)}, color: "${o.color}" }`);
    const walls = objects.filter(o => o.kind === 'wall').map(o => `{ x: ${o.x}, y: ${o.y}, w: ${o.size}, h: ${Math.round(o.size / 2)}, color: "${o.color}" }`);
    codeEl.value = `let player, coins, enemies, walls, score, timeLeft, state;

function setup() {
  player = { x: ${px}, y: ${py}, speed: ${pspeed}, r: ${p ? p.size / 2 : 12}, color: "${p ? p.color : '#7CFC7C'}" };
  coins = [${coins.join(', ')}];
  enemies = [${enemies.join(', ')}];
  walls = [${walls.join(', ')}];
  score = 0;
  timeLeft = 30;
  state = 'play';
}

function update(dt) {
  if (state !== 'play') return;
  timeLeft = Math.max(0, timeLeft - dt);
  if (timeLeft <= 0) { state = 'timeup'; return; }
  const s = player.speed * dt;
  if (keys.ArrowLeft) player.x -= s;
  if (keys.ArrowRight) player.x += s;
  if (keys.ArrowUp) player.y -= s;
  if (keys.ArrowDown) player.y += s;
  if (touch.down) { player.x += (touch.x - player.x) * 0.1; player.y += (touch.y - player.y) * 0.1; }
  player.x = Math.max(player.r, Math.min(W - player.r, player.x));
  player.y = Math.max(player.r, Math.min(H - player.r, player.y));
  for (const e of enemies) {
    e.x += e.vx * dt; e.y += e.vy * dt;
    if (e.x < e.r || e.x > W - e.r) e.vx = -e.vx;
    if (e.y < e.r || e.y > H - e.r) e.vy = -e.vy;
  }
  coins = coins.filter(c => {
    if (Math.hypot(c.x - player.x, c.y - player.y) < c.r + player.r) { score += 10; return false; }
    return true;
  });
}

function draw(ctx) {
  for (const w of walls) { ctx.fillStyle = w.color; ctx.fillRect(w.x - w.w / 2, w.y - w.h / 2, w.w, w.h); }
  ctx.fillStyle = '#D4AF37';
  for (const c of coins) { ctx.beginPath(); ctx.arc(c.x, c.y, c.r, 0, Math.PI * 2); ctx.fill(); }
  for (const e of enemies) { ctx.fillStyle = e.color; ctx.beginPath(); ctx.arc(e.x, e.y, e.r, 0, Math.PI * 2); ctx.fill(); }
  ctx.fillStyle = player.color;
  ctx.beginPath(); ctx.arc(player.x, player.y, player.r, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = '#fff'; ctx.font = '15px sans-serif';
  ctx.fillText('النقاط: ' + score, 8, 22);
  ctx.fillText('الوقت: ' + Math.ceil(timeLeft), 250, 22);
  if (state === 'timeup') {
    ctx.fillStyle = 'rgba(0,0,0,0.6)'; ctx.fillRect(0, 0, W, H);
    ctx.fillStyle = '#D4AF37'; ctx.font = 'bold 24px sans-serif';
    ctx.fillText('انتهى الوقت', 100, 230);
    ctx.font = '16px sans-serif';
    ctx.fillText('نتيجتك: ' + score, 130, 262);
  }
}`;
  }

  function stop() { if (raf) cancelAnimationFrame(raf); raf = null; }

  function run() {
    stop();
    errEl.textContent = '';
    const ctx = cv.getContext('2d');
    let g;
    try {
      const src = codeEl.value + '\n;return { setup: typeof setup === "function" ? setup : null, update: typeof update === "function" ? update : null, draw: typeof draw === "function" ? draw : null, pick: typeof pick === "function" ? pick : null };';
      g = new Function('ctx', 'keys', 'touch', 'W', 'H', 'sprite', 'sound', src)(ctx, keys, touch, cv.width, cv.height, () => {}, () => {});
      gameRef = g;
      if (g.setup) g.setup();
    } catch (e) { errEl.textContent = 'خطأ في الكود: ' + e; return; }
    let last = performance.now();
    function frame(now) {
      const dt = Math.min(0.05, (now - last) / 1000);
      last = now;
      try {
        if (g.update) g.update(dt);
        ctx.fillStyle = '#0A1F3D';
        ctx.fillRect(0, 0, cv.width, cv.height);
        if (g.draw) g.draw(ctx);
      } catch (e) { errEl.textContent = 'خطأ أثناء التشغيل: ' + e; raf = null; return; }
      raf = requestAnimationFrame(frame);
    }
    raf = requestAnimationFrame(frame);
  }

  window.addEventListener('keydown', e => { keys[e.key] = true; if (e.key.startsWith('Arrow')) e.preventDefault(); });
  window.addEventListener('keyup', e => { keys[e.key] = false; });

  document.getElementById('gen').onclick = generateCode;
  document.getElementById('run').onclick = run;
  document.getElementById('stop').onclick = () => { stop(); errEl.textContent = 'متوقفة'; };

  document.querySelector('.kind[data-kind="coin"]').classList.add('sel');
  refresh();
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
