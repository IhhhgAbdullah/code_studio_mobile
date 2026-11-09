import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'editor_page.dart';
import 'python_test_page.dart';

final ValueNotifier<Locale> localeNotifier = ValueNotifier(const Locale('ar'));
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

const navy = Color(0xFF0D2B52);
const gold = Color(0xFFD4AF37);

void main() => runApp(const CodeStudioApp());

class CodeStudioApp extends StatelessWidget {
  const CodeStudioApp({super.key});

  ThemeData _theme(Brightness brightness) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: navy,
          brightness: brightness,
        ).copyWith(secondary: gold),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([localeNotifier, themeNotifier]),
      builder: (context, _) => MaterialApp(
        title: 'Code Studio Mobile',
        debugShowCheckedModeBanner: false,
        locale: localeNotifier.value,
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: themeNotifier.value,
        home: const HomeShell(),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _titles = ['الرئيسية', 'المحرر', 'الإعدادات'];

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _PlaceholderPage(text: 'مشاريعك ستظهر هنا'),
      const PythonTestPage(),
      const _SettingsPage(),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.code), label: 'المحرر'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'الإعدادات'),
        ],
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String text;
  const _PlaceholderPage({required this.text});

  @override
  Widget build(BuildContext context) =>
      Center(child: Text(text, style: Theme.of(context).textTheme.titleMedium));
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: SwitchListTile(
            title: const Text('الوضع الداكن'),
            value: themeNotifier.value == ThemeMode.dark,
            onChanged: (dark) =>
                themeNotifier.value = dark ? ThemeMode.dark : ThemeMode.light,
          ),
        ),
        Card(
          child: SwitchListTile(
            title: const Text('English interface'),
            value: localeNotifier.value.languageCode == 'en',
            onChanged: (en) =>
                localeNotifier.value = Locale(en ? 'en' : 'ar'),
          ),
        ),
      ],
    );
  }
}
