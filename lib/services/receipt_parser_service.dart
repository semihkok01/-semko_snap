import 'dart:math' as math;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/receipt_parse_result.dart';

class ReceiptParserService {
  ReceiptParseResult parse(RecognizedText recognizedText) {
    final lines = _extractLines(recognizedText);
    final ocrText = recognizedText.text.trim();
    final merchant = _detectMerchant(lines, ocrText);
    final amount = _detectAmount(lines);
    final date = _detectDate(lines);

    return ReceiptParseResult(
      shopName: merchant.value,
      amount: amount.value,
      date: date.value,
      ocrText: ocrText,
      shopConfidence: merchant.confidence,
      amountConfidence: amount.confidence,
      dateConfidence: date.confidence,
      source: 'mlkit',
    );
  }

  List<_ReceiptLine> _extractLines(RecognizedText recognizedText) {
    final lines = <_ReceiptLine>[];
    var index = 0;

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = _normalizeSpaces(line.text);
        if (text.isEmpty) {
          continue;
        }

        final box = line.boundingBox;
        lines.add(
          _ReceiptLine(
            text: text,
            normalized: text.toLowerCase(),
            top: box.top.toDouble(),
            left: box.left.toDouble(),
            index: index,
          ),
        );
        index += 1;
      }
    }

    lines.sort((a, b) {
      final topCompare = a.top.compareTo(b.top);
      if (topCompare != 0) {
        return topCompare;
      }
      return a.left.compareTo(b.left);
    });

    return lines;
  }

  _FieldCandidate<String> _detectMerchant(
    List<_ReceiptLine> lines,
    String fullText,
  ) {
    final normalizedFullText = fullText.toLowerCase();

    for (final entry in _merchantAliases.entries) {
      if (normalizedFullText.contains(entry.key)) {
        return _FieldCandidate(entry.value, 0.96);
      }
    }

    _ScoredValue<String>? best;

    for (var i = 0; i < lines.length && i < 12; i++) {
      final line = lines[i];
      if (!_hasLetters(line.normalized)) {
        continue;
      }

      var score = 0.0;
      if (i < 2) {
        score += 50;
      } else if (i < 5) {
        score += 28;
      }

      if (!_hasDigits(line.normalized)) {
        score += 18;
      } else {
        score -= 20;
      }

      final words = line.normalized.split(RegExp(r'\s+'));
      if (words.length <= 4) {
        score += 12;
      } else {
        score -= 10;
      }

      if (_looksLikeAddress(line.normalized)) {
        score -= 40;
      }

      if (_hasAny(line.normalized, _merchantNoiseKeywords)) {
        score -= 55;
      }

      if (_looksLikeQuantityLine(line.normalized)) {
        score -= 45;
      }

      if (i + 1 < lines.length &&
          _hasAny(lines[i + 1].normalized, _paymentKeywords)) {
        score -= 45;
      }

      if (i + 2 < lines.length &&
          _hasAny(lines[i + 2].normalized, _paymentKeywords)) {
        score -= 25;
      }

      if (line.text.length > 32) {
        score -= 10;
      }

      if (best == null || score > best.score) {
        best = _ScoredValue(line.text, score);
      }
    }

    if (best == null || best.score < 25) {
      return const _FieldCandidate(null, 0);
    }

    return _FieldCandidate(best.value, _confidence(best.score, 20, 110));
  }

  _FieldCandidate<double> _detectAmount(List<_ReceiptLine> lines) {
    _ScoredValue<double>? best;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final matches = _moneyPattern.allMatches(line.text).toList();
      final baseScore = _amountBaseScore(lines, i);

      if (matches.isNotEmpty) {
        for (var m = 0; m < matches.length; m++) {
          final value = matches[m].group(1);
          final amount = value == null ? null : _normalizeAmount(value);
          if (amount == null || amount <= 0) {
            continue;
          }

          var score = baseScore;
          if (m == matches.length - 1) {
            score += 12;
          }
          if (amount >= 1 && amount <= 500) {
            score += 12;
          }
          if (amount < 0.5) {
            score -= 120;
          }
          if (amount > 1000) {
            score -= 80;
          }

          if (best == null || score > best.score) {
            best = _ScoredValue(amount, score);
          }
        }
      }

      if (matches.isEmpty &&
          _hasAny(line.normalized, _finalAmountKeywords) &&
          i + 1 < lines.length) {
        final nextLine = lines[i + 1];
        for (final match in _moneyPattern.allMatches(nextLine.text)) {
          final value = match.group(1);
          final amount = value == null ? null : _normalizeAmount(value);
          if (amount == null || amount <= 0) {
            continue;
          }

          final score = baseScore + 80;
          if (best == null || score > best.score) {
            best = _ScoredValue(amount, score);
          }
        }
      }
    }

    if (best == null || best.score < 40) {
      return const _FieldCandidate(null, 0);
    }

    return _FieldCandidate(best.value, _confidence(best.score, 30, 220));
  }

  double _amountBaseScore(List<_ReceiptLine> lines, int index) {
    final line = lines[index];
    final text = line.normalized;
    var score = 0.0;

    if (_hasAny(text, _finalAmountKeywords)) {
      score += 165;
    }
    if (_hasAny(text, _totalKeywords)) {
      score += 110;
    }
    if (text.contains('eur') || text.contains('€')) {
      score += 24;
    }
    if (_hasAny(text, _taxKeywords)) {
      score -= 170;
    }
    if (_looksLikeDateOrTime(text)) {
      score -= 150;
    }
    if (_hasAny(text, _transactionNoiseKeywords)) {
      score -= 140;
    }
    if (_looksLikeQuantityLine(text)) {
      score -= 85;
    }
    if (index > lines.length ~/ 2) {
      score += 10;
    }

    if (index > 0 && _hasAny(lines[index - 1].normalized, _finalAmountKeywords)) {
      score += 55;
    }
    if (index + 1 < lines.length &&
        _hasAny(lines[index + 1].normalized, _finalAmountKeywords)) {
      score += 30;
    }

    return score;
  }

  _FieldCandidate<String> _detectDate(List<_ReceiptLine> lines) {
    _ScoredValue<String>? best;
    final now = DateTime.now();

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      for (final pattern in [_isoDatePattern, _localDatePattern]) {
        for (final match in pattern.allMatches(line.text)) {
          final normalized = _normalizeDate(match);
          if (normalized == null) {
            continue;
          }

          var score = 65.0;
          if (_hasAny(line.normalized, _dateKeywords)) {
            score += 30;
          }
          if (_looksLikeDateOrTime(line.normalized)) {
            score += 8;
          }
          if (_hasAny(line.normalized, _transactionNoiseKeywords)) {
            score -= 28;
          }
          if (i > lines.length ~/ 2) {
            score += 12;
          }

          final parsedDate = DateTime.tryParse(normalized);
          if (parsedDate != null) {
            final yearDiff = (parsedDate.year - now.year).abs();
            if (yearDiff <= 2) {
              score += 18;
            } else {
              score -= 22;
            }
          }

          if (best == null || score > best.score) {
            best = _ScoredValue(normalized, score);
          }
        }
      }
    }

    if (best == null) {
      return const _FieldCandidate(null, 0);
    }

    return _FieldCandidate(best.value, _confidence(best.score, 45, 125));
  }

  String _normalizeSpaces(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _hasLetters(String value) => RegExp(r'[A-Za-zÄÖÜäöüß]').hasMatch(value);

  bool _hasDigits(String value) => RegExp(r'\d').hasMatch(value);

  bool _hasAny(String value, List<String> keywords) {
    for (final keyword in keywords) {
      if (value.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  bool _looksLikeAddress(String value) {
    return RegExp(r'(str\.?|straße|street|hamburg|berlin|\b\d{5}\b)').hasMatch(value);
  }

  bool _looksLikeDateOrTime(String value) {
    return RegExp(r'\b\d{1,2}[.:]\d{2}\b').hasMatch(value) ||
        RegExp(r'\b\d{1,2}[./-]\d{1,2}[./-]\d{2,4}\b').hasMatch(value) ||
        RegExp(r'\b\d{4}-\d{2}-\d{2}\b').hasMatch(value);
  }

  bool _looksLikeQuantityLine(String value) {
    return RegExp(r'\d+[.,]\d{2}\s*x\s*\d+').hasMatch(value);
  }

  double? _normalizeAmount(String raw) {
    var clean = raw.replaceAll(' ', '');
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
      final decimals = parts.removeLast();
      clean = '${parts.join()}.$decimals';
    }

    return double.tryParse(clean);
  }

  String? _normalizeDate(RegExpMatch match) {
    if (match.pattern == _isoDatePattern) {
      final year = int.tryParse(match.group(1) ?? '');
      final month = int.tryParse(match.group(2) ?? '');
      final day = int.tryParse(match.group(3) ?? '');
      return _validatedDate(year, month, day);
    }

    final day = int.tryParse(match.group(1) ?? '');
    final month = int.tryParse(match.group(2) ?? '');
    var year = int.tryParse(match.group(3) ?? '');
    if (day == null || month == null || year == null) {
      return null;
    }

    if (year < 100) {
      year += year < 70 ? 2000 : 1900;
    }

    return _validatedDate(year, month, day);
  }

  String? _validatedDate(int? year, int? month, int? day) {
    if (year == null || month == null || day == null) {
      return null;
    }

    try {
      final date = DateTime(year, month, day);
      if (date.year == year && date.month == month && date.day == day) {
        return '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  double _confidence(double score, double minScore, double maxScore) {
    final normalized = (score - minScore) / (maxScore - minScore);
    return math.max(0, math.min(1, normalized));
  }
}

class _ReceiptLine {
  const _ReceiptLine({
    required this.text,
    required this.normalized,
    required this.top,
    required this.left,
    required this.index,
  });

  final String text;
  final String normalized;
  final double top;
  final double left;
  final int index;
}

class _FieldCandidate<T> {
  const _FieldCandidate(this.value, this.confidence);

  final T? value;
  final double confidence;
}

class _ScoredValue<T> {
  const _ScoredValue(this.value, this.score);

  final T value;
  final double score;
}

const Map<String, String> _merchantAliases = {
  'lidl plus': 'Lidl',
  'lidl': 'Lidl',
  'aldi': 'ALDI',
  'rewe': 'REWE',
  'edeka': 'EDEKA',
  'kaufland': 'Kaufland',
  'netto': 'Netto',
  'penny': 'PENNY',
  'rossmann': 'Rossmann',
  'dm': 'dm',
  'budni': 'Budni',
  'ikea': 'IKEA',
  'shell': 'Shell',
  'aral': 'Aral',
  'esso': 'Esso',
};

const List<String> _merchantNoiseKeywords = [
  'summe',
  'betrag',
  'zu zahlen',
  'karte',
  'kartenzahlung',
  'mwst',
  'ust',
  'transaktion',
  'signatur',
  'online',
  'beleg',
  'zahl',
];

const List<String> _paymentKeywords = [
  'zu zahlen',
  'karte',
  'kartenzahlung',
  'summe',
  'betrag',
  'payment',
  'total',
];

const List<String> _totalKeywords = [
  'summe',
  'betrag',
  'zu zahlen',
  'total',
  'gesamt',
  'brutto',
  'eur',
  '€',
];

const List<String> _finalAmountKeywords = [
  'betrag',
  'summe',
  'zu zahlen',
  'gesamt',
  'endbetrag',
  'kartenzahlung',
  'karte',
  'payment',
  'total',
];

const List<String> _taxKeywords = [
  'mwst',
  'ust',
  'steuer',
  'netto',
  'tax',
  'vat',
  'rabatt',
];

const List<String> _transactionNoiseKeywords = [
  'transaktion',
  'tse',
  'signatur',
  'prüfwert',
  'prufwert',
  'beleg',
  'serien',
  'kassen',
  'online',
  'vu-nummer',
  'autorisierung',
  'ust-id',
];

const List<String> _dateKeywords = [
  'datum',
  'date',
  'uhr',
  'zeit',
];

final RegExp _moneyPattern = RegExp(r'(?<!\d)(\d{1,5}(?:[.,]\d{2}))(?!\d)');
final RegExp _isoDatePattern = RegExp(r'\b(\d{4})[\/.\-](\d{1,2})[\/.\-](\d{1,2})\b');
final RegExp _localDatePattern = RegExp(r'\b(\d{1,2})[\/.\-](\d{1,2})[\/.\-](\d{2,4})\b');

