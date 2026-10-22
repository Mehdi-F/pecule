import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'store.dart';
import 'ui/screens/activities.dart';
import 'ui/screens/analysis.dart';
import 'ui/screens/settings.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  Intl.defaultLocale = 'fr_FR';
  runApp(const PeculeApp());
}

class PeculeApp extends StatelessWidget {
  const PeculeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pécule',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
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
  late final Future<void> _init = store.init();
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _init,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Erreur au démarrage : ${snap.error}', textAlign: TextAlign.center),
              ),
            ),
          );
        }
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          body: IndexedStack(
            index: _index,
            children: const [ActivitiesScreen(), AnalysisScreen(), SettingsScreen()],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                label: 'Activités',
              ),
              NavigationDestination(
                icon: Icon(Icons.pie_chart_outline_rounded),
                selectedIcon: Icon(Icons.pie_chart_rounded, color: AppColors.primary),
                label: 'Analyse',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune_rounded, color: AppColors.primary),
                label: 'Réglages',
              ),
            ],
          ),
        );
      },
    );
  }
}
