import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

import 'bank/eb_client.dart';
import 'format.dart';
import 'store.dart';

const String _morningTask = 'pecule.morning';
const String _channelId = 'daily_balance';
const String _channelName = 'Solde du matin';

final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
bool _notifReady = false;

Future<void> _initNotifications() async {
  if (_notifReady) return;
  await _notifications.initialize(
    const InitializationSettings(android: AndroidInitializationSettings('ic_stat_pecule')),
  );
  _notifReady = true;
}

/// Demande l'autorisation d'afficher des notifications (Android 13+). Renvoie false si refusée.
Future<bool> requestNotificationPermission() async {
  await _initNotifications();
  final android =
      _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  final granted = await android?.requestNotificationsPermission();
  return granted ?? true;
}

Future<void> _show(String title, String body) async {
  await _initNotifications();
  await _notifications.show(
    1,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Ton solde et les mouvements de la veille, chaque matin',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        color: Color(0xFF5B5FEF),
      ),
    ),
  );
}

/// Synchro + notification du solde. Utilisée chaque matin en arrière-plan, et par « Tester maintenant ».
Future<void> runMorningSync({bool force = false}) async {
  await store.init();
  if (!store.dailyNotif && !force) return;

  var newOps = 0;
  if (store.bankConnected && !store.bankExpired) {
    try {
      newOps = (await store.syncBank()).added;
    } on EbException catch (e) {
      if (e.needsReconnect) {
        await _show('Pécule · accès bancaire expiré', 'Ouvre Pécule pour reconnecter ta banque.');
        return;
      }
      // Coupure réseau : on affiche quand même le dernier solde connu.
    }
  } else if (store.bankExpired) {
    await _show('Pécule · accès bancaire expiré', 'Ouvre Pécule pour reconnecter ta banque.');
    return;
  }

  final balance = store.currentBalance;
  if (balance == null) return;
  final last = store.lastNotifiedBalance;
  final delta = last == null ? null : balance - last;
  await store.setLastNotifiedBalance(balance);

  final parts = <String>[
    if (delta != null && delta != 0) '${signedMoney(delta)} depuis hier',
    if (newOps > 0) '$newOps nouvelle${newOps > 1 ? 's' : ''} opération${newOps > 1 ? 's' : ''}',
  ];
  await _show(
    'Solde ${store.ebAspsp ?? 'du compte'} : ${money(balance)}',
    parts.isEmpty ? 'Aucun mouvement depuis hier.' : parts.join(' · '),
  );
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    try {
      await runMorningSync();
    } catch (_) {
      // On ne fait jamais échouer la tâche : elle reviendra demain.
    }
    return true;
  });
}

/// À appeler une fois au démarrage de l'app.
Future<void> initBackground() async {
  await Workmanager().initialize(callbackDispatcher);
}

/// (Re)programme la synchro du matin vers [hour] h. Android peut la décaler un peu pour économiser la batterie.
Future<void> scheduleMorning(int hour) async {
  final now = DateTime.now();
  var next = DateTime(now.year, now.month, now.day, hour);
  if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
  await Workmanager().cancelByUniqueName(_morningTask);
  await Workmanager().registerPeriodicTask(
    _morningTask,
    _morningTask,
    frequency: const Duration(hours: 24),
    initialDelay: next.difference(now),
    constraints: Constraints(networkType: NetworkType.connected),
  );
}

Future<void> cancelMorning() => Workmanager().cancelByUniqueName(_morningTask);
