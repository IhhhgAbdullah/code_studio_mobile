import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String _pyHtml = r'''
<!DOCTYPE html>
<html dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<script src="https://cdn.jsdelivr.net/pyodide/v0.25.1/full/pyodide.js"></script>
<style>
  * { box-sizing: border-box; }
  body { font-family: sans-serif; margin: 0; padding: 12px; background: #0D2B52; color: #fff; }
  .card {
    background: #132F5A; border: 1px solid #D4AF37; border-radius: 14px;
    padding: 12px; margin-bottom: 12px;
  }
  .card-title { color: #D4AF37; font-weight: bold; margin-bottom: 8px; font-size: 14px; }
  input, select, textarea {
    width: 100%; padding: 10px; margin-bottom: 8px; border-radius: 10px;
    border: 1px solid #D4AF37; background: #0A1F3D; color: #fff; font-size: 15px;
  }
  #code {
    width: 100%; min-height: 170px; font-family: monospace; font-size: 15px;
    direction: ltr; text-align: left; background: #0A1F3D; color: #e6edf7;
    border-radius: 10px; padding: 10px; white-space: pre-wrap; word-break: break-word;
    outline: none; overflow-y: auto;
  }
  .row { display: flex; gap: 8px; }
  .row > * { flex: 1; }
  button {
    width: 100%; padding: 13px; font-size: 16px; border: none;
    border-radius: 10px; background: #D4AF37; color: #0D2B52; font-weight: bold;
  }
  button.alt { background: #2A4A7A; color: #fff; }
  button.danger { background: #8B2A2A; color: #fff; }
  button:disabled { opacity: 0.6; }
  pre {
    background: #0A1F3D; color: #7CFC7C; padding: 10px; border-radius: 10px;
    min-height: 90px; margin: 0; direction: ltr; white-space: pre-wrap; text-align: left;
    font-family: monospace; font-size: 14px;
  }
  #term-in { direction: ltr; font-family: monospace; }
  #term-out { min-height: 120px; max-height: 260px; overflow-y: auto; }
  .err { color: #ff6b6b; font-weight: bold; }
  .msg { color: #D4AF37; font-size: 13px; margin-top: 6px; }
  .kw { color: #C792EA; font-weight: bold; }
  .bi { color: #82AAFF; }
  .str { color: #C3E88D; }
  .num { color: #F78C6C; }
  .com { color: #6A8A9A; font-style: italic; }
</style>
</head>
<body>
<div class="card">
  <div class="card-title">الكود</div>
  <input id="fname" value="main.py" placeholder="اسم الملف أو المسار (مثال: projects/app.py)">
  <div id="code" contenteditable="true" spellcheck="false"></div>
  <div class="row" style="margin-top:8px">
    <button id="save" class="alt">حفظ</button>
    <button id="open" class="alt">فتح</button>
  </div>
  <div class="row" style="margin-top:8px">
    <button id="new" class="alt">جديد</button>
    <button id="del" class="danger">حذف</button>
  </div>
  <div class="row" style="margin-top:8px">
    <select id="files"></select>
  </div>
  <div class="row" style="margin-top:8px">
    <button id="ren" class="alt">إعادة تسمية (نقل الكود)</button>
  </div>
  <input id="fold" placeholder="اسم المجلد الجديد (مثال: projects)" style="margin-top:8px">
  <div class="row" style="margin-top:8px">
    <button id="mkdir" class="alt">مجلد جديد</button>
  </div>
  <div class="row" style="margin-top:8px">
    <button id="exp" class="alt">تصدير الكل</button>
    <button id="imp" class="alt">استيراد</button>
  </div>
  <textarea id="xdata" rows="4" placeholder="نص التصدير يظهر هنا، والصق نص الاستيراد هنا"></textarea>
  <div id="msg" class="msg"></div>
</div>
<div class="card">
  <div class="card-title">التشغيل</div>
  <button id="run" disabled>جاري تحميل Python...</button>
</div>
<div class="card">
  <div class="card-title">المخرجات</div>
  <pre id="out">المخرجات ستظهر هنا</pre>
</div>
<div class="card">
  <div class="card-title">الطرفية (سطر واحد، والمتغيرات تبقى)</div>
  <input id="term-in" placeholder="اكتب سطر Python ثم Enter، مثال: x = 5">
  <pre id="term-out">طرفية Python جاهزة بعد تحميل Python</pre>
</div>
<script>
  const KEY = 'cs_files';
  const FKEY = 'cs_folders';
  const KEYWORDS = ['False','None','True','and','as','assert','async','await','break','class','continue','def','del','elif','else','except','finally','for','from','global','if','import','in','is','lambda','nonlocal','not','or','pass','raise','return','try','while','with','yield','match','case'];
  const BUILTINS = ['print','len','range','int','str','float','list','dict','set','tuple','sum','min','max','abs','sorted','enumerate','zip','map','filter','open','type','isinstance','input'];
  const PAIRS = { '(': ')', '[': ']', '{': '}', '"': '"', "'": "'" };
  const CLOSERS = [')', ']', '}', '"', "'"];

  function esc(s) {
    return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  function highlight(src) {
    const re = /(#[^\n]*)|("(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*')|\b(\d+(?:\.\d+)?)\b|([A-Za-z_]\w*)/g;
    let out = '', last = 0, m;
    while ((m = re.exec(src)) !== null) {
      out += esc(src.slice(last, m.index));
      last = re.lastIndex;
      const t = m[0];
      if (m[1]) out += '<span class="com">' + esc(t) + '</span>';
      else if (m[2]) out += '<span class="str">' + esc(t) + '</span>';
      else if (m[3]) out += '<span class="num">' + esc(t) + '</span>';
      else if (KEYWORDS.includes(t)) out += '<span class="kw">' + esc(t) + '</span>';
      else if (BUILTINS.includes(t)) out += '<span class="bi">' + esc(t) + '</span>';
      else out += esc(t);
    }
    out += esc(src.slice(last));
    return out + '\n';
  }

  function getCode() {
    return document.getElementById('code').innerText.replace(/\u00a0/g, ' ');
  }

  function setCode(src) {
    document.getElementById('code').innerHTML = highlight(src);
  }

  function getFiles() {
    try { return JSON.parse(localStorage.getItem(KEY) || '{}'); }
    catch (e) { return {}; }
  }

  function getFolders() {
    try { return JSON.parse(localStorage.getItem(FKEY) || '[]'); }
    catch (e) { return []; }
  }

  function cleanPath(raw) {
    return (raw || '').trim().replace(/\\/g, '/').replace(/\/+/g, '/')
      .split('/').filter(p => p && p !== '.' && p !== '..').join('/');
  }

  function cleanName(raw) {
    let n = cleanPath(raw);
    if (!n) n = 'main.py';
    if (!n.endsWith('.py')) n += '.py';
    return n;
  }

  function opt(n, label) {
    const o = document.createElement('option');
    o.value = n;
    o.textContent = label || n;
    return o;
  }

  function refreshList(selected) {
    const sel = document.getElementById('files');
    const files = getFiles();
    const names = Object.keys(files);
    const folders = new Set(getFolders());
    names.forEach(n => {
      if (n.includes('/')) folders.add(n.slice(0, n.lastIndexOf('/')));
    });
    sel.innerHTML = '';

    const rootNames = names.filter(n => !n.includes('/')).sort();
    if (rootNames.length) {
      const g = document.createElement('optgroup');
      g.label = 'الجذر';
      rootNames.forEach(n => g.appendChild(opt(n)));
      sel.appendChild(g);
    }

    [...folders].sort().forEach(f => {
      const g = document.createElement('optgroup');
      g.label = f + '/';
      const inside = names.filter(n => n.startsWith(f + '/')).sort();
      if (inside.length) {
        inside.forEach(n => g.appendChild(opt(n, n.slice(f.length + 1))));
      } else {
        const e = opt('', '(مجلد فارغ)');
        e.disabled = true;
        g.appendChild(e);
      }
      sel.appendChild(g);
    });

    if (selected) sel.value = selected;
  }

  function msg(t) {
    document.getElementById('msg').textContent = t;
  }

  function saveFile() {
    const name = cleanName(document.getElementById('fname').value);
    const files = getFiles();
    files[name] = getCode();
    try {
      localStorage.setItem(KEY, JSON.stringify(files));
      document.getElementById('fname').value = name;
      refreshList(name);
      msg('تم الحفظ: ' + name);
    } catch (e) {
      msg('تعذّر الحفظ: ' + e);
    }
  }

  function openFile() {
    const name = document.getElementById('files').value;
    const files = getFiles();
    if (!name || !(name in files)) { msg('لا يوجد ملف محفوظ لفتحه'); return; }
    setCode(files[name]);
    document.getElementById('fname').value = name;
    msg('تم فتح: ' + name);
  }

  function newFile() {
    setCode('');
    document.getElementById('fname').value = 'new.py';
    document.getElementById('out').textContent = 'ملف جديد. اكتب الكود ثم احفظه.';
    msg('ملف جديد');
  }

  function deleteFile() {
    const name = document.getElementById('files').value;
    const files = getFiles();
    if (!name || !(name in files)) { msg('لا يوجد ملف محدد للحذف'); return; }
    delete files[name];
    localStorage.setItem(KEY, JSON.stringify(files));
    refreshList();
    msg('تم حذف: ' + name);
  }

  function renameFile() {
    const oldName = document.getElementById('files').value;
    const files = getFiles();
    if (!oldName || !(oldName in files)) { msg('اختر ملفاً من القائمة أولاً'); return; }
    const newName = cleanName(document.getElementById('fname').value);
    if (newName === oldName) { msg('الاسم الجديد مطابق للقديم، غيّر الاسم في الحقل أولاً'); return; }
    if (newName in files) { msg('يوجد ملف بهذا الاسم: ' + newName); return; }
    files[newName] = getCode();
    delete files[oldName];
    localStorage.setItem(KEY, JSON.stringify(files));
    document.getElementById('fname').value = newName;
    refreshList(newName);
    msg('تم النقل إلى: ' + newName);
  }

  function newFolder() {
    const f = cleanPath(document.getElementById('fold').value);
    if (!f) { msg('اكتب اسم المجلد أولاً'); return; }
    const list = getFolders();
    if (!list.includes(f)) list.push(f);
    localStorage.setItem(FKEY, JSON.stringify(list));
    document.getElementById('fold').value = '';
    refreshList();
    msg('تم إنشاء المجلد: ' + f + '/');
  }

  function exportAll() {
    const data = { app: 'code_studio_mobile', version: 1,
      folders: getFolders(), files: getFiles() };
    const text = JSON.stringify(data, null, 2);
    document.getElementById('xdata').value = text;
    msg('تم التصدير: ' + Object.keys(data.files).length + ' ملف. انسخ النص من الحقل أدناه.');
  }

  function importAll() {
    const raw = document.getElementById('xdata').value.trim();
    let data;
    try { data = JSON.parse(raw); }
    catch (e) { msg('النص ليس JSON صالحاً. الصق نص التصدير كاملاً.'); return; }
    if (!data || data.app !== 'code_studio_mobile' || typeof data.files !== 'object') {
      msg('هذا النص ليس تصديراً من التطبيق');
      return;
    }
    const files = getFiles();
    const names = Object.keys(data.files);
    names.forEach(n => {
      const clean = cleanPath(n);
      if (clean) files[clean] = String(data.files[n]);
    });
    try {
      localStorage.setItem(KEY, JSON.stringify(files));
    } catch (e) {
      msg('تعذّر الاستيراد: ' + e);
      return;
    }
    const folders = new Set(getFolders());
    (data.folders || []).forEach(f => {
      const clean = cleanPath(f);
      if (clean) folders.add(clean);
    });
    localStorage.setItem(FKEY, JSON.stringify([...folders]));
    refreshList();
    msg('تم الاستيراد: ' + names.length + ' ملف. الملفات التي لها نفس الاسم استُبدلت.');
  }

  function openByName(n) {
    refreshList(n);
    openFile();
  }

  let timer = null;
  function getCaret(el) {
    const sel = window.getSelection();
    if (!sel.rangeCount) return 0;
    const r = sel.getRangeAt(0).cloneRange();
    r.selectNodeContents(el);
    r.setEnd(sel.anchorNode, sel.anchorOffset);
    return r.toString().length;
  }
  function setCaret(el, pos) {
    const sel = window.getSelection();
    const r = document.createRange();
    let node = null, count = 0;
    const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
    while ((node = walker.nextNode())) {
      if (count + node.length >= pos) {
        r.setStart(node, pos - count);
        r.collapse(true);
        sel.removeAllRanges();
        sel.addRange(r);
        return;
      }
      count += node.length;
    }
  }

  const codeEl = document.getElementById('code');

  codeEl.addEventListener('keydown', (e) => {
    const sel = window.getSelection();
    if (!sel.rangeCount || !sel.isCollapsed) return;
    const el = codeEl;
    const pos = getCaret(el);
    const src = el.innerText.replace(/\u00a0/g, ' ');

    if (e.key === 'Enter') {
      e.preventDefault();
      const lineStart = src.lastIndexOf('\n', pos - 1) + 1;
      const line = src.slice(lineStart, pos);
      const indent = line.match(/^\s*/)[0];
      const extra = line.trimEnd().endsWith(':') ? '    ' : '';
      document.execCommand('insertText', false, '\n' + indent + extra);
      return;
    }

    if (CLOSERS.includes(e.key) && src[pos] === e.key) {
      e.preventDefault();
      sel.modify('move', 'forward', 'character');
      return;
    }

    if (e.key in PAIRS) {
      e.preventDefault();
      document.execCommand('insertText', false, e.key + PAIRS[e.key]);
      sel.modify('move', 'backward', 'character');
    }
  });

  codeEl.addEventListener('input', () => {
    clearTimeout(timer);
    timer = setTimeout(() => {
      const el = codeEl;
      const pos = getCaret(el);
      const src = el.innerText.replace(/\u00a0/g, ' ');
      el.innerHTML = highlight(src);
      setCaret(el, pos);
    }, 250);
  });

  codeEl.addEventListener('paste', (e) => {
    e.preventDefault();
    const text = (e.clipboardData || window.clipboardData).getData('text');
    document.execCommand('insertText', false, text);
  });

  let pyodide = null;
  let termActive = false;

  function log(s) {
    document.getElementById('out').textContent += s + '\n';
  }

  function tlog(s) {
    const t = document.getElementById('term-out');
    t.textContent += s + '\n';
    t.scrollTop = t.scrollHeight;
  }

  function showErr(title, detail) {
    const out = document.getElementById('out');
    out.innerHTML = '';
    const t = document.createElement('div');
    t.className = 'err';
    t.textContent = title;
    const d = document.createElement('div');
    d.textContent = detail;
    out.appendChild(t);
    out.appendChild(d);
  }

  async function termRun() {
    const input = document.getElementById('term-in');
    const line = input.value;
    if (!line.trim()) return;
    tlog('>>> ' + line);
    input.value = '';
    termActive = true;
    try {
      const result = await pyodide.runPythonAsync(line);
      if (result !== undefined && result !== null) tlog(String(result));
    } catch (e) {
      const text = String(e);
      const lines = text.trim().split('\n');
      tlog(lines[lines.length - 1]);
    } finally {
      termActive = false;
    }
  }

  async function init() {
    if (typeof loadPyodide !== 'function') {
      throw new Error('ملف Pyodide لم يُحمَّل. تأكد من اتصال الإنترنت.');
    }
    pyodide = await loadPyodide({
      indexURL: 'https://cdn.jsdelivr.net/pyodide/v0.25.1/full/'
    });
    pyodide.setStdout({ batched: (s) => { if (termActive) tlog(s); else log(s); } });
    pyodide.setStderr({ batched: (s) => { if (termActive) tlog(s); else log(s); } });
    const btn = document.getElementById('run');
    btn.disabled = false;
    btn.textContent = 'تشغيل';
    btn.onclick = runCode;
    document.getElementById('out').textContent = 'Python جاهز';
    document.getElementById('term-out').textContent = 'طرفية Python جاهزة\n';
  }

  async function runCode() {
    document.getElementById('out').textContent = '';
    try {
      await pyodide.runPythonAsync(getCode());
    } catch (e) {
      const text = String(e);
      const lines = text.trim().split('\n');
      const last = lines[lines.length - 1];
      const lineMatch = text.match(/line (\d+)/);
      const title = 'خطأ في Python' + (lineMatch ? ' - السطر ' + lineMatch[1] : '');
      showErr(title, last);
    }
  }

  document.getElementById('save').onclick = saveFile;
  document.getElementById('open').onclick = openFile;
  document.getElementById('new').onclick = newFile;
  document.getElementById('del').onclick = deleteFile;
  document.getElementById('ren').onclick = renameFile;
  document.getElementById('mkdir').onclick = newFolder;
  document.getElementById('exp').onclick = exportAll;
  document.getElementById('imp').onclick = importAll;
  document.getElementById('term-in').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') { e.preventDefault(); termRun(); }
  });
  setCode('name = "Abdullah"\nfor i in range(3):\n    print("مرحباً", name, i + 1)\n');
  refreshList();
  init().catch(e => showErr('فشل التحميل', (e && e.message) ? e.message : String(e)));
</script>
</body>
</html>
''';

final GlobalKey<PythonTestPageState> editorKey = GlobalKey<PythonTestPageState>();

class PythonTestPage extends StatefulWidget {
  const PythonTestPage({super.key});

  @override
  State<PythonTestPage> createState() => PythonTestPageState();
}

class PythonTestPageState extends State<PythonTestPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(_pyHtml, baseUrl: 'https://localhost/');
  }

  void openFile(String name) {
    _controller.runJavaScript('openByName(${jsonEncode(name)})');
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
