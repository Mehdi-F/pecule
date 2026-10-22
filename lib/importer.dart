import 'dart:convert';
import 'dart:math';

import 'text_utils.dart';

class ParsedTx {
  final DateTime date;
  final int amountCents;
  final String label;
  final String rawLabel;
  final String hash;
  const ParsedTx(this.date, this.amountCents, this.label, this.rawLabel, this.hash);
}

class ParseResult {
  final List<ParsedTx> txs;
  final String format;
  final int? balanceCents;
  final DateTime? balanceDate;
  const ParseResult(this.txs, this.format, {this.balanceCents, this.balanceDate});
}

class ImportException implements Exception {
  final String message;
  const ImportException(this.message);
  @override
  String toString() => message;
}

const String _formatHelp =
    'Formats acceptés : CSV (date, montant ou débit/crédit, libellé) ou OFX exporté depuis ta banque.';

ParseResult parseStatement(List<int> bytes) {
  final text = decodeText(bytes);
  if (text.trim().isEmpty) throw const ImportException('Le fichier est vide.');
  final upper = text.toUpperCase();
  if (upper.contains('<STMTTRN>') || upper.contains('OFXHEADER') || upper.contains('<OFX>')) {
    return parseOfx(text);
  }
  return parseCsv(text);
}

String decodeText(List<int> bytes) {
  var b = bytes;
  if (b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) b = b.sublist(3);
  try {
    return utf8.decode(b);
  } on FormatException {
    return latin1.decode(b);
  }
}

// ---------------------------------------------------------------- valeurs

final RegExp _ymdRe = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})');
final RegExp _dmyRe = RegExp(r'^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2,4})$');

DateTime? _validDate(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1 || d > 31 || y < 1970 || y > 2100) return null;
  final dt = DateTime(y, m, d);
  if (dt.month != m) return null;
  return dt;
}

