import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
        themeMode: themeNotifier.value
