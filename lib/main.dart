import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'background.dart';
import 'bank/eb_client.dart';
import 'store.dart';
import 'ui/screens/activities.dart';
import 'ui/screens/analysis.dart';
import 'ui/screens/settings.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  try {
    await initBackground();
  } catch (_) {
    // pas de tâches de fond disponibles : l'app fonctionne quand même
  }
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
      scaffoldMessengerKey: messengerKey,
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
  late final Future<void> _init = store.init().then((_) => _autoSync());

  /// Synchro discrète à l'ouverture si la dernière date de plus de 6 h.
  void _autoSync() {
    if (store.dailyNotif) scheduleMorning(store.dailyNotifHour).catchError((_) {});
    final last = store.ebLastSync;
    if (!store.bankConnected || store.bankExpired) return;
    if (last != null && DateTime.now().difference(last) < const Duration(hours: 6)) return;
    store.syncBank().catchError((_) => const ImportSummary(0, 0, 'Banque', false));
  }
  int _index = 0;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    // Retour pecule://auth?code=… après validation dans l'appli de la banque.
    _linkSub = _appLinks.uriLinkStream.listen(_onLink, onError: (_) {});
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _onLink(uri);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  Future<void> _onLink(Uri uri) async {
    if (uri.scheme != 'pecule') return;
    await _init;
    final messenger = messengerKey.currentState;
    try {
      final r = await store.completeBankAuth(uri);
      if (r != null) {
        messenger?.showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Banque connectée · ${r.added} opération${r.added > 1 ? 's' : ''} récupérée${r.added > 1 ? 's' : ''}.'),
        ));
      }
    } on EbException catch (e) {
      messenger?.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        content: Text(e.message),
      ));
    }
  }

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
