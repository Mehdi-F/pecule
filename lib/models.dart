import 'text_utils.dart';

class Category {
  final int id;
  String name;
  String icon;
  int color;
  String kind; // expense | income | both

  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.kind,
  });

  factory Category.fromMap(Map<String, Object?> m) => Category(
        id: m['id'] as int,
        name: m['name'] as String,
        icon: m['icon'] as String,
        color: m['color'] as int,
        kind: m['kind'] as String,
      );
}

class Tx {
  final int id;
  final String hash;
  final DateTime date;
  final int amountCents;
  final String label;
  final String rawLabel;
  int? categoryId;
  bool categoryManual;
  String note;
  bool excluded;

  Tx({
    required this.id,
    required this.hash,
    required this.date,
    required this.amountCents,
    required this.label,
    required this.rawLabel,
    this.categoryId,
    this.categoryManual = false,
    this.note = '',
    this.excluded = false,
  });

  bool get isExpense => amountCents < 0;

  factory Tx.fromMap(Map<String, Object?> m) => Tx(
        id: m['id'] as int,
        hash: m['hash'] as String,
        date: DateTime.parse(m['date'] as String),
        amountCents: m['amount_cents'] as int,
        label: m['label'] as String,
        rawLabel: m['raw_label'] as String,
        categoryId: m['category_id'] as int?,
        categoryManual: (m['cat_manual'] as int? ?? 0) == 1,
        note: m['note'] as String? ?? '',
        excluded: (m['excluded'] as int? ?? 0) == 1,
      );
}

class Rule {
  final int id;
  final String keyword;
  final int categoryId;
  final int priority;
  RegExp? _re;

  Rule({required this.id, required this.keyword, required this.categoryId, this.priority = 0});

  bool matches(String normalizedLabel) {
    _re ??= keywordRegExp(keyword);
    return _re!.hasMatch(normalizedLabel);
  }

  factory Rule.fromMap(Map<String, Object?> m) => Rule(
        id: m['id'] as int,
        keyword: m['keyword'] as String,
        categoryId: m['category_id'] as int,
        priority: m['priority'] as int? ?? 0,
      );
}

/// Une part d'une entrée (incomeId) affectée au remboursement d'une sortie (expenseId).
class Link {
  final int id;
  final int expenseId;
  final int incomeId;
  final int amountCents;

  Link({required this.id, required this.expenseId, required this.incomeId, required this.amountCents});

  factory Link.fromMap(Map<String, Object?> m) => Link(
        id: m['id'] as int,
        expenseId: m['expense_id'] as int,
        incomeId: m['income_id'] as int,
        amountCents: m['amount_cents'] as int,
      );
}
