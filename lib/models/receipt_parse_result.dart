class ReceiptParseResult {
  const ReceiptParseResult({
    this.shopName,
    this.amount,
    this.date,
    required this.ocrText,
    this.shopConfidence = 0,
    this.amountConfidence = 0,
    this.dateConfidence = 0,
    this.usedAi = false,
    this.source = 'mlkit',
    this.notes,
  });

  final String? shopName;
  final double? amount;
  final String? date;
  final String ocrText;
  final double shopConfidence;
  final double amountConfidence;
  final double dateConfidence;
  final bool usedAi;
  final String source;
  final String? notes;

  bool get shouldUseAiFallback {
    return amount == null ||
        amountConfidence < 0.78 ||
        shopName == null ||
        shopConfidence < 0.55 ||
        date == null ||
        dateConfidence < 0.70;
  }

  String get sourceLabel {
    switch (source) {
      case 'gemini':
        return 'Gemini';
      case 'mlkit+gemini':
        return 'ML Kit + Gemini';
      default:
        return 'ML Kit';
    }
  }

  ReceiptParseResult copyWith({
    String? shopName,
    double? amount,
    String? date,
    String? ocrText,
    double? shopConfidence,
    double? amountConfidence,
    double? dateConfidence,
    bool? usedAi,
    String? source,
    String? notes,
  }) {
    return ReceiptParseResult(
      shopName: shopName ?? this.shopName,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      ocrText: ocrText ?? this.ocrText,
      shopConfidence: shopConfidence ?? this.shopConfidence,
      amountConfidence: amountConfidence ?? this.amountConfidence,
      dateConfidence: dateConfidence ?? this.dateConfidence,
      usedAi: usedAi ?? this.usedAi,
      source: source ?? this.source,
      notes: notes ?? this.notes,
    );
  }

  factory ReceiptParseResult.fromAiResponse(
    Map<String, dynamic> json, {
    required String fallbackOcrText,
  }) {
    final payload = (json['result'] as Map<String, dynamic>?) ?? json;

    return ReceiptParseResult(
      shopName: _cleanString(payload['shop_name']),
      amount: _toDouble(payload['amount']),
      date: _cleanString(payload['date']),
      ocrText: fallbackOcrText,
      shopConfidence: _toDouble(payload['merchant_confidence']) ?? 0,
      amountConfidence: _toDouble(payload['amount_confidence']) ?? 0,
      dateConfidence: _toDouble(payload['date_confidence']) ?? 0,
      usedAi: true,
      source: 'gemini',
      notes: _cleanString(payload['notes']),
    );
  }

  static String? _cleanString(dynamic value) {
    if (value is! String) {
      return null;
    }

    final clean = value.trim();
    return clean.isEmpty ? null : clean;
  }

  static double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.'));
    }

    return null;
  }
}
