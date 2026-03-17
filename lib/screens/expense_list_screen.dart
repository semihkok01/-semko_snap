import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/expense.dart';
import '../services/api_service.dart';
import '../services/category_service.dart';
import '../services/expense_service.dart';
import '../utils/app_format.dart';
import '../widgets/brand_app_bar_title.dart';
import '../widgets/error_card.dart';
import 'expense_detail_screen.dart';

class ExpenseListScreen extends StatefulWidget {
  ExpenseListScreen({super.key, int? month, int? year})
      : month = month ?? _currentMonth,
        year = year ?? _currentYear;

  static int get _currentMonth => DateTime.now().month;
  static int get _currentYear => DateTime.now().year;

  final int month;
  final int year;

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  final ExpenseService _expenseService = ExpenseService();
  final CategoryService _categoryService = CategoryService();
  bool _loading = true;
  String? _error;
  int? _deletingExpenseId;
  List<Expense> _expenses = const [];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _categoryService.fetchCategories();
      final expenses = await _expenseService.getExpenses(
        month: widget.month,
        year: widget.year,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _expenses = expenses;
      });
    } on ApiException catch (exception) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = exception.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openExpenseDetail(Expense expense) async {
    final didChange = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ExpenseDetailScreen(expense: expense),
      ),
    );

    if (!mounted || didChange != true) {
      return;
    }

    await _loadExpenses();
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ausgabe löschen'),
        content: Text(
          'Möchtest du „${expense.shopName}“ wirklich löschen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _deletingExpenseId = expense.id;
    });

    try {
      await _expenseService.deleteExpense(expense.id);
      if (!mounted) {
        return;
      }

      setState(() {
        _expenses = _expenses.where((item) => item.id != expense.id).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ausgabe wurde gelöscht.')),
      );
    } on ApiException catch (exception) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(exception.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingExpenseId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _expenses.fold<double>(0, (sum, item) => sum + item.amount);

    return Scaffold(
      appBar: AppBar(
        title: BrandAppBarTitle('${_monthName(widget.month)} ${widget.year}'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadExpenses,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.wallet_rounded, color: Color(0xFF2563EB)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Gesamtausgaben',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                    Text(
                      AppFormat.currency(total),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              ErrorCard(
                message: _error!,
                onRetry: _loadExpenses,
              )
            else if (_expenses.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    'Für diesen Monat wurden keine Ausgaben gefunden.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              )
            else
              ..._expenses.map(
                (expense) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ExpenseCard(
                    expense: expense,
                    deleting: _deletingExpenseId == expense.id,
                    onDelete: () => _deleteExpense(expense),
                    onTap: () => _openExpenseDetail(expense),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember',
    ];

    return months[month - 1];
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.expense,
    required this.deleting,
    required this.onDelete,
    required this.onTap,
  });

  final Expense expense;
  final bool deleting;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fallbackCategory = Category.byId(expense.categoryId);
    final category = Category.byName(expense.categoryName) ?? fallbackCategory;
    final categoryText = Category.byName(expense.categoryName)?.localizedName ??
        expense.categoryName ??
        category.localizedName;
    final categoryColor = expense.categoryColor != null
        ? Category.colorFromHex(expense.categoryColor)
        : category.color;
    final categoryIcon = Category.iconForName(
      expense.categoryIcon ?? category.iconName,
    );

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: categoryColor.withValues(alpha: 0.14),
                foregroundColor: categoryColor,
                child: Icon(categoryIcon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.shopName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      categoryText,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppFormat.displayDate(expense.date),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    if ((expense.note ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        expense.note!,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppFormat.currency(expense.amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  deleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          tooltip: 'Löschen',
                          onPressed: onDelete,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


