import 'package:flutter/foundation.dart' show ChangeNotifier, compute;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'bank/eb_client.dart';
import 'bank/eb_mapping.dart';
import 'categorizer.dart';
import 'importer.dart';
import 'models.dart';
import 'pdf_words.dart';
import 'text_utils.dart';

class ImportSummary {
  final int added;
  final int duplicates;
  final String format;
  final bool balanceUpdated;
  const ImportSummary(this.added, this.duplicates, this.format, this.balanceUpdated);
}

class DaySummary {
  final DateTime day;
  final List<Tx> txs;
  final int deltaCents;
  final int? balanceCents;
  const DaySummary(this.day, this.txs, this.deltaCents, this.balanceCents);
}

class CategoryTotal {
  final Category category;
  final int cents;
  final int count;
  const CategoryTotal(this.category, this.cents, this.count);
}

class Store extends ChangeNotifier {
  Database? _db;
  final List<Tx> txs = [];
  final Map<int, Tx> _byId = {};
  final Map<int, Category> categories = {};
  final List<Rule> rules = [];
  final List<Link> links = [];
  final Map<int, int> _reimbursed = {};
  final Map<int, int> _allocated = {};
  int? budgetCents;
  int? anchorBalanceCents;
  DateTime? anchorDate;
  int? _fallbackExpense;
  int? _fallbackIncome;

  // Synchro bancaire (Enable Banking)
  String? ebAppId;
  String? _ebKey;
  String? ebAspsp;
  String? _ebSessionId;
  String? _ebAccountUid;
  String? ebAccountName;
  DateTime? ebValidUntil;
  DateTime? ebLastSync;
  bool syncing = false;

  static final Category unknownCategory =
      Category(id: -1, name: 'Sans catégorie', icon: 'other', color: 0xFFB0B7C9, kind: 'both');

  Database get db => _db!;

  Future<void> init() async {
    if (_db != null) return;
    final path = p.join(await getDatabasesPath(), 'pecule.db');
    _db = await openDatabase(path, version: 1, onCreate: _create);
    await _loadAll();
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('CREATE TABLE categories(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, '
        'icon TEXT NOT NULL, color INTEGER NOT NULL, kind TEXT NOT NULL)');
    await db.execute('CREATE TABLE rules(id INTEGER PRIMARY KEY AUTOINCREMENT, keyword TEXT NOT NULL, '
        'category_id INTEGER NOT NULL, priority INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, hash TEXT NOT NULL UNIQUE, '
        'date TEXT NOT NULL, amount_cents INTEGER NOT NULL, label TEXT NOT NULL, raw_label TEXT NOT NULL, '
        'category_id INTEGER, cat_manual INTEGER NOT NULL DEFAULT 0, note TEXT NOT NULL DEFAULT \'\', '
        'excluded INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE links(id INTEGER PRIMARY KEY AUTOINCREMENT, expense_id INTEGER NOT NULL, '
        'income_id INTEGER NOT NULL, amount_cents INTEGER NOT NULL)');
    await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)');

