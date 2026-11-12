import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String _puzzleHtml = r'''
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
  #grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 6px; width: 100%; max-width: 320px; margin: 0 auto; }
  .cell { aspect-ratio: 1 / 1; border-radius: 10px; background: #0A1F3D; display: flex; align-items: center;
    justify-content: center; font-size: 26px; font-weight: bold; color: #fff; border: 2px solid transparent; }
  .cell.fixed { color: #D4AF37; }
  .cell.empty { color: #cfd8e6; }
  .cell.sel { border-color: #fff; }
  .cell.bad { background: #5a1f1f; color: #ff6b6b; }
  .cell.ok { background: #1f4a2a; }
  .pad { display: grid; grid-template-columns: repeat(4, 1fr); gap: 6px; max-width: 320px; margin: 10px auto 0; }
  button { padding: 12px; font-size: 16px; border: none; border-radius: 10px;
    background: #D4AF37; color: #0D2B52; font-weight: bold; width: 100%; }
  button.alt { background: #2A4A7A; color: #fff; }
  button.num { padding: 14px 0; }
  .row { display: flex; gap: 8px; margin-top: 10px; }
  .row > * { flex: 1; }
  .msg { color: #D4AF37; font-size: 14px; margin-top: 10px; min-height: 20px; text-align: center; }
  .stats { font-size: 13px; text-align: center; margin-top: 6px; color: #cfd8e6; }
</style>
</head>
<body>
<div class="card">
  <div class="title">ألغاز الأرقام 4×4: املأ كل خانة بالرقم من 1 إلى 4، بدون تكرار في الصف أو العمود أو المربع 2×2</div>
  <div id="grid"></div>
  <div class="pad" id="pad"></div>
  <div class="row">
    <button id="check" class="alt">تحقق</button>
    <button id="clear" class="alt">مسح الخانة</button>
    <button id="newp">مرحلة جديدة</button>
  </div>
  <div class="stats" id="stats"></div>
  <div class="msg" id="msg"></div>
</div>
<script>
  const N = 4;
  // حلول جاهزة صحيحة؛ نبدأ من أحدها ونخلط الأرقام والصفوف ونحذف بعض الخانات
  const SOLUTIONS = [
    [[1,2,3,4],[3,4,1,2],[2,1,4,3],[4,3,2,1]],
    [[2,4,1,3],[1,3,2,4],[4,2,3,1],[3,1,4,2]],
    [[3,1,4,2],[4,2,3,1],[1,3,2,4],[2,4,1,3]]
  ];
  const HIDE = 9;

  let solution = [];
  let board = [];
  let fixed = [];
  let sel = null;
  let solved = false;

  const gridEl = document.getElementById('grid');
  const padEl = document.getElementById('pad');
  const msgEl = document.getElementById('msg');
  const statsEl = document.getElementById('stats');

  function rnd(n) { return Math.floor(Math.random() * n); }

  function shuffled(arr) {
    const a = arr.slice();
    for (let i = a.length - 1; i > 0; i--) {
      const j = rnd(i + 1);
      const t = a[i]; a[i] = a[j]; a[j] = t;
    }
    return a;
  }

  // تبديل عشوائي للأرقام: نفس الحل بأرقام مختلفة يبقى صحيحاً
  function newPuzzle() {
    const base = SOLUTIONS[rnd(SOLUTIONS.length)];
    const map = shuffled([1, 2, 3, 4]);
    solution = base.map(row => row.map(v => map[v - 1]));

    const cells = [];
    for (let r = 0; r < N; r++) for (let c = 0; c < N; c++) cells.push([r, c]);
    const hidden = shuffled(cells).slice(0, HIDE);

    board = solution.map(row => row.slice());
    fixed = Array.from({ length: N }, () => Array(N).fill(true));
    for (const [r, c] of hidden) {
      board[r][c] = 0;
      fixed[r][c] = false;
    }
    sel = null;
    solved = false;
    msgEl.textContent = '';
    render();
  }

  function render() {
    gridEl.innerHTML = '';
    for (let r = 0; r < N; r++) for (let c = 0; c < N; c++) {
      const d = document.createElement('div');
      const v = board[r][c];
      let cls = 'cell ' + (fixed[r][c] ? 'fixed' : 'empty');
      if (sel && sel.r === r && sel.c === c) cls += ' sel';
      d.className = cls;
      d.textContent = v ? v : '';
      d.dataset.r = r; d.dataset.c = c;
      d.onclick = () => {
        if (solved) return;
        sel = { r, c };
        render();
      };
      gridEl.appendChild(d);
    }
    renderPad();
    statsEl.textContent = 'الخانات الفارغة: ' + countEmpty();
  }

  function renderPad() {
    padEl.innerHTML = '';
    for (let n = 1; n <= N; n++) {
      const b = document.createElement('button');
      b.className = 'num';
      b.textContent = n;
      b.onclick = () => setValue(n);
      padEl.appendChild(b);
    }
  }

  function countEmpty() {
    let k = 0;
    for (let r = 0; r < N; r++) for (let c = 0; c < N; c++) if (!fixed[r][c] && board[r][c] === 0) k++;
    return k;
  }

  function setValue(n) {
    if (solved) return;
    if (!sel) { msgEl.textContent = 'اختر خانة فارغة أولاً'; return; }
    if (fixed[sel.r][sel.c]) { msgEl.textContent = 'هذه الخانة ثابتة'; return; }
    board[sel.r][sel.c] = n;
    msgEl.textContent = '';
    render();
    if (countEmpty() === 0) checkWin();
  }

  function checkWin() {
    let ok = true;
    for (let r = 0; r < N; r++) for (let c = 0; c < N; c++) {
      if (board[r][c] !== solution[r][c]) ok = false;
    }
    if (ok) {
      solved = true;
      sel = null;
      msgEl.textContent = 'أحسنت! حللت اللغز';
      render();
    } else {
      msgEl.textContent = 'توجد أخطاء، اضغط تحقق لترى أين';
    }
  }

  // تحقق: نعرض الخانات الخاطئة بالأحمر والصحيحة بالأخضر
  function checkAll() {
    let wrong = 0;
    const cells = gridEl.querySelectorAll('.cell');
    cells.forEach(d => {
      const r = Number(d.dataset.r), c = Number(d.dataset.c);
      if (fixed[r][c]) return;
      if (board[r][c] === 0) return;
      if (board[r][c] === solution[r][c]) d.classList.add('ok');
      else { d.classList.add('bad'); wrong++; }
    });
    msgEl.textContent = wrong ? 'هناك ' + wrong + ' خانة خاطئة (باللون الأحمر)' : 'كل ما أدخلته صحيح حتى الآن';
    setTimeout(render, 1200);
  }

  document.getElementById('check').onclick = () => { if (!solved) checkAll(); };
  document.getElementById('clear').onclick = () => {
    if (solved || !sel || fixed[sel.r][sel.c]) return;
    board[sel.r][sel.c] = 0;
    render();
  };
  document.getElementById('newp').onclick = newPuzzle;

  newPuzzle();
</script>
</body>
</html>
''';

class PuzzlePage extends StatefulWidget {
  const PuzzlePage({super.key});

  @override
  State<PuzzlePage> createState() => _PuzzlePageState();
}

class _PuzzlePageState extends State<PuzzlePage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(_puzzleHtml, baseUrl: 'https://localhost/');
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
