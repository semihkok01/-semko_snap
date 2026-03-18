import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/expense.dart';
import '../services/api_service.dart';
import '../services/category_service.dart';
import '../services/expense_service.dart';
import '../utils/app_format.dart';
import '../widgets/brand_app_bar_title.dart';

class ManualExpenseScreen extends StatefulWidget {
  const ManualExpenseScreen({super.key});

  @override
  State<ManualExpenseScreen> createState() => _ManualExpenseScreenState();
}

class _ManualExpenseScreenState extends State<ManualExpenseScreen> {
  final _shopController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _dateController = TextEditingController(
    text: AppFormat.date(DateTime.now()),
  );
  final _formKey = GlobalKey<FormState>();
  final ExpenseService _expenseService = ExpenseService();
  final CategoryService _categoryService = CategoryService();

  List<Category> _categories = Category.all;
  Category _selectedCategory = Category.all.first;
  String _selectedCurrencyCode = AppFormat.defaultCurrencyCode;
  bool _submitting = false;
  bool _loadingCategories = true;
  String? _categoryNotice;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _shopController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryService.fetchCategories();
      if (!mounted) {
        return;
      }

      final resolvedCategories =
          categories.isNotEmpty ? categories : Category.all;
      setState(() {
        _categories = resolvedCategories;
        _selectedCategory = resolvedCategories.first;
        _categoryNotice = categories.isEmpty
            ? 'Der Server hat keine aktiven Kategorien geliefert. Standardkategorien werden verwendet.'
            : null;
        _loadingCategories = false;
      });
    } on ApiException catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _categories = Category.all;
        _selectedCategory = _categories.first;
        _categoryNotice =
            'Serverkategorien konnten nicht geladen werden. Standardkategorien werden verwendet.';
        _loadingCategories = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _categories = Category.all;
        _selectedCategory = _categories.first;
        _categoryNotice =
            'Kategorien konnten nicht geladen werden. Standardkategorien werden verwendet.';
        _loadingCategories = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = AppFormat.parseDate(_dateController.text) ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
    );

    if (selected != null) {
      _dateController.text = AppFormat.date(selected);
    }
  }

  Future<bool> _confirmDuplicateSave(ApiException exception) async {
    final duplicate = exception.payload['duplicate'];
    final duplicateExpense =
        duplicate is Map<String, dynamic> ? Expense.fromJson(duplicate) : null;

    final content = duplicateExpense == null
        ? 'Es gibt bereits eine ähnliche Ausgabe. Möchtest du trotzdem speichern?'
        : 'Es gibt bereits „${duplicateExpense.shopName}“ am '
            '${AppFormat.displayDate(duplicateExpense.date)} mit '
            '${AppFormat.currency(duplicateExpense.amount, currencyCode: duplicateExpense.currencyCode)}. Trotzdem speichern?';

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
    if (!_formKey.currentState!.validate()) {
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
      _submitting = true;
    });

    try {
      await _expenseService.addManualExpense(
        amount: amount,
        currencyCode: _selectedCurrencyCode,
        categoryId: _selectedCategory.id,
        date: _dateController.text,
        note: _noteController.text.trim(),
        shopName: _shopController.text.trim(),
        force: force,
      );

      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        const SnackBar(content: Text('Ausgabe gespeichert.')),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (exception) {
      if (!force && exception.isDuplicateExpense) {
        final continueSave = await _confirmDuplicateSave(exception);
        if (!mounted) {
          return;
        }
        if (continueSave) {
          setState(() {
            _submitting = false;
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
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const BrandAppBarTitle('Manuelle Ausgabe')),
      body: SafeArea(
        child: _loadingCategories
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
                            'Manuelle Ausgabe erfassen',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Nutze diesen Bildschirm für Ausgaben ohne gescannten Beleg.',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          if (_categoryNotice != null) ...[
                            const SizedBox(height: 18),
                            _InfoNotice(message: _categoryNotice!),
                          ],
                          const SizedBox(height: 22),
                          TextFormField(
                            controller: _shopController,
                            decoration: const InputDecoration(
                              labelText: 'Geschäft oder Zweck',
                              prefixIcon: Icon(Icons.storefront_outlined),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Bitte ein Geschäft oder einen Zweck eingeben.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedCurrencyCode,
                            decoration: const InputDecoration(
                              labelText: 'Währung',
                              prefixIcon: Icon(Icons.payments_rounded),
                            ),
                            items: AppFormat.dropdownCurrencyCodes(_selectedCurrencyCode)
                                .map(
                                  (currency) => DropdownMenuItem<String>(
                                    value: currency,
                                    child: Text(AppFormat.currencyLabel(currency)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedCurrencyCode = value;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Betrag',
                              prefixText:
                                  '${AppFormat.currencySymbol(_selectedCurrencyCode)} ',
                              hintText: 'z. B. 6,50',
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
                                  (category) => DropdownMenuItem(
                                    value: category,
                                    child: Row(
                                      children: [
                                        Icon(
                                          category.iconData,
                                          color: category.color,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(category.localizedName),
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
                            decoration: const InputDecoration(
                              labelText: 'Datum',
                              prefixIcon: Icon(Icons.calendar_today_rounded),
                            ),
                            onTap: _pickDate,
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
                              onPressed: _submitting ? null : _submit,
                              child: _submitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Ausgabe speichern'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _InfoNotice extends StatelessWidget {
  const _InfoNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFD97706),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF92400E),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

