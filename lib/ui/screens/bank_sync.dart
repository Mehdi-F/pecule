import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../bank/eb_client.dart';
import '../../store.dart';
import '../theme.dart';
import '../widgets.dart';

const String bankRedirectUrl = 'https://localhost/pecule';
const String bankCountry = 'FR';

String _fmt(DateTime d) => DateFormat('d MMM y à HH:mm', 'fr_FR').format(d);
String syncAgo(DateTime d) {
  final m = DateTime.now().difference(d).inMinutes;
  if (m < 1) return 'à l\'instant';
  if (m < 60) return 'il y a $m min';
  if (m < 24 * 60) return 'il y a ${m ~/ 60} h';
  return 'le ${DateFormat('d MMM', 'fr_FR').format(d)}';
}

String _fmtDay(DateTime d) => DateFormat('d MMMM y', 'fr_FR').format(d);

/// Synchro manuelle avec retour à l'utilisateur.
Future<void> runBankSync(BuildContext context) async {
  try {
    final r = await store.syncBank();
    if (!context.mounted) return;
    toast(
      context,
      r.added == 0
          ? 'Déjà à jour.'
          : '${r.added} nouvelle${r.added > 1 ? 's' : ''} opération${r.added > 1 ? 's' : ''}.',
    );
  } on EbException catch (e) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Synchro impossible'),
        content: Text(e.needsReconnect
            ? 'L\'accès à ta banque a expiré ou a été refusé. Reconnecte-la depuis Réglages → Synchro bancaire.\n\n${e.message}'
            : e.message),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }
}

class BankSyncScreen extends StatefulWidget {
  const BankSyncScreen({super.key});

  @override
  State<BankSyncScreen> createState() => _BankSyncScreenState();
}

class _BankSyncScreenState extends State<BankSyncScreen> {
  bool _busy = false;
  String? _status;

