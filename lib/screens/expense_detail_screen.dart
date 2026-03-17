import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/expense.dart';
import '../services/api_service.dart';
import '../services/expense_service.dart';
import '../utils/app_format.dart';
import '../widgets/brand_app_bar_title.dart';
import 'expense_edit_screen.dart';

class ExpenseDetailScreen extends StatefulWidget {
  const ExpenseDetailScreen({super.key, required this.expense});

  final Expense expense;

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  final ExpenseService _expenseService = ExpenseService();
  late Expense _expense;
  bool _didChange = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _expense = widget.expense;
  }

  void _popWithResult() {
    Navigator.of(context).pop(_didChange);
  }

  Future<void> _openEdit() async {
    final updatedExpense = await Navigator.of(context).push<Expense>(
      MaterialPageRoute(
        builder: (_) => ExpenseEditScreen(expense: _expense),
      ),
    );

    if (!mounted || updatedExpense == null) {
      return;
    }

    setState(() {
      _expense = updatedExpense;
      _didChange = true;
    });
  }

  Future<void> _deleteExpense() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ausgabe löschen'),
        content: Text(
          'Möchtest du „${_expense.shopName}“ wirklich löschen?',
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
      _deleting = true;
    });

    try {
      await _expenseService.deleteExpense(_expense.id);
      if (!mounted) {
        return;
      }

      _didChange = true;
      Navigator.of(context).pop(true);
    } on ApiException catch (exception) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(exception.message)));
    } finally {
      if (mounted) {
        setState(() {
          _deleting = false;
        });
      }
    }
  }

  void _openImagePreview() {
    if ((_expense.receiptImageUrl ?? '').isEmpty) {
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          child: Image.network(_expense.receiptImageUrl!, fit: BoxFit.contain),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fallbackCategory = Category.byId(_expense.categoryId);
    final category = Category.byName(_expense.categoryName) ?? fallbackCategory;
    final categoryColor = _expense.categoryColor != null
        ? Category.colorFromHex(_expense.categoryColor)
        : category.color;
    final categoryIcon = Category.iconForName(
      _expense.categoryIcon ?? category.iconName,
    );
    final categoryLabel = Category.byName(_expense.categoryName)?.localizedName ??
        _expense.categoryName ??
        category.localizedName;

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
          title: const BrandAppBarTitle('Belegdetails'),
          actions: [
            IconButton(
              tooltip: 'Bearbeiten',
              onPressed: _openEdit,
              icon: const Icon(Icons.edit_rounded),
            ),
            IconButton(
              tooltip: 'Löschen',
              onPressed: _deleting ? null : _deleteExpense,
              icon: _deleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if ((_expense.receiptImageUrl ?? '').isNotEmpty)
              GestureDetector(
                onTap: _openImagePreview,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.network(
                      _expense.receiptImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Belegbild konnte nicht geladen werden.'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if ((_expense.receiptImageUrl ?? '').isNotEmpty)
              const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _expense.shopName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DetailRow(
                      icon: Icons.euro_rounded,
                      label: 'Betrag',
                      value: AppFormat.currency(_expense.amount),
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.calendar_today_rounded,
                      label: 'Datum',
                      value: AppFormat.displayDate(_expense.date),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: categoryColor.withValues(alpha: 0.14),
                          foregroundColor: categoryColor,
                          child: Icon(categoryIcon),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Kategorie',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              categoryLabel,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if ((_expense.note ?? '').isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Notiz',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _expense.note!,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
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
                      'OCR-Text',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      (_expense.ocrText ?? '').trim().isEmpty
                          ? 'Für diese Ausgabe wurde kein OCR-Text gespeichert.'
                          : _expense.ocrText!,
                      style: TextStyle(color: Colors.grey.shade700, height: 1.45),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF2563EB)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}


