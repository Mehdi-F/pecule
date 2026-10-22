const String _from = 'ÀÁÂÃÄÅàáâãäåÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕÖòóôõöÙÚÛÜùúûüÇçÑñÿŸ';
const String _to = 'AAAAAAaaaaaaEEEEeeeeIIIIiiiiOOOOOoooooUUUUuuuuCcNnyY';

/// Majuscules, sans accents, espaces normalisés. Sert au matching et aux hash.
String normalize(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    final i = _from.indexOf(ch);
    b.write(i >= 0 ? _to[i] : ch);
  }
  return b
      .toString()
      .replaceAll('œ', 'oe')
      .replaceAll('Œ', 'OE')
      .toUpperCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String two(int v) => v.toString().padLeft(2, '0');

String ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

final List<RegExp> _prefixes = [
  RegExp(r'^(PAIEMENT\s+)?(PAR\s+)?(CB|CARTE)(\s+X?\d{4})?\s+', caseSensitive: false),
  RegExp(r'^PRELVT\s+SEPA(\s+RECU)?(\s+D/O\s+CONFRERE)?\s+', caseSensitive: false),
  RegExp(r'^PAIEMENT\s+(A|À)\s+', caseSensitive: false),
  RegExp(r'^(PRLV|PRELEVEMENT|PRÉLÈVEMENT)(\s+SEPA)?\s+', caseSensitive: false),
  RegExp(
      r'^(VIREMENT\s+PERMANENT|VIR\.?\s?PERMANENT|VIREMENT|VIR)(\s+SEPA)?(\s+INST(ANTANE)?)?(\s+(RECU|REÇU|EMIS|ÉMIS))?(\s+(DE|A|À|VERS))?\s+',
      caseSensitive: false),
];

final RegExp _innerPrlv = RegExp(r'\b(PRLV|PRELEVEMENT)\s+SEPA\s+', caseSensitive: false);
final RegExp _junkToken = RegExp(r'^(\.?(ICS|RUM|SDR|REF|NUM)[.:]?\S*\d\S*|\S*\d{8,}\S*)$', caseSensitive: false);
final RegExp _hasDigit = RegExp(r'\d');
final RegExp _hasLetter = RegExp(r'[A-Za-z]');

/// Références techniques (ICS, RUM, numéros de mandat…) sans intérêt pour la lecture.
bool _isJunk(String w) =>
    _junkToken.hasMatch(w) || (w.length >= 14 && _hasDigit.hasMatch(w) && _hasLetter.hasMatch(w));

/// Libellé lisible : retire les préfixes bancaires (CB, PRLV SEPA…), les références techniques
/// et la date finale.
String cleanLabel(String raw) {
  var s = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  for (var round = 0; round < 4; round++) {
    var changed = false;
    for (final p in _prefixes) {
      final n = s.replaceFirst(p, '');
      if (n != s && n.trim().isNotEmpty) {
        s = n;
        changed = true;
      }
    }
    if (!changed) break;
  }
  final inner = _innerPrlv.allMatches(s).toList();
  if (inner.isNotEmpty) {
    final rest = s.substring(inner.last.end).trim();
    if (rest.isNotEmpty) s = rest;
  }
  final kept = s.split(' ').where((w) => w.isNotEmpty && !_isJunk(w)).join(' ').trim();
  if (kept.isNotEmpty) s = kept;
  s = s.replaceFirst(RegExp(r'\s+\d{2}[/.]\d{2}([/.]\d{2,4})?$'), '').trim();
  if (s.isEmpty) s = raw.trim();
  return _titleCase(s);
}

String _titleCase(String s) => s.split(' ').map((w) {
      if (w.isEmpty) return w;
      final lower = w.toLowerCase();
      return lower[0].toUpperCase() + lower.substring(1);
    }).join(' ');

/// Mot-clé « marchand » proposé pour créer une règle (ex. CARREFOUR MARKET).
String merchantKey(String label) {
  final words = normalize(cleanLabel(label))
      .split(' ')
      .where((w) => w.length > 1 && !RegExp(r'\d').hasMatch(w))
      .toList();
  if (words.isEmpty) return normalize(label);
  return words.take(2).join(' ');
}

RegExp keywordRegExp(String keyword) {
  final k = normalize(keyword);
  return RegExp('(^|[^A-Z0-9])${RegExp.escape(k)}(\$|[^A-Z0-9])');
}
