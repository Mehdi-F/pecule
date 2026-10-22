import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'importer.dart';
import 'lcl_pdf.dart';

bool isPdf(List<int> bytes) =>
    bytes.length > 4 && bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46; // %PDF

/// Extrait les mots positionnés d'un PDF (en local, rien n'est envoyé).
List<PdfWord> extractPdfWords(List<int> bytes) {
  PdfDocument? doc;
  try {
    doc = PdfDocument(inputBytes: bytes);
    final out = <PdfWord>[];
    for (final line in PdfTextExtractor(doc).extractTextLines()) {
      for (final w in line.wordCollection) {
        final t = w.text.trim();
        if (t.isEmpty) continue;
        out.add(PdfWord(line.pageIndex, w.bounds.top, w.bounds.left, w.bounds.right, t));
      }
    }
    return out;
  } catch (e) {
    throw ImportException('Impossible de lire ce PDF ($e).');
  } finally {
    doc?.dispose();
  }
}

/// Point d'entrée utilisable avec `compute` (hors du fil de l'interface).
ParseResult parseLclPdfBytes(List<int> bytes) => parseLclPdf(extractPdfWords(bytes));
