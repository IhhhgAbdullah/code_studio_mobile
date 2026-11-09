import 'package:flutter/material.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final _controller = TextEditingController(
    text: "print('مرحباً من Code Studio')\n",
  );
  String _output = '';

  void _run() {
    final lines = _controller.text.split('\n').length;
    setState(() {
      _output = 'تم استلام $lines سطر.\n(التشغيل الفعلي يُضاف في المرحلة القادمة)';
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Expanded(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'اكتب الكود هنا',
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _run,
              icon: const Icon(Icons.play_arrow),
              label: const Text('تشغيل'),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 120,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.secondary),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: Text(_output.isEmpty ? 'المخرجات ستظهر هنا' : _output),
            ),
          ),
        ],
      ),
    );
  }
}
