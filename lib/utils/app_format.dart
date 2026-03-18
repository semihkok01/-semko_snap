import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

class CurrencyTotalEntry {
  const CurrencyTotalEntry({
    required this.currencyCode,
    required this.total,
    this.expenseCount = 0,
    this.dailyAverage,
  });

  final String currencyCode;
  final double total;
  final int expenseCount;
  final double? dailyAverage;

  factory CurrencyTotalEntry.fromJson(Map<String, dynamic> json) {
    return CurrencyTotalEntry(
      currencyCode: AppFormat.normalizeCurrencyCode(
        json['currency'] as String?,
      ),
      total: (json['total'] as num?)?.toDouble() ?? 0,
      expenseCount: (json['expense_count'] as num?)?.toInt() ?? 0,
      dailyAverage: (json['daily_average'] as num?)?.toDouble(),
    );
  }
}

class AppFormat {
  static const String defaultCurrencyCode = 'EUR';
  static const List<String> supportedCurrencyCodes = [
    'EUR',
    'TRY',
    'USD',
    'GBP',
    'CHF',
    'AED',
    'SAR',
  ];
  static final Set<String> _knownCurrencyCodes = {
    ...supportedCurrencyCodes,
  };
  static const Map<String, String> _currencySymbols = {
    'EUR': '€',
    'TRY': '₺',
    'USD': r'$',
    'GBP': '£',
    'CHF': 'CHF',
    'AED': 'AED',
    'SAR': 'SAR',
  };
  static const Map<String, String> _currencyLabels = {
    'EUR': 'Euro',
    'TRY': 'Turkische Lira',
    'USD': 'US-Dollar',
    'GBP': 'Britisches Pfund',
    'CHF': 'Schweizer Franken',
    'AED': 'VAE-Dirham',
    'SAR': 'Saudi-Riyal',
  };
  static final NumberFormat _decimalFormat = NumberFormat('0.00', 'de_DE');
  static final DateFormat _displayDateFormat = DateFormat('dd.MM.yyyy', 'de_DE');

  static Future<void> initialize() => initializeDateFormatting('de_DE');

  static String currency(num value, {String? currencyCode}) {
    final code = normalizeCurrencyCode(currencyCode);
    return '${amount(value)} ${currencySymbol(code)}';
  }

  static String amount(num value) => _decimalFormat.format(value);

  static String currencySymbol(String? currencyCode) {
    final code = normalizeCurrencyCode(currencyCode);
    return _currencySymbols[code] ?? code;
  }

  static String currencyLabel(String? currencyCode) {
    final code = normalizeCurrencyCode(currencyCode);
    final label = _currencyLabels[code];
    final symbol = currencySymbol(code);
    if (label != null) {
      return '$label ($symbol)';
    }

    return symbol == code ? code : '$code ($symbol)';
  }

  static String normalizeCurrencyCode(
    String? value, {
    String fallback = defaultCurrencyCode,
  }) {
    final normalized = _coerceCurrencyCode(value);
    if (normalized != null) {
      _knownCurrencyCodes.add(normalized);
      return normalized;
    }

    _knownCurrencyCodes.add(fallback);
    return fallback;
  }

  static String? normalizeCurrencyCodeOrNull(String? value) {
    final normalized = _coerceCurrencyCode(value);
    if (normalized != null) {
      _knownCurrencyCodes.add(normalized);
    }
    return normalized;
  }

  static String? _coerceCurrencyCode(String? value) {
    if (value == null) {
      return null;
    }

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final upper = trimmed.toUpperCase();
    const aliases = <String, String>{
      '€': 'EUR',
      'EURO': 'EUR',
      'EUR': 'EUR',
      '₺': 'TRY',
      'TL': 'TRY',
      'TRY': 'TRY',
      'TURKISCHE LIRA': 'TRY',
      'TURK LIRASI': 'TRY',
      'TURKISH LIRA': 'TRY',
      r'$': 'USD',
      'USD': 'USD',
      'DOLLAR': 'USD',
      'US DOLLAR': 'USD',
      '£': 'GBP',
      'GBP': 'GBP',
      'POUND': 'GBP',
      'CHF': 'CHF',
      'FRANK': 'CHF',
      'FRANKEN': 'CHF',
      'AED': 'AED',
      'DIRHAM': 'AED',
      'SAR': 'SAR',
      'RIYAL': 'SAR',
    };

    if (aliases.containsKey(upper)) {
      return aliases[upper];
    }

    if (RegExp(r'^[A-Z]{3}$').hasMatch(upper)) {
      return upper;
    }

    return null;
  }

  static void registerCurrencyCode(String? value) {
    final normalized = _coerceCurrencyCode(value);
    if (normalized != null) {
      _knownCurrencyCodes.add(normalized);
    }
  }

  static void registerCurrencyCodes(Iterable<String?> values) {
    for (final value in values) {
      registerCurrencyCode(value);
    }
  }

  static List<CurrencyTotalEntry> currencyTotalsFromJson(dynamic value) {
    if (value is! List) {
      return const [];
    }

    final totals = value
        .whereType<Map<String, dynamic>>()
        .map(CurrencyTotalEntry.fromJson)
        .toList();
    registerCurrencyCodes(totals.map((entry) => entry.currencyCode));
    return totals;
  }

  static List<String> dropdownCurrencyCodes([
    String? currentCurrencyCode,
    Iterable<String?> additionalCurrencyCodes = const [],
  ]) {
    registerCurrencyCodes(additionalCurrencyCodes);

    final normalizedCurrent = normalizeCurrencyCodeOrNull(currentCurrencyCode);
    final codes = _knownCurrencyCodes.toList()
      ..sort((left, right) {
        final leftIndex = supportedCurrencyCodes.indexOf(left);
        final rightIndex = supportedCurrencyCodes.indexOf(right);
        if (leftIndex == -1 && rightIndex == -1) {
          return left.compareTo(right);
        }
        if (leftIndex == -1) {
          return 1;
        }
        if (rightIndex == -1) {
          return -1;
        }
        return leftIndex.compareTo(rightIndex);
      });

    if (normalizedCurrent != null && !codes.contains(normalizedCurrent)) {
      codes.insert(0, normalizedCurrent);
    }

    return codes;
  }

  static String currencyTotalsSummary(List<CurrencyTotalEntry> totals) {
    return currencyMetricSummary(
      totals,
      (entry) => entry.total,
      emptyValue: currency(0, currencyCode: defaultCurrencyCode),
    );
  }

  static String currencyMetricSummary(
    List<CurrencyTotalEntry> totals,
    double? Function(CurrencyTotalEntry entry) selector, {
    String? emptyValue,
  }) {
    if (totals.isEmpty) {
      return emptyValue ?? currency(0, currencyCode: defaultCurrencyCode);
    }

    final parts = <String>[];
    for (final entry in totals) {
      final value = selector(entry);
      if (value == null) {
        continue;
      }

      parts.add(currency(value, currencyCode: entry.currencyCode));
    }

    if (parts.isEmpty) {
      return emptyValue ?? currency(0, currencyCode: defaultCurrencyCode);
    }

    return parts.join(' • ');
  }

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

    var clean = value.trim();

    for (final symbol in _currencySymbols.values) {
      clean = clean.replaceAll(symbol, '');
    }

    for (final code in _knownCurrencyCodes) {
      clean = clean.replaceAll(RegExp(code, caseSensitive: false), '');
    }

    clean = clean.replaceAll(RegExp(r'\s+'), '').trim();

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
