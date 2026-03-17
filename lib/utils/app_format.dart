import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

class AppFormat {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'de_DE',
    symbol: '€',
    decimalDigits: 2,
  );
  static final NumberFormat _decimalFormat = NumberFormat('0.00', 'de_DE');
  static final DateFormat _displayDateFormat = DateFormat('dd.MM.yyyy', 'de_DE');

  static Future<void> initialize() => initializeDateFormatting('de_DE');

  static String currency(num value) => _currencyFormat.format(value);

  static String amount(num value) => _decimalFormat.format(value);

  static String date(DateTime value) => _displayDateFormat.format(value);

  static String displayDate(String? value) {
    final parsed = parseDate(value);
    return parsed == null ? (value ?? '') : date(parsed);
  }

  static DateTime? parseDate(String? value) {
    if (value == null) {
      return null;
    }

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    for (final format in [
      DateFormat('dd.MM.yyyy', 'de_DE'),
      DateFormat('yyyy-MM-dd'),
      DateFormat('yyyy/MM/dd'),
      DateFormat('dd.MM.yyyy HH:mm:ss', 'de_DE'),
    ]) {
      try {
        return format.parseStrict(trimmed);
      } catch (_) {
        // Try next format.
      }
    }

    return DateTime.tryParse(trimmed);
  }

  static String apiDate(String? value) {
    final parsed = parseDate(value);
    return parsed == null ? (value ?? '') : date(parsed);
  }

  static double? parseAmount(String? value) {
    if (value == null) {
      return null;
    }

    var clean = value
        .replaceAll('€', '')
        .replaceAll(RegExp(r'\s+'), '')
        .trim();

    if (clean.isEmpty) {
      return null;
    }

    final lastComma = clean.lastIndexOf(',');
    final lastDot = clean.lastIndexOf('.');

    if (lastComma != -1 && lastDot != -1) {
      if (lastComma > lastDot) {
        clean = clean.replaceAll('.', '').replaceAll(',', '.');
      } else {
        clean = clean.replaceAll(',', '');
      }
    } else if (lastComma != -1) {
      clean = clean.replaceAll('.', '').replaceAll(',', '.');
    } else if ('.'.allMatches(clean).length > 1) {
      final parts = clean.split('.');
      final decimal = parts.removeLast();
      clean = '${parts.join()}.$decimal';
    }

    return double.tryParse(clean);
  }
}
