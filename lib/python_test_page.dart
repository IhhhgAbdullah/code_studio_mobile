import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String _pyHtml = '''
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
  textarea {
    width: 100%; height: 170px; font-family: monospace; font-size: 15px;
    direction: ltr; background: #0A1F3D; color: #fff; border: none;
    border-radius: 10px; padding: 10px; resize: vertical;
  }
  input, select {
    width: 100%; padding: 10px; margin-bottom: 8px; border-radius: 10px;
    border: 1px solid #D4AF37; background: #0A1F3D; color: #fff; font-size: 15px;
  }
  .row { display: flex; gap: 8px; }
  .row > * { flex: 1; }
  button {
    width: 100%; padding: 13px; font-size: 16px; border: none;
    border-radius: 10px; background: #D4AF37; color: #0D2B52; font-weight: bold;
  }
  button.alt { background: #2A4A7A; color: #fff; }
  button:disabled { opacity: 0.6; }
  pre {
    background: #0A1F3D; color: #7CFC7C; padding: 10px; border-radius: 10px;
    min-height: 90px; margin: 0; direction: ltr; white-space: pre-wrap; text-align: left;
    font-family: monospace; font-size: 14px;
  }
  .err { color: #ff6b6b; font-weight: bold; }
  .msg { color: #D4AF37; font-size: 13px; margin-top: 6px; }
</style>
</head>
<body>
<div class="card">
  <div class="card-title">الكود</div>
  <input id="fname" value="main.py" placeholder="اسم الملف">
  <textarea id="code">name = "Abdullah"
for i in range(3):
    print("مرحباً", name, i + 1)</textarea>
  <div class="row" style="margin-top:8px">
    <button id="save" class="alt">حفظ</button>
    <button id="open" class="alt">فتح</button>
  </div>
  <div class="row" style="margin-top:8px">
    <select id="files"></select>
  </div>
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
<script>
  const KEY = 'cs_files';

  function getFiles() {
    try { return JSON.parse(localStorage.getItem(KEY) || '{}'); }
    catch (e) { return {}; }
  }

  function refreshList(selected) {
    const sel = document.getElementById('files');
    const files = getFiles();
    sel.innerHTML = '';
    Object.keys(files).sort().forEach(n => {
      const o = document.createElement('option');
      o.value = n;
      o.textContent = n;
      sel.appendChild(o);
    });
    if (selected) sel.value = selected;
  }

  function msg(t) {
    document.getElementById('msg').textContent = t;
  }

  function saveFile() {
    let name = document.getElementById('fname').value.trim() || 'main.py';
    if (!name.endsWith('.py')) name += '.py';
    const files = getFiles();
    files[name] = document.getElementById('code').value;
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
    document.getElementById('code').value = files[name];
    document.getElementById('fname').value = name;
    msg('تم فتح: ' + name);
  }

  function openByName(n) {
    refreshList(n);
    openFile();
  }

  let pyodide = null;

  function log(s) {
    document.getElementById('out').textContent += s + '\\n';
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

  async function init() {
    if (typeof loadPyodide !== 'function') {
      throw new Error('ملف Pyodide لم يُحمَّل. تأكد من اتصال الإنترنت.');
    }
    pyodide = await loadPyodide({
      indexURL: 'https://cdn.jsdelivr.net/pyodide/v0.25.1/full/'
    });
    pyodide.setStdout({ batched: (s) => log(s) });
    pyodide.setStderr({ batched: (s) => log(s) });
    const btn = document.getElementById('run');
    btn.disabled = false;
    btn.textContent = 'تشغيل';
    btn.onclick = runCode;
    document.getElementById('out').textContent = 'Python جاهز';
  }

  async function runCode() {
    document.getElementById('out').textContent = '';
    try {
      await pyodide.runPythonAsync(document.getElementById('code').value);
    } catch (e) {
      const text = String(e);
      const lines = text.trim().split('\\n');
      const last = lines[lines.length - 1];
      const lineMatch = text.match(/line (\\d+)/);
      const title = 'خطأ في Python' + (lineMatch ? ' - السطر ' + lineMatch[1] : '');
      showErr(title, last);
    }
  }

  document.getElementById('save').onclick = saveFile;
  document.getElementById('open').onclick = openFile;
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
