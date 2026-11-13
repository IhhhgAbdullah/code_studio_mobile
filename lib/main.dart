import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'design_page.dart';
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
  int _tab = 0;
  int _sub = 0;

  static const _tabs = ['الرئيسية', 'الألعاب', 'التصميم', 'المحرر'];

  // كل صفحة فرعية: اسم العرض، ومعرّف الصفحة
  static const _subs = {
    0: [['الرئيسية', 'home']],
    1: [
      ['الذاكرة', 'memory'],
      ['جمع العملات', 'coins'],
      ['تجنب العوائق', 'dodge'],
      ['Match-3', 'match3'],
      ['ألغاز', 'puzzle'],
      ['الفيزياء 3D', 'physics'],
      ['مشهد 3D', 'scene3d'],
    ],
    2: [['شاشات', 'screens'], ['واجهة لعبة', 'gameui'], ['قوالب', 'wizard']],
    3: [['Python', 'python'], ['الإعدادات', 'settings']],
  };

  void _openInEditor(String name) {
    setState(() { _tab = 3; _sub = 0; });
    editorKey.currentState?.openFile(name);
  }

  Widget _page() {
    final id = _subs[_tab]![_sub][1];
    switch (id) {
      case 'home': return HomePage(key: homeKey, onOpen: _openInEditor);
      case 'memory': return const GamePage(template: 'memory');
      case 'coins': return const GamePage(template: 'coins');
      case 'dodge': return const GamePage(template: 'dodge');
      case 'match3': return const Match3Page();
      case 'puzzle': return const PuzzlePage();
      case 'physics':
      case 'scene3d': return const ThreePage();
      case 'screens':
      case 'gameui':
      case 'wizard': return const DesignPage();
      case 'python': return PythonTestPage(key: editorKey);
      case 'settings': return const _SettingsPage();
      default: return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final subs = _subs[_tab]!;
    return Scaffold(
      appBar: AppBar(title: Text(_tabs[_tab])),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D2B52), Color(0xFF061429)],
          ),
        ),
        child: Column(
          children: [
            if (subs.length > 1)
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  children: List.generate(subs.length, (i) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text(subs[i][0]),
                      selected: _sub == i,
                      onSelected: (_) => setState(() => _sub = i),
                    ),
                  )),
                ),
              ),
            Expanded(child: _page()),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) {
          setState(() { _tab = i; _sub = 0; });
          if (i == 0) homeKey.currentState?.reload();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.sports_esports_outlined), label: 'الألعاب'),
          NavigationDestination(icon: Icon(Icons.dashboard_customize_outlined), label: 'التصميم'),
          NavigationDestination(icon: Icon(Icons.code), label: 'المحرر'),
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
