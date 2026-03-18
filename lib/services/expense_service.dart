import '../models/expense.dart';
import '../utils/app_format.dart';
import 'api_service.dart';

class ExpenseService {
  ExpenseService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  Future<Map<String, dynamic>> getStats({
    required int month,
    required int year,
  }) {
    return _apiService.get(
      'get_stats.php',
      queryParameters: {'month': month, 'year': year},
    );
  }

  Future<List<Expense>> getExpenses({
    required int month,
    required int year,
  }) async {
    final response = await _apiService.get(
      'get_expenses.php',
      queryParameters: {'month': month, 'year': year},
    );

    final items = (response['expenses'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();

    return items.map(Expense.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> getArchive() async {
    final response = await _apiService.get('get_archive.php');
    final archive = (response['archive'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();

    return archive;
  }

  Future<Expense?> addManualExpense({
    required double amount,
    required String currencyCode,
    required int categoryId,
    required String date,
    required String note,
    required String shopName,
    bool force = false,
  }) async {
    final response = await _apiService.post(
      'add_manual_expense.php',
      body: {
        'amount': amount.toStringAsFixed(2),
        'currency': AppFormat.normalizeCurrencyCode(currencyCode),
        'category_id': categoryId,
        'date': date,
        'note': note,
        'shop_name': shopName,
        if (force) 'force': true,
      },
    );

    final expense = response['expense'];
    return expense is Map<String, dynamic> ? Expense.fromJson(expense) : null;
  }

  Future<Expense?> addScannedExpense({
    required double amount,
    required String currencyCode,
    required String shopName,
    required String date,
    required int categoryId,
    required String ocrText,
    required String imagePath,
    bool force = false,
  }) async {
    final response = await _apiService.multipart(
      'add_expense.php',
      fields: {
        'amount': amount.toStringAsFixed(2),
        'currency': AppFormat.normalizeCurrencyCode(currencyCode),
        'shop_name': shopName,
        'date': date,
        'category_id': categoryId.toString(),
        'ocr_text': ocrText,
        if (force) 'force': '1',
      },
      files: {'image': imagePath},
    );

    final expense = response['expense'];
    return expense is Map<String, dynamic> ? Expense.fromJson(expense) : null;
  }

  Future<Expense> updateExpense({
    required int expenseId,
    required double amount,
    required String currencyCode,
    required String shopName,
    required String date,
    required int categoryId,
    required String note,
    String? receiptImagePath,
    bool force = false,
  }) async {
    final normalizedCurrency = AppFormat.normalizeCurrencyCode(currencyCode);
    late final Map<String, dynamic> response;

    if (receiptImagePath != null && receiptImagePath.trim().isNotEmpty) {
      response = await _apiService.multipart(
        'update_expense.php',
        fields: {
          'expense_id': expenseId.toString(),
          'amount': amount.toStringAsFixed(2),
          'currency': normalizedCurrency,
          'shop_name': shopName,
          'date': date,
          'category_id': categoryId.toString(),
          'note': note,
          if (force) 'force': '1',
        },
        files: {'image': receiptImagePath},
      );
    } else {
      response = await _apiService.post(
        'update_expense.php',
        body: {
          'expense_id': expenseId,
          'amount': amount.toStringAsFixed(2),
          'currency': normalizedCurrency,
          'shop_name': shopName,
          'date': date,
          'category_id': categoryId,
          'note': note,
          if (force) 'force': true,
        },
      );
    }

    final expense = response['expense'];
    if (expense is! Map<String, dynamic>) {
      throw ApiException('Aktualisierte Ausgabe fehlt in der Serverantwort.');
    }

    return Expense.fromJson(expense);
  }

  Future<void> deleteExpense(int expenseId) async {
    await _apiService.post(
      'delete_expense.php',
      body: {'expense_id': expenseId},
    );
  }

  Future<Map<String, dynamic>> parseReceiptWithAi({
    required String imagePath,
    required String ocrText,
  }) async {
    return _apiService.multipart(
      'parse_receipt_ai.php',
      fields: {
        'ocr_text': ocrText,
      },
      files: {'image': imagePath},
    );
  }
}
