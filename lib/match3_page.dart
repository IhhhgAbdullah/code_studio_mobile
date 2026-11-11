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
  .stats { display: flex; justify-content: space-between; font-size: 14px; margin-bottom: 8px; }
  #board { display: grid; grid-template-columns: repeat(8, 1fr); gap: 3px; width: 100%; touch-action: none; user-select: none; }
  .cell { aspect-ratio: 1 / 1; border-radius: 10px; background: #0A1F3D; display: flex;
    align-items: center; justify-content: center; font-size: 22px; }
  .cell.sel { outline: 3px solid #fff; }
  button { width: 100%; padding: 12px; font-size: 15px; border: none; border-radius: 10px;
    background: #D4AF37; color: #0D2B52; font-weight: bold; margin-top: 8px; }
  .msg { color: #D4AF37; font-size: 13px; margin-top: 8px; min-height: 18px; text-align: center; }
</style>
</head>
<body>
<div class="card">
  <div class="title">Match-3: بدّل قطعتين متجاورتين لتكوين 3 أو أكثر من اللون نفسه</div>
  <div class="stats">
    <span id="score">النقاط: 0</span>
    <span id="moves">الحركات: 20</span>
    <span id="goal">الهدف: 500</span>
  </div>
  <div id="board"></div>
  <button id="restart">لعبة جديدة</button>
  <div id="msg" class="msg"></div>
</div>
<script>
  const N = 8;
  const COLORS = ['#FF6B6B', '#4DD0E1', '#FFD54F', '#81C784', '#BA68C8', '#FF8A65'];
  const MAX_MOVES = 20;
  const GOAL = 500;

  let grid = [];
  let score = 0;
  let moves = MAX_MOVES;
  let sel = null;
  let busy = false;
  let over = false;

  const boardEl = document.getElementById('board');
  const scoreEl = document.getElementById('score');
  const movesEl = document.getElementById('moves');
  const goalEl = document.getElementById('goal');
  const msgEl = document.getElementById('msg');

  function rnd(n) { return Math.floor(Math.random() * n); }

  function newGrid() {
    const g = [];
    for (let r = 0; r < N; r++) {
      g.push([]);
      for (let c = 0; c < N; c++) {
        let v;
        do { v = rnd(COLORS.length); }
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
    for (let r = 0; r < N; r++) for (let c = 0; c < N; c++) if (hit[r][c]) any = true;
    return { hit, any };
  }

  // إزالة المجموعات وإسقاط القطع وتعبئة الفراغات، ثم إعادة التحقق
  function resolve(done) {
    const m = findMatches(grid);
    if (!m.any) { done(); return; }
    let cleared = 0;
    for (let r = 0; r < N; r++) for (let c = 0; c < N; c++) {
      if (m.hit[r][c]) { grid[r][c] = -1; cleared++; }
    }
    score += cleared * 10;
    render();
    setTimeout(() => {
      for (let c = 0; c < N; c++) {
        let write = N - 1;
        for (let r = N - 1; r >= 0; r--) {
          if (grid[r][c] >= 0) { grid[write][c] = grid[r][c]; write--; }
        }
        for (let r = write; r >= 0; r--) grid[r][c] = rnd(COLORS.length);
      }
      render();
      setTimeout(() => resolve(done), 180);
    }, 180);
  }

  function render() {
    boardEl.innerHTML = '';
    for (let r = 0; r < N; r++) for (let c = 0; c < N; c++) {
      const d = document.createElement('div');
      d.className = 'cell' + (sel && sel.r === r && sel.c === c ? ' sel' : '');
      const v = grid[r][c];
      d.style.background = v >= 0 ? COLORS[v] : '#0A1F3D';
      d.dataset.r = r; d.dataset.c = c;
      boardEl.appendChild(d);
    }
    scoreEl.textContent = 'النقاط: ' + score;
    movesEl.textContent = 'الحركات: ' + moves;
    goalEl.textContent = 'الهدف: ' + GOAL;
  }

  function adjacent(a, b) {
    return Math.abs(a.r - b.r) + Math.abs(a.c - b.c) === 1;
  }

  function swap(a, b) {
    const t = grid[a.r][a.c];
    grid[a.r][a.c] = grid[b.r][b.c];
    grid[b.r][b.c] = t;
  }

  function endCheck() {
    if (score >= GOAL) { over = true; msgEl.textContent = 'فزت! وصلت إلى الهدف'; }
    else if (moves <= 0) { over = true; msgEl.textContent = 'انتهت الحركات. النتيجة: ' + score; }
  }

  function tryMove(a, b) {
    busy = true;
    swap(a, b);
    const m = findMatches(grid);
    if (!m.any) {
      // لا توجد مجموعة: نرجع القطع إلى مكانها
      setTimeout(() => { swap(a, b); render(); busy = false; }, 200);
      msgEl.textContent = 'لا توجد مجموعة في هذه الحركة';
      render();
      return;
    }
    moves--;
    msgEl.textContent = '';
    render();
    resolve(() => {
      busy = false;
      render();
      endCheck();
    });
  }

  function cellFromEvent(e) {
    const t = e.target.closest('.cell');
    if (!t) return null;
    return { r: Number(t.dataset.r), c: Number(t.dataset.c) };
  }

  // اللمس: الضغط على قطعة ثم سحب إلى المجاورة (أو نقرتان)
  let start = null;
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
      // نقرة: تحديد أو إلغاء
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

  document.getElementById('restart').onclick = () => {
    grid = newGrid();
    score = 0;
    moves = MAX_MOVES;
    sel = null;
    busy = false;
    over = false;
    msgEl.textContent = '';
    render();
  };

  grid = newGrid();
  render();
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
