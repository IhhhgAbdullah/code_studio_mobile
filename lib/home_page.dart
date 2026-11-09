import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String _homeHtml = '''
<!DOCTYPE html>
<html dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  * { box-sizing: border-box; }
  html, body { background: transparent; margin: 0; }
  body { font-family: sans-serif; padding: 12px; color: #fff; }
  h3 { color: #D4AF37; margin: 4px 0 12px; }
  .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
  .card {
    background: #132F5A; border: 1px solid #D4AF37; border-radius: 14px;
    padding: 12px; min-height: 120px;
  }
  .title { color: #D4AF37; font-weight: bold; margin-bottom: 6px; direction: ltr;
           text-align: left; word-break: break-all; }
  .preview { font-family: monospace; font-size: 12px; color: #cfd8e6; direction: ltr;
             text-align: left; white-space: pre-wrap; overflow: hidden; max-height: 80px; }
  .empty { text-align: center; color: #cfd8e6; margin-top: 60px; }
</style>
</head>
<body>
<h3>مشاريعي</h3>
<div class="grid" id="grid"></div>
<div class="empty" id="empty">لا توجد ملفات بعد. اكتب كوداً في المحرر واحفظه.</div>
<script>
  function render() {
    let files = {};
    try { files = JSON.parse(localStorage.getItem('cs_files') || '{}'); } catch (e) { files = {}; }
    const grid = document.getElementById('grid');
    grid.innerHTML = '';
    const names = Object.keys(files).sort();
    document.getElementById('empty').style.display = names.length ? 'none' : 'block';
    names.forEach(function (n) {
      const card = document.createElement('div');
      card.className = 'card';
      const t = document.createElement('div');
      t.className = 'title';
      t.textContent = n;
      const p = document.createElement('div');
      p.className = 'preview';
      p.textContent = String(files[n] || '').split('\\n').slice(0, 5).join('\\n');
      card.appendChild(t);
      card.appendChild(p);
      card.onclick = function () { Flutter.postMessage(n); };
      grid.appendChild(card);
    });
  }
  function reloadList() { render(); }
  render();
</script>
</body>
</html>
''';

final GlobalKey<HomePageState> homeKey = GlobalKey<HomePageState>();

class HomePage extends StatefulWidget {
  final void Function(String name) onOpen;
  const HomePage({super.key, required this.onOpen});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'Flutter',
        onMessageReceived: (m) => widget.onOpen(m.message),
      )
      ..loadHtmlString(_homeHtml, baseUrl: 'https://localhost/');
  }

  void reload() => _controller.runJavaScript('reloadList()');

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
