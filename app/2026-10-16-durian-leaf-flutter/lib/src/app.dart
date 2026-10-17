import 'package:flutter/material.dart';

import 'classifier.dart';
import 'history_store.dart';
import 'theme.dart';
import 'ui/about_page.dart';
import 'ui/history_page.dart';
import 'ui/scan_page.dart';

class DurianLeafApp extends StatelessWidget {
  const DurianLeafApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'หมอใบทุเรียน',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final classifier = Classifier();
  final store = HistoryStore();
  final historyRevision = ValueNotifier<int>(0);
  int _tab = 0;

  @override
  void dispose() {
    classifier.dispose();
    historyRevision.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: [
        ScanPage(classifier: classifier, store: store, onSaved: () => historyRevision.value++),
        HistoryPage(store: store, revision: historyRevision),
        const AboutPage(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.photo_camera_outlined), selectedIcon: Icon(Icons.photo_camera), label: 'ตรวจใบ'),
          NavigationDestination(icon: Icon(Icons.history), label: 'ประวัติ'),
          NavigationDestination(icon: Icon(Icons.info_outline), selectedIcon: Icon(Icons.info), label: 'เกี่ยวกับ'),
        ],
      ),
    );
  }
}