  Future<void> _guard(String status, Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _status = status;
    });
    try {
      await action();
    } on EbException catch (e) {
      if (mounted) await _error(e.message);
    } catch (e) {
      if (mounted) await _error('Erreur inattendue : $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = null;
        });
      }
    }
  }

  Future<void> _error(String message) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Oups'),
          content: Text(message),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );

  Future<void> _importKey() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    if (res == null || res.files.isEmpty || !mounted) return;
    final f = res.files.first;
    List<int>? bytes = f.bytes;
    if (bytes == null && f.path != null) bytes = await File(f.path!).readAsBytes();
    if (bytes == null || !mounted) return;
    final pem = utf8.decode(bytes, allowMalformed: true);
    if (!pem.contains('PRIVATE KEY')) {
      await _error('Ce fichier n\'est pas une clé privée. Choisis le fichier .pem téléchargé à la création de l\'application Enable Banking.');
      return;
    }
    final guess = RegExp(r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
        .firstMatch(f.name)
        ?.group(0);
    final appId = await _askAppId(guess);
    if (appId == null || appId.trim().isEmpty || !mounted) return;
    await _guard('Vérification de la clé…', () => store.setBankApp(appId, pem));
  }

  Future<String?> _askAppId(String? guess) {
    final ctrl = TextEditingController(text: guess ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Identifiant de l\'application'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Application ID',
            helperText: 'Visible dans le Control Panel Enable Banking (c\'est aussi le nom du fichier .pem).',
            helperMaxLines: 3,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Valider')),
        ],
      ),
    );
  }

  Future<void> _connect() async {
    final client = store.bankClient;
    List<Map<String, dynamic>> banks = const [];
    await _guard('Liste des banques…', () async => banks = await client.aspsps(bankCountry));
    if (!mounted || banks.isEmpty) return;
    final bank = await _pickBank(banks);
    if (bank == null || !mounted) return;
    final name = bank['name'] as String;
    final maxSeconds = (bank['maximum_consent_validity'] as num?)?.toInt() ?? 180 * 24 * 3600;
    final validUntil = DateTime.now().add(Duration(seconds: min(maxSeconds, 180 * 24 * 3600) - 3600));
    final state = DateTime.now().microsecondsSinceEpoch.toString();

    String? url;
    await _guard('Préparation de la connexion…', () async {
      url = await client.startAuth(
        aspspName: name,
        country: bankCountry,
        validUntil: validUntil,
        redirectUrl: bankRedirectUrl,
        state: state,
      );
    });
    if (url == null || !mounted) return;
    final back = await Navigator.of(context).push<Uri>(
      MaterialPageRoute(builder: (_) => BankAuthScreen(url: Uri.parse(url!), bankName: name)),
    );
    if (back == null || !mounted) return;
    final code = back.queryParameters['code'];
    if (code == null) {
      await _error('Connexion annulée par la banque (${back.queryParameters['error'] ?? 'sans détail'}).');
      return;
    }

    Map<String, dynamic>? session;
    await _guard('Ouverture de la session…', () async => session = await client.createSession(code));
    final s = session;
    if (s == null || !mounted) return;
    final accounts = (s['accounts'] is List)
        ? (s['accounts'] as List).whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];
    if (accounts.isEmpty) {
      await _error('La banque n\'a partagé aucun compte.');
      return;
    }
    final account = accounts.length == 1 ? accounts.first : await _pickAccount(accounts);
    if (account == null || !mounted) return;
    final access = s['access'];
    final until = access is Map ? DateTime.tryParse('${access['valid_until']}') : null;
    await store.saveBankSession(
      sessionId: '${s['session_id']}',
      accountUid: '${account['uid']}',
      accountName: _accountLabel(account),
      aspsp: name,
      validUntil: until ?? validUntil,
    );
    if (!mounted) return;
    await _guard('Première synchro (jusqu\'à un an d\'historique)…', () async {
      final r = await store.syncBank();
      if (mounted) {
        toast(context, '${r.added} opérations récupérées${r.duplicates > 0 ? ', ${r.duplicates} déjà présentes' : ''}.');
      }
    });
  }

  String _accountLabel(Map<String, dynamic> a) {
    final name = (a['name'] ?? a['product'] ?? 'Compte').toString();
    final id = a['account_id'];
    final iban = id is Map ? id['iban']?.toString() : null;
    return iban != null && iban.length > 4 ? '$name ·•${iban.substring(iban.length - 4)}' : name;
  }

  Future<Map<String, dynamic>?> _pickAccount(List<Map<String, dynamic>> accounts) => showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Quel compte suivre ?'),
          children: [
            for (final a in accounts)
              SimpleDialogOption(onPressed: () => Navigator.pop(ctx, a), child: Text(_accountLabel(a))),
          ],
        ),
      );

  Future<Map<String, dynamic>?> _pickBank(List<Map<String, dynamic>> banks) {
    var query = 'LCL';
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final q = query.toLowerCase();
          final shown = banks.where((b) => '${b['name']}'.toLowerCase().contains(q)).toList();
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: Column(
              children: [
                TextFormField(
                  initialValue: query,
                  autofocus: false,
                  onChanged: (v) => setSt(() => query = v),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Ta banque'),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: [
                      for (final b in shown)
                        ListTile(
                          title: Text('${b['name']}'),
                          subtitle: b['beta'] == true ? const Text('bêta') : null,
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.pop(ctx, b),
                        ),
                      if (shown.isEmpty)
                        const Padding(padding: EdgeInsets.all(24), child: Text('Aucune banque trouvée.')),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Synchro bancaire', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
          ),
          body: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  const SectionTitle('1 · APPLICATION ENABLE BANKING'),
                  AppCard(child: store.hasBankApp ? _appReady() : _appSetup()),
                  const SectionTitle('2 · CONNEXION À TA BANQUE'),
                  AppCard(child: _connection()),
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Pécule parle directement à Enable Banking depuis ce téléphone, en lecture seule. '
                      'La clé de ton application reste sur le téléphone. L\'accès à la banque est à renouveler '
                      'tous les 180 jours environ (règle européenne DSP2).',
                      style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
              if (_busy)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black26,
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(_status ?? 'Un instant…'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _appSetup() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Dans le Control Panel Enable Banking, crée une application Production avec la redirect URL '
            '« $bankRedirectUrl », puis active-la avec « Activate by linking accounts ». '
            'Importe ensuite ici le fichier .pem téléchargé à sa création.',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _busy ? null : _importKey,
            icon: const Icon(Icons.key_rounded),
            label: const Text('Importer la clé (.pem)'),
          ),
        ],
      );

  Widget _appReady() => Row(
        children: [
          const Icon(Icons.verified_rounded, color: AppColors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Clé importée', style: TextStyle(fontWeight: FontWeight.w600)),
                Text('Application ${store.ebAppId!.substring(0, min(8, store.ebAppId!.length))}…',
                    style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              ],
            ),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    final ok = await confirmDialog(context, 'Oublier la clé ?',
                        'La connexion bancaire sera aussi coupée. Tes opérations restent dans l\'app.',
                        ok: 'Oublier');
                    if (ok) await store.disconnectBank(forgetApp: true);
                  },
            child: const Text('Changer'),
          ),
        ],
      );

  Widget _connection() {
    if (!store.hasBankApp) {
      return const Text('Importe d\'abord la clé de ton application.', style: TextStyle(color: AppColors.muted));
    }
    if (!store.bankConnected) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Tu vas te connecter à ta banque comme sur son site (identifiant + code), dans une page sécurisée.',
              style: TextStyle(color: AppColors.muted, height: 1.4)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _busy ? null : _connect,
            icon: const Icon(Icons.account_balance_rounded),
            label: const Text('Connecter ma banque'),
          ),
        ],
      );
    }
    final expired = store.bankExpired;
    final until = store.ebValidUntil;
    final last = store.ebLastSync;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(expired ? Icons.error_outline_rounded : Icons.link_rounded,
                color: expired ? AppColors.red : AppColors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${store.ebAspsp ?? 'Banque'} · ${store.ebAccountName ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    [
                      if (until != null) (expired ? 'Accès expiré le ${_fmtDay(until)}' : 'Accès valable jusqu\'au ${_fmtDay(until)}'),
                      last == null ? 'Jamais synchronisé' : 'Dernière synchro : ${_fmt(last)}',
                    ].join('\n'),
                    style: TextStyle(color: expired ? AppColors.red : AppColors.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (!expired)
          FilledButton.icon(
            onPressed: _busy || store.syncing ? null : () => _guard('Synchronisation…', () => runBankSync(context)),
            icon: const Icon(Icons.sync_rounded),
            label: const Text('Synchroniser maintenant'),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _connect,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(expired ? 'Reconnecter ma banque' : 'Renouveler l\'accès'),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () async {
                  final ok = await confirmDialog(context, 'Déconnecter la banque ?',
                      'Pécule n\'aura plus accès à tes opérations. Celles déjà récupérées restent dans l\'app.',
                      ok: 'Déconnecter');
                  if (ok) await store.disconnectBank();
                },
          child: const Text('Déconnecter', style: TextStyle(color: AppColors.red)),
        ),
      ],
    );
  }
}

/// Page de connexion de la banque ; se referme dès le retour sur l'URL de redirection.
class BankAuthScreen extends StatefulWidget {
  final Uri url;
  final String bankName;
  const BankAuthScreen({super.key, required this.url, required this.bankName});

  @override
  State<BankAuthScreen> createState() => _BankAuthScreenState();
}

class _BankAuthScreenState extends State<BankAuthScreen> {
  late final WebViewController _controller;
  bool _done = false;
  int _progress = 0;

  bool _handle(String? url) {
    if (_done || url == null || !url.startsWith(bankRedirectUrl)) return false;
    _done = true;
    final uri = Uri.parse(url);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(uri);
    });
    return true;
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (req) => _handle(req.url) ? NavigationDecision.prevent : NavigationDecision.navigate,
        onPageStarted: _handle,
        onUrlChange: (change) => _handle(change.url),
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      ))
      ..loadRequest(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bankName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(value: _progress / 100, minHeight: 3),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
