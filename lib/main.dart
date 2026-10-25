import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'data/db.dart';
import 'data/store.dart';
import 'pages/home_page.dart';
import 'pages/notes_page.dart';
import 'pages/stats_page.dart';
import 'pages/budget_page.dart';
import 'pages/settings_page.dart';

// 桌面端要换sqflite的ffi实现，放main里最早做
void _setupDesktopDb() {
  // web不管了，本来到不了web
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    try {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    } catch (e) {
      debugPrint('ffi db init失败: $e'); // 起不来再说
    }
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _setupDesktopDb();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    // 平板横着也行吧，算了先锁竖屏
  ]);
  runApp(const NoteOriginApp());
}

const _kSeed = Color(0xFF4F6CF5);

class NoteOriginApp extends StatelessWidget {
  const NoteOriginApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Db>.value(value: Db.instance),
        ChangeNotifierProvider(create: (_) => AppStore(Db.instance)..bootstrap()),
      ],
      child: DynamicColorBuilder(
        builder: (lightDynamic, darkDynamic) {
          // 有壁纸取色就用（安卓12+），没有就种子色。全平台同一套Material3语言
          final light = lightDynamic ?? ColorScheme.fromSeed(seedColor: _kSeed);
          final dark = darkDynamic ?? ColorScheme.fromSeed(seedColor: _kSeed, brightness: Brightness.dark);
          return MaterialApp(
            title: 'Note Origin',
            theme: ThemeData(
              colorScheme: light,
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: dark,
              useMaterial3: true,
            ),
            themeMode: ThemeMode.system,
            home: const RootScaffold(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  int _tab = 0;

  final _pages = const [
    HomePage(),
    StatsPage(),
    BudgetPage(),
    NotesPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: '明细'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: '统计'),
          NavigationDestination(icon: Icon(Icons.savings_outlined), selectedIcon: Icon(Icons.savings), label: '预算'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: '笔记'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
