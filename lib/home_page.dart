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
  body { font-family: sans-serif; padding: 16px; color: #fff; }
  .header { margin-bottom: 16px; }
  .hello { font-size: 20px; font-weight: bold; color: #fff; }
  .sub { font-size: 13px; color: #cfd8e6; margin-top: 4px; }
  .badge { display: inline-block; margin-top: 10px; padding: 4px 12px; border-radius: 20px;
           background: rgba(212,175,55,0.15); border: 1px solid #D4AF37; color: #D4AF37; font-size: 12px; }
  .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
  .card {
    background: linear-gradient(160deg, #1A3D6E 0%, #132F5A 100%);
    border: 1px solid rgba(212,175,55,0.7); border-radius: 18px;
    padding: 12px; min-height: 130px; box-shadow: 0 6px 16px rgba(0,0,0,0.35);
    display: flex; flex-direction: column;
  }
  .icon { width: 36px; height: 36px; border-radius: 10px; background: #D4AF37; color: #0D2B52;
          font-weight: bold; font-size: 13px; display: flex; align-items: center;
          justify-content: center; margin-bottom: 8px; }
  .title { color: #fff; font-weight: bold; font-size: 14px; direction: ltr; text-align: left; word-break: break-all; }
  .preview { margin-top: 6px; font-family: monospace; font-size: 11px; color: #9fb3d1; direction: ltr;
             text-align: left; white-space: pre-wrap; overflow: hidden; max-height: 60px; }
  .empty { text-align: center; color: #cfd8e6; margin-top: 60px; line-height: 1.8; }
  .empty b { color: #D4AF37; }
</style>
</head>
<body>
<div class="header">
  <div class="hello">مرحباً بك 👋</div>
  <div class="sub">مشاريعك البرمجية في مكان واحد</div>
  <div class="badge" id="count">0 ملفات</div>
</div>
<div class="grid" id="grid"></div>
<div class="empty" id="empty">لا توجد ملفات بعد.<br>اكتب كوداً في <b>المحرر</b> واحفظه، وسيظهر هنا.</div>
<script>
  function render() {
    let files = {};
    try { files = JSON.parse(localStorage.getItem('cs_files') || '{}'); } catch (e) { files = {}; }
    const grid = document.getElementById('grid');
    grid.innerHTML = '';
    const names = Object.keys(files).sort();
    document.getElementById('empty').style.display = names.length ? 'none' : 'block';
    document.getElementById('count').textContent = names.length + (names.length === 1 ? ' ملف' : ' ملفات');
    names.forEach(function (n) {
      const card = document.createElement('div');
      card.className = 'card';
      const ic = document.createElement('div');
      ic.className = 'icon';
      ic.textContent = 'Py';
      const t = document.createElement('div');
      t.className = 'title';
      t.textContent = n;
      const p = document.createElement('div');
      p.className = 'preview';
      p.textContent = String(files[n] || '').split('\\n').slice(0, 4).join('\\n');
      card.appendChild(ic);
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
