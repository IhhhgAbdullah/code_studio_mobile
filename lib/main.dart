import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'game_page.dart';
import 'home_page.dart';
import 'match3_page.dart';
import 'puzzle_page.dart';
import 'python_test_page.dart';
import 'three_page.dart';

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

  static const _titles = [
    'الرئيسية', 'المحرر', 'الألعاب', 'Match-3', 'ألغاز', '3D', 'الإعدادات',
  ];

  void _openInEditor(String name) {
    setState(() => _index = 1);
    editorKey.currentState?.openFile(name);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(key: homeKey, onOpen: _openInEditor),
      PythonTestPage(key: editorKey),
      const GamePage(),
      const Match3Page(),
      const PuzzlePage(),
      const ThreePage(),
      const _SettingsPage(),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D2B52), Color(0xFF061429)],
          ),
        ),
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          if (i == 0) homeKey.currentState?.reload();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.code), label: 'المحرر'),
          NavigationDestination(icon: Icon(Icons.sports_esports_outlined), label: 'الألعاب'),
          NavigationDestination(icon: Icon(Icons.grid_on_outlined), label: 'Match-3'),
          NavigationDestination(icon: Icon(Icons.extension_outlined), label: 'ألغاز'),
          NavigationDestination(icon: Icon(Icons.view_in_ar_outlined), label: '3D'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'الإعدادات'),
        ],
      ),
    );
  }
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
