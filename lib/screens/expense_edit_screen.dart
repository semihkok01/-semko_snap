import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/expense.dart';
import '../services/api_service.dart';
import '../services/category_service.dart';
import '../services/expense_service.dart';
import '../utils/app_format.dart';
import '../widgets/brand_app_bar_title.dart';

class ExpenseEditScreen extends StatefulWidget {
  const ExpenseEditScreen({super.key, required this.expense});

  final Expense expense;

  @override
  State<ExpenseEditScreen> createState() => _ExpenseEditScreenState();
}

class _ExpenseEditScreenState extends State<ExpenseEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final ExpenseService _expenseService = ExpenseService();
  final CategoryService _categoryService = CategoryService();
  late final TextEditingController _shopController;
  late final TextEditingController _amountController;
  late final TextEditingController _dateController;
  late final TextEditingController _noteController;

  List<Category> _categories = const [];
  Category? _selectedCategory;
  bool _loadingCategories = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _shopController = TextEditingController(text: widget.expense.shopName);
    _amountController = TextEditingController(
      text: AppFormat.amount(widget.expense.amount),
    );
    _dateController = TextEditingController(
      text: AppFormat.displayDate(widget.expense.date),
    );
    _noteController = TextEditingController(text: widget.expense.note ?? '');
    _loadCategories();
  }

  @override
  void dispose() {
    _shopController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryService.fetchCategories();
      final currentCategory = _currentExpenseCategory();
      final containsCurrent = categories.any(
        (category) => category.id == currentCategory.id,
      );
      final merged = containsCurrent ? categories : [currentCategory, ...categories];

      if (!mounted) {
        return;
      }

      setState(() {
        _categories = merged;
        _selectedCategory = merged.firstWhere(
          (category) => category.id == currentCategory.id,
          orElse: () => merged.first,
        );
        _loadingCategories = false;
      });
    } catch (_) {
      final currentCategory = _currentExpenseCategory();
      if (!mounted) {
        return;
      }

      setState(() {
        _categories = [
          currentCategory,
          ...Category.all.where((category) => category.id != currentCategory.id),
        ];
        _selectedCategory = currentCategory;
        _loadingCategories = false;
      });
    }
  }

  Category _currentExpenseCategory() {
    final byName = Category.byName(widget.expense.categoryName);
    if (byName != null && byName.id == widget.expense.categoryId) {
      return byName.copyWith(isActive: widget.expense.categoryIsActive);
    }

    return Category(
      id: widget.expense.categoryId,
      name: widget.expense.categoryName ?? 'Kategorie',
      iconName: widget.expense.categoryIcon ?? 'category',
      color: Category.colorFromHex(widget.expense.categoryColor),
      isActive: widget.expense.categoryIsActive,
    );
  }

  Future<void> _pickDate() async {
    final initialDate = AppFormat.parseDate(_dateController.text) ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(initialDate.year - 3),
      lastDate: DateTime(initialDate.year + 3),
    );

    if (selected != null) {
      _dateController.text = AppFormat.date(selected);
    }
  }

  Future<bool> _confirmDuplicateSave(ApiException exception) async {
    final duplicate = exception.payload['duplicate'];
    final duplicateExpense = duplicate is Map<String, dynamic>
        ? Expense.fromJson(duplicate)
        : null;

    final content = duplicateExpense == null
        ? 'Es gibt bereits eine ähnliche Ausgabe. Möchtest du trotzdem speichern?'
        : 'Es gibt bereits „${duplicateExpense.shopName}“ am '
            '${AppFormat.displayDate(duplicateExpense.date)} mit '
            '${AppFormat.currency(duplicateExpense.amount)}. Trotzdem speichern?';

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Mögliche Dublette'),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Abbrechen'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Trotzdem speichern'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _submit({bool force = false}) async {
    if (!_formKey.currentState!.validate() || _selectedCategory == null) {
      return;
    }

    final amount = AppFormat.parseAmount(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte einen gültigen Betrag eingeben.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _saving = true;
    });

    try {
      final updatedExpense = await _expenseService.updateExpense(
        expenseId: widget.expense.id,
        amount: amount,
        shopName: _shopController.text.trim(),
        date: _dateController.text.trim(),
        categoryId: _selectedCategory!.id,
        note: _noteController.text.trim(),
        force: force,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(updatedExpense);
    } on ApiException catch (exception) {
      if (!force && exception.isDuplicateExpense) {
        final continueSave = await _confirmDuplicateSave(exception);
        if (!mounted) {
          return;
        }
        if (continueSave) {
          setState(() {
            _saving = false;
          });
          return _submit(force: true);
        }
      }

      if (!mounted) {
        return;
      }

      messenger.showSnackBar(SnackBar(content: Text(exception.message)));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const BrandAppBarTitle('Ausgabe bearbeiten')),
      body: _loadingCategories
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daten korrigieren',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _shopController,
                          decoration: const InputDecoration(
                            labelText: 'Geschäft',
                            prefixIcon: Icon(Icons.storefront_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Bitte ein Geschäft eingeben.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Betrag',
                            prefixIcon: Icon(Icons.euro_rounded),
                          ),
                          validator: (value) {
                            final parsed = AppFormat.parseAmount(value);
                            if (parsed == null || parsed <= 0) {
                              return 'Bitte einen gültigen Betrag eingeben.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<Category>(
                          initialValue: _selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Kategorie',
                            prefixIcon: Icon(Icons.category_rounded),
                          ),
                          items: _categories
                              .map(
                                (category) => DropdownMenuItem<Category>(
                                  value: category,
                                  child: Row(
                                    children: [
                                      Icon(category.iconData, color: category.color),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          category.localizedName,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (!category.isActive)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 8),
                                          child: Text('(inaktiv)'),
                                        ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedCategory = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _dateController,
                          readOnly: true,
                          onTap: _pickDate,
                          decoration: const InputDecoration(
                            labelText: 'Datum',
                            prefixIcon: Icon(Icons.calendar_today_rounded),
                          ),
                          validator: (value) {
                            if (AppFormat.parseDate(value) == null) {
                              return 'Bitte ein gültiges Datum auswählen.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _noteController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Notiz',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.notes_rounded),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _submit,
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Änderungen speichern'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}