    final ids = <String, int>{};
    for (final c in defaultCategories) {
      ids[c.name] = await db.insert('categories', {'name': c.name, 'icon': c.icon, 'color': c.color, 'kind': c.kind});
    }
    for (final r in defaultRuleSeeds) {
      final cid = ids[r.category];
      if (cid == null) continue;
      await db.insert('rules', {'keyword': r.keyword, 'category_id': cid, 'priority': r.priority});
    }
    await db.insert('settings', {'key': 'fallback_expense', 'value': '${ids[expenseFallbackName]}'});
    await db.insert('settings', {'key': 'fallback_income', 'value': '${ids[incomeFallbackName]}'});
    await db.insert('settings', {'key': 'rules_version', 'value': '$defaultRulesVersion'});
  }

  /// Ajoute les nouvelles règles par défaut d'une mise à jour, puis recatégorise
  /// les opérations qui n'ont pas été rangées à la main.
  Future<void> _upgradeRules() async {
    final byName = {for (final c in categories.values) c.name: c.id};
    final known = rules.map((r) => r.keyword.toUpperCase()).toSet();
    await db.transaction((txn) async {
      for (final seed in defaultRuleSeeds) {
        final cid = byName[seed.category];
        if (cid == null || known.contains(seed.keyword.toUpperCase())) continue;
        final id = await txn.insert('rules', {'keyword': seed.keyword, 'category_id': cid, 'priority': seed.priority});
        rules.add(Rule(id: id, keyword: seed.keyword, categoryId: cid, priority: seed.priority));
      }
      final sorted = sortRules(rules);
      for (final t in txs) {
        if (t.categoryManual) continue;
        final cid = categorize(t.rawLabel, sorted) ?? (t.isExpense ? _fallbackExpense : _fallbackIncome);
        if (cid == null || cid == t.categoryId) continue;
        t.categoryId = cid;
        await txn.update('transactions', {'category_id': cid}, where: 'id = ?', whereArgs: [t.id]);
      }
      await txn.insert('settings', {'key': 'rules_version', 'value': '$defaultRulesVersion'},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> _loadAll() async {
    final catRows = await db.query('categories', orderBy: 'id');
    categories
      ..clear()
      ..addEntries(catRows.map((m) {
        final c = Category.fromMap(m);
        return MapEntry(c.id, c);
      }));
    final ruleRows = await db.query('rules');
    rules
      ..clear()
      ..addAll(ruleRows.map((m) => Rule.fromMap(m)));
    final linkRows = await db.query('links');
    links
      ..clear()
      ..addAll(linkRows.map((m) => Link.fromMap(m)));
    final txRows = await db.query('transactions');
    txs
      ..clear()
      ..addAll(txRows.map((m) => Tx.fromMap(m)));
    final settingRows = await db.query('settings');
    final s = <String, String>{for (final m in settingRows) m['key'] as String: m['value'] as String};
    budgetCents = int.tryParse(s['budget_cents'] ?? '');
    anchorBalanceCents = int.tryParse(s['anchor_balance_cents'] ?? '');
    anchorDate = DateTime.tryParse(s['anchor_date'] ?? '');
    _fallbackExpense = int.tryParse(s['fallback_expense'] ?? '');
    _fallbackIncome = int.tryParse(s['fallback_income'] ?? '');
    ebAppId = s['eb_app_id'];
    _ebKey = s['eb_key'];
    ebAspsp = s['eb_aspsp'];
    _ebSessionId = s['eb_session_id'];
    _ebAccountUid = s['eb_account_uid'];
    ebAccountName = s['eb_account_name'];
    ebValidUntil = DateTime.tryParse(s['eb_valid_until'] ?? '');
    ebLastSync = DateTime.tryParse(s['eb_last_sync'] ?? '');
    _reindex();
    if ((int.tryParse(s['rules_version'] ?? '') ?? 1) < defaultRulesVersion) await _upgradeRules();
  }

  void _reindex() {
    txs.sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : b.id.compareTo(a.id);
    });
    _byId
      ..clear()
      ..addEntries(txs.map((t) => MapEntry(t.id, t)));
    _reimbursed.clear();
    _allocated.clear();
    for (final l in links) {
      _reimbursed[l.expenseId] = (_reimbursed[l.expenseId] ?? 0) + l.amountCents;
      _allocated[l.incomeId] = (_allocated[l.incomeId] ?? 0) + l.amountCents;
    }
  }

  Future<void> _setSetting(String key, String? value) async {
    if (value == null) {
      await db.delete('settings', where: 'key = ?', whereArgs: [key]);
    } else {
      await db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // ---------------------------------------------------------------- lecture

  Tx? txById(int id) => _byId[id];

  Category categoryOf(Tx t) => categories[t.categoryId] ?? unknownCategory;

  List<Category> get sortedCategories => categories.values.toList()..sort((a, b) => a.name.compareTo(b.name));

  List<Rule> get sortedRules => sortRules(rules);

  int reimbursed(Tx t) => _reimbursed[t.id] ?? 0;
  int allocated(Tx t) => _allocated[t.id] ?? 0;

  /// Montant après remboursements (dépense) ou après affectation (entrée).
  int netCents(Tx t) => t.isExpense ? t.amountCents + reimbursed(t) : t.amountCents - allocated(t);

  /// Ce qui reste à rembourser (dépense) ou à affecter (entrée), en positif.
  int remaining(Tx t) => t.isExpense ? -t.amountCents - reimbursed(t) : t.amountCents - allocated(t);

  List<Link> linksOf(Tx t) =>
      links.where((l) => t.isExpense ? l.expenseId == t.id : l.incomeId == t.id).toList();

  int? get currentBalance {
    final a = anchorBalanceCents, d = anchorDate;
    if (a == null || d == null) return null;
    var v = a;
    for (final t in txs) {
      if (t.date.isAfter(d)) v += t.amountCents;
    }
    return v;
  }

  List<DaySummary> days() {
    final byDay = <DateTime, List<Tx>>{};
    for (final t in txs) {
      byDay.putIfAbsent(t.date, () => []).add(t);
    }
    final keys = byDay.keys.toList()..sort();
    final balances = <DateTime, int>{};
    final a = anchorBalanceCents, ad = anchorDate;
    if (a != null && ad != null) {
      var prefixAtAnchor = 0;
      for (final t in txs) {
        if (!t.date.isAfter(ad)) prefixAtAnchor += t.amountCents;
      }
      var run = 0;
      for (final d in keys) {
        for (final t in byDay[d]!) {
          run += t.amountCents;
        }
        balances[d] = a + run - prefixAtAnchor;
      }
    }
    return [
      for (final d in keys.reversed)
        DaySummary(
          d,
          byDay[d]!..sort((x, y) => x.amountCents.compareTo(y.amountCents)),
          byDay[d]!.fold(0, (s, t) => s + t.amountCents),
          balances[d],
        ),
    ];
  }

  List<Tx> monthTxs(DateTime month) => txs
      .where((t) => t.date.year == month.year && t.date.month == month.month && !t.excluded)
      .toList();

  List<CategoryTotal> totals(DateTime month, {required bool expenses}) {
    final cents = <int, int>{};
    final counts = <int, int>{};
    for (final t in monthTxs(month)) {
      if (t.isExpense != expenses) continue;
      final net = netCents(t).abs();
      if (net == 0) continue;
      final key = t.categoryId ?? -1;
      cents[key] = (cents[key] ?? 0) + net;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final list = [
      for (final e in cents.entries)
        CategoryTotal(categories[e.key] ?? unknownCategory, e.value, counts[e.key] ?? 0),
    ];
    list.sort((a, b) => b.cents.compareTo(a.cents));
    return list;
  }

  int monthTotal(DateTime month, {required bool expenses}) =>
      totals(month, expenses: expenses).fold(0, (s, c) => s + c.cents);

  // ---------------------------------------------------------------- écriture

  /// Le PDF est lu hors du fil de l'interface ; repli en direct si l'isolate échoue.
  Future<ParseResult> _parsePdf(List<int> bytes) async {
    try {
      return await compute(parseLclPdfBytes, bytes);
    } on ImportException {
      rethrow;
    } catch (_) {
      return parseLclPdfBytes(bytes);
    }
  }

  Future<ImportSummary> importBytes(List<int> bytes) async {
    final res = isPdf(bytes) ? await _parsePdf(bytes) : parseStatement(bytes);
    return ingest(res);
  }

  static bool _fromBank(String hash) => hash.startsWith(bankHashPrefix);

  /// Ajoute des opérations en ignorant les doublons :
  /// - même empreinte (réimport du même fichier / même synchro) ;
  /// - même montant à ±3 jours d'une opération venue de l'autre source
  ///   (relevé importé d'un côté, synchro bancaire de l'autre).
  Future<ImportSummary> ingest(ParseResult res) async {
    final existing = txs.map((t) => t.hash).toSet();
    final crossSource = <int, List<Tx>>{};
    for (final t in txs) {
      crossSource.putIfAbsent(t.amountCents, () => []).add(t);
    }
    final matched = <int>{};
    final sorted = sortedRules;
    var dup = 0;
    final added = <Tx>[];
    await db.transaction((txn) async {
      for (final ptx in res.txs) {
        if (!existing.add(ptx.hash)) {
          dup++;
          continue;
        }
        final incomingBank = _fromBank(ptx.hash);
        Tx? twin;
        var bestGap = 4;
        for (final t in crossSource[ptx.amountCents] ?? const <Tx>[]) {
          if (_fromBank(t.hash) == incomingBank || matched.contains(t.id)) continue;
          final gap = t.date.difference(dateOnly(ptx.date)).inDays.abs();
          if (gap < bestGap) {
            bestGap = gap;
            twin = t;
          }
        }
        if (twin != null) {
          matched.add(twin.id);
          dup++;
          continue;
        }
        final catId = categorize(ptx.rawLabel, sorted) ??
            (ptx.amountCents < 0 ? _fallbackExpense : _fallbackIncome);
        final id = await txn.insert('transactions', {
          'hash': ptx.hash,
          'date': ymd(ptx.date),
          'amount_cents': ptx.amountCents,
          'label': ptx.label,
          'raw_label': ptx.rawLabel,
          'category_id': catId,
        });
        added.add(Tx(
          id: id,
          hash: ptx.hash,
          date: dateOnly(ptx.date),
          amountCents: ptx.amountCents,
          label: ptx.label,
          rawLabel: ptx.rawLabel,
          categoryId: catId,
        ));
      }
    });
    txs.addAll(added);
    _reindex();

    var balanceUpdated = false;
    final bal = res.balanceCents, bd = res.balanceDate;
    if (bal != null && bd != null && (anchorDate == null || !bd.isBefore(anchorDate!))) {
      await setAnchor(bal, bd, notify: false);
      balanceUpdated = true;
    }
    notifyListeners();
    return ImportSummary(added.length, dup, res.format, balanceUpdated);
  }

  Future<void> setCategory(Tx t, int categoryId) async {
    await db.update('transactions', {'category_id': categoryId, 'cat_manual': 1},
        where: 'id = ?', whereArgs: [t.id]);
    t.categoryId = categoryId;
    t.categoryManual = true;
    notifyListeners();
  }

  /// Crée une règle (prioritaire sur celles par défaut) et l'applique aux opérations
  /// non modifiées à la main. Renvoie le nombre d'opérations recatégorisées.
  Future<int> addRuleAndApply(String keyword, int categoryId) async {
    final k = normalize(keyword);
    if (k.isEmpty) return 0;
    final id = await db.insert('rules', {'keyword': k, 'category_id': categoryId, 'priority': userRulePriority});
    final rule = Rule(id: id, keyword: k, categoryId: categoryId, priority: userRulePriority);
    rules.add(rule);
    final targets = txs.where((t) => !t.categoryManual && t.categoryId != categoryId && rule.matches(normalize(t.rawLabel))).toList();
    await db.transaction((txn) async {
      for (final t in targets) {
        await txn.update('transactions', {'category_id': categoryId}, where: 'id = ?', whereArgs: [t.id]);
      }
    });
    for (final t in targets) {
      t.categoryId = categoryId;
    }
    notifyListeners();
    return targets.length;
  }

  Future<void> deleteRule(Rule r) async {
    await db.delete('rules', where: 'id = ?', whereArgs: [r.id]);
    rules.removeWhere((x) => x.id == r.id);
    notifyListeners();
  }

  Future<void> setExcluded(Tx t, bool excluded) async {
    await db.update('transactions', {'excluded': excluded ? 1 : 0}, where: 'id = ?', whereArgs: [t.id]);
    t.excluded = excluded;
    notifyListeners();
  }

  /// Sans notification : appelé pendant la saisie.
  Future<void> setNote(Tx t, String note) async {
    t.note = note;
    await db.update('transactions', {'note': note}, where: 'id = ?', whereArgs: [t.id]);
  }

  Future<void> addLink(Tx expense, Tx income, int cents) async {
    final id = await db.insert('links', {'expense_id': expense.id, 'income_id': income.id, 'amount_cents': cents});
    links.add(Link(id: id, expenseId: expense.id, incomeId: income.id, amountCents: cents));
    _reindex();
    notifyListeners();
  }

  Future<void> removeLink(Link l) async {
    await db.delete('links', where: 'id = ?', whereArgs: [l.id]);
    links.removeWhere((x) => x.id == l.id);
    _reindex();
    notifyListeners();
  }

  Future<void> deleteTx(Tx t) async {
    await db.delete('links', where: 'expense_id = ? OR income_id = ?', whereArgs: [t.id, t.id]);
    await db.delete('transactions', where: 'id = ?', whereArgs: [t.id]);
    links.removeWhere((l) => l.expenseId == t.id || l.incomeId == t.id);
    txs.removeWhere((x) => x.id == t.id);
    _reindex();
    notifyListeners();
  }

  Future<void> setBudget(int? cents) async {
    budgetCents = cents;
    await _setSetting('budget_cents', cents?.toString());
    notifyListeners();
  }

  Future<void> setAnchor(int cents, DateTime date, {bool notify = true}) async {
    anchorBalanceCents = cents;
    anchorDate = dateOnly(date);
    await _setSetting('anchor_balance_cents', '$cents');
    await _setSetting('anchor_date', ymd(anchorDate!));
    if (notify) notifyListeners();
  }

  Future<int> addCategory(String name, String icon, int color) async {
    final id = await db.insert('categories', {'name': name, 'icon': icon, 'color': color, 'kind': 'both'});
    categories[id] = Category(id: id, name: name, icon: icon, color: color, kind: 'both');
    notifyListeners();
    return id;
  }

  Future<void> clearTransactions() async {
    await db.delete('links');
    await db.delete('transactions');
    await _setSetting('anchor_balance_cents', null);
    await _setSetting('anchor_date', null);
    links.clear();
    txs.clear();
    anchorBalanceCents = null;
    anchorDate = null;
    _reindex();
    notifyListeners();
  }

  // ---------------------------------------------------------------- synchro bancaire

  bool get hasBankApp => ebAppId != null && _ebKey != null;
  bool get bankConnected => hasBankApp && _ebSessionId != null && _ebAccountUid != null;
  bool get bankExpired => bankConnected && ebValidUntil != null && ebValidUntil!.isBefore(DateTime.now());

  EbClient get bankClient {
    if (!hasBankApp) throw const EbException('Configure d\'abord ton application Enable Banking.');
    return EbClient(ebAppId!, _ebKey!);
  }

  Future<void> setBankApp(String appId, String pem) async {
    EbClient.validateKey(pem);
    ebAppId = appId.trim();
    _ebKey = pem;
    await _setSetting('eb_app_id', ebAppId);
    await _setSetting('eb_key', pem);
    notifyListeners();
  }

  /// Enregistre la session créée après l'autorisation à la banque.
  Future<void> saveBankSession({
    required String sessionId,
    required String accountUid,
    required String accountName,
    required String aspsp,
    DateTime? validUntil,
  }) async {
    _ebSessionId = sessionId;
    _ebAccountUid = accountUid;
    ebAccountName = accountName;
    ebAspsp = aspsp;
    ebValidUntil = validUntil;
    await _setSetting('eb_session_id', sessionId);
    await _setSetting('eb_account_uid', accountUid);
    await _setSetting('eb_account_name', accountName);
    await _setSetting('eb_aspsp', aspsp);
    await _setSetting('eb_valid_until', validUntil?.toIso8601String());
    notifyListeners();
  }

  Future<void> disconnectBank({bool forgetApp = false}) async {
    final id = _ebSessionId;
    if (id != null && hasBankApp) {
      try {
        await bankClient.deleteSession(id);
      } catch (_) {
        // déjà expirée côté banque : rien à faire
      }
    }
    _ebSessionId = null;
    _ebAccountUid = null;
    ebAccountName = null;
    ebValidUntil = null;
    for (final k in ['eb_session_id', 'eb_account_uid', 'eb_account_name', 'eb_valid_until']) {
      await _setSetting(k, null);
    }
    if (forgetApp) {
      ebAppId = null;
      _ebKey = null;
      ebLastSync = null;
      for (final k in ['eb_app_id', 'eb_key', 'eb_last_sync']) {
        await _setSetting(k, null);
      }
    }
    notifyListeners();
  }

  /// Récupère les opérations comptabilisées depuis la dernière synchro (1 an la première fois).
  Future<ImportSummary> syncBank() async {
    if (!bankConnected) throw const EbException('Aucune banque connectée.');
    if (syncing) return const ImportSummary(0, 0, 'Banque', false);
    syncing = true;
    notifyListeners();
    try {
      final client = bankClient;
      final uid = _ebAccountUid!;
      final now = DateTime.now();
      final last = ebLastSync;
      List<Map<String, dynamic>> raw;
      if (last == null) {
        try {
          raw = await client.transactions(uid, now.subtract(const Duration(days: 365)));
        } on EbException catch (e) {
          if (e.needsReconnect) rethrow;
          raw = await client.transactions(uid, now.subtract(const Duration(days: 89)));
        }
      } else {
        raw = await client.transactions(uid, last.subtract(const Duration(days: 10)));
      }
      final occ = <String, int>{};
      final parsed = [for (final j in raw) mapEbTransaction(j, occ)].whereType<ParsedTx>().toList();
      (int, DateTime)? balance;
      try {
        balance = pickBalance(await client.balances(uid));
      } on EbException {
        balance = null;
      }
      final res = ParseResult(parsed, 'Banque', balanceCents: balance?.$1, balanceDate: balance?.$2);
      final summary = await ingest(res);
      ebLastSync = now;
      await _setSetting('eb_last_sync', now.toIso8601String());
      return summary;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }
}

final Store store = Store();
