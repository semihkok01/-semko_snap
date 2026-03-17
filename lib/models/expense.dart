class Expense {
  const Expense({
    required this.id,
    required this.shopName,
    required this.amount,
    required this.categoryId,
    required this.date,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    this.categoryIsActive = true,
    this.note,
    this.ocrText,
    this.receiptImage,
    this.receiptImageUrl,
    this.createdAt,
  });

  final int id;
  final String shopName;
  final double amount;
  final int categoryId;
  final String date;
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;
  final bool categoryIsActive;
  final String? note;
  final String? ocrText;
  final String? receiptImage;
  final String? receiptImageUrl;
  final String? createdAt;

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: (json['id'] as num?)?.toInt() ?? 0,
      shopName: (json['shop_name'] as String?)?.trim().isNotEmpty == true
          ? (json['shop_name'] as String).trim()
          : 'Unbekanntes Geschäft',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      categoryId: (json['category_id'] as num?)?.toInt() ?? 0,
      date: (json['date'] as String?)?.trim() ?? '',
      categoryName: json['category_name'] as String?,
      categoryIcon: json['category_icon'] as String?,
      categoryColor: json['category_color'] as String?,
      categoryIsActive: json['category_is_active'] is bool
          ? json['category_is_active'] as bool
          : ((json['category_is_active'] as num?)?.toInt() ?? 1) == 1,
      note: json['note'] as String?,
      ocrText: json['ocr_text'] as String?,
      receiptImage: json['receipt_image'] as String?,
      receiptImageUrl: json['receipt_image_url'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  Expense copyWith({
    int? id,
    String? shopName,
    double? amount,
    int? categoryId,
    String? date,
    String? categoryName,
    String? categoryIcon,
    String? categoryColor,
    bool? categoryIsActive,
    String? note,
    String? ocrText,
    String? receiptImage,
    String? receiptImageUrl,
    String? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      shopName: shopName ?? this.shopName,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      date: date ?? this.date,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      categoryColor: categoryColor ?? this.categoryColor,
      categoryIsActive: categoryIsActive ?? this.categoryIsActive,
      note: note ?? this.note,
      ocrText: ocrText ?? this.ocrText,
      receiptImage: receiptImage ?? this.receiptImage,
      receiptImageUrl: receiptImageUrl ?? this.receiptImageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
