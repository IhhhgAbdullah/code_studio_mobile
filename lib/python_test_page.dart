import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
      ..loadHtmlString('''
        <html dir="rtl">
          <body style="font-family: sans-serif; text-align: center; padding-top: 40px;">
            <h2>Python جاهز</h2>
          </body>
        </html>
      ''');
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
