import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:workmanager/workmanager.dart';

import 'bank/eb_client.dart';
import 'format.dart';
import 'store.dart';
import 'text_utils.dart';

/// Tâche périodique (toutes les heures environ) : à chaque passage, elle vérifie s'il est
/// l'heure de la notification du jour et si elle n'a pas encore été envoyée. Ainsi, même si
/// Android retarde ou saute un passage (mode veille, économie de batterie), la notification
/// part au passage suivant au lieu d'être perdue pour la journée.
const String _checkTask = 'pecule.check';
const String _legacyTask = 'pecule.morning';
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

/// Pécule est-il exempté de l'optimisation de batterie ?
Future<bool> isBatteryUnrestricted() async {
  try {
    return await Permission.ignoreBatteryOptimizations.isGranted;
  } catch (_) {
    return false;
  }
}

/// Demande à Android de ne pas restreindre Pécule en arrière-plan.
Future<bool> requestBatteryUnrestricted() async {
  try {
    return (await Permission.ignoreBatteryOptimizations.request()).isGranted;
  } catch (_) {
    return false;
  }
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

/// Synchro + notification du solde. Appelée par la tâche de fond et par « Tester maintenant ».
Future<String> runMorningSync({bool force = false}) async {
  await store.init();
  if (!store.dailyNotif && !force) return 'désactivé';

  var newOps = 0;
  var note = '';
  if (store.bankExpired) {
    await _show('Pécule · accès bancaire expiré', 'Ouvre Pécule pour reconnecter ta banque.');
    if (!force) await store.markNotifiedToday();
    return 'accès bancaire expiré';
  }
  if (store.bankConnected) {
    try {
      newOps = (await store.syncBank()).added;
    } on EbException catch (e) {
      if (e.needsReconnect) {
        await _show('Pécule · accès bancaire expiré', 'Ouvre Pécule pour reconnecter ta banque.');
        if (!force) await store.markNotifiedToday();
        return 'reconnexion nécessaire (${e.status})';
      }
      note = 'synchro échouée : ${e.message}';
    } catch (e) {
      note = 'synchro échouée : $e';
    }
  }

  final balance = store.currentBalance;
  if (balance == null) return 'pas de solde connu';
  final last = store.lastNotifiedBalance;
  final delta = last == null ? null : balance - last;
  await store.setLastNotifiedBalance(balance);

  final parts = <String>[
    if (delta != null && delta != 0) '${signedMoney(delta)} depuis hier',
    if (newOps > 0) '$newOps nouvelle${newOps > 1 ? 's' : ''} opération${newOps > 1 ? 's' : ''}',
    if (note.isNotEmpty) 'synchro impossible, dernier solde connu',
  ];
  await _show(
    'Solde ${store.ebAspsp ?? 'du compte'} : ${money(balance)}',
    parts.isEmpty ? 'Aucun mouvement depuis hier.' : parts.join(' · '),
  );
  if (!force) await store.markNotifiedToday();
  return note.isEmpty ? 'notification envoyée ($newOps nouvelle(s) opération(s))' : 'notification envoyée, $note';
}

/// Passage de la tâche de fond : n'envoie la notification qu'une fois par jour, après l'heure choisie.
Future<void> _check() async {
  await store.init();
  if (!store.dailyNotif) return;
  final now = DateTime.now();
  final today = dateOnly(now);
  if (now.hour < store.dailyNotifHour) {
    await store.logBackground('vérification ${two(now.hour)}:${two(now.minute)} : trop tôt');
    return;
  }
  final last = store.lastNotifiedDay;
  if (last != null && !last.isBefore(today)) return; // déjà envoyée aujourd'hui
  final result = await runMorningSync();
  await store.logBackground(result);
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    try {
      await _check();
    } catch (e) {
      try {
        await store.logBackground('erreur : $e');
      } catch (_) {}
    }
    return true; // jamais d'échec : le prochain passage réessaiera
  });
}

/// À appeler une fois au démarrage de l'app.
Future<void> initBackground() async {
  await Workmanager().initialize(callbackDispatcher);
}

/// Programme la vérification horaire si elle ne l'est pas déjà (sans réinitialiser son minuteur).
Future<void> ensureMorningScheduled() async {
  await Workmanager().cancelByUniqueName(_legacyTask); // ancienne tâche quotidienne, peu fiable
  await Workmanager().registerPeriodicTask(
    _checkTask,
    _checkTask,
    frequency: const Duration(hours: 1),
    constraints: Constraints(networkType: NetworkType.connected),
  );
}

/// Compatibilité avec l'écran Réglages : l'heure est relue à chaque passage, il suffit
/// de s'assurer que la vérification est programmée.
Future<void> scheduleMorning(int hour) => ensureMorningScheduled();

Future<void> cancelMorning() async {
  await Workmanager().cancelByUniqueName(_checkTask);
  await Workmanager().cancelByUniqueName(_legacyTask);
}
