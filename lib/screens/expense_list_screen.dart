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
  final TextEditingController _shopFilterController = TextEditingController();

  bool _loading = true;
  String? _error;
  int? _deletingExpenseId;
  List<Expense> _allExpenses = const [];
  List<Category> _categories = const [];
  int? _selectedCategoryId;
  DateTime? _selectedFilterDate;
  bool _didChange = false;

  bool get _hasActiveFilters =>
      _shopFilterController.text.trim().isNotEmpty ||
      _selectedCategoryId != null ||
      _selectedFilterDate != null;

  @override
  void initState() {
    super.initState();
    _shopFilterController.addListener(_onFilterChanged);
    _loadExpenses();
  }

  @override
  void dispose() {
    _shopFilterController
      ..removeListener(_onFilterChanged)
      ..dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadExpenses() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      List<Category> categories = const [];
      try {
        categories = await _categoryService.fetchCategories(includeInactive: true);
      } catch (_) {
        categories = Category.all;
      }

      final expenses = await _expenseService.getExpenses(
        month: widget.month,
        year: widget.year,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _allExpenses = expenses;
        _categories = _mergeCategories(categories, expenses);
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

    setState(() {
      _didChange = true;
    });

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
        _allExpenses = _allExpenses.where((item) => item.id != expense.id).toList();
        _didChange = true;
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

  List<Category> _mergeCategories(List<Category> categories, List<Expense> expenses) {
    final merged = <Category>[];
    final seen = <int>{};

    void addCategory(Category category) {
      if (seen.add(category.id)) {
        merged.add(category);
      }
    }

    for (final category in categories) {
      addCategory(category);
    }

    for (final expense in expenses) {
      final byName = Category.byName(expense.categoryName);
      if (byName != null && byName.id == expense.categoryId) {
        addCategory(byName.copyWith(isActive: expense.categoryIsActive));
        continue;
      }

      addCategory(
        Category(
          id: expense.categoryId,
          name: expense.categoryName ?? 'Kategorie',
          iconName: expense.categoryIcon ?? 'category',
          color: Category.colorFromHex(expense.categoryColor),
          isActive: expense.categoryIsActive,
        ),
      );
    }

    merged.sort((left, right) => left.localizedName.compareTo(right.localizedName));
    return merged;
  }

  List<Expense> _filteredExpenses() {
    final query = _shopFilterController.text.trim().toLowerCase();
    final selectedDate = _selectedFilterDate != null
        ? _normalizeApiDate(_selectedFilterDate!)
        : null;

    return _allExpenses.where((expense) {
      if (_selectedCategoryId != null && expense.categoryId != _selectedCategoryId) {
        return false;
      }

      if (query.isNotEmpty) {
        final haystack = [expense.shopName, expense.note ?? '']
            .join(' ')
            .toLowerCase();
        if (!haystack.contains(query)) {
          return false;
        }
      }

      if (selectedDate != null && expense.date != selectedDate) {
        return false;
      }

      return true;
    }).toList();
  }

  String _normalizeApiDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _pickFilterDate() async {
    final initialDate = _selectedFilterDate ?? DateTime(widget.year, widget.month, 1);
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(widget.year - 3),
      lastDate: DateTime(widget.year + 3, 12, 31),
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _selectedFilterDate = selected;
    });
  }

  List<CurrencyTotalEntry> _expenseCurrencyTotals(List<Expense> expenses) {
    final totals = <String, double>{};
    for (final expense in expenses) {
      totals.update(
        expense.currencyCode,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    return totals.entries
        .map(
          (entry) => CurrencyTotalEntry(
            currencyCode: entry.key,
            total: entry.value,
          ),
        )
        .toList();
  }

  void _popWithResult() {
    Navigator.of(context).pop(_didChange);
  }

  @override
  Widget build(BuildContext context) {
    final filteredExpenses = _filteredExpenses();
    final totalSummary = AppFormat.currencyTotalsSummary(
      _expenseCurrencyTotals(filteredExpenses),
    );

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _popWithResult();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _popWithResult,
        ),
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
                        _hasActiveFilters ? 'Gefilterte Ausgaben' : 'Gesamtausgaben',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        totalSummary,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filter',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _shopFilterController,
                      decoration: InputDecoration(
                        labelText: 'Geschäft oder Notiz suchen',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _shopFilterController.text.trim().isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _shopFilterController.clear();
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int?>(
                      initialValue: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Kategorie',
                        prefixIcon: Icon(Icons.category_rounded),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Alle Kategorien'),
                        ),
                        ..._categories.map(
                          (category) => DropdownMenuItem<int?>(
                            value: category.id,
                            child: Text(
                              category.isActive
                                  ? category.localizedName
                                  : '${category.localizedName} (inaktiv)',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCategoryId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: TextEditingController(
                        text: _selectedFilterDate == null
                            ? ''
                            : AppFormat.date(_selectedFilterDate!),
                      ),
                      readOnly: true,
                      onTap: _pickFilterDate,
                      decoration: InputDecoration(
                        labelText: 'Datum',
                        prefixIcon: const Icon(Icons.calendar_today_rounded),
                        suffixIcon: _selectedFilterDate == null
                            ? null
                            : IconButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedFilterDate = null;
                                  });
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                    if (_hasActiveFilters) ...[
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _shopFilterController.clear();
                              _selectedCategoryId = null;
                              _selectedFilterDate = null;
                            });
                          },
                          icon: const Icon(Icons.filter_alt_off_rounded),
                          label: const Text('Filter zurücksetzen'),
                        ),
                      ),
                    ],
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
            else if (filteredExpenses.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    _hasActiveFilters
                        ? 'Keine Ausgaben entsprechen den gewählten Filtern.'
                        : 'Für diesen Monat wurden keine Ausgaben gefunden.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              )
            else
              ...filteredExpenses.map(
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
                    AppFormat.currency(
                      expense.amount,
                      currencyCode: expense.currencyCode,
                    ),
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

