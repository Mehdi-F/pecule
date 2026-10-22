import 'importer.dart';

/// Un mot extrait d'un PDF avec sa position (points, origine en haut à gauche).
class PdfWord {
  final int page;
  final double top;
  final double left;
  final double right;
  final String text;
  const PdfWord(this.page, this.top, this.left, this.right, this.text);

  double get center => (left + right) / 2;
}

class _Row {
  final int page;
  final double top;
  final List<PdfWord> words = [];
  _Row(this.page, this.top);

  String get text => words.map((w) => w.text).join(' ');
}

class _Cols {
  final double mid; // frontière entre colonnes DEBIT et CREDIT
  final double valueLeft; // début de la colonne VALEUR
  final double valueRight;
  final double dateRight;
  const _Cols(this.mid, this.valueLeft, this.valueRight, this.dateRight);
}

final RegExp _opDate = RegExp(r'^\d{2}\.\d{2}$');
final RegExp _amountToken = RegExp(r'^[\d.,]+$');
final RegExp _period = RegExp(r'du (\d{2})\.(\d{2})\.(\d{4}) au (\d{2})\.(\d{2})\.(\d{4})');
final RegExp _pageFooter = RegExp(r'PAGE \d+ / \d+');
final RegExp _skipCont = RegExp(
    r'^(REF\.CLIENT|ID\.CREANCIER|REF\.MANDAT|NATURE DU PAIEMENT|CREANCIER INITIAL|PAYEUR INITIAL|COM CHANGE)',
    caseSensitive: false);
final RegExp _fxCont = RegExp(r'\b(EUR|USD|GBP|CHF)\s+[\d.,]+\s*$');

List<_Row> _rows(List<PdfWord> words) {
  final sorted = [...words]..sort((a, b) {
      final p = a.page.compareTo(b.page);
      if (p != 0) return p;
      final t = a.top.compareTo(b.top);
      return t != 0 ? t : a.left.compareTo(b.left);
    });
  final rows = <_Row>[];
  for (final w in sorted) {
    if (rows.isNotEmpty && rows.last.page == w.page && (rows.last.top - w.top).abs() <= 3) {
      rows.last.words.add(w);
    } else {
      rows.add(_Row(w.page, w.top)..words.add(w));
    }
  }
  for (final r in rows) {
    r.words.sort((a, b) => a.left.compareTo(b.left));
  }
  return rows;
}

/// Lit un relevé de compte PDF LCL (« ECRITURES DE LA PERIODE ») à partir des mots positionnés.
ParseResult parseLclPdf(List<PdfWord> words) {
  final rows = _rows(words);

  DateTime? end;
  for (final r in rows) {
    final m = _period.firstMatch(r.text);
    if (m != null) {
      end = DateTime(int.parse(m.group(6)!), int.parse(m.group(5)!), int.parse(m.group(4)!));
      break;
    }
  }
  final endDate = end ?? DateTime.now();

  _Cols? cols;
  var inTable = false;
  final out = <ParsedTx>[];
  final occ = <String, int>{};
  int? closing;

  // Opération en cours de lecture (les lignes suivantes peuvent compléter son libellé).
  DateTime? curDate;
  int? curCents;
  String curLabel = '';
  final curExtra = <String>[];

  void flush() {
    if (curDate != null && curCents != null) {
      final raw = [curLabel, ...curExtra].where((s) => s.isNotEmpty).join(' ');
      out.add(makeParsedTx(curDate!, curCents!, curLabel.isEmpty ? raw : curLabel, raw.isEmpty ? 'Opération' : raw, occ,
          hashLabel: curLabel));
    }
    curDate = null;
    curCents = null;
    curLabel = '';
    curExtra.clear();
  }

  for (final r in rows) {
    final ws = r.words;
    final up = r.text.toUpperCase();
    final names = ws.map((w) => w.text.toUpperCase()).toList();

    if (names.contains('DATE') && names.contains('DEBIT') && names.contains('CREDIT')) {
      PdfWord byName(String n) => ws[names.indexOf(n)];
      final deb = byName('DEBIT'), cre = byName('CREDIT');
      final val = names.contains('VALEUR') ? byName('VALEUR') : null;
      cols = _Cols(
        (deb.center + cre.center) / 2,
        val?.left ?? deb.left - 60,
        val?.right ?? deb.left - 20,
        byName('DATE').right,
      );
      inTable = true;
      continue;
    }
    final c = cols;
    if (c == null) continue;
    if (_pageFooter.hasMatch(up) || up.contains('RELEVE DE COMPTE') || up.startsWith('CRÉDIT LYONNAIS') || up.startsWith('CREDIT LYONNAIS')) {
      inTable = false;
      continue;
    }
    if (!inTable) continue;

    int? signedAmount() {
      final deb = <String>[], cre = <String>[];
      for (final w in ws) {
        if (w.left <= c.valueRight || w.text == '.' || !_amountToken.hasMatch(w.text)) continue;
        (w.center < c.mid ? deb : cre).add(w.text);
      }
      if (deb.isNotEmpty) {
        final v = parseAmountCents(deb.join(' '));
        if (v != null) return -v.abs();
      }
      if (cre.isNotEmpty) {
        final v = parseAmountCents(cre.join(' '));
        if (v != null) return v.abs();
      }
      return null;
    }

    if (up.contains('SOLDE EN EUROS')) {
      flush();
      closing = signedAmount();
      break;
    }
    if (up.contains('ANCIEN SOLDE') || up.contains('TOTAUX')) {
      flush();
      continue;
    }

    final first = ws.first;
    final labelWords = ws.where((w) => w.right < c.valueLeft - 2);
    if (_opDate.hasMatch(first.text) && first.left < c.dateRight + 8) {
      flush();
      final cents = signedAmount();
      if (cents == null || cents == 0) continue;
      final parts = first.text.split('.');
      final day = int.parse(parts[0]), month = int.parse(parts[1]);
      var year = endDate.year;
      if (month > endDate.month) year -= 1; // relevé à cheval sur deux années
      curDate = DateTime(year, month, day);
      curCents = cents;
      curLabel = labelWords.where((w) => !identical(w, first)).map((w) => w.text).join(' ').trim();
    } else if (curDate != null) {
      final cont = labelWords.map((w) => w.text).join(' ').trim();
      if (cont.isEmpty || _skipCont.hasMatch(cont) || _fxCont.hasMatch(cont)) continue;
      if (curExtra.isEmpty && curLabel.length >= 48 && !cont.contains(':') && !cont.contains(' ')) {
        curLabel = '$curLabel$cont'; // libellé coupé en bout de colonne
      } else if (curExtra.length < 2) {
        curExtra.add(cont.replaceFirst(RegExp(r'^LIBELLE:', caseSensitive: false), ''));
      }
    }
  }
  flush();

  if (cols == null) {
    throw const ImportException('Ce PDF ne ressemble pas à un relevé de compte LCL (tableau des écritures introuvable).');
  }
  if (out.isEmpty) throw const ImportException('Aucune opération trouvée dans ce relevé PDF.');
  return ParseResult(out, 'PDF', balanceCents: closing, balanceDate: end);
}
