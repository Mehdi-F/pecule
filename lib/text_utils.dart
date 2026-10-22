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
  RegExp(r'^(PRLV|PRELEVEMENT|PRÉLÈVEMENT)(\s+SEPA)?\s+', caseSensitive: false),
  RegExp(
      r'^(VIR\.?\s?PERMANENT|VIREMENT|VIR)(\s+SEPA)?(\s+INST(ANTANE)?)?(\s+(RECU|REÇU|EMIS|ÉMIS))?(\s+(DE|A|À|VERS))?\s+',
      caseSensitive: false),
];

/// Libellé lisible : retire les préfixes bancaires (CB, PRLV SEPA…) et la date finale.
String cleanLabel(String raw) {
  var s = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  for (final p in _prefixes) {
    final n = s.replaceFirst(p, '');
    if (n.trim().isNotEmpty) s = n;
  }
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
