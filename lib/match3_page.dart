import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String _match3Html = r'''
<!DOCTYPE html>
<html dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
<style>
  * { box-sizing: border-box; }
  body { margin: 0; padding: 10px; background: #0D2B52; color: #fff; font-family: sans-serif; }
  .card { background: #132F5A; border: 1px solid #D4AF37; border-radius: 14px; padding: 10px; margin-bottom: 10px; }
  .title { color: #D4AF37; font-weight: bold; font-size: 14px; margin-bottom: 8px; }
  .stats { display: flex; justify-content: space-between; font-size: 13px; margin-bottom: 8px; }
  #wrap { position: relative; width: 100%; }
  #board { display: grid; grid-template-columns: repeat(8, 1fr); gap: 3px; width: 100%; touch-action: none; user-select: none; }
  .cell { aspect-ratio: 1 / 1; border-radius: 10px; background: #0A1F3D; transition: transform 0.15s ease, opacity 0.15s ease; }
  .cell.sel { outline: 3px solid #fff; }
  .cell.pop { transform: scale(0.1); opacity: 0; }
  .cell.fall { animation: fall 0.18s ease-out; }
  @keyframes fall { from { transform: translateY(-30%); opacity: 0.6; } to { transform: none; opacity: 1; } }
  .floater { position: absolute; color: #D4AF37; font-weight: bold; font-size: 16px; pointer-events: none;
    transform: translate(-50%, -50%); animation: rise 0.7s ease-out forwards; text-shadow: 0 1px 2px #000; }
  @keyframes rise { from { opacity: 1; margin-top: 0; } to { opacity: 0; margin-top: -30px; } }
  button { width: 100%; padding: 12px; font-size: 15px; border: none; border-radius: 10px;
    background: #D4AF37; color: #0D2B52; font-weight: bold; margin-top: 8px; }
  button.alt { background: #2A4A7A; color: #fff; }
  button.mute { background: #2A4A7A; color: #fff; }
  .levels { display: grid; grid-template-columns: repeat(5, 1fr); gap: 6px; margin-top: 8px; }
  .lv { padding: 8px 0; border-radius: 8px; background: #0A1F3D; text-align: center; font-size: 14px; }
  .lv.open { color: #D4AF37; border: 1px solid #D4AF37; }
  .lv.lock { color: #556; }
  .lv.cur { background: #D4AF37; color: #0D2B52; font-weight: bold; }
  .msg { color: #D4AF37; font-size: 14px; margin-top: 8px; min-height: 20px; text-align: center; }
</style>
</head>
<body>
<div class="card">
  <div class="title">Match-3: بدّل قطعتين متجاورتين لتكوين 3 أو أكثر من اللون نفسه</div>
  <div class="stats">
    <span id="lvl">المرحلة 1</span>
    <span id="score">النقاط: 0</span>
    <span id="moves">الحركات: 0</span>
    <span id="goal">الهدف: 0</span>
  </div>
  <div id="wrap">
    <div id="board"></div>
  </div>
  <div class="msg" id="msg"></div>
  <button id="next" style="display:none">المرحلة التالية</button>
  <button id="restart" class="alt">إعادة المرحلة</button>
  <button id="mute" class="mute">الصوت: مفعّل</button>
</div>
<div class="card">
  <div class="title">اختيار المرحلة</div>
  <div class="levels" id="levels"></div>
</div>
<script>
  const N = 8;
  const ALL_COLORS = ['#FF6B6B', '#4DD0E1', '#FFD54F', '#81C784', '#BA68C8', '#FF8A65'];
  const KEY = 'cs_match3_best';

  const LEVELS = [
    { goal: 300, moves: 20, colors: 3 },
    { goal: 400, moves: 20, colors: 3 },
    { goal: 500, moves: 20, colors: 4 },
    { goal: 600, moves: 19, colors: 4 },
    { goal: 700, moves: 18, colors: 4 },
    { goal: 800, moves: 18, colors: 5 },
    { goal: 900, moves: 17, colors: 5 },
    { goal: 1000, moves: 16, colors: 5 },
    { goal: 1100, moves: 15, colors: 6 },
    { goal: 1300, moves: 14, colors: 6 }
  ];

  // ===== الأصوات المولّدة =====
  let audioCtx = null;
  let muted = false;
  function beep(freq, dur, type, vol) {
    if (muted) return;
    try {
      if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
      const o = audioCtx.createOscillator();
      const g = audioCtx.createGain();
      o.type = type || 'sine';
      o.frequency.value = freq;
      g.gain.value = vol || 0.08;
      o.connect(g); g.connect(audioCtx.destination);
      o.start();
      o.stop(audioCtx.currentTime + dur);
    } catch (e) {}
  }
  const SFX = {
    swap: () => beep(330, 0.06, 'triangle', 0.06),
    bad: () => beep(160, 0.15, 'sawtooth', 0.05),
    match: (n) => beep(520 + Math.min(n, 8) * 60, 0.09, 'sine', 0.09),
    fall: () => beep(220, 0.07, 'triangle', 0.04),
    win: () => { beep(523, 0.12, 'triangle', 0.1); setTimeout(() => beep(659, 0.12, 'triangle', 0.1), 120); setTimeout(() => beep(784, 0.25, 'triangle', 0.1), 240); },
    lose: () => { beep(330, 0.2, 'sawtooth', 0.07); setTimeout(() => beep(220, 0.35, 'sawtooth', 0.07), 200); }
  };

  let level = 0;
  let grid = [];
  let score = 0;
  let moves = 0;
  let sel = null;
  let busy = false;
  let over = false;
  let start = null;

  const boardEl = document.getElementById('board');
  const wrapEl = document.getElementById('wrap');
  const msgEl = document.getElementById('msg');
  const nextBtn = document.getElementById('next');
  const muteBtn = document.getElementById('mute');

  muteBtn.onclick = () => {
    muted = !muted;
    muteBtn.textContent = muted ? 'الصوت: متوقف' : 'الصوت: مفعّل';
  };

  function getUnlocked() {
    return Number(localStorage.getItem(KEY) || 1);
  }
  function setUnlocked(n) {
    try { localStorage.setItem(KEY, String(n)); } catch (e) {}
  }

  function rnd(n) { return Math.floor(Math.random() * n); }
  function colorCount() { return LEVELS[level].colors; }

  function newGrid() {
    const k = colorCount();
    const g = [];
    for (let r = 0; r < N; r++) {
      g.push([]);
      for (let c = 0; c < N; c++) {
        let v;
        do { v = rnd(k); }
        while ((c >= 2 && g[r][c - 1] === v && g[r][c - 2] === v) ||
               (r >= 2 && g[r - 1][c] === v && g[r - 2][c] === v));
        g[r].push(v);
      }
    }
    return g;
  }

  function findMatches(g) {
    const hit = Array.from({ length: N }, () => Array(N).fill(false));
    for (let r = 0; r < N; r++) {
      for (let c = 0; c < N - 2; c++) {
        const v = g[r][c];
        if (v >= 0 && v === g[r][c + 1] && v === g[r][c + 2]) {
          let e = c;
          while (e + 1 < N && g[r][e + 1] === v) e++;
          for (let k = c; k <= e; k++) hit[r][k] = true;
          c = e;
        }
      }
    }
    for (let c = 0; c < N; c++) {
      for (let r = 0; r < N - 2; r++) {
        const v = g[r][c];
        if (v >= 0 && v === g[r + 1][c] && v === g[r + 2][c]) {
          let e = r;
          while (e + 1 < N && g[e + 1][c] === v) e++;
          for (let k = r; k <= e; k++) hit[k][c] = true;
          r = e;
        }
      }
    }
    let any = false;
    let count = 0;
    for (let r = 0; r < N; r++) for (let c = 0; c < N; c++) if (hit[r][c]) { any = true; count++; }
    return { hit, any, count };
  }

  // عرض الشبكة مع الحفاظ على كل شيء في مكانه
  function cellEl(r, c) {
    return boardEl.querySelector('.cell[data-r="' + r + '"][data-c="' + c + '"]');
  }

  function render(fallRows) {
    boardEl.innerHTML = '';
    for (let r = 0; r < N; r++) for (let c = 0; c < N; c++) {
      const d = document.createElement('div');
      d.className = 'cell' + (sel && sel.r === r && sel.c === c ? ' sel' : '');
      const v = grid[r][c];
      d.style.background = v >= 0 ? ALL_COLORS[v] : '#0A1F3D';
      d.dataset.r = r; d.dataset.c = c;
      if (fallRows && fallRows.has(r + ',' + c)) d.classList.add('fall');
      boardEl.appendChild(d);
    }
    document.getElementById('lvl').textContent = 'المرحلة ' + (level + 1);
    document.getElementById('score').textContent = 'النقاط: ' + score;
    document.getElementById('moves').textContent = 'الحركات: ' + moves;
    document.getElementById('goal').textContent = 'الهدف: ' + LEVELS[level].goal;
    renderLevels();
  }

  // نقاط تظهر فوق مجموعة مع تأثير الصعود
  function floatText(r, c, text) {
    const cell = cellEl(r, c);
    if (!cell) return;
    const rect = cell.getBoundingClientRect();
    const wrap = wrapEl.getBoundingClientRect();
    const f = document.createElement('div');
    f.className = 'floater';
    f.textContent = text;
    f.style.left = (rect.left + rect.width / 2 - wrap.left) + 'px';
    f.style.top = (rect.top + rect.height / 2 - wrap.top) + 'px';
    wrapEl.appendChild(f);
    setTimeout(() => f.remove(), 800);
  }

  function resolve(done, combo) {
    const m = findMatches(grid);
    if (!m.any) { done(); return; }
    SFX.match(combo);
    // تأثير التكبير والتلاشي للقطع المحذوفة
    for (let r = 0; r < N; r++) for (let c = 0; c < N; c++) {
      if (m.hit[r][c]) {
        const el = cellEl(r, c);
        if (el) el.classList.add('pop');
      }
    }
    const pts = m.count * 10 * combo;
    let first = null;
    for (let r = 0; r < N; r++) for (let c = 0; c < N; c++) {
      if (m.hit[r][c]) { grid[r][c] = -1; if (!first) first = [r, c]; }
    }
    score += pts;
    if (first) floatText(first[0], first[1], '+' + pts);
    setTimeout(() => {
      const k = colorCount();
      const moved = new Set();
      for (let c = 0; c < N; c++) {
        let write = N - 1;
        for (let r = N - 1; r >= 0; r--) {
          if (grid[r][c] >= 0) {
            if (write !== r) moved.add(write + ',' + c);
            grid[write][c] = grid[r][c];
            write--;
          }
        }
        for (let r = write; r >= 0; r--) {
          grid[r][c] = rnd(k);
          moved.add(r + ',' + c);
        }
      }
      SFX.fall();
      render(moved);
      setTimeout(() => resolve(done, combo + 1), 220);
    }, 180);
  }

  function hasMove() {
    for (let r = 0; r < N; r++) for (let c = 0; c < N; c++) {
      const pairs = [[r, c + 1], [r + 1, c]];
      for (const [r2, c2] of pairs) {
        if (r2 >= N || c2 >= N) continue;
        swapRaw(grid, r, c, r2, c2);
        const ok = findMatches(grid).any;
        swapRaw(grid, r, c, r2, c2);
        if (ok) return true;
      }
    }
    return false;
  }
  function swapRaw(g, r1, c1, r2, c2) {
    const t = g[r1][c1]; g[r1][c1] = g[r2][c2]; g[r2][c2] = t;
  }
  function reshuffle() {
    grid = newGrid();
    while (!hasMove()) grid = newGrid();
  }

  function renderLevels() {
    const box = document.getElementById('levels');
    const unlocked = getUnlocked();
    box.innerHTML = '';
    LEVELS.forEach((_, i) => {
      const d = document.createElement('div');
      const isOpen = i + 1 <= unlocked;
      d.className = 'lv ' + (i === level ? 'cur' : (isOpen ? 'open' : 'lock'));
      d.textContent = i + 1;
      if (isOpen) d.onclick = () => startLevel(i);
      box.appendChild(d);
    });
  }

  function startLevel(i) {
    level = i;
    score = 0;
    moves = LEVELS[i].moves;
    sel = null;
    busy = false;
    over = false;
    nextBtn.style.display = 'none';
    msgEl.textContent = '';
    reshuffle();
    render();
  }

  function adjacent(a, b) {
    return Math.abs(a.r - b.r) + Math.abs(a.c - b.c) === 1;
  }

  function endCheck() {
    const L = LEVELS[level];
    if (score >= L.goal) {
      over = true;
      SFX.win();
      msgEl.textContent = 'أحسنت! اجتزت المرحلة ' + (level + 1);
      if (level + 1 < LEVELS.length) {
        if (getUnlocked() <= level + 1) setUnlocked(level + 2);
        nextBtn.style.display = 'block';
      } else {
        msgEl.textContent = 'أنهيت كل المراحل! نتيجتك النهائية: ' + score;
      }
      renderLevels();
    } else if (moves <= 0) {
      over = true;
      SFX.lose();
      msgEl.textContent = 'انتهت الحركات. تحتاج ' + (L.goal - score) + ' نقطة إضافية';
    }
  }

  function tryMove(a, b) {
    busy = true;
    SFX.swap();
    swapRaw(grid, a.r, a.c, b.r, b.c);
    const m = findMatches(grid);
    if (!m.any) {
      SFX.bad();
      render();
      msgEl.textContent = 'لا توجد مجموعة في هذه الحركة';
      setTimeout(() => {
        swapRaw(grid, a.r, a.c, b.r, b.c);
        render();
        busy = false;
      }, 220);
      return;
    }
    moves--;
    msgEl.textContent = '';
    render();
    resolve(() => {
      if (!hasMove()) reshuffle();
      busy = false;
      render();
      endCheck();
    }, 1);
  }

  function cellFromEvent(e) {
    const t = e.target.closest('.cell');
    if (!t) return null;
    return { r: Number(t.dataset.r), c: Number(t.dataset.c) };
  }

  boardEl.addEventListener('pointerdown', e => {
    if (busy || over) return;
    start = cellFromEvent(e);
  });
  boardEl.addEventListener('pointerup', e => {
    if (busy || over || !start) return;
    const end = cellFromEvent(e);
    const from = start;
    start = null;
    if (!end) return;
    if (end.r === from.r && end.c === from.c) {
      if (sel && sel.r === from.r && sel.c === from.c) sel = null;
      else if (sel && adjacent(sel, from)) { const a = sel; sel = null; tryMove(a, from); return; }
      else sel = from;
      render();
      return;
    }
    if (adjacent(from, end)) {
      sel = null;
      tryMove(from, end);
    }
  });

  nextBtn.onclick = () => startLevel(level + 1);
  document.getElementById('restart').onclick = () => startLevel(level);

  startLevel(0);
</script>
</body>
</html>
''';

class Match3Page extends StatefulWidget {
  const Match3Page({super.key});

  @override
  State<Match3Page> createState() => _Match3PageState();
}

class _Match3PageState extends State<Match3Page> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(_match3Html, baseUrl: 'https://localhost/');
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
