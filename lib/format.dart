import 'package:intl/intl.dart';

final NumberFormat _eur = NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 2);

String money(int cents) => _eur.format(cents / 100);

String signedMoney(int cents) {
  if (cents == 0) return money(0);
  return '${cents > 0 ? '+' : '-'} ${_eur.format(cents.abs() / 100)}';
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String dayTitle(DateTime d) => _cap(DateFormat('EEEE d MMMM y', 'fr_FR').format(d));

String shortDate(DateTime d) => DateFormat('d MMM y', 'fr_FR').format(d);

String monthTitle(DateTime d) => _cap(DateFormat('MMMM y', 'fr_FR').format(d));

String centsToInput(int c) => (c / 100).toStringAsFixed(2).replaceAll('.', ',');
