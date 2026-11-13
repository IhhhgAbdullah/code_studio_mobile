import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String _pyHtml = r'''
<!DOCTYPE html>
<html dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<script src="file:///android_asset/flutter_assets/assets/pyodide/pyodide.js"></script>
<style>
  * { box-sizing: border-box; }
  body { font-family: sans-serif; margin: 0; padding: 12px; background: #0D2B52; color: #fff; }
  .card { background: #132F5A; border: 1px solid #D4AF37; border-radius: 14px; padding: 12px; margin-bottom: 12px; }
  .card-title { color: #D4AF37; font-weight: bold; margin-bottom: 8px; font-size: 14px; }
  input, select {
    width: 100%; padding: 10px; margin-bottom: 8px; border-radius: 10px;
    border: 1px solid #D4AF37; background: #0A1F3D; color: #fff; font-size: 15px;
  }
  .editor { display: flex; direction: ltr; background: #0A1F3D; border-radius: 10px; overflow: hidden; min-height: 170px; }
  #gutter {
    flex: 0 0 34px; padding: 10px 6px 10px 0; text-align: right; color: #6A8A9A;
    font-family: monospace; font-size: 15px; line-height: 1.45; user-select: none; background: #081A33;
    white-space: pre; overflow: hidden;
  }
  #code {
    flex: 1; min-width: 0; font-family: monospace; font-size: 15px; line-height: 1.45;
    direction: ltr; text-align: left; color: #e6edf7; padding: 10px;
    white-space: pre-wrap; word-break: break-word; outline: none; overflow-y: auto;
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
  #stdin {
    width: 100%; min-height: 70px; margin-bottom: 8px; border-radius: 10px;
    border: 1px solid #D4AF37; background: #0A1F3D; color: #fff; font-size: 14px;
    direction: ltr; font-family: monospace; padding: 8px;
  }
  .err { color: #ff6b6b; font-weight: bold; }
  .msg { color: #D4AF37; font-size: 13px; margin-top: 6px; min-height: 16px; }
  .kw { color: #C792EA; font-weight: bold; }
  .bi { color: #82AAFF; }
  .str { color: #C3E88D; }
  .num { color: #F78C6C; }
  .com { color: #6A8A9A; font-style: italic; }
  .errnum { color: #ff6b6b; font-weight: bold; background: #3a1414; border-radius: 4px; }
</style>
</head>
<body>
<div class="card">
  <div class="card-title">المشاريع</div>
  <div class="row">
    <input id="pname" placeholder="اسم المشروع الجديد">
    <button id="pnew" class="alt" style="flex:0 0 auto;width:auto;padding:10px 14px">إنشاء</button>
  </div>
  <select id="projSel"></select>
  <div class="row">
    <button id="pdel" class="danger">حذف المشروع</button>
    <button id="pcur" class="alt">تحديد كمشروع حالي</button>
  </div>
  <div id="pinfo" class="msg"></div>
</div>
<div class="card">
  <div class="card-title">الكود</div>
  <input id="fname" value="main.py" placeholder="اسم الملف (مثال: app.py)">
  <div class="editor">
    <div id="gutter"></div>
    <div id="code" contenteditable="true" spellcheck="false"></div>
  </div>
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
  <input id="fold" placeholder="اسم المجلد الجديد (مثال: src)" style="margin-top:8px">
  <div class="row" style="margin-top:8px">
    <button id="mkdir" class="alt">مجلد جديد</button>
  </div>
  <div class="row" style="margin-top:8px">
    <button id="exp" class="alt">تصدير الكل</button>
    <button id="imp" class="alt">استيراد</button>
  </div>
  <button id="copyProj" class="alt" style="margin-top:8px">نسخ المشروع إلى الحافظة</button>
  <button id="impClip" class="alt" style="margin-top:8px">استيراد من الحافظة</button>
  <textarea id="xdata" rows="4" placeholder="نص التصدير يظهر هنا، والصق نص الاستيراد هنا" style="width:100%;margin-top:8px;background:#0A1F3D;color:#fff;border:1px solid #D4AF37;border-radius:10px;padding:8px;direction:ltr"></textarea>
  <div id="msg" class="msg"></div>
</div>
<div class="card">
  <div class="card-title">مدخلات input() (سطر لكل إدخال، بالترتيب)</div>
  <textarea id="stdin" placeholder="مثال:\nAbdullah\n25"></textarea>
  <div class="msg">كل استدعاء لـ input() يأخذ السطر التالي من هذا الحقل.</div>
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
  <div class="card-title">الطرفية (تدعم الكتل: سطر ينتهي بـ : ثم سطر فارغ للتنفيذ)</div>
  <input id="term-in" placeholder="اكتب سطر Python ثم Enter">
  <pre id="term-out">طرفية Python جاهزة بعد تحميل Python</pre>
</div>
<script>
  const KEY = 'cs_files';
  const FKEY = 'cs_folders';
  const PKEY = 'cs_projects';
  const CURKEY = 'cs_cur_project';
  const KEYWORDS = ['False','None','True','and','as','assert','async','await','break','class','continue','def','del','elif','else','except','finally','for','from','global','if','import','in','is','lambda','nonlocal','not','or','pass','raise','return','try','while','with','yield','match','case'];
  const BUILTINS = ['print','len','range','int','str','float','list','dict','set','tuple','sum','min','max','abs','sorted','enumerate','zip','map','filter','open','type','isinstance','input'];
  const PAIRS = { '(': ')', '[': ']', '{': '}' };
  const CLOSERS = [')', ']', '}'];

  function esc(s) { return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }

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

  // رقم السطر المعطوب (0 = لا يوجد خطأ)
  let errorLine = 0;

  function updateGutter() {
    const src = getCode();
    const n = src.split('\n').length - (src.endsWith('\n') ? 1 : 0);
    const lines = [];
    for (let i = 1; i <= Math.max(1, n); i++) {
      lines.push(i === errorLine ? '<span class="errnum">' + i + '</span>' : String(i));
    }
    document.getElementById('gutter').innerHTML = lines.join('\n');
  }

  function getCode() { return document.getElementById('code').innerText.replace(/\u00a0/g, ' '); }
  function setCode(src) {
    document.getElementById('code').innerHTML = highlight(src);
    updateGutter();
  }

  function getFiles() { try { return JSON.parse(localStorage.getItem(KEY) || '{}'); } catch (e) { return {}; } }
  function getFolders() { try { return JSON.parse(localStorage.getItem(FKEY) || '[]'); } catch (e) { return []; } }
  function getProjects() { try { return JSON.parse(localStorage.getItem(PKEY) || '[]'); } catch (e) { return []; } }
  function setProjects(list) { localStorage.setItem(PKEY, JSON.stringify(list)); }
  function curProject() { return localStorage.getItem(CURKEY) || ''; }

  function cleanPath(raw) {
    return (raw || '').trim().replace(/\\/g, '/').replace(/\/+/g, '/')
      .split('/').filter(p => p && p !== '.' && p !== '..').join('/');
  }
  function fullName(raw) {
    let n = cleanPath(raw);
    if (!n) n = 'main.py';
    if (!n.endsWith('.py')) n += '.py';
    const p = curProject();
    return p ? p + '/' + n : n;
  }
  function shownName(full) {
    const p = curProject();
    return p && full.startsWith(p + '/') ? full.slice(p.length + 1) : full;
  }

  function opt(v, label) {
    const o = document.createElement('option');
    o.value = v; o.textContent = label || v;
    return o;
  }

  function msg(t) { document.getElementById('msg').textContent = t; }

  // ===== المشاريع =====
  function refreshProjects() {
    const sel = document.getElementById('projSel');
    const list = getProjects();
    const cur = curProject();
    sel.innerHTML = '';
    sel.appendChild(opt('', 'بدون مشروع (الجذر)'));
    list.forEach(p => sel.appendChild(opt(p, p)));
    sel.value = cur;
    document.getElementById('pinfo').textContent = cur
      ? 'المشروع الحالي: ' + cur + ' (الملفات الجديدة تُحفظ داخله)'
      : 'لا يوجد مشروع حالي، الملفات تُحفظ في الجذر';
  }

  function createProject() {
    const name = cleanPath(document.getElementById('pname').value);
    if (!name) { msg('اكتب اسم المشروع أولاً'); return; }
    if (name.includes('/')) { msg('اسم المشروع بدون مجلدات'); return; }
    const list = getProjects();
    if (list.includes(name)) { msg('يوجد مشروع بهذا الاسم'); return; }
    list.push(name);
    setProjects(list);
    localStorage.setItem(CURKEY, name);
    document.getElementById('pname').value = '';
    refreshProjects();
    refreshList();
    msg('تم إنشاء المشروع وتحديده: ' + name);
  }

  function setCurrent() {
    const sel = document.getElementById('projSel').value;
    localStorage.setItem(CURKEY, sel);
    refreshProjects();
    refreshList();
    msg(sel ? 'المشروع الحالي: ' + sel : 'تم اختيار الجذر');
  }

  function deleteProject() {
    const name = document.getElementById('projSel').value;
    if (!name) { msg('اختر مشروعاً لحذفه'); return; }
    const files = getFiles();
    Object.keys(files).forEach(k => { if (k.startsWith(name + '/')) delete files[k]; });
    localStorage.setItem(KEY, JSON.stringify(files));
    setProjects(getProjects().filter(p => p !== name));
    const folders = getFolders().filter(f => f !== name && !f.startsWith(name + '/'));
    localStorage.setItem(FKEY, JSON.stringify(folders));
    if (curProject() === name) localStorage.setItem(CURKEY, '');
    refreshProjects();
    refreshList();
    msg('تم حذف المشروع وملفاته: ' + name);
  }

  // ===== الملفات =====
  function refreshList(selected) {
    const sel = document.getElementById('files');
    const files = getFiles();
    const cur = curProject();
    const names = Object.keys(files);
    const folders = new Set(getFolders());
    names.forEach(n => { if (n.includes('/')) folders.add(n.slice(0, n.lastIndexOf('/'))); });
    sel.innerHTML = '';

    const scope = cur ? names.filter(n => n.startsWith(cur + '/')) : names.filter(n => !n.includes('/'));
    const rootNames = scope.filter(n => {
      const rel = cur ? n.slice(cur.length + 1) : n;
      return !rel.includes('/');
    }).sort();
    if (rootNames.length) {
      const g = document.createElement('optgroup');
      g.label = cur ? 'المشروع: ' + cur : 'الجذر';
      rootNames.forEach(n => g.appendChild(opt(n, shownName(n))));
      sel.appendChild(g);
    }

    const base = cur ? cur + '/' : '';
    [...folders].filter(f => (cur ? f.startsWith(cur + '/') : !f.includes('/')) && f !== cur).sort().forEach(f => {
      const g = document.createElement('optgroup');
      g.label = f.slice(base.length) + '/';
      const inside = names.filter(n => n.startsWith(f + '/')).sort();
      if (inside.length) inside.forEach(n => g.appendChild(opt(n, n.slice(f.length + 1))));
      else g.appendChild(opt('folder:' + f, '(مجلد فارغ، اضغط حذف لإزالته)'));
      sel.appendChild(g);
    });

    if (selected) sel.value = selected;
  }

  function saveFile() {
    const name = fullName(document.getElementById('fname').value);
    const files = getFiles();
    files[name] = getCode();
    try {
      localStorage.setItem(KEY, JSON.stringify(files));
      document.getElementById('fname').value = shownName(name);
      refreshList(name);
      msg('تم الحفظ: ' + shownName(name));
    } catch (e) { msg('تعذّر الحفظ: ' + e); }
  }

  function openFile() {
    const name = document.getElementById('files').value;
    const files = getFiles();
    if (name.startsWith('folder:')) { msg('هذا مجلد، اختر ملفاً لفتحه'); return; }
    if (!name || !(name in files)) { msg('لا يوجد ملف محفوظ لفتحه'); return; }
    setCode(files[name]);
    document.getElementById('fname').value = shownName(name);
    msg('تم فتح: ' + shownName(name));
  }

  function newFile() {
    setCode('');
    document.getElementById('fname').value = 'new.py';
    document.getElementById('out').textContent = 'ملف جديد. اكتب الكود ثم احفظه.';
    msg('ملف جديد');
  }

  function deleteFile() {
    const sel = document.getElementById('files').value;
    const files = getFiles();
    if (sel.startsWith('folder:')) {
      const f = sel.slice('folder:'.length);
      localStorage.setItem(FKEY, JSON.stringify(getFolders().filter(x => x !== f)));
      refreshList();
      msg('تم حذف المجلد');
      return;
    }
    if (!sel || !(sel in files)) { msg('لا يوجد ملف محدد للحذف'); return; }
    delete files[sel];
    localStorage.setItem(KEY, JSON.stringify(files));
    refreshList();
    msg('تم حذف: ' + shownName(sel));
  }

  function renameFile() {
    const oldName = document.getElementById('files').value;
    const files = getFiles();
    if (!oldName || oldName.startsWith('folder:') || !(oldName in files)) { msg('اختر ملفاً من القائمة أولاً'); return; }
    const newName = fullName(document.getElementById('fname').value);
    if (newName === oldName) { msg('الاسم الجديد مطابق للقديم'); return; }
    if (newName in files) { msg('يوجد ملف بهذا الاسم'); return; }
    files[newName] = getCode();
    delete files[oldName];
    localStorage.setItem(KEY, JSON.stringify(files));
    document.getElementById('fname').value = shownName(newName);
    refreshList(newName);
    msg('تم النقل إلى: ' + shownName(newName));
  }

  function newFolder() {
    const f0 = cleanPath(document.getElementById('fold').value);
    if (!f0) { msg('اكتب اسم المجلد أولاً'); return; }
    const f = curProject() ? curProject() + '/' + f0 : f0;
    const list = getFolders();
    if (!list.includes(f)) list.push(f);
    localStorage.setItem(FKEY, JSON.stringify(list));
    document.getElementById('fold').value = '';
    refreshList();
    msg('تم إنشاء المجلد: ' + f0);
  }

  function exportAll() {
    const data = { app: 'code_studio_mobile', version: 2,
      projects: getProjects(), folders: getFolders(), files: getFiles() };
    document.getElementById('xdata').value = JSON.stringify(data, null, 2);
    msg('تم التصدير: ' + Object.keys(data.files).length + ' ملف. انسخ النص من الحقل أدناه.');
  }

  // نسخ ملفات المشروع الحالي (أو ملفات الجذر) كنص JSON إلى الحافظة
  async function copyProject() {
    const cur = curProject();
    const files = getFiles();
    const scoped = {};
    Object.keys(files).forEach(k => {
      if (cur ? k.startsWith(cur + '/') : !k.includes('/')) scoped[k] = files[k];
    });
    const data = { app: 'code_studio_mobile', version: 2,
      projects: cur ? [cur] : [], folders: [], files: scoped };
    const text = JSON.stringify(data, null, 2);
    try {
      await navigator.clipboard.writeText(text);
      msg('تم نسخ المشروع (' + Object.keys(scoped).length + ' ملف) إلى الحافظة');
    } catch (e) {
      const ta = document.getElementById('xdata');
      ta.value = text;
      ta.select();
      const ok = document.execCommand('copy');
      msg(ok ? 'تم نسخ المشروع إلى الحافظة' : 'تعذّر النسخ، انسخ النص من الحقل أدناه يدوياً');
    }
  }

  // استيراد مباشر من الحافظة: يقرأ النص ثم يستورده
  async function importFromClipboard() {
    let text = '';
    try {
      text = await navigator.clipboard.readText();
    } catch (e) {
      document.getElementById('xdata').focus();
      msg('تعذّر قراءة الحافظة. ألصق النص في الحقل أدناه، ثم اضغط استيراد');
      return;
    }
    if (!text || !text.trim()) { msg('الحافظة فارغة'); return; }
    document.getElementById('xdata').value = text;
    importAll();
  }

  function importAll() {
    const raw = document.getElementById('xdata').value.trim();
    let data;
    try { data = JSON.parse(raw); }
    catch (e) { msg('النص ليس JSON صالحاً.'); return; }
    if (!data || data.app !== 'code_studio_mobile' || typeof data.files !== 'object') {
      msg('هذا النص ليس تصديراً من التطبيق'); return;
    }
    const files = getFiles();
    const names = Object.keys(data.files);
    names.forEach(n => { const c = cleanPath(n); if (c) files[c] = String(data.files[n]); });
    try { localStorage.setItem(KEY, JSON.stringify(files)); }
    catch (e) { msg('تعذّر الاستيراد: ' + e); return; }
    const folders = new Set(getFolders());
    (data.folders || []).forEach(f => { const c = cleanPath(f); if (c) folders.add(c); });
    localStorage.setItem(FKEY, JSON.stringify([...folders]));
    const projects = new Set(getProjects());
    (data.projects || []).forEach(p => { const c = cleanPath(p); if (c) projects.add(c); });
    setProjects([...projects]);
    refreshProjects();
    refreshList();
    msg('تم الاستيراد: ' + names.length + ' ملف');
  }

  function openByName(n) { refreshList(n); openFile(); }

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
        r.setStart(node, pos - count); r.collapse(true);
        sel.removeAllRanges(); sel.addRange(r);
        return;
      }
      count += node.length;
    }
  }

  const codeEl = document.getElementById('code');
  codeEl.addEventListener('keydown', (e) => {
    const sel = window.getSelection();
    if (!sel.rangeCount || !sel.isCollapsed) return;
    const pos = getCaret(codeEl);
    const src = codeEl.innerText.replace(/\u00a0/g, ' ');
    if (e.key === 'Enter') {
      e.preventDefault();
      const lineStart = src.lastIndexOf('\n', pos - 1) + 1;
      const line = src.slice(lineStart, pos);
      const indent = line.match(/^\s*/)[0];
      const extra = line.trimEnd().endsWith(':') ? '    ' : '';
      document.execCommand('insertText', false, '\n' + indent + extra);
      updateGutter();
      return;
    }
    if (CLOSERS.includes(e.key) && src[pos] === e.key) {
      e.preventDefault(); sel.modify('move', 'forward', 'character'); return;
    }
    if (e.key in PAIRS) {
      e.preventDefault();
      document.execCommand('insertText', false, e.key + PAIRS[e.key]);
      sel.modify('move', 'backward', 'character');
      updateGutter();
    }
  });
  codeEl.addEventListener('input', () => {
    updateGutter();
    clearTimeout(timer);
    timer = setTimeout(() => {
      const pos = getCaret(codeEl);
      const src = codeEl.innerText.replace(/\u00a0/g, ' ');
      codeEl.innerHTML = highlight(src);
      setCaret(codeEl, pos);
    }, 250);
  });
  codeEl.addEventListener('paste', (e) => {
    e.preventDefault();
    const text = (e.clipboardData || window.clipboardData).getData('text');
    document.execCommand('insertText', false, text);
    updateGutter();
  });
  codeEl.addEventListener('scroll', () => {
    document.getElementById('gutter').scrollTop = codeEl.scrollTop;
  });

  // ===== Python =====
  let pyodide = null;
  let termActive = false;
  let termBlock = [];
  let stdinQueue = [];

  function log(s) { document.getElementById('out').textContent += s + '\n'; }
  function tlog(s) {
    const t = document.getElementById('term-out');
    t.textContent += s + '\n';
    t.scrollTop = t.scrollHeight;
  }
  function showErr(title, detail) {
    const out = document.getElementById('out');
    out.innerHTML = '';
    const t = document.createElement('div'); t.className = 'err'; t.textContent = title;
    const d = document.createElement('div'); d.textContent = detail;
    out.appendChild(t); out.appendChild(d);
  }

  function readStdin() {
    if (stdinQueue.length > 0) {
      const v = stdinQueue.shift();
      log('> ' + v);
      return v;
    }
    log('[تنبيه: لا يوجد إدخال متبقٍ لـ input()، أُعيد نص فارغ]');
    return '';
  }

  function loadStdinFromBox() {
    const raw = document.getElementById('stdin').value;
    stdinQueue = raw === '' ? [] : raw.split('\n');
  }

  async function termExec(src) {
    termActive = true;
    try {
      const result = await pyodide.runPythonAsync(src);
      if (result !== undefined && result !== null) tlog(String(result));
    } catch (e) {
      const lines = String(e).trim().split('\n');
      tlog(lines[lines.length - 1]);
    } finally { termActive = false; }
  }

  async function termRun() {
    const input = document.getElementById('term-in');
    const line = input.value;
    input.value = '';
    if (termBlock.length === 0) {
      if (!line.trim()) return;
      if (line.trimEnd().endsWith(':')) {
        termBlock.push(line);
        tlog('... ' + line);
        input.placeholder = '... اكتب أسطر الكتلة مسافة بادئة، ثم سطراً فارغاً للتنفيذ';
        return;
      }
      tlog('>>> ' + line);
      await termExec(line);
      return;
    }
    if (!line.trim()) {
      const block = termBlock.join('\n') + '\n';
      termBlock = [];
      input.placeholder = 'اكتب سطر Python ثم Enter';
      tlog('[تنفيذ الكتلة]');
      await termExec(block);
      return;
    }
    termBlock.push(line);
    tlog('... ' + line);
  }

  function loadScript(src) {
    return new Promise((resolve, reject) => {
      const s = document.createElement('script');
      s.src = src;
      s.onload = resolve;
      s.onerror = () => reject(new Error('تعذّر تحميل: ' + src));
      document.head.appendChild(s);
    });
  }

  async function init() {
    const LOCAL = 'file:///android_asset/flutter_assets/assets/pyodide/';
    const CDN = 'https://cdn.jsdelivr.net/pyodide/v0.25.1/full/';
    let source = 'من ملفات التطبيق';
    try {
      if (typeof loadPyodide !== 'function') throw new Error('محلي غير متاح');
      pyodide = await loadPyodide({ indexURL: LOCAL });
    } catch (localErr) {
      source = 'من الإنترنت (احتياط)';
      await loadScript(CDN + 'pyodide.js');
      pyodide = await loadPyodide({ indexURL: CDN });
    }
    pyodide.setStdout({ batched: (s) => { if (termActive) tlog(s); else log(s); } });
    pyodide.setStderr({ batched: (s) => { if (termActive) tlog(s); else log(s); } });
    pyodide.setStdin({ stdin: readStdin });
    const btn = document.getElementById('run');
    btn.disabled = false;
    btn.textContent = 'تشغيل';
    btn.onclick = runCode;
    document.getElementById('out').textContent = 'Python جاهز (' + source + ')';
    document.getElementById('term-out').textContent = 'طرفية Python جاهزة\n';
  }

  // رقم السطر يُؤخذ من آخر إشارة إلى كود المستخدم (<exec>)
  async function runCode() {
    errorLine = 0;
    updateGutter();
    document.getElementById('out').textContent = '';
    loadStdinFromBox();
    try {
      await pyodide.runPythonAsync(getCode());
    } catch (e) {
      const text = String(e);
      const lines = text.trim().split('\n');
      const frames = text.match(/File "<exec>", line (\d+)/g);
      let lineNo = null;
      if (frames && frames.length) {
        const m = frames[frames.length - 1].match(/line (\d+)/);
        lineNo = m ? m[1] : null;
      }
      errorLine = lineNo ? Number(lineNo) : 0;
      updateGutter();
      const last = lines[lines.length - 1];
      const title = lineNo ? 'خطأ في Python - السطر ' + lineNo : 'خطأ في Python';
      showErr(title, last + '\n\nالنص الأصلي:\n' + text);
      if (lineNo) tlog('خطأ في السطر ' + lineNo + ': ' + last);
    }
  }

  // ===== ربط الأزرار =====
  document.getElementById('pnew').onclick = createProject;
  document.getElementById('pcur').onclick = setCurrent;
  document.getElementById('pdel').onclick = deleteProject;
  document.getElementById('save').onclick = saveFile;
  document.getElementById('open').onclick = openFile;
  document.getElementById('new').onclick = newFile;
  document.getElementById('del').onclick = deleteFile;
  document.getElementById('ren').onclick = renameFile;
  document.getElementById('mkdir').onclick = newFolder;
  document.getElementById('exp').onclick = exportAll;
  document.getElementById('copyProj').onclick = copyProject;
  document.getElementById('impClip').onclick = importFromClipboard;
  document.getElementById('imp').onclick = importAll;
  document.getElementById('term-in').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') { e.preventDefault(); termRun(); }
  });

  setCode('name = input("اسمك: ")\nprint("مرحباً", name)\n');
  refreshProjects();
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
