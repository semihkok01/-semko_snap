import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/category.dart';
import '../models/expense.dart';
import '../services/api_service.dart';
import '../services/category_preferences_service.dart';
import '../services/category_service.dart';
import '../services/document_scan_service.dart';
import '../services/expense_service.dart';
import '../utils/app_format.dart';
import '../widgets/authenticated_receipt_image.dart';
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
  final CategoryPreferencesService _categoryPreferencesService =
      CategoryPreferencesService();
  final ImagePicker _imagePicker = ImagePicker();
  final DocumentScanService _documentScanService = DocumentScanService();
  late final TextEditingController _shopController;
  late final TextEditingController _amountController;
  late final TextEditingController _dateController;
  late final TextEditingController _noteController;

  List<Category> _categories = const [];
  Category? _selectedCategory;
  late String _selectedCurrencyCode;
  String? _replacementImagePath;
  bool _loadingCategories = true;
  bool _saving = false;

  bool get _supportsSmartScan => Platform.isAndroid || Platform.isIOS;

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
    _selectedCurrencyCode = widget.expense.currencyCode;
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
      final categories = await _categoryService.fetchCategories(
        includeInactive: true,
      );
      final currentCategory = _currentExpenseCategory();
      final containsCurrent = categories.any(
        (category) => category.id == currentCategory.id,
      );
      final merged = containsCurrent ? categories : [currentCategory, ...categories];
      final sortedCategories = await _categoryPreferencesService.sortCategories(
        merged,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _categories = sortedCategories;
        _selectedCategory = sortedCategories.firstWhere(
          (category) => category.id == currentCategory.id,
          orElse: () => sortedCategories.first,
        );
        _loadingCategories = false;
      });
    } catch (_) {
      final currentCategory = _currentExpenseCategory();
      final fallbackCategories = await _categoryPreferencesService.sortCategories([
        currentCategory,
        ...Category.all.where((category) => category.id != currentCategory.id),
      ]);
      if (!mounted) {
        return;
      }

      setState(() {
        _categories = fallbackCategories;
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

  Future<void> _replaceWithSmartScan() async {
    try {
      final path = await _documentScanService.scanSinglePage();
      if (!mounted || path == null) {
        return;
      }

      setState(() {
        _replacementImagePath = path;
      });
    } catch (exception) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Smart-Scan fehlgeschlagen: $exception')),
      );
    }
  }

  Future<void> _pickReplacementFromGallery() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (!mounted || image == null) {
        return;
      }

      setState(() {
        _replacementImagePath = image.path;
      });
    } catch (exception) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bildauswahl fehlgeschlagen: $exception')),
      );
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
        currencyCode: _selectedCurrencyCode,
        shopName: _shopController.text.trim(),
        date: _dateController.text.trim(),
        categoryId: _selectedCategory!.id,
        note: _noteController.text.trim(),
        receiptImagePath: _replacementImagePath,
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

  Widget _buildReceiptPreview() {
    final hasReplacement = (_replacementImagePath ?? '').isNotEmpty;
    final hasStoredImage = (widget.expense.receiptImage ?? '').isNotEmpty ||
        (widget.expense.receiptImageUrl ?? '').isNotEmpty;

    if (!hasReplacement && !hasStoredImage) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          'Für diese Ausgabe ist noch kein Belegbild gespeichert.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: hasReplacement
            ? Image.file(
                File(_replacementImagePath!),
                fit: BoxFit.cover,
              )
            : AuthenticatedReceiptImage(
                expenseId: widget.expense.id,
                fit: BoxFit.cover,
              ),
      ),
    );
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
                                  child: Text(
                                    category.isActive
                                        ? category.localizedName
                                        : '${category.localizedName} (inaktiv)',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
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
                        const Text(
                          'Belegbild',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildReceiptPreview(),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            if (_supportsSmartScan)
                              OutlinedButton.icon(
                                onPressed: _saving ? null : _replaceWithSmartScan,
                                icon: const Icon(Icons.document_scanner_rounded),
                                label: const Text('Smart-Scan'),
                              ),
                            OutlinedButton.icon(
                              onPressed: _saving ? null : _pickReplacementFromGallery,
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Aus Galerie wählen'),
                            ),
                            if (_replacementImagePath != null)
                              TextButton.icon(
                                onPressed: _saving
                                    ? null
                                    : () {
                                        setState(() {
                                          _replacementImagePath = null;
                                        });
                                      },
                                icon: const Icon(Icons.undo_rounded),
                                label: const Text('Neue Auswahl verwerfen'),
                              ),
                          ],
                        ),
                        if (_replacementImagePath != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Das neue Belegbild wird beim Speichern übernommen.',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
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


