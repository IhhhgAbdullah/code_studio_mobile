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
  body { font-family: sans-serif; margin: 0; padding: 12px; background: #0D2B52; color: #fff; }
  textarea { width: 100%; height: 160px; box-sizing: border-box; font-family: monospace;
             font-size: 15px; direction: ltr; border: 2px solid #D4AF37; border-radius: 8px; padding: 8px; }
  button { width: 100%; margin-top: 8px; padding: 12px; font-size: 16px; border: none;
           border-radius: 8px; background: #D4AF37; color: #0D2B52; font-weight: bold; }
  pre { background: #111; color: #0f0; padding: 10px; border-radius: 8px; min-height: 80px;
        direction: ltr; white-space: pre-wrap; text-align: left; }
  .err { color: #ff6b6b; }
</style>
</head>
<body>
<textarea id="code">name = "Abdullah"
for i in range(3):
    print("مرحباً", name, i + 1)</textarea>
<button id="run" disabled>جاري تحميل Python...</button>
<pre id="out">المخرجات ستظهر هنا</pre>
<script>
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
  let pyodide = null;
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
      // Python errors: type, line number and message
      const text = String(e);
      const lines = text.trim().split('\n');
      const last = lines[lines.length - 1];
      const lineMatch = text.match(/line (\d+)/);
      const title = 'خطأ في Python' + (lineMatch ? ' - السطر ' + lineMatch[1] : '');
      showErr(title, last);
    }
  }
  init().catch(e => showErr('فشل التحميل', (e && e.message) ? e.message : String(e)));
</script>
</body>
</html>
''';

class PythonTestPage extends StatefulWidget {
  const PythonTestPage({super.key});

  @override
  State<PythonTestPage> createState() => _PythonTestPageState();
}

class _PythonTestPageState extends State<PythonTestPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(_pyHtml, baseUrl: 'https://localhost/');
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
