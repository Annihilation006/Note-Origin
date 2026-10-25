import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'data/db.dart';
import 'data/store.dart';
import 'pages/today_page.dart';
import 'pages/notes_page.dart';
import 'pages/ledger_page.dart';
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

  void _go(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    // 笔记优先：今日/笔记/账本/设置
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          TodayPage(onNavigate: _go),
          const NotesPage(),
          const LedgerPage(),
          const SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: '今日'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: '笔记'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: '账本'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
