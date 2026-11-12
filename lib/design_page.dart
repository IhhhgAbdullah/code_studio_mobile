import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String _designHtml = r'''
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
  .modes { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; }
  .palette { display: grid; grid-template-columns: repeat(2, 1fr); gap: 6px; }
  button { padding: 10px 4px; font-size: 13px; border: none; border-radius: 10px;
    background: #2A4A7A; color: #fff; font-weight: bold; }
  button.danger { background: #8B2A2A; }
  button.gold { background: #D4AF37; color: #0D2B52; }
  button:disabled { opacity: 0.4; }
  .row { display: flex; gap: 8px; margin-top: 8px; }
  .row > * { flex: 1; }
  #phone { position: relative; width: 240px; height: 420px; margin: 0 auto; background: #0A1F3D;
    border: 3px solid #D4AF37; border-radius: 28px; overflow: hidden; touch-action: none; }
  .el { position: absolute; display: flex; align-items: center; justify-content: center;
    border-radius: 8px; cursor: move; user-select: none; font-size: 14px; }
  .el.sel { outline: 2px solid #fff; }
  .el .tag { position: absolute; top: -10px; right: -4px; font-size: 10px; background: #fff; color: #0D2B52;
    border-radius: 6px; padding: 1px 5px; }
  .prop { display: flex; align-items: center; gap: 8px; margin-top: 8px; font-size: 13px; }
  .prop label { min-width: 60px; }
  .prop input[type=range] { flex: 1; }
  .prop input[type=color] { width: 46px; height: 30px; border: none; background: none; }
  input[type=text], select { width: 100%; padding: 8px; border-radius: 8px; border: 1px solid #D4AF37;
    background: #0A1F3D; color: #fff; font-size: 14px; }
  textarea { width: 100%; height: 180px; background: #0A1F3D; color: #e6edf7; border: none;
    border-radius: 10px; padding: 10px; font-family: monospace; font-size: 12px; direction: ltr; margin-top: 8px; }
  .hint { font-size: 12px; color: #cfd8e6; margin-top: 8px; text-align: right; }
  .msg { color: #D4AF37; font-size: 13px; margin-top: 6px; min-height: 16px; text-align: right; }
</style>
</head>
<body>
<div class="card">
  <div class="modes">
    <button class="gold mode" data-mode="app">شاشات التطبيق</button>
    <button class="mode" data-mode="game">واجهة اللعبة</button>
  </div>
</div>
<div class="card">
  <div class="title" id="paletteTitle">لوحة العناصر: اختر عنصراً ثم انقر على الشاشة لإضافته</div>
  <div class="palette" id="palette"></div>
</div>
<div class="card">
  <div id="phone"></div>
  <div class="hint">اسحب العنصر لتحريكه. انقر عليه لتحديده وتعديل خصائصه.</div>
  <div class="row">
    <button id="delsel" class="danger" disabled>حذف المحدد</button>
    <button id="clear" class="danger">حذف الكل</button>
  </div>
</div>
<div class="card" id="props" style="display:none">
  <div class="title">خصائص العنصر</div>
  <div class="prop" id="textRow">
    <label>النص</label>
    <input type="text" id="ptext">
  </div>
  <div class="prop">
    <label>اللون</label>
    <input type="color" id="pcolor">
  </div>
  <div class="prop">
    <label>الحجم</label>
    <input type="range" id="psize" min="40" max="200" step="2" value="100">
    <span id="psizeOut">100%</span>
  </div>
</div>
<div class="card">
  <div class="title">حفظ التصميم وفتحه</div>
  <input type="text" id="sname" placeholder="اسم التصميم (مثال: شاشة_الرئيسية)">
  <div class="row">
    <button id="save" class="gold">حفظ التصميم</button>
    <button id="load">فتح المحدد</button>
  </div>
  <select id="designs" style="margin-top:8px"></select>
  <div class="row">
    <button id="delds" class="danger">حذف المحفوظ</button>
  </div>
  <div class="msg" id="msg"></div>
</div>
<div class="card">
  <div class="title">تصدير كود Flutter</div>
  <button id="export" class="gold">توليد الكود من التصميم</button>
  <textarea id="code" placeholder="الكود يظهر هنا، انسخه إلى مشروعك"></textarea>
</div>
<script>
  const DKEY = 'cs_designs';
  const W = 240, H = 420;
  const phone = document.getElementById('phone');
  const propsEl = document.getElementById('props');
  const ptext = document.getElementById('ptext');
  const pcolor = document.getElementById('pcolor');
  const psize = document.getElementById('psize');
  const psizeOut = document.getElementById('psizeOut');
  const delsel = document.getElementById('delsel');
  const textRow = document.getElementById('textRow');
  const msgEl = document.getElementById('msg');
  const codeEl = document.getElementById('code');
  const paletteEl = document.getElementById('palette');
  const paletteTitle = document.getElementById('paletteTitle');

  // عناصر وضع التطبيق
  const APP_KINDS = {
    button: { label: 'زر', w: 140, h: 44, text: 'زر', color: '#D4AF37', fg: '#0D2B52' },
    text:   { label: 'نص', w: 150, h: 30, text: 'نص', color: 'transparent', fg: '#ffffff' },
    input:  { label: 'مربع إدخال', w: 180, h: 40, text: 'اكتب هنا', color: '#132F5A', fg: '#cfd8e6' },
    image:  { label: 'صورة', w: 120, h: 120, text: '', color: '#2A4A7A', fg: '#ffffff' }
  };
  // عناصر وضع اللعبة
  const GAME_KINDS = {
    startBtn: { label: 'زر بدء', w: 140, h: 44, text: 'ابدأ', color: '#D4AF37', fg: '#0D2B52' },
    score:    { label: 'نقاط', w: 120, h: 30, text: 'النقاط: 0', color: 'transparent', fg: '#ffffff' },
    title:    { label: 'عنوان', w: 200, h: 50, text: 'اسم اللعبة', color: 'transparent', fg: '#D4AF37' },
    resetBtn: { label: 'زر إعادة', w: 140, h: 44, text: 'إعادة', color: '#2A4A7A', fg: '#ffffff' }
  };

  let mode = 'app';
  let kinds = APP_KINDS;
  let kind = 'button';
  let items = [];
  let selected = -1;
  let drag = null;

  function kindsFor(m) { return m === 'game' ? GAME_KINDS : APP_KINDS; }

  function buildPalette() {
    paletteEl.innerHTML = '';
    const names = Object.keys(kinds);
    if (!names.includes(kind)) kind = names[0];
    names.forEach(k => {
      const b = document.createElement('button');
      b.className = 'kind' + (k === kind ? ' gold' : '');
      b.textContent = kinds[k].label;
      b.onclick = () => {
        kind = k;
        buildPalette();
      };
      paletteEl.appendChild(b);
    });
  }

  function setMode(m) {
    mode = m;
    kinds = kindsFor(m);
    kind = Object.keys(kinds)[0];
    document.querySelectorAll('.mode').forEach(b => b.classList.toggle('gold', b.dataset.mode === m));
    paletteTitle.textContent = m === 'game'
      ? 'عناصر اللعبة: اختر عنصراً ثم انقر على الشاشة لإضافته'
      : 'لوحة العناصر: اختر عنصراً ثم انقر على الشاشة لإضافته';
    buildPalette();
  }

  function render() {
    phone.innerHTML = '';
    items.forEach((it, i) => {
      const d = document.createElement('div');
      d.className = 'el' + (i === selected ? ' sel' : '');
      d.style.left = it.x + 'px';
      d.style.top = it.y + 'px';
      d.style.width = it.w + 'px';
      d.style.height = it.h + 'px';
      d.style.background = it.color;
      d.style.color = it.fg;
      d.textContent = it.kind === 'image' ? '\u25A3' : it.text;
      d.dataset.i = i;
      if (it.mode === 'game') {
        const tag = document.createElement('span');
        tag.className = 'tag';
        tag.textContent = GAME_KINDS[it.kind].label;
        d.appendChild(tag);
      }
      phone.appendChild(d);
    });
    renderProps();
  }

  function renderProps() {
    const it = items[selected];
    if (!it) { propsEl.style.display = 'none'; delsel.disabled = true; return; }
    propsEl.style.display = 'block';
    delsel.disabled = false;
    textRow.style.display = it.kind === 'image' ? 'none' : 'flex';
    ptext.value = it.text;
    pcolor.value = it.color.startsWith('#') ? it.color : '#132F5A';
    const base = kindsFor(it.mode)[it.kind];
    const pct = Math.round(it.w / base.w * 100);
    psize.value = Math.max(40, Math.min(200, pct));
    psizeOut.textContent = psize.value + '%';
  }

  function pos(e) {
    const r = phone.getBoundingClientRect();
    return { x: e.clientX - r.left, y: e.clientY - r.top };
  }

  function indexAt(e) {
    const t = e.target.closest('.el');
    return t ? Number(t.dataset.i) : -1;
  }

  phone.addEventListener('pointerdown', e => {
    const i = indexAt(e);
    if (i >= 0) {
      selected = i;
      const p = pos(e);
      drag = { i, dx: p.x - items[i].x, dy: p.y - items[i].y, moved: false, sx: e.clientX, sy: e.clientY };
      render();
    } else {
      const p = pos(e);
      const d = kinds[kind];
      items.push({ mode, kind, x: Math.round(p.x - d.w / 2), y: Math.round(p.y - d.h / 2),
        w: d.w, h: d.h, text: d.text, color: d.color, fg: d.fg });
      selected = items.length - 1;
      drag = null;
      render();
    }
  });

  phone.addEventListener('pointermove', e => {
    if (!drag) return;
    if (Math.abs(e.clientX - drag.sx) + Math.abs(e.clientY - drag.sy) > 4) drag.moved = true;
    if (!drag.moved) return;
    const p = pos(e);
    const it = items[drag.i];
    it.x = Math.max(0, Math.min(W - it.w, Math.round(p.x - drag.dx)));
    it.y = Math.max(0, Math.min(H - it.h, Math.round(p.y - drag.dy)));
    render();
  });

  phone.addEventListener('pointerup', () => { drag = null; });
  phone.addEventListener('pointercancel', () => { drag = null; });

  ptext.addEventListener('input', () => {
    if (selected >= 0) { items[selected].text = ptext.value; render(); }
  });
  pcolor.addEventListener('input', () => {
    if (selected >= 0) { items[selected].color = pcolor.value; render(); }
  });
  psize.addEventListener('input', () => {
    if (selected < 0) return;
    const it = items[selected];
    const base = kindsFor(it.mode)[it.kind];
    const f = Number(psize.value) / 100;
    it.w = Math.round(base.w * f);
    it.h = Math.round(base.h * f);
    it.x = Math.max(0, Math.min(W - it.w, it.x));
    it.y = Math.max(0, Math.min(H - it.h, it.y));
    psizeOut.textContent = psize.value + '%';
    render();
  });

  delsel.onclick = () => {
    if (selected < 0) return;
    items.splice(selected, 1);
    selected = -1;
    render();
  };
  document.getElementById('clear').onclick = () => {
    items = []; selected = -1; render();
  };

  document.querySelectorAll('.mode').forEach(b => {
    b.addEventListener('click', () => setMode(b.dataset.mode));
  });

  // ===== الحفظ والفتح =====
  function getDesigns() {
    try { return JSON.parse(localStorage.getItem(DKEY) || '{}'); }
    catch (e) { return {}; }
  }
  function refreshDesigns(selectedName) {
    const sel = document.getElementById('designs');
    const all = getDesigns();
    sel.innerHTML = '';
    Object.keys(all).sort().forEach(n => {
      const o = document.createElement('option');
      o.value = n; o.textContent = n;
      sel.appendChild(o);
    });
    if (selectedName) sel.value = selectedName;
  }
  function msg(t) { msgEl.textContent = t; }

  document.getElementById('save').onclick = () => {
    const name = document.getElementById('sname').value.trim();
    if (!name) { msg('اكتب اسم التصميم أولاً'); return; }
    const all = getDesigns();
    all[name] = JSON.parse(JSON.stringify(items));
    try {
      localStorage.setItem(DKEY, JSON.stringify(all));
      refreshDesigns(name);
      msg('تم حفظ التصميم: ' + name);
    } catch (e) { msg('تعذّر الحفظ: ' + e); }
  };
  document.getElementById('load').onclick = () => {
    const name = document.getElementById('designs').value;
    const all = getDesigns();
    if (!name || !(name in all)) { msg('لا يوجد تصميم محدد لفتحه'); return; }
    items = JSON.parse(JSON.stringify(all[name]));
    selected = -1;
    document.getElementById('sname').value = name;
    render();
    msg('تم فتح: ' + name);
  };
  document.getElementById('delds').onclick = () => {
    const name = document.getElementById('designs').value;
    const all = getDesigns();
    if (!name || !(name in all)) { msg('لا يوجد تصميم محدد للحذف'); return; }
    delete all[name];
    localStorage.setItem(DKEY, JSON.stringify(all));
    refreshDesigns();
    msg('تم حذف: ' + name);
  };

  // ===== توليد كود Flutter =====
  function dartStr(s) {
    return "'" + String(s).replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\$/g, '\\$') + "'";
  }
  function dartColor(c) {
    if (!c || c === 'transparent') return 'Colors.transparent';
    return 'Color(0xFF' + c.replace('#', '').toUpperCase() + ')';
  }
  function generateDart() {
    const appItems = items.filter(it => it.mode !== 'game');
    const children = appItems.map(it => {
      const common = 'Positioned(left: ' + it.x + ', top: ' + it.y + ', width: ' + it.w + ', height: ' + it.h + ', child: ';
      if (it.kind === 'button') {
        return common + 'ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: ' + dartColor(it.color) + ', foregroundColor: ' + dartColor(it.fg) + '), child: Text(' + dartStr(it.text) + ')),)';
      }
      if (it.kind === 'text') {
        return common + 'Center(child: Text(' + dartStr(it.text) + ', style: TextStyle(color: ' + dartColor(it.fg) + '))),)';
      }
      if (it.kind === 'input') {
        return common + 'TextField(decoration: InputDecoration(hintText: ' + dartStr(it.text) + ', filled: true, fillColor: ' + dartColor(it.color) + ', border: OutlineInputBorder())),)';
      }
      return common + 'Container(decoration: BoxDecoration(color: ' + dartColor(it.color) + ', borderRadius: BorderRadius.circular(8))),)';
    });
    return `import 'package:flutter/material.dart';

class DesignedScreen extends StatelessWidget {
  const DesignedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D2B52),
      body: Center(
        child: SizedBox(
          width: ${W},
          height: ${H},
          child: Stack(
            children: [
              ${children.join('\n              ')}
            ],
          ),
        ),
      ),
    );
  }
}
`;
  }
  document.getElementById('export').onclick = () => {
    const appItems = items.filter(it => it.mode !== 'game');
    if (!appItems.length) { msg('لا توجد عناصر شاشة للتصدير في وضع التطبيق'); return; }
    codeEl.value = generateDart();
    msg('تم توليد الكود من عناصر شاشات التطبيق');
  };

  setMode('app');
  render();
  refreshDesigns();
</script>
</body>
</html>
''';

class DesignPage extends StatefulWidget {
  const DesignPage({super.key});

  @override
  State<DesignPage> createState() => _DesignPageState();
}

class _DesignPageState extends State<DesignPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(_designHtml, baseUrl: 'https://localhost/');
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