DateTime? parseDate(String s) {
  final t = s.trim();
  var m = _ymdRe.firstMatch(t);
  if (m != null) {
    return _validDate(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  }
  m = _dmyRe.firstMatch(t);
  if (m != null) {
    var y = int.parse(m.group(3)!);
    if (y < 100) y += 2000;
    return _validDate(y, int.parse(m.group(2)!), int.parse(m.group(1)!));
  }
  return null;
}

/// Montant en centimes : gère « -131,32 », « 1 234,56 € », « 1.234,56 », « 1,234.56 », « 47.00 ».
int? parseAmountCents(String s) {
  var t = s.trim().replaceAll(RegExp(r'[\s  €]'), '').replaceAll(RegExp('EUR', caseSensitive: false), '');
  if (t.isEmpty) return null;
  var neg = false;
  if (t.startsWith('(') && t.endsWith(')') && t.length > 2) {
    neg = true;
    t = t.substring(1, t.length - 1);
  }
  if (t.startsWith('-')) {
    neg = !neg;
    t = t.substring(1);
  } else if (t.startsWith('+')) {
    t = t.substring(1);
  }
  if (t.endsWith('-')) {
    neg = !neg;
    t = t.substring(0, t.length - 1);
  }
  if (!RegExp(r'^[0-9.,]+$').hasMatch(t) || !RegExp(r'[0-9]').hasMatch(t)) return null;

  final lc = t.lastIndexOf(',');
  final ld = t.lastIndexOf('.');
  var sepIdx = -1;
  if (lc >= 0 && ld >= 0) {
    sepIdx = max(lc, ld);
  } else if (lc >= 0) {
    if (t.indexOf(',') == lc && t.length - lc - 1 <= 2) sepIdx = lc;
  } else if (ld >= 0) {
    if (t.indexOf('.') == ld && t.length - ld - 1 <= 2) sepIdx = ld;
  }
  var intPart = t;
  var frac = '';
  if (sepIdx >= 0) {
    intPart = t.substring(0, sepIdx);
    frac = t.substring(sepIdx + 1);
  }
  intPart = intPart.replaceAll(RegExp(r'[.,]'), '');
  if (frac.contains(RegExp(r'[.,]')) || frac.length > 2) return null;
  frac = frac.padRight(2, '0');
  final v = int.parse(intPart.isEmpty ? '0' : intPart) * 100 + int.parse(frac);
  return neg ? -v : v;
}

ParsedTx _make(DateTime date, int cents, String display, String raw, Map<String, int> occ,
    {String? fixedHash}) {
  final base = '${ymd(date)}|$cents|${normalize(raw)}';
  String hash;
  if (fixedHash != null) {
    hash = fixedHash;
  } else {
    final n = occ[base] ?? 0;
    occ[base] = n + 1;
    hash = '$base|$n';
  }
  return ParsedTx(date, cents, cleanLabel(display), raw, hash);
}

// ---------------------------------------------------------------- CSV

String detectSeparator(String text) {
  final lines = const LineSplitter().convert(text).where((l) => l.trim().isNotEmpty).take(30).toList();
  var best = ';';
  var bestScore = -1;
  for (final s in const [';', '\t', ',', '|']) {
    final freq = <int, int>{};
    for (final l in lines) {
      final c = s.allMatches(l).length;
      if (c > 0) freq[c] = (freq[c] ?? 0) + 1;
    }
    if (freq.isEmpty) continue;
    final score = freq.values.reduce(max);
    if (score > bestScore) {
      best = s;
      bestScore = score;
    }
  }
  return best;
}

List<List<String>> splitCsv(String text, String sep) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"' && field.isEmpty) {
      inQuotes = true;
    } else if (c == sep) {
      row.add(field.toString());
      field.clear();
    } else if (c == '\r') {
      continue;
    } else if (c == '\n') {
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else {
      field.write(c);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}

class _Mapping {
  final int date;
  final int? amount;
  final int? debit;
  final int? credit;
  final int? label;
  final List<int> extra;
  final int firstDataRow;
  _Mapping(this.date, this.amount, this.debit, this.credit, this.label, this.extra, this.firstDataRow);
}

_Mapping? _headerMapping(List<List<String>> rows) {
  for (var i = 0; i < rows.length && i < 15; i++) {
    final h = rows[i].map((c) => normalize(c).toLowerCase()).toList();
    final hasDate = h.any((c) => c.contains('date'));
    final hasAmount = h.any((c) =>
        c.contains('montant') || c.contains('amount') || c.contains('debit') || c.contains('credit'));
    if (!hasDate || !hasAmount) continue;
    int? date, amount, debit, credit, label;
    final extra = <int>[];
    for (var c = 0; c < h.length; c++) {
      final v = h[c];
      if (v.isEmpty) continue;
      if (v.contains('date')) {
        if (date == null && !v.contains('valeur')) date = c;
        continue;
      }
      if (v.contains('solde') || v.contains('balance')) continue;
      if (v.contains('montant') || v.contains('amount')) {
        amount ??= c;
      } else if (v.contains('debit')) {
        debit ??= c;
      } else if (v.contains('credit')) {
        credit ??= c;
      } else if (v.contains('libelle') ||
          v.contains('label') ||
          v.contains('description') ||
          v.contains('intitule') ||
          v.contains('detail') ||
          v.contains('operation') ||
          v.contains('beneficiaire') ||
          v.contains('tiers')) {
        if (label == null) {
          label = c;
        } else {
          extra.add(c);
        }
      } else if (v.contains('type') || v.contains('info') || v.contains('commentaire') || v.contains('reference')) {
        extra.add(c);
      }
    }
    date ??= h.indexWhere((c) => c.contains('date'));
    if (amount == null && debit == null && credit == null) continue;
    if (label == null && extra.isNotEmpty) label = extra.removeAt(0);
    return _Mapping(date, amount, debit, credit, label, extra, i + 1);
  }
  return null;
}

final RegExp _decimalEnd = RegExp(r'[.,]\d{1,2}\s*(€|EUR)?$', caseSensitive: false);

_Mapping? _inferMapping(List<List<String>> rows) {
  final sample = rows.where((r) => r.length >= 2).take(300).toList();
  if (sample.isEmpty) return null;
  final cols = sample.map((r) => r.length).reduce(max);
  final n = sample.length;

  int filled(int c) => sample.where((r) => c < r.length && r[c].isNotEmpty).length;
  double ratio(int c, bool Function(String) f) {
    var nonEmpty = 0, ok = 0;
    for (final r in sample) {
      if (c >= r.length || r[c].isEmpty) continue;
      nonEmpty++;
      if (f(r[c])) ok++;
    }
    return nonEmpty == 0 ? 0 : ok / nonEmpty;
  }

  bool isDate(String v) => parseDate(v) != null;
  bool isAmount(String v) => parseAmountCents(v) != null && _decimalEnd.hasMatch(v.trim());
  bool isNumber(String v) => parseAmountCents(v) != null;

  int? dateCol;
  var best = 0.0;
  for (var c = 0; c < cols; c++) {
    final score = ratio(c, isDate) * filled(c) / n;
    if (score >= 0.5 && score > best + 1e-9) {
      best = score;
      dateCol = c;
    }
  }
  if (dateCol == null) return null;

  final amountCols = <int>[
    for (var c = 0; c < cols; c++)
      if (c != dateCol && ratio(c, isAmount) >= 0.6 && filled(c) >= max(1, n * 0.2)) c,
  ];
  if (amountCols.isEmpty) return null;

  int? amount, debit, credit;
  if (amountCols.length == 1) {
    amount = amountCols.first;
  } else {
    final a = amountCols[0], b = amountCols[1];
    final both = sample.where((r) => a < r.length && b < r.length && r[a].isNotEmpty && r[b].isNotEmpty).length;
    if (both <= n * 0.1) {
      debit = a;
      credit = b;
    } else {
      bool neg(String v) => v.trim().startsWith('-');
      amount = ratio(a, neg) > 0 ? a : (ratio(b, neg) > 0 ? b : a);
    }
  }

  final textCols = <int>[
    for (var c = 0; c < cols; c++)
      if (c != dateCol && !amountCols.contains(c) && filled(c) > 0 && ratio(c, isDate) < 0.5 && ratio(c, isNumber) < 0.5) c,
  ];
  double avgLen(int c) {
    final vals = sample.where((r) => c < r.length && r[c].isNotEmpty).map((r) => r[c].length);
    return vals.isEmpty ? 0 : vals.reduce((x, y) => x + y) / vals.length;
  }

  textCols.sort((x, y) => avgLen(y).compareTo(avgLen(x)));
  final label = textCols.isEmpty ? null : textCols.first;
  final extra = textCols.skip(1).where((c) => avgLen(c) >= 2).toList();
  return _Mapping(dateCol, amount, debit, credit, label, extra, 0);
}

ParseResult parseCsv(String text) {
  final sep = detectSeparator(text);
  final rows = splitCsv(text, sep)
      .map((r) => r.map((c) => c.trim()).toList())
      .where((r) => r.any((c) => c.isNotEmpty))
      .toList();
  if (rows.isEmpty) throw const ImportException('Le fichier est vide.');
  final mapping = _headerMapping(rows) ?? _inferMapping(rows);
  if (mapping == null) {
    throw const ImportException('Impossible de reconnaître les colonnes du fichier. $_formatHelp');
  }

  final out = <ParsedTx>[];
  final occ = <String, int>{};
  for (var i = mapping.firstDataRow; i < rows.length; i++) {
    final r = rows[i];
    String cell(int? c) => (c != null && c >= 0 && c < r.length) ? r[c] : '';
    final date = parseDate(cell(mapping.date));
    int? amount;
    if (mapping.amount != null) {
      amount = parseAmountCents(cell(mapping.amount));
    } else {
      final d = parseAmountCents(cell(mapping.debit));
      final c = parseAmountCents(cell(mapping.credit));
      if (d != null || c != null) amount = (c?.abs() ?? 0) - (d?.abs() ?? 0);
    }
    if (date == null || amount == null || amount == 0) continue;
    final main = cell(mapping.label).trim();
    final others = mapping.extra.map(cell).map((s) => s.trim()).where((s) => s.isNotEmpty);
    var raw = [main, ...others].where((s) => s.isNotEmpty).join(' ');
    if (raw.isEmpty) raw = 'Opération';
    out.add(_make(date, amount, main.isNotEmpty ? main : raw, raw, occ));
  }
  if (out.isEmpty) {
    throw const ImportException('Aucune opération trouvée dans le fichier. $_formatHelp');
  }
  return ParseResult(out, 'CSV');
}

// ---------------------------------------------------------------- OFX

String? _tag(String src, String name) {
  final m = RegExp('<$name>([^<\\r\\n]*)', caseSensitive: false).firstMatch(src);
  final v = m?.group(1)?.trim();
  if (v == null || v.isEmpty) return null;
  return v
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&apos;', "'")
      .replaceAll('&quot;', '"');
}

DateTime? _ofxDate(String? v) {
  if (v == null || v.length < 8) return null;
  final y = int.tryParse(v.substring(0, 4));
  final m = int.tryParse(v.substring(4, 6));
  final d = int.tryParse(v.substring(6, 8));
  if (y == null || m == null || d == null) return null;
  return _validDate(y, m, d);
}

ParseResult parseOfx(String text) {
  final out = <ParsedTx>[];
  final occ = <String, int>{};
  final parts = text.split(RegExp('<STMTTRN>', caseSensitive: false));
  for (final part in parts.skip(1)) {
    var chunk = part;
    final up = chunk.toUpperCase();
    var end = up.indexOf('</STMTTRN>');
    if (end < 0) end = up.indexOf('</BANKTRANLIST>');
    if (end >= 0) chunk = chunk.substring(0, end);

    final date = _ofxDate(_tag(chunk, 'DTPOSTED')) ?? _ofxDate(_tag(chunk, 'DTUSER'));
    final amount = parseAmountCents(_tag(chunk, 'TRNAMT') ?? '');
    if (date == null || amount == null || amount == 0) continue;
    final name = _tag(chunk, 'NAME') ?? '';
    final memo = _tag(chunk, 'MEMO') ?? '';
    final display = name.isNotEmpty ? name : (memo.isNotEmpty ? memo : 'Opération');
    final raw = (memo.isNotEmpty && memo != name) ? '$display $memo'.trim() : display;
    final fitid = _tag(chunk, 'FITID');
    out.add(_make(date, amount, display, raw, occ,
        fixedHash: fitid == null ? null : 'ofx|$fitid|${ymd(date)}|$amount'));
  }
  if (out.isEmpty) throw const ImportException('Aucune opération trouvée dans le fichier OFX.');

  int? bal;
  DateTime? balDate;
  final i = text.toUpperCase().indexOf('<LEDGERBAL>');
  if (i >= 0) {
    final sub = text.substring(i);
    bal = parseAmountCents(_tag(sub, 'BALAMT') ?? '');
    balDate = _ofxDate(_tag(sub, 'DTASOF'));
  }
  return ParseResult(out, 'OFX', balanceCents: bal, balanceDate: balDate);
}
